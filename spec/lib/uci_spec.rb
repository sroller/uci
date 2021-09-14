require 'spec_helper'
require 'uci'

describe Uci do
  before(:each) do
    allow_any_instance_of(Uci).to receive(:check_engine)
    allow_any_instance_of(Uci).to receive(:open_engine_connection)
    allow_any_instance_of(Uci).to receive(:get_engine_name)
    allow_any_instance_of(Uci).to receive(:new_game!)
  end

  subject do
    Uci.new(
      :engine_path => '/usr/bin/stockfish.exe',
      # :debug => true
    )
  end

  describe "#initialize" do
    let(:valid_options) do
      { :engine_path => 'xxx' }
    end
    it "should be an instance of Uci" do
      expect(subject).to be_a_kind_of Uci
    end
    it "should require :engine_path' in the options hash" do
      expect { Uci.new({}) }.to raise_error(MissingRequiredHashKeyError)
      expect { Uci.new(valid_options) }.to_not raise_exception
    end
    it "should set debug mode" do
      uci = Uci.new(valid_options)
      expect(uci.debug).to be false

      uci = Uci.new(valid_options.merge( :debug => true ))
      expect(uci.debug).to be true
    end
  end

  describe "#ready?" do
    before(:each) do
      expect(subject).to receive(:write_to_engine)
    end

    context "engine is ready" do
      it "should be true" do
        expect(subject).to receive(:read_from_engine).and_return('readyok')

        expect(subject.ready?).to be true
      end
    end

    context "engine is not ready" do
      it "should be false" do
        expect(subject).to receive(:read_from_engine).and_return('no')

        expect(subject.ready?).to be false
      end
    end
  end

  describe "new_game?" do
    context "game is new" do
      it "should be true" do
        expect(subject).to receive(:moves).and_return([])
        expect(subject.new_game?).to be true
      end
    end
    context "game is not new" do
      it "should be false" do
        expect(subject).to receive(:moves).and_return(%w[ a2a3 ])
        expect(subject.new_game?).to be false
      end
    end
  end

  describe "#board" do
    it "should return an ascii-art version of the current board" do
      # starting position
      expect(subject.board).to eq "  ABCDEFGH
8 rnbqkbnr
7 pppppppp
6 ........
5 ........
4 ........
3 ........
2 PPPPPPPP
1 RNBQKBNR
"

      # moves
      subject.move_piece('b2b4')
      subject.move_piece('b8a6')
      expect(subject.board).to eq "  ABCDEFGH
8 r.bqkbnr
7 pppppppp
6 n.......
5 ........
4 .P......
3 ........
2 P.PPPPPP
1 RNBQKBNR
"
    end
  end

  describe "#fenstring" do
    it "should return a short fenstring of the current board" do
      # starting position
      expect(subject.fenstring).to eq "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"

      # moves
      subject.move_piece('b2b4')
      subject.move_piece('b8a6')
      expect(subject.fenstring).to eq "r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR"
    end
  end

  describe "#set_board" do
    it "should set the board layout from a passed LONG fenstring" do
      # given
      expect(subject).to receive( :send_position_to_engine )
      subject.set_board("r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR b KQkq - 0 1")
      # expect
      expect(subject.fenstring).to eq "r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR"
    end
    it "should raise an error is the passed fen format is incorret" do
      # try to use a short fen where we neeed a long fen
      expect { subject.set_board("r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR") }.to raise_exception FenFormatError
    end
  end

  describe "#place_piece" do
    it "should place a piece on the board" do
      subject.place_piece(:white, :queen, "a3")
      expect(subject.get_piece("a3")).to eq [:queen, :white]

      subject.place_piece(:black, :knight, "a3")
      expect(subject.get_piece("a3")).to eq [:knight, :black]
    end
    it "should raise an error if the board was set from a fen string" do
      expect(subject).to receive(:send_position_to_engine)
      subject.set_board("r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR b KQkq - 0 1")
      expect { subject.place_piece(:black, :knight, "a3") }.to raise_exception BoardLockedError
    end
  end

  describe "#clear_position" do
    it "should clear a position on the board" do
      # sanity
      expect(subject.get_piece("a1")).to eq [:rook, :white]
      # given
      subject.clear_position("a1")
      # expect
      expect(subject.piece_at?("a1")).to be false
    end
    it "should raise an error if the board was set from a fen string" do
      expect(subject).to receive(:send_position_to_engine)
      subject.set_board("r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR b KQkq - 0 1")
      expect { subject.clear_position("a1") }.to raise_exception BoardLockedError
    end
  end

  describe "#piece_name" do
    context "symbol name passed" do
      it "should return the single letter symbol" do
        expect(subject.piece_name(:queen)).to eq "q"
        expect(subject.piece_name(:knight)).to eq "n"
      end
    end
    context "single letter symbol passes" do
      it "should return the symbol name" do
        expect(subject.piece_name('n')).to eq :knight
        expect(subject.piece_name('k')).to eq :king
        expect(subject.piece_name('q')).to eq :queen
      end
    end
  end

  describe "#piece_at?" do
    it "should be true if there is a piece at the position indicated" do
      # assume startpos
      expect(subject.piece_at?("a1")).to be true
    end
    it "should be false if there is not a piece at the position indicated" do
      # assume startpos
      expect(subject.piece_at?("a3")).to be false
    end
  end

  describe "#get_piece" do
    it "should return the information for a piece at a given position" do
      # assume startpos
      expect(subject.get_piece('a1')).to eq [:rook, :white]
      expect(subject.get_piece('h8')).to eq [:rook, :black]
    end
    it "should raise an exception if there is no piece at the given position" do
      expect { subject.get_piece('a3') }.to raise_exception NoPieceAtPositionError
    end
  end

  describe "#moves" do
    it "should return the interal move list" do
      # startpos
      expect(subject.moves).to eq []

      # add some moves
      subject.move_piece('a2a3')
      subject.move_piece('a7a5')
      expect(subject.moves).to eq ['a2a3', 'a7a5']
    end
  end

  describe "#move_piece" do
    before(:each) do
      # sanity
      expect(subject.piece_at?("a2")).to be true
      expect(subject.piece_at?("a3")).to be false
    end
    it "should raise an error if the board was set from a fen string" do
      expect(subject).to receive(:send_position_to_engine)
      subject.set_board("r1bqkbnr/pppppppp/n7/8/1P6/8/P1PPPPPP/RNBQKBNR b KQkq - 0 1")
      expect { subject.move_piece("a2a3") }.to raise_exception BoardLockedError
    end
    it "should move pieces from one position to another" do
      piece = subject.get_piece("a2")
      subject.move_piece("a2a3")
      expect(piece).to eq subject.get_piece("a3")
      expect(subject.piece_at?("a2")).to be false
    end
    it 'it should overwrite pieces if one is moved atop another' do
      # note this is an illegal move
      piece = subject.get_piece("a1")
      subject.move_piece("a1a2")
      expect(piece).to eq subject.get_piece("a2")
      expect(subject.piece_at?("a1")).to be false
    end
    it "should raise an exception if the source position has no piece" do
      expect { subject.move_piece("a3a4") }.to raise_exception NoPieceAtPositionError
    end
    it "should promote a pawn to a queen at the correct rank with the correct notation" do
      subject.move_piece("a2a8q")
      expect(subject.get_piece("a8")).to eq [:queen, :white]
    end
    it "should promote a pawn to a rook at the correct rank with the correct notation" do
      subject.move_piece("a2a8r")
      expect(subject.get_piece("a8")).to eq [:rook, :white]
    end
    it "should promote a pawn to a knight at the correct rank with the correct notation" do
      subject.move_piece("a2a8n")
      expect(subject.get_piece("a8")).to eq [:knight, :white]
    end
    it "should promote a pawn to a bishop at the correct rank with the correct notation" do
      subject.move_piece("a2a8b")
      expect(subject.get_piece("a8")).to eq [:bishop, :white]
    end
    it "should raise an exception if promotion to unallowed piece" do
      expect { subject.move_piece("a2a8k") }.to raise_exception UnknownNotationExtensionError
    end
    it "should properly understand castling, white king's rook" do
      subject.move_piece("e1g1")
      expect(subject.get_piece("f1")).to eq [:rook, :white]
      expect(subject.get_piece("g1")).to eq [:king, :white]
    end
    it "should properly understand castling, white queens's rook" do
      subject.move_piece("e1c1")
      expect(subject.get_piece("d1")).to eq [:rook, :white]
      expect(subject.get_piece("c1")).to eq [:king, :white]
    end
    it "should properly understand castling, black king's rook" do
      subject.move_piece("e8g8")
      expect(subject.get_piece("f8")).to eq [:rook, :black]
      expect(subject.get_piece("g8")).to eq [:king, :black]
    end
    it "should properly understand castling, black queens's rook" do
      subject.move_piece("e8c8")
      expect(subject.get_piece("d8")).to eq [:rook, :black]
      expect(subject.get_piece("c8")).to eq [:king, :black]
    end

    it "should append the move to the move log" do
      expect(subject.moves).to be_empty
      subject.move_piece("a2a3")
      expect(subject.moves).to eq ["a2a3"]
    end
  end

  describe "#new_game!" do
    xit "should tell the engine a new game is set" do
      pending
    end
    xit "should reset the internal board" do
      pending
    end
    xit "should set the pieces in a startpos" do
      pending
    end
  end

  describe "#bestmove" do
    xit "should write the bestmove command to the engine" do
      pending
    end
    xit "should detect various forfeit notations" do
      pending
    end
    xit "should raise and exception if the bestmove notation is not understood" do
      pending
    end
    xit "should raise and exception if the returned command was not prefixed with 'bestmove'" do
      pending
    end
  end

  describe "#send_position_to_engine" do
    context "board was set from fen" do
      xit "should send a 'position fen' command" do
        pending
      end
    end
    context "the board is set from startpos" do
      xit "should set a 'position startpo' command followed by the move log" do
        pending
      end
    end
  end

  describe "#go!" do
    xit "should send the current position to the engine" do
      pending
    end
    xit "should update the current board with the result of 'bestmove'" do
      pending
    end
  end
end

