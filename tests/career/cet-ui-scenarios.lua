-- Execute the shipped init.lua and click the actual CET controls. Other module
-- display calls and ImGui are boundaries; careerAction is production code.
local f=CareerFixture;f:Reset(0)
local callbacks={};local pressed;local labels={};local spawned=0
local function noop() end
local function display() return 'fixture' end
local function no() return false end
local function zero() return 0 end
local vipRequests,ambushRequests,ambushPreferenceClicks=0,0,0
local backupReleases=0
package.loaded.partner={state=display,activeProfile=display,vehicleState=display,aidState=display,spawn=function() spawned=spawned+1 end}
package.loaded.dispatch={isBusy=no,isAutomatic=no,isSoundEnabled=no,isVoiceEnabled=no,isActive=no,
 cyberpsychoState=display,cyberpsychoDiagnostics=display,
 cyberpsychoVariantState=display,
 vipState=display,vipDiagnostics=display,vipAmbushState=display,
 vipAmbushCars=display,cycleVIPAmbushCars=function() ambushPreferenceClicks=ambushPreferenceClicks+1 end,
 requestVIP=function() vipRequests=vipRequests+1 end,
 requestVIPAmbush=function() ambushRequests=ambushRequests+1 end,
 navigationState=display,state=display,lastOutcome=display,journalDiagnostics=display,hudState=display,
 completed=zero,failedCount=zero,seconds=zero}
package.loaded.vehicle_radio={isEnabled=no,state=display}
package.loaded.backup={state=display,release=function() backupReleases=backupReleases+1 end};package.loaded.arrest={state=display}
package.loaded.trunk={repairSeconds=zero}
function registerForEvent(name,callback) callbacks[name]=callback end
function registerHotkey() end
ImGui={Begin=function() return true end,End=noop,Text=noop,TextWrapped=noop,Separator=noop,
 CollapsingHeader=function() return true end,
 Button=function(label) labels[label]=true;return label==pressed end}
Game.GetScriptableSystemsContainer=function() return {Get=function(_,name)
 if name=='NCPDPatrolCareerSystem' then return Career end
end} end
dofile(MOD_DIR..'/init.lua');callbacks.onOverlayOpen()
local function click(label) pressed=label;callbacks.onDraw();assert(labels[label],'CET button missing: '..label);pressed=nil end
click('TEST: Request VIP transport');click('TEST: Trigger VIP ambush');click('Log VIP diagnostics')
assert(vipRequests==1 and ambushRequests==1)
click('Ambush cars: fixture (change)');assert(ambushPreferenceClicks==1)
click('10-4: Release backup');assert(backupReleases==1)
click('TEST: Unlock all milestones (session)')
assert(Career:IsTestUnlockActive() and Career:GetAvailableRewards()==7 and Core:GetRecordedScannerCount()==0)
assert(#f.itemCalls==0 and #f.vehicleCalls==0)
click('Claim next milestone reward');assert(f.inventory['Items.Helmet_02_basic_01']==1)
click('TEST: Give tiered reward weapons')
assert(f.inventory['Items.Preset_Lexington_Military_NCPDPatrol_Tier2']==1)
assert(f.inventory['Items.Preset_Masamune_Military_NCPDPatrol_Tier3']==1)
assert(f.inventory['Items.Preset_Defender_Military_NCPDPatrol_Tier5']==1)
assert(f.inventory['Items.NCPDBeanBagger_M2038']==1)
assert(Career:GetClaimedRewards()==1 and Core:GetRecordedScannerCount()==0)
click('TEST: Give tiered reward weapons');assert(#f.itemCalls==5)
click('TEST: Give Bean Bagger (Tier 2)');assert(#f.itemCalls==5)
click('Assign MaxTac Netrunner');assert(Career:GetSelectedPartnerIndex()==3 and spawned==0)
click('Clear test unlocks')
assert(not Career:IsTestUnlockActive() and Career:GetSelectedPartnerIndex()==0 and Career:GetAvailableRewards()==0)
click('LOCKED: MaxTac Netrunner');assert(Career:GetSelectedPartnerIndex()==0 and spawned==0)
f:Reset(0)
click('TEST: Give Bean Bagger (Tier 2)')
assert(f.inventory['Items.NCPDBeanBagger_M2038']==1 and not Career:IsTestUnlockActive())
assert(Career.m_issuedRewards.n==0 and Core:GetRecordedScannerCount()==0 and #f.itemCalls==1)
click('TEST: Give Bean Bagger (Tier 2)');assert(#f.itemCalls==1)
