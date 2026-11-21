// Ordinary hit/death crime requests require a player instigator in the pinned
// game source. Police vehicles also InjectThreat/CombatHit for non-prevention
// attackers; our dynamically spawned follower is not a prevention-system unit.
// Stop only our current partner's stray gun hits before those hit callbacks.
public class NCPDPatrolPartnerSafety extends IScriptable {
    public static func ShouldIgnoreHit(receiver: ref<GameObject>, hit: ref<gameHitEvent>) -> Bool {
        let instigator: ref<GameObject>;
        let player: ref<PlayerPuppet>;
        let patrol: ref<NCPDPatrolSystem>;
        let support: ref<NCPDPatrolSupportSystem>;
        let npc: ref<NPCPuppet>;
        let vehicle: ref<VehicleObject>;
        let record: wref<Vehicle_Record>;
        if !IsDefined(receiver) || !receiver.IsAttached() || !IsDefined(hit) || !IsDefined(hit.attackData)
            || hit.target != receiver || !AttackData.IsRangedOnly(hit.attackData.GetAttackType()) { return false; };
        instigator = hit.attackData.GetInstigator();
        if !IsDefined(instigator) || instigator.IsPlayer() || !instigator.IsAttached() { return false; };
        if !NCPDPatrolMarkerSession.WorldReady() { return false; };
        patrol = NCPDPatrolSystem.Get(receiver.GetGame());
        support = NCPDPatrolSupportSystem.Get(receiver.GetGame());
        if !IsDefined(patrol) || !patrol.IsOnDuty() || !IsDefined(support) || !support.IsPartner(instigator) { return false; };
        player = GetPlayer(receiver.GetGame());
        if !IsDefined(player) || !player.IsAttached() || player.IsDead() { return false; };
        // Hostile quest actors retain normal combat even with police records.
        if Equals(GameObject.GetAttitudeTowards(receiver, instigator), EAIAttitude.AIA_Hostile)
            || Equals(GameObject.GetAttitudeTowards(receiver, player), EAIAttitude.AIA_Hostile) { return false; };
        npc = receiver as NPCPuppet;
        if IsDefined(npc) { return npc.IsCharacterPolice(); };
        vehicle = receiver as VehicleObject;
        if !IsDefined(vehicle) { return false; };
        if vehicle.IsPrevention() { return true; };
        // Parked or empty police vehicles may have no prevention passengers.
        record = vehicle.GetRecord();
        return IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.NCPD);
    }
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
