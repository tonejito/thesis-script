#!/usr/bin/ruby
# encoding: utf-8

require 'csv'
require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

number=30000+1

treebase = "dc=xnas,dc=local"

ldap = Net::LDAP.new \
:host => "localhost",
:port => 389,
:auth =>
{
 :method => :simple,
 :username => "cn=admin,dc=xnas,dc=local",
 :password => "thesis",
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

profesores = []
i=0

CSV.foreach("../profesores.csv") do |row|
  id_prof, num_trab, curp, RFC, nombre = row
  next if id_prof == "id_prof"
  nombre = nombre.split(" ").map {|word| word.capitalize}.join(" ")
  profesores[i] = [id_prof, num_trab, curp, RFC, nombre]
  i+=1
  commonName  = nombre.gsub(/\ /,'-').gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N').downcase
  displayName = nombre.gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'á','É'=>'é','Í'=>'í','Ó'=>'ó','Ú'=>'ú','Ü'=>'ü','Ñ'=>'ñ').split(" ").map {|word| word.capitalize}.join(" ")

  posixAccountDN = "uid="+commonName+","+"ou=profesores,ou=users"+","+treebase
  posixAccountAttributes = {:objectclass => [ "top" , "posixAccount" , "shadowAccount" , "person" , "organizationalPerson" , "inetOrgPerson"] , :uid => commonName , :cn => displayName , :sn => commonName , :uidnumber => number.to_s(), :gidnumber => number.to_s() , :homedirectory => "/opt/xNAS/files/profesor/"+commonName , :loginshell => "/usr/sbin/nologin"}
  posixGroupDN    = "cn="+commonName+","+"ou=profesores,ou=unix,ou=groups"+","+treebase
  posixGroupAttributes = {:objectclass => [ "top" , "posixGroup"] , :cn => commonName , :gidnumber => number.to_s() , :memberuid => commonName }
  puts [posixGroupDN,posixGroupAttributes].inspect
  
  ldap.add( :dn => posixGroupDN , :attributes => posixGroupAttributes)
  puts "+ "+posixGroupDN
  p ldap.get_operation_result

  ldap.add( :dn => posixAccountDN , :attributes => posixAccountAttributes)
  puts "+ "+posixAccountDN
  p ldap.get_operation_result
  
  number+=1
  
end

