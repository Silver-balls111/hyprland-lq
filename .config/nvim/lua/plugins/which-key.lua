return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	opts = {
		delay = 500,
		spec = {
			{ "<leader>s", group = "split" },
			{ "<leader>t", group = "tab / terminal / toggle" },
			{ "<leader>g", group = "git" },
			{ "<leader>h", group = "git hunks" },
			{ "<leader>x", group = "trouble" },
			{ "<leader>w", group = "session" },
			{ "<leader>p", group = "pick" },
			{ "<leader>b", group = "debug" },
			{ "<leader>u", group = "ui toggles" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
