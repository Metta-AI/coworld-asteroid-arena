import
  bitworld/replays as replayCodec,
  sim

type
  ReplayPlayer* = object
    data*: ReplayData
    joinIndex*: int
    leaveIndex*: int
    inputIndex*: int
    hashIndex*: int
    masks*: seq[uint8]
    playing*: bool

const
  AsteroidReplayMagic = "BITWORLD"
  AsteroidReplayFormatVersion = 3'u16
  AsteroidReplaySpec = ReplaySpec(
    magic: AsteroidReplayMagic,
    formatVersion: AsteroidReplayFormatVersion,
    gameName: GameName,
    gameVersion: GameVersion,
    joinKind: rjkNameSlotToken,
    allowChat: false,
    allowCompressed: true,
    hashOrder: rhoStop
  )

export replayCodec

proc tickTime*(tick: int): uint32 =
  ## Converts a simulation tick to replay milliseconds.
  replayCodec.tickTime(tick, ReplayFps)

proc openReplayWriter*(path, configJson: string): ReplayWriter =
  ## Opens a replay file and writes the header.
  replayCodec.openReplayWriter(path, configJson, AsteroidReplaySpec)

proc parseReplayBytes*(bytes: string): ReplayData =
  ## Parses one replay file buffer into memory.
  replayCodec.parseReplayBytes(bytes, AsteroidReplaySpec)

proc loadReplay*(path: string): ReplayData =
  ## Loads a replay file into memory.
  replayCodec.loadReplay(path, AsteroidReplaySpec)

proc initReplayPlayer*(data: ReplayData): ReplayPlayer =
  result.data = data
  result.masks = @[]
  result.playing = true

proc ensureReplayPlayer(replay: var ReplayPlayer, player: int) =
  while replay.masks.len <= player:
    replay.masks.add(0)

proc stepReplay*(replay: var ReplayPlayer, sim: var SimServer) =
  let time = tickTime(sim.tickCount)

  # Apply leaves
  while replay.leaveIndex < replay.data.leaves.len and
      replay.data.leaves[replay.leaveIndex].time <= time:
    let leave = replay.data.leaves[replay.leaveIndex]
    let idx = int(leave.player)
    if idx >= 0 and idx < sim.players.len:
      sim.players.delete(idx)
      if idx < replay.masks.len:
        replay.masks.delete(idx)
    inc replay.leaveIndex

  # Apply joins
  while replay.joinIndex < replay.data.joins.len and
      replay.data.joins[replay.joinIndex].time <= time:
    let join = replay.data.joins[replay.joinIndex]
    discard sim.addPlayer(join.name)
    replay.ensureReplayPlayer(int(join.player))
    inc replay.joinIndex

  # Apply input changes
  while replay.inputIndex < replay.data.inputs.len and
      replay.data.inputs[replay.inputIndex].time <= time:
    let input = replay.data.inputs[replay.inputIndex]
    replay.ensureReplayPlayer(int(input.player))
    replay.masks[int(input.player)] = input.keys
    inc replay.inputIndex

  # Build inputs from masks
  var inputs = newSeq[PlayerInput](sim.players.len)
  for i in 0 ..< sim.players.len:
    replay.ensureReplayPlayer(i)
    inputs[i] = playerInputFromMasks(replay.masks[i], 0)

  sim.step(inputs)

  # Check hash
  if replay.hashIndex >= replay.data.hashes.len:
    replay.playing = false
    return
  let expected = replay.data.hashes[replay.hashIndex]
  if int(expected.tick) > sim.tickCount:
    return
  if int(expected.tick) == sim.tickCount:
    let hash = sim.gameHash()
    if hash != expected.hash:
      raise newException(
        ReplayError,
        "Replay hash mismatch at tick " & $sim.tickCount
      )
    inc replay.hashIndex
    if replay.hashIndex >= replay.data.hashes.len:
      replay.playing = false
