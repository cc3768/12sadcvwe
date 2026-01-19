-- install_vibephone.lua
-- Installs apps from server AppStore HTTP endpoints.
-- Run: wget run http://<SERVER>:8080/install_vibephone.lua

local DEFAULT_BASE = "http://15.204.199.112:8080" -- change
local DEFAULT_LIST = "vibephone,vibechat,calculator,controller"

local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end

local function httpGet(url)
  local h = http.get(url)
  if not h then return nil, "http.get failed: "..url end
  local s = h.readAll(); h.close(); return s
end

local function getJSON(url)
  local raw, err = httpGet(url)
  if not raw then return nil, err end
  local ok, obj = pcall(textutils.unserializeJSON, raw)
  if not ok then return nil, "bad json: "..url end
  return obj
end

local function writeFile(path, data)
  fs.makeDir(fs.getDir(path))
  local f = fs.open(path, "w")
  assert(f, "Failed to write "..path)
  f.write(data)
  f.close()
end

local function prompt(label, def)
  term.setTextColor(colors.white)
  term.write(label)
  if def then term.write(" ["..def.."]") end
  term.write(": ")
  local s = trim(read())
  if s == "" then return def end
  return s
end

local function installApp(base, id)
  local m = getJSON(base.."/api/apps/"..id.."/manifest")
  assert(m and m.ok and m.manifest, "manifest not ok for "..id)
  local man = m.manifest
  local installBase = assert(man.installBase, "no installBase "..id)
  local files = assert(man.files, "no files "..id)

  print(("Installing %s -> %s"):format(id, installBase))
  for _, rel in ipairs(files) do
    rel = tostring(rel):gsub("\\","/")
    local body, berr = httpGet(base.."/api/apps/"..id.."/file/"..rel)
    assert(body, "file fetch failed: "..rel.." ("..tostring(berr)..")")

    local outPath = fs.combine(installBase, rel)
    writeFile(outPath, body)
    print("  ok "..outPath)
  end
end

local function main()
  if not http or not http.get then error("HTTP disabled in CC:Tweaked config.") end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1,1)

  print("VibePhone Full Installer")
  print("------------------------")

  local base = prompt("Server base URL", DEFAULT_BASE):gsub("/+$","")
  local listRaw = prompt("Apps (comma)", DEFAULT_LIST)

  local apps = {}
  for p in tostring(listRaw):gmatch("[^,]+") do
    p = trim(p)
    if p ~= "" then apps[#apps+1] = p end
  end

  for _, id in ipairs(apps) do
    installApp(base, id)
  end

  writeFile("/startup", [[
if fs.exists("/vibephone/main.lua") then
  shell.run("/vibephone/main.lua")
else
  print("Missing /vibephone/main.lua")
end
]])

  print("")
  print("Done. Reboot to launch.")
end

main()
