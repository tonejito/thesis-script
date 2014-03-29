#!/usr/bin/env ruby

# Ruby LDAP quickstart
#
# http://net-ldap.rubyforge.org/Net/LDAP.html

require 'rubygems'
require 'net/ldap'

require 'digest/sha1'
require 'base64'

ldap = Net::LDAP.new \
:host => "localhost",
:port => 389,
:auth =>
{
 :method => :simple,
 :username => "cn=admin,dc=xnas,dc=local",
 :password => "thesis",
}

if ldap.bind
  print "= ^ . ^ =","\n"
else
  print "= T . T =","\n"
end

filter = Net::LDAP::Filter.eq("cn","test")
treebase = "dc=xnas,dc=local"

# https://github.com/ruby-ldap/ruby-net-ldap/blob/master/lib/net/ldap/password.rb
#pw = Net::LDAP::Password.generate(:ssha,"test")
#print pw
str = "test"
srand; salt = (rand * 1000).to_i.to_s
print salt
attribute_value = '{SSHA}' + Base64.encode64(Digest::SHA1.digest(str + salt) + salt).chomp!
print attribute_value

dn = "cn=test,dc=xnas,dc=local"
attrs =
{
  :objectclass => [ "top" , "organizationalRole" , "simpleSecurityObject" ] ,
  :userpassword => attribute_value ,
}

ldap.delete :dn => dn
p ldap.get_operation_result

ldap.add( :dn => dn , :attributes => attrs)
p ldap.get_operation_result


ldap.search(:base => treebase , :filter => filter) do |entry|
  puts "DN: #{entry.dn}"
  entry.each do |atribute , values|
    puts "	#{atribute}:"
    values.each do |value|
      puts "		#{value}"
    end
  end
end

p ldap.get_operation_result

