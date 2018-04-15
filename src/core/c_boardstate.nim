# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ./c_empty_points, ./c_groups,
  ../datatypes

func newBoardState*(size: static[int8]): BoardState[size] {.noInit.} =

  result.next_player = Black
  result.nb_black_stones = 0
  result.ko_pos = -1
  newGroups[size](result.groups)

  for i, mstone in result.board.mpairs:
    # Set borders
    if  i < size+2 or             # first row
        i >= (size+1)*(size+2) or # last row
        i mod (size+2) == 0 or    # first column
        i mod (size+2) == size+1: # last column
      mstone = Border
      result.groups.metadata[i].reset_border
    else:
      mstone = Empty
      result.empty_points.incl i.int16

{.this:self.}
proc place_stone*(self: var BoardState, color: Player, point: Point) {.inline.}=
  ## Place a stone at a specified position
  ## This only updates board state metadata
  ## And does not trigger groups/stones related life & death computation

  assert board[point] == Empty

  self.empty_points.excl point
  if color == Black:
    inc self.nb_black_stones

  self.board[point] = color

proc remove_stone*(self: var BoardState, point: Point) {.inline.}=
  ## Remove a stone at a specified position
  ## This only updates board state metadata
  ## And does not trigger groups/stones related life & death computation

  assert board[point] != Empty and board[point] != Border

  self.empty_points.incl point
  if self.board[point] == Black:
    dec self.nb_black_stones

  self.board[point] = Empty


########## Board operations on groups ##########
# Those operations are done at the board level to avoid double indirection
# when checking the color of the neighboring stones,
# it would require metadata[id[point]] otherwise

func group_id*(self: var BoardState, point: Point): var GroupID {.inline.}=
  self.groups.id[point]

func group*(self: var BoardState, point: Point): var GroupMetadata {.inline.}=
  self.groups.metadata[self.groups.id[point]]

func group_next*(self: BoardState, point: Point): NextStone {.inline.}=
  self.groups.next_stones[point]

func group_next*(self: var BoardState, point: Point): var NextStone {.inline.}=
  self.groups.next_stones[point]

func add_neighboring_libs(self: var BoardState, point: Point) =
  ## Update groups metadata with liberties adjacent from a point
  for neighbor in point.neighbors:
    {.unroll: 4.}
    if self.board[neighbor] == Empty:
      group[point].add_as_lib neighbor

func remove_from_neighbors_libs(self: var BoardState, point: Point) =
  ## Remove a point from neighboring groups liberties
  for neighbor in point.neighbors:
    {.unroll: 4.}
    group(neighbor).remove_from_lib point

func singleton(self: var BoardState, color: Player, point: Point) =
  ## Create a new group from a single stone

  group_id[point] = point
  group_next[point] = point

  group[point].reset()
  group[point].color = color
  inc group[point].nb_stones

  add_neighboring_libs point

func add_to_group(self: var BoardState, point, group_repr: Point) =
  ## Add a point to the same group as a representative

  group_id[point] = group_id[group_repr]
  # Insert the point to the group list (i.e. swap)
  group_next[point] = group_next[group_repr]
  group_next[group_repr] = point

  inc group[point].nb_stones

  add_neighboring_libs point

func merge_with_groups*(self: var BoardState, color: Player, point: Point) =
  ## Merge a new stone with surrounding stones of the same color.
  ## Create a new group if it is standalone

  # We use an "union-by-rank" algorithm, merging the smallest groups into the biggest.
  var max_nb_stones, max_neighbor: int16

  for neighbor in point.neighbors:
    {.unroll: 4.}
    let neighbor_stones = group[neighbor].nb_stones
    if self.board[neighbor] == color and neighbor_stones > max_nb_stones:
      # Note, contrary to union-by-rank, we don't special case when both groups have the same
      # number of stones as we apply path compression right away
      max_nb_stones = neighbor_stones
      max_neighbor  = neighbor

  # If there is no friendly group, create a singleton group and return
  if max_nb_stones == 0:
    singleton(color, point)
    return

  let max_group_id = group_id(max_neighbor)

  # If there are 2 groups or more of the same color that become connected
  for neighbor in point.neighbors:
    {.unroll: 4.} # TODO when unroll pragma is effective check code size and cache effect.
    if self.board[neighbor] == color and neighbor != max_neighbor:

      # Merge the metadata
      self.groups.metadata.merge(max_group_id, group_id(neighbor))

      # Path compression: rattach all stones from smallest group to the bigger group
      for stone in self.groups.groupof(neighbor):
        group_id[stone] = max_group_id

      # Concatenate the linked rings listing stones in each group.
      self.groups.next_stones.concat(max_neighbor, neighbor)

  # Now add the new stone to the adjacent group or merged group
  point.add_to_group max_neighbor

func remove_group(self: var BoardState, point: Point) =
  ## Remove the group input point is part of
  # This does not clear leftover metadata

  for stone in self.groups.groupof(point):
    remove_stone stone

    # Update liberties of neighboring groups
    for neighbor in stone.neighbors:
      # We don't care if we update the liberties of the group the deleted stone is part of
      # We don't want an "if" branch in a tight for loop
      group(neighbor).add_as_lib stone

func capture_deads_around(self: var BoardState, color: Player, point: Point) =
  ## Capture dead group around a stone

  let color_opponent = color.opponent
  for neighbor in point.neighbors:
    if self.board[neighbor] == color_opponent and group[neighbor].isDead:
      remove_group neighbor
