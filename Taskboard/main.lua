local tasks = require("tasks")
tasks.init()

local uiMonitor = require("ui_monitor")
local uiShell = require("ui_shell")

-- Demo data
if #tasks.list == 0 then
    tasks.add("Create city walls", "Stone perimeter", 3)
    tasks.add("Charge batteries", "Solar backup", 2)
end

local shellDirty = true

local function markDirty()
    uiMonitor.markDirty()
    shellDirty = true
end

markDirty()

while true do
    uiMonitor.update(tasks)

    if shellDirty then
        uiShell.draw(tasks)
        shellDirty = false
    end

    local event, p1, p2, p3 = os.pullEvent()

    if event == "monitor_touch" then
        uiMonitor.handleTouch(p2, p3)
        markDirty()
    elseif event == "shell_delete" then
        local index = p1
        tasks.remove(index)
        markDirty()
    elseif event == "shell_edit" then
        local index, title, desc, priority = p1, p2, p3, p4
        tasks.list[index].title = title
        tasks.list[index].description = desc
        tasks.list[index].priority = priority
        markDirty()
    elseif event == "char" then
        uiShell.handleChar(p1)
        shellDirty = true
    elseif event == "key" then
        uiShell.handleKey(p1)
        shellDirty = true
    elseif event == "mouse_click" then
        if uiShell.handleClick(p2, p3) then
            shellDirty = true
        end
    elseif event == "shell_add" then
        local title, desc, priority = p1, p2, p3
        tasks.add(title, desc, priority)
        markDirty()
    elseif event == "key" then
        if p1 == keys.q then
            term.clear()
            return
        end
    end
end
