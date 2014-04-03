#!/usr/bin/ruby
# encoding: utf-8

require 'csv'
require 'rubygems'
require 'net/ldap'

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

materias = []
i=0

# Parse CSV file
CSV.foreach("../materias.csv") do |row|
  # Get row contents
  id_materia, materia = row

  # Skip header
  next if id_materia == "CLAVE"

  # Put row into array
  materias[i] = [ id_materia , materia ]
  i+=1

  # Remove all accents and spaces from name to convert to cn
  cn = materia.gsub(/\ /,'-').gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'A','É'=>'E','Í'=>'I','Ó'=>'O','Ú'=>'U','Ü'=>'U','Ñ'=>'N').downcase

  # Get current DN
  dn = "cn="+cn+","+"ou=materias"+","+treebase

  # Search directory for DN whitout subtree and save as boolean
  result = ldap.search(:base => dn , :scope => Net::LDAP::SearchScope_BaseObject , :return_result => false)
  
  # Convert name to "Sentence Case" including accents and special chars
  materia = materia.gsub(/[ÁÉÍÓÚÜÑ]/,'Á'=>'á','É'=>'é','Í'=>'í','Ó'=>'ó','Ú'=>'ú','Ü'=>'ü','Ñ'=>'ñ').split(" ").map {|word| word.capitalize}.join(" ")

  # Insert object unless it already exists
  unless(result)
    puts "+ "+dn
    attrs =
    {
      :objectclass => [ "top" , "organizationalRole"] ,
      :cn => cn ,
      :description => materia ,
    }
    
    # Insert object in LDAP tree
    ldap.add( :dn => dn , :attributes => attrs)
    # Search and print object as returned from the LDAP tree
    ldap.search(:base => dn , :scope => Net::LDAP::SearchScope_BaseObject) do |entry|
      puts "DN: #{entry.dn}"
      entry.each do |atribute , values|
        puts "	#{atribute}:"
        values.each do |value|
          puts "		#{value}"
        end
      end
    end

  else
    # Object already exists (no change)
    puts "= "+dn
  end
end

