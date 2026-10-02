"""Headless harness: loads the IRON CLASH Lua source tree into a lupa runtime with the Roblox shim."""
import os
import sys
from pathlib import Path

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "IronClash" / "src"
SHIM = ROOT / "tests" / "rbx_shim.lua"


class Game:
    def __init__(self, src=SRC):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        lua = self.lua
        self.shim = lua.execute(f"return dofile({str(SHIM)!r})")
        self.env = self.shim.makeEnv()
        self.shim.installRequire(self.env)
        self.src = Path(src)
        self._build_tree()

    # build instance tree mirroring the directory layout --------------------------------
    def _build_tree(self):
        shim = self.shim
        self.nodes = {}
        for svc in sorted(p for p in self.src.iterdir() if p.is_dir()):
            node = shim.service(svc.name)
            self.nodes[svc.name] = node
            self._walk(svc, node, svc.name)

    def _make_child(self, path: Path, parent, key):
        shim = self.shim
        name = path.name
        if path.is_dir():
            # a directory that has a sibling script file is that script's children container -> handled in _walk
            node = shim.Instance.new("Folder", parent)
            node.Name = name
            return node
        return None

    def _walk(self, d: Path, parent, key):
        shim = self.shim
        entries = sorted(d.iterdir())
        files = {p.name: p for p in entries if p.is_file()}
        dirs = {p.name: p for p in entries if p.is_dir()}
        created = {}
        for fname, p in files.items():
            if fname.endswith(".server.lua"):
                cls, name = "Script", fname[: -len(".server.lua")]
            elif fname.endswith(".client.lua"):
                cls, name = "LocalScript", fname[: -len(".client.lua")]
            elif fname.endswith(".lua"):
                cls, name = "ModuleScript", fname[: -len(".lua")]
            else:
                continue
            node = shim.newScript(cls, name, str(p), parent)
            created[name] = node
            self.nodes[f"{key}/{name}"] = node
        for dname, p in dirs.items():
            if dname in created:
                self._walk(p, created[dname], f"{key}/{dname}")
            else:
                node = shim.Instance.new("Folder", parent)
                node.Name = dname
                self.nodes[f"{key}/{dname}"] = node
                self._walk(p, node, f"{key}/{dname}")

    def module(self, path):
        """require() a module by tree path, e.g. 'ReplicatedStorage/Shared/Moves'."""
        return self.env.require(self.nodes[path])


def game():
    return Game()


def lua_ctx(g, real_fighters=False):
    """Context table handed to Lua test helpers."""
    lua = g.lua
    ctx = lua.table()
    ctx.realFighters = real_fighters
    ctx.shim = g.shim
    ctx.env = g.env
    ctx.node = lambda path: g.nodes[path]
    return ctx


def new_sim(latency=0.06, real_fighters=False):
    g = Game()
    ctx = lua_ctx(g, real_fighters)
    sim = g.lua.execute("return dofile(%r)" % str(ROOT / "tests" / "sim.lua"))(ctx)
    sim.latency = latency
    sim.boot()
    return g, sim
