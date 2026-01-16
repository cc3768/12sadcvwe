-- require_shim.lua
-- CraftOS 1.9 (and some CC builds) may not provide global `require`.
-- This shim provides a minimal require() that loads Lua files and caches them.
--
-- Supports:
--   require("ui")                -> tries ./ui.lua, then /vibephone/ui.lua
--   require("screens.home")      -> screens/home.lua
--   require("/vibephone/config") -> /vibephone/config.lua
--
-- Note: This is NOT LuaRocks/package.path compatible; it's a simple CC loader.

if not _G.require then
  local cache = {}

  local function normalize(name)
    name = tostring(name or "")
    name = name:gsub("\\", "/")
    return name
  end

  local function ensureLuaExt(path)
    if path:sub(-4) ~= ".lua" then return path .. ".lua" end
    return path
  end

  local function exists(path)
    return fs.exists(path) and not fs.isDir(path)
  end

  local function tryPaths(name)
    local n = normalize(name)
    local candidates = {}

    if n:sub(1,1) == "/" then
      local p = ensureLuaExt(n)
      candidates[#candidates+1] = p
    else
      -- dotted module -> path
      local rel = ensureLuaExt(n:gsub("%.", "/"))

      -- 1) relative to current shell dir
      local here = shell and shell.dir and shell.dir() or ""
      if here ~= "" then candidates[#candidates+1] = fs.combine(here, rel) end

      -- 2) relative to program dir (best-effort)
      local prog = shell and shell.getRunningProgram and shell.getRunningProgram() or ""
      if prog ~= "" then candidates[#candidates+1] = fs.combine(fs.getDir(prog), rel) end

      -- 3) vibephone root fallback
      candidates[#candidates+1] = fs.combine("/vibephone", rel)

      -- 4) raw rel (root-relative)
      candidates[#candidates+1] = "/" .. rel
    end

    for _,p in ipairs(candidates) do
      if exists(p) then return p end
    end
    return nil
  end

  _G.require = function(name)
    name = tostring(name)
    if cache[name] ~= nil then return cache[name] end

    local path = tryPaths(name)
    if not path then
      error("module '"..name.."' not found (shim)")
    end

    local result = dofile(path)
    if result == nil then result = true end
    cache[name] = result
    return result
  end
end
