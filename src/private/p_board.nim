# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import  tables,
        ./p_empty_points, ./p_groups, ./p_pointcoord.nim,
        ../datatypes

func newBoardState*(size: static[int8]): BoardState[size] {.noInit.} =

  result.next_player = Black
  result.nb_black_stones = 0
  result.ko_pos = -1
  newGroups[size](result.groups)

  for i, mstone in result.board.mpairs:
    # Set borders
    if  i < size+2 or             # first row
        i >= (size+1)*(size+2) or # last row
        i mod (size+2) == 0 or    # first column
        i mod (size+2) == size+1: # last column
      mstone = Border
      result.groups.metadata[i].reset_border
    else:
      mstone = Empty
      result.empty_points.incl i.int16

func `$`*[N: static[int]](board: Board[N]): string =
  # Display a go board

  # The go board as an extra border on the top, left, right and bottom
  # So a 19x19 board is actually 21x21 and the end of line is at the 20th position of each line

  # TODO requires int and not int8 otherwise `$` doesn't catch it: https://github.com/nim-lang/Nim/issues/7611

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


when isMainModule:
  echo "\n###### 9x9 board ######"
  echo $newBoardState(9)

  echo "\n###### 19x19 board ######"
  var a = newBoardState(19)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)
  echo toCoord("A1", 19)
  echo toCoord("B1", 19)
  echo toCoord("Q16", 19)
  echo toPoint[19](toCoord("A1", 19))
  echo toPoint[19](toCoord("B1", 19))
  echo toPoint[19](toCoord("Q16", 19))

