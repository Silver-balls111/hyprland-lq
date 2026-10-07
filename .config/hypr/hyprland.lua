-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")


------------------
---- MONITORS ----
------------------
require("config/monitors")

-------------------
---- AUTOSTART ----
-------------------
require("config/autostart")

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
require("config/env-variables")
-----------------------

----- PERMISSIONS -----
-----------------------
require("config/permissions")

-----------------------
---- LOOK AND FEEL ----
-----------------------
require("config/aesthetics")

---------------
---- INPUT ----
---------------
require("config/input-rules")

---------------------
---- KEYBINDINGS ----
---------------------
require("config/keybinds")

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
require("config/window-rules")
