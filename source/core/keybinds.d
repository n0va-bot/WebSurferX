module core.keybinds;

import gdk.types;

enum ModifierType MODKEY = ModifierType.ControlMask;

enum Action
{
    Go,
    Find,
    Stop,
    Reload,
    ReloadBypassCache,
    NavigateForward,
    NavigateBack,
    ScrollV,
    ScrollH,
    ZoomIn,
    ZoomOut,
    ZoomReset,
    ClipboardCopy,
    ClipboardPaste,
    FindNext,
    FindPrev,
    Print,
    ShowCert,
    ToggleCookiePolicy,
    ToggleFullscreen,
    ToggleInspector,
    ToggleCaretBrowsing,
    ToggleGeolocation,
    ToggleJavaScript,
    ToggleLoadImages,
    ToggleScrollBars,
    ToggleStrictTLS,
    ToggleStyle,
    ToggleDarkMode,
    NewTab,
    CloseTab,
    NextTab,
    PrevTab
}

struct KeyBind
{
    ModifierType mod;
    uint keyval;
    Action action;
    int intArg;
    float floatArg;
    string strArg;
}

KeyBind[] keys = [
    KeyBind(MODKEY, KEY_g, Action.Go),
    KeyBind(MODKEY, KEY_f, Action.Find),
    KeyBind(MODKEY, KEY_slash, Action.Find),

    KeyBind(ModifierType.NoModifierMask, KEY_Escape, Action.Stop),
    KeyBind(MODKEY, KEY_c, Action.Stop),

    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_r, Action.ReloadBypassCache),
    KeyBind(MODKEY, KEY_r, Action.Reload),

    KeyBind(MODKEY, KEY_l, Action.NavigateForward),
    KeyBind(MODKEY, KEY_h, Action.NavigateBack),

    KeyBind(MODKEY, KEY_j, Action.ScrollV, 10),
    KeyBind(MODKEY, KEY_k, Action.ScrollV, -10),
    KeyBind(MODKEY, KEY_space, Action.ScrollV, 50),
    KeyBind(MODKEY, KEY_b, Action.ScrollV, -50),
    KeyBind(MODKEY, KEY_i, Action.ScrollH, 10),
    KeyBind(MODKEY, KEY_u, Action.ScrollH, -10),

    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_j, Action.ZoomOut),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_k, Action.ZoomIn),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_q, Action.ZoomReset),
    KeyBind(MODKEY, KEY_minus, Action.ZoomOut),
    KeyBind(MODKEY, KEY_plus, Action.ZoomIn),

    KeyBind(MODKEY, KEY_p, Action.ClipboardPaste),
    KeyBind(MODKEY, KEY_y, Action.ClipboardCopy),

    KeyBind(MODKEY, KEY_n, Action.FindNext),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_n, Action.FindPrev),

    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_p, Action.Print),

    KeyBind(MODKEY, KEY_t, Action.NewTab),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_c, Action.ShowCert),
    KeyBind(MODKEY, KEY_w, Action.CloseTab),
    KeyBind(MODKEY, KEY_Tab, Action.NextTab),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_Tab, Action.PrevTab),

    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_a, Action.ToggleCookiePolicy),
    KeyBind(ModifierType.NoModifierMask, KEY_F11, Action.ToggleFullscreen),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_o, Action.ToggleInspector),

    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_c, Action.ToggleCaretBrowsing),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_g, Action.ToggleGeolocation),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_s, Action.ToggleJavaScript),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_i, Action.ToggleLoadImages),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_b, Action.ToggleScrollBars),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_t, Action.ToggleStrictTLS),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_m, Action.ToggleStyle),
    KeyBind(MODKEY | ModifierType.ShiftMask, KEY_d, Action.ToggleDarkMode),
];
