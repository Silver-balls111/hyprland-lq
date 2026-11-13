-------------------
---- AUTOSTART ----
-------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:

----------------------------
---- HYPRLAND ECOSYSTEM ----
----------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("hypridle & hyprsunset")
end)

----------------------------
---- DESKTOP EXPERIENCE ----
----------------------------
hl.on("hyprland.start", function()
    -- glibc knobs: cap per-thread arenas + keep freed heap returning to the
    -- OS — quickshell RSS was ratcheting ~100 MB/day without them
    hl.exec_cmd("MALLOC_ARENA_MAX=2 MALLOC_TRIM_THRESHOLD_=8388608 qs -c rice & awww-daemon")
end)

----------------------------
---- USER APPLICATIONS -----
----------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("vicinae server")
    -- hl.exec_cmd("steam & discord")
end)

-------------------
------ EXTRAS -----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("xdg-desktop-portal-hyprland")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")    -- to get share picker use system theme
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME") -- to get share picker use system theme
    --hl.exec_cmd("xwaylandvideobridge")          -- it is like a compatibility tool for screensharing/running X11/xorg windows on Wayland
end)
