#!/usr/bin/ruby
# encoding: utf-8
#	= ^ . ^ =
# vim : filetype=ruby

require 'yaml'
require 'rubygems'
require 'net/ldap'

treebase = "dc=xnas,dc=local"


# Define the order of targets and the attributes to pivot on to be deleted
target =
{
  :webdav =>
  {
    :dn => "ou=webdav,ou=groups" + "," +  treebase ,
    :objectClass => "groupOfNames",
    :attribs => ["dn","cn"]
  },
  :materias =>
  {
    :dn => "ou=materias" + "," +  treebase ,
    :objectClass => "organizationalRole",
    :attribs => ["dn","cn"]
  },
  :unix =>
  {
    :dn => "ou=unix,ou=groups" + "," + treebase ,
    :objectClass => "posixGroup",
    :attribs => ["dn","cn"]
  },
  :profesores => 
  {
    :dn => "ou=profesores,ou=users" + "," +  treebase ,
    :objectClass => "posixAccount",
    :attribs => ["dn","cn","uid"]
  },
}

ldap = Net::LDAP.new \
:host => "thesis",
:port => 389,
:auth =>
{
  :method => :simple,
  :username => "cn=admin" + "," + treebase,
  :password => "thesis",
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

# Iterate on each target to delete the contained attributes
target.each do |ou,data|
  # Print current target container
  puts "=>	#{data[:dn]}"
  # Search all the contained items that match the objectClass and delete them as they are found
  ldap.search(
    :base => data[:dn] ,
    :filter => "(objectClass=#{data[:objectClass]})" ,
    :scope => Net::LDAP::SearchScope_SingleLevel ,
    :attriutes => data[:attribs],
    :return_result => true
  ).each do |item|
    # Print the current item being deleted
    puts "- " + item.dn
    ldap.delete_tree( :dn => item.dn)
    # Print errors (if any)
    p ldap.get_operation_result unless (ldap.get_operation_result.code == 0)
  end
end

puts "	= ^ . ^ ="
