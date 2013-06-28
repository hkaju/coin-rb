#!/usr/bin/env ruby

require "rubygems"
require "json"
require "ruby-tmdb3"
require "colorize"
require "trollop"
require "pp"

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

    @movies.each do |tmdb_id, movie|
      unless movie.key? "watched"
        weight = movie.rating * 10 + 1
        weight.to_i.times do pool << tmdb_id end
      end
    end

    random_movie = @movies[pool.choice]
    return random_movie
  end
  
  def flip
    movie = self.pick
      if movie
        puts "Your random movie is #{ movie.title.blue } (#{ movie.released[0..3] })"
        self.mark_as_watched(movie.tmdb_id.to_s)
        exec("open '#{ movie.url }'") if movie.key? "url"
      else
        puts "No more unwatched movies in the database. Try adding some with 'coin add'."
      end
  end
  
  def mark_as_watched(tmdb_id)
    time = Time.now
    @movies[tmdb_id]["watched"] = time.strftime("%Y-%m-%d %H:%M")
    self.write_database
  end

  def add(movie, url=nil)
    imdb = movie.match /imdb.com\/title\/(tt\d+)/
    tmdb = movie.match /themoviedb.org\/movie\/(\d+)/
    if tmdb
      result = TmdbMovie.find(:id => tmdb.captures[0], :limit => 1)
    elsif imdb
      result = TmdbMovie.find(:imdb => imdb.captures[0], :limit => 1)
    else
      result = TmdbMovie.find(:title => movie, :limit => 1)
    end
    if result != []
      @movies[result.id.to_s] = {"title" => result.title,
                                 "rating" => result.vote_average,
                                 "tmdb_id" => result.id,
                                 "released" => result.release_date}
      @movies[result.id.to_s]["url"] = url if url
      self.write_database
      puts "Added #{ result.title.blue } (#{ result.release_date[0..3] })"
    else
      puts "Movie not found: #{ movie }"
    end
  end
  
  def addurl(tmdb_id, url)
    if @movies.key? tmdb_id
      @movies[tmdb_id]["url"] = url
      puts "Added URL to #{ @movies[tmdb_id].title.blue } (#{ @movies[tmdb_id].released[0..3] })"
    else
      puts "Movie with ID #{ tmdb_id } not found!"
    end
    self.write_database
  end

  def list
    puts "TMDB ID  ".green << "Title".blue << " (Year)\n\n"
    puts "Currently in the pool:"
    watched = []
    @movies.each do |key, movie|
      if movie.key? "watched"
        watched << movie
      else
        puts "#{ movie.tmdb_id.to_s.green } \t #{ movie.title.blue } (#{ movie.released[0..3] })"
      end
    end
    puts "\nAlready watched:"
    watched.each do |movie|
      puts "#{ movie.tmdb_id.to_s.green } \t #{ movie.title.red } (#{ movie.released[0..3] })"
    end
  end

  def remove(tmdb_id)
    movie = @movies[tmdb_id]
    if movie
      @movies.delete(tmdb_id)
      self.write_database
      puts "Deleted #{ movie.title } (#{ movie.released[0..3] })"
    else
      puts "Movie not found!"
    end
  end
  
  def import(filename)
    if File.exist? filename
      puts "Importing #{ filename.dup.green }..."
      File.open(filename, "r").each_line do |entry|
        parts = entry.strip.split ";"
        if parts.length == 2
          self.add(parts[0], url=parts[1]) unless parts[0].match /^[\s]*$/
        else
          self.add entry unless entry.match /^[\s]*$/
        end
      end
    else
      puts "File not found: #{ filename.dup.green }"
    end
  end

end

if __FILE__ == $0
  pool = MoviePool.new
  
  SUB_COMMANDS = %w(add a list l flip f remove delete d rm del import i url u)
  global_opts = Trollop::options do
    version "coin-rb 0.1 (c) 2013 Hendrik Kaju <hendrik.kaju@gmail.com>"
    banner <<-EOS
Coin is a utility for picking a semi-random selection from a pool of acceptable movies.

Usage:
    #{ "coin".red } #{ "[action]".green } #{ "<argument(s)>".blue }
    
Actions:
    #{ "add, a".green }         Add a new movie to the database. Arguments can be movie titles, IMDB addresses (www.imdb.com/title/<IDMB ID>) or TMDb addresses (www.themoviedb.org/movie/<TMDb ID>). If the title contains spaces, enclose it in double quotes (e.g. 'coin add "Kung Fu Panda"')
    #{ "delete, d".green }      Delete a movie from the database. Arguments are movie IDs (TMDb IDs) that are displayed by 'coin list'
    #{ "flip, f".green }        Get a semi-random movie from the database
    #{ "list, l".green }        List all movies in the database
    #{ "import, i".green }      Import movies from a file that contains one movie title/IMDB URL/TMDb URL per line. Arguments are paths to text files
    #{ "url, u".green }         Add a URL to a movie in the database. When the movie is selected, the URL is opened with the command 'open <URL>'. Arguments are the ID of the movie and the URL/filename
    
Options:
EOS
    #opt :database, "Movie database file location", :default => File.expand_path(DB_LOCATION + DBFILE)
    stop_on SUB_COMMANDS
  end

  cmd = ARGV.shift
  cmd_opts = case cmd
    when "delete", "remove", "rm", "del", "d"
      ARGV.each do |arg| pool.remove arg end
    when "add", "a"
      ARGV.each do |arg| pool.add arg end
    when "url", "u"
      tmdb_id = ARGV.shift
      if ARGV[0]
        pool.addurl(tmdb_id, ARGV[0])
      else
        puts "Missing URL!"
      end
    when "list", "l"
      pool.list
    when "flip", "f"
      pool.flip
    when "import", "i"
      ARGV.each do |arg| pool.import arg  end
    else
      Trollop::die "Unknown command #{cmd.inspect}"
    end
end