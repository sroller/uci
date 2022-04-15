#!/usr/bin/env ruby

require 'open3'
require 'awesome_print'

if Gem::Platform.local.to_s =~ /linux/
  ENGINE_PATH = '/usr/games/stockfish'
elsif Gem::Platform.local.to_s =~ /mingw32/
  ENGINE_PATH = 'c:/util/stockfish_14_x64_avx2.exe'
end

# seconds to 00:00:00
def sec2human(seconds)
  seconds = seconds.to_i / 1000
  hours = seconds / 3600
  minutes = (seconds - (hours*3600)) / 60
  secs = seconds % 60
  sprintf "%02d:%02d:%02d", hours, minutes, secs
end

def send_string(channel, msg)
  puts "< #{msg}"
  channel.puts(msg)
  sleep(0.25)
end

move = ""

def uci_find_best_move(fen, depth)
  # fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" if fen.nil?

  warn "start #{ENGINE_PATH}"

  sin, sout, thread = Open3.popen2e(ENGINE_PATH)

  input_thread = nil
  output_thread = nil
  bestmove = ""
  score = 0

  output_thread = Thread.new do
    warn "start output thread"
    line = ""
    while true do
      
      line = sout.gets.chomp
      # ap line
      case
      when val = line.match(/depth (\d+) .*score cp (\d+) .*time (\d+).*pv (.*)$/)
        score = val[2].to_f / 100
        printf "%.1f depth: %d %s (%s)\n", val[2].to_f/100, val[1].to_i, val[4], sec2human(val[3])
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
    send_string(sin, "uci")
    send_string(sin, "isready")
    send_string(sin, "ucinewgame")
    send_string(sin, "setoption name UCI_Chess960 value true")
    send_string(sin, "setoption name Threads value 6")
    send_string(sin, "setoption name Hash value 4096")
    send_string(sin, "setoption name MultPV value 2")
    send_string(sin, "position fen #{fen}")
    send_string(sin, "go depth #{depth}")
    while true do
      command = gets.chomp
      send_string(sin, command)
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
  sin.close
  sout.close
  warn "UCI out"
  return bestmove, score
end

# main

depth = 30
File.open("starting_positions.txt", "r") do |f|
  File.write("best_move.csv", "#fen,bestmove,score,depth #{Time.now} #{ENGINE_PATH}\n", mode: "a")
  while fen = f.readline.chomp do
    move, score = uci_find_best_move(fen, depth)
    File.write("best_move.csv", "#{fen},#{move},#{"%.2f" % score},#{depth}\n", mode: "a")
  end
end
warn "done"

