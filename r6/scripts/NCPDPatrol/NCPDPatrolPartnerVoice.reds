// Observe script VO requests for our registered partner. Always preserve the
// original call, arguments and return value; this does not mute or replay audio.
@wrapMethod(GameObject)
public final static func PlayVoiceOver(self: ref<GameObject>, voName: CName, debugInitialContext: CName, opt delay: Float, opt answeringEntityID: EntityID, opt canPlayInVehicle: Bool) -> DelayID {
    let support: ref<NCPDPatrolSupportSystem>;
    if IsDefined(self) {
        support = NCPDPatrolSupportSystem.Get(self.GetGame());
        if IsDefined(support) && support.IsPartner(self) {
            support.RecordPartnerVoice(self, voName, debugInitialContext);
        };
    };
    return wrappedMethod(self, voName, debugInitialContext, delay, answeringEntityID, canPlayInVehicle);
}
