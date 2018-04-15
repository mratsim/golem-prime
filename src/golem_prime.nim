# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./datatypes,
  ./core/[c_boardstate, c_conversion]

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
