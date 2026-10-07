---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout          = "us",
        kb_variant         = "",
        kb_model           = "",
        kb_options         = "",
        kb_rules           = "",

        follow_mouse       = 1,
        numlock_by_default = true,

        sensitivity        = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad           = {
            natural_scroll = true,
            disable_while_typing = true, -- set to false if you play games with touch pad.
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
    workspace_swipe_cancel_ratio = 0.3,
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
-- hl.device({
--     name        = "epic-mouse-v1",
--     sensitivity = -0.5,
-- })

-- switch main mod key to win for my aula f75 :)
hl.device({
    name       = "compx-2.4g-wireless-receiver",
    kb_options = "altwin:swap_alt_win, caps:backspace",
})
hl.device({
    name       = "aula-f75-5.0-kb-keyboard",
    kb_options = "altwin:swap_alt_win, caps:backspace",
})
hl.device({
    name       = "aula-f75-3.0-kb-keyboard",
    kb_options = "altwin:swap_alt_win, caps:backspace",
})
