# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import  algorithm,
        ../datatypes

func newGroups*[N: static[int8]](g: var Groups[N]) =
  new g
  g.id.fill GroupID[N](-1)
  g.next_stones.fill NextStone[N](-1)

{.this:self.}
func reset*(self: var GroupMetadata) =
  sum_square_degree_vertices = 0
  sum_degree_vertices = 0
  nb_stones = 0
  nb_pseudo_libs = 0
  color = Empty

func reset_border*(self: var GroupMetadata) =
  ## Special values for the border stones. They have infinite liberties
  ## and should never be in atari
  sum_square_degree_vertices = high(int32)
  sum_degree_vertices = high(int16)
  nb_pseudo_libs = high(int16)
  nb_stones = 0
  color = Border

iterator groupof*[N: static[int8]](g: Groups[N], id: Point[N]): Point[N] =

  if g.next_stones == -1:
    break

  yield id

  var stone = g.next_stones[id]
  while stone != id:
    yield stone
    stone = g.next_stones[stone]
