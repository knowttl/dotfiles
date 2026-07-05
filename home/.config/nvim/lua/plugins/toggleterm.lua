return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = function()
    -- Setup Toggle Term
    require('toggleterm').setup {
      open_mapping = [[<c-\>]],
      share_filetypes = {},
      shade_terminals = false,
      close_on_exit = true,
      direction = 'horizontal',
      size = math.floor(vim.opt.lines:get() * 0.25),
      highlights = {
        -- highlights which map to a highlight group name and a table of it's values
        -- NOTE: this is only a subset of values, any group placed here will be set for the terminal window split
      },
    }
    -- Floating Terminal
    local FTerminal = require('toggleterm.terminal').Terminal
    local fterm = FTerminal:new { hidden = true, direction = 'float' }

    function _fterm_toggle()
      fterm:toggle()
    end
    -- vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>lua _fterm_toggle()<CR>', { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', '<C-t>', '<cmd>lua _fterm_toggle()<CR>', { noremap = true, silent = true, desc = 'Toggle Floating Terminal' })
    vim.api.nvim_set_keymap('t', '<C-t>', '<cmd>lua _fterm_toggle()<CR>', { noremap = true, silent = true, desc = 'Toggle Floating Terminal' })

    -- For Setting keymaps to be able to move out of terminal easily

    function _G.set_terminal_keymaps()
      local opts = { buffer = 0, desc = 'Toggle Term Keymaps to leave Terminal Mode' }
      vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts)
      vim.keymap.set('t', 'jk', [[<C-\><C-n>]], opts)
      vim.keymap.set('t', '<A-h>', [[<Cmd>wincmd h<CR>]], opts)
      vim.keymap.set('t', '<A-j>', [[<Cmd>wincmd j<CR>]], opts)
      vim.keymap.set('t', '<A-k>', [[<Cmd>wincmd k<CR>]], opts)
      vim.keymap.set('t', '<A-l>', [[<Cmd>wincmd l<CR>]], opts)
    end

    -- if you only want these mappings for toggle term use term://*toggleterm#* instead
    vim.cmd 'autocmd! TermOpen term://* lua set_terminal_keymaps()'
  end,
}
