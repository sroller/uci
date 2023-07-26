#!/usr/bin/env ruby

require 'open3'
require 'awesome_print'

if Gem::Platform.local.to_s =~ /linux/
  # ENGINE_PATH = '/usr/games/stockfish'
  ENGINE_PATH = 'stockfish'
elsif Gem::Platform.local.to_s =~ /mingw32/
  ENGINE_PATH = 'c:/util/stockfish_14_x64_avx2.exe'
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
  puts "< #{msg}"
  channel.puts(msg)
  sleep(0.25)
end

move = ""

def uci_find_best_move(fen:, depth:, hash:, threads: )
  fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" if fen.nil?  # standard position

  warn "start #{ENGINE_PATH}"

  uci_inp, uci_out, thread = Open3.popen2e(ENGINE_PATH)

  input_thread = nil
  output_thread = nil
  bestmove = ""
  time = ""
  score = 0
  engine_version = "unknown"

  output_thread = Thread.new do
    warn "start output thread"
    line = ""
    while true do
      
      line = uci_out.readline.chomp
      # ap line
      case
      when line[0..8] == 'Stockfish'
        engine_version = line.match(/(Stockfish [.0-9]+)/)[1] # catch the version number eg 14.1
        puts line
      when val = line.match(/depth (\d+) .*score cp (\d+) .*time (\d+).*pv (.*)$/)
        score = val[2].to_f / 100
        time = sec2human(val[3])
        printf "%.2f depth: %d %s (%s)\n", val[2].to_f/100, val[1].to_i, val[4], time
      else
        puts "> #{line}" unless line =~ /currmove/
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
    send_string(uci_inp, "uci")
    send_string(uci_inp, "isready")
    send_string(uci_inp, "ucinewgame")
    send_string(uci_inp, "setoption name UCI_Chess960 value true")
    send_string(uci_inp, "setoption name Threads value #{threads}")
    send_string(uci_inp, "setoption name Hash value #{hash}")
    send_string(uci_inp, "setoption name MultiPV value 1")
    send_string(uci_inp, "position fen #{fen}")
    send_string(uci_inp, "go depth #{depth}")
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
  return bestmove, score, engine_version, time
end

# main

# parameters should come from config file or command line
depth = 35 
hash_size = 4096 # in megabytes
threads = 6

File.open("starting_positions.txt", "r") do |f|
  File.write("best_move.csv", "#parameters: depth #{depth}, hash #{hash_size}, threads #{threads}, start #{Time.now} with #{ENGINE_PATH}\n", mode: "a")
  File.write("best_move.csv", "#headers: fen,bestmove,score,depth,version,time\n", mode: "a")
  while fen = f.readline.chomp do
    move, score, version, time = uci_find_best_move(fen: fen, depth: depth, hash: hash_size, threads: threads)
    File.write("best_move.csv", "#{fen},#{move},#{"%.2f" % score},#{depth},#{version},#{time}\n", mode: "a")
  end
end
warn "done"

