return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true }, function(err)
					if not err and vim.startswith(vim.api.nvim_get_mode().mode:lower(), "v") then
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
					end
				end)
			end,
			mode = { "n", "v" },
			desc = "Format code",
		},
	},
	---@module "conform"
	---@type conform.setupOpts
	opts = {
		formatters_by_ft = {
			c = { "clang-format" },
			cpp = { "clang-format" },
			cmake = { "gersemi" },
			lua = { "stylua" },
			python = { "ruff_organize_imports", "ruff_format" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			qml = { "qmlformat" },
			json = { "prettier" },
			yaml = { "prettier" },
			toml = { "taplo" },
			markdown = { "prettier" },
			kotlin = { "ktfmt" },
		},
		default_format_opts = {
			lsp_format = "fallback",
		},
		-- format_on_save = { timeout_ms = 500 },
		formatters = {
			["clang-format"] = {
				prepend_args = { "--style={IndentWidth: 4}" },
			},
			shfmt = {
				append_args = { "-i", "2" },
			},
		},
	},
	init = function()
		-- If you want the formatexpr, here is the place to set it
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
