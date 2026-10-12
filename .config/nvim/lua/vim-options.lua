local opt = vim.opt

opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 4 -- 4 spaces for tabs (prettier default)
opt.shiftwidth = 4 -- 4 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

opt.wrap = false

opt.scrolloff = 8
opt.undofile = true
opt.updatetime = 250
opt.confirm = true
opt.inccommand = "split"
opt.winborder = "rounded"
opt.foldtext = "" -- fold line keeps its syntax highlighting (0.10+)

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

opt.cursorline = false

opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

opt.foldlevelstart = 99 -- open files with all folds open

opt.fillchars:append({ eob = ' ' })

-- for autosession 
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions"

-- remove auto comments prefix
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "o", "r" })
  end,
})

-- auto show diagonistics
vim.diagnostic.config({
    virtual_text = false,
    virtual_lines = { current_line = true },
    severity_sort = true,
    update_in_insert = false,
})

opt.pumheight = 15
