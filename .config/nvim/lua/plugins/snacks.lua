return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		dashboard = { enabled = true },
		explorer = { enabled = false },
		indent = { enabled = true },
		input = { enabled = true },
		picker = { enabled = true },
		notifier = { enabled = true },
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = true },
		lazygit = { enabled = true },
		terminal = {
			win = {
				-- merges with the default terminal keys (q = hide, gf, double <esc>)
				keys = {
					hide_toggle = { "<C-t>", "hide", mode = { "n", "t" }, desc = "Hide terminal" },
					term_normal_ctrl = {
						"<C-q>",
						function()
							vim.cmd("stopinsert")
						end,
						mode = "t",
						desc = "Terminal normal mode",
					},
				},
			},
		},
	},
}
