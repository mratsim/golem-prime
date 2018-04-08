# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import  strutils, tables, algorithm,
        ./datatypes

proc initBoard*(size: static[int]): Board[size] {.noInit.} =

  for i, mstone in result.mpairs:
    # Set borders
    if  i < size+2 or             # first row
        i >= (size+1)*(size+2) or # last row
        i mod (size+2) == 0 or    # first column
        i mod (size+2) == size+1: # last column
      mstone = Border
    else:
      mstone = Empty

proc initBoardState*(size: static[int]): BoardState[size] {.noInit.} =

  const adj_size_squared = (size+2) * (size+2)
    ## Squared size adjusted to take borders into account

  result.board = initboard(size)
  result.next_player = Black
  result.prev_moves = newSeqOfCap[PlayerMove[size]](MaxNbMoves)
  result.nb_black_stones = 0
  result.empty_points = newSeqofCap[Point[size]](size * size)
  result.empty_points_idx = newSeq[int](adj_size_squared)
  result.ko_pos = -1
  result.groups = newSeq[Group](adj_size_squared)
  result.group_id = newSeq[Point[size]](adj_size_squared) # Note: we do not use newSeqUninitialized to keep the code
  result.group_id.fill(-1)                                # compatible with the Javascript backend
  result.group_next = newSeq[Point[size]](adj_size_squared) # Note: we do not use newSeqUninitialized to keep the code
  result.group_next.fill(-1)                                # compatible with the Javascript backend

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

proc toCoord*(coordStr: string, board_size: static[int]): Coord[board_size]  {.inline.} =

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

  let a = initBoardState(19)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo $initBoard(9)
  echo toCoord("Q16", 19)
  echo toCoord("B1", 19)
