#!/usr/bin/env ruby

require 'open3'
require 'awesome_print'

if Gem::Platform.local.to_s =~ /linux/
  ENGINE_PATH = '/usr/games/stockfish'
elsif Gem::Platform.local.to_s =~ /mingw/
  ENGINE_PATH = 'c:/util/stockfish-17.0-windows-x86-64-avx2.exe'
  # ENGINE_PATH = 'e:/schach/lc0/lc0.exe -w e:/schach/lc0/weights/384x30-T60-611246.pb.gz'
end

# seconds to 00:00:00
def sec2human(seconds)
  seconds = seconds.to_i / 1000
  hours = seconds / 3600
  minutes = (seconds - (hours*3600)) / 60
  secs = seconds % 60
  sprintf "%0d:%02d:%02d", hours, minutes, secs
end

def send_string(channel, msg)
  warn "< #{msg}"
  channel.puts(msg)
  # sleep(0.25) # is this necessary?
end

move = ""

def uci_find_best_move(fen, set_depth, set_move_time)
  # fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" if fen.nil?

  warn "start #{ENGINE_PATH}"

  uci_inp, uci_out, thread = Open3.popen2e(ENGINE_PATH)

  input_thread = nil
  output_thread = nil
  bestmove = ""
  time = ""
  score = 0
  time = "0"
  depth = 0
  options = Hash.new

  output_thread = Thread.new do
    warn "start output thread"
    line = ""
    # while true do
    while line = sout.gets.chomp do
      # warn "> #{line}"
      next if line =~ /currmove/

      case
      
      when line[0,2] == 'id'
        if /id name (?<v>.+)$/ =~ line
          version = v
        end

      when line[0,6] == 'option'
        if /option name (?<opt>.+) type (?<typ>\w+) default (?<dflt>\w+)/ =~ line
          options[opt] = { type: typ, default: dflt }
        end

      when line[0,4] == 'info'

        if /depth (?<d>\d+)/ =~ line
          depth = d.to_i
        end
        if /score cp (?<s>\d+)/ =~ line
          score = s.to_f / 100
        end
        if /time (?<t>\d+)/ =~ line
          time = sec2human(t)
        end
        if / pv (?<p>.+)$/ =~ line
          pv = p
        end
        printf "%.2f %d %s (%s)\n", score, depth, pv, time
      else
        puts line
      end
      break if line[0,8] == "bestmove"
    end
    warn "bestmove found!"
    bestmove = line.match(/bestmove (\w+)/)[1]
    Thread.kill input_thread
    output_thread.exit
  end

  input_thread = Thread.new do
    warn "start input thread"
    send_string(sin, "uci")
    send_string(sin, "isready")
    send_string(sin, "ucinewgame")
    send_string(sin, "setoption name UCI_Chess960 value true")
    send_string(sin, "setoption name Threads value 32")
    send_string(sin, "setoption name Hash value 57000")
    # send_string(sin, "setoption name MultPV value 1")
    send_string(sin, "position fen #{fen}")
    send_string(sin, "go depth #{set_depth} movetime #{set_move_time}")
    while true do
      command = gets.chomp
      send_string(uci_inp, command)
      if command == "quit"
        # set_global_stop true
        Thread.kill output_thread
        input_thread.exit
      end
    end
    input_thread.exit
  end

  input_thread.join
  output_thread.join
  uci_inp.close
  uci_out.close
  warn "UCI out"
  return bestmove, score, time, depth
end

# main

depth = 40
time = 60000 # in milliseconds

File.open("starting_positions.txt", "r") do |f|
  File.write("best_move.csv", "#started at #{Time.now.utc}, #{ENGINE_PATH}\n#fen,bestmove,score,depth,time\n", mode: "a")
  while fen = f.readline.chomp do
    move, score, last_time, last_depth = uci_find_best_move(fen, depth, time)
    File.write("best_move.csv", "#{fen},#{move},#{"%.2f" % score},#{last_depth},#{last_time}\n", mode: "a")
  end
end
warn "done"

