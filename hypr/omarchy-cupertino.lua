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
    border_size = 0,
  },
  decoration = {
    rounding = 10,
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
