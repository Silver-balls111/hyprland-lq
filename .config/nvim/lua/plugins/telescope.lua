return {
    'nvim-telescope/telescope.nvim', version = '*',
    dependencies = {
        'nvim-lua/plenary.nvim',
        { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    },
    config = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")

        telescope.setup({
            defaults = {
                path_display = { "smart" },
                mappings = {
                    n = {
                        ["q"] = actions.close,
                        ["o"] = actions.select_default,
                    },
                    i = {
                        ["<Esc>"] = actions.close,
                    },
                },
            },
        })

        -- to improve sorting performance
        telescope.load_extension("fzf")

        local keymap = vim.keymap
        local builtin = require("telescope.builtin")
        keymap.set('n', '<C-p>',        builtin.find_files,  { desc= "Find Files" })
        keymap.set('n', '<leader>pg',   builtin.live_grep,   { desc = "Grep" })
    end
}
