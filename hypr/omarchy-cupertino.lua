-- Copyright (c) 2026 Sebastian Webber
-- Copyright (c) 2026 Rafael Bertholdo
-- Licensed under the MIT License. See LICENSE.

local TITLEBARS = "/usr/lib/omarchy-hyprland-titlebars/titlebars.so"

local LIGHTS = {
  ["×"] = { order = 1, bg = "rgb(ff5f57)" },
  ["−"] = { order = 2, bg = "rgb(febc2e)" },
  ["□"] = { order = 3, bg = "rgb(28c840)" },
}
local LIGHT_COUNT = 3
local BUTTON_SIZE = 14

hl.config({
  general = {
    border_size = 1,
    col = {
      active_border = "rgba(ffffff33)",
      inactive_border = "rgba(ffffff1a)",
    },
  },
  decoration = {
    rounding = 16,
    rounding_power = 3.4,
    shadow = {
      enabled = true,
      range = 28,
      render_power = 3,
      offset = "0 8",
      color = "rgba(00000059)",
      color_inactive = "rgba(00000030)",
    },
  },
})

local HIDDEN = "special:hidden"
local MINIMIZED = "special:minimized"

local function target(window)
  return "address:" .. tostring(window.address)
end

local function app_windows(class, visible_only)
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    local workspace = window.workspace and window.workspace.name
    if window.class == class and window.mapped
        and not (visible_only and (workspace == HIDDEN or workspace == MINIMIZED)) then
      windows[#windows + 1] = window
    end
  end
  return windows
end

local apps = {}

function apps.quit()
  local active = hl.get_active_window()
  if not active then
    return
  end
  for _, window in ipairs(app_windows(active.class)) do
    hl.dispatch(hl.dsp.window.close({ window = target(window) }))
  end
end

function apps.hide()
  local active = hl.get_active_window()
  if not active then
    return
  end
  local workspace = active.workspace and active.workspace.name
  for _, window in ipairs(app_windows(active.class, true)) do
    hl.dispatch(hl.dsp.window.move({ workspace = HIDDEN, follow = false, window = target(window) }))
  end
  if workspace and not workspace:find("^special:") then
    hl.dispatch(hl.dsp.focus({ workspace = workspace }))
  end
end

function apps.cycle()
  local active = hl.get_active_window()
  if not active then
    return
  end
  local windows = app_windows(active.class, true)
  if #windows < 2 then
    return
  end
  table.sort(windows, function(a, b)
    return tostring(a.address) < tostring(b.address)
  end)
  for index, window in ipairs(windows) do
    if tostring(window.address) == tostring(active.address) then
      local next_window = windows[index % #windows + 1]
      hl.dispatch(hl.dsp.focus({ window = target(next_window) }))
      return
    end
  end
end

package.loaded["omarchy-cupertino.apps"] = apps

hl.unbind("SUPER + Q")
hl.unbind("SUPER + grave")
o.bind("SUPER + Q", "Quit app (close all its windows)", apps.quit)
o.bind("SUPER + H", "Hide app", apps.hide)
o.bind("SUPER + grave", "Cycle windows of the same app", apps.cycle)
o.bind("SUPER + ALT + grave", "Toggle Quake console", hl.dsp.workspace.toggle_special("qconsole"))

if package.loaded["hypr.titlebars"] then
  return
end

local config = hl.config
hl.config = function(values)
  local bars = values and values.plugin and values.plugin.hyprbars
  if bars then
    bars.bar_buttons_alignment = "left"
    bars.bar_text_align = "center"
    bars.button_rounding = BUTTON_SIZE // 2
    bars.icon_on_hover = true
    bars.inactive_button_color = "rgba(8e8e9399)"
    bars.bar_button_padding = 8
  end
  return config(values)
end

local function wrap_add_button(hyprbars)
  if not hyprbars or hyprbars.__traffic_lights then
    return
  end
  local add_button = hyprbars.add_button
  local pending = {}

  hyprbars.add_button = function(button)
    local light = button and LIGHTS[button.icon]
    if not light then
      return add_button(button)
    end

    button.bg_color = light.bg
    button.fg_color = "rgba(00000099)"
    button.size = BUTTON_SIZE
    pending[light.order] = button

    local count = 0
    for _ in pairs(pending) do
      count = count + 1
    end
    if count == LIGHT_COUNT then
      for i = 1, LIGHT_COUNT do
        add_button(pending[i])
      end
      pending = {}
    end
  end
  hyprbars.__traffic_lights = true
end

local load = hl.plugin.load
hl.plugin.load = function(path, ...)
  local result = load(path, ...)
  if path == TITLEBARS then
    wrap_add_button(hl.plugin.hyprbars)
  end
  return result
end

hl.layer_rule({ match = { namespace = "^omarchy-cupertino-bar$" }, no_anim = true, animation = "none" })
