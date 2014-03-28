#!/usr/bin/env ruby

# Ruby LDAP quickstart
#
# http://net-ldap.rubyforge.org/Net/LDAP.html

require 'rubygems'
require 'net/ldap'

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

filter = Net::LDAP::Filter.eq("cn","m1-p1")
treebase = "dc=xnas,dc=local"

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

