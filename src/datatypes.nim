# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import tables, strutils

type
  Stone* = enum
    Empty, Black, White, Border # TODO, will having Empty = 0 or Black = 0 + White = 1 faster?
    # If memory/cache speed is a bottleneck, consider packing

  # We index from 0
  Coord*[N: static[int]] = tuple[col, row: range[0 .. (N-1)]]
  Point*[N: static[int]] = range[0 .. (N + 2) * (N + 2) - 1]  # Easily switch how to index for perf testing: native word size (int) vs cache locality (int16)

  MoveKind* = enum
    Play, Pass, Resign, Undo

  Move*[N: static[int]] = object
    case kind: MoveKind
    of Play:
      pos: Point[N]
    else:
      discard

  Board*[N: static[int]] = array[(N + 2) * (N + 2), Stone]
    # To ease boarder detection in algorithms, boarders are also represented as an (invalid) intersection

  BoardState*[N: static[int]] = object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.
    #
    # Size 450 Bytes - fits in 7.01 cache lines :/ (64B per cache lines - 7*64B = 448B)
    board: Board[N]
    next_player: range[Black..White]
    last_move: Move[N]
    nb_stones: tuple[black, white: int16] # Depending on the ruleset we might need to track captures instead

  GameState*[N: static[int]] = object
    ## Besides the board state, immutable data related to the game
    board_state: BoardState[N]
    komi: float32
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

  result.col = uint8 cols.find(coordStr[0])
  result.row = uint8 parseInt coordStr[1 .. coordStr.high]

when isMainModule:

  let a = BoardState[19](next_player: Black)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of nb_stones: " & $sizeof(a.nb_stones)
  echo "Size of last move: " & $sizeof(a.last_move)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Stone)

  echo $initBoard(9)
  echo toCoord("Q16", 19)
  echo toCoord("B1", 19)

