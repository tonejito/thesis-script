#!/usr/bin/ruby
# encoding: utf-8
#	= ^ . ^ =
# vim : filetype=ruby

########	require

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

########	def

def get_name(identifier="")
  return identifier.split(" ").map {|word| word.capitalize}.join(" ")
end

def get_common_name(identifier="")
  if (identifier.nil?)
    puts "!!! identifier NIL" if (DEBUG)
    return ""
  end
  # Remove all accents and spaces from name to convert to cn
  return identifier.gsub(/\ /,'-').gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N').downcase
end

def get_display_name(identifier="")
  # Convert name to "Sentence Case" including accents and special chars
  return identifier.gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'á','É'=>'é','Í'=>'í','Ó'=>'ó','Ú'=>'ú','Ü'=>'ü','Ñ'=>'ñ').split(" ").map {|word| word.capitalize}.join(" ")
end

def print_result(ldap)
  if (DEBUG)
    p ldap.get_operation_result unless (ldap.get_operation_result.code == 0)
  else
    p ldap.get_operation_result unless (ldap.get_operation_result.code == 0)
  end
end

def valid_group(p_name)
  invalid_names = ["POR ASIGNAR PROFESOR","CONTACTAR A LA DIVISION CORRESPONDIENTE GRUPO CANCELADO CANC"]
  invalid_names.each do |n|
    return false if p_name == n
  end
  return true
end

########	vars

DEBUG = true

number = 20000 + 1

treebase       = "dc=xnas,dc=local"
posix_account_ou = "ou=profesores,ou=users" + "," + treebase
posix_group_ou = "ou=unix,ou=groups" + "," + treebase
posix_group_attribute = "memberUid"
home_prefix     = "/opt/xNAS/files/profesor/"
login_shell = "/usr/sbin/nologin"
employee_type = "profesor"
user_password = "thesis"
gid_number = number
mail = "nobody@localhost"

ldap = Net::LDAP.new \
:host => "thesis",
:port => 389,
:auth =>
{
 :method => :simple,
 :username => "cn=admin,dc=xnas,dc=local",
 :password => "thesis",
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

########	./profesores.rb

profesores = []
i=0

CSV.foreach("../profesores2.csv") do |row|
  rfc, name = row
  next if rfc == "RFC"
  next if rfc == "SIN"
  name = get_name(name)
  rfc = rfc[0,9]
  profesores[i] = [rfc, name]
  i+=1
  
  common_name  = get_common_name(name)
  displayName = get_display_name(name)

  posix_account_dn = "uid=" + rfc + "," + posix_account_ou
  posix_account_attributes =
  {
    :objectclass =>
    [
      "top" ,
      "person" ,
      "organizationalPerson" ,
      "inetOrgPerson" ,
      "posixAccount" ,
      "shadowAccount"
    ] ,
    :uid            => rfc ,
    :cn             => name ,
    :sn             => "." ,
    :mail           => mail ,
    :description    => displayName ,
    :employeeType   => employee_type ,
    :uidNumber      => number.to_s(),
    :gidNumber      => gid_number.to_s() ,
    :homeDirectory  => home_prefix + common_name ,
    :loginShell     => login_shell ,
    :userPassword   => user_password
  }
  
  posix_group_dn = "cn=" + rfc + "," + posix_group_ou
  posix_group_attributes =
  {
      :objectclass =>
    [
      "top" ,
      "posixGroup"
    ] ,
    :cn => rfc ,
    :gidNumber => number.to_s() ,
    :memberuid => rfc
  }

  #puts YAML::dump(posix_account_attributes) if (DEBUG)
  ldap.add( :dn => posix_account_dn , :attributes => posix_account_attributes )
  print_result(ldap)
  
  # Check OpenLDAP return status
  # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
  case ldap.get_operation_result.code
    # 0 success
    when 0
      puts "+ " + posix_account_dn if (DEBUG)
  
      # If the result is successful add the user to the defined posixGroup and create the homeDirectory
      if (ldap.get_operation_result.code == 0)
        #puts YAML::dump(posix_group_attributes) if (DEBUG)
        ldap.add( :dn => posix_group_dn , :attributes => posix_group_attributes)
        print_result(ldap)

        # Check OpenLDAP return status
        case ldap.get_operation_result.code
          # 0 success
          when 0
            puts "+ "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc if (DEBUG)
          # 20 attributeOrValueExists
          when 20
            puts "* "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc + "\t" + "attributeOrValueExists"
          # 68 entryAlreadyExists
          when 68
            puts "* "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc + "\t" + "entryAlreadyExists"
        # 53 unwillingToPerform
          else
            puts "! "+posix_group_dn + " : " + posix_group_attribute + " << " + rfc
            # rollback
            ldap.delete( :dn => posix_account_dn )
            ldap.delete( :dn => posix_group_dn )
            puts "- " + posix_account_dn
            puts "- " + posix_group_dn
        end
      end
    # 20 attributeOrValueExists
    when 20
      puts "* " + posix_account_dn + " << " + rfc + "\t" + "attributeOrValueExists"
    # 68 entryAlreadyExists
    when 68
      puts "* " + posix_account_dn + " << " + rfc + "\t" + "entryAlreadyExists"
    # 53 unwillingToPerform
    else
      puts "! " + posix_account_dn
  end
  
  number+=1
end

########	./materias.rb

materias = []
i=0
bad = []
current = last = nil

# Parse CSV file
CSV.foreach("../materias2.csv") do |row|
  # Get row contents
   id, grupo, materia, p_name = row

  #puts YAML::dump(row) if (DEBUG)
  
  # Skip header
  next if id == "ID"
  next if (!valid_group(p_name))
  
  # job control
  last = current
  current = id
  next if (current == last)
  
  # Remove all accents and spaces from name to convert to cn
  commonName = get_common_name(materia)
  
  # Get current DN
  displayName = "cn=" + id + "," + "ou=materias" + "," + treebase
  
  # Convert name to "Sentence Case" including accents and special chars
  materia = get_display_name(materia)
  
  materia_attributes =
  {
    :objectclass =>
    [
      "top" ,
      "organizationalRole"
    ] ,
    :cn => id ,
    :description => materia ,
  }
  
  ldap.add( :dn => displayName , :attributes => materia_attributes)
  print_result(ldap)
  
  # Check OpenLDAP return status
  case ldap.get_operation_result.code
    # 0 success
    when 0
      puts "+ " + displayName if (DEBUG)
  
      rfc = nil
      a = b = nil
      # assign profesor identifier (rfc) to each subject
      profesores.each do |profesor|
        # Normalize strings before comparison
        a = p_name.chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
        b = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
        if (a.start_with?(b))
          rfc = profesor[0][0,9]
          p_name = b
        end
      end
      bad << i if (rfc.nil? or rfc.empty?)
      #puts row.inspect if (rfc.nil? or rfc.empty?)
      next if (rfc.nil? or rfc.empty?)

      # Put row into array
      materias[i] = [ id, grupo, materia, rfc , p_name ]
      i += 1
      #mat[:id] => { :name => materia , :group => grupo , :rfc => rfc }
      
      group_of_names_cn = rfc + "-" + id
      group_of_names_dn = "cn=" + group_of_names_cn + "," + "ou=webdav,ou=groups" + "," + treebase
      group_of_names_attributes = 
      {
        :objectClass =>
        [
          "top", 
          "groupOfNames"
        ] ,
        :cn => group_of_names_cn ,
        :description => p_name + " + " + materia ,
        :owner => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
        # when processing students we must add the "member" attribute via ldap.add
        :member => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
      }

      #puts YAML::dump([group_of_names_dn , group_of_names_attributes]) if (DEBUG)
      ldap.add( :dn => group_of_names_dn , :attributes => group_of_names_attributes)
      print_result(ldap)
    
      # Check OpenLDAP return status
      case ldap.get_operation_result.code
        # 0 success
        when 0
          puts "+ " + group_of_names_dn + " << " + rfc if (DEBUG)
        # 20 attributeOrValueExists
        when 20
          puts "* " + group_of_names_dn + " << " + rfc + "\t" + "attributeOrValueExists"
        # 68 entryAlreadyExists
        when 68
          puts "* " + group_of_names_dn + " << " + rfc + "\t" + "entryAlreadyExists"
        # 53 unwillingToPerform
        else
          puts "! " + group_of_names_dn
       end
    # 20 attributeOrValueExists
    when 20
      puts "* " + displayName + " << " + commonName + "\t" + "attributeOrValueExists"
    # 68 entryAlreadyExists
    when 68
      puts "* " + displayName + " << " + commonName + "\t" + "entryAlreadyExists"
    # 53 unwillingToPerform
    else
      puts "! " + displayName
  end
end

puts "	= ^ . ^ ="
