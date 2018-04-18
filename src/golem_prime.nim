# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./datatypes,
  ./core/[c_boardstate, c_conversion, c_move]

# Note: Golem Prime accepts a random seed parameter for reproducibily.
#       Compile it with -d:random_seed=1234 to set the random seed to 1234
when defined(march_native):
  {.passC:"-march=native".}

when isMainModule:
  const Size: GoInt = 19

  # Sanity check: Position conversion
  doAssert $pos("D4", Size) == "D4"

  # Sanity check: Reset fully reset
  let a0 = newBoardState(Size)
  var a1 = newBoardState(Size)

  for _ in 0 ..< 100:
    let move = a1.random_move
    a1.play(move)
    a1.next_player()

  a1.reset()

  doAssert a0.groups.next_stones == a1.groups.next_stones
  doAssert a0.groups.id == a1.groups.id
  doAssert a0.groups.metadata == a1.groups.metadata
  doAssert a0.board == a1.board
  doAssert a0.empty_points == a1.empty_points
  doAssert a0.nb_black_stones == a1.nb_black_stones
  doAssert a0.ko_pos == a1.ko_pos
  doAssert a0.to_move == a1.to_move


when true and isMainModule:
  proc simulate[N: static[GoInt]](a: BoardState[N], simulation_id: int) =
    a.reset()

    # echo a.groups.repr

    var counter: int
    while a.empty_points.len > 0:

      # echo "\n\n#############"
      # echo &"Simulation.Iteration #{simulation_id}.{counter}"
      # echo a.board

      # echo "Player: " & $a.to_move

      let move = a.random_move
      if (move == Point[N](-1)):
        # echo "\n------------------"
        # echo "No legal move left!"
        break

      # echo "Next move: " & $move
      # echo "Empty set: " & $a.empty_points
      # echo "Empty set len: " & $a.empty_points.len

      a.play(move)
      a.next_player()

      inc counter
      if counter >= 500:
        break

  echo "\n###### Board ######"
  var a = newBoardState(Size)
  echo a.board

  echo "\n###### Random simulations ######"
  import times, os, strutils, strformat

  let arguments = commandLineParams()
  let nb_iter = if arguments.len > 0: parseInt($arguments[0])
                else: 1

  let start = cpuTime()
  for i in 0 ..< nb_iter:
    a.simulate(i)
    # echo a.board
  let stop = cpuTIme()

  let elapsed = stop - start
  echo &"Took {elapsed}s for {nb_iter} simulations: {(nb_iter.float / (1000 * elapsed)):3} kpps (K playouts/s)"

  # Bench: about 16.5 kpps on a i5-5257U mobile dual core (Broadwell 2.7 Ghz, turbo 3.1)
  # 19x19  with int32 base type.
  #        Note: this is without scoring and MCTS, just naive random playouts

  # Bench: about 58 kpps on a i5-5257U mobile dual core (2.7 Ghz, turbo 3.1)
  #   9x9  with int32 base type
  #        Note: this is without scoring and MCTS, just naive random playouts

when false and isMainModule:
  const N: GoInt = 19
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
  echo "Size of Move: " & $sizeof(Move[N])
  echo "Size of Intersection: " & $sizeof(Intersection)

  echo "\n###### Playing: 19x19 board ######"
  a.play pos("Q16", N); a.next_player
  a.play pos("A4", N) ; a.next_player
  a.play pos("Q4", N) ; a.next_player
  a.play pos("B4", N) ; a.next_player
  echo a.board

  echo "\n###### Capturing white ######"
  a.play pos("A3", N), Black
  a.play pos("B3", N), Black
  a.play pos("C4", N), Black
  a.play pos("B5", N), Black
  a.play pos("A5", N), Black

  echo a.board
