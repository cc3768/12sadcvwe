-- Theme + color presets for the phone UI
local M = {}

M.order = { "neon", "midnight", "amber", "mint", "rose" }

M.presets = {
  neon = {
    name   = "Neon",
    bg     = colors.black,
    bg2    = colors.gray,
    panel  = colors.gray,
    panel2 = colors.black,
    text   = colors.white,
    muted  = colors.lightGray,
    accent = colors.cyan,
    good   = colors.lime,
    bad    = colors.red,
  },
  midnight = {
    name   = "Midnight",
    bg     = colors.black,
    bg2    = colors.blue,
    panel  = colors.gray,
    panel2 = colors.black,
    text   = colors.white,
    muted  = colors.lightGray,
    accent = colors.lightBlue,
    good   = colors.lime,
    bad    = colors.red,
  },
  amber = {
    name   = "Amber",
    bg     = colors.black,
    bg2    = colors.brown,
    panel  = colors.gray,
    panel2 = colors.black,
    text   = colors.white,
    muted  = colors.lightGray,
    accent = colors.orange,
    good   = colors.lime,
    bad    = colors.red,
  },
  mint = {
    name   = "Mint",
    bg     = colors.black,
    bg2    = colors.green,
    panel  = colors.gray,
    panel2 = colors.black,
    text   = colors.white,
    muted  = colors.lightGray,
    accent = colors.lime,
    good   = colors.lime,
    bad    = colors.red,
  },
  rose = {
    name   = "Rose",
    bg     = colors.black,
    bg2    = colors.magenta,
    panel  = colors.gray,
    panel2 = colors.black,
    text   = colors.white,
    muted  = colors.lightGray,
    accent = colors.pink,
    good   = colors.lime,
    bad    = colors.red,
  }
}

function M.get(themeKey)
  return M.presets[themeKey] or M.presets.neon
end

function M.next(themeKey)
  local idx = 1
  for i,k in ipairs(M.order) do
    if k == themeKey then idx = i break end
  end
  idx = idx + 1
  if idx > #M.order then idx = 1 end
  return M.order[idx]
end

return M
