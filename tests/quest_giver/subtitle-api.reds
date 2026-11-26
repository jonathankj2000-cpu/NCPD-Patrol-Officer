// Offline source-derived API signatures only; never part of the install ZIP.
// MOD_Development_Reference 81d996b584a693e8b0f0b20526a9fa38b5c83fe7:
// orphans.swift scnDialogLineData; core/ui/widgetReference.swift inkTextRef;
// cyberpunk/UI/subtitles/{baseSubtitlesControllers,subtitlesControllers}.swift.
public native struct scnDialogLineData {
    public native let text: String;
    public native let speaker: wref<GameObject>;
    public native let duration: Float;
}
public native class inkTextParams extends IScriptable {}
public native struct inkTextRef {
    public static native func SetText(self: inkTextRef, displayText: String, opt textParams: ref<inkTextParams>) -> Void;
}
public class BaseSubtitleLineLogicController extends inkLogicController {}
public class SubtitleLineLogicController extends BaseSubtitleLineLogicController {
    private let m_lineData: scnDialogLineData;
    private let m_targetTextWidgetRef: inkTextRef;
    public func SetLineData(const lineData: script_ref<scnDialogLineData>) -> Void {}
}
