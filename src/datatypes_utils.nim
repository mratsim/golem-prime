# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import  strutils, tables, algorithm,
        ./datatypes

proc contains*(x: EmptyPoints, point: Point): bool {.inline.} =
  x.data.contains(point)

proc incl*(x: var EmptyPoints, point: Point) {.inline.} =
  ## Add a Point to a set of EmptyPoints
  ## The Point should not be in EmptyPoints already. It will throw
  ## an error in debug mode otherwise

  assert point notin x, "Error: " & $point & " is already in EmptyPoints"
  # We assume point is not already in the set to avoid branching when updating the count

  x.data.incl point
  inc x.len

proc excl*(x: var EmptyPoints, point: Point) {.inline.} =
  ## Remove a Point to a set of EmptyPoints
  ## The Point should be in EmptyPoints. It will throw
  ## an error in debug mode otherwise

  assert point in x, "Error: " & $point & " is not in EmptyPoints"
  # We assume point is in the set to avoid branching when updating the count

  x.data.excl point
  dec x.len

proc newGroupsGraph*[N: static[int16]](gg: var GroupsGraph[N]) =

  const size_squared_with_borders = (N+2) * (N+2)
    ## Squared size adjusted to take borders into account

  newSeq(gg.groups, size_squared_with_borders)
  # Note: we do not use newSeqUninitialized to keep the code
  #       compatible with the Javascript backend

  newSeq(gg.group_id, size_squared_with_borders)
  gg.group_id.fill(-1)
  newSeq(gg.group_next, size_squared_with_borders)
  gg.group_next.fill(-1)

proc newBoardState*(size: static[int16]): BoardState[size] {.noInit.} =

  result.next_player = Black
  result.prev_moves = newSeqOfCap[PlayerMove[size]](MaxNbMoves)
  result.nb_black_stones = 0
  result.ko_pos = -1
  newGroupsGraph[size](result.groups_graph)

  for i, mstone in result.board.mpairs:
    # Set borders
    if  i < size+2 or             # first row
        i >= (size+1)*(size+2) or # last row
        i mod (size+2) == 0 or    # first column
        i mod (size+2) == size+1: # last column
      mstone = Border
    else:
      mstone = Empty
      result.empty_points.incl i.int16

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

  let a = newBoardState(19)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo $newBoardState(9)
  echo toCoord("Q16", 19)
  echo toCoord("B1", 19)
