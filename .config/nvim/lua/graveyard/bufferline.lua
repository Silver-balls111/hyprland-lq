return {
    'akinsho/bufferline.nvim',
    version = "*",
    event = "VeryLazy",
    dependencies = 'nvim-tree/nvim-web-devicons',
    opts = {
        options = {
            mode = "tabs",
            separator_style = "slope",
            diagnostics = "nvim_lsp",
            hover = {
                enabled = true,
                delay = 200,
                reveal = { "close" },
            },
        },
    },
}
