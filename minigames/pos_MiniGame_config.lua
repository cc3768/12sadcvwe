-- pos_Minigame_config.lua
-- Config for pos_Minigame.lua
--made by cc3768
return {
  -- Set to a side like: "top", "left", "right", "back", "front", "bottom"
  -- Leave nil to auto-detect the first connected monitor.
  monitorSide = nil,

  -- 0.5 looks good on a 3x2 advanced monitor
  textScale = 0.5,

  -- Min/Max rounds required (the game picks a random number between these each run)
  minRounds = 6,
  maxRounds = 14,

  -- How long (seconds) before the dot fully fades to red and you lose
  baseTimeSeconds = 1.8,      -- starting time window
  timeDecayPerRound = 0.06,   -- reduces time each successful tap
  minTimeSeconds = 0.55,      -- never faster than this window

  -- Difficulty thresholds
  moveAfter = 5,              -- after 5 taps, dot starts sliding
  fastAfter = 10,             -- after 10 taps, everything speeds up a bit

  -- Sliding speed (seconds per 1-tile step)
  moveInterval = 0.65,        -- slower sliding
  fastMoveInterval = 0.45,    -- faster after fastAfter, but still reasonable

  -- Dot size in characters
  dotSize = 2,

  -- UI rows reserved at the top (progress/instructions)
  uiRows = 2,
}
