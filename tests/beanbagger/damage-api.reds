// Offline signatures only; NEVER installed. Source: damageManager.swift,
// attackData.swift, hitReactionComponent.swift, NPCPuppet.swift and native
// gameeventsHitEvent/gameAttackComputed/ItemID definitions.
public enum gamedataAttackType { Ranged = 10, Explosion = 3, QuickMelee = 9 }
public enum hitFlag { Kill = 14, DealNoDamage = 16, Nonlethal = 22, DoNotTriggerFinisher = 30, ForceDismember = 100010 }
public native class AttackData extends IScriptable {
 public native const func GetInstigator() -> wref<GameObject>;
 public native const func GetWeapon() -> wref<WeaponObject>;
 public native const func GetAttackType() -> gamedataAttackType;
 public native func AddFlag(flag: hitFlag, sourceName: CName) -> Void;
 public native func RemoveFlag(flag: hitFlag) -> Void;
 public static native func IsRangedOnly(attackType: gamedataAttackType) -> Bool;
}
public native class gameAttackComputed extends IScriptable {
 public native func MultAttackValue(value: Float) -> Void;
}
public native class gameHitEvent extends Event {
 public let attackData: ref<AttackData>;
 public let attackComputed: ref<gameAttackComputed>;
 public let target: wref<GameObject>;
}
public class DamageManager extends IScriptable {
 public final static func ModifyHitData(hitEvent: ref<gameHitEvent>) -> Void {}
}
@addMethod(ItemID)
public static native func GetTDBID(id: ItemID) -> TweakDBID;
@addMethod(GameObject)
public native const func IsPlayer() -> Bool;
@addMethod(NPCPuppet)
public native const func IsAboutToBeDefeated() -> Bool;
@addMethod(NPCPuppet)
public native const func IsDefeatMechanicActive() -> Bool;
