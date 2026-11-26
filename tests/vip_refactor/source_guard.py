"""Byte-preservation guards for a mechanical extraction, not gameplay replicas."""
from pathlib import Path
import hashlib,subprocess,textwrap,sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'quest_marker_probe'))
from probe_source import without_probe,without_location_exclusion,without_quest_giver
BASE='a9b654fed01145dd908ffe82de6e097bf2917c56'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
BRANDING={
    'init.lua':[
        ('-- NCPD Patrol v0.17d CET refactor r2 | separated menu and live session',
         '-- NCPD Patrol v0.17d VIP refactor r3 | extracted locations and waypoint ownership'),
        ('v0.17d CET refactor r2 loaded. Patrol, Dispatch, Career, Settings, Diagnostics and Testing tabs. Existing gameplay and dispatch refactor retained. Install the complete package and restart.',
         'v0.17d VIP refactor r3 loaded. VIP locations and waypoint ownership are separate modules. Transport, ambush, rewards and the CET menu retain their existing behavior. Install the complete package and restart.'),
    ],
    'cet_ui.lua':[
        ('ImGui.Begin("NCPD Patrol - v0.17d CET refactor r2###NCPDPatrolWindow")',
         'ImGui.Begin("NCPD Patrol - v0.17d VIP refactor r3###NCPDPatrolWindow")'),
    ],
}

def original(root,name):
    return subprocess.check_output(['git','show',f'{BASE}:{PREFIX}{name}'],cwd=root,text=True)

def between(text,start,end):
    index=text.index(start)
    return text[index:text.index(end,index)]

def verify(root):
    mods=root/PREFIX
    old=original(root,'vip.lua')
    sys.path.insert(0,str(root/'tests/vip'))
    from legacy_locations import source as legacy_source
    locations=without_location_exclusion(legacy_source(root))
    current_locations=(mods/'vip_locations.lua').read_text()
    waypoint=without_probe((mods/'vip_waypoint.lua').read_text())
    distance=between(old,'local function distance(','local function finite(')
    finite=between(old,'local function finite(','local function same(')
    choose=between(old,'local function chooseLocations(player)','local function spawnVIP(player)')
    marker=between(old,'local function releaseWaypointID()','function M.state()')
    fields=between(old,'local waypointID,waypointPoint=','local function native()')
    actual_locations=textwrap.dedent(between(locations,'    local function distance(','    local locations ='))
    actual_marker=textwrap.dedent(between(waypoint,'    local waypointID,waypointPoint=','    local marker ='))
    assert actual_locations==distance+finite+choose,'VIP geographic policy/RNG order changed'
    assert actual_marker==fields+distance+marker,'VIP registry/recovery policy changed'
    for source in [current_locations,locations,waypoint]:
        for forbidden in ['GetDynamicEntitySystem','CreateEntity','DeleteEntity','GetScriptableSystemsContainer','Game.GetPlayer','GiveItem','NCPDPatrolVIPSystem']:
            assert forbidden not in source,forbidden
    # Reinsert only the extracted source/call sites. Everything else, including
    # actor ownership, native transitions, mounting and cleanup, must be exact.
    current=(mods/'vip.lua').read_text()
    current=current.replace('local Locations = require("vip_locations").new()\nlocal Waypoint = require("vip_waypoint").new()\n','',1)
    current=current.replace('local keepResolvedScene=false\n','local keepResolvedScene=false\nlocal locationInfo="Not selected"\n'+fields,1)
    current=current.replace('function M.state()',marker+'function M.state()',1)
    current=current.replace('local function spawnVIP(player)',choose+'local function spawnVIP(player)',1)
    current=current.replace('    Locations.reset()\n    Waypoint.reset()\n',between(old,'    locationInfo="Not selected"\n','    Ambush.reset()'),1)
    old_diag=between(old,'.." | locations="..locationInfo','\n        .." | ambush="')
    current=current.replace('.." | locations="..Locations.diagnostics().." | "..Waypoint.diagnostics()',old_diag,1)
    current=current.replace('Waypoint.rebuild(patrol,stage==2 and destination or pickup,stage==2 and "Delivery" or "Pickup")',
        'waypoint(patrol,stage==2 and destination or pickup,stage==2 and "Delivery" or "Pickup")\n        waypointRepairs=waypointRepairs+1',1)
    current=current.replace('ok and Waypoint.status() or tostring(err)','ok and waypointStatus or tostring(err)',1)
    current=current.replace('Waypoint.clear()','clearWaypoint()').replace('Locations.choose(player)','chooseLocations(player)')
    current=current.replace('status("VIP locations | "..Locations.diagnostics())','status("VIP locations | "..locationInfo)',1)
    current=current.replace('Waypoint.beginAssignment(patrol,pickup,"Pickup")','waypointRepairs=0\n        waypoint(patrol,pickup,"Pickup")',1)
    current=current.replace('Waypoint.place(patrol,destination,"Delivery")','waypoint(patrol,destination,"Delivery")')
    current=current.replace('Waypoint.update(delta,patrol,status)','checkWaypoint(delta,patrol,status)')
    assert current==old,'Unrelated transport/AI/cleanup statements changed'
    for name,replacements in BRANDING.items():
        if name=='cet_ui.lua':
            # The explicitly requested v0.18i menu cleanup changes layout.
            # Pin the reviewed complete UI; retained action equivalence is
            # exercised by check_cet_ui, and retired/current routes separately.
            assert hashlib.sha256(without_quest_giver((mods/name).read_text()).encode()).hexdigest()=='d2fc8398ac309b52549c1ed25f37561077bf0e0cd169f2af5d2d2937a75727e1','Unreviewed CET menu change'
            continue
        expected=original(root,name)
        for before,after in replacements:
            assert expected.count(before)==1
            expected=expected.replace(before,after)
        assert without_probe((mods/name).read_text())==expected,'Only build labels and isolated r4 probe hooks may change in '+name
