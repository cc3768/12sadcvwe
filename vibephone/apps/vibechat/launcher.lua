dofile("/vibephone/require_shim.lua")
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)

if fs.exists("/vcchat/main.lua") then
  shell.run("/vcchat/main.lua")
else
  print("VibeChat is not installed yet.")
  print("Open App Store and install/update VibeChat.")
  print("")
  print("Press any key...")
  os.pullEvent("key")
end
