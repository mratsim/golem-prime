# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes,
  ../core/core,
  ./h_filling_eye,
  random

# Random seed setting for reproducibility
# You can pass your own with:
const random_seed {.intdefine.} = 0
when random_seed == 0:
  randomize()
else:
  randomize random_seed

proc pick_idx[N: static[GoSint]](s: EmptyPoints[N]): EmptyIdx[N] {.inline.}=
  ## Generate a random move from a set of empty points
  ## Nim random uses Xoroshiro128+ PRNG which is very fast
  ## and produces high quality random numbers
  rand(0.GoSint .. GoSint(s.len-1))

func play*[N: static[GoSint]](self: BoardState[N], point: Point[N], player: Player) =
  ## Play a stone
  ## Move is assumed valid. Illegality should be checked beforehand

  let
    potential_ko = self.is_opponent_eye(point, player)
    prev_len_empty_points = self.empty_points.len

  self.merge_with_groups           point, player
  self.place_stone                 point, player
  self.remove_from_neighbors_libs  point
  self.capture_deads_around        point, player

  self.ko_pos = if potential_ko and prev_len_empty_points == self.empty_points.len:
                  self.empty_points.peek
                else: Point[N](-1)

func play*[N: static[GoSint]](self: BoardState[N], point: Point[N]) {.inline.}=
  self.play point, self.to_move

func surrounded_but_legal(self: BoardState, point: Point, player: Player): bool =
  # Check if playing a stone in a surrounded space is legal

  let opponent = player.opponent

  for neighbor in point.neighbors:
    # We track liberties of empty spaces.
    let neighbor_in_atari = self.group(neighbor).is_in_atari

    # 1. False eye in atari from opponent
    # 2. Dame: we connect to a friendly group with a liberty elsewhere
    if  ((self.board[neighbor] == opponent) and neighbor_in_atari) or
        ((self.board[neighbor] == player) and not neighbor_in_atari):
      return true
  return false

func is_legalish_move[N: static[GoSint]](self: BoardState[N], point: Point[N], player: Player): bool =
  ## Check if a move looks legal
  ## This does not check for superko for efficiency reason.
  ## They are very rare and we can just take the second best move
  ## if it comes to that.

  # Optimization note: "dont_fill_own_true_eye" and "surrounded_but_legal"
  # reloads the opponent player. It might be more efficient to store it here but:
  #   - Value is a small, and loaded from a constant array.
  #   - Opponent array is likely to be in cache
  #   - Memory latency can be hidden by a non-blocking load
  #   - One less parameter passed = 1 more register available
  #   - Benchmark is inconclusive

  assert point != Point[N](-1), "-1 is is not a real board position."
  assert self.board[point] == Empty, $point & " is already occupied by a " & $self.board[point] &
    " stone. This shouldn't happen."

  # 0. Rapid checks

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

  # 1. Basic heuristic (don't fill your own eye).
  #    Note: it is tuned to provide as less bias and blind spots
  #    as possible (i.e. if filling eye is a good move, it should be considered)

  if dont_fill_own_true_eye(self, point, player):
    return false

  # 2. Check out for illegal moves
  if surrounded_but_legal(self, point, player):
    return true

  return false # Opponent's true eye or filling the dame will suicide.

proc random_move*[N: static[GoSint]](self: BoardState[N], player: Player): Point[N] =

  assert self.empty_points.len > 0, "It seems like the whole board is completely full of stones, " &
    "not even eyes are left. Are you playing go?"

  let first_proposal = self.empty_points.pick_idx
  var candidate_idx = first_proposal

  while true:
    result = self.empty_points.list[candidate_idx]
    if self.is_legalish_move(result, player):
      return

    inc candidate_idx
    if candidate_idx == self.empty_points.len:
      # Roll-over if we reach max length
      candidate_idx = 0
    if candidate_idx == first_proposal:
      # Stop if we checked every candidate
      return Point[N](-1)

proc random_move*[N: static[GoSint]](self: BoardState[N]): Point[N] {.inline.}=
  self.random_move self.to_move
