# IRON CLASH

`IronClash_6.rbxlx` is the playable place file (open it in Roblox Studio). It is built from the
script sources in `IronClash/src` by `tools/build.py`, starting from `IronClash_5.rbxlx`.

## What changed in this version

**Arenas** (`ServerScriptService/IronClashServer/Modules/Arena*.lua`)
- Every stage is rebuilt from rounded, layered geometry instead of flat boxes: rounded stage
  corners, filleted floor edges, corner pylons/posts, parapets, rails and ropes.
- Real backdrops: Neon Rooftop has a lit skyline, rooftop machinery and a water tower; the Dojo has
  a two-tier hall, torii gates, stone lanterns, cherry trees, bamboo, a koi pond with bridge and a
  pagoda; the Volcano has a lava sea, angular rock spires, a fortress and a smoking cone; the Frozen
  Temple has a colonnade, guardians, pines, ice crystals, glacier blocks and an aurora.
- Terrain mountains are carved with `Terrain:WriteVoxels` behind each stage.
- Floor markings use layered inlays so nothing z-fights (`tests/test_arenas.py` checks this).

**Fighters** (`Shared/FighterModels.lua`, `Shared/Secondary.lua`)
- Bodies are built from overlapping ellipsoids and tapered limbs rather than boxes/wedges.
- Hair strands, ponytails, scarves, belt tails and coat tails follow through a spring/drag simulation (secondary motion).

**Combos** (`Shared/Moves.lua`, `Shared/FightControl.lua`, `ServerScriptService/.../MatchService.lua`)
- The chain window now opens right after the hit and the server finishes a chained follow-up at the
  right moment, so strings land at 0-150 ms latency. Presses made early are buffered (0.3 s).
- New strings: `1,1,2`, `1,2,3` (launcher), `3,4`, plus juggle follow-ups after a launcher.
- The move list screen has a COMBOS page listing every string.

| Combo | Input |
| --- | --- |
| Triple Strike | `1, 2, 4` |
| Jab Rush | `1, 1, 2` |
| Hook Combo | `2, 1` |
| Kick Combo | `3, 4` |
| Elbow String | `d/f+1, 2` |
| Lift Juggle | `1, 2, 3` then `1, 2, 4` |
| Uppercut Juggle | `d/f+2` then `1, 2, 4` |

**Rebindable controls** (`Shared/Keybinds.lua`, `IronClashClient/Controls.lua`)
- Open CONTROLS from the main menu, the practice menu or the move list (KEYS).
- Every action has four slots (keyboard and gamepad); click a slot, press the new key.
  Binding a key that is in use swaps it. Bindings are saved with the player's stats.

## Tools

```
python3 tools/extract.py IronClash_5.rbxlx IronClash      # place -> source tree
python3 tools/build.py IronClash IronClash_6.rbxlx        # source tree -> place
python3 tools/preview.py arena 2 out.png game             # geometry preview (not a Studio render)
python3 -m unittest discover -s tests                     # headless tests (needs `pip install lupa numpy pillow`)
```

`docs/previews` holds software-rendered previews of the four arenas. They approximate geometry and
terrain only; lighting, materials and post-processing will look different in Studio.
