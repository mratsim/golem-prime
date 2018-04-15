# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./datatypes,
  ./core/[c_boardstate, c_conversion, c_groups]

when isMainModule:
  echo "\n###### 9x9 board ######"
  echo $newBoardState(9'i8).board

  echo "\n###### 19x19 board ######"
  var a = newBoardState(19'i8)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of next player: " & $sizeof(a.next_player)
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo "\n###### Playing: 19x19 board ######"
  a.play(Black, pos("Q16", 19'i8))
  a.play(White, pos("A4", 19'i8))
  a.play(Black, pos("Q4", 19'i8))
  a.play(White, pos("B4", 19'i8))
  echo a.board

  echo a.group_id(pos("A4", 19'i8)).int16
  echo a.group(pos("A4", 19'i8))

  echo a.group_id(pos("B4", 19'i8)).int16
  echo a.group(pos("B4", 19'i8))

  echo "\n###### Capturing white ######"
  a.play(Black, pos("A3", 19'i8))
  a.play(Black, pos("B3", 19'i8))
  a.play(Black, pos("C4", 19'i8))
  a.play(Black, pos("B5", 19'i8))
  a.play(Black, pos("A5", 19'i8))

  echo a.board
