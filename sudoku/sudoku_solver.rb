UNFILLED_ENTRY = 0
SET = (1..9)

#
# Sudoku board
#
# TODO: Validate board
#
class Board
  def initialize
    @store = []
    @remaining = 0
  end

  attr_reader :store, :remaining

  def add_row(row, entries)
    @store[row] = entries
    update_remaining entries
  end

  def filled_entries_at(position)
    entries = row_entries(position.row) + col_entries(position.col) - [UNFILLED_ENTRY]
    entries.uniq
  end

  def fill(entry, position)
    @store[position.row][position.col] = entry
    @remaining -= 1
  end

  private

  def update_remaining(entries)
    @remaining += entries.select { |entry| entry == UNFILLED_ENTRY }.count
  end

  def row_entries(row)
    store[row]
  end

  def col_entries(col)
    store.map { |row| row[col] }
  end
end

#
# Position of element on the board in terms of row and col
#
class Position
  def initialize(row, col)
    @row = row
    @col = col
  end

  attr_reader :row, :col
end

#
# The 9x9 module of sudoku
#
class Box
  def initialize(key)
    @key = key
    @open_positions = []
    @unfilled_entries = []
  end

  attr_reader :key, :open_positions, :unfilled_entries
  attr_accessor :possibility_map

  def add_open_position(row, col)
    @open_positions.push Position.new(row, col)
  end

  def add_unfilled_entries(entries)
    @unfilled_entries += entries.uniq
    @unfilled_entries.uniq!
  end

  def fill(entry, position)
    @unfilled_entries -= [entry]
    @open_positions -= [position]
    possibility_map.update_possibilities entry, position
  end
end

#
# Entries which are not filled, yet sure to appear in a certain row/column
#
class Linearity
  def initialize
    @rows = {}
    @cols = {}
  end

  attr_reader :rows, :cols

  def add_from(box)
    box.possibility_map.store.each do |entry, positions|
      add_to_row entry, row_from(positions), box.key if row_linear? positions
      add_to_col entry, col_from(positions), box.key if col_linear? positions
    end
  end

  def linearity_map_for(box)
    box.open_positions.inject({}) do |hash, position|
      hash.merge position => possible_filled_entries_for(position, box)
    end
  end

  private

  def row_linear?(positions)
    positions.map(&:row).uniq.count == 1
  end

  def col_linear?(positions)
    positions.map(&:col).uniq.count == 1
  end

  def row_from(positions)
    positions.first.row
  end

  def col_from(positions)
    positions.first.col
  end

  def add_to_row(entry, row, key)
    @rows[row] ||= []
    @rows[row].push entry: entry, box: key
  end

  def add_to_col(entry, col, key)
    @cols[col] ||= []
    @cols[col].push entry: entry, box: key
  end

  def possible_filled_entries_for(position, box)
    row_entries(position.row, box.key) + col_entries(position.col, box.key)
  end

  def row_entries(row, key)
    entries = rows[row] || []
    entries.map { |entry| entry[:entry] if entry[:box] != key }.compact
  end

  def col_entries(col, key)
    entries = cols[col] || []
    entries.map { |entry| entry[:entry] if entry[:box] != key }.compact
  end
end

#
# Stores possible positions of all unfilled entries of a box
#
class PossibilityMap
  def initialize(board, box, linearity)
    @board = board
    @box = box
    @linearity = linearity
    @store = {}
  end

  attr_reader :board, :box, :store, :linearity

  def generate
    generate_linearity_map
    box.unfilled_entries.each { |entry| add entry, allowed_positions_for(entry) }
    self
  end

  def update_possibilities(entry, position)
    @store.delete entry
    @store.each { |_, positions| positions.select! { |pos| pos != position } }
  end

  def positions_with_single_possibility
    @store.select { |_, positions| positions.count == 1 }
  end

  private

  def generate_linearity_map
    @linearity_map = {}
    return if box.possibility_map.nil?
    @linearity_map = linearity.linearity_map_for box
  end

  def allowed_positions_for(entry)
    box.open_positions.select { |position| allowed? entry, position }
  end

  def allowed?(entry, position)
    !filled_entries_at(position).include? entry
  end

  def filled_entries_at(position)
    board_entries_at(position) + linear_entries_at(position)
  end

  def board_entries_at(position)
    board.filled_entries_at(position)
  end

  def linear_entries_at(position)
    @linearity_map[position] || []
  end

  def add(entry, positions)
    @store[entry] = positions
  end
end

#
# Exception raised when current version of solver lacks enough algorithm to solve the puzzle
#
class MissingAlgorithm < StandardError
end

#
# Solver for sudoku
#
class Solver
  def initialize(board, boxes)
    @board = board
    @boxes = boxes
    @linearity = Linearity.new
    @previous = board.remaining
  end

  attr_reader :board, :boxes, :linearity

  def solve
    until board.remaining == 0
      boxes.each { |box| solve_for box }

      raise MissingAlgorithm if @previous == board.remaining
      @previous = board.remaining
    end

    board.store
  end

  private

  def solve_for(box)
    generate_possibility_map_for box
    fetch_positions_to_be_filled_for(box)

    until @positions_to_be_filled.count == 0
      fill box
      fetch_positions_to_be_filled_for(box)
    end

    build_linearity_from box
  end

  def generate_possibility_map_for(box)
    box.possibility_map = PossibilityMap.new(board, box, linearity).generate
  end

  def fetch_positions_to_be_filled_for(box)
    @positions_to_be_filled = box.possibility_map.positions_with_single_possibility
  end

  def fill(box)
    @positions_to_be_filled.each do |entry, positions|
      position = positions.first

      board.fill entry, position
      box.fill entry, position
    end
  end

  def build_linearity_from(box)
    linearity.add_from box
  end
end

#
# Scans input file and builds the board and boxes
#
class InputScanner
  BOX_SIZE = 3

  def initialize(filename)
    @board = Board.new
    @boxes = []
    @file = filename
  end

  attr_reader :board, :boxes, :file

  def scan
    build_board
    build_boxes
  end

  private

  def build_board
    File.foreach(file).with_index { |line, row| board.add_row row, entries(line) }
  end

  def entries(line)
    line.split(' ').map(&:to_i)
  end

  def build_boxes
    BOX_SIZE.times do |n|
      row_offset = n * BOX_SIZE

      add_box block_entries(row_offset, 0), n, 0
      add_box block_entries(row_offset, 3), n, 3
      add_box block_entries(row_offset, 6), n, 6
    end
  end

  def block_entries(row_offset, col_offset)
    board.store[row_offset..row_offset + 2].map do |row|
      row[col_offset..col_offset + 2]
    end
  end

  def add_box(block, row_offset, col_offset)
    key = "#{row_offset}_#{col_offset}"
    box = Box.new key
    @unfilled_entries = SET.to_a

    fill_block(box, block, row_offset, col_offset)

    box.add_unfilled_entries @unfilled_entries
    boxes.push box
  end

  def fill_block(box, block, row_offset, col_offset)
    block.each_with_index do |row_entries, row_index|
      row_entries.each_with_index do |entry, col_index|
        next if entry != UNFILLED_ENTRY

        row = BOX_SIZE * row_offset + row_index
        col = col_offset + col_index

        box.add_open_position row, col
      end

      @unfilled_entries -= row_entries.select { |n| n != UNFILLED_ENTRY }
    end
  end
end

### RUN
scanner = InputScanner.new('inputs/input')
scanner.scan
entries = Solver.new(scanner.board, scanner.boxes).solve

file = File.open('output', 'w')
entries.each { |row| file.puts row.join(' ') }
file.close
