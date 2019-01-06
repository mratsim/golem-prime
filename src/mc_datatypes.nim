# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  hashes, tables,
  ./datatypes

type
  Zobrist* = Hash

  PosHash*[N: static[GoInt]] = tuple[position: Point[N], hash: Zobrist]

  Node*[N: static[GoInt]] = object
    children*: seq[PosHash[N]]
    parents*: seq[Zobrist]

    nb_plays*: GoNatural2
    nb_wins*: GoNatural2
    nb_rave_plays*: GoNatural2
    nb_rave_wins*: GoNatural2

    to_play*: Player # TODO is it needed

  NodeTable*[N: static[GoInt]] = Table[Zobrist, Node[N]]

  MCTS_Context*[N: static[GoInt]] = object
    nodes*: NodeTable[N]
    double_komi*: GoNatural

const
  NodePrior*: GoNatural = 10
  ExpansionThreshold*: GoNatural = 8 + NodePrior
  UctC*: float32 = 1.4
  RaveC*: float32 = 0
  RaveEquiv*: float32 = 3500
  MaxNbMoves* = 512
  PreallocatedSize* = 1 shl 17 # 2^16 is 65k elements
  # This is a soft limit on the max number of moves
  # It is extremely rare to exceed 400 moves, longest game recorded is 411 moves.
  # Yamabe Toshiro, 5p vs Hoshino Toshi 3p, Japan 1950
