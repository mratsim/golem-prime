# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import macros

### Hardcoded
# macro set_of_points*(size: static[int]): untyped =
#   ## Workaround to set raising "ordinal type expected"
#   ## when used with static[int]: https://github.com/nim-lang/Nim/issues/7546

#   # Returns set[ -1'i16 .. (N+2)^2 - 1]

#   var nodeStartRange = newNimNode(nnkInt16Lit)
#   nodeStartRange.intVal = -1

#   var nodeEndRange = newNimNode(nnkInt16Lit)
#   nodeEndRange.intVal = (size+2) * (size+2) - 1

#   result = nnkBracketExpr.newTree(
#     newIdentNode("set"),
#     nnkInfix.newTree(
#       newIdentNode(".."),
#       nodeStartRange,
#       nodeEndRange
#     )
#   )

type

  ################################ Coordinates ###################################

  # We index from 0
  Coord*[N: static[int8]] = tuple[col, row: range[0'i8 .. (N-1)]]
  Point*[N: static[int8]] = range[-1'i16 .. (N.int16 + 2) * (N.int16 + 2) - 1]  # Easily switch how to index for perf testing: native word size (int) vs cache locality (int16)
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
    # Graph theory
    sum_square_degree_vertices*: int32
    sum_degree_vertices*: int16
    # Go Metadata (nb_stones acts as "rank" for disjoint sets "union by rank" optimization)
    nb_stones*: int16
    nb_pseudo_libs*: int16
    color*: Intersection # TODO separate to improve alignment, and can be packed

  GroupID*[N: static[int8]] = distinct Point[N]   # Aliases to make sure we don't use the wrong Point/index
  NextStone*[N: static[int8]] = distinct Point[N] # in the wrong places unintentionally

  # GroupsMetaPool and GroupIDs form a disjoint sets with union by rank and path compression.
  # GroupsMetaPool is a memory pool and use as needed. TODO: find the upper bound on the number of groups.
  # Groups IDs is an array of "pointers" to the location of the group metadata in the pool.
  # NextStones allow efficient iteration as an array-backed LinkedRing (circular linkedlist).
  # Arrays are chosen to minimize cache misses and avoid allocations within Monte-Carlo playouts.
  GroupsMetaPool*[N: static[int8]] = array[(N + 2) * (N + 2), GroupMetadata]
  GroupIDs*[N: static[int8]] = array[(N + 2) * (N + 2), GroupID[N]]
  NextStones*[N: static[int8]] = array[(N + 2) * (N + 2), NextStone[N]]

  Groups*[N: static[int8]] = ref object
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

  EmptyPoints*[N: static[int8]] = object
    # data: set_of_points(N) # Broken https://github.com/nim-lang/Nim/issues/7547
    data*: set[-1 .. (19+2)*(19+2) - 1] # Hardcoded as workaround
    len*: int16 # sets have a card(inality) proc but it is not O(1), it traverse both set and unset values

  BoardState*[N: static[int8]] = object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.
    #
    # Size 450 Bytes - fits in 7.01 cache lines :/ (64B per cache lines - 7*64B = 448B)
    board*: Board[N]
    next_player*: Player

    # With black stones and empty positions we can recompute white score
    nb_black_stones*: int16        # Depending on the ruleset we might need to track captures instead
    empty_points*: EmptyPoints[N]  # Keep track of empty intersections

    ko_pos*: Point[N]              # Last ko position
    groups*: Groups[N]             # Track the groups on board


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
  [idx-1, idx+1, idx - (N+2), idx + (N+2)]

const opponents: array[Player, Player] = [
  Black: Player White,
  White: Player Black]

func opponent*(color: Player): Player {.inline.} =
  opponents[color]

################################ Go common logic ###################################

when isMainModule:

  var a: EmptyPoints[19]
  echo a.sizeof
