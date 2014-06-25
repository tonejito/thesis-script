#!/usr/bin/ruby
# encoding: utf-8

#{ "id": "2",
#    "parentid": "1",
#    "text": "Hot Chocolate",
#    "value": "$2.3"
#}

#	./p1/m2/2014/g04

require 'json'
require 'csv'


data = []

#parsed_file = CSV.read($stdin, { :col_sep => "\t" })

CSV.foreach("../profesor.data.1", { :col_sep => "\t" }) do |row|
  # Retrieve elements as returned from command
  level, path, dir = row
  #print "\n\t"+row.to_s+"\n"
  # Iterate on each element of the path
  #print "\n"+path.length.to_s
  #print "\n"
  data << { "id" => path+"/"+dir , "parent" => path , "name" => dir }

end

#print "\n"
print data.to_json
print "\n"
#print data.to_s
#print "\n"

