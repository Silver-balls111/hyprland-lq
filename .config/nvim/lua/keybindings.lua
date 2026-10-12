vim.g.mapleader = " "

local map = vim.keymap.set

map("i", "jj", "<Esc>")

-- ':NvimTreeToggle<CR>',
map('n', '<C-n>', '<cmd>Neotree toggle reveal<CR>', { silent = true })

-- ctrl-[hjkl] to select active split
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- to switch between editor and terminal
for _, dir in ipairs({ "h", "j", "k", "l" }) do
    map("t", "<C-" .. dir .. ">", "<cmd>wincmd " .. dir .. "<cr>", { desc = "Go to " .. dir .. " window" })
end

-- window management
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })                   -- split window vertically
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })                 -- split window horizontally
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })                    -- make split windows equal width & height
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })               -- close current split window

map("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })                     -- open new tab
map("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })              -- close current tab
map("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })                     --  go to next tab
map("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })                 --  go to previous tab
map("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- lazygit
map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })

-- github (snacks picker)
map("n", "<leader>gi", function() Snacks.picker.gh_issue() end, { desc = "GitHub Issues (open)" })
map("n", "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, { desc = "GitHub Issues (all)" })
map("n", "<leader>gp", function() Snacks.picker.gh_pr() end, { desc = "GitHub Pull Requests (open)" })
map("n", "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, { desc = "GitHub Pull Requests (all)" })

-- terminal
map({ "n", "t" }, "<C-t>", function() Snacks.terminal() end, { desc = "Toggle terminal (2<C-t> = terminal #2)" })

map("n", "<leader>tt", function()
    Snacks.terminal(nil, {
        env = { term_kind = "float" },
        win = { position = "float", border = "rounded", width = 0.9, height = 0.9 },
    })
end, { desc = "Floating terminal" })

map("n", "<leader>th", function()
    Snacks.terminal(nil, { env = { term_id = tostring(vim.uv.hrtime()) }, win = { position = "bottom" } })
end, { desc = "New terminal (horizontal)" })

map("n", "<leader>tv", function()
    Snacks.terminal(nil, { env = { term_id = tostring(vim.uv.hrtime()) }, win = { position = "right" } })
end, { desc = "New terminal (vertical)" })

map("n", "<leader>ts", function()
    local terms = Snacks.terminal.list()
    if #terms == 0 then
        return Snacks.notify.warn("No open terminals")
    end
    vim.ui.select(terms, {
        prompt = "Select terminal",
        format_item = function(term)
            local info = vim.b[term.buf].snacks_terminal or {}
            return ("%s: %s"):format(info.id or term.buf, vim.b[term.buf].term_title or "terminal")
        end,
    }, function(term)
        if term then
            term:show()
            term:focus()
        end
    end)
end, { desc = "Select terminal" })
