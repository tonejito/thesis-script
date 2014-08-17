#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

treebase     = "dc=xnas,dc=local"
accountOU    = "ou=alumnos,ou=users" + "," + treebase
employeeType = "alumno"
userPassword = "thesis"
mail = "nobody@localhost"

last = ""

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

def get_display_name(identifier="")
  # Convert name to "Sentence Case" including accents and special chars
  return identifier.gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'á','É'=>'é','Í'=>'í','Ó'=>'ó','Ú'=>'ú','Ü'=>'ü','Ñ'=>'ñ').split(" ").map {|word| word.capitalize}.join(" ")
end

alumnos = []
i=0

CSV.foreach("../alumnos.csv") do |row|
  num_cta, name, mail, id_materia, materia = row
  next if num_cta == "CUENTA"
  name = name.split(" ").map {|word| word.capitalize}.join(" ")
  alumnos[i] = [num_cta, name, mail, id_materia, materia]
  # skip same employeeNumber
  next if num_cta == last
  i+=1
  commonName  = num_cta
  displayName = get_display_name(name)
  last = num_cta
  
  accountDN = "cn=" + commonName + "," + accountOU
  accountAttributes =
  {
    :objectclass =>
    [
      "top" ,
      "person" ,
      "organizationalPerson" ,
      "inetOrgPerson" ,
      "simpleSecurityObject"
    ] ,
    :cn             => num_cta ,
    :sn             => "." ,
    :mail           => mail ,
    :description    => displayName ,
    :employeeNumber => num_cta ,
    :employeeType   => employeeType ,
    :userPassword   => userPassword
  }
  
  #puts YAML::dump(accountAttributes)
  ldap.add( :dn => accountDN , :attributes => accountAttributes )
  p ldap.get_operation_result
  
  # Check OpenLDAP return status
  # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
  case ldap.get_operation_result.code
    # 0 success
    when 0
      puts "+ " + accountDN
    # 20 attributeOrValueExists
    when 20
      puts "* " + accountDN + " << " + commonName + "\t" + "attributeOrValueExists"
    # 68 entryAlreadyExists
    when 68
      puts "* " + accountDN + " << " + commonName + "\t" + "entryAlreadyExists"
    # 53 unwillingToPerform
    else
      puts "! " + accountDN
  end
  
end
