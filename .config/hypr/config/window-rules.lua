--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

--------------------------------
-----   Developer Fixes   ------
--------------------------------
local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name           = "suppress-maximize-events",
    match          = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name     = "fix-xwayland-drags",
    match    = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})


--------------------------------
-----   Window Rules      ------
--------------------------------
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "nwg-look",
    match = { title = "nwg-look" },
    float = true,
})

hl.window_rule({
    name = "slint-preview",
    match = { title = "Slint Live-Preview" },
    float = true,
    size    = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
})

hl.window_rule({
    name = "android-emulator",
    match = { class = "Emulator" },
    float = true,
})

hl.window_rule({
    name   = "make file picker popups floating",
    match  = {
        title = [[^\s*(Open File|Open|Save As|Save|Export|Import|Choose File|
        Choose Download Folder|Rename)\s*$]],
    },
    float  = true,
    center = true,
    size    = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
})

hl.window_rule({
    name = "file-pickers, screen-share popup etc",
    match = { class = [[^\s*(xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland)\s*$]] },
    float = true,
    center  = true,
    size    = {"(monitor_w*0.5)", "(monitor_h*0.5)"},
})

--------------------------------
-----   Layer Rules       ------
--------------------------------
-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

local qs_bar = hl.layer_rule({
    name = "qs:top-bar",
    match = { namespace = "quickshell:bar" },
    blur = true,
    ignore_alpha = 0.5,
})
qs_bar:set_enabled(true)

hl.layer_rule({
    name = "qs:wallswitch-dim",
    match = { namespace = "quickshell:wallswitch" },
    dim_around = true,
    -- experiment to see which animation fits
    animation = "slide right",
})

hl.layer_rule({
    name = "qs:clipboard-dim",
    match = { namespace = "quickshell:clipboard" },
    dim_around = true,
    animation = "popin 80%"
})

hl.layer_rule({
    name = "rofi",
    match = { namespace = "rofi" },
    blur = true,
    dim_around = true,
    animation = "popin 80%",
})
