# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes

func initGroups*[N: static[int8]](groups: var Groups[N]) =
  for idx, group_id in mpairs(groups.id):
    group_id = GroupID[N](idx)
  for next_stone in groups.next_stones.mitems:
    next_stone = Point[N](-1)

{.this:self.}
func reset*(self: var GroupMetadata) {.inline.} =
  self.sum_square_degree_vertices = 0
  self.sum_degree_vertices = 0
  self.nb_stones = 0
  self.nb_pseudo_libs = 0
  self.color = Empty

func reset_border*(self: var GroupMetadata) {.inline.} =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  self.sum_square_degree_vertices = high(int32)
  self.sum_degree_vertices = high(int16)
  self.nb_pseudo_libs = high(int16)
  self.nb_stones = 0
  self.color = Border

iterator groupof*[N: static[int8]](g: Groups[N], start_stone: Point[N]): Point[N] =
  ## Iterates over the all the stones of the same group as the input

  yield start_stone

  var stone = g.next_stones[start_stone]

  if stone != Point[N](-1):
    while stone != start_stone:
      yield stone
      stone = g.next_stones[stone]

func add_as_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc self.nb_pseudo_libs
  self.sum_degree_vertices += point.int16
  self.sum_square_degree_vertices += point.int32 * point.int32

func remove_from_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Remove an adjacent point from a group liberty
  dec self.nb_pseudo_libs
  self.sum_degree_vertices -= point.int16
  self.sum_square_degree_vertices -= point.int32 * point.int32

func merge*(self: var GroupsMetaPool, g1, g2: GroupID) {.inline.}=
  ## Merge the metadata of the groups of 2 stones
  ## This does not clear leftover metadata
  assert g1 != g2
  assert self[g1].color == self[g2].color

  self[g1].sum_square_degree_vertices += self[g2].sum_square_degree_vertices
  self[g1].sum_degree_vertices        += self[g2].sum_degree_vertices
  self[g1].nb_stones                  += self[g2].nb_stones
  self[g1].nb_pseudo_libs             += self[g2].nb_pseudo_libs

func concat*(self: var NextStones, p1, p2: Point) {.inline.}=
  ## Concatenate the lists of stones in the groups of p1 and p2
  swap(self[p1], self[p2])

func isDead*(self: GroupMetadata): bool {.inline.}=
  self.nb_pseudo_libs == 0
