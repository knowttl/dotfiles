vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd({ 'FileType' }, {
  pattern = { 'cs', 'vb', 'csproj', 'sln' },
  callback = function()
    vim.cmd [[compiler msbuild]]
    vim.opt.makeprg = 'msbuild.exe'
    vim.opt.shellpipe = '>%s 2>&1'
  end,
})
