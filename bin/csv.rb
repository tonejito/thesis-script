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
  # Remove all accents and spaces from name to convert to cn
  return strip_accents(identifier).gsub(/\ /,'-').downcase
end

def get_display_name(identifier="")
  # Convert name to "Sentence Case" including accents and special chars
  return strip_accents(identifier).split(" ").map {|word| word.capitalize}.join(" ")
end

def get_ascii_string(string="")
  return string.dup.force_encoding("ASCII-8BIT")
end

def print_result(ldap)
  if (DEBUG)
    p ldap.get_operation_result
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

# normalization functions

def strip_accents(string="")
  replacement =
  {
    'á' => 'a','à' => 'a','Á' => 'A','À' => 'A',
    'é' => 'e','è' => 'e','È' => 'E','É' => 'E',
    'í' => 'i','ì' => 'i','Ì' => 'I','Í' => 'I',
    'ó' => 'o','ò' => 'o','Ò' => 'O','Ó' => 'O',
    'ú' => 'u','ù' => 'u','Ù' => 'U','Ú' => 'U',
    'ñ' => 'n','Ñ' => 'N','ü' => 'u','Ü' => 'U'
  }
  return string.gsub(/[áàÁÀéèÈÉíìÌÍóòÒÓúùÙÚñüÑÜ]/,replacement)
end

def strip_title_tag(string="")
  return string.chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"")
end

def normalize(string)
  # Remove <CR> or <CR><LF>
  string = string.chomp
  # Remove leading and trailing space characters and also compact white spaces
  string = string.gsub(/(^\s+)|(\s+$)/,'').gsub(/\s+/,' ')
  # strip punctuation signs
  string = string.gsub(/[.,]/,'')
  # Strip title tag
  string = strip_title_tag(string)
  # Convert spaces into dashes
  string = string.gsub(/\ /,'-')
  # Replace accented letters with [[:alpha:]] chars
  string = strip_accents(string).downcase
  # Remove characters not in the range of \w [a-zA-Z0-9_]
  string = string.split("-").map {|word| word.gsub(/\W/,'')}.join("-")
  return string
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
fallback_mail = "nobody@localhost"

ldap = Net::LDAP.new \
:host => "thesis",
:port => 389,
:auth =>
{
 :method => :simple,
 :username => "cn=admin"+","+treebase,
 :password => "thesis",
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

########	./profesores.rb

profesores = []
i=0

CSV.foreach("../profesores3.csv") do |row|
#CSV.foreach("../profesores2.csv") do |row|
#CSV.foreach("../profesores-fail.csv") do |row|
  rfc, name, mail = row
  next if rfc == "RFC"
  next if rfc == "SIN"
  name = get_name(strip_accents(name))
  rfc = rfc[0,9]
  mail = fallback_mail if (mail.nil? or mail.empty?)
  profesores[i] = [rfc, name, mail]
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
    :cn             => normalize(name) ,
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

#puts YAML::dump(profesores) if (DEBUG)

#  profesores.each do |profesor|
#    #puts profesor.inspect
#    #puts YAML::dump(profesor)
#    puts profesor[1]
#  end

########	./materias.rb

materias = []
i=0
bad = []
current = last = nil

# Parse CSV file
CSV.foreach("../materias2.csv") do |row|
#CSV.foreach("../materias-fail.csv") do |row|
  # Get row contents
  id, grupo, materia, p_rfc, p_name = row

  p_rfc = "" if (p_rfc.nil? or p_rfc.empty?)

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
      #mat[:id] => { :name => materia , :group => grupo , :rfc => rfc }
      
      group_of_names_cn = rfc + "-" + id + "-" + grupo
      #group_of_names_cn = materias[i][3] + "-" + materias[i][0] + "-" + materias[i][1]
      group_of_names_dn = "cn=" + group_of_names_cn + "," + "ou=webdav,ou=groups" + "," + treebase
      group_of_names_attributes = 
      {
        :objectClass =>
        [
          "top", 
          "groupOfNames"
        ] ,
        :cn => group_of_names_cn ,
        :description => [ rfc , "m" + id , "g" + grupo ] ,
        :owner => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
        # when processing students we must add the "member" attribute via ldap.add
        :member => "uid="+rfc+",ou=profesores,ou=users,"+treebase,
        # relationship wuth the subject
        :seeAlso => displayName,
      }
      i += 1
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

#puts YAML::dump(bad) if (DEBUG)
def badish
# Post process each bad entry to match against the profesor names in a regular expression fashion
bad.each do |item|
  # unpack
  id      = materias[item][0]
  rfc     = materias[item][3]
  p_name  = materias[item][4]
  #puts materias[item].inspect if (DEBUG)

  #name = []
  profesores.each do |profesor|
    # normalize string and split into words
    name = profesor[1].chomp.upcase.gsub(/\s+/,' ').gsub(/(M\.[ICAG]|L\.A|I\.Q|ING|FIS|MTRO|MRTO|DRA?)\.?$/,"").split(" ")
    # match the known name against a regular expression
    if (name.length >= 5)
      regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2]+" "+name[3]+" "+name[4])
      puts [p_name , name , regex].inspect if (p_name =~ regex)
    end
    if (name.length >= 4)
      regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2]+" "+name[3])
      puts [p_name , name , regex].inspect if (p_name =~ regex)
    end
    if (name.length >= 3)
      regex = Regexp.new("^"+name[0]+" "+name[1]+" "+name[2])
      puts [p_name , name , regex].inspect if (p_name =~ regex)
    end
    if (name.length >= 2)
      regex = Regexp.new("^"+name[0]+" "+name[1])
      puts [p_name , name , regex].inspect if (p_name =~ regex)
    end
  end
end
end

puts "#	= ^ . ^ ="

#materias.each do |materia|
#  puts YAML::dump(materia) if (!materia[3].nil?)
#end
