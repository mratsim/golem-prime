# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./datatypes,
  ./core/[c_boardstate, c_conversion, c_move]

# Note: Golem Prime accepts a random seed parameter for reproducibily.
#       Compile it with -d:random_seed=1234 to set the random seed to 1234


when isMainModule:
  # Sanity check:
  doAssert $pos("D4", 19'i8) == "D4"

when isMainModule:
  const N: int8 = 9
  echo "\n###### board ######"
  var a = newBoardState(N)
  echo a.board

  echo "\n###### Random simulations ######"

  var count: int
  while a.empty_points.len > 0:

    echo "\n\n#############"
    echo "Iteration #" & $count
    echo a.board

    echo "Player: " & $a.next_player

    let move = a.random_move
    if move == Point[N](-1):
      echo "No legal move left!"
      break

    echo "Next move: " & $move
    echo "Empty set: " & $a.empty_points
    echo "Empty set len: " & $a.empty_points.len

    a.play(move)
    a.next_player = a.next_player.opponent
    inc count

  echo a.board


when false and isMainModule:
  const N: int8 = 9
  var a = newBoardState(N)

  echo "\nSize of BoardState on the stack: " & $sizeof(a)
  var total_size: int
  echo "BoardState field sizes"
  for name, value in a[].fieldPairs:
    echo "Size of " & $name & ": " & $sizeof(value)
    total_size += sizeof(value)
  echo "total fields size (alignment padding ignored): " & $total_size
  echo "total cache lines: " & $(total_size.float / 64.0f)

  echo "\nMisc sizes"
  echo "Size of Move: " & $sizeof(Move[19])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo "\n###### Playing: 19x19 board ######"
  a.play(Black, pos("Q16", 19'i8))
  a.play(White, pos("A4", 19'i8))
  a.play(Black, pos("Q4", 19'i8))
  a.play(White, pos("B4", 19'i8))
  echo a.board

  echo "\n A4"
  let A4 = pos("A4", 19'i8)
  echo a.group_id(A4).int16
  echo a.group(A4)
  echo "next A4: " & $a.group_next(A4)

  echo "\n B4"
  let B4 = pos("B4", 19'i8)
  echo a.group_id(B4).int16
  echo a.group(B4)
  echo "next B4: " & $a.group_next(B4)

  echo "\n Group"
  for stone in groupof(a.groups, A4):
    echo $stone

  echo "\n###### Capturing white ######"
  a.play(Black, pos("A3", 19'i8))
  a.play(Black, pos("B3", 19'i8))
  a.play(Black, pos("C4", 19'i8))
  a.play(Black, pos("B5", 19'i8))
  a.play(Black, pos("A5", 19'i8))
