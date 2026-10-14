return {
	{
		-- only mason.nvim would have satisfied but
		-- using mason-lsp we don't need to remember all the installed
		-- lsp names.
		"mason-org/mason-lspconfig.nvim",
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			"neovim/nvim-lspconfig",
		},
		opts = {
			ensure_installed = {
				"clangd",
				"neocmake",
				"slint_lsp",
				"basedpyright",
				"lua_ls",
				"bashls",
				"ruff",
                "qmlls",
                "kotlin_lsp",
			},
		},
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
        dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
        },
		opts = {
			ensure_installed = {
                -- formatters
				"clang-format",
				"gersemi",
				"shfmt",
				"stylua",
				"prettier",
				"shellcheck",
                "taplo",    -- toml
                "tree-sitter-cli",
                "ktfmt",

                -- daps
                "debugpy", "codelldb"
			},
			auto_update = true,
		},
	},
}
