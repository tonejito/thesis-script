#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

number = 10000 + 1

treebase       = "dc=xnas,dc=local"
posixAccountOU = "ou=staff,ou=users" + "," + treebase
posixGroupDN = "cn=support,ou=unix,ou=groups" + "," + treebase
posixGroupAttribute = "memberUid"
homeDirectoryPrefix     = "/opt/xNAS/files/staff/"
loginShell = "/bin/bash"
employeeType = "staff"
userPassword = "thesis"
gidNumber = "10000"

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

staff = []
i=0

CSV.foreach("../staff.csv") do |row|
  username , name , mail , curp = row
  next if username == "usuario"
  name = name.split(" ").map {|word| word.capitalize}.join(" ")
  staff[i] = [username , name , mail , curp]
  i+=1
  commonName  = username
  displayName = name

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
    :employeeNumber => curp ,
    :employeeType   => employeeType ,
    :uidNumber      => number.to_s(),
    :gidNumber      => gidNumber ,
    :homeDirectory  => homeDirectoryPrefix + commonName ,
    :loginShell     => loginShell ,
    :userPassword   => userPassword
  }

  ldap.add( :dn => posixAccountDN , :attributes => posixAccountAttributes)

  # Check OpenLDAP return status
  # http://www.openldap.org/doc/admin24/appendix-ldap-result-codes.html
  code = ldap.get_operation_result.code
  case code
    # 0 success
    when 0
      puts "+ " + posixAccountDN
  
      # If the result is successful add the user to the defined posixGroup and create the homeDirectory
      if (ldap.get_operation_result)
        ldap.add_attribute(posixGroupDN, :memberUID, commonName)

        # Check OpenLDAP return status
        code = ldap.get_operation_result.code
        case code
          # 0 success
          when 0
            puts "/ "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
          # 20 attributeOrValueExists
          when 20
            puts "* "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName + "\t" + "attributeOrValueExists"
          # 53 unwillingToPerform
          else
            ldap.delete( :dn => posixAccountDN )
            puts "! "+posixGroupDN + " : " + posixGroupAttribute + " << " + commonName
            puts "- " + posixAccountDN
        end
      end
    # 20 attributeOrValueExists
    when 20
      puts "* " + posixAccountDN + " << " + commonName + "\t" + "attributeOrValueExists"
    # 53 unwillingToPerform
    else
      puts "! " + posixAccountDN
  end
  
  number+=1
end
