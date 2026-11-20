"""Pinned pre-route provider for historical actor/scheduler trace comparisons.

This is actual old source, not a second implementation. These scenarios use
synthetic live terminals. New geography is exercised without this substitution
in tests/vip_routes and in the actual native marker-bank integration suite.
"""
import subprocess

BASE = 'fa4c9b60d4ee3908ac1a5e77c6d21b32156506d4'
PATH = 'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/vip_locations.lua'


def source(root):
    return subprocess.check_output(['git', 'show', f'{BASE}:{PATH}'], cwd=root, text=True)


def install(lua, root):
    policy = subprocess.check_output(['git', 'show', f'{BASE}:{PATH.replace("vip_locations.lua", "dispatch_location_policy.lua")}'], cwd=root, text=True)
    lua.globals().LegacyVIPLocationPolicy = lua.execute(policy)
    lua.execute('package.loaded.dispatch_location_policy=LegacyVIPLocationPolicy')
    load = lua.eval('function(code) return assert(loadstring(code,"@legacy_vip_locations.lua"))() end')
    lua.globals().LegacyVIPLocations = load(source(root))
    lua.execute("package.loaded.vip_locations=LegacyVIPLocations")
