return {
  'https://github.com/xiyaowong/transparent.nvim.git',
  lazy = false,
  init = function()
    local cache_path = vim.fn.stdpath 'data' .. package.config:sub(1, 1) .. 'transparent_cache'
    if vim.fn.filereadable(cache_path) == 0 and vim.g.transparent_enabled == nil then
      vim.g.transparent_enabled = true
    end
  end,
  config = function()
    local transparent = require 'transparent'

    transparent.setup {
      extra_groups = {
        'NormalFloat',
        'FloatBorder',
        'FloatTitle',
        'FoldColumn',
        'Folded',
        'MsgArea',
        'WinSeparator',
        'TabLine',
        'TabLineFill',
        'TelescopeNormal',
        'TelescopeBorder',
        'TelescopePromptNormal',
        'TelescopePromptBorder',
        'TelescopeResultsNormal',
        'TelescopeResultsBorder',
        'TelescopePreviewNormal',
        'TelescopePreviewBorder',
        'WhichKeyFloat',
        'LazyNormal',
        'MasonNormal',
        'BlinkCmpMenu',
        'BlinkCmpMenuBorder',
        'BlinkCmpDoc',
        'BlinkCmpDocBorder',
        'BlinkCmpSignatureHelp',
        'BlinkCmpSignatureHelpBorder',
      },
    }

    transparent.clear_prefix 'BufferLine'
    transparent.clear_prefix 'NeoTree'
    transparent.clear_prefix 'lualine'
    transparent.clear_prefix 'ToggleTerm'
  end,
}
