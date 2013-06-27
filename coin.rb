#!/usr/bin/env ruby

require "rubygems"
require "json"
require "pp"
require "ruby-tmdb3"
require "colorize"

Tmdb.api_key = "11433deecaf09ef3aa3fb68d7e02a772"

DBFILE = ".coindb.json"
DB_LOCATION = "~/"

class ::Hash
  def method_missing(name)
    return self[name] if key? name
    self.each { |k,v| return v if k.to_s.to_sym == name }
    super.method_missing name
  end
end

class MoviePool
  
  def initialize
    self.read_database
  end
  
  def read_database
    db_path = DB_LOCATION + DBFILE
    if File.exists? File.expand_path(db_path):
      json = File.read(File.expand_path(db_path))
      @movies = JSON.parse(json)
    else
      @movies = Hash.new
    end
  end

  def write_database
    db_path = DB_LOCATION + DBFILE
    File.open(File.expand_path(db_path), "w") { |f| f.write(@movies.to_json) }
  end

  def flip
    pool = []

    @movies.each do |tmdb, movie|
      unless movie.key? "watched"
        weight = movie.rating * 10
        weight.to_i.times do pool << tmdb end
      end
    end

    random_movie = @movies[pool.choice]
    return random_movie
  end
  
  def watch(tmdb=nil)
    if tmdb
      movie = @movies[tmdb]
    else
      movie = self.flip
    end
    puts "Now watching #{ movie.title }"
    self.mark_as_watched(movie.tmdb.to_s)
    exec("open '#{ movie.uri }'") if movie.key? "uri"
  end
  
  def mark_as_watched(tmdb)
    time = Time.now
    @movies[tmdb]["watched"] = time.strftime("%Y-%m-%d %H:%M")
    self.write_database
  end

  def add(movie, uri=nil)
    imdb = movie.match /imdb.com\/title\/(tt\d+)/
    tmdb = movie.match /themoviedb.org\/movie\/(\d+)/
    if tmdb
      result = TmdbMovie.find(:id => tmdb.captures[0], :limit => 1)
    elsif imdb
      result = TmdbMovie.find(:imdb => imdb.captures[0], :limit => 1)
    else
      result = TmdbMovie.find(:title => movie, :limit => 1)
    end
    @movies[result.id.to_s] = {"title" => result.title,
                              "rating" => result.vote_average,
                              "tmdb" => result.id,
                              "released" => result.release_date}
    @movies[result.id.to_s]["uri"] = uri if uri
    self.write_database
    puts "Added #{ result.title } (#{ result.release_date[0..3] })"
  end

  def list
    puts "TMDB ID - Title (Year)\n"
    watched = []
    @movies.each do |key, movie|
      if movie.key? "watched"
        watched << movie
      else
        puts "#{ key } - #{ movie.title } (#{ movie.released[0..3] })"
      end
    end
    puts "\nWatched:"
    watched.each do |movie|
      puts "#{ movie.tmdb.to_s } - #{ movie.title } (#{ movie.released[0..3] })"
    end
    #pp @movies
  end

  def remove(tmdb)
    movie = @movies[tmdb]
    if movie
      @movies.delete(tmdb)
      self.write_database
      puts "Deleted #{ movie.title } (#{ movie.released[0..3] })"
    else
      puts "Movie not found!"
    end
  end
  
  def help
    # TODO Help text
    puts "Coming soon..."
  end

end

if __FILE__ == $0
  action = ARGV[0]
  pool = MoviePool.new
  case action
  when "flip", "f"
    movie = pool.flip
    puts movie.title if movie
  when "watch", "w"
    if ARGV[1]
      pool.watch ARGV[1]
    else
      pool.watch
    end
  when "add", "a"
    if ARGV[2]
      # TODO URI validation
      pool.add(ARGV[1], ARGV[2])
    else
      pool.add ARGV[1]
    end
  when "list", "l"
    pool.list
  when "rm", "del", "delete", "remove", "d"
    pool.remove ARGV[1]
  end
end
