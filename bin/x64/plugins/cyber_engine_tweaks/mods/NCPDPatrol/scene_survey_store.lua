-- Append-only evidence survives interruption. A JSON export is derived from it;
-- only matching site/catalog/layout revisions may provide a preferred heading.
local Catalog=require('scene_survey_sites')
local Layout=require('officer_down_layout')
local M={logFile='scene_survey_results.jsonl',exportFile='scene_survey_report.json'}
local known={};for _,site in ipairs(Catalog.sites) do known[site.id]=site end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<100000 end
function M.new()
    local self={loaded=false,last={},best={},pilotLast={},pilotBest={},placementLast={},placementBest={},functionalLast={},functionalBest={},events={},ignored=0}
    local function accept(row)
        if type(row)~='table' or row.schema~=1 then return false end
        if row.kind~='site_result' then return true end
        local site=known[row.site]
        if not site or row.catalog_revision~=Catalog.revision or row.layout_revision~=Layout.revision
            or (row.variant~='compact' and row.variant~='standard') or type(row.position)~='table'
            or row.position.x~=site.x or row.position.y~=site.y or row.position.z~=site.z then return false end
        local key=row.site..'/'..row.variant
        local profile=row.validation_profile or 'legacy-immediate-v1'
        if profile~='legacy-immediate-v1' and profile~='injured-settling-pilot-v1' and profile~='injured-staging-pilot-v1' and profile~='injured-functional-v1' then return false end
        local latest,best=self.last,self.best
        if profile=='injured-settling-pilot-v1' then latest,best=self.pilotLast,self.pilotBest end
        if profile=='injured-staging-pilot-v1' then latest,best=self.placementLast,self.placementBest end
        if profile=='injured-functional-v1' then latest,best=self.functionalLast,self.functionalBest end
        if row.status=='validated' then
            if not finite(row.heading) or row.heading<0 or row.heading>=360 or row.cleanup_confirmed~=true
                or type(row.samples)~='table' or #row.samples~=10 or not finite(row.observed_seconds) or row.observed_seconds<3 then return false end
            if (profile=='injured-settling-pilot-v1' or profile=='injured-staging-pilot-v1') and (row.pilot_settling_seconds~=4
                or not finite(row.maximum_observation_drift) or row.maximum_observation_drift>.15) then return false end
            if profile=='injured-staging-pilot-v1' and (row.placement_release_seconds~=.5
                or not finite(row.placement_corrections) or row.placement_corrections<0
                or row.placement_corrections%1~=0) then return false end
            if profile=='injured-functional-v1' then
                local proof=row.functional_validation
                if type(proof)~='table' or proof.ground_supported~=true or proof.static_clear~=true or proof.vehicle_clear~=true
                    or proof.aid_state_ready~=true or proof.path_confirmed~=true or proof.revive_executed~=false
                    or not finite(proof.ready_seconds) or proof.ready_seconds<3
                    or not finite(proof.aid_distance) or proof.aid_distance<0 or proof.aid_distance>2.5
                    or not finite(proof.scene_distance) or proof.scene_distance<0 or proof.scene_distance>25 or proof.scene_radius~=25
                    or type(proof.actual_position)~='table' or type(proof.assistance_position)~='table' then return false end
                for _,p in ipairs({proof.actual_position,proof.assistance_position}) do
                    if type(p)~='table' or not finite(p.x) or not finite(p.y) or not finite(p.z) then return false end
                end
            end
            best[key]=row
        elseif row.status~='unverified' and row.status~='failed' and row.status~='cancelled' then return false end
        latest[key]=row
        return true
    end
    function self:load()
        if self.loaded then return end
        if not json or not json.decode or not json.encode or not io or not io.open then error('CET JSON/file services unavailable') end
        local file=io.open(M.logFile,'r')
        if file then
            for line in file:lines() do
                if line:match('%S') then
                    local ok,row=pcall(json.decode,line)
                    if ok and accept(row) then self.events[#self.events+1]=row else self.ignored=self.ignored+1 end
                end
            end
            file:close()
        end
        self.loaded=true
    end
    function self:append(row)
        self:load()
        row.schema=1
        row.timestamp=(os and os.date) and os.date('!%Y-%m-%dT%H:%M:%SZ') or 'time unavailable'
        local body=json.encode(row)
        local file,reason=io.open(M.logFile,'a')
        if not file then error('Cannot append survey evidence: '..tostring(reason)) end
        -- Leading newline separates any truncated tail from a previous crash.
        local ok,result=pcall(function() assert(file:write('\n'..body..'\n'));assert(file:flush());return file:close() end)
        if not ok or result==nil or result==false then pcall(function() file:close() end);error('Survey evidence write/flush failed: '..tostring(result)) end
        if not accept(row) then error('Survey evidence failed schema/revision validation') end
        self.events[#self.events+1]=row
    end
    function self:preferred(site,variant,profile)
        self:load();local key=site.id..'/'..variant
        local row=(profile=='injured-functional-v1' and self.functionalBest[key])
            or (profile=='injured-staging-pilot-v1' and self.placementBest[key])
            or (profile=='injured-settling-pilot-v1' and self.pilotBest[key]) or self.best[key]
        return row and row.heading or nil
    end
    function self:needsTest(site,variant,profile)
        self:load();local rows=profile=='injured-functional-v1' and self.functionalLast or self.last
        local row=rows[site.id..'/'..variant]
        return not row or row.status~='validated'
    end
    function self:count(variant,profile)
        local count=0
        local best=profile=='injured-functional-v1' and self.functionalBest or (profile=='injured-staging-pilot-v1' and self.placementBest
            or (profile=='injured-settling-pilot-v1' and self.pilotBest or self.best)
        )
        for _,site in ipairs(Catalog.sites) do if best[site.id..'/'..variant] then count=count+1 end end
        return count
    end
    function self:export(profile)
        self:load()
        local functional=profile=='injured-functional-v1'
        local selectedLast,selectedBest=self.last,self.best
        if functional then selectedLast,selectedBest=self.functionalLast,self.functionalBest end
        local rows={}
        for _,site in ipairs(Catalog.sites) do
            for _,variant in ipairs({'compact','standard'}) do
                local key=site.id..'/'..variant
                rows[#rows+1]={site=site.id,label=site.label,variant=variant,position={x=site.x,y=site.y,z=site.z},captured_heading=site.heading,
                    latest=selectedLast[key] or {status='untested'},proven=selectedBest[key] or false,
                    legacy_latest=self.last[key] or {status='untested'},legacy_proven=self.best[key] or false,
                    injured_settling_pilot_latest=self.pilotLast[key] or {status='untested'},injured_settling_pilot_proven=self.pilotBest[key] or false,
                    injured_placement_pilot_latest=self.placementLast[key] or {status='untested'},injured_placement_pilot_proven=self.placementBest[key] or false,
                    injured_functional_latest=self.functionalLast[key] or {status='untested'},injured_functional_proven=self.functionalBest[key] or false}
            end
        end
        local report={schema=1,catalog_revision=Catalog.revision,layout_revision=Layout.revision,coverage=Catalog.coverage,
            default_validation_profile='injured-functional-v1',
            primary_validation_profile=functional and 'injured-functional-v1' or 'legacy-immediate-v1',
            scope='Actual ten-actor spawn; functional profile checks injured ground/clearance and reachable aid position. Combat and actual revive execution not tested',
            sites=rows,events=self.events,ignored_or_incompatible_lines=self.ignored,
            validation_profiles={legacy='Original immediate 1.5 m survey',pilot='Opt-in 4 s injured settling, then unchanged 1.5 m bound, local support/clearance and 3 s stable observation; separate results',
                placement='Opt-in production-style injured correction for 4 s, then corrections disabled, 0.5 s release and 3 s stable observation within original 1.5 m; separate results',
                functional='Default full tours: injured displacement informational; actual supported/clear space and complete walking route to a 2.5 m aid position usable for 3 s; 25 m incident area; no corrections'}}
        local file,reason=io.open(M.exportFile,'w')
        if not file then error('Cannot export survey report: '..tostring(reason)) end
        local ok,result=pcall(function() assert(file:write(json.encode(report)));assert(file:flush());return file:close() end)
        if not ok or result==nil or result==false then pcall(function() file:close() end);error('Survey export failed: '..tostring(result)) end
        return M.exportFile
    end
    return self
end
return M
