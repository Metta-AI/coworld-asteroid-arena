import std/os

{.warning[UnusedImport]: off.}
import asteroid_arena
{.warning[UnusedImport]: on.}

echo "Testing Asteroid Arena"
doAssert fileExists("coworld_manifest.json"), "manifest should exist"
doAssert fileExists("src/asteroid_arena.nim"), "game source should exist"
doAssert fileExists("players/shooter/shooter.nim"), "shooter bot should exist"
