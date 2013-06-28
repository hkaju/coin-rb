#!/usr/bin/env ruby

require "rubygems"
require "json"
require "pp"
require "ruby-tmdb3"
require "colorize"
require "trollop"

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

  def pick
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
  
  def flip(tmdb=nil)
    if tmdb
      movie = @movies[tmdb]
    else
      movie = self.pick
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
  
  def import(filename)
    if File.exist? filename
      File.open(filename, "r").each_line do |entry|
        self.add entry unless entry.match /^[\s]*$/
      end
    else
      puts "File not found: #{ filename }"
    end
  end

end

if __FILE__ == $0
  pool = MoviePool.new
  
  SUB_COMMANDS = %w(add a list l flip f remove delete d rm del)
  global_opts = Trollop::options do
    version "coin-rb 0.1 (c) 2013 Hendrik Kaju <hendrik.kaju@gmail.com>"
    banner "Coin is a utility for picking a semi-random selection from a pool of acceptable movies"
    opt :database, "Movie database file location", :default => File.expand_path(DB_LOCATION + DBFILE)
    stop_on SUB_COMMANDS
  end

  cmd = ARGV.shift
  cmd_opts = case cmd
    when "delete", "remove", "rm", "del", "d"
      ARGV.each do |arg| pool.remove arg end
    when "add", "a"
      ARGV.each do |arg| pool.add arg  end
    when "list", "l"
      pool.list
    when "flip", "f"
      if ARGV[0]
        pool.flip ARGV[0]
      else
        pool.flip
      end
    else
      Trollop::die "Unknown command #{cmd.inspect}"
    end
end