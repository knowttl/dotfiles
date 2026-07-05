return {
  {
    'NeogitOrg/neogit',
    cmd = 'Neogit',
    keys = {
      { '<leader>gg', '<cmd>Neogit<CR>', desc = 'Open Neogit UI' },
    },
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'sindrets/diffview.nvim',
    },
    opts = {
      integrations = {
        diffview = true,
        telescope = true,
      },
    },
  },
}