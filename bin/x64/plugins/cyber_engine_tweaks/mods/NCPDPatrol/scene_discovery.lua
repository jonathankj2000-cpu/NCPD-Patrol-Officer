-- Off-duty dataset search. No quest, reward, dispatch, actor or teleport calls.
-- The existing survey runner owns all movement, spawning and cleanup.
local Anchors=require('scene_discovery_sites')
local Evidence=require('scene_survey_store')
local Approved=require('officer_down_sites')
local M={logFile='scene_discovery_results.jsonl',exportFile='scene_discovery_report.json'}
local radii={10,20,30}
local headings={0,90,180,270,45,135,225,315}
local function copy(p) return {x=p.x,y=p.y,z=p.z} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function nearby(a,b,metres)
    return (a.x-b.x)^2+(a.y-b.y)^2<=metres^2 and math.abs(a.z-b.z)<=1
end
local function round(v) return math.floor(v*1000000+.5)/1000000 end
function M.new()
    local all,byID,sourceFor={}, {}, {}
    local offsets={}
    for _,anchor in ipairs(Anchors.sites) do
        all[#all+1]=anchor;sourceFor[anchor.id]=anchor;byID[anchor.id]=anchor;offsets[anchor.id]={}
        for _,radius in ipairs(radii) do
            for bearing=0,315,45 do
                local a=math.rad(bearing)
                local candidate={id=anchor.id..'_r'..radius..'_b'..bearing,label=anchor.label..' + '..radius..' m / '..bearing..' deg',
                    x=round(anchor.x+math.cos(a)*radius),y=round(anchor.y+math.sin(a)*radius),z=anchor.z,heading=0,
                    anchor_id=anchor.id,source_index=anchor.source_index,radius=radius,bearing=bearing}
                all[#all+1]=candidate;byID[candidate.id]=candidate;sourceFor[candidate.id]=anchor
                offsets[anchor.id][#offsets[anchor.id]+1]=candidate
            end
        end
    end
    local catalogue={revision=Anchors.revision..'/offset-search-v1',coverage=Anchors.coverage,sites=all}
    local state={anchor=nil,variant=nil,cursor=0,attempts=0,passes=2,posesPerPass=24*#headings}
    local function winners(store)
        local found={}
        for _,row in pairs(store.functionalBest) do
            local anchor=sourceFor[row.site]
            if anchor and row.status=='validated' then
                local key=anchor.id..'/'..row.variant
                if not found[key] or (tonumber(row.discovery_order) or 0)>(tonumber(found[key].discovery_order) or 0) then found[key]=row end
            end
        end
        return found
    end
    local store=Evidence.new({catalog=catalogue,logFile=M.logFile,exportFile=M.exportFile,
        groundedOffsets=true,onlyTested=true,decorate=function(report,self)
            local found=winners(self);local verified={}
            for _,anchor in ipairs(Anchors.sites) do
                for _,variant in ipairs({'compact','standard'}) do
                    local row=found[anchor.id..'/'..variant]
                    if row then
                        local nominal=byID[row.site]
                        verified[#verified+1]={id=row.site,anchor_id=anchor.id,source_index=anchor.source_index,
                            source_id=anchor.source_id,label=anchor.label,district=anchor.district,variant=variant,
                            position=copy(row.position),heading=row.heading,radius=nominal.radius,bearing=nominal.bearing,
                            nominal_position=copy(nominal),anchor_position=copy(anchor),cleanup_confirmed=row.cleanup_confirmed,
                            observed_seconds=row.observed_seconds,samples=row.samples,functional_validation=row.functional_validation}
                    end
                end
            end
            report.tool='Officer Down terminal-offset discovery'
            report.search={anchors=#Anchors.sites,radii_metres=radii,bearings=8,headings=headings,passes=2,
                original_approved_dispatch_sites=#Approved.sites,production_sites_changed=false}
            report.verified_candidates=verified;report.verified_count=#verified
            report.event_count=#self.events;report.events=nil
            report.scope='Developer placement evidence only. Full ten-actor/aid-access test, no actual combat or revive. Not a production dispatch catalogue.'
        end})
    local append=store.append
    function store:append(row)
        self:load();row.discovery_order=#self.events+1
        return append(self,row)
    end
    function store:needsTest(site,variant)
        self:load();return winners(self)[site.id..'/'..variant]==nil
    end
    function store:count(variant,profile)
        if profile and profile~='injured-functional-v1' then return 0 end
        local n=0
        for key in pairs(winners(self)) do if key:sub(-#variant-1)=='/'..variant then n=n+1 end end
        return n
    end
    local self={catalog={revision=catalogue.revision,coverage=Anchors.coverage,sites=Anchors.sites},store=store,
        logFile=M.logFile,exportFile=M.exportFile,interval=.1}
    function self:queue(requestedVariant,onlyUnverified,scope)
        local ordered={};for _,anchor in ipairs(Anchors.sites) do ordered[#ordered+1]=anchor end
        if scope=='nearby' then
            local p=Game.GetPlayer():GetWorldPosition()
            table.sort(ordered,function(a,b) local da,db=distance(a,p),distance(b,p);return da==db and a.id<b.id or da<db end)
        end
        local queue={}
        for i,anchor in ipairs(ordered) do
            if scope~='nearby' or i<=3 then
                for _,variant in ipairs(requestedVariant=='both' and {'compact','standard'} or {requestedVariant}) do
                    if not onlyUnverified or store:needsTest(anchor,variant) then
                        local row={};for k,v in pairs(anchor) do row[k]=v end
                        row.variant=variant;queue[#queue+1]=row
                    end
                end
            end
        end
        return queue
    end
    function self:begin(anchor,variant)
        state.anchor,state.variant,state.cursor,state.attempts=anchor,variant,0,0
    end
    function self:next()
        if state.cursor>=state.posesPerPass*state.passes then return nil end
        local cursor=state.cursor;state.cursor=cursor+1;state.attempts=state.attempts+1
        local pose=cursor%state.posesPerPass
        return offsets[state.anchor.id][math.floor(pose/#headings)+1],headings[pose%#headings+1],math.floor(cursor/state.posesPerPass)+1
    end
    function self:grounded(candidate,landing)
        local site={};for k,v in pairs(candidate) do site[k]=v end
        site.x,site.y,site.z=landing.x,landing.y,landing.z-.1
        if (site.x-candidate.x)^2+(site.y-candidate.y)^2>.25 or math.abs(site.z-candidate.z)>1.3 then return nil end
        return site
    end
    function self:duplicate(site,variant)
        if variant=='compact' then
            for _,old in ipairs(Approved.sites) do if old.enabled and nearby(site,old,5) then return 'Existing approved site '..old.id end end
        end
        for _,row in pairs(store.functionalBest) do
            if row.variant==variant and sourceFor[row.site] and sourceFor[row.site].id~=state.anchor.id
                and nearby(site,row.position,10) then return 'Nearby verified discovery '..row.site end
        end
    end
    function self:progress()
        return tostring(state.attempts)..'/'..(state.posesPerPass*state.passes)..' geometric poses | compact='..store:count('compact')..'/60 | standard='..store:count('standard')..'/60'
    end
    return self
end
return M
