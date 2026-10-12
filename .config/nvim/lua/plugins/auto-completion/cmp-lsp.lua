return {
    {
        -- for better auto completion
        "hrsh7th/cmp-nvim-lsp",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.lsp.config("*", {
                capabilities = require("cmp_nvim_lsp").default_capabilities(),
            })
        end,
    },
}
