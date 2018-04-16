# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import macros, sequtils

# TODO: template or macro for (N.int16 + 2) * (N.int16 + 2)

type
  ################################ Coordinates ###################################

  # We index from 0
  Coord*[N: static[int8]] = tuple[col, row: range[0'i8 .. (N-1)]]
  Point*[N: static[int8]] = distinct range[-1'i16 .. (N.int16 + 2) * (N.int16 + 2) - 1]
    # Easily switch how to index for perf testing: native word size (int) vs cache locality (int16)
    # -1 is used for ko or group position: nil
    # TODO something more robust
    #  - object variant
    #  - options
    #  - separate in 2 types ValidPoints and Ko Points

    # Can't use plain static[int]: https://github.com/nim-lang/Nim/issues/7609

  ################################ Coordinates ###################################

  ################################ Color & Moves ###################################

  Intersection* = enum
    Empty, Black, White, Border # TODO, will having Empty = 0 or Black = 0 + White = 1 faster?
    # If memory/cache speed is a bottleneck, consider packing

  Player* = range[Black..White]

  MoveKind* = enum
    Play, Pass, Resign, Undo

  Move*[N: static[int8]] = object
    case kind*: MoveKind
    of Play:
      pos*: Point[N]
    else:
      discard

  PlayerMove*[N: static[int8]] = tuple[color: Player, move: Move[N]]

  ################################ Color & Moves ###################################

  ################################ Groups  ###################################

  GroupMetadata* = object
    # Graph theory. We use uint because we want the rollover on overflow.
    sum_square_degree_vertices*: uint32
    sum_degree_vertices*: uint16
    # Go Metadata (nb_stones acts as "rank" for disjoint sets "union by rank" optimization)
    nb_stones*: int16
    nb_pseudo_libs*: uint16
    color*: Intersection # TODO separate to improve alignment, and can be packed

  GroupID*[N: static[int8]] = distinct range[0'i16 .. (N.int16 + 2) * (N.int16 + 2) - 1]
    # Alias to prevent directly accessing group metadata
    # without getting the groupID first

  # GroupsMetaPool and GroupIDs form a disjoint sets with union by rank and path compression.
  # GroupsMetaPool is a memory pool and use as needed. TODO: find the upper bound on the number of groups.
  # Groups IDs is an array of "pointers" to the location of the group metadata in the pool.
  # NextStones allow efficient iteration as an array-backed LinkedRing (circular linkedlist).
  # Arrays are chosen to minimize cache misses and avoid allocations within Monte-Carlo playouts.

  # static[int8] can go beyond high(i8) for some reason
  # TODO: use distinct for proper type-checking: Pending borrowing for static
  #        https://github.com/nim-lang/Nim/issues/7552
  GroupsMetaPool*[N: static[int8]] = array[(N.int16 + 2) * (N.int16 + 2), GroupMetadata]
  GroupIDs*[N: static[int8]]       = array[(N.int16 + 2) * (N.int16 + 2), GroupID[N]]
  NextStones*[N: static[int8]]     = array[(N.int16 + 2) * (N.int16 + 2), Point[N]]

  Groups*[N: static[int8]] = object
    ## Groups Common Fate Graph. Represented as an array-based disjoint-set.
    ##
    # Groups is allocated on the heap as it is quite large (>2MB) and
    # See implementation notes at https://github.com/mratsim/golem-prime/issues/1
    metadata*: GroupsMetaPool[N]  # Contains the metadata of each groups
    id*: GroupIDs[N]              # map an input point to its group id in "groups".
    next_stones*: NextStones[N]   # next stone in the group, this is a linked ring (circular).

  ################################ Groups ###################################

  ################################ Board  ###################################

  Board*[N: static[int]] = array[(N + 2) * (N + 2), Intersection]
    # To ease boarder detection in algorithms, borders are also represented as an (invalid) intersection
    # We use a column-major representation i.e:
    #  - A2 <-> (0, 1) has index "1" adjusted for borders
    #  - B1 <-> (1, 0) has index "19" adjusted for borders on a 19x19 goban
    # This implies that iterating on the board should be `for col in cols: for row in rows`

    # TODO requires int and not int8 otherwise `$` doesn't catch it: https://github.com/nim-lang/Nim/issues/7611

  EmptyIdx*[N: static[int8]] = range[-1'i16 .. N.int16 * N.int16]

  EmptyPoints*[N: static[int8]] = object
    # We need a set/hashset with the following properties:
    #  - Can store up to ~500 elements at most (covered by `set` and `Hashset`)
    #  - Incl and Excl as fast as possible (in hot path) (covered by `set` and `Hashset`)
    #  - Can take the length without iterating (in hot path) (covered by `Hashset`, can use a int16 length field or popcount with `set`)
    #  - Can take a random value from the set as fast as possible (in hot path for Monte-Carlo simulations) (covered by ????)
    #  - Have access to the last inserted elements for ko checking

    # Implementation
    # - An array of indices that maps input -> -1 if not present in set or its index in an array of value present (allows incl/excl)
    # - An (array of values + length) present in the set (allows fast random pick).
    indices*: array[(N.int16 + 2) * (N.int16 + 2), EmptyIdx[N]]
    list*: array[N.int16 * N.int16, Point[N]]
    len*: int16

  BoardState*[N: static[int8]] = ref object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.

    # Order must be from biggest field to smallest to optimize space used/alignment
    groups*: Groups[N]             # Track the groups on board
    board*: Board[N]
    empty_points*: EmptyPoints[N]  # Keep track of empty intersections
    nb_black_stones*: int16        # With black stones and empty positions we can recompute white score
    ko_pos*: Point[N]              # Last ko position
    next_player*: Player

  GameState*[N: static[int8]] = object
    ## Metadata related to the game. Everything that is not copied
    ## uring Monte-Carlo playouts should be here
    board_state*: BoardState[N]
    prev_moves*: seq[PlayerMove[N]]
    komi*: float32
    # ruleset

  ################################ Board  ###################################

################################ Constants  ###################################

const MaxNbMoves* = 512
  # This is a soft limit on the max number of moves
  # It is extremely rare to exceed 400 moves, longest game recorded is 411 moves.
  # Yamabe Toshiro, 5p vs Hoshino Toshi 3p, Japan 1950

################################ Constants  ###################################

################################ Go common logic ###################################

func neighbors*[N: static[int8]](idx: Point[N]): array[4, Point[N]] {.inline.}=
  [Point[N] idx.int16 - 1, Point[N] idx.int16 + 1, Point[N] idx.int16 - (N+2), Point[N] idx.int16 + (N+2)]

const opponents: array[Player, Player] = [
  Black: Player White,
  White: Player Black]

func opponent*(color: Player): Player {.inline.} =
  opponents[color]

################################ Go common logic ###################################

################# Strongly checked indexers and iterators ##########################

template genIndexersN(Container, Idx, Value) =
  # TODO: Will be improved with borrowing for static:
  #       https://github.com/nim-lang/Nim/issues/7552

  func `[]`*[N: static[int8]](container: Container[N], idx: Idx[N]): Value[N] {.inline.} =
    container[idx.int16]

  func `[]`*[N: static[int8]](container: var Container[N], idx: Idx[N]): var Value[N] {.inline.} =
    container[idx.int16]

  func `[]=`*[N: static[int8]](container: var Container[N], idx: Idx[N], val: Value[N]){.inline.} =
    container[idx.int16]

template genIndexers(Container, Idx, Value) =
  # TODO: Will be improved with borrowing for static:
  #       https://github.com/nim-lang/Nim/issues/7552

  func `[]`*[N: static[int8]](container: Container[N], idx: Idx[N]): Value {.inline.} =
    container[idx.int16]

  func `[]`*[N: static[int8]](container: var Container[N], idx: Idx[N]): var Value {.inline.} =
    container[idx.int16]

  func `[]=`*[N: static[int8]](container: var Container[N], idx: Idx[N], val: Value){.inline.} =
    container[idx.int16] = val

genIndexers(GroupsMetaPool, GroupID, GroupMetadata)
genIndexersN(GroupIDs, Point, GroupID)
genIndexersN(NextStones, Point, Point)
genIndexers(Board, Point, Intersection)

func `==`*(val1, val2: Point or GroupID): bool = val1.int16 == val2.int16

################# Strongly checked indexers and iterators ##########################


when isMainModule:

  var a: EmptyPoints[19]
  echo a.sizeof
