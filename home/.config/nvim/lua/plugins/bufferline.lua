return {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
        require('bufferline').setup {
            options = {
                -- separator_style = 'slant',
                offsets = {
                    {
                        filetype = 'neo-tree',
                        text = 'Neo-Tree File Explorer',
                        text_align = 'left',
                        seperator = true,
                    },
                },
            },
        }

        vim.keymap.set('n', '<A-.>', '<Cmd>bnext<CR>', { desc = 'Bufferline Next Buffer' })
        vim.keymap.set('n', '<A-,>', '<Cmd>bprevious<CR>', { desc = 'Bufferline Previous Buffer' })
        vim.keymap.set('n', '<A-w>', '<Cmd>bdelete<CR>', { desc = 'Bufferline Delete Buffer' })
    end,
}
