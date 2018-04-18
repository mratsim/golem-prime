# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes

{.this:self.}
func reset_members*[N: static[GoInt]](groups: var Groups[N]) =
  for idx, group_id in mpairs(groups.id):
    group_id = GroupID[N](idx)
  for next_stone in groups.next_stones.mitems:
    next_stone = Point[N](-1)

func reset_meta*(self: var GroupMetadata) {.inline.} =
  sum_square_degree_vertices = 0.GoInt2
  sum_degree_vertices = 0.GoInt
  nb_stones = 0.GoInt
  nb_pseudo_libs = 0.GoInt

func reset_border*(self: var GroupMetadata) {.inline.} =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  sum_square_degree_vertices = high(GoInt2)
  sum_degree_vertices = high(GoInt)
  nb_pseudo_libs = 4.GoInt
  nb_stones = 0.GoInt

iterator groupof*[N: static[GoInt]](self: BoardState, start_stone: Point[N]): Point[N] =
  ## Iterates over the all the stones of the same group as the input

  assert start_stone != Point[N](-1)

  # We need to store the next stone too before yielding,
  # to deal with iterator aliasing in remove_group
  var
    current = start_stone
    next = self.groups.next_stones[current]

  while true:
    yield current
    current = next
    if current == start_stone:
      break
    next = self.groups.next_stones[current]

func add_as_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc self.nb_pseudo_libs
  self.sum_degree_vertices += point.GoInt
  self.sum_square_degree_vertices += point.GoInt2 * point.GoInt2

func remove_from_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Remove an adjacent point from a group liberty
  dec self.nb_pseudo_libs
  self.sum_degree_vertices -= point.GoInt
  self.sum_square_degree_vertices -= point.GoInt2 * point.GoInt2

func merge*(self: var GroupsMetaPool, g1, g2: GroupID) {.inline.}=
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
  nb_pseudo_libs == 0.GoInt

func is_in_atari*(self: GroupMetadata): bool {.inline.}=
  nb_pseudo_libs.GoInt2 * sum_square_degree_vertices == sum_degree_vertices.GoInt2 * sum_degree_vertices.GoInt2
