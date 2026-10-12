return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-tree/nvim-web-devicons", -- optional, but recommended
	},
	lazy = false, -- neo-tree will lazily load itself
	---@module 'neo-tree'
	---@type neotree.Config
	opts = {
		window = {
			position = "right",
			width = 30,
			auto_expand_width = false,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
			mappings = {
				["l"] = function(state)
					local node = state.tree:get_node()
					state.commands["open"](state) --expands dir or open a file
					if node.type == "file" then
						require("neo-tree.command").execute({ action = "close" })
					end
				end,
				["h"] = "close_node",
				["L"] = "set_root",
				["H"] = "navigate_up",
				["."] = "toggle_hidden",
				["d"] = "trash",
				["D"] = "delete",
				["<space>"] = "select",

				["<Tab>"] = {
					"toggle_preview",
					config = {
						use_float = false,
						use_snacks_image = true,
						use_image_nvim = true,
					},
				},
				["f"] = "focus_preview",

				-- reveal in system file explorer
				["O"] = function(state)
					local node = state.tree:get_node()
					local dir = node.type == "directory" and node.path or vim.fn.fnamemodify(node.path, ":h")
					vim.ui.open(dir)
				end,
			},
		},
		filesystem = {
			filtered_items = {
				visible = true,
			},
		},
	},
}
