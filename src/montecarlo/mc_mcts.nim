# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

# Implements Monte-Carlo Tree Search
# TODO: Implement Beam search + Monte-Carlo Tree Search
# Cazenave, 2012: https://hal.archives-ouvertes.fr/hal-01498618/document
# Baier & Winands, 2017: https://dke.maastrichtuniversity.nl/m.winands/documents/CIG2012_paper_32.pdf


import
  ../datatypes, ../mc_datatypes,
  ../core/core,
  ../move_heuristics/m_move,
  ./mc_zobristhash,
  random, tables

func initMCTS_Context*(komi: GoFloat, N: static[GoInt]): MCTS_Context[N] =
  result.nodes = initTable[Zobrist, Node[N]](PreallocatedSize)
  result.double_komi = GoNatural(komi * 2)

func simulate[N: static[GoInt]](self: BoardState[N], double_komi: GoInt,
  amaf_color_map: var array[(N+2)*(N+2), Intersection]
  ): bool {.inline.}=
  ## TODO: implement Jigo
  ## Starting from a leaf node, simulate and returns if black wins

  var consecutive_passes: range[0..2]
  var nb_moves: range[0 .. MaxNbMoves - 1]

  while consecutive_passes < 2:
    # TODO: check the player to move
    let move = self.random_move
    if (move == Point[N](-1)):
      inc consecutive_passes
    else:
      # Update AMAF
      if amaf_color_map[move.GoInt] == Empty:
        amaf_color_map[move.GoInt] = self.to_play

      self.play(move)
      consecutive_passes = 0

    if nb_moves == MaxNbMoves - 1:
      # Shortcut if we reach the move limit
      # It's probably a bad move tht suicides one of the players
      return false

    self.next.player()

  result = self.score * 2 > double_komi


func rave_urgency(self: Node): GoFloat =

  template wins: untyped = self.nb_wins.GoFloat
  template visits: untyped = self.nb_plays.GoFloat
  template rave_wins: untyped = self.nb_rave_wins.GoFloat
  template rave_visits: untyped = self.nb_rave_plays.GoFloat

  result = wins / visits
  if rave_visits == 0:
    return

  let rave_value = rave_wins / rave_visits
  let beta = rave_visits / (rave_visits + visits + (rave_visits + visits)/RaveEquiv)

  result *= 1.GoFloat - beta
  result += beta * rave_value

func best_child[N: static[GoInt]](self: Node[N], nodes: NodeTable[N]): PosHash[N] =
  var best_value: GoFloat

  for poshash in self.children:
    let value = nodes[poshash.hash].rave_urgency
    if value > best_value:
      best_value = value
      result = poshash

func best_move[N: static[GoInt]](self: Node[N], nodes: NodeTable[N]): PosHash[N] =
  var max_visits: GoNatural2
  for child in self.children:
    let nb_plays = nodes[child.hash].nb_plays
    if nb_plays > max_visits:
      result = child
      max_visits = nb_plays

func expand_node[N: static[GoInt]](self: var MCTS_Context[N], board_state: BoardState[N],
                parent_node: var Node[N], parent_hash: Zobrist) =

  let opponent: Player = parent_node.to_play.opponent

  var bstate_copy: BoardState[N]

  for move in items(board_state.empty_points):
    if is_legalish_move(board_state, move, opponent):
      deepCopy(bstate_copy, board_state)
      bstate_copy.play(move, opponent)

      let child_hash = bstate_copy.board.hash

      self.nodes
        .mgetOrPut(child_hash, Node[N](to_play: opponent)) # If child isn't in the table add it
        .parents.add parent_hash                        # Add the input hash as a parent

      # Add as the child to input
      parent_node.children.add (move, child_hash)

      # TODO: Setting priors

proc run_rollout[N: static[GoInt]](
        self: var MCTS_Context[N],
        board_state: BoardState[N],
        root_hash: Zobrist) =

  # Track who played at each point first for AMAF (All moves as first) heuristic
  var
    amaf_color_map: array[(N+2)*(N+2), Intersection]
    hash = root_hash

  # Comment this out and this compiles:
  # "nim c -r -o:build/golem_prime src/golem_prime.nim"
  echo amaf_color_map
  # otherwise:
  # datatypes.nim(96, 42) Error: cannot infer the value of the static param 'N'
  # which correstonds to unrelated line
  # Board*[N: static[GoInt]] = array[(N+2) * (N+2), Intersection]

  # Get a pointer to the node.
  # TODO: This is unsafe but there is nothing that will cause memory to move
  var node = self.nodes.mget(hash).addr

  # 1. Selection: Descend the tree until we reach a leaf
  while not (node.children.len == 0):

    # Shuffle to break ties. #TODO find a faster way
    node.children.shuffle
    let (promising_move, promising_hash) = node[].best_child(self.nodes)

    if promising_move != Point[N](-1):
      # If not a pass
      board_state.play(promising_move)

      # Update AMAF
      # if amaf_color_map[promising_move.GoInt] == Empty:
      #   amaf_color_map[promising_move.GoInt] = node.to_play

      # TODO: virtual loss

    hash = promising_hash
    node = self.nodes[hash].addr
    # TODO: This is very unsafe, if the "nodes" table is too small
    #       expand_node will move the memory to grow the Table
    #       and node will point to nothing.

    # 2. Expansion
    if (node.children.len == 0) and node.nb_plays > ExpansionThreshold:
      self.expand_node(board_state, node[], hash)

    # 3. Simulation
    # let black_wins = board_state.simulate(self.double_komi, amaf_color_map)

    # 4. Backpropagation
    var update_nodes = @[hash] # TODO: reduce allocation
    while update_nodes.len != 0:
      node = self.nodes[update_nodes.pop].addr
      update_nodes.add node.parents

    #   let isWinningSide = black_wins xor (node.to_play == White)

      inc node.nb_plays
    #   node.num_wins += GoInt isWinningSide

      # Update RAVE visits of child nodes
      for poshash in node.children:
        let child = self.nodes.mget(hash).addr
        # if amaf_color_map[poshash.position.GoInt] == child.to_play:
        #   inc child.nb_rave_plays
    #       child.nb_rave_wins += GoInt not isWinningSide # Children are the opposite player

proc search_best_move*[N: static[GoInt]](
  self: var MCTS_Context[N], board_state: BoardState[N],
  nb_simulations: Natural): Point[N] =

  assert board_state.empty_points.len > 0, "It seems like the whole board is completely full of stones, " &
    "not even eyes are left. Are you playing go?"

  if not board_state.are_legalish_moves_left:
    # TODO: we do one pass over all moves here
    # But we will do that anyway during move generation
    # Except that this is checked at every move.
    return Point[N](-1)

  var simulstate: BoardState[N]
  deepCopy(simulstate, board_state)

  let root_hash = simulstate.board.hash

  var root = self.nodes.mgetOrPut(root_hash, Node[N](to_play: board_state.to_move))
    # TODO: This is very unsafe, if the "nodes" table is too small
    #       expand_node will move the memory to grow the Table
    #       and node will point to nothing.

  if root.children.len == 0:
    self.expand_node(board_state, root, root_hash)

  for i in 0 ..< nb_simulations:
    # TODO Error: cannot infer the value of the static param 'N'
    #   Only workaround is to use a static int, a static GoInt will trigger
    #   will trigger type mismatch down the line
    run_rollout(self, simulstate, root_hash)
    deepCopy(simulstate, board_state)

  let (best_move, best_hash) = self.nodes[root_hash].best_move(self.nodes)
  return best_move
