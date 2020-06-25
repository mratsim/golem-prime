# Copyright (c) 2018 Mamy André-Ratsimbazafy
# Distributed under the Apache v2 License
# (license terms are at https://www.apache.org/licenses/LICENSE-2.0).

# Papers
# - All-Moves-As-First Heuristics in Monte-Carlo Go
#   David P. Helmbold and Aleatha Parker-Wood, 2009
#   Department of Computer Science, University of California, Santa Cruz, California, USA
#   https://pdfs.semanticscholar.org/87b8/9babfa66c3bc33ad579e59e65321fb4b6d48.pdf
#
# - Monte-Carlo Tree Search and Rapid Action ValueEstimation in Computer Go
#   Sylvain Gelly and David Silver, 2011
#   https://www.cs.utexas.edu/~pstone/Courses/394Rspring11/resources/mcrave.pdf
#
# - Generalized Rapid Action Value Estimation
#   Tristan Cazenave, 2017
#   https://www.lamsade.dauphine.fr/~cazenave/papers/grave.pdf

import
  metab,
  ../core/core,
  ../move_heuristics/m_move,
  ../datatypes,
  ./mc_zobristhash, ./mc_datatypes

proc init(T: type MCTS_Context, komi: GoFloat): T =
  result.dag = initTab[Zobrist, Node[T.N]](sz = PreallocatedSize)
  result.double_komi = GoSint(komi * 2)

# Evaluation
# --------------------------------------------------------------

func raveUrgency(node: Node): GoFloat =
  ## Compute the Rapid Action Value Estimation Urgency
  let
    wins = node.nbWins.GoFloat
    visits = node.nbPlays.GoFloat
    raveWins = node.nbRaveWins.GoFloat
    raveVisits = node.nbRavePlays.GoFloat

  result = wins / visits
  if raveVisits == 0:
    return

  let raveValue = raveWins / raveVisits
  let beta = raveVisits / (
    raveVisits + visits + (raveVisits + visits)/RaveEquiv
  )

  result *= 1.GoFloat - beta
  result += beta * raveValue

# Selection
# --------------------------------------------------------------

func bestChild(node: Node, dag: Dag): PosHash =
  var highestUrgency: float32 -Inf
  for posHash in node.children:
    let urgency = dag[posHash.hash].raveUrgency()
    if urgency > highestUrgency:
      highestUrgency = urgency
      result = posHash

func bestMove(node: Node, dag: Dag): PosHash =
  var maxVisits: GoUInt
  for child in node.children:
    let nbPlays = dag[child.hash].nbPlays
    if nbPlays > maxVisits:
      result = child
      maxVisits = nbPlays

# Expansion
# --------------------------------------------------------------

func expand(ctx: MCTS_Context, board: BoardState, parent: var Node, parentHash: Zobrist) =
  ## Add every legalish moves as explorable children
  ## A legalish move is the set of
  ## - All legal moves
  ## - minus not filling our own true eye
  ## SuperKo are not checked

  let opponent = parent.toPlay.opponent()

  var tmpBoard: typeof(board) # A temporary board for rolling back changes

  for move in board.emptyPoints.items():
    if board.isLegalishMove(move, opponent):
      tmpBoard[] = board[] # overwrite with a fresh state
      tmpBoard.play(move, opponent)

      let childHash = tmpBoard.board.hash()

      ctx.dag
         # If child isn't in tha table add it and returns it
         .mgetOrPut(childHash, Node[ctx.N](to_play: opponent))
         # Add the input hash as a parent
         .parents.add parentHash

      parent.children.add((move, childHash))

      # TODO: Setting priors

# Simulation
# --------------------------------------------------------------

func simulate[N: static GoSInt](
        board: BoardState[N], doubleKomi: GoSInt,
        amafColorMap: var array[(N+2)*(N+2), Intersection]
      ): bool =
  ## Starting from a leaf node, simulate and returns
  ## if black wins
  # TODO implement Jigo

  var consecutivePasses = 0
  var nbMoves = 0

  while consecutivePasses < 2:
    # TODO: check the player to move
    let move = board.random_move()
    if move == Point[N](-1):
      inc consecutivePasses
    else:
      # Update AMAF (All Moves As First)
      if amafColorMap[move.GoInt] == Empty:
        amaf_color_map[move.GoInt] = board.toPlay

      board.play(move)
      consecutivePasses = 0

    if nbMoves >= MaxNbMoves:
      # Shortcut if we reach the move limit
      # It's probably a bad move that suicides one of the players
      return false

    board.next.player()

  return board.score() * 2 > doubleKomi

# -----------------------------------------------------------
when isMainModule:

  let board = MCTS_Context[19].init(7.5)

  echo board
