// Shared read-only aid prerequisites for the survey and live Officer Down.
public class NCPDPatrolAidAccess extends IScriptable {
    public static func IsReady(npc: ref<NPCPuppet>) -> Bool {
        return IsDefined(npc) && npc.IsAttached() && !npc.IsDead() && IsDefined(npc.GetAIControllerComponent())
            && StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.NCPDPatrolOfficerDown");
    }
    public static func HasPath(game: GameInstance, npc: ref<NPCPuppet>, point: Vector4) -> Bool {
        let player: ref<PlayerPuppet> = GetPlayer(game);
        let navigation: ref<AINavigationSystem>;
        let path: ref<NavigationPath>;
        let origin: Vector4;
        let road: NavigationFindPointResult;
        let count: Int32;
        let i: Int32 = 0;
        if !NCPDPatrolAidAccess.IsReady(npc) || !IsDefined(player) || !player.IsAttached() || player.IsDead()
            || point.X != point.X || point.Y != point.Y || point.Z != point.Z
            || Vector4.Distance(point, npc.GetWorldPosition()) > 2.5 { return false; };
        navigation = GameInstance.GetAINavigationSystem(game);
        if !IsDefined(navigation) { return false; };
        origin = player.GetWorldPosition();
        // A vehicle seat is above the road. Stay within this same local road
        // level while finding V's walkable route; never snap to a lower bridge.
        if VehicleComponent.IsMountedToVehicle(game, player) {
            road = navigation.FindPointInSphereForCharacter(origin, 1.5, player);
            if NotEquals(road.status, worldNavigationRequestStatus.OK) || Vector4.Distance(road.point, origin) > 1.5 { return false; };
            origin = road.point;
        };
        path = navigation.CalculatePathForCharacter(origin, point, 0.5, player);
        if !IsDefined(path) { return false; };
        count = ArraySize(path.path);
        if count == 0 || Vector4.Distance(path.path[0], origin) > 1.0
            || Vector4.Distance(path.path[count - 1], point) > 0.75 { return false; };
        while i < count {
            if path.path[i].X != path.path[i].X || path.path[i].Y != path.path[i].Y || path.path[i].Z != path.path[i].Z
                || AbsF(path.path[i].X) >= 100000.0 || AbsF(path.path[i].Y) >= 100000.0 || AbsF(path.path[i].Z) >= 100000.0 { return false; };
            i += 1;
        };
        return true;
    }
}
