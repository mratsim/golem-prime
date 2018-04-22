# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

# Implement Zobrist hashing: https://en.wikipedia.org/wiki/Zobrist_hashing

import
  ../mc_datatypes, ../datatypes, ../global_config,
  random

const Mbs = Max_Board_Size

func seedZobrist(): array[(Mbs+2)*(Mbs+2), array[Player, Zobrist]] =
  ## Create a Zobrist seed board
  ## for Zobrist initial values.
  ## Can be used at compile-time.

  var rng = initRand(0x1337DEEDBEAF) # Completely arbitrary random seed
  # Note: here we use an independant random state from the Monte-Carlo one.

  # Usually plays are near each other so we maximize cache loads by keeping
  # positions near each other and interleaving players' seed Zobrist.
  for position in 0 ..< (Mbs+2)*(Mbs+2):
    for player in Black..White:
      result[position][player] = rng.rand(high(int)) # TODO: we should seed with negative values as well

const SeedZobrist = seedZobrist()

func hash*[N: static[GoInt]](board: Board[N]): Zobrist =

  static: assert N <= Max_Board_Size, "The max board size supported is " & $Max_Board_Size &
                                      ". Please change it in the global_config and recompile."

  for pos in 0 ..< (N+2)*(N+2):
    let player = board[pos]
    if player in {Black, White}:
      result = result xor SeedZobrist[pos][player]

func mix*[N: static[GoInt]](h: Zobrist, pos: Point[N], player: Player): Zobrist {.inline.}=
  h xor SeedZobrist[pos][player]
