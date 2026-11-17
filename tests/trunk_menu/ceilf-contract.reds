// Recorded game signature: globals.lua and core/math/scalar.swift at
// In-Question/MOD_Development_Reference 81d996b584a693e8b0f0b20526a9fa38b5c83fe7.
// CeilF returns Int32, not Float. Do not add an identity Int32 -> Int32 cast.
public native func CeilF(value: Float) -> Int32;
public native func Cast(value: Float) -> Int32;
public native func OperatorSubtract(lhs: Float, rhs: Float) -> Float;
public native func OperatorLogicNot(value: Bool) -> Bool;
