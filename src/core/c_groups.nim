# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  algorithm,
  ../datatypes

func newGroups*[N: static[int8]](groups: var Groups[N]) =
  new groups
  groups.id.fill GroupID[N](-1)
  groups.next_stones.fill NextStone[N](-1)

{.this:self.}
func reset*(self: var GroupMetadata) {.inline.} =
  sum_square_degree_vertices = 0
  sum_degree_vertices = 0
  nb_stones = 0
  nb_pseudo_libs = 0
  color = Empty

func reset_border*(self: var GroupMetadata) {.inline.} =
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

func add_as_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc nb_pseudo_libs
  sum_degree_vertices += point
  sum_square_degree_vertices += point.i32 * point.i32

func remove_from_lib(self: var GroupMetadata, point: Point) {.inline.} =
  ## Remove an adjacent point from a group liberty
  dec nb_pseudo_libs
  sum_degree_vertices -= point
  sum_square_degree_vertices -= point.i32 * point.i32

func merge(self: var GroupsMetaPool, g1, g2: GroupID) {.inline.}=
  ## Merge the metadata of the groups of 2 stones
  ## This does not clear leftover metadata
  assert g1 != g2
  assert self[g1].color == self[g2].color

  self[g1].sum_square_degree_vertices += self[g2].sum_square_degree_vertices
  self[g1].sum_degree_vertices        += self[g2].sum_degree_vertices
  self[g1].nb_stones                  += self[g2].nb_stones
  self[g1].nb_pseudo_libs             += self[g2].nb_pseudo_libs

func concat(self: var NextStones, p1, p2: Point) {.inline.}=
  ## Concatenate the lists of stones in the groups of p1 and p2
  swap(self[p1], self[p2])

func isDead*(self: GroupMetadata): bool {.inline.}=
  self.nb_pseudo_libs == 0
