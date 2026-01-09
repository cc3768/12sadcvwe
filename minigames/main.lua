local game = dofile("pos_MiniGame.lua")

local ok, won = pcall(game.Play)
if not ok then
  print("Minigame error:")
  print(won)
  won = false
end
--made by cc3768
if won then
  game.GameWon()
  print("You won the minigame!")
else
  game.GameLost()
  print("You lost the minigame.")
end