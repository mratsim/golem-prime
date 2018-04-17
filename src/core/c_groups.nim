# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes

{.this:self.}
func reset_members*[N: static[int8]](groups: var Groups[N]) =
  for idx, group_id in mpairs(groups.id):
    group_id = GroupID[N](idx)
  for next_stone in groups.next_stones.mitems:
    next_stone = Point[N](-1)

func reset_meta*(self: var GroupMetadata) {.inline.} =
  sum_square_degree_vertices = 0
  sum_degree_vertices = 0
  nb_stones = 0
  nb_pseudo_libs = 0

func reset_border*(self: var GroupMetadata) {.inline.} =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  sum_square_degree_vertices = high(uint32)
  sum_degree_vertices = high(uint16)
  nb_pseudo_libs = 4
  nb_stones = 0

template groupof_impl(self: NextStones, start_stone: Point): untyped =
  # Implementation of the groupof iterator

  yield start_stone

  var stone = next[start_stone]

  if stone != Point[N](-1):
    while stone != start_stone:
      yield stone
      stone = next[stone]

iterator groupof_noalias*[N: static[int8]](self: BoardState, start_stone: Point[N]): Point[N] =
  ## Iterates over the all the stones of the same group as the input

  let next = self.groups.next_stones # Need to store state to prevent aliasing
  groupof_impl(next, start_stone)

iterator groupof_alias*[N: static[int8]](self: BoardState, start_stone: Point[N]): Point[N] =
  ## Iterates over the all the stones of the same group as the input

  groupof_impl(self.groups.next_stones, start_stone)


func add_as_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc self.nb_pseudo_libs
  self.sum_degree_vertices += point.uint16
  self.sum_square_degree_vertices += point.uint32 * point.uint32

func remove_from_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Remove an adjacent point from a group liberty
  dec self.nb_pseudo_libs
  self.sum_degree_vertices -= point.uint16
  self.sum_square_degree_vertices -= point.uint32 * point.uint32

func merge*(self: var GroupsMetaPool, g1, g2: GroupID) =
  ## Merge the metadata of the groups of 2 stones
  ## This does not clear leftover metadata
  assert g1 != g2

  self[g1].sum_square_degree_vertices += self[g2].sum_square_degree_vertices
  self[g1].sum_degree_vertices        += self[g2].sum_degree_vertices
  self[g1].nb_stones                  += self[g2].nb_stones
  self[g1].nb_pseudo_libs             += self[g2].nb_pseudo_libs

func concat*(self: var NextStones, p1, p2: Point) {.inline.}=
  ## Concatenate the lists of stones in the groups of p1 and p2
  swap(self[p1], self[p2])

func is_dead*(self: GroupMetadata): bool {.inline.}=
  nb_pseudo_libs == 0

func is_in_atari*(self: GroupMetadata): bool {.inline.}=
  nb_pseudo_libs.uint32 * sum_square_degree_vertices == sum_degree_vertices.uint32 * sum_degree_vertices.uint32
