# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes, ./c_boardstate, ./c_empty_points,
  random

# Random seed setting for reproducibility
# You can pass your own with:
const random_seed {.intdefine.} = 0
when random_seed == 0:
  randomize()
else:
  randomize random_seed

proc rand*[N: static[int8]](s: EmptyPoints[N]): Point[N] {.inline.}=
  ## Generate a random move from a set of empty points
  ## Nim random uses Xoroshiro128+ PRNG which is very fast
  ## and produces high quality random numbers
  s.list[rand(0'i16 .. s.len-1)]

func play*[N: static[int8]](self: BoardState[N], color: Player, point: Point[N]) =
  ## Play a stone
  ## Move is assumed valid. Illegality should be checked beforehand

  let
    potential_ko = self.is_opponent_eye(color, point)
    prev_len_empty_points = self.empty_points.len

  self.merge_with_groups(color, point)
  self.place_stone(color, point)
  self.remove_from_neighbors_libs(point)
  self.capture_deads_around(color, point)

  self.ko_pos = if potential_ko and prev_len_empty_points == self.empty_points.len:
                  self.empty_points.peek
                else: Point[N](-1)

# func is_legalish_move(self: BoardState, point: Point): bool =
#   ## Check if a move looks legal
#   ## This does not check for superko for efficiency reason.
#   ## They are very rare and we can just take the second best move
#   ## if it comes to that.

#   assert self.board[point] == Empty, $point & " is already occupied by a " & $self.board[point] &
#     " stone. This shouldn't happen."
