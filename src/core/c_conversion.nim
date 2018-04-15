# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  strutils,
  ../datatypes

################################ Coordinates ###################################

func toCoord*(coordStr: string, board_size: static[int8]): Coord[board_size] =

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

func toPoint*[N: static[int8]](coord: Coord[N]): Point[N] {.inline.}=
  ## Convert a tuple of coordinate to index representation adjusted for borders
  # We use a column-major representation i.e:
  #  - A2 <-> (0, 1) has index "1" adjusted for borders
  #  - B1 <-> (1, 0) has index "19" adjusted for borders on a 19x19 goban
  # This implies that iterating on the board should be `for col in cols: for row in rows`

  # TODO, proc/func requires the N as input at the moment.

  int16(coord.col + 1) * int16(N + 2) + coord.row.int16 + 1

################################ Display ###################################

const stone_display: array[Intersection, char] = [
  Empty: '.',
  Black: 'X',
  White: 'O',
  Border: ' ']

func toChar*(intersection: Intersection): char {.inline.}=
  stone_display[intersection]

func `$`*[N: static[int]](board: Board[N]): string =
  # Display a go board

  # The go board as an extra border on the top, left, right and bottom
  # So a 19x19 board is actually 21x21 and the end of line is at the 20th position of each line

  # TODO requires int and not int8 otherwise `$` doesn't catch it: https://github.com/nim-lang/Nim/issues/7611

  result = ""

  for i, stone in board:
    result.add stone.toChar
    if i mod (N+2) == N+1: # Test if we reach end of line
      result.add '\n'
