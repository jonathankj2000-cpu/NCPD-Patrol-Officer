// Offline signatures only; never shipped. From core/systems/vehicleSystem.swift
// and orphans.swift (TDBID.Create and GameInstance.GetVehicleSystem).
public native struct TDBID {
    public static native func Create(value: String) -> TweakDBID;
}
public native func StrBeginsWith(const value: script_ref<String>, const prefix: script_ref<String>) -> Bool;
// The shared GameInstance contract also declares its native GetVehicleSystem.
public native class VehicleSystem extends IScriptable {
    public final native func EnablePlayerVehicle(vehicle: String, enable: Bool, opt despawnIfDisabling: Bool) -> Bool;
    public final native func IsVehiclePlayerUnlocked(recordID: TweakDBID) -> Bool;
}
