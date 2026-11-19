// Offline contracts only. Sources: Codeware 1.21.4 (6dfdbce),
// scripts/Quest/QuestsSystem.reds, Base/Imports/quest*NodeDefinition.reds,
// Base/Addons/gameJournalPath.reds; game orphans.swift and journalManager.swift.
// These declarations are never installed and do not prove native execution.
// Game orphans.swift:26718, explicit Int32 -> Uint16 conversion.
public native func Cast(a: Int32) -> Uint16;
@addMethod(GameInstance)
public static native func GetQuestsSystem(game: GameInstance) -> ref<QuestsSystem>;
@addMethod(JournalManager)
public final native const func GetEntryHash(entry: wref<JournalEntry>) -> Int32;
@addMethod(MappinSystem)
public final native func GetMappinFromObjective(phaseEntry: wref<JournalEntry>, objectiveEntry: wref<JournalEntry>) -> wref<IMappin>;
@addMethod(MappinSystem)
public final native func GetManuallyTrackedMappinID() -> NewMappinID;
@addMethod(IMappin)
public final native func IsQuestMappin() -> Bool;
@addMethod(IMappin)
public final native func GetWorldPosition() -> Vector4;
public native class QuestsSystem extends IScriptable {
 public native func ExecuteNode(node: ref<questNodeDefinition>, opt inputSocket: CName) -> Void;
}
public native class graphGraphNodeDefinition extends IScriptable {}
public abstract native class questNodeDefinition extends graphGraphNodeDefinition {
 public native let id: Uint16;
}
public abstract native class questDisableableNodeDefinition extends questNodeDefinition {}
public native class questMappinManagerNodeDefinition extends questDisableableNodeDefinition {
 public native let path: ref<gameJournalPath>;
 public native let disablePreviousMappins: Bool;
}
public native class gameJournalPath extends IScriptable {
 public native let realPath: String;
 public native let fileEntryIndex: Int32;
 public native let className: CName;
 public final native const func GetHash() -> Uint32;
}
public abstract native class QuestMappin extends IMappin {
 public final native func GetJournalPathHash() -> Uint32;
}
