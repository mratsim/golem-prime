# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  strutils,
  ../datatypes

func toCoord*(coordStr: string, board_size: static[int8]): Coord[board_size]  {.inline.} =

  # Constraints
  #   - No space in input
  #   - board size 25 at most
  #   - square board
  #   - input of length 2 or 3 like A1 and Q16
  #   - input in uppercase
  assert coordStr.len <= 3
  const cols = " ABCDEFGHJKLMNOPQRSTUVWXYZ "

  result.col = cols.find(coordStr[0]) - 1
  result.row = coordStr[1 .. coordStr.high].parseInt - 1

func toPoint*[N: static[int8]](coord: Coord[N]): Point[N] =
  ## Convert a tuple of coordinate to index representation adjusted for borders
  # We use a column-major representation i.e:
  #  - A2 <-> (0, 1) has index "1" adjusted for borders
  #  - B1 <-> (1, 0) has index "19" adjusted for borders on a 19x19 goban
  # This implies that iterating on the board should be `for col in cols: for row in rows`

  # TODO, proc/func requires the N as input at the moment.

  int16(coord.col + 1) * int16(N + 2) + coord.row.int16 + 1

proc neighbors*[N: static[int8]](idx: Point[N]): array[4, Point[N]] {.inline.}=
  [idx-1, idx+1, idx - (N+2), idx + (N+2)]
