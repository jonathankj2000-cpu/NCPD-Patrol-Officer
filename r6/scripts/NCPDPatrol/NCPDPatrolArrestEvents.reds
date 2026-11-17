// PlayInDeviceSimple sends this normal game event to the specific callback
// recipient. Only the current arrest helper's unique EntityID is accepted.
@addMethod(GameObject)
protected cb func OnPlayInDeviceCallbackEvent(evt: ref<PlayInDeviceCallbackEvent>) -> Bool {
    let system: ref<NCPDPatrolArrestSystem>;
    if !IsDefined(evt) { return false; };
    system = NCPDPatrolArrestSystem.Get(this.GetGame());
    if !IsDefined(system) { return false; };
    return system.AcceptPlayResult(this.GetEntityID(), evt.wasPlayInDeviceSuccessful);
}
