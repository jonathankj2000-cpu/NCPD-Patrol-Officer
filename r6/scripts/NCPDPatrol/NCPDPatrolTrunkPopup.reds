import Codeware.UI.*

// A real blocking game popup: number keys select here, not weapon quickslots.
// Codeware supplies popup scaling, input context, focus and escape handling.
public class NCPDPatrolTrunkPopup extends InGamePopup {
    private let m_trunk: wref<NCPDPatrolTrunkSystem>;
    private let m_vehicle: wref<VehicleObject>;
    private let m_closing: Bool;
    private let m_attached: Bool;
    private let m_armedKey: EInputKey;
    private let m_buttons: array<wref<inkCanvas>>;
    private let m_commands: array<Int32>;

    public func Configure(trunk: ref<NCPDPatrolTrunkSystem>, vehicle: ref<VehicleObject>) -> Void {
        this.m_trunk = trunk;
        this.m_vehicle = vehicle;
    }
    public func UseCursor() -> Bool { return true; }
    public func IsPresented() -> Bool { return this.m_attached; }

    private func Color(red: Float, green: Float, blue: Float, alpha: Float) -> HDRColor {
        let color: HDRColor;
        color.Red = red; color.Green = green; color.Blue = blue; color.Alpha = alpha;
        return color;
    }
    private func Text(parent: ref<inkCompoundWidget>, text: String, x: Float, y: Float, width: Float, height: Float, size: Int32, color: HDRColor) -> Void {
        let label: ref<inkText> = new inkText();
        label.SetText(text);
        label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        label.SetFontStyle(n"Medium");
        label.SetFontSize(size);
        label.SetMargin(x, y, 0.0, 0.0);
        label.SetSize(width, height);
        label.SetWrappingAtPosition(width);
        label.SetTintColor(color);
        label.SetInteractive(false);
        label.Reparent(parent);
    }
    private func Card(parent: ref<inkCompoundWidget>, number: Int32, command: Int32, caption: String, x: Float, y: Float, enabled: Bool) -> Void {
        let card: ref<inkCanvas> = new inkCanvas();
        let background: ref<inkRectangle> = new inkRectangle();
        let color: HDRColor = this.Color(0.35, 0.85, 0.93, 1.0);
        card.SetSize(246.0, 92.0);
        card.SetMargin(x, y, 0.0, 0.0);
        card.SetInteractive(enabled);
        card.Reparent(parent);
        background.SetSize(246.0, 92.0);
        background.SetTintColor(this.Color(0.035, 0.09, 0.13, 0.98));
        background.SetInteractive(false);
        background.Reparent(card);
        if !enabled { color = this.Color(0.38, 0.42, 0.44, 1.0); };
        this.Text(card, ToString(number), 12.0, 22.0, 30.0, 50.0, 32, color);
        this.Text(card, caption, 50.0, 13.0, 184.0, 68.0, 22, color);
        card.RegisterToCallback(n"OnRelease", this, n"OnOptionClicked");
        ArrayPush(this.m_buttons, card);
        ArrayPush(this.m_commands, command);
    }
    protected func CreateContainer() -> Void {
        let panel: ref<inkCanvas> = new inkCanvas();
        let background: ref<inkRectangle> = new inkRectangle();
        let availability: String = GetLocalizedTextByKey(n"NCPDPatrol-Busy");
        panel.SetName(n"NCPDPatrolTrunkMenu");
        panel.SetAnchor(inkEAnchor.Centered);
        panel.SetAnchorPoint(0.5, 0.5);
        panel.SetSize(1080.0, 330.0);
        panel.Reparent(this.GetRootCompoundWidget());
        this.m_container = panel;
        this.SetContainerWidget(panel);
        background.SetSize(1080.0, 330.0);
        background.SetTintColor(this.Color(0.015, 0.025, 0.04, 0.97));
        background.SetInteractive(false);
        background.Reparent(panel);
        this.Text(panel, "NCPD | PATROL SERVICES", 24.0, 12.0, 1000.0, 42.0, 30, this.Color(0.95, 0.77, 0.25, 1.0));
        if this.m_trunk.IsBusy() { availability = GetLocalizedTextByKey(n"NCPDPatrol-Available"); };
        this.Card(panel, 1, 1, availability, 24.0, 70.0, true);
        this.Card(panel, 2, 2, GetLocalizedTextByKey(n"NCPDPatrol-Repair"), 286.0, 70.0, true);
        this.Card(panel, 3, 3, GetLocalizedTextByKey(n"NCPDPatrol-NewPartner"), 548.0, 70.0, true);
        this.Card(panel, 4, 4, GetLocalizedTextByKey(n"NCPDPatrol-CancelDispatch"), 810.0, 70.0, true);
        this.Card(panel, 5, 5, GetLocalizedTextByKey(n"NCPDPatrol-NewDispatch"), 24.0, 178.0, true);
        this.Card(panel, 6, 6, GetLocalizedTextByKey(n"NCPDPatrol-CopStats"), 286.0, 178.0, true);
        this.Card(panel, 7, 7, GetLocalizedTextByKey(n"NCPDPatrol-ReleaseBackup"), 548.0, 178.0, this.m_trunk.CanReleaseBackup());
        this.Card(panel, 9, 0, GetLocalizedTextByKey(n"NCPDPatrol-CloseMenu"), 810.0, 178.0, true);
        this.Text(panel, "1-7: select  |  9 / Esc: close  |  Mouse: select", 24.0, 282.0, 1030.0, 32.0, 19, this.Color(0.6, 0.7, 0.75, 1.0));
    }
    protected cb func OnAttach() -> Void {
        this.m_attached = true;
        super.OnAttach();
        if this.m_closing { super.Close(); return; };
        this.m_armedKey = EInputKey.IK_None;
        GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnNumericKey");
    }
    protected cb func OnDetach() -> Void {
        GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnNumericKey");
        this.m_armedKey = EInputKey.IK_None;
        this.m_closing = true;
        this.m_attached = false;
        if IsDefined(this.m_trunk) { this.m_trunk.ClosePopup(this); };
        super.OnDetach();
    }
    // Public for deterministic input-contract checks. 8 is intentionally spare.
    public func NumberCommand(key: EInputKey) -> Int32 {
        if Equals(key, EInputKey.IK_1) || Equals(key, EInputKey.IK_NumPad1) { return 1; };
        if Equals(key, EInputKey.IK_2) || Equals(key, EInputKey.IK_NumPad2) { return 2; };
        if Equals(key, EInputKey.IK_3) || Equals(key, EInputKey.IK_NumPad3) { return 3; };
        if Equals(key, EInputKey.IK_4) || Equals(key, EInputKey.IK_NumPad4) { return 4; };
        if Equals(key, EInputKey.IK_5) || Equals(key, EInputKey.IK_NumPad5) { return 5; };
        if Equals(key, EInputKey.IK_6) || Equals(key, EInputKey.IK_NumPad6) { return 6; };
        if Equals(key, EInputKey.IK_7) || Equals(key, EInputKey.IK_NumPad7) { return 7; };
        if Equals(key, EInputKey.IK_9) || Equals(key, EInputKey.IK_NumPad9) { return 0; };
        return -1;
    }
    protected cb func OnNumericKey(event: ref<KeyInputEvent>) -> Void {
        let key: EInputKey = event.GetKey();
        let command: Int32 = this.NumberCommand(key);
        if this.m_closing || !this.IsTopPopup() || !IsDefined(this.m_trunk)
            || !this.m_trunk.IsOpenFor(this.m_vehicle) { this.m_armedKey = EInputKey.IK_None; return; };
        if event.IsControlDown() || event.IsAltDown() || event.IsShiftDown() { this.m_armedKey = EInputKey.IK_None; return; };
        if command < 0 { return; };
        if Equals(event.GetAction(), EInputAction.IACT_Press) { this.m_armedKey = key; return; };
        if Equals(event.GetAction(), EInputAction.IACT_Release) && Equals(this.m_armedKey, key) {
            this.m_armedKey = EInputKey.IK_None;
            this.m_trunk.Select(command, this.m_vehicle);
        };
    }
    protected cb func OnOptionClicked(event: ref<inkPointerEvent>) -> Bool {
        let i: Int32 = 0;
        if this.m_closing || !this.IsTopPopup() || !event.IsAction(n"click") || !IsDefined(this.m_trunk) { return false; };
        while i < ArraySize(this.m_buttons) {
            if event.GetCurrentTarget() == this.m_buttons[i] && this.m_buttons[i].IsInteractive() {
                this.m_trunk.Select(this.m_commands[i], this.m_vehicle);
                return true;
            };
            i += 1;
        };
        return false;
    }
    public func Close() -> Void {
        if this.m_closing { return; };
        this.m_closing = true;
        if IsDefined(this.m_trunk) { this.m_trunk.ClosePopup(this); };
        if this.m_attached { super.Close(); };
    }
}
