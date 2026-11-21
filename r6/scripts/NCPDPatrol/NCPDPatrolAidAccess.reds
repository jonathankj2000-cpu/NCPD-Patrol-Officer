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
        return NCPDPatrolAidAccess.CompletePath(path, origin, point);
    }
    // A live incident is prepared independently of V's moving vehicle seat.
    // Use the scene's empty center and its own healthy defender's nav profile.
    // The off-duty survey above continues to prove the route from V.
    public static func HasPathFromScene(game: GameInstance, npc: ref<NPCPuppet>, point: Vector4, origin: Vector4, defender: ref<NPCPuppet>) -> Bool {
        let navigation: ref<AINavigationSystem>;
        let road: NavigationFindPointResult;
        let path: ref<NavigationPath>;
        if !NCPDPatrolAidAccess.IsReady(npc) || !IsDefined(defender) || !defender.IsAttached() || defender.IsDead()
            || point.X != point.X || point.Y != point.Y || point.Z != point.Z
            || origin.X != origin.X || origin.Y != origin.Y || origin.Z != origin.Z
            || Vector4.Distance(point, npc.GetWorldPosition()) > 2.5 { return false; };
        navigation = GameInstance.GetAINavigationSystem(game);
        if !IsDefined(navigation) { return false; };
        road = navigation.FindPointInSphereForCharacter(origin, 1.5, defender);
        if NotEquals(road.status, worldNavigationRequestStatus.OK) || Vector4.Distance(road.point, origin) > 1.5
            || AbsF(road.point.Z - origin.Z) > 0.75 { return false; };
        path = navigation.CalculatePathForCharacter(road.point, point, 0.5, defender);
        return NCPDPatrolAidAccess.CompletePath(path, road.point, point);
    }
    private static func CompletePath(path: ref<NavigationPath>, origin: Vector4, point: Vector4) -> Bool {
        let count: Int32;
        let i: Int32 = 0;
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
