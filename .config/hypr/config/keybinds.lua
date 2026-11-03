---------------------
---- KEYBINDINGS ----
---------------------
-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more

local variables = require("config/variables")
local mainMod = "ALT"


------------------------------------
------ Application Launchers -------
------------------------------------
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(variables.terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(variables.fileManager))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(variables.alt_fileManager))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(variables.editor))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(variables.alt_editor))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(variables.browser))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(variables.launcher))


------------------------------------
------       Utilities       -------
------------------------------------
hl.bind("PRINT", hl.dsp.exec_cmd(variables.ss_region))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(variables.ss_screen))


------------------------------------
------       Quickshell       -------
------------------------------------
hl.bind(mainMod .. " + N", hl.dsp.global("qs-bar:notification"))
hl.bind(mainMod .. " + X", hl.dsp.global("qs-bar:powermenu"))
hl.bind("SUPER + L", hl.dsp.global("qs:lock"))
hl.bind("SUPER + W", hl.dsp.global("qs:wallpaper-switcher"))


------------------------------------
------       Functions       -------
------------------------------------
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

hl.bind(mainMod .. " + SHIFT + M",
    hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

--hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "for dwindle mode"})


------------------------------------
------       Focus           -------
------------------------------------
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move focus with vim nav-keys
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))


------------------------------------
------  Workspace Switching  -------
------------------------------------
-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "previous" }))


------------------------------------
------   Window Movement     -------
------------------------------------
-- Move the windows using shift + arrow keys
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "t" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "b" }))

-- Move the windows using shift + vim style navigation
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "t" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "b" }))


------------------------------------
--------   Window Resize   ---------
------------------------------------
-- Switch to a submap called `resize`.
hl.bind(mainMod .. " + R", function()
    hl.dispatch(hl.dsp.submap("resize"))
    hl.notification.create({
        text = "Resize Mode [ON]",
        color = "rgb(40a02b)",
        timeout = 4000
    })
end)

-- Start a submap called "resize".
hl.define_submap("resize", function()

    -- Set repeating binds for resizing the active window.
    hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true}), { repeating = true })
    hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true}), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true}), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true}), { repeating = true })

    -- Use `reset` to go back to the global submap
    hl.bind("escape", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.notification.create({
            text = "Resize Mode [OFf]",
            color = "rgb(d20f39)",
            timeout = 4000
        })
    end)
end)

-- MOVE MODE
hl.bind(mainMod .. " + M", function()
    hl.dispatch(hl.dsp.submap("move"))
    hl.notification.create({
        text = "Move Mode [ON]",
        color = "rgb(40a02b)",
        timeout = 4000
    })
end)

hl.define_submap("move", function()
    hl.bind("l", hl.dsp.window.move({ x = 15,  y = 0,  relative = true }), { repeating = true })
    hl.bind("h", hl.dsp.window.move({ x = -15, y = 0,  relative = true }), { repeating = true })
    hl.bind("k", hl.dsp.window.move({ x = 0,  y = -15, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.move({ x = 0,  y = 15,  relative = true }), { repeating = true })

    hl.bind("escape", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.notification.create({
            text = "Move Mode [OFf]",
            color = "rgb(d20f39)",
            timeout = 4000
        })
    end)

end)
-- Keybinds further down will be global again...


------------------------------------
------     Scratchpad        -------
------------------------------------
-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


------------------------------------
------       Mouse           -------
------------------------------------
-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


------------------------------------
------       Gamemode        -------
------------------------------------
hl.bind("SUPER + F1", function ()
    local game_mode = (hl.get_config("animations.enabled") == false)

    if game_mode then
        hl.exec_cmd("hyprctl reload")
        hl.notification.create({
            text = "Gamemode [OFF]",
            color = "rgb(d20f39)",
            timeout = 4000
        })
        return
    end

    hl.config({
        general = {
            gaps_in = 0, gaps_out = 0, -- Disable gaps
            border_size = 0,
        },

        animations = {
            enabled = false, -- Disable animations
        },

        -- Disable blur, shadow and window rounding
        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = 0,
        }
    })

    hl.notification.create({
        text = "Gamemode [ON]",
        color = "rgb(40a02b)",
        timeout = 4000
    })
end)


------------------------------------
------       Laptop          -------
------------------------------------
-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 2 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)
hl.bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true }
)
hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -q set 5%+"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -q set 5%-"),
    { locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })


------------------------------------
------       Debug           -------
------------------------------------
hl.bind("SUPER + R", hl.dsp.exec_cmd("cd ~/.config/hypr/scripts ; sh launch.sh"))
