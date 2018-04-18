# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

##############################################
# Filling eyes considerations
#
# Main motivation:
#   We don't want to introduce bias in the final bot with human (non-rules derived)
#   knowledge.
# But
#   To improve random play, we can't just prevent illegal moves per the go rules
#   Otherwise the bot will fill its eyes, opening possibilities to the group capture.
#
# In certain cases filling a true eye might be beneficial:
#   - Semeai similar to this:
#   Black is dead
#   ------------------
#  | . O O # . # . . .
#  | O O . # # O O . .
#  | . # # # O O . . .
#  | # # O O . . . . .
#  | . # O . O . . . .
#  | # O O . . . . . .
#  | . O . . . . . . .
#  | . . . . . . . . .
#  | . . . . . . . . .
#
#  - Preventing Oshi-Tsubushi (squashing move)
#    There might be squashing move with true eyes
#  Oshi-tsubushi if black play first at 1
#  ------------------
# | . O # . . . . . .
# | O # # . O . . . .
# | 1 # O O . . . . .
# | . O . . . . . . .
# | . . O . . . . . .
# | . . . . . . . . .
# | . . . . . . . . .
#
# #######################################################
#
# So we need to prevent filling eyes in most cases but not introduce
# life and death blind spot/bias with a too rigid heuristic.
# Also it must be fast for the random playout
#
# Proposal consideration:
#   - We only consider the corner here, allowing false eyes filling is enough
#     for stones in the middle of the board.
#   - The smallest living groups are 6 stones strong in the corner (see https://senseis.xmp.net/?SmallestGroupWithTwoEyes)
#   - The practical killing shape with an eye is the "bulky five" in a corner.
#   - If the bot has the opportunity to form a rabbity six in a corner (5 stones already)
#     he can just as well form 2 eyes (see 2 and 4 corner group)
#   - There shouldn't be (?) situation where from a bulky five with eye in a corner
#     we want to do a rectangle-six. The ko will not help in any semeai.
#
# Policy
#   Do not fill a true eye if the count of stones in friendly groups around is 5+.
#   This allows filling an eye in tricky semeai situations.
#   It introduce an acceptable bias/blind-spot/question:
#     - Are there situation where a group is 5 stones where filling an eye
#       is the best move?
#
# ########################################################
# Related:
#   - Filling a true eye is never (?) a ko threat.
#   - Smallest living groups
#   - Killing shapes
#
#
#  1st corner group
#  ------------
# | . # . # O .
# | # # # # O .
# | O O O O O .
# | . . . , . .
# | . . . . . .
#
#  2nd corner group
#  ------------
# | . # # O . .
# | # . # O . .
# | O # # O . .
# | O O O O . .
# | . . . . . .
# | . . . . . .
#
#  3rd corner group
#  ------------
# | # . # O . .
# | . # # O . .
# | # # O O . .
# | O O O , . .
# | . . . . . .
#
#  4th corner group
#  ------------
# | . # # O . .
# | # . # O . .
# | # # O O . .
# | O O O , . .
# | . . . . . .
#
#  Killing shapes of stones
#  ---------------------------------------
# | . . . . . . . . . . . . . . . . . . . |
# | . . . . . . . . . O . . # # . . . . . |
# | . O . . # # . . O O O . # # # . . . . |
# | . . . , . . . . . , . . . . . . . . . |
# | . # . . O O O . # # . . . O . . . . . |
# | . # # . . . . . # # . . O O O . . . . |
# | . . . . . . . . . . . . . O . . . . . |
# | . . O . . . . . . . . . . . . . . . . |
# | . O O O . . . . . . . . . . . . . . . |
# | . O O , . . . . . , . . . . . , . . . |
# | . . . . . . . . . . . . . . . . . . . |


import
  ../datatypes, ../core/c_boardstate

func dont_fill_own_true_eye*[N: static[GoInt]](self: BoardState[N], point: Point[N], player, opponent: Player): bool =
  ## Prevent filling true eye if resulting group would be 6 stones or more
  ## Compared to regular "Don't fill your own eye" this should prevent blind spots
  ## where filling your own eye is actually a good move, while costing low simulation time.

  assert (self.board[point] == Empty) and self.group(point).nb_pseudo_libs == 0, "This proc " &
    "is only valid for a completely surrounded empty space"

  # 1. Confirm if around is friend and foe
  # At the same time we count the number of stones in friendly groups
  var counted: set[GroupID[N]]
  var nb_friendly: GoInt

  for neighbor in point.neighbors:
    if self.board[neighbor] == opponent:
      return false                       # Not own true eye. Return early.
    let neighbor_group = self.group_id(neighbor)
    if neighbor_group notin counted:
      counted.incl neighbor_group
      nb_friendly += self.group(neighbor).nb_stones

  # 2. Determine if it's a true eye or a half-eye
  #    - At most 1 enemy stone or the border around
  var countArray: array[Intersection, GoInt]
  for diag in point.diag_neighbors:
    inc countArray[self.board[diag]]

  # 3. True eyes or half-eye can be filled if resulting group
  #    is 5 stones or less.
  #    A false eye is:
  #      - On the border with 1 enemy stone in diagonal
  #      - 2 enemy stones in diagonal otherwise
  #    Everything else is a true eye or a half-eye.

  if (countArray[opponent] + GoInt(countArray[Border]>0)) < 2 and nb_friendly > 4:
    return true

  # 4. Otherwise, move elsewhere first.
  #    - Don't fill true eyes
  #    - Don't fill half-eyes until they effectively become false eyes

  return false
