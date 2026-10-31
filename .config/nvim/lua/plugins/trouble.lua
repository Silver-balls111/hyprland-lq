return {
    "folke/trouble.nvim",
    dependencies = {
          "folke/todo-comments.nvim",
    },
    opts = {
        focus = true,
        keys = {
            l = "fold_open",
            h = "fold_close",
        },
        -- diagnostics for cwd only
        modes = {
            diagnostics_cwd = {
                mode = "diagnostics",
                filter = function(items)
                    local cwd = vim.fn.getcwd() .. "/"
                    return vim.tbl_filter(function(item)
                        return vim.startswith(item.filename, cwd)
                    end, items)
                end,
            },
        },
    },
    cmd = "Trouble",
    keys = {
        {
            "<leader>xx",
            "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
            desc = "Diagnostics (current file)",
        },
        {
            "<leader>xw",
            "<cmd>Trouble diagnostics_cwd toggle<cr>",
            desc = "Diagnostics (cwd)",
        },
        {
            "<leader>xX",
            "<cmd>Trouble diagnostics toggle<cr>",
            desc = "Diagnostics (all)",
        },
        {
            "<leader>xt",
            "<cmd>Trouble todo<cr>",
            desc = "Show TODO's",
        },
    },
}
