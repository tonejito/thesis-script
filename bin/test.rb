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

# Payload data for R/W table
payload =
{
  :s =>
  {
    :except => ["usuario"],
    :filename => ["../staff.csv","staff.stdout.csv","staff.stderr.csv"],
    :values => [],
    :total => [],
  },
  :p =>
  {
    :except => ["RFC","SIN"],
#    :filename => ["../profesores-fail.csv","profesores.stdout.csv","profesores.stderr.csv"],
    :filename => ["../profesores.csv","profesores.stdout.csv","profesores.stderr.csv"],
    :values => [],
    :total => [],
  },
  :m =>
  {
    :except => ["ID"],
#    :filename => ["../materias-fail.csv","materias.stdout.csv","materias.stderr.csv"],
    :filename => ["../materias.csv","materias.stdout.csv","materias.stderr.csv"],
    :values => [],
    :total => [],
  },
  :a =>
  {
    :except => ["CUENTA"],
    :filename => ["../alumnos-fail.csv","alumnos.stdout.csv","alumnos.stderr.csv"],
#    :filename => ["../alumnos.csv","alumnos.stdout.csv","alumnos.stderr.csv"],
    :values => [],
    :total => [],
  },
}

# This script *requires* connection to the ldap server
exit unless(ldap.bind)

#XNAS.staff_load(ldap,payload[:s][:filename][0],payload[:s][:filename][1],payload[:s][:filename][2])
#XNAS.profesor_load(ldap,payload[:p][:filename][0],payload[:p][:filename][1],payload[:p][:filename][2])
#XNAS.materias_load(ldap,payload[:m][:filename][0],payload[:m][:filename][1],payload[:m][:filename][2])
XNAS.alumnos_load(ldap,payload[:a][:filename][0],payload[:a][:filename][1],payload[:a][:filename][2])

# Get the read / written values and print them
[0,1,2].each do |i|
  payload.each do |k,v|
    v[:values][i] , v[:total][i] = XNAS.different(v[:filename][i],v[:except])
  end
end
puts "	   uniq		 stdout		 stderr"
puts "	r	w	R	W	R	W"
payload.each do |k,v|
  puts "#{k.to_s}\t#{v[:values].join("\t")}	#{v[:total].join("\t")}"
end

exit
