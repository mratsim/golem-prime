# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import
  ../datatypes

const stone_display: array[Intersection, char] = [
  Empty: '.',
  Black: 'X',
  White: 'O',
  Border: ' ']

func toChar*(intersection: Intersection): char {.inline.}=
  stone_display[intersection]

const opponents: array[Player, Player] = [
  Black: Player White,
  White: Player Black]

func opponent*(color: Player): Player {.inline.} =
  opponents[color]
