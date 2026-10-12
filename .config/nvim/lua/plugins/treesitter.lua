return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter").install({
            "c", "cpp", "python", "lua", "cmake", "bash", "json", "toml",
            "slint", "groovy", "dockerfile", "gitignore", "qmljs",
        })

        -- filetype is "qml", parser is "qmljs"
        vim.treesitter.language.register("qmljs", "qml")

        vim.api.nvim_create_autocmd("FileType", {
            callback = function(ev)
                if not pcall(vim.treesitter.start, ev.buf) then
                    return -- no parser for this filetype
                end
                vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
                vim.wo[0][0].foldmethod = "expr"
            end,
        })
    end,
}
