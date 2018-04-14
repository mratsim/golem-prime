# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  algorithm,
  ./p_pointcoord,
  ../datatypes

func newGroups*[N: static[int8]](groups: var Groups[N]) =
  new groups
  groups.id.fill GroupID[N](-1)
  groups.next_stones.fill NextStone[N](-1)

{.this:self.}
func reset(self: var GroupMetadata) {.inline.} =
  sum_square_degree_vertices = 0
  sum_degree_vertices = 0
  nb_stones = 0
  nb_pseudo_libs = 0
  color = Empty

func reset_border(self: var GroupMetadata) {.inline.} =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  sum_square_degree_vertices = high(int32)
  sum_degree_vertices = high(int16)
  nb_pseudo_libs = high(int16)
  nb_stones = 0
  color = Border

iterator groupof*[N: static[int8]](g: Groups[N], start_stone: Point[N]): Point[N] =
  ## Iterates over the all the stones of the same group as the input

  yield start_stone
  if g.next_stones == -1:
    break

  var stone = g.next_stones[start_stone]
  while stone != start_stone:
    yield stone
    stone = g.next_stones[stone]

func add_lib(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc nb_pseudo_libs
  sum_degree_vertices += point
  sum_square_degree_vertices += point.i32 * point.i32

func merge(self: var GroupsMetaPool, g1, g2: GroupID) {.inline.}=
  ## Merge the metadata of the groups of 2 stones
  ## This does not clear leftover data
  assert g1 != g2
  assert self[g1].color == self[g2].color

  self[g1].sum_square_degree_vertices += self[g2].sum_square_degree_vertices
  self[g1].sum_degree_vertices        += self[g2].sum_degree_vertices
  self[g1].nb_stones                  += self[g2].nb_stones
  self[g1].nb_pseudo_libs             += self[g2].nb_pseudo_libs

func concat(self: var NextStones, p1, p2: Point) {.inline.}=
  ## Concatenate the lists of stones in the groups of p1 and p2
  swap(self[p1], self[p2])

########## Board operations on groups ##########
# Those operations are done at the board level to avoid double indirection
# when checking the color of the neighboring stones,
# it would require metadata[id[point]] otherwise

func group_id*(self: var BoardState, point: Point): var GroupID {.inline.}=
  self.groups.id[point]

func group*(self: var BoardState, point: Point): var GroupMetadata {.inline.}=
  self.groups.metadata[self.groups.id[point]]

func singleton(self: var BoardState, color: Player, point: Point) =
  ## Create a new group from a single stone

  group_id[point] = point
  self.groups.next_stones[point] = point

  group[point].reset()
  group[point].color = color
  inc group[point].nb_stones

  for neighbor in point.neighbors:
    if self.board[neighbor] == Empty:
      group[point].add_lib neighbor


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
