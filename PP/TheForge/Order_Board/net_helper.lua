local M = {}

function M.getMonitor(preferredSide)
  if preferredSide and peripheral.getType(preferredSide) == "monitor" then
    return peripheral.wrap(preferredSide)
  end
  return peripheral.find("monitor")
end

function M.openModem()
  if rednet.isOpen() then return true end
  local modem = peripheral.find("modem")
  if not modem then return false, "No modem attached" end
  rednet.open(peripheral.getName(modem))
  return true
end

return M
