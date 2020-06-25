# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  hashes, metab,
  ../datatypes

type
  Zobrist* = Hash

  PosHash*[N: static GoSint] = tuple[position: Point[N], hash: Zobrist]

  Node*[N: static GoSint] = object
    ## A DAG node
    children*: seq[PosHash[N]]
    parents*: seq[Zobrist]

    nbPlays*: GoUint
    nbWins*: GoUint
    nbRavePlays*: GoUint # Rapid Value Estimation plays
    nbRaveWins*: GoUint  # Rapid Value Estimation wins

    toPlay*: Player # TODO is it needed

  DAG*[N: static GoSint] = Tab[Zobrist, Node[N]]
    ## The Monte-Carlo "Tree", which is a DAG
    ## because 2 sequences of moves can lead to the same position
    ## N is the board size

  MCTS_Context*[N: static GoSint] = object
    dag*: DAG[N]
    doubleKomi*: GoSint

const
  NodePrior*: GoSint = 10
  ExpansionThreshold*: GoSint = 8 + NodePrior
  UctC*: float32 = 1.4
  RaveC*: float32 = 0
  RaveEquiv*: float32 = 3500
  MaxNbMoves* = 512
  PreallocatedSize* = 1 shl 17 # 2^16 is 65k elements
  # This is a soft limit on the max number of moves
  # It is extremely rare to exceed 400 moves, longest game recorded is 411 moves.
  # Yamabe Toshiro, 5p vs Hoshino Toshi 3p, Japan 1950
