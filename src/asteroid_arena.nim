import
  std/[json, os],
  jsony,
  bitworld/runtime,
  bitworld/protocol,
  asteroid_arena/server,
  asteroid_arena/sim

type
  RunConfig = object
    address: string
    port: int
    seed: int
    durationTicks: int
    tokens: seq[string]
    coopSpawnPercent: int
    coopScoreMultiplier: int
    planetCount: int

proc readConfigInt(node: JsonNode, name: string, value: var int) =
  if not node.hasKey(name):
    return
  let item = node[name]
  if item.kind != JInt:
    raise newException(ValueError, "Config field " & name & " must be an integer.")
  value = item.getInt()

proc update(config: var RunConfig, jsonText: string) =
  if jsonText.len == 0:
    return
  var node: JsonNode
  try:
    node = fromJson(jsonText)
  except jsony.JsonError as e:
    raise newException(ValueError, "Could not parse config JSON: " & e.msg)
  if node.kind != JObject:
    raise newException(ValueError, "Config must be a JSON object.")
  node.readConfigInt("seed", config.seed)
  if node.hasKey("duration"):
    var durationSeconds = 0
    node.readConfigInt("duration", durationSeconds)
    if durationSeconds < 0:
      raise newException(
        ValueError,
        "Config field duration must be at least 0."
      )
    config.durationTicks = durationSeconds * TargetFps
  node.readConfigInt("coopSpawnPercent", config.coopSpawnPercent)
  node.readConfigInt("coopScoreMultiplier", config.coopScoreMultiplier)
  node.readConfigInt("planetCount", config.planetCount)
  if node.hasKey("tokens") and node["tokens"].kind == JArray:
    for item in node["tokens"]:
      if item.kind == JString:
        config.tokens.add(item.getStr())

when isMainModule:
  let runtimeConfig = readRuntimeConfig(DefaultHost, DefaultPort)
  var
    config = RunConfig(
      address: runtimeConfig.host,
      port: runtimeConfig.port,
      seed: 0xA57E2,
      durationTicks: 0,
      coopSpawnPercent: DefaultCoopSpawnPercent,
      coopScoreMultiplier: DefaultCoopScoreMultiplier,
      planetCount: DefaultPlanetCount
    )
  config.update(runtimeConfig.config)
  let
    saveReplayPath =
      if runtimeConfig.replayUri.len > 0:
        getTempDir() / ("asteroid-arena-replay-" & $getCurrentProcessId() &
          ".bitreplay")
      else:
        ""
    loadReplayPath =
      if runtimeConfig.replayMode:
        let path = getTempDir() / ("asteroid-arena-load-replay-" &
          $getCurrentProcessId() & ".bitreplay")
        writeFile(path, runtimeConfig.replay)
        path
      else:
        ""
  runServerLoop(config.address, config.port, seed = config.seed,
    durationTicks = config.durationTicks,
    tokens = config.tokens,
    saveReplayPath = saveReplayPath,
    loadReplayPath = loadReplayPath,
    runtimeConfig = runtimeConfig,
    coopSpawnPercent = config.coopSpawnPercent,
    coopScoreMultiplier = config.coopScoreMultiplier,
    planetCount = config.planetCount)
