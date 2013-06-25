#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'pp'

json = File.read("movies.txt")
movies = JSON.parse(json)

pool = []
pp movies
movies.each do |id,movie|
  weight = movie["rating"] * 10
  weight.to_i.times do pool << id end
end

puts pool.count

gold = pool.choice
exec("open http://www.imdb.com/title/" << gold)
