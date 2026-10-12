local function make_transparent()
	local groups = {
		"Normal", "NormalNC", "NormalFloat", "FloatBorder",
		"SignColumn", "StatusLine", "StatusLineNC", "EndOfBuffer",
		-- neo-tree
		"NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
		"NeoTreeWinSeparator", "NeoTreeVertSplit",
		"NeoTreeStatusLine", "NeoTreeStatusLineNC",
		"NeoTreeSignColumn", "NeoTreeFloatNormal", "NeoTreeFloatBorder",
	}

	for _, group in ipairs(groups) do
		-- link = false resolves linked groups (e.g. NormalFloat -> Normal) to real values
		local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
		hl.bg = "NONE"
		hl.ctermbg = "NONE"
		vim.api.nvim_set_hl(0, group, hl)
	end
end

make_transparent()
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = make_transparent,
})
