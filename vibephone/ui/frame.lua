local p = require("ui.primitives")
local M = {}

function M.statusBar(theme, leftText, rightText)
  local w,_ = term.getSize()
  p.fillRect(1,1,w,1, theme.bg)
  p.writeAt(2,1,leftText or "", theme.text, theme.bg)

  local rt = rightText or textutils.formatTime(os.time(), true)
  local rx = math.max(1, w-#rt)
  p.writeAt(rx,1,rt, theme.muted, theme.bg)

  p.fillRect(1,2,w,1, theme.line)
end

function M.header(theme, title, rightHint)
  local w,_ = term.getSize()
  p.fillRect(1,3,w,1, theme.bg)
  p.writeAt(2,3,title or "", theme.text, theme.bg)

  if rightHint then
    local rx = math.max(1, w-#rightHint)
    p.writeAt(rx,3,rightHint, theme.muted, theme.bg)
  end

  p.fillRect(1,4,w,1, theme.accent)
end

return M
