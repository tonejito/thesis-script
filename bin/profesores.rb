#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

number = 20000 + 1

treebase       = "dc=xnas,dc=local"
posixAccountOU = "ou=profesores,ou=users" + "," + treebase
posixGroupOU = "ou=unix,ou=groups" + "," + treebase
posixGroupAttribute = "memberUid"
homeDirectoryPrefix     = "/opt/xNAS/files/profesor/"
loginShell = "/usr/sbin/nologin"
employeeType = "profesor"
userPassword = "thesis"
gidNumber = number
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

def get_common_name(identifier="")
  # Remove all accents and spaces from name to convert to cn
  return identifier.gsub(/\ /,'-').gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N').downcase
end

def get_display_name(identifier="")
  # Convert name to "Sentence Case" including accents and special chars
  return identifier.gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'á','É'=>'é','Í'=>'í','Ó'=>'ó','Ú'=>'ú','Ü'=>'ü','Ñ'=>'ñ').split(" ").map {|word| word.capitalize}.join(" ")
end


profesores = []
i=0

CSV.foreach("../profesores.csv") do |row|
  id_prof, num_trab, curp, rfc, name = row
  next if id_prof == "id_prof"
  name = name.split(" ").map {|word| word.capitalize}.join(" ")
  profesores[i] = [id_prof, num_trab, curp, rfc, name]
  i+=1
  commonName  = get_common_name(name)
  displayName = get_display_name(name)

  posixAccountDN = "uid=" + commonName + "," + posixAccountOU
  posixAccountAttributes =
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
    :uid            => commonName ,
    :cn             => commonName ,
    :sn             => "." ,
    :mail           => mail ,
    :description    => displayName ,
    :employeeNumber => rfc ,
    :employeeType   => employeeType ,
    :uidNumber      => number.to_s(),
    :gidNumber      => gidNumber.to_s() ,
    :homeDirectory  => homeDirectoryPrefix + commonName ,
    :loginShell     => loginShell ,
    :userPassword   => userPassword
  }
  
  posixGroupDN = "cn=" + commonName + "," + posixGroupOU
  posixGroupAttributes =
  {
      :objectclass =>
    [
      "top" ,
      "posixGroup"
    ] ,
    :cn => commonName ,
    :gidnumber => number.to_s() ,
    :memberuid => commonName
  }

  #puts YAML::dump(posixAccountAttributes)
  ldap.add( :dn => posixAccountDN , :attributes => posixAccountAttributes )
  p ldap.get_operation_result

  # Check OpenLDAP return status
  # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
  case ldap.get_operation_result.code
    # 0 success
    when 0
      puts "+ " + posixAccountDN
  
      # If the result is successful add the user to the defined posixGroup and create the homeDirectory
      if (ldap.get_operation_result)
        #puts YAML::dump(posixGroupAttributes)
        ldap.add( :dn => posixGroupDN , :attributes => posixGroupAttributes)
        p ldap.get_operation_result

        # Check OpenLDAP return status
        case ldap.get_operation_result.code
          # 0 success
          when 0
            puts "+ "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
          # 20 attributeOrValueExists
          when 20
            puts "* "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName + "\t" + "attributeOrValueExists"
          # 68 entryAlreadyExists
          when 68
            puts "* "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName + "\t" + "attributeOrValueExists"
        # 53 unwillingToPerform
          else
            puts "! "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
            ldap.delete( :dn => posixAccountDN )
            ldap.delete( :dn => posixGroupDN )
            puts "- " + posixAccountDN
            puts "- " + posixGroupDN
        end
      end
    # 20 attributeOrValueExists
    when 20
      puts "* " + posixAccountDN + " << " + commonName + "\t" + "attributeOrValueExists"
    # 68 entryAlreadyExists
    when 68
      puts "* " + posixAccountDN + " << " + commonName + "\t" + "entryAlreadyExists"
    # 53 unwillingToPerform
    else
      puts "! " + posixAccountDN
  end
  
  number+=1
end
