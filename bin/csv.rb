#!/usr/bin/ruby

require 'csv'

@materias = {}

CSV.foreach("../materias.csv") do |row|
  id_materia, materia = row
  next if id_materia == "CLAVE"
  @materias[id_materia] = materia.split(" ").map {|word| word.capitalize}.join(" ")
end

@materias.each do |key, value| 
  puts key + " - " + value 
end

@profesores = {}

CSV.foreach("../profesores.csv") do |row|
  id_prof, num_trab, curp, RFC, nombre = row
  next if id_prof == "id_prof"
  @profesores[id_prof] = nombre.split(" ").map {|word| word.capitalize}.join(" ")
end

@profesores.each do |key, value| 
  puts key + " : " + value 
end

