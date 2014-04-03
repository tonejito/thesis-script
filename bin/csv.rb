#!/usr/bin/ruby

require 'csv'

materias = []
i=0

CSV.foreach("../materias.csv") do |row|
  id_materia, materia = row
  next if id_materia == "CLAVE"
  materia = materia.split(" ").map {|word| word.capitalize}.join(" ")
  materias[i] = [ id_materia , materia ]
  i+=1
end

materias.each do |value|
  puts value.inspect
end


profesores = []
i=0

CSV.foreach("../profesores.csv") do |row|
  id_prof, num_trab, curp, RFC, nombre = row
  next if id_prof == "id_prof"
  nombre = nombre.split(" ").map {|word| word.capitalize}.join(" ")
  profesores[i] = [id_prof, num_trab, curp, RFC, nombre]
  i+=1
end

profesores.each do |value|
  puts value.inspect
end

