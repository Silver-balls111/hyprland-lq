!# /bin/bash

printf "Git Clone...\n"
git clone https://Silver-balls111/hyprland-lq.git && cd hyprland-lq
echo "Copying files...\n"
cp -r .config/ ~/.config/

printf "Package install...\n"
sudo pacman -Syu --needed iwd wpa_supplicant wireless_tools dialog dhcpcd \
hyprland hypridle hyprshot hyprsunset quickshell \
playerctl brightnessctl \
imagemagick bluez networkmanager upower pipewire wireplumber blueman \
matugen awww cliphist wl-clip-persist

printf "AUR Packages install...\n"
yay -Syu --needed ttf-jetbrains-mono-nerd ttf-rubik-vf sddm-silent-theme

printf "\n\n-Put wallpapers in ~/Pictures/wallpapers\n\n"
printf "To make suspend work edit file:
- sudo vim /etc/systemd/logind.con
- uncomment this lines:
    [Login]
    HandleLidSwitch=suspend
    LidSwitchIgnoreInhibited=no\n"

printf "\nFor icon theme: https://store.kde.org/p/1961046/"
printf "\nFor cursor theme: https://www.gnome-look.org/p/1457884"
printf "\nDownload and extract to both to .icons\n"

printf "\nTo setup matugen follow: https://github.com/InioX/matugen-themes"
