// Ordinary hit/death crime requests require a player instigator in the pinned
// game source. Police vehicles also InjectThreat/CombatHit for non-prevention
// attackers; our dynamically spawned follower is not a prevention-system unit.
// Stop the registered partner's stray hits and V's narrowly excused stray shot
// before those hit callbacks. Never clear heat or override a criminal shift end.
public class NCPDPatrolPartnerSafety extends IScriptable {
    public static func IsPolice(object: ref<GameObject>) -> Bool {
        let npc: ref<NPCPuppet> = object as NPCPuppet;
        let vehicle: ref<VehicleObject> = object as VehicleObject;
        let record: wref<Vehicle_Record>;
        if !IsDefined(object) { return false; };
        if IsDefined(npc) { return npc.IsCharacterPolice(); };
        if !IsDefined(vehicle) { return false; };
        if vehicle.IsPrevention() { return true; };
        record = vehicle.GetRecord();
        return IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.NCPD);
    }
    public static func IsHostileSuspect(object: ref<GameObject>, player: ref<PlayerPuppet>) -> Bool {
        let npc: ref<NPCPuppet> = object as NPCPuppet;
        return IsDefined(npc) && IsDefined(player) && npc.IsAttached() && !npc.IsDead() && !npc.IsDeadNoStatPool()
            && !npc.IsCharacterPolice() && !ScriptedPuppet.IsDefeated(npc) && !ScriptedPuppet.IsUnconscious(npc)
            && Equals(GameObject.GetAttitudeTowards(npc, player), EAIAttitude.AIA_Hostile)
            && Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition()) <= 150.0;
    }
    public static func ObserveIncomingHit(receiver: ref<GameObject>, hit: ref<gameHitEvent>) -> Void {
        let player: ref<PlayerPuppet> = receiver as PlayerPuppet;
        let patrol: ref<NCPDPatrolSystem>;
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() || !NCPDPatrolMarkerSession.WorldReady()
            || !IsDefined(hit) || hit.target != receiver || !IsDefined(hit.attackData)
            || !AttackData.IsRangedOnly(hit.attackData.GetAttackType())
            || !NCPDPatrolPartnerSafety.IsHostileSuspect(hit.attackData.GetInstigator(), player) { return; };
        patrol = NCPDPatrolSystem.Get(receiver.GetGame());
        if IsDefined(patrol) { patrol.RecordHostileShooter(hit.attackData.GetInstigator()); };
    }
    public static func ShouldIgnoreHit(receiver: ref<GameObject>, hit: ref<gameHitEvent>) -> Bool {
        let instigator: ref<GameObject>;
        let player: ref<PlayerPuppet>;
        let patrol: ref<NCPDPatrolSystem>;
        let support: ref<NCPDPatrolSupportSystem>;
        if !IsDefined(receiver) || !receiver.IsAttached() || !IsDefined(hit) || !IsDefined(hit.attackData)
            || hit.target != receiver || !AttackData.IsRangedOnly(hit.attackData.GetAttackType()) { return false; };
        instigator = hit.attackData.GetInstigator();
        if !IsDefined(instigator) || !instigator.IsAttached() { return false; };
        if !NCPDPatrolMarkerSession.WorldReady() { return false; };
        patrol = NCPDPatrolSystem.Get(receiver.GetGame());
        support = NCPDPatrolSupportSystem.Get(receiver.GetGame());
        if !IsDefined(patrol) || !patrol.IsOnDuty() { return false; };
        player = GetPlayer(receiver.GetGame());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return false; };
        // Hostile quest actors retain normal combat even with police records.
        if Equals(GameObject.GetAttitudeTowards(receiver, instigator), EAIAttitude.AIA_Hostile)
            || Equals(GameObject.GetAttitudeTowards(receiver, player), EAIAttitude.AIA_Hostile) { return false; };
        if !NCPDPatrolPartnerSafety.IsPolice(receiver) { return false; };
        if instigator == player { return patrol.CanExcusePoliceHit(receiver, hit); };
        return IsDefined(support) && support.IsPartner(instigator);
    }
}

@wrapMethod(GameObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    NCPDPatrolPartnerSafety.ObserveIncomingHit(this, evt);
    return wrappedMethod(evt);
}

@wrapMethod(VehicleObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    if NCPDPatrolPartnerSafety.ShouldIgnoreHit(this, evt) { return false; };
    return wrappedMethod(evt);
}

@wrapMethod(NPCPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
    if NCPDPatrolPartnerSafety.ShouldIgnoreHit(this, evt) { return false; };
    return wrappedMethod(evt);
}
