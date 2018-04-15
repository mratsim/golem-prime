# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import ../datatypes

func contains*(x: EmptyPoints, point: Point): bool {.inline.} =
  x.data.contains(point)

func incl*(x: var EmptyPoints, point: Point) {.inline.} =
  ## Add a Point to a set of EmptyPoints
  ## The Point should not be in EmptyPoints already. It will throw
  ## an error in debug mode otherwise

  assert point notin x, "Error: " & $point & " is already in EmptyPoints"
  # We assume point is not already in the set to avoid branching when updating the count

  x.data.incl point
  x.last = point # Used for ko checking
  inc x.len

func excl*(x: var EmptyPoints, point: Point) {.inline.} =
  ## Remove a Point to a set of EmptyPoints
  ## The Point should be in EmptyPoints. It will throw
  ## an error in debug mode otherwise

  assert point in x, "Error: " & $point & " is not in EmptyPoints"
  # We assume point is in the set to avoid branching when updating the count

  x.data.excl point
  dec x.len
