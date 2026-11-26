-- Append-only gameplay evidence, independent of survey results and payouts.
-- Only per-site aggregates are retained in memory; raw history stays on disk.
local Catalog=require('officer_down_sites')
local M={file='officer_down_dispatch.jsonl',reportFile='officer_down_dispatch_report.json'}
local loaded,total,ignored,serial=false,0,0,0
local stats,lastError,lastPrinted={},nil,nil
local counted={assigned=true,spawn_created=true,ready=true,arrived=true,revived=true,
    completed=true,failed=true,cancelled=true,interrupted=true,cleanup_confirmed=true,recovered_cleanup=true}
local function accept(row)
    if type(row)~='table' or row.schema~=1 or type(row.kind)~='string' or type(row.site)~='string' then return false end
    total=total+1
    if counted[row.kind] then
        local s=stats[row.site] or {site=row.site};stats[row.site]=s
        s[row.kind]=(s[row.kind] or 0)+1;s.last_run=row.run;s.last_timestamp=row.timestamp;s.last_kind=row.kind
        if row.kind=='failed' or row.kind=='interrupted' then s.last_failure=row.details end
    end
    return true
end
local function load()
    if loaded then return end
    if not json or not json.encode or not json.decode or not io or not io.open then error('CET JSON/file services unavailable') end
    local file=io.open(M.file,'r')
    if file then
        for line in file:lines() do
            if line:match('%S') then
                local ok,row=pcall(json.decode,line)
                if not ok or not accept(row) then ignored=ignored+1 end
            end
        end
        file:close()
    end
    loaded=true
end
local function fault(reason,status)
    lastError=tostring(reason)
    if status and lastPrinted~=lastError then status('Officer Down logging | '..lastError);lastPrinted=lastError end
end
function M.newRun()
    pcall(load);serial=serial+1
    return ((os and os.date) and os.date('!%Y%m%dT%H%M%S') or 'run')..'-'..(total+serial)
end
function M.event(run,site,kind,details,status)
    local ok,reason=pcall(function()
        load()
        local row={schema=1,run=run,site=site and site.id or 'none',catalog_revision=Catalog.revision,kind=kind,
            timestamp=(os and os.date) and os.date('!%Y-%m-%dT%H:%M:%SZ') or 'time unavailable',details=details or {}}
        local body=json.encode(row)
        local file,why=io.open(M.file,'a');if not file then error('Cannot append Officer Down log: '..tostring(why)) end
        local wrote,result=pcall(function() assert(file:write('\n'..body..'\n'));assert(file:flush());return file:close() end)
        if not wrote or not result then pcall(function() file:close() end);error('Officer Down log write failed: '..tostring(result)) end
        assert(accept(row),'Officer Down log schema rejected')
    end)
    if not ok then fault(reason,status) end
    return ok
end
function M.state() return 'Gameplay log: '..M.file..' | loaded='..tostring(loaded)..' | records='..total..' | ignored='..ignored..' | error='..tostring(lastError or 'none') end
function M.export(status)
    local ok,reason=pcall(function()
        load()
        local rows={}
        for _,site in ipairs(Catalog.sites) do
            rows[#rows+1]={site=site.id,label=site.label,position={x=site.x,y=site.y,z=site.z},preferred_heading=site.heading,
                enabled=site.enabled,statistics=stats[site.id] or {site=site.id}}
        end
        local report={schema=1,catalog_revision=Catalog.revision,coverage=Catalog.coverage,log_file=M.file,
            records=total,ignored_lines=ignored,sites=rows,last_logging_error=lastError,
            scope='Observed gameplay attempts and lifecycle outcomes; survey proof and payment ledgers are separate'}
        local file,why=io.open(M.reportFile,'w');if not file then error(why) end
        local wrote,result=pcall(function() assert(file:write(json.encode(report)));assert(file:flush());return file:close() end)
        if not wrote or not result then pcall(function() file:close() end);error('Officer Down report write failed') end
        return M.reportFile
    end)
    if not ok then fault(reason,status) elseif status then status('Officer Down report exported: '..reason) end
    return ok
end
return M
