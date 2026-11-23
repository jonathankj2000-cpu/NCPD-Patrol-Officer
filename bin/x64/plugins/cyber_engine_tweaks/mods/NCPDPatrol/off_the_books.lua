-- Separate, durable off-duty quest. Never owns a dispatch reservation or pays
-- scanner/career rewards. Native facts + saved dynamic entities own progress.
local M={}
local TAG='ncpd_patrol_off_the_books'
local SITE={x=-649.795,y=929.771,z=9.400}
local ROLES={
    {role='target',record='Character.NCPDPatrol_VossContractor01',x=-649.795,y=929.771,z=9.400,yaw=-170.762,appearance='citizen__arasaka_corpo_ma_corporate_01_1'},
    {role='guard1',record='Character.NCPDPatrol_VossGuard01',x=-648.602,y=933.895,z=9.400,yaw=98.288},
    {role='guard2',record='Character.NCPDPatrol_VossGuard02',x=-648.041,y=930.799,z=9.400,yaw=98.838},
}
local context,rows,retired={},{},{}
local recover,cleanupPending=true,false
local poll,stable,missing,age=0,0,0,0
local label='Off the Books: finish Voss\'s briefing to begin.'
local lastError,lastStage=nil,nil
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function ready() return context.worldReady and context.worldReady() end
local function say(text,status)
    label=text;local output=status or context.status
    if output then output('Off the Books | '..text) end
end
local function owner()
    local box=Game.GetScriptableSystemsContainer()
    local n=box and box:Get('NCPDPatrolOffBooksSystem')
    if not n or n:Version()~=1 then error('Install the complete v0.20a Off the Books package and restart the game') end
    return n
end
local function system()
    local s=Game.GetDynamicEntitySystem()
    if not s or not s:IsReady() then return nil end
    -- IsRestored reports load vs new game, not restore completion. Existing
    -- world-ready/stable-frame gates work for both fresh and loaded worlds.
    return s
end
local function definition(role)
    for _,v in ipairs(ROLES) do if role==v.role then return v end end
end
local function collect()
    local s=system();if not s then return false end
    local current={}
    for _,def in ipairs(ROLES) do
        local found={}
        for _,id in ipairs(s:GetTaggedIDs(CName.new(TAG..'_'..def.role))) do
            if s:IsManaged(id) and not retired[tostring(id.hash)] then
                if not s:IsTagged(id,CName.new(TAG)) then error('Refusing an encounter role without its private ownership tag') end
                found[#found+1]=id
            end
        end
        if #found>1 then error('Duplicate saved '..def.role..' actors; clear this test before retrying') end
        local old=rows[def.role]
        if #found==1 then
            local same=old and old.id.hash==found[1].hash
            current[def.role]={id=found[1],definition=def,accepted=same and old.accepted,
                object=same and old.object,bound=same and old.bound,seeded=same and old.seeded}
        elseif old and old.accepted and ((old.object and old.object:IsAttached()) or s:IsSpawning(old.id)) then
            current[def.role]=old -- accepted deletion is not proof of physical detach
        end
    end
    rows=current;return true
end
local function cleanup()
    local s=system();if not s or not collect() then return false end
    local pending=false
    for _,row in pairs(rows) do
        local object=s:GetEntity(row.id) or row.object
        row.object=object
        if object and object:IsAttached() then
            if object:GetRecordID()~=TweakDBID.new(row.definition.record) then error('Unexpected record on an owned encounter tag; actor retained') end
            local scene=Game.GetSceneSystem():GetScriptInterface()
            if scene:IsEntityInScene(row.id) then pending=true;row.blocked=true else row.blocked=false end
        end
        if not row.blocked then
            if not row.accepted then row.accepted=s:DeleteEntity(row.id)==true end
            if s:IsSpawning(row.id) or (object and object:IsAttached()) or s:IsManaged(row.id) then pending=true
            else retired[tostring(row.id.hash)]=true end
        end
    end
    cleanupPending=pending
    return not pending
end
local function ground(p,player)
    local spatial=Game.GetSpatialQueriesSystem();local nav=Game.GetAINavigationSystem()
    if not spatial or not nav then error('Ground/navigation service unavailable') end
    local hit,data=spatial:SyncRaycastByCollisionGroup(Vector4.new(p.x,p.y,p.z+1.5,1),Vector4.new(p.x,p.y,p.z-1.5,1),CName.new('Static'),true,false)
    if not hit or not data or not data.position or not data.normal or data.normal.z<.80
        or math.abs(data.position.z-p.z)>1.5 then error('The recorded '..p.role..' position has no supported floor; move closer and retry') end
    local at=Vector4.new(data.position.x,data.position.y,data.position.z,1)
    if spatial:SyncRaycastByCollisionGroup(Vector4.new(at.x,at.y,at.z+.15,1),Vector4.new(at.x,at.y,at.z+1.85,1),CName.new('Static'),true,false) then
        error('Static obstruction at '..p.role..'; scene not spawned')
    end
    local route=nav:FindPointInSphereForCharacter(at,.8,player)
    if not route or route.status~=worldNavigationRequestStatus.OK or not route.point or distance(route.point,at)>.8 then
        error('No nearby character navigation at '..p.role..'; scene not spawned')
    end
    return at
end
local function spawnMissing(n,player)
    local s=system();if not s or not collect() then return end
    local cycle=n:GetCycle();local plan={}
    for _,def in ipairs(ROLES) do
        if not rows[def.role] then
            if n:WasCreated(CName.new(def.role)) then
                -- Missing live references are not proof that a saved actor
                -- should be recreated. Never resurrect a killed contractor.
                if def.role=='target' and n:TargetDead() then return end
                error('Saved '..def.role..' is still restoring or unavailable; no duplicate was spawned')
            end
            plan[#plan+1]={definition=def,position=ground(def,player)}
        end
    end
    for _,p in ipairs(plan) do
        local def=p.definition
        local spec=DynamicEntitySpec.new();spec.recordID=TweakDBID.new(def.record)
        spec.position=p.position;spec.orientation=EulerAngles.new(0,0,def.yaw):ToQuat()
        spec.persistState=true;spec.persistSpawn=true;spec.alwaysSpawned=false
        spec.spawnInView=true;spec.active=true;spec.tags={CName.new(TAG),CName.new(TAG..'_'..def.role)}
        if def.appearance then spec.appearanceName=CName.new(def.appearance) end
        local id=s:CreateEntity(spec)
        if not id or id.hash==0 then error('Creation failed at '..def.role..'; existing owned actors were retained') end
        rows[def.role]={id=id,definition=def}
        if not n:MarkCreated(CName.new(def.role),cycle) then
            s:DeleteEntity(id);error('Quest changed during spawning; stale actor rejected')
        end
    end
    if #plan>0 then say('Contractor and two guards requested at Cherry Blossom Market.') end
end
function M.configure(value) context=value or {};recover=true end
function M.state() return label end
function M.active()
    local ok,value=pcall(function() return owner():IsActive() end)
    return ok and value==true
end
function M.blocksDuty()
    local ok,value=pcall(function() return owner():BlocksDuty() end)
    return ok and value==true
end
function M.keepVoss() return M.active() end
function M.reset()
    -- Forget only this world's handles. Native facts, inventory and registered
    -- persistent spawns survive save/load, death and shift-session resets.
    rows,retired={},{};recover=true;cleanupPending=false
    poll,stable,missing,age=0,0,0,0;lastError,lastStage=nil,nil
end
function M.begin(status)
    local ok,result=pcall(function()
        if not ready() or not system() then error('Load a save before continuing Off the Books') end
        if recover then error('Wait for the current game session to finish restoring before this test') end
        local n=owner()
        if n:IsActive() then say('The operation is already active.',status);return true end
        if context.onDuty and context.onDuty() then error('Go OFF DUTY before this operation') end
        if not collect() or next(rows) or cleanupPending then error('Previous encounter cleanup must finish before a new test') end
        if not n:RecordsReady() then error('Required contractor/guard/shard records or Read action unavailable in TweakDB; install the complete package') end
        if not n:Begin() then error('Finish Voss\'s briefing first; ensure the Off the Books journal is installed and close menus') end
        recover=false;stable=0;age=0;lastError=nil
        say('Off-duty operation assigned. Eliminate the contractor and retrieve his encrypted shard.',status)
        return true
    end)
    if not ok then say(tostring(result),status);return false end
    return result
end
function M.clear(status)
    if not ready() then say('Load a save before clearing this test.',status);return false end
    local ok,err=pcall(function() owner():Cancel();cleanupPending=true;collect() end)
    if not ok then say(tostring(err),status);return false end
    say('Test cancellation requested; native shard history is retained. Owned encounter cleanup is pending.',status)
    return true
end
local function update(delta)
    if not ready() or delta<=0 or delta>.5 then return end
    local s=system();if not s then return end
    local ok,n=pcall(owner);if not ok then return end -- passive until this optional quest bridge is available
    if n:IsMenuOpen() then return end
    stable=stable+delta;poll=poll+delta;age=age+delta
    if stable<1.0 then return end
    if recover then
        if not collect() then return end
        recover=false;cleanupPending=not n:IsActive() and next(rows)~=nil
    end
    if cleanupPending then
        if poll>=.25 then poll=0;if cleanup() then say('Encounter cleared. You may continue after the existing Voss briefing again.') end end
        return
    end
    if not n:IsActive() then return end
    local player=Game.GetPlayer();if not player or not player:IsAttached() or player:IsDead() then return end
    if poll>=.25 then
        poll=0
        n:Tick(.25)
        if distance(player:GetWorldPosition(),SITE)<=140 and n:GetStage()<=2 and n:ObjectiveVisible() then spawnMissing(n,player) else collect() end
        local stage=n:GetStage()
        if stage~=lastStage then
            lastStage=stage
            say(({[1]='Eliminate the Arasaka contractor.',[2]='Contractor eliminated. Retrieve the encrypted data shard from his loot.',
                [3]='Evidence secured. Lose the NCPD.',[4]='Evidence secured. Return to Lieutenant Mara Voss.'})[stage] or 'Operation state updated.')
        end
    end
    -- Bind attached actors without waiting for the next quarter-second poll.
    -- An unloaded saved actor stays managed; re-entry enables the same ID.
    for _,row in pairs(rows) do
        local object=s:GetEntity(row.id)
        if object and object:IsAttached() then
            row.object=object
            if object:GetRecordID()~=TweakDBID.new(row.definition.record) then error('Unexpected encounter record; state retained') end
            if row.bound~=object then
                if n:BindActor(CName.new(row.definition.role),object,n:GetCycle()) then row.bound=object end
            end
            if row.bound and row.definition.role=='target' and not row.seeded then
                row.seeded=n:SeedEvidence()
                if not row.seeded and age>10 and not n:HasEvidence() then
                    error('Evidence could not be placed in the contractor\'s native inventory; no automatic player grant was made')
                end
            end
        elseif distance(player:GetWorldPosition(),SITE)<=140 and not s:IsSpawning(row.id) then
            s:EnableEntity(row.id)
        end
    end
    if n:GetStage()==4 and context.voss then
        local voss=context.voss()
        if voss and n:AtVoss(voss) and label~='At Voss. Evidence secured; ready for the return conversation.' then
            say('At Voss. Evidence secured; ready for the return conversation.')
        end
    end
end
function M.update(delta)
    local ok,err=pcall(update,delta)
    if not ok and lastError~=tostring(err) then lastError=tostring(err);say(tostring(err)) end
end
function M.diagnostics()
    local ok,value=pcall(function() return owner():GetDiagnostics() end)
    local count=0;for _ in pairs(rows) do count=count+1 end
    return 'managed roles='..count..' | cleanup='..tostring(cleanupPending)..' | '..(ok and value or tostring(value))..' | '..label
end
function M.shutdown() end -- durable quest/spawns are intentionally not cancelled
return M
