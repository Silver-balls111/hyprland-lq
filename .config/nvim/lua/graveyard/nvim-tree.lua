return {
  'nvim-tree/nvim-tree.lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  opts = {
      on_attach = function(bufnr)
      local api = require('nvim-tree.api')

      local function opts(desc)
        return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      api.config.mappings.default_on_attach(bufnr)

      -- hide the ~ in this window only
      vim.opt_local.fillchars:append({ eob = ' ' })

      -- l: cd into a directory, or open a file
      vim.keymap.set('n', 'l', function()
        local node = api.tree.get_node_under_cursor()
        if node and node.type == 'directory' then
          api.tree.change_root_to_node(node)
       end
      end, opts('CD into dir / open file'))

      vim.keymap.set('n', '?', api.tree.toggle_help,                  opts('Help'))
      vim.keymap.set('n', 'm', api.fs.cut,                            opts('Move (cut, then paste with p)'))
      vim.keymap.set('n', 'd', api.fs.trash,                          opts('Trash'))
      vim.keymap.set('n', 'D', api.fs.remove,                         opts('Delete'))
      vim.keymap.set('n', 'h', api.tree.change_root_to_parent,        opts('Parent dir'))
      vim.keymap.set('n', '>', api.node.navigate.sibling.next,        opts('Next sibling'))
      vim.keymap.set('n', '<', api.node.navigate.sibling.prev,        opts('Previous sibling'))
    end,
    sort = {
      sorter = 'case_sensitive',
    },
    view = {
      width = 30,
      side = 'right',
    },
    renderer = {
      group_empty = true,
    },
    filters = {
      dotfiles = true,
    },
  },
}
