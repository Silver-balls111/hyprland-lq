-- Minimal Hyprland Lua configuration for greetd greeter
-- Runs the quickshell greeter, then exits Hyprland so greetd can launch the user session.

hl.monitor({ name = "", res = "preferred", pos = "auto", scale = 1 })

hl.input({
    kb_layout = "us",
    follow_mouse = 1,
    touchpad = {
        natural_scroll = true
    }
})

hl.general({
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0
})

hl.decoration({
    rounding = 0,
    blur = { enabled = false }
})

hl.animations({
    enabled = false
})

hl.misc({
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0
})

-- Autostart quickshell greeter; when quickshell terminates upon login, Hyprland exits
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p /etc/greetd/greeter/shell.qml; hyprctl dispatch 'hl.dsp.exit()'")
end)
