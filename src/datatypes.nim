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
  Intersection* = enum
    Empty, Black, White, Border # TODO, will having Empty = 0 or Black = 0 + White = 1 faster?
    # If memory/cache speed is a bottleneck, consider packing

  Player* = range[Black..White]

  # We index from 0
  Coord*[N: static[int8]] = tuple[col, row: range[0'i8 .. (N-1)]]
  Point*[N: static[int16]] = range[-1'i16 .. (N + 2) * (N + 2) - 1]  # Easily switch how to index for perf testing: native word size (int) vs cache locality (int16)
    # -1 is used for ko or group position: nil
    # TODO something more robust
    #  - object variant
    #  - options
    #  - separate in 2 types ValidPoints and Ko Points

  MoveKind* = enum
    Play, Pass, Resign, Undo

  Move*[N: static[int16]] = object
    case kind*: MoveKind
    of Play:
      pos*: Point[N]
    else:
      discard

  PlayerMove*[N: static[int16]] = tuple[color: Player, move: Move[N]]

  Group* = object
    color*: Intersection
    nb_stones*: int16
    nb_pseudo_libs*: int16
    # Graph theory
    sum_degree_vertices*: int16
    sum_square_degree_vertices*: int32

  GroupsGraph*[N: static[int16]] = object
    # Groups Common Fate Graph.
    #
    # This avoid recurring floodfill calls to determine which group a stone is part of.
    # Floodfill was a huge bottleneck in my previous bot.
    #
    # However it it heap-allocated and so requires preallocation before multithreading/for loops
    #
    # Note: Graphs are often represented with LinkedLists, something like array[N^2, ref (Group, LinkedList[Point])]
    #       would work to map each Point with its group and a LinkedList of adjacent points
    #       but that would allocate during Monte-Carlo playouts and mem allocations are costly.
    #       Also each thread has it's own heap but not sure how well multithreaded GC works
    groups*: seq[Group]        # Contains the list of groups
    group_id*: seq[Point[N]]   # map an input point to its group id in "groups".
    group_next*: seq[Point[N]] # next stone in the group (similar to SinglyLinkedRing)

  Board*[N: static[int]] = array[(N + 2) * (N + 2), Intersection]
    # To ease boarder detection in algorithms, boarders are also represented as an (invalid) intersection

  EmptyPoints*[N: static[int16]] = object
    # data: set_of_points(N) # Broken https://github.com/nim-lang/Nim/issues/7547
    data*: set[-1 .. (19+2)*(19+2) - 1] # Hardcoded as workaround
    len*: int16 # sets have a card(inality) proc but it is not O(1), it traverse both set and unset values

  BoardState*[N: static[int16]] = object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.
    #
    # Size 450 Bytes - fits in 7.01 cache lines :/ (64B per cache lines - 7*64B = 448B)
    board*: Board[N]
    next_player*: Player
    prev_moves*: seq[PlayerMove[N]]

    # With black stones and empty positions we can recompute white score
    nb_black_stones*: int16        # Depending on the ruleset we might need to track captures instead
    empty_points*: EmptyPoints[N]  # Keep track of empty intersections

    ko_pos*: Point[N]              # Last ko position
    groups_graph*: GroupsGraph[N]  # Track the groups on board (Common Fate Graph)


  GameState*[N: static[int16]] = object
    ## Besides the board state, immutable data related to the game
    board_state*: BoardState[N]
    komi*: float32
    # ruleset

const MaxNbMoves* = 512
  # This is a soft limit on the max number of moves
  # It is extremely rare to exceed 400 moves, longest game recorded is 411 moves.
  # Yamabe Toshiro, 5p vs Hoshino Toshi 3p, Japan 1950

when isMainModule:

  var a: EmptyPoints[19]
  echo a.sizeof
