# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import ../datatypes

func contains(s: EmptyPoints, point: Point): bool {.inline.} =
  assert point.GoInt != -1
  s.indices[point.GoInt] != -1

func reset_border*(s: var EmptyPoints, point: Point) {.inline.} =
  ## Add a point to the border
  s.indices[point.GoInt] = -1

func reset_empty*(s: var EmptyPoints, point: Point) {.inline.} =
  ## Add a point to the empty list without pre-checks
  s.indices[point.GoInt] = s.len
  s.list[s.len] = point
  inc s.len

func peek*[N: static[GoInt]](s: EmptyPoints[N]): Point[N] {.inline.} =
  ## Returns the last point in the set.
  ## Note: if an item is deleted this is NOT the last inserted point.

  assert s.len > 0, "Error: there is no empty points"
  s.list[s.len - 1]

func incl*[N: static[GoInt]](s: var EmptyPoints[N], point: Point[N]) {.inline.} =
  ## Add a Point to a set of EmptyPoints
  ## The Point should not be in EmptyPoints already. It will throw
  ## an error in debug mode otherwise

  # We assume point is not already in the set to avoid branching when updating the count
  assert point notin s, "Error: " & $point & " is already in EmptyPoints"
  # Bound checking
  assert s.len <= N * N, "EmptyPoints is already at max capacity."

  s.indices[point.GoInt] = s.len
  s.list[s.len] = point
  inc s.len

func excl*(s: var EmptyPoints, point: Point) {.inline.} =
  ## Remove a Point to a set of EmptyPoints
  ## The Point should be in EmptyPoints. It will throw
  ## an error in debug mode otherwise

  # We assume point is in the set to avoid branching when updating the count
  assert point in s, "Error: " & $point & " is not in EmptyPoints"

  # We do constant time deletion by replacing the deleted point
  # by the last value in the list

  let del_idx = s.indices[point.GoInt]

  s.indices[s.peek.GoInt] = del_idx   # Last value now points to deleted index
  dec s.len
  s.list[del_idx] = s.list[s.len]     # Deleted item is now last value

  when compileOption("boundChecks"):
    s.indices[point.GoInt] = -1       # Now we erase last value (take care of border case when we remove last value)
