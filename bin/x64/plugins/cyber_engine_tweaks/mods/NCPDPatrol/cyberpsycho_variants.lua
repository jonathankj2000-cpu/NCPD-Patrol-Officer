-- Generated from assets/cyberpsycho/variants.json; do not guess base IDs.
local M = {}
local entries = {
    {record="Character.NCPDPatrol_Cyberpsycho",base="Character.ma_wat_lch_06_cyberpsycho",label="Heavy gunner / strong arms - Little China"},
    {record="Character.NCPDPatrol_CP_ma_bls_ina_se1_07_cyberpsycho_1",base="Character.ma_bls_ina_se1_07_cyberpsycho_1",label="Armored exo - Badlands"},
    {record="Character.NCPDPatrol_CP_ma_bls_ina_se1_08_cyberpsycho",base="Character.ma_bls_ina_se1_08_cyberpsycho",label="Shotgunner - Badlands"},
    {record="Character.NCPDPatrol_CP_ma_bls_ina_se1_22_psycho",base="Character.ma_bls_ina_se1_22_psycho",label="Sniper - Badlands"},
    {record="Character.NCPDPatrol_CP_ma_cct_dtn_03_cyberpsycho",base="Character.ma_cct_dtn_03_cyberpsycho",label="Shotgunner - Downtown"},
    {record="Character.NCPDPatrol_CP_ma_cct_dtn_07_cyberpsycho",base="Character.ma_cct_dtn_07_cyberpsycho",label="Katana / optical camo - Downtown"},
    {record="Character.NCPDPatrol_CP_ma_hey_spr_04_cyberpsycho",base="Character.ma_hey_spr_04_cyberpsycho",label="Fast ranged - Wellsprings A"},
    {record="Character.NCPDPatrol_CP_ma_hey_spr_06_cyberpsycho",base="Character.ma_hey_spr_06_cyberpsycho",label="Fast ranged - Wellsprings B"},
    {record="Character.NCPDPatrol_CP_ma_pac_cvi_08_psycho",base="Character.ma_pac_cvi_08_psycho",label="Shotgunner - Coastview"},
    {record="Character.NCPDPatrol_CP_ma_pac_cvi_15_cyberpsycho",base="Character.ma_pac_cvi_15_cyberpsycho",label="Netrunner - Coastview"},
    {record="Character.NCPDPatrol_CP_ma_std_arr_06_cyberpsycho",base="Character.ma_std_arr_06_cyberpsycho",label="Netrunner - Arroyo"},
    {record="Character.NCPDPatrol_CP_ma_std_rcr_11_cyberpsycho",base="Character.ma_std_rcr_11_cyberpsycho",label="Armored exo - Rancho Coronado"},
    {record="Character.NCPDPatrol_CP_ma_wat_kab_02_cyberpsycho",base="Character.ma_wat_kab_02_cyberpsycho",label="Sniper - Kabuki"},
    {record="Character.NCPDPatrol_CP_ma_wat_kab_08_cyberpsycho",base="Character.ma_wat_kab_08_cyberpsycho",label="Fast melee / strong arms - Kabuki"},
    {record="Character.NCPDPatrol_CP_ma_wat_nid_03_shard_psycho",base="Character.ma_wat_nid_03_shard_psycho",label="Fast melee - Northside"},
    {record="Character.NCPDPatrol_CP_ma_wat_nid_15_psycho",base="Character.ma_wat_nid_15_psycho",label="Mantis blades - Northside"},
    {record="Character.NCPDPatrol_CP_ma_wat_nid_22_monk",base="Character.ma_wat_nid_22_monk",label="Rifleman - Northside"},
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
