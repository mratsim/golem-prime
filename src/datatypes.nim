# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import tables, strutils

type
  Intersection* = enum
    Empty, Black, White, Border # TODO, will having Empty = 0 or Black = 0 + White = 1 faster?
    # If memory/cache speed is a bottleneck, consider packing

  # We index from 0
  Coord*[N: static[int8]] = tuple[col, row: range[0'i8 .. (N-1)]]
  Point*[N: static[int16]] = range[-1'i16 .. (N + 2) * (N + 2) - 1]  # Easily switch how to index for perf testing: native word size (int) vs cache locality (int16)
    # -1 is used for ko position: null
    # TODO something more robust
    # (object variant or separate in 2 types ValidPoints and Ko Points)

  MoveKind* = enum
    Play, Pass, Resign, Undo

  Move*[N: static[int16]] = object
    case kind*: MoveKind
    of Play:
      pos*: Point[N]
    else:
      discard

  Group* = object
    color*: Intersection
    nb_stones*: int16
    nb_pseudo_libs*: int16
    # Graph theory
    sum_degree_vertices*: int16
    sum_square_degree_vertices*: int32

  Board*[N: static[int]] = array[(N + 2) * (N + 2), Intersection]
    # To ease boarder detection in algorithms, boarders are also represented as an (invalid) intersection

  BoardState*[N: static[int16]] = object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.
    #
    # Size 450 Bytes - fits in 7.01 cache lines :/ (64B per cache lines - 7*64B = 448B)
    board*: Board[N]
    next_player*: range[Black..White]
    prev_moves*: seq[Move[N]]

    # With black stones and empty positions we can recompute white score
    nb_black_stones*: int16      # Depending on the ruleset we might need to track captures instead

    # Todo: evaluate using sets or table or intset
    empty_points*: seq[Point[N]] # Heap-allocated, preallocate before multithreading/loops
    empty_points_idx: seq[int]   # Position of each empty_points for O(1) del and add from the middle of the seq

    ko_pos: Point[N]             # Last ko position

    # Groups: this avoid recurring floodfill calls to determine which group a stone is part of.
    # This was a huge bottleneck.
    # However it it heap-allocated and so requires preallocation before multithreading/for loops
    # Todo evaluate using linked lists
    groups: seq[Group]
    group_id: seq[Point[N]]   # one point will be chosen as the id of the group
    group_next: seq[Point[N]] # next stone in the group (linked-list)

  GameState*[N: static[int16]] = object
    ## Besides the board state, immutable data related to the game
    board_state*: BoardState[N]
    komi*: float32
    # ruleset

proc initBoard(size: static[int]): Board[size] {.noInit.} =

  for i, mstone in result.mpairs:
    # Set borders
    if  i < size+2 or             # first row
        i >= (size+1)*(size+2) or # last row
        i mod (size+2) == 0 or    # first column
        i mod (size+2) == size+1: # last column
      mstone = Border
    else:
      mstone = Empty

proc `$`*[N: static[int]](board: Board[N]): string =
  # Display a go board

  # The go board as an extra border on the top, left, right and bottom
  # So a 19x19 board is actually 21x21 and the end of line is at the 20th position of each line

  const stone_display = {
    Empty: '.',
    Black: 'X',
    White: 'O',
    Border: ' '}.toTable

  result = ""

  for i, stone in board:
    result.add stone_display[stone]
    if i mod (N+2) == N+1: # Test if we reach end of line
      result.add '\n'

proc toCoord(coordStr: string, board_size: static[int]): Coord[board_size]  {.inline, noInit.} =

  # Constraints
  #   - No space in input
  #   - board size 25 at most
  #   - square board
  #   - input of length 2 or 3 like A1 and Q16
  #   - input in uppercase
  assert coordStr.len <= 3
  const cols = " ABCDEFGHJKLMNOPQRSTUVWXYZ "

  result.col = int8 cols.find(coordStr[0])
  result.row = int8 parseInt coordStr[1 .. coordStr.high]

when isMainModule:

  let a = BoardState[19](next_player: Black)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo $initBoard(9)
  echo toCoord("Q16", 19)
  echo toCoord("B1", 19)

