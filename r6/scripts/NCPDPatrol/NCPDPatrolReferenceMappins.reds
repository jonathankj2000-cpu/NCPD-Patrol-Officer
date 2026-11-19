// Adapted from CCSharedMappins, Copyright (c) 2026 Andrea Olivato, MIT.
// Upstream a256760bafb625676d13b02ccf49c52b60f41d40, NegativeBalance.
// See THIRD_PARTY_NOTICES.txt. Added active flag and private ownership checks.
// This renderer alone does not create a journal-linked QuestMappin.
public abstract class NCPDPatrolReferenceMappins {
    public static func Show(game: GameInstance, spot: Vector4) -> NewMappinID {
        let ms: ref<MappinSystem> = GameInstance.GetMappinSystem(game);
        let id: NewMappinID;
        let data: MappinData;
        if !IsDefined(ms) { return id; };
        data.mappinType = t"Mappins.QuestStaticMappinDefinition";
        data.variant = gamedataMappinVariant.QuestGiverVariant;
        data.visibleThroughWalls = true;
        data.active = true;
        data.scriptData = new NCPDPatrolReferenceMappinData();
        return ms.RegisterMappin(data, spot);
    }
    public static func IsOwned(game: GameInstance, id: NewMappinID) -> Bool {
        let ms: ref<MappinSystem> = GameInstance.GetMappinSystem(game);
        let pin: ref<IMappin>;
        if !IsDefined(ms) { return false; };
        pin = ms.GetMappin(id);
        return IsDefined(pin) && IsDefined(pin.GetScriptData() as NCPDPatrolReferenceMappinData);
    }
    public static func Move(game: GameInstance, id: NewMappinID, spot: Vector4) -> Void {
        if NCPDPatrolReferenceMappins.IsOwned(game, id) {
            GameInstance.GetMappinSystem(game).SetMappinPosition(id, spot);
        };
    }
    public static func Hide(game: GameInstance, id: NewMappinID) -> Void {
        if NCPDPatrolReferenceMappins.IsOwned(game, id) {
            GameInstance.GetMappinSystem(game).UnregisterMappin(id);
        };
    }
}
