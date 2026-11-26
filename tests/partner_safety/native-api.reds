// Offline signatures only, never installed. In-Question/MOD_Development_Reference
// 81d996b584a693e8b0f0b20526a9fa38b5c83fe7: core/gameplay/vehicles.swift,
// core/entity/gameObject.swift, NPC/NPCPuppet.swift and game definitions.
// Affiliation enum values are placeholders; production uses symbolic names.
public enum gamedataAffiliation { NCPD = 1, Other = 2 }
public native class Affiliation_Record extends IScriptable {
    public native const func Type() -> gamedataAffiliation;
}
@addMethod(Vehicle_Record)
public native const func Affiliation() -> wref<Affiliation_Record>;
@addMethod(VehicleObject)
public native const func IsPrevention() -> Bool;
@addMethod(GameObject)
public final static native func GetAttitudeTowards(const first: ref<GameObject>, const second: ref<GameObject>) -> EAIAttitude;
@addMethod(VehicleObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool { return false; }
@addMethod(NPCPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool { return false; }
// GameObject.swift:984, orphans.swift:11353/22383/22401/22415,
// attackData.swift:204/252. These are source methods, not RTTI-only imports.
@addMethod(GameObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool { return false; }
@addMethod(GameInstance)
public final static native func GetSimTime(game: GameInstance) -> EngineTime;
@addMethod(GameInstance)
public final static native func GetTargetingSystem(game: GameInstance) -> ref<TargetingSystem>;
public native class IAttack extends IScriptable {}
public native class TargetingSystem extends IScriptable {
    public final native func GetLookAtObject(instigator: wref<GameObject>, opt withLOS: Bool, opt ignoreTranparent: Bool) -> ref<GameObject>;
    public final native func GetTrackedTargetObject(instigator: wref<GameObject>) -> ref<GameObject>;
}
