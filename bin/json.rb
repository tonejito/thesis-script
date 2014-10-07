#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

require 'xnas'

payload="../find.data"

ldap = Net::LDAP.new \
:host => "thesis",
:port => 389,
:auth =>
{
  :method => :simple,
  :username => "cn=admin" + "," + "dc=xnas,dc=local",
  :password => "thesis",
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)
# Convert the find payload to json
XNAS.json_jqxlistmenu(payload,"jqxListMenu.json",ldap)
XNAS.json_jqxtree(payload,"jqxTree.json")
