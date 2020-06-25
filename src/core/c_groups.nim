# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes

{.this:self.}

################# Initialization ######################

func reset_members*[N: static[GoSint]](groups: var Groups[N]) =
  for idx, group_id in mpairs(groups.id):
    group_id = GroupID[N](idx)
  for next_stone in groups.next_stones.mitems:
    next_stone = Point[N](-1)

func reset_meta*(self: var GroupMetadata) {.inline.} =
  sum_square_degree_vertices = 0.GoUint
  sum_degree_vertices = 0.GoSint
  nb_stones = 0.GoSint
  nb_pseudo_libs = 0.GoSint

func reset_border*(self: var GroupMetadata) {.inline.} =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  sum_square_degree_vertices = high(GoUint)
  sum_degree_vertices = high(GoSint)
  nb_pseudo_libs = 4.GoSint
  nb_stones = 0.GoSint

################# Initialization ######################

########## Iteration and group accessors ##############

iterator groupof*[N: static[GoSint]](self: BoardState, start_stone: Point[N]): Point[N] =
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

# Those operations are done at the board level to avoid double indirection
# when checking the color of the neighboring stones.

func group_id*[N: static[GoSint]](self: BoardState[N], point: Point[N]): var GroupID[N] {.inline.}=
  self.groups.id[point]

func group*(self: BoardState, point: Point): var GroupMetadata {.inline.}=
  self.groups.metadata[self.groups.id[point]]

func group_next*[N: static[GoSint]](self: BoardState[N], point: Point[N]): var Point[N] {.inline.}=
  self.groups.next_stones[point]

########## Iteration and group accessors ##############

################# Liberties  ##########################

func add_as_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Add an adjacent point as a liberty to a group
  inc self.nb_pseudo_libs
  self.sum_degree_vertices += point.GoSint
  self.sum_square_degree_vertices += point.GoUint * point.GoUint

func remove_from_lib*(self: var GroupMetadata, point: Point) {.inline.} =
  ## Remove an adjacent point from a group liberty
  dec self.nb_pseudo_libs
  self.sum_degree_vertices -= point.GoSint
  self.sum_square_degree_vertices -= point.GoUint * point.GoUint

func is_dead*(self: GroupMetadata): bool {.inline.}=
  nb_pseudo_libs == 0.GoSint

func is_in_atari*(self: GroupMetadata): bool {.inline.}=
  # Graph theory
  # To detect atari we use the inequality that if we have n liberties: ∑(liberties²)/n ≤ (∑liberties)².
  # Equality only if each liberty is the same (contributed by the same point).
  # See: https://web.archive.org/web/20090404040318/http://computer-go.org/pipermail/computer-go/2007-November/012350.html
  #
  nb_pseudo_libs.GoUint * sum_square_degree_vertices == sum_degree_vertices.GoUint * sum_degree_vertices.GoUint

################# Liberties  ##########################

################## Merging  ###########################

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

################## Merging  ###########################
