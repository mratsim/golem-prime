import sequtils, random, times

const
  SizeSquare: int16 = 19 * 19
  ItemsToKeep = 10 # For bench we will initialize with 19 * 19 items
                   # And only keep 1à at the end

# We evaluate which implementation is best to track empty points on the goban:
#   - using a set
#   - using 2 seqs
#       - Indeed constant time deletion will swap deleted index with seq.high
#       - So we need to track the swap in a second seq

# Empty points are removed millions of times per second during MonteCarlo simulations

type
  Point = range[-1'i16 .. SizeSquare - 1]
  SetPoints = set[Point]

  SeqPoints = object
    points: seq[Point]
    track_point_idx: seq[int16] # Maps the wanted point with
                              # it's real position in the "points" field
                              # This enable constant-time deletion

proc peek[T](s: seq[T]): T {.inline.} =
  s[s.high]

proc add(s: var SeqPoints, p: Point) =
  s.track_point_idx[p] = s.points.len.int16
  s.points.add p

proc del(s: var SeqPoints, p: Point) =

  # Note: we need to remove Point from the list
  # We also want a constant-time operation
  # Nim provides `del` O(1) or `delete` O(n)
  # s.del(i) replace with s[i] with s[s.high] and pops the end

  let
    idx = s.track_point_idx[p]
    last = s.points.high

  # Replace the value at p by the last value
  s.points.del(p)
  # Track the new place of the last
  s.track_point_idx[last] = idx
  s.track_point_idx[p] = -1

iterator items(s: SeqPoints): Point =
  for p in s.points:
    yield p

proc initSeqPoints(): SeqPoints =

  newSeq(result.points, SizeSquare)
  newSeq(result.track_point_idx, SizeSquare)

  for i in 0'i16 ..< SizeSquare:
    result.points[i] = i
    result.track_point_idx[i] = i

proc initIndices(): array[SizeSquare - ItemsToKeep, int16] {.noInit.}=

  var tmp {.noInit.}: array[SizeSquare, int16]

  for i in 0'i16 ..< SizeSquare:
    tmp[i] = i

  shuffle(tmp)

  for i, v in result.mpairs:
    v = tmp[i]

proc removeSetP[N: static[int]](s: var SetPoints, indices: array[N, int16]) =

  for idx in indices:
    s.excl idx

proc removeSeqP[N: static[int]](s: var SeqPoints, indices: array[N, int16]) =

  for idx in indices:
    s.del idx

proc main() =

  var setp: SetPoints = {0'i16 .. SizeSquare - 1}
  echo "Size setp: " & $sizeof(setp)

  var seqp = initSeqPoints()
  echo "Size setq " & $(
    seqp.points.len * Point.sizeof +
    seqp.track_point_idx.len * int16.sizeof
    )

  let indices = initIndices()


  ########## Warmup ################
  var start = cpuTime()

  # Raise CPU to max perf even if using ondemand CPU governor
  # (mod is a costly operation)
  var foo = 123
  for i in 0 ..< 1000000000:
    foo += i*i mod 456
    foo = foo mod 789

  # Compiler shouldn't optimize away the results so we print it
  var stop = cpuTime()
  echo "Warmup val: " & $foo
  echo "Warmup: " & $(stop - start) & "s"
  ########## Warmup ################

  ########## Set operations ################
  start = cpuTime()
  removeSetP(setp, indices)
  stop = cpuTime()
  echo "Set content: " & $setp
  echo "Set: " & $(stop - start) & "s"
  echo "set len: " & $setp.card
  ########## Set operations ################

  ########## 2x seq operations ################
  start = cpuTime()
  removeSeqP(seqp, indices)
  stop = cpuTime()
  echo "2x seq content: " & $toSeq(items(seqp))
  echo "2x seq: " & $(stop - start) & "s"
  echo "seq len: " & $seqp.points.len
  ########## 2x seq operations ################

  ########## Sanity checks ################

  var sanity_set: SetPoints = {5'i16..15}
  echo "Sanity check {5..15}: " & $sanity_set
  sanity_set.excl 10
  echo "Sanity check {5..15} - {10}: " & $sanity_set

  var sanity_seqs = initSeqPoints()
  sanity_seqs.points = sanity_seqs.points[5..15]
  sanity_seqs.track_point_idx = sanity_seqs.track_point_idx[5..15]
  echo "Sanity check {5..15}: " & $sanity_seqs
  sanity_seqs.del 5 # 10 is in position 5
  echo "Sanity check {5..15} - {10}: " & $sanity_seqs

  ########## Sanity checks ################

  ###############################################

main()
