return {
	{
		-- only mason.nvim would have satisfied but
		-- using mason-lsp we don't need to remember all the installed
		-- lsp names.
		"mason-org/mason-lspconfig.nvim",
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
			},
		},
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			"neovim/nvim-lspconfig",
		},
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		opts = {
			ensure_installed = {
				"clang-format",
				"gersemi",
				"shfmt",
				"stylua",
				"prettier",
				"shellcheck",
			},
			auto_update = true,
		},
	},
}
