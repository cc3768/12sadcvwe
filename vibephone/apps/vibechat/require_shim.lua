-- /vibephone/apps/vibechat/require_shim.lua
-- ALWAYS overrides _G.require and resolves modules inside this app folder.

do
  local cache = {}

  local function ensureLua(p)
    if p:sub(-4) ~= ".lua" then return p .. ".lua" end
    return p
  end

  local function exists(p)
    return fs.exists(p) and not fs.isDir(p)
  end

  -- main.lua sets _G.__VC_ENTRY before loading this shim
  local entry = _G.__VC_ENTRY
  if type(entry) ~= "string" or entry == "" then
    if shell and shell.getRunningProgram then
      entry = shell.getRunningProgram()
    end
  end
  if type(entry) ~= "string" or entry == "" then
    entry = "/vibephone/apps/vibechat/main.lua"
  end

  local APP_DIR = fs.getDir(entry)

  local function resolve(name)
    name = tostring(name):gsub("\\","/")

    if name:sub(1,1) == "/" then
      local p = ensureLua(name)
      if exists(p) then return p end
      return nil
    end

    local rel = ensureLua(name:gsub("%.","/"))
    local p1 = fs.combine(APP_DIR, rel)
    if exists(p1) then return p1 end

    return nil
  end

  _G.require = function(name)
    name = tostring(name)
    if cache[name] ~= nil then return cache[name] end

    local path = resolve(name)
    if not path then error("module '"..name.."' not found (shim)") end

    local r = dofile(path)
    if r == nil then r = true end
    cache[name] = r
    return r
  end
end
