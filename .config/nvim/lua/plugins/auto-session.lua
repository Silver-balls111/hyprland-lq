return {
	"rmagatti/auto-session",
	lazy = false,
	keys = {
		{ "<leader>wr", "<cmd>AutoSession restore<CR>", desc = "Session restore" },
		{ "<leader>ws", "<cmd>AutoSession save<CR>", desc = "Save session" },
	},
	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		suppressed_dirs = { "~/", "~/Dev", "~/Downloads", "/" },
		pre_save_cmds = { "Neotree close" },
	},
}
