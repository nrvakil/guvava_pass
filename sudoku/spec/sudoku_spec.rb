require_relative 'spec_helper'

describe Board do
  let(:board) { Board.new }
  let(:entries) { [0, 5, 0, 6, 1, 3, 0, 0, 8] }
  let(:row) { 0 }
  let(:position) { Position.new 0, 1 }

  describe '.add_row' do
    subject do
      board.add_row(row, entries)
      board
    end

    it 'should add row at correct position' do
      expect(subject.store[row]).to eq entries
    end

    it 'should update remaining entries' do
      expect(subject.remaining).to eq entries.select { |n| n == 0 }.count
    end
  end

  describe '.filled_entries_at' do
    subject do
      board.add_row(row, entries)
      board.filled_entries_at(position)
    end

    it 'should return filled entries at given position' do
      expect(subject).to eq [5, 6, 1, 3, 8]
    end
  end
end

#
# More unit tests can go in the similar fashion
# Next is overall sudoku solver spec
#

describe Solver do
  let(:easy_input) { InputScanner.new('inputs/input_easy') }
  let(:medium_input) { InputScanner.new('inputs/input_medium') }
  let(:hard_input) { InputScanner.new('inputs/input_hard') }

  describe '.solve' do
    context 'easy' do
      subject do
        easy_input.scan
        Solver.new(easy_input.board, easy_input.boxes).solve
      end

      it 'should fill all the entries' do
        expect(subject.any? { |row| row.any? { |e| e == 0 } }).to be_falsy
      end

      it 'should have each row with unique values' do
        expect(subject.any? { |row| row.uniq.count != 9 }).to be_falsy
      end

      it 'should have each column with unique values' do
        expect(subject.transpose.any? { |col| col.uniq.count != 9 }).to be_falsy
      end
    end

    context 'medium' do
      subject do
        medium_input.scan
        Solver.new(medium_input.board, medium_input.boxes).solve
      end

      it 'should fill all the entries' do
        expect(subject.any? { |row| row.any? { |e| e == 0 } }).to be_falsy
      end

      it 'should have each row with unique values' do
        expect(subject.any? { |row| row.uniq.count != 9 }).to be_falsy
      end

      it 'should have each column with unique values' do
        expect(subject.transpose.any? { |col| col.uniq.count != 9 }).to be_falsy
      end
    end

    context 'hard' do
      it 'should raise MissingAlgorithm execpetion' do
        expect do
          hard_input.scan
          Solver.new(hard_input.board, hard_input.boxes).solve
        end.to raise_error(MissingAlgorithm)
      end
    end
  end
end
