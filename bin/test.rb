#!/usr/bin/ruby
# encoding: utf-8
# vim : filetype=ruby

require 'yaml'
require 'csv'
require 'rubygems'
require 'net/ldap'

require 'xnas'

DEBUG=true

treebase = "dc=xnas,dc=local"

ldap = Net::LDAP.new \
:host => "thesis",
:port => 389,
:auth =>
{
 :method => :simple,
 :username => "cn=admin" + "," + treebase,
 :password => "thesis"
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

XNAS.staff_load(ldap,"../staff.csv")
XNAS.profesor_load(ldap,"../profesores3.csv")
XNAS.materias_load(ldap,"../materias2.csv")
XNAS.alumnos_load(ldap,"../alumnos.csv")
exit
