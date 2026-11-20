-- API boundaries only; the selector and two-metre navigation matcher are real.
RouteTest={point={x=0,y=0,z=10},pins={},requests={},scope=8,serial=0,reads=0}
local f=RouteTest
Vector4={new=function(x,y,z,w) return {x=x,y=y,z=z,w=w,X=x,Y=y,Z=z,W=w} end}
gamedataMappinVariant={GangWatchVariant='assault',OutpostVariant='outpost',FastTravelVariant='fasttravel',ServicePointDropPointVariant='drop-point'}
gamedataMappinPhase={CompletedPhase='complete'}
f.player={GetWorldPosition=function() return f.point end}
f.map={GetAllMappins=function() f.reads=f.reads+1;return f.pins end}
function f:Pin(x,y,z,variant,phase)
    return {GetVariant=function() return variant end,GetPhase=function() return phase end,
        GetWorldPosition=function() return Vector4.new(x,y,z,1) end,
        IsActive=function() error('VIP selection read FT interaction availability') end}
end
f.backend={Version=function() return 4 end,GetScope=function() return f.scope end,
    Request=function(_,site,point)
        assert(site>0,'Baked route reached off-catalog fallback')
        f.serial=f.serial+1;f.requests[#f.requests+1]={site=site,point=point};return f.serial
    end}
Game={GetMappinSystem=function() return f.map end,
    GetScriptableSystemsContainer=function() return {Get=function(_,name)
        assert(name=='NCPDPatrolFixedMarkerSystem');return f.backend
    end} end}
