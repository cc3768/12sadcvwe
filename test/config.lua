-- Shared config for BOTH shop and queue computers.
--
-- This file provides:
--   cfg.ui          (colors + title)
--   cfg.materials   (base price + enabled)
--   cfg.grades      (material grade multiplier system)
--   cfg.defaultGrade
--   cfg.partRules   (exclude/allow materials per part)
--   cfg.tools       (tool -> parts)
--   cfg.toolCategories
--   cfg.sales
--   cfg.rednet      (protocol + heartbeat)
--   cfg.monitors

local cfg = {
  ui = {
    title      = "THE FORGE Order Screen",
    background = colors.black,
    header     = colors.gray,
    accent     = colors.cyan,
    -- Optional extras used by the new UI (safe to delete if you want)
    surface    = colors.gray,
    sidebar    = colors.lightGray,
    text       = colors.white,
    textDark   = colors.black,
    ok         = colors.lime,
    warn       = colors.orange,
    danger     = colors.red,
  },

  -- Base price PER PART.
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

  -- Material grade system.
  -- Total = sum(material.price for each part) * grade.mult, then optional sale discount.
  grades = {
    standard   = { label = "Standard",   mult = 1.00, enabled = true },
    refined    = { label = "Refined",    mult = 1.20, enabled = true },
    pristine   = { label = "Pristine",   mult = 1.40, enabled = true },
    masterwork = { label = "Masterwork", mult = 1.60, enabled = true },
  },
  defaultGrade = "standard",

  -- Part material rules.
  --
  -- Examples:
  --   partRules.blade  = { exclude = {"wood","stone"} }
  --   partRules.handle = { allow   = {"wood","iron"} }
  --
  -- Rules are GLOBAL by part name (applies across all tools).
  partRules = {
    -- empty by default
  },

  tools = {
    sword     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    katana    = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    machete   = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    knife     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    dagger    = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    spear     = { parts = {"head","shaft"}, enabled = false },
    trident   = { parts = {"head","shaft"}, enabled = false },
    mace      = { parts = {"head","handle"}, enabled = false },
    shield    = { parts = {"face","handle","rim"}, enabled = false },

    bow        = { parts = {"limbs","string","grip"}, enabled = false },
    crossbow   = { parts = {"frame","string","trigger"}, enabled = false },
    slingshot  = { parts = {"frame","bands"}, enabled = false },
    arrow      = { parts = {"shaft","tip","fletching"}, enabled = false },

    pick       = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    shovel     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    axe        = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    paxel      = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    hammer     = { parts = {"blade","handle","binding","coating","tip","grip"}, enabled = true },
    excavator  = { parts = {"head","handle"}, enabled = false },
    saw        = { parts = {"blade","handle"}, enabled = false },
    prospector_hammer = { parts = {"head","handle"}, enabled = false },
    hoe        = { parts = {"head","handle"}, enabled = false },
    mattock    = { parts = {"head","handle"}, enabled = false },
    sickle     = { parts = {"blade","handle"}, enabled = false },
    shears     = { parts = {"blade","handle"}, enabled = false },
    fishing_pole = { parts = {"rod","reel","line"}, enabled = false },

    helmet     = { parts = {"main","tip","binding","coating","lining"}, enabled = true },
    chestplate = { parts = {"main","tip","binding","coating","lining"}, enabled = true },
    leggings   = { parts = {"main","tip","binding","coating","lining"}, enabled = true },
    boots      = { parts = {"main","tip","binding","coating","lining"}, enabled = true },
    elytra     = { parts = {"wings","frame"}, enabled = false },

    ring       = { parts = {"band","setting"}, enabled = true },
    bracelet   = { parts = {"links","clasp"}, enabled = true },
    necklace   = { parts = {"chain","pendant"}, enabled = true },
  },

  toolCategories = {
    Armor   = {"helmet","chestplate","leggings","boots","elytra"},
    Weapons = {"sword","katana","machete","knife","dagger","spear","trident","mace","shield"},
    Ranged  = {"bow","crossbow","slingshot","arrow"},
    Tools   = {"pick","shovel","axe","paxel","hammer","excavator","saw","prospector_hammer","hoe","mattock","sickle","shears","fishing_pole"},
    Jewelry = {"ring","bracelet","necklace"},
  },

  sales = { enabled = false, discount = 0.20 },

  rednet = { protocol = "shop_queue_v1", heartbeat_interval = 3 },

  monitors = {
    builder = nil, -- optional preferred monitor side/name
    queue   = nil,
  },
}

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
    ui           = cfg.ui,
    materials    = cfg.materials,
    grades       = cfg.grades,
    defaultGrade = cfg.defaultGrade,
    partRules    = cfg.partRules,
    tools        = cfg.tools,
    toolCategories = cfg.toolCategories,
    sales        = cfg.sales,
    rednet       = cfg.rednet,
    monitors     = cfg.monitors,
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
