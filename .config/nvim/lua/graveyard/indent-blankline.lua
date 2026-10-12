return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    ---@module "ibl"
    ---@type ibl.config
    opts = {
        indent = { char = "▏", highlight = "IblIndent" },
        scope = {
            char = "▏",
            highlight = "IblScope",
            show_start = false,
            show_end = false,
        },
    },
}
