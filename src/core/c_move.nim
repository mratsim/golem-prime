# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes, ../debug, ./c_boardstate, ./c_empty_points, ./c_groups,
  random

# Random seed setting for reproducibility
# You can pass your own with:
const random_seed {.intdefine.} = 0
when random_seed == 0:
  randomize()
else:
  randomize random_seed

proc pick_idx[N: static[int8]](s: EmptyPoints[N]): EmptyIdx[N] {.inline.}=
  ## Generate a random move from a set of empty points
  ## Nim random uses Xoroshiro128+ PRNG which is very fast
  ## and produces high quality random numbers
  rand(0'i16 .. s.len-1)

func play*[N: static[int8]](self: BoardState[N], point: Point[N], color: Player) =
  ## Play a stone
  ## Move is assumed valid. Illegality should be checked beforehand

  let
    potential_ko = self.is_opponent_eye(color, point)
    prev_len_empty_points = self.empty_points.len

  self.merge_with_groups           color, point
  debugonly:
    debugecho "-----------------------"
    debug     "\n Before play at:"
  self.place_stone                 color, point
  self.remove_from_neighbors_libs         point
  debugonly:
    debug "\n After play at:"
  self.capture_deads_around        color, point
  debugonly:
    debug "\n After play & capture at:"

  self.ko_pos = if potential_ko and prev_len_empty_points == self.empty_points.len:
                  self.empty_points.peek
                else: Point[N](-1)

func play*[N: static[int8]](self: BoardState[N], point: Point[N]) {.inline.}=
  self.play point, self.to_move

func is_legalish_move[N: static[int8]](self: BoardState[N], point: Point[N], color: Player): bool =
  ## Check if a move looks legal
  ## This does not check for superko for efficiency reason.
  ## They are very rare and we can just take the second best move
  ## if it comes to that.

  assert point != Point[N](-1), "-1 is is not a real board position."

  assert self.board[point] == Empty, $point & " is already occupied by a " & $self.board[point] &
    " stone. This shouldn't happen."

  if point == self.ko_pos:
    return false

  # We track liberties even for empty points to detect eyes without actually playing
  # A play is "always" valid if there are liberties. (Besides superko)
  if self.group(point).nb_pseudo_libs > 0:
    return true

  # Now we deal with spaces with no apparent liberties
  # We either have 5 cases:
  #   - true/false eyes from player/opponent
  #   - a dame point.
  # We only need to prevent:
  #   - playing in an eye with no enemy stone in atari.
  #   - suicide (dame/false eye was the last liberty of a group)

  let color_opponent = color.opponent

  for neighbor in point.neighbors:

    # We track liberties of empty spaces.
    let neighbor_in_atari = self.group(neighbor).is_in_atari

    # 1. False eye in atari from opponent
    # 2. Dame: we connect to a friendly group with a liberty elsewhere
    if  ((self.board[neighbor] == color_opponent) and neighbor_in_atari) or
        ((self.board[neighbor] == color) and not neighbor_in_atari):
      return true
  return false # Opponent's true eye or filling the dame will suicide.

func is_legalish_move[N: static[int8]](self: BoardState[N], point: Point[N]) {.inline.}=
  self.is_legalish_move point self.to_move

proc random_move*[N: static[int8]](self: BoardState[N], color: Player): Point[N] =

  assert self.empty_points.len > 0, "It seems like the whole board is completely full of stones, " &
    "not even eyes are left. Are you playing go?"

  let first_proposal = self.empty_points.pick_idx
  var candidate_idx = first_proposal

  while true:
    result = self.empty_points.list[candidate_idx]
    if self.is_legalish_move(result, color):
      return

    inc candidate_idx
    if candidate_idx == self.empty_points.len:
      # Roll-over if we reach max length
      candidate_idx = 0
    if candidate_idx == first_proposal:
      # Stop if we checked every candidate
      return Point[N](-1)

proc random_move*[N: static[int8]](self: BoardState[N]): Point[N] {.inline.}=
  self.random_move self.to_move
