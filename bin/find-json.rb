#!/usr/bin/ruby
# encoding: utf-8

#{
#  "2014":
#  {
#  "profesor":
#    {
#      "p1":
#      {
#        "m1":["g01","g11"],
#        "m2":["g04","g14"],
#        "m3":["g07","g17"]
#      },
#      "p2":
#      {
#        "m1":["g02","g12"],
#        "m2":["g05","g15"],
#        "m3":["g08","g18"]
#      },
#      "p3":
#      {
#        "m1":["g03","g13"],
#        "m2":["g06","g16"],
#        "m3":["g09","g19"]
#      }
#    }
#  }
#}
#

#	./p1/m2/2014/g04

require 'json'
require 'csv'


data = {}

#parsed_file = CSV.read($stdin, { :col_sep => "\t" })

CSV.foreach("../profesor.data.1", { :col_sep => "\t" }) do |row|
  # Retrieve elements as returned from command
  level, path, dir = row
  #print "\n\t"+row.to_s+"\n"
  # Split into path elements
  path = path.split("/")
  # Remove first element "."
  path.shift
  # Iterate on each element of the path
  #print "\n"+path.length.to_s
  #print "\n"
#  if path.length
    case path.length
      when 0
        #print "\n.\n"
      when 1
        #print "L1 "
        if !(data.has_key? path[0])
           #print "i1 "+path.to_s+" "
           data[path[0]] = {}
	end
      when 2
        #print "L2 "
        if !(data[path[0]].has_key? path[1])
           #print "i2 "+path.to_s+" "
           data[path[0]][path[1]] = {}
        end
      when 3
        #print "L3 "
        if !(data[path[0]][path[1]].has_key? path[2])
           #print "i3 "+path.to_s+" "
           data[path[0]][path[1]][path[2]] = {}
        end
      when 4
        #print "L4 "
        if !(data[path[0]][path[1]][path[2]].has_key? path[3])
           #print "i4 "+path.to_s+" "
           data[path[0]][path[1]][path[2]][path[3]] = []
	end
           #print "i4 "+path.to_s+" << "+dir
           data[path[0]][path[1]][path[2]][path[3]] << dir
	   #print "\n"
      else
        #print "\n:\n"
    end
#  end


end

#print "\n"
print data.to_json
print "\n"
#print data.to_s
#print "\n"

#array = 
#{
#  :y2014 => 
#  {
#    :profesor =>
#    {
#      :p1 =>
#      {
#        :m1 => ["g01","g11"],
#        :m2 => ["g04","g14"],
#        :m3 => ["g07","g17"],
#      },
#      :p2 =>
#      {
#        :m1 => ["g02","g12"],
#        :m2 => ["g05","g15"],
#        :m3 => ["g08","g17"],
#      },
#      :p3 =>
#      {
#        :m1 => ["g03","g13"],
#        :m2 => ["g06","g16"],
#        :m3 => ["g09","g19"],
#      },
#    },
#  },
#}

#print array.to_json

