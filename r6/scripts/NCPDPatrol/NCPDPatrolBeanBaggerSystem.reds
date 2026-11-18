// Source-backed hit policy for V's Bean Bagger. No actor life/state rewrites,
// automatic arrests, payments, quest completion or changes to other weapons.
public class NCPDPatrolBeanBaggerSystem extends ScriptableSystem {
    private let m_target: wref<NPCPuppet>;
    private let m_hits: Int32;
    private let m_protectedHits: Int32;
    public static func Get(game: GameInstance) -> ref<NCPDPatrolBeanBaggerSystem> {
        return GameInstance.GetScriptableSystemsContainer(game).Get(n"NCPDPatrolBeanBaggerSystem") as NCPDPatrolBeanBaggerSystem;
    }
    public func Version() -> Int32 { return 1; }
    private func OnAttach() -> Void { this.Reset(); }
    private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.Reset(); }
    private func Reset() -> Void { this.m_target = null; this.m_hits = 0; this.m_protectedHits = 0; }

    public static func IsBeanBaggerHit(hit: ref<gameHitEvent>) -> Bool {
        let weapon: ref<WeaponObject>;
        let instigator: ref<GameObject>;
        if !IsDefined(hit) || !IsDefined(hit.attackData) { return false; };
        instigator = hit.attackData.GetInstigator();
        weapon = hit.attackData.GetWeapon();
        return IsDefined(instigator) && instigator.IsPlayer() && IsDefined(weapon)
            && Equals(ItemID.GetTDBID(weapon.GetItemID()), t"Items.NCPDBeanBagger_M2038")
            && AttackData.IsRangedOnly(hit.attackData.GetAttackType());
    }
    public func Apply(hit: ref<gameHitEvent>) -> Void {
        let target: ref<NPCPuppet>;
        if !NCPDPatrolBeanBaggerSystem.IsBeanBaggerHit(hit) || !IsDefined(hit.attackComputed) { return; };
        target = hit.target as NPCPuppet;
        if !IsDefined(target) || NotEquals(target.GetNPCType(), gamedataNPCType.Human)
            || target.IsDead() || target.IsDeadNoStatPool() { return; };
        this.m_target = target;
        this.m_hits += 1;
        // Runs after vanilla ModifyHitData, before DamageSystem.ProcessInstantKill.
        // Keep ordinary modifiers/critical hits; remove explicit lethal overrides
        // from this one weapon's human hit and use the native defeat mechanism.
        hit.attackData.RemoveFlag(hitFlag.Kill);
        hit.attackData.RemoveFlag(hitFlag.ForceDismember);
        hit.attackData.AddFlag(hitFlag.Nonlethal, n"NCPDBeanBagger");
        hit.attackData.AddFlag(hitFlag.DoNotTriggerFinisher, n"NCPDBeanBagger");
        // Later pellets/repeated Bean Bagger shots must not finish a living
        // incapacitated suspect. Other weapons and environmental hits keep vanilla.
        if ScriptedPuppet.IsDefeated(target) || ScriptedPuppet.IsUnconscious(target) || target.IsAboutToBeDefeated() {
            hit.attackComputed.MultAttackValue(0.0);
            hit.attackData.AddFlag(hitFlag.DealNoDamage, n"NCPDBeanBaggerDowned");
            this.m_protectedHits += 1;
        };
    }
    public func GetDiagnostics() -> String {
        let dead: Bool;
        let defeated: Bool;
        let unconscious: Bool;
        let acceptsDefeat: Bool;
        let hits: Int32 = this.m_hits;
        let protectedHits: Int32 = this.m_protectedHits;
        if !IsDefined(this.m_target) || !this.m_target.IsAttached() {
            return s"Bean Bagger hits=\(hits) | downed hits ignored=\(protectedHits) | last target unavailable";
        };
        dead = this.m_target.IsDead() || this.m_target.IsDeadNoStatPool();
        defeated = ScriptedPuppet.IsDefeated(this.m_target);
        unconscious = ScriptedPuppet.IsUnconscious(this.m_target);
        acceptsDefeat = this.m_target.IsDefeatMechanicActive();
        return s"Bean Bagger hits=\(hits) | downed hits ignored=\(protectedHits) | last target dead=\(dead) | defeated=\(defeated) | unconscious=\(unconscious) | native defeat enabled=\(acceptsDefeat)";
    }
}

@wrapMethod(DamageManager)
public final static func ModifyHitData(hitEvent: ref<gameHitEvent>) -> Void {
    let system: ref<NCPDPatrolBeanBaggerSystem>;
    wrappedMethod(hitEvent);
    if NCPDPatrolBeanBaggerSystem.IsBeanBaggerHit(hitEvent) && IsDefined(hitEvent.target) {
        system = NCPDPatrolBeanBaggerSystem.Get(hitEvent.target.GetGame());
        if IsDefined(system) { system.Apply(hitEvent); };
    };
}
