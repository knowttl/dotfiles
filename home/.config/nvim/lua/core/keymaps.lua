vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, {})
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<A-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<A-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<A-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<A-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

vim.keymap.set('n', '<leader>sr', [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Center Screen when moving down' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Center Screen when moving up' })
vim.keymap.set('n', '<C-j>', '<C-d>zz', { desc = 'Center Screen when moving down' })
vim.keymap.set('n', '<C-k>', '<C-u>zz', { desc = 'Center Screen when moving up' })

vim.keymap.set('n', '<leader>l', '<C-w>v<C-w>l')
vim.keymap.set('n', '<leader>j', '<C-w>s<C-w>j')
vim.keymap.set('n', '<leader>x', '<C-w>b')

vim.keymap.set('x', '<C-_>', 'gc', { remap = true, desc = 'Commenct selection' })
vim.keymap.set('x', '<C-/>', 'gc', { remap = true, desc = 'Commenct selection' })

vim.keymap.set({ 'n', 'v' }, '<leader>d', [['_d]])
