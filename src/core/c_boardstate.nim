# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./c_empty_points, ./c_groups,
  ../datatypes

{.this: self.} # TODO: this does not work with static - https://github.com/nim-lang/Nim/issues/7618

########## Iteration and group accessors ##########
# Those operations are done at the board level to avoid double indirection
# when checking the color of the neighboring stones.

func group_id[N: static[int8]](self: BoardState[N], point: Point[N]): var GroupID[N] {.inline.}=
  self.groups.id[point]

func group*(self: BoardState, point: Point): var GroupMetadata {.inline.}=
  self.groups.metadata[self.groups.id[point]]

func group_next[N: static[int8]](self: BoardState[N], point: Point[N]): var Point[N] {.inline.}=
  self.groups.next_stones[point]

########## Group liberties ##########
import sequtils
func add_neighboring_libs(self: BoardState, point: Point) =
  ## Update groups metadata with liberties adjacent from a point
  for neighbor in point.neighbors:
    {.unroll: 4.}
    if self.board[neighbor] == Empty:
      self.group(point).add_as_lib neighbor

func remove_from_neighbors_libs*(self: BoardState, point: Point) =
  ## Remove a point from neighboring groups liberties
  for neighbor in point.neighbors:
    {.unroll: 4.}
    self.group(neighbor).remove_from_lib point

########## Initialization ##########

func singleton[N: static[int8]](self: BoardState[N], color: range[Empty..White], point: Point[N]) =
  ## Create a new group from a single stone
  ## Empty intersections also form a singleton group

  self.group_id(point) = GroupID[N](point)
  self.group_next(point) = point

  self.group(point).reset_meta()
  debug_only:
    self.group(point).color = color
  inc self.group(point).nb_stones

  self.add_neighboring_libs point

func reset*[N: static[int8]](self: BoardState[N]) =
  ## Reset the board state without reallocating
  ## and triggering the GC

  self.to_move = Black
  self.nb_black_stones = 0
  self.ko_pos = Point[N](-1)

  self.groups.reset_members()
  self.empty_points = EmptyPoints[N]()

  for i, mstone in self.board.mpairs:
    # Set borders
    if  i < N+2 or             # first row
        i >= (N+1)*(N+2) or    # last row
        i mod (N+2) == 0 or    # first column
        i mod (N+2) == N+1:    # last column
      mstone = Border
      self.groups.metadata[GroupID[N] i].reset_border()
      self.empty_points.reset_border Point[N](i)
    else:
      mstone = Empty
      self.groups.metadata[GroupID[N] i].reset_meta()
      self.empty_points.reset_empty Point[N](i)

  # To ease testing if a move is legal, even empty positions
  # have liberties.
  for idx, stone in self.board:
    if stone == Empty:
      self.add_neighboring_libs Point[N](idx)

func newBoardState*(size: static[int8]): BoardState[size] {.inline.} =
  new result
  result.reset()

########## Board operations on stones ##########

proc place_stone*(self: BoardState, color: Player, point: Point) {.inline.}=
  ## Place a stone at a specified position
  ## This only updates board state metadata
  ## And does not trigger groups/stones related life & death computation

  assert self.board[point] == Empty, "Error: position " & $point &
    " is currently occupied by " & $self.board[point]

  self.empty_points.excl point
  if color == Black:
    inc self.nb_black_stones

  self.board[point] = color

proc remove_stone(self: BoardState, point: Point) {.inline.}=
  ## Remove a stone at a specified position
  ## This only updates board state metadata
  ## And does not trigger groups/stones related life & death computation

  assert self.board[point] notin {Empty, Border}

  self.empty_points.incl point
  if self.board[point] == Black:
    dec self.nb_black_stones

  self.board[point] = Empty
  self.singleton Empty, point

func is_opponent_eye*(self: BoardState, color: Player, point: Point): bool =
  ## Returns true if a stone would be in the opponent eye.
  for neighbor in point.neighbors:
    {.unroll: 4.}
    let color_neighbor = self.board[neighbor]
    if color_neighbor in {Intersection color, Empty}:
      return false
  return true

########## Merging/killing dragons ##########

func add_to_group(self: BoardState, point, group_repr: Point) =
  ## Add a point to the same group as a representative

  self.group_id(point) = self.group_id(group_repr)
  # Insert the point to the group list (i.e. swap)
  self.group_next(point) = self.group_next(group_repr)
  self.group_next(group_repr) = point

  inc self.group(point).nb_stones

  self.add_neighboring_libs point

func merge_with_groups*(self: BoardState, color: Player, point: Point) =
  ## Merge a new stone with surrounding stones of the same color.
  ## Create a new group if it is standalone

  # We use an "union-by-rank" algorithm, merging the smallest groups into the biggest.
  var
    max_nb_stones: int16
    max_neighbor: Point

  for neighbor in point.neighbors:
    {.unroll: 4.}
    if self.board[neighbor] == color:
      let neighbor_stones = self.group(neighbor).nb_stones
      if neighbor_stones > max_nb_stones:
        # Note, contrary to union-by-rank, we don't special case when both groups have the same
        # number of stones as we apply path compression right away
        max_nb_stones = neighbor_stones
        max_neighbor  = neighbor

  # If there is no friendly group, create a singleton group and return
  if max_nb_stones == 0:
    self.singleton(color, point)
    return

  let max_group_id = self.group_id(max_neighbor)

  # If there are 2 groups or more of the same color that become connected
  for neighbor in point.neighbors:
    {.unroll: 4.} # TODO when unroll pragma is effective check code N and cache effect.
    let group_neighbor = self.group_id(neighbor)
    if self.board[neighbor] == color and group_neighbor != max_group_id:

      # Merge the metadata
      self.groups.metadata.merge(max_group_id, group_neighbor)

      # Path compression: rattach all stones from smallest group to the bigger group
      for stone in self.groups.groupof(neighbor):
        self.group_id(stone) = max_group_id

      # Concatenate the linked rings listing stones in each group.
      self.groups.next_stones.concat(max_neighbor, neighbor)

  # Now add the new stone to the adjacent group or merged group
  self.add_to_group(point, max_neighbor)

func remove_group(self: BoardState, point: Point) =
  ## Remove the group input point is part of

  let removed_group = self.group_id(point)

  for stone in self.groups.groupof(point):
    self.remove_stone stone

    # Update liberties of neighboring groups
    for neighbor in stone.neighbors:
      if (group_id(self, neighbor) != removed_group) or self.board[neighbor] == Empty:
        self.group(neighbor).add_as_lib stone

func capture_deads_around*(self: BoardState, color: Player, point: Point) =
  ## Capture dead group around a stone

  let color_opponent = color.opponent
  for neighbor in point.neighbors:
    if self.board[neighbor] == color_opponent and self.group(neighbor).isDead:
      self.remove_group neighbor
