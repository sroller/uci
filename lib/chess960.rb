#!/usr/bin/env ruby

module Chess960
# create Chess960 starting position
# algorithm from https://en.wikipedia.org/wiki/Fischer_random_chess_numbering_scheme

# place knight on free square according to
# position table
def self.place_knights(row, n)
  knight_positions = [
    ['N', 'N', '.', '.', '.'],
    ['N', '.', 'N', '.', '.'],
    ['N', '.', '.', 'N', '.'],
    ['N', '.', '.', '.', 'N'],
    ['.', 'N', 'N', '.', '.'],
    ['.', 'N', '.', 'N', '.'],
    ['.', 'N', '.', '.', 'N'],
    ['.', '.', 'N', 'N', '.'],
    ['.', '.', 'N', '.', 'N'],
    ['.', '.', '.', 'N', 'N']
  ]

  i = 0
  knights = knight_positions[n]
  row.each_with_index do |square, index|
    next unless square == '.'

    row[index] = 'N' if knights[i] == 'N'
    i += 1
  end
  row
end

# place queen on Nth free column
def self.place_queen(row, n)
  i = 0
  row.each_with_index do |square, index|
    next unless square == '.'

    if i == n
      row[index] = 'Q'
      break
    end
    i += 1
  end
  row
end

def self.place_king_and_rooks(row)
  i = 0
  row.each_with_index do |square, index|
    next unless square == '.'

    case i
    when 0
      row[index] = 'R'
    when 1
      row[index] = 'K'
    when 2
      row[index] = 'R'
    end
    i += 1
  end
  row
end

# starting position in FEN
def self.starting_position(n1 = rand(960))

  if (n1 < 0 or n1 > 959)
    raise StandardError.new("#{n1}: parameter not in range from 0-959")
  end
  
  row = Array.new(8) { '.' }
  n2, b1 = n1.divmod(4)

  # light squared bishop
  row[b1 * 2 + 1] = 'B'

  n3, b2 = n2.divmod(4)

  # dark squared bishop
  row[b2 * 2] = 'B'

  n4, q = n3.divmod(6)

  place_queen(row, q)

  place_knights(row, n4)

  place_king_and_rooks(row)

  { pos: n1, fen: "#{row.join.downcase}/pppppppp/8/8/8/8/PPPPPPPP/#{row.join} w KQkq - 0 1" }
end

end

# N1 = 1 # rand(960)
# N1 = 518 # standard chess
puts Chess960.starting_position
puts Chess960.starting_position(959)
puts Chess960.starting_position(518)
puts Chess960.starting_position(0)
puts Chess960.starting_position -1

