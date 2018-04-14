# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

import  ./private/p_seqtoolbox,
        ./datatypes

proc place_stone*(self: var BoardState, color: Intersection, point: Point) =
  ## Place or change the color of a stone at a specified position
  ## This only updates board state metadata
  ## And does not trigger groups/stones related life & death computation

  if color == Empty:
    self.empty_points_idx[point] = self.empty_points.len
    self.empty_points.add point
  else:
    # Note: we need to remove Point from the empty list
    # We also want a constant-time operation
    # Nim provides del: constant-time or delete O(n)
    # s.del(i) replace with s[i] with s[s.high] and pops the end

    let
      idx = self.empty_points_idx[point]
      last = self.empty_points.peek

    # Replace the value at idx by the last value
    self.empty_points_idx[last]
