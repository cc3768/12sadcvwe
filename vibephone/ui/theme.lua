local themes = require("themes")

local M = {}

function M.theme(data)
  local t = themes.get(data.ui and data.ui.theme)
  local accent = (data.ui and data.ui.accent) or t.accent

  return {
    key     = (data.ui and data.ui.theme) or "neon",
    name    = t.name,

    bg      = colors.black,
    bg2     = colors.gray,

    surface = colors.gray,
    inner   = colors.black,

    panel2  = colors.black, -- old screens expect panel2

    text    = colors.white,
    muted   = colors.lightGray,

    accent  = accent,
    good    = t.good,
    bad     = t.bad,
    line    = colors.gray,
  }
end

-- Old name used by earlier screens
function M.getTheme(data)
  return M.theme(data)
end

return M
