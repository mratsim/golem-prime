# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).


type
  Intersection* = enum
    Empty, Black, White, Border # TODO, will having Empty = 0 or Black = 0 + White = 1 faster?
    # If memory/cache speed is a bottleneck, consider packing

  Coord* = tuple[x, y: int8]

  MoveKind* = enum
    Play, Pass, Resign, Undo

  Move* = object
    case kind: MoveKind
    of Play:
      coord: Coord
    else:
      discard

  Board*[N: static[int]] = array[(N + 2) * (N + 2), Intersection]
    # To ease boarder detection in algorithms, boarders are also represented as an (invalid) intersection

  BoardState*[N: static[int]] = object
    ## Dynamic data related to the board
    # Only store what is essential for board evaluation as
    # trees of board state are generated thousands of time per second
    # during Monte-Carlo Tree Search.
    #
    # Size 450 Bytes - fits in 7.01 cache lines :/ (64B per cache lines - 7*64B = 448B)
    board: Board[N]
    next_player: range[Black..White]
    nb_stones: tuple[black, white: int16] # Depending on the ruleset we might need to track captures instead
    last_move: Move

  GameState*[N: static[int]] = object
    ## Besides the board state, immutable data related to the game
    board_state: BoardState[N]
    komi: float32
    # ruleset

when isMainModule:

  let a = BoardState[19](next_player: Black)
  #echo repr a

  echo "Size of Board + State: " & $sizeof(a)
  echo "Size of Board: " & $sizeof(a.board)
  echo "Size of Move: " & $sizeof(Move)
  echo "Size of Intersection: " & $sizeof(Intersection)

