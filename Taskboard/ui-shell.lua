local shellUI = {
    buttons = {},
    mode = "list", -- list | add | edit
    selected = nil,
    page = 1,
    perPage = 5,
    temp = {
        title = "",
        desc = "",
        priority = 2,
        field = "title",
        editIndex = nil
    }
}

-- ---------- Helpers ----------
local function resetTerm()
    term.setCursorBlink(false)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function addButton(x1, y1, x2, y2, action)
    table.insert(shellUI.buttons, {
        x1 = x1, y1 = y1,
        x2 = x2, y2 = y2,
        action = action
    })
end

local function inside(x, y, b)
    return x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2
end

local function maxPages(tasks)
    return math.max(1, math.ceil(#tasks.list / shellUI.perPage))
end

local function priorityColor(t)
    if t.completed then return colors.green end
    if t.priority == 3 then return colors.red end
    if t.priority == 2 then return colors.orange end
    return colors.lightGray
end

local function statusLabel(t)
    if t.completed then return " DONE " end
    if t.priority == 3 then return " HIGH " end
    if t.priority == 2 then return " MED  " end
    return " LOW  "
end

-- ---------- ADD / EDIT POPUP ----------
local function drawTaskPopup(isEdit)
    resetTerm()
    shellUI.buttons = {}

    local w, h = term.getSize()
    local pw, ph = 44, 14
    local x = math.floor((w - pw) / 2) + 1
    local y = math.floor((h - ph) / 2)

    for i = 0, ph - 1 do
        term.setCursorPos(x, y + i)
        term.setBackgroundColor(colors.gray)
        term.write(string.rep(" ", pw))
    end

    term.setTextColor(colors.black)
    term.setCursorPos(x + 2, y + 1)
    term.write(isEdit and "EDIT TASK" or "ADD TASK")

    -- Title
    term.setCursorPos(x + 2, y + 3)
    term.write("Title:")
    term.setCursorPos(x + 9, y + 3)
    term.setBackgroundColor(shellUI.temp.field == "title" and colors.white or colors.lightGray)
    term.write((shellUI.temp.title .. " "):sub(1, pw - 11))
    addButton(x + 9, y + 3, x + pw - 2, y + 3, function()
        shellUI.temp.field = "title"
    end)

    -- Description
    term.setCursorPos(x + 2, y + 5)
    term.setBackgroundColor(colors.gray)
    term.write("Desc:")
    term.setCursorPos(x + 9, y + 5)
    term.setBackgroundColor(shellUI.temp.field == "desc" and colors.white or colors.lightGray)
    term.write((shellUI.temp.desc .. " "):sub(1, pw - 11))
    addButton(x + 9, y + 5, x + pw - 2, y + 5, function()
        shellUI.temp.field = "desc"
    end)

    -- Priority
    term.setCursorPos(x + 2, y + 7)
    term.write("Priority:")

    local function prio(px, label, value)
        local sel = shellUI.temp.priority == value
        term.setCursorPos(px, y + 7)
        term.setBackgroundColor(sel and colors.white or priorityColor({ priority = value }))
        term.write(" " .. label .. " ")
        addButton(px, y + 7, px + #label + 1, y + 7, function()
            shellUI.temp.priority = value
        end)
    end

    prio(x + 13, "LOW", 1)
    prio(x + 19, "MED", 2)
    prio(x + 25, "HIGH", 3)

    -- Confirm
    term.setCursorPos(x + 10, y + 10)
    term.setBackgroundColor(colors.green)
    term.write(isEdit and " SAVE " or " ADD ")
    addButton(x + 10, y + 10, x + 17, y + 10, function()
        if isEdit then
            os.queueEvent(
                "shell_edit",
                shellUI.temp.editIndex,
                shellUI.temp.title,
                shellUI.temp.desc,
                shellUI.temp.priority
            )
        else
            os.queueEvent(
                "shell_add",
                shellUI.temp.title,
                shellUI.temp.desc,
                shellUI.temp.priority
            )
        end

        shellUI.temp = { title = "", desc = "", priority = 2, field = "title", editIndex = nil }
        shellUI.mode = "list"
    end)

    -- Cancel
    term.setCursorPos(x + 22, y + 10)
    term.setBackgroundColor(colors.red)
    term.write(" CANCEL ")
    addButton(x + 22, y + 10, x + 29, y + 10, function()
        shellUI.temp = { title = "", desc = "", priority = 2, field = "title", editIndex = nil }
        shellUI.mode = "list"
    end)

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- ---------- MAIN DRAW ----------
function shellUI.draw(tasks)
    if shellUI.mode == "add" then
        drawTaskPopup(false)
        return
    elseif shellUI.mode == "edit" then
        drawTaskPopup(true)
        return
    end

    resetTerm()
    shellUI.buttons = {}

    local w, h = term.getSize()
    local totalPages = maxPages(tasks)
    shellUI.page = math.min(shellUI.page, totalPages)

    -- Header
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.black)
    term.write(string.rep(" ", w))
    term.setCursorPos(3, 1)
    term.write("TASK MANAGER")

    term.setCursorPos(w - 12, 1)
    term.write("Page " .. shellUI.page .. "/" .. totalPages)

    -- Page buttons
    if shellUI.page > 1 then
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.lightGray)
        term.write("<")
        addButton(1, 1, 1, 1, function()
            shellUI.page = shellUI.page - 1
            shellUI.selected = nil
        end)
    end

    if shellUI.page < totalPages then
        term.setCursorPos(w, 1)
        term.setBackgroundColor(colors.lightGray)
        term.write(">")
        addButton(w, 1, w, 1, function()
            shellUI.page = shellUI.page + 1
            shellUI.selected = nil
        end)
    end

    -- Task list
    local start = (shellUI.page - 1) * shellUI.perPage + 1
    local finish = math.min(#tasks.list, start + shellUI.perPage - 1)

    local y = 3
    for i = start, finish do
        local t = tasks.list[i]
        local selected = shellUI.selected == i

        for r = 0, 1 do
            term.setCursorPos(2, y + r)
            term.setBackgroundColor(selected and colors.blue or priorityColor(t))
            term.write(string.rep(" ", w - 2))
        end

        term.setCursorPos(4, y)
        term.setTextColor(colors.black)
        term.write(t.title:sub(1, w - 12))

        term.setCursorPos(w - 7, y)
        term.write(statusLabel(t))

        addButton(2, y, w - 1, y + 1, function()
            shellUI.selected = i
        end)

        y = y + 3
    end

    -- Footer
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", w))

    local x = 3

    term.setCursorPos(x, h)
    term.setBackgroundColor(colors.lightGray)
    term.write(" ADD ")
    addButton(x, h, x + 5, h, function()
        shellUI.mode = "add"
    end)
    x = x + 8

    if shellUI.selected then
        term.setCursorPos(x, h)
        term.setBackgroundColor(colors.orange)
        term.write(" EDIT ")
        addButton(x, h, x + 6, h, function()
            local t = tasks.list[shellUI.selected]
            shellUI.temp.title = t.title
            shellUI.temp.desc = t.description or ""
            shellUI.temp.priority = t.priority
            shellUI.temp.editIndex = shellUI.selected
            shellUI.temp.field = "title"
            shellUI.mode = "edit"
        end)
        x = x + 9

        term.setCursorPos(x, h)
        term.setBackgroundColor(colors.red)
        term.write(" DELETE ")
        addButton(x, h, x + 8, h, function()
            os.queueEvent("shell_delete", shellUI.selected)
            shellUI.selected = nil
        end)
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- ---------- INPUT ----------
function shellUI.handleChar(c)
    if shellUI.mode == "add" or shellUI.mode == "edit" then
        local field = shellUI.temp.field
        shellUI.temp[field] = shellUI.temp[field] .. c
    end
end

function shellUI.handleKey(key)
    if shellUI.mode == "add" or shellUI.mode == "edit" then
        local field = shellUI.temp.field
        if key == keys.backspace then
            shellUI.temp[field] = shellUI.temp[field]:sub(1, -2)
        elseif key == keys.enter then
            shellUI.temp.field = (field == "title") and "desc" or "title"
        end
    end
end

function shellUI.handleClick(x, y)
    for _, b in ipairs(shellUI.buttons) do
        if inside(x, y, b) then
            b.action()
            return true
        end
    end
    return false
end

return shellUI
