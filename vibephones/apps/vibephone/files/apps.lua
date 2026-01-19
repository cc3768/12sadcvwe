dofile("/vibephone/require_shim.lua")
-- App registry.
-- Static apps live here; installed apps are merged from /vibephone/apps_registry.json

local REGISTRY_PATH = "/vibephone/apps_registry.json"

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r"); if not f then return nil end
  local s = f.readAll(); f.close(); return s
end

local function loadRegistry()
  local raw = readFile(REGISTRY_PATH)
  if not raw then return {} end
  local ok, obj = pcall(function() return textutils.unserializeJSON(raw) end)
  if ok and type(obj) == "table" then return obj end
  return {}
end

-- Static built-ins
local apps = {
  vibechat = {
    id = "vibechat",
    name = "VibeChat",
    entry = "/vibephone/apps/vibechat/main.lua",
    accent = colors.cyan,
    glyph = "💬",
    multishell = true
  },
  appstore = {
    id = "appstore",
    name = "App Store",
    entry = "/vibephone/apps/appstore/app.lua",
    accent = colors.purple,
    glyph = "⬇",
    multishell = true
  },
  calculator = {
    id = "calculator",
    name = "Calc",
    entry = "/vibephone/apps/calculator/app.lua",
    accent = colors.orange,
    glyph = "∑",
    multishell = true
  },
  controller = {
    id = "controller",
    name = "Ctrl",
    entry = "/vibephone/apps/controller/app.lua",
    accent = colors.lime,
    glyph = "⚙",
    multishell = true
  }
}

-- Merge installed apps from registry (without overwriting built-ins)
local reg = loadRegistry()
for id, a in pairs(reg) do
  if type(id) == "string" and type(a) == "table" then
    if not apps[id] then
      -- minimal validation
      local entry = tostring(a.entry or "")
      local name = tostring(a.name or id)
      if entry ~= "" then
        apps[id] = {
          id = id,
          name = name,
          entry = entry,
          accent = a.accent,
          glyph = a.glyph,
          multishell = (a.multishell ~= false)
        }
      end
    end
  end
end

return apps
