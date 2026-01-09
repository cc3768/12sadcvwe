-- Quiz_Minigame_config.lua
-- Put your questions + answers here.

return {
  title = "QUIZ",

  -- 3x2 advanced monitor: 0.5 gives more room
  textScale = 0.5,

  -- How many questions per run (random between min and max)
  minQuestions = 3,
  maxQuestions = 5,

  -- Time allowed per question
  timeLimitSeconds = 12,

  -- If true: one wrong answer immediately loses
  failOnWrong = true,

  -- Simple theme colors
  colors = {
    bg       = colors.black,
    header   = colors.cyan,
    timer    = colors.yellow,
    question = colors.white,

    btnBg     = colors.gray,
    btnBorder = colors.lightGray,
    btnText   = colors.white,
  },

  -- Questions format:
  -- {
  --   question = "text",
  --   answers  = {"A", "B", "C", "D"},
  --   correct  = 1 -- index into answers
  -- }
  questions = {
    {
      question = "What does CC stand for in CC:Tweaked?",
      answers  = { "ComputerCraft", "CodeCraft", "CreativeCore", "CraftComputer" },
      correct  = 1
    },
    {
      question = "Which event fires when you touch a monitor?",
      answers  = { "monitor_press", "monitor_touch", "touch_monitor", "screen_touch" },
      correct  = 2
    },
    {
      question = "Which function pauses execution for a number of seconds?",
      answers  = { "wait()", "delay()", "sleep()", "pause()" },
      correct  = 3
    },
    {
      question = "What does dofile() do?",
      answers  = { "Deletes a file", "Loads and runs a Lua file", "Lists files", "Compiles bytecode only" },
      correct  = 2
    },
    {
      question = "Which one is a valid color constant in CC?",
      answers  = { "colors.lime", "colors.purpleish", "colors.ultra", "colors.clear" },
      correct  = 1
    },
  }
}
