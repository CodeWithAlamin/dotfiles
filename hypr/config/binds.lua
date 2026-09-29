-- Variables & helpers

local mainMod      = "SUPER"
local noctCall     = "noctalia msg "
local launchPrefix = "uwsm app -- " -- if you are not using UWSM, make this empty (e.g. "")

-- Applications
local TERMINAL          = "ghostty"
local BROWSER           = "vivaldi"
local BROWSER_INCOGNITO = "vivaldi --incognito" -- chrome: --incognito / firefox: -private-window
local FILE_MANAGER      = "dolphin"
local EDITOR            = "gnome-text-editor --new-window"
local VSCODE            = "code"

-- Run a Noctalia IPC command
local function noct(cmd)
    return hl.dsp.exec_cmd(noctCall .. cmd)
end

-- Launch an app through the launch prefix
local function launch(cmd)
    return hl.dsp.exec_cmd(launchPrefix .. cmd)
end

-- AZERTY fix: the number-row keys emit symbols (& é " ' ...) without Shift, so
-- binding to the digit characters fails. Bind by physical keycode instead.
-- Digit d -> evdev keycode: 1..9 => 10..18, 0 => 19
local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

-- Repeat a scrolling-layout message until it hits the edge (first/last column).
-- Needs wrap_focus = false and wrap_swapcol = false in the scrolling config.
local function repeatLayout(msg)
    for _ = 1, 30 do
        hl.dispatch(hl.dsp.layout(msg))
    end
end


-- 1. Applications

hl.bind(mainMod .. " + Return",    launch(TERMINAL),                                    { description = "Terminal" })
hl.bind(mainMod .. " + E",         launch(FILE_MANAGER),                                { description = "File Manager" })
hl.bind(mainMod .. " + N",         launch(EDITOR),                                      { description = "Text Editor" })
hl.bind(mainMod .. " + C",         launch(VSCODE),                                      { description = "VS Code" })
hl.bind(mainMod .. " + B",         launch(BROWSER),                                     { description = "Browser" })
hl.bind(mainMod .. " + SHIFT + B", launch(BROWSER_INCOGNITO),                           { description = "Browser (Incognito)" })
hl.bind(mainMod .. " + J",         launch("jopdf"),                                     { description = "JoPDF" })
hl.bind(mainMod .. " + Escape",    launch(TERMINAL .. " -e btop"),                      { description = "System Monitor (btop)" })
hl.bind("XF86Tools",               launch(BROWSER .. " --app=https://www.youtube.com"), { description = "YouTube Web App" })


-- 2. Window Control

hl.bind(mainMod .. " + Q",         hl.dsp.window.close(),                        { description = "Close Window" })
hl.bind(mainMod .. " + Z",         hl.dsp.window.float({ action = "toggle" }),   { description = "Toggle Floating" })
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("sh " .. os.getenv("HOME") .. "/.config/hypr/scripts/toggle-width"), { description = "Toggle Half / Full Width" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen(),                   { description = "Fullscreen" })

-- Move & resize with the mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Drag Window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize Window" })


-- 3. Focus

hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus Left" })
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }), { description = "Focus Right" })
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus Up" })
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus Down" })

hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ direction = "left" }),  { description = "Focus Left (Scroll)" })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ direction = "right" }), { description = "Focus Right (Scroll)" })

hl.bind(mainMod .. " + Home", function() repeatLayout("focus l") end, { description = "Focus First Column" })
hl.bind(mainMod .. " + End",  function() repeatLayout("focus r") end, { description = "Focus Last Column" })

hl.bind("ALT + Tab", noct("window-switcher"), { description = "Window Switcher" })


-- 4. Columns (Scrolling Layout)

-- Column width
hl.bind(mainMod .. " + R",         hl.dsp.layout("colresize +conf"), { description = "Cycle Width Preset" })
hl.bind(mainMod .. " + equal",     hl.dsp.layout("colresize +0.1"),  { description = "Widen Column" })
hl.bind(mainMod .. " + minus",     hl.dsp.layout("colresize -0.1"),  { description = "Narrow Column" })
hl.bind(mainMod .. " + ALT + Right", hl.dsp.layout("colresize +0.1"), { description = "Widen Column" })
hl.bind(mainMod .. " + ALT + Left",  hl.dsp.layout("colresize -0.1"), { description = "Narrow Column" })
hl.bind(mainMod .. " + CTRL + F",  hl.dsp.layout("fit expand"),      { description = "Fill Remaining Space" })

-- Move columns
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.layout("swapcol r"), { description = "Move Column Right" })
hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.layout("swapcol l"), { description = "Move Column Left" })
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.layout("swapcol r"), { description = "Move Column Right (Scroll)" })
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.layout("swapcol l"), { description = "Move Column Left (Scroll)" })
hl.bind(mainMod .. " + SHIFT + Home", function() repeatLayout("swapcol l") end, { description = "Move Column to Start" })
hl.bind(mainMod .. " + SHIFT + End",  function() repeatLayout("swapcol r") end, { description = "Move Column to End" })

-- Move windows within / between columns
hl.bind(mainMod .. " + SHIFT + Up",   hl.dsp.window.move({ direction = "u" }), { description = "Move Window Up" })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d" }), { description = "Move Window Down" })
hl.bind(mainMod .. " + SHIFT + apostrophe", hl.dsp.layout("expel"),   { description = "Expel Window to Own Column" })
hl.bind(mainMod .. " + SHIFT + semicolon",  hl.dsp.layout("consume"), { description = "Consume Window into Previous Column" })


-- 5. Workspaces

-- Workspace 1-9 on the current monitor: focus / move & follow / move & stay
for i = 1, 9 do
    local key = digitCode(i)
    local ws  = "m~" .. i
    hl.bind(mainMod .. " + " .. key,                hl.dsp.focus({ workspace = ws }),                       { description = "Focus Workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key,        hl.dsp.window.move({ workspace = ws }),                 { description = "Move Window to Workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + ALT + " .. key,  hl.dsp.window.move({ workspace = ws, follow = false }), { description = "Move Window (Stay) to Workspace " .. i })
end

-- Previous / next workspace
hl.bind(mainMod .. " + Page_Up",         hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace Up" })
hl.bind(mainMod .. " + Page_Down",       hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace Down" })
hl.bind(mainMod .. " + CTRL + mouse_up",   hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace Up (Scroll)" })
hl.bind(mainMod .. " + CTRL + mouse_down", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace Down (Scroll)" })

-- Move window to previous / next workspace
hl.bind(mainMod .. " + SHIFT + Page_Up",   hl.dsp.window.move({ workspace = "r-1" }), { description = "Move Window Up a Workspace" })
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Move Window Down a Workspace" })
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "r-1" }), { description = "Move Window Up a Workspace (Scroll)" })
hl.bind(mainMod .. " + CTRL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r+1" }), { description = "Move Window Down a Workspace (Scroll)" })

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special(),          { description = "Toggle Scratchpad" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), { description = "Move Window to Scratchpad" })


-- 6. Noctalia Shell

-- Panels
hl.bind(mainMod .. " + Space",     noct("panel-toggle launcher"),                 { description = "Launcher" })
hl.bind(mainMod .. " + period",    noct("panel-toggle launcher /emo"),            { description = "Emoji Picker" })
hl.bind(mainMod .. " + V",         noct("panel-toggle clipboard"),                { description = "Clipboard History" })
hl.bind(mainMod .. " + F1",        noct("panel-toggle blackbartblues/keymap:panel"), { description = "Keymap Panel" })
hl.bind(mainMod .. " + BackSlash", noct("wallpaper-next"),                        { description = "Next Wallpaper" })

-- Screenshot & OCR
hl.bind("Print",               noct("screenshot-region"),     { description = "Screenshot Region" })
hl.bind(mainMod .. " + Print", noct("screenshot-fullscreen"), { description = "Screenshot Fullscreen" })
hl.bind("Scroll_Lock",         noct("plugin fel/ocr:ocr all ocr-region"), { description = "OCR Region" })

-- Notifications
hl.bind(mainMod .. " + ALT + N",   noct("panel-toggle control-center notifications"), { description = "Notification Center" })
hl.bind(mainMod .. " + SHIFT + N", noct("notification-clear-active"),                 { description = "Dismiss All Popups" })
hl.bind(mainMod .. " + CTRL + N",  noct("notification-clear-history"),                { description = "Clear All Notifications" })


-- 7. System & Session

hl.bind(mainMod .. " + L",                     noct("session lock"),              { description = "Lock Screen" })
hl.bind(mainMod .. " + SHIFT + Escape",        noct("panel-toggle session"),      { description = "Session Menu" })
hl.bind(mainMod .. " + CTRL + SHIFT + Escape",
    hl.dsp.exec_cmd("sh -c '" .. noctCall .. "session lock && sleep 1 && systemctl hibernate'"),
    { description = "Lock & Hibernate" })


-- 8. Hardware Keys

-- Audio
hl.bind("XF86AudioRaiseVolume", noct("volume-up"),   { locked = true, repeating = true, description = "Volume Up" })
hl.bind("XF86AudioLowerVolume", noct("volume-down"), { locked = true, repeating = true, description = "Volume Down" })
hl.bind("XF86AudioMute",        noct("volume-mute"), { locked = true, description = "Mute" })
hl.bind("XF86AudioMicMute",     noct("mic-mute"),    { locked = true, description = "Mute Microphone" })

-- Media
hl.bind("XF86AudioPlay",  noct("media toggle"),   { locked = true, description = "Play / Pause" })
hl.bind("XF86AudioPause", noct("media toggle"),   { locked = true, description = "Play / Pause" })
hl.bind("XF86AudioNext",  noct("media next"),     { locked = true, description = "Next Track" })
hl.bind("XF86AudioPrev",  noct("media previous"), { locked = true, description = "Previous Track" })

-- Brightness
hl.bind("XF86MonBrightnessUp",   noct("brightness-up"),   { locked = true, repeating = true, description = "Brightness Up" })
hl.bind("XF86MonBrightnessDown", noct("brightness-down"), { locked = true, repeating = true, description = "Brightness Down" })
