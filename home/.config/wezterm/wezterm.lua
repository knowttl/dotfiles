local wezterm = require 'wezterm'
local mux = wezterm.mux

local config = wezterm.config_builder()

local function file_exists(path)
  local file = io.open(path, 'rb')
  if file then
    file:close()
    return true
  end

  return false
end

local installed_background_image = wezterm.config_dir .. '/images/seed-gundam.jpg'
local repo_background_image = wezterm.config_dir .. '/../../assets/images/seed-gundam.jpg'
local background_image = installed_background_image

if not file_exists(background_image) then
  background_image = repo_background_image
end

wezterm.on('gui-startup', function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  local screen = wezterm.gui.screens().active or wezterm.gui.screens().main

  local width = math.floor(screen.width * 0.7)
  local height = math.floor(screen.height * 0.7)
  local x = screen.x + math.floor((screen.width - width) / 2)
  local y = screen.y + math.floor((screen.height - height) / 2)

  window:gui_window():set_inner_size(width, height)
  window:gui_window():set_position(x, y)
end)

config.color_scheme = 'rose-pine-moon'
config.colors = {
  selection_bg = '#f6c177',
  selection_fg = '#191724',
}
config.font = wezterm.font_with_fallback {
  {
    family = 'JetBrainsMonoNL Nerd Font',
    weight = 'Medium',
  },
  {
    family = 'JetBrains Mono',
    weight = 'Medium',
  },
  {
    family = 'Hack Nerd Font Mono',
    weight = 'DemiBold',
  },
}
config.font_size = 11
config.cursor_blink_rate = 0
config.adjust_window_size_when_changing_font_size = false
config.audible_bell = 'Disabled'
config.hide_tab_bar_if_only_one_tab = false
config.window_close_confirmation = 'NeverPrompt'
config.window_decorations = 'RESIZE'
config.window_background_opacity = 1.0
config.win32_system_backdrop = 'Disable'
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}
config.keys = {
  {
    key = 'Backspace',
    mods = 'CTRL',
    action = wezterm.action.SendString '\x17',
  },
  {
    key = 't',
    mods = 'CTRL',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'w',
    mods = 'CTRL',
    action = wezterm.action.CloseCurrentTab { confirm = false },
  },
  {
    key = 'Tab',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'PageDown',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'PageUp',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = '1',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'CTRL',
    action = wezterm.action.ActivateTab(-1),
  },
}
config.background = {
  {
    source = {
      Color = '#000000',
    },
    width = '100%',
    height = '100%',
    opacity = 1.0,
  },
  {
    source = {
      File = background_image,
    },
    horizontal_align = 'Center',
    vertical_align = 'Middle',
    repeat_x = 'NoRepeat',
    repeat_y = 'NoRepeat',
    opacity = 1.0,
    hsb = {
      brightness = 0.10,
      saturation = 0.9,
    },
  },
}

return config
