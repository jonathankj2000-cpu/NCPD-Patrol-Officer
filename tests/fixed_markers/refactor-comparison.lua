-- Compare actual r5c with the extraction, including complete diagnostic text.
-- Every observation is read-only; transitions are driven by the original owner.
local rows={}
local function observe(label)
 local before={Native.m_revision,#F.writes,#F.nodes,#F.deleted,F.activationWrites,F.fallbackCreates}
 local current=Native:GetDiagnostics()
 local evidence=Native:NativeEvidence()
 local previous=Native:GetLastNativeProbe()
 assert(Native.m_revision==before[1] and #F.writes==before[2] and #F.nodes==before[3]
  and #F.deleted==before[4] and F.activationWrites==before[5] and F.fallbackCreates==before[6], 'diagnostic read changed marker state')
 rows[#rows+1]=label..'|'..current..'|'..evidence..'|'..previous
 for i,v in ipairs(before) do rows[#rows+1]=label..'|counter'..i..'='..v end
 for i=0,F.pins.n-1 do
  local p=F.pins[i]
  rows[#rows+1]=label..'|pin='..p.id..'/'..tostring(p.hash)..'/'..tostring(p.active)
 end
end
local function ticks(count,label)
 for i=1,count do Native:Tick(.25);observe(label..i) end
end
for scope=0,9 do
 F:Reset(scope);F.materialize=true
 local site=scope<6 and 40 or 204
 local p=Sites[site].position
 local token=Native:Request(site,Vector4.new(p.x,p.y,p.z,1))
 ticks(26,'active'..scope..'/')
 assert(Native.m_confirmed and not Native.m_fallback)
 Native:Stop(token+100);ticks(1,'stale/')
 Native:Stop(token);ticks(3,'closed/')
end
F:Reset(3);F.hideSitePins=true;Native:OnRestored(0,0);ticks(40,'late-restore/')
F.hideSitePins=false;F.materialize=true
local p=Sites[40].position
Native:Request(40,Vector4.new(p.x,p.y,p.z,1));ticks(26,'late-active/')
F:Emit('Session/BeforeEnd');ticks(3,'unavailable/')
F:Reset(8);p=Sites[204].position
local token=Native:Request(204,Vector4.new(p.x,p.y,p.z,1));ticks(28,'fallback/')
F.failDelete=true;Native:Stop(token);ticks(3,'fallback-retained/')
F.failDelete=false;ticks(3,'fallback-closed/')
return rows
