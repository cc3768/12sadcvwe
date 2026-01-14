local M = {}
local PATH = "orders.db"
M.orders = {}

function M.load()
  if fs.exists(PATH) then
    local f = fs.open(PATH, "r")
    M.orders = textutils.unserialize(f.readAll()) or {}
    f.close()
  end
end

function M.save()
  local f = fs.open(PATH, "w")
  f.write(textutils.serialize(M.orders))
  f.close()
end

return M
