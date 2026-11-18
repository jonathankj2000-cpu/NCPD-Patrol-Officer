"""Generate private clones, CET catalog and exact native admission from verified IDs."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
def outputs():
 data=json.loads((ROOT/'assets/cyberpsycho/variants.json').read_text());rows=data['variants']
 assert len(rows)==17 and len({r['base'] for r in rows})==17 and len({r['record'] for r in rows})==17
 assert rows[0]['record']=='Character.NCPDPatrol_Cyberpsycho'
 yaml='# Private cyberpsycho clones; original quests, actors and records are untouched.\n# Verified source IDs: assets/cyberpsycho/variants.json\n'
 for row in rows:
  yaml+='\n'+row['record']+':\n  $base: '+row['base']+'\n'
  yaml+='  quest: NPCQuestAffiliation.General\n  priority: SpawnableObjectPriority.Regular\n  savable: false\n  baseAttitudeGroup: hostile\n  reactionPreset: ReactionPresets.Ganger_Aggressive\n  affiliation: Factions.Unaffiliated\n'
  yaml+='  displayName: LocKey#NCPDPatrol_Cyberpsycho_Name\n  fullDisplayName: LocKey#NCPDPatrol_Cyberpsycho_Name\n  lootDrop: LootTables.Empty\n'
 entries='\n'.join('    {record='+json.dumps(r['record'])+',base='+json.dumps(r['base'])+',label='+json.dumps(r['label'])+'},' for r in rows)
 lua='''-- Generated from assets/cyberpsycho/variants.json; do not guess base IDs.
local M = {}
local entries = {
'''+entries+'''
}
function M.all() return entries end
function M.count() return #entries end
function M.label(index) return index and entries[index].label or "Random (17 cyberpsycho variants)" end
function M.choose(index,previous)
    local choices={}
    for i,entry in ipairs(entries) do
        if (not index or index==i) and TweakDB:GetRecord(TweakDBID.new(entry.base))
            and TweakDB:GetRecord(TweakDBID.new(entry.record)) then choices[#choices+1]=entry end
    end
    if #choices==0 then error("Selected cyberpsycho records unavailable; install the complete variant tweak file") end
    if not index and #choices>1 and previous then
        for i=#choices,1,-1 do if choices[i].record==previous then table.remove(choices,i) end end
    end
    return choices[math.random(1,#choices)]
end
return M
'''
 clause='        return '+('\n            || '.join('Equals(record, t"'+r['record']+'")' for r in rows))+';'
 return {'r6/tweaks/NCPDPatrol_Cyberpsycho.yaml':yaml,'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/cyberpsycho_variants.lua':lua},clause

def main():
 files,clause=outputs()
 for name,text in files.items():(ROOT/name).write_text(text)
 path=ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolCyberpsychoSystem.reds'
 source=path.read_text()
 source,count=re.subn(r'(        // BEGIN GENERATED CYBERPSYCHO ALLOWLIST\n).*?(\n        // END GENERATED CYBERPSYCHO ALLOWLIST)',lambda m:m[1]+clause+m[2],source,flags=re.S)
 assert count==1;path.write_text(source)
 print('Generated 17 verified private cyberpsycho variants and exact native admission gate.')
if __name__=='__main__':main()
