return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = function()
    local theme = require('lualine.themes.auto')

    -- clear only the middle section's bg, leave a/b/y/z alone
    for _, mode in pairs(theme) do
      if mode.c then mode.c.bg = 'NONE' end
    end

    return {
      options = { theme = theme },
      sections = {
        lualine_x = { 'filetype' }, -- dropped encoding and fileformat
      },
    }
  end,
}
