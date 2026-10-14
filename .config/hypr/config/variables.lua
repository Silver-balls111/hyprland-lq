---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local V = {
    terminal    = "alacritty",
    alt_terminal= "kitty",
    fileManager = "kitty -e yazi",
    alt_fileManager = "nautilus",
    browser     = "zen-browser",
    editor      = "zeditor",
    alt_editor  = "alacritty -e nvim ~/Dev/",
    menu        = "~/.config/rofi/launch_rofi.sh",
    ss_region   = "hyprshot -m region --raw | satty --filename -",
    ss_screen   = "hyprshot -m output --raw | satty --filename -",
}

return V
