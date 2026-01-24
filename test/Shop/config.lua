-- config.lua
-- Shared config for BOTH shop (builder) and queue computers.
-- Saved overrides are stored in config.db (textutils.serialize).

local cfg = {

  -- =========================
  -- UI THEME
  -- =========================
  ui = {
    title      = "THE FORGE Order Screen",
    background = colors.black,
    header     = colors.gray,
    accent     = colors.cyan,
  },

  -- =========================
  -- MATERIALS (base price)
  -- =========================
  materials = {
    none        = { price = 0,   enabled = true },
    wood        = { price = 5,   enabled = true },
    stone       = { price = 10,  enabled = true },
    iron        = { price = 20,  enabled = true },
    gold        = { price = 35,  enabled = true },
    diamond     = { price = 75,  enabled = true },
    netherite   = { price = 120, enabled = true },
    speed_alloy = { price = 150, enabled = true },
  },

  -- =========================
  -- GRADES (applied per-part)
  -- price formula per part:
  --   final = base * mult + add
  -- =========================
  gradeDefault = "basic",

  grades = {
    { id = "basic",  label = "Basic",  mult = 1.00, add = 0,  enabled = true },
    { id = "fine",   label = "Fine",   mult = 1.15, add = 5,  enabled = true },
    { id = "master", label = "Master", mult = 1.35, add = 15, enabled = true },
  },

  -- =========================
  -- MATERIAL EXCLUSIONS
  -- =========================
  -- Global exclusions by part name (applies to all tools):
  --   partMaterialExclusions = { blade = { wood=true, stone=true } }
  partMaterialExclusions = {},

  -- Per-tool exclusions by part name:
  --   cfg.tools.sword.exclude = { blade = { wood=true } }
  -- (kept under each tool definition)

  -- =========================
  -- TOOL / PART DEFINITIONS
  -- =========================
  tools = {
    -- Weapons
    sword     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    katana    = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    machete   = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    knife     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    dagger    = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    spear     = { parts = {"head","shaft"}, enabled = false },
    trident   = { parts = {"head","shaft"}, enabled = false },
    mace      = { parts = {"head","handle"}, enabled = false },
    shield    = { parts = {"plate","rim","boss","strap"}, enabled = false },

    -- Ranged
    bow        = { parts = {"limbs","string","grip"}, enabled = false },
    crossbow   = { parts = {"frame","string","trigger"}, enabled = false },
    slingshot  = { parts = {"frame","bands"}, enabled = false },
    arrow      = { parts = {"shaft","tip","fletching"}, enabled = false },

    -- Tools
    pick       = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    shovel     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    axe        = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    paxel      = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    hammer     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    excavator  = { parts = {"head","handle"}, enabled = false },
    saw        = { parts = {"blade","handle"}, enabled = false },
    hoe        = { parts = {"blade","handle"}, enabled = false },
    mattock    = { parts = {"blade","handle"}, enabled = false },
    sickle     = { parts = {"blade","handle"}, enabled = false },
    shears     = { parts = {"blades","hinge","grip"}, enabled = false },
    fishing_pole = { parts = {"rod","reel","line","hook"}, enabled = false },

    -- Armor
    helmet     = { parts = {"main","lining","strap"}, enabled = true },
    chestplate = { parts = {"front","back","straps","lining"}, enabled = true },
    leggings   = { parts = {"waist","legs","lining"}, enabled = true },
    boots      = { parts = {"main","tip","binding","coating","lining"}, enabled = true },
    elytra     = { parts = {"wings","frame"}, enabled = false },

    -- Jewelry
    ring       = { parts = {"band","setting"}, enabled = true },
    bracelet   = { parts = {"links","clasp"}, enabled = true },
    necklace   = { parts = {"chain","pendant"}, enabled = true },
  },

  toolCategories = {
    Armor   = {"helmet","chestplate","leggings","boots","elytra"},
    Weapons = {"sword","katana","machete","knife","dagger","spear","trident","mace","shield"},
    Ranged  = {"bow","crossbow","slingshot","arrow"},
    Tools   = {"pick","shovel","axe","paxel","hammer","excavator","saw","hoe","mattock","sickle","shears","fishing_pole"},
    Jewelry = {"ring","bracelet","necklace"},
  },

  -- =========================
  -- SALES (optional)
  -- =========================
  sales = { enabled = false, discount = 0.20 },

  -- =========================
  -- NETWORK / DEVICES
  -- =========================
  rednet = { protocol = "shop_queue_v1", heartbeat_interval = 3 },
  monitors = { builder = nil, queue = nil },
  peripherals = { playerDetectorSide = nil },
}

-- ============================================================
-- Persisted overrides
-- ============================================================
local PATH = "config.db"

local function merge(dst, src)
  for k,v in pairs(src or {}) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

local function snapshot()
  return {
    ui = cfg.ui,
    materials = cfg.materials,
    grades = cfg.grades,
    gradeDefault = cfg.gradeDefault,
    partMaterialExclusions = cfg.partMaterialExclusions,
    tools = cfg.tools,
    toolCategories = cfg.toolCategories,
    sales = cfg.sales,
    rednet = cfg.rednet,
    monitors = cfg.monitors,
    peripherals = cfg.peripherals,
  }
end

if fs.exists(PATH) then
  local f = fs.open(PATH, "r")
  local loaded = textutils.unserialize(f.readAll())
  f.close()
  if loaded then merge(cfg, loaded) end
end

function cfg.save()
  local f = fs.open(PATH, "w")
  f.write(textutils.serialize(snapshot()))
  f.close()
end

return cfg
