#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'pp'
require 'themoviedb'

Tmdb::Api.key("11433deecaf09ef3aa3fb68d7e02a772")

class ::Hash
  def method_missing(name)
    return self[name] if key? name
    self.each { |k,v| return v if k.to_s.to_sym == name }
    super.method_missing name
  end
end

def open
  if File.exists? File.expand_path('~/.coindb.json'):
    json = File.read(File.expand_path('~/.coindb.json'))
    @movies = JSON.parse(json)
  else
    @movies = Hash.new
  end
end

def close
  File.open(File.expand_path('~/.coindb.json'), 'w') { |f| f.write(@movies.to_json) }
end

def flip
  open
  pool = []

  @movies.each do |id,movie|
    weight = movie.rating * 10
    weight.to_i.times do pool << id end
  end

  gold = pool.choice
  response = gold ? @movies[gold].title : "No movies in database!"
  puts response
end

def add(title, uri=nil)
  open
  movie = Tmdb::Movie.find(title)[0]
  @movies[movie.id.to_s] = {'title' => movie.title,
                       'rating' => movie.vote_average,
                       'id' => movie.id}
  @movies[movie.id.to_s]['uri'] = uri if uri
  close
end

def list
  open
  puts "ID - Title\n\n"
  @movies.each do |id, movie|
    puts "#{ id } - #{ movie.title }"
  end
end

def remove(id)
  open
  @movies.delete(id)
  close
end

if __FILE__ == $0
  action = ARGV[0]
  case action
  when 'flip', 'f'
    flip
  when 'add', 'a'
    if ARGV[2]
      # TODO URI validation
      add(ARGV[1], ARGV[2])
    else
      add ARGV[1]
    end
  when 'list', 'l'
    list
  when 'del', 'delete', 'remove', 'd'
    remove ARGV[1]
  end
end
