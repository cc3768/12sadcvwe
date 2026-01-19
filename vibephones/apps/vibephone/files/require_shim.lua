-- VibePhone require shim (global)
-- Fix: supports ROM modules/APIs (e.g. require("cc.audio.dfpwm"))
-- Path: /vibephone/require_shim.lua

if not _G.require then
  local cache = {}

  local function ensureLua(p)
    p = tostring(p or "")
    if p:sub(-4) ~= ".lua" then return p .. ".lua" end
    return p
  end

  local function exists(p)
    return fs.exists(p) and not fs.isDir(p)
  end

  local function tryPath(p)
    p = tostring(p or ""):gsub("\\","/")
    if p == "" then return nil end
    local lp = ensureLua(p)
    if exists(lp) then return lp end
    return nil
  end

  -- Best-effort app dir (whatever is currently running)
  local function getRunning()
    if shell and shell.getRunningProgram then
      local rp = shell.getRunningProgram()
      if rp and rp ~= "" then return rp end
    end
    return "/vibephone/main.lua"
  end

  local APP_DIR = fs.getDir(getRunning())

  local function nameToRel(name)
    name = tostring(name or ""):gsub("\\","/")
    -- if user already passed a path-like module, keep slashes
    if name:find("/") then return ensureLua(name) end
    -- dotted module -> path
    return ensureLua(name:gsub("%.","/"))
  end

  local function resolve(name)
    name = tostring(name or ""):gsub("\\","/")

    -- 1) absolute path
    if name:sub(1,1) == "/" then
      return tryPath(name)
    end

    local rel = nameToRel(name)

    -- 2) app-local (current app folder)
    local p1 = fs.combine(APP_DIR, rel)
    local hit = tryPath(p1)
    if hit then return hit end

    -- 3) shared vibephone libs (allow require("ui") etc. to map to /vibephone/ui.lua)
    local p2 = fs.combine("/vibephone", rel)
    hit = tryPath(p2)
    if hit then return hit end

    -- 4) ROM modules (common CC:Tweaked locations)
    -- cc.audio.dfpwm is usually in /rom/modules/main/cc/audio/dfpwm.lua
    local romCandidates = {
      fs.combine("/rom/modules/main", rel),
      fs.combine("/rom/modules", rel),
      fs.combine("/rom/apis", rel),
      fs.combine("/rom", rel),
    }
    for _,p in ipairs(romCandidates) do
      hit = tryPath(p)
      if hit then return hit end
    end

    return nil
  end

  _G.require = function(name)
    name = tostring(name or "")
    if cache[name] ~= nil then return cache[name] end

    local path = resolve(name)
    if not path then
      error("module '"..name.."' not found (require_shim)", 2)
    end

    local r = dofile(path)
    if r == nil then r = true end
    cache[name] = r
    return r
  end
end
