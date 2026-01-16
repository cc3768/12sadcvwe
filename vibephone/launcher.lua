dofile("/vibephone/require_shim.lua")
-- launcher.lua
-- Start VibePhone in its own multishell tab if possible, otherwise run main.
local function defaultEnv()
  return setmetatable({}, { __index = _G })
end

if multishell and multishell.launch then
  multishell.launch(defaultEnv(), "/vibephone/main.lua")
  term.setCursorPos(1,1)
  print("VibePhone launched in a new tab.")
  print("Use Ctrl+Tab to switch tabs.")
else
  shell.run("/vibephone/main.lua")
end
