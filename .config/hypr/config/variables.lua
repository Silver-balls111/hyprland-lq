---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local V = {
    terminal    = "alacritty",
    alt_terminal= "kitty",
    fileManager = "nautilus",
    browser     = "zen-browser",
    editor      = "zeditor",
    alt_editor  = "vscodium",
    ss_region   = "hyprshot -m region --raw | satty --filename -",
    ss_screen   = "hyprshot -m output --raw | satty --filename -",
}

return V
