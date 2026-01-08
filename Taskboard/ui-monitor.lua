local util = require("util")

local ui = {
    buttons = {},
    dirty = true,
    mode = "list", -- list | detail
    selected = nil,
    tasksPerPage = 8,
    page = 1,
    anim = 0 -- 0..1 animation progress
}

ui.monitor = peripheral.find("monitor")
assert(ui.monitor, "Advanced Monitor not found")

ui.monitor.setTextScale(1)
ui.w, ui.h = ui.monitor.getSize()

-- ---------- Colors ----------
local C = {
    bg = colors.black,
    header = colors.gray,
    text = colors.white,
    doneBtn = colors.gray,
    doneText = colors.white,
    overlay = colors.black,
    card = colors.lightGray,
    danger = colors.red
}

local function priorityColor(p)
    if p == 3 then return colors.red end
    if p == 2 then return colors.orange end
    return colors.lightGray
end

local function maxPages(tasks)
    return math.max(1, math.ceil(#tasks.list / ui.tasksPerPage))
end

-- ---------- Helpers ----------
function ui.markDirty()
    ui.dirty = true
end

function ui.clear()
    ui.monitor.setBackgroundColor(C.bg)
    ui.monitor.setTextColor(C.text)
    ui.monitor.clear()
    ui.buttons = {}
end

local function addButton(x1, y1, x2, y2, action)
    table.insert(ui.buttons, {
        x1 = x1, y1 = y1,
        x2 = x2, y2 = y2,
        action = action
    })
end

local function fillLine(y, bg)
    ui.monitor.setCursorPos(1, y)
    ui.monitor.setBackgroundColor(bg)
    ui.monitor.write(string.rep(" ", ui.w))
end

-- ---------- Animated Detail Popup ----------
local function drawDetail(tasks)
    local t = tasks.list[ui.selected]
    if not t then
        ui.mode = "list"
        ui.anim = 0
        ui.markDirty()
        return
    end

    -- Animate in
    ui.anim = math.min(1, ui.anim + 0.25)

    -- Dim background
    for y = 1, ui.h do
        fillLine(y, C.overlay)
    end

    local cardW = math.min(ui.w - 4, 32)
    local cardH = 9

local centerY = math.floor((ui.h - cardH) / 2) + 1
local startY = math.min(10, centerY)
local y1 = math.floor(startY + (centerY - startY) * ui.anim)
    local x1 = math.floor((ui.w - cardW) / 2) + 1

    -- Card
    for y = 0, cardH - 1 do
        ui.monitor.setCursorPos(x1, y1 + y)
        ui.monitor.setBackgroundColor(C.card)
        ui.monitor.write(string.rep(" ", cardW))
    end

    ui.monitor.setTextColor(colors.black)

    -- Title
    ui.monitor.setCursorPos(x1 + 2, y1 + 1)
    ui.monitor.write(t.title:sub(1, cardW - 4))

    -- Description
    ui.monitor.setCursorPos(x1 + 2, y1 + 3)
    ui.monitor.write((t.description or "No description"):sub(1, cardW - 4))

    -- Buttons
    local btnY = y1 + cardH - 2

    -- CLOSE
    local closeTxt = " CLOSE "
    local closeX = x1 + 2
    ui.monitor.setCursorPos(closeX, btnY)
    ui.monitor.setBackgroundColor(colors.gray)
    ui.monitor.setTextColor(colors.white)
    ui.monitor.write(closeTxt)

    addButton(
        closeX,
        btnY,
        closeX + #closeTxt - 1,
        btnY,
        function()
            ui.anim = 0
            ui.mode = "list"
            ui.selected = nil
            ui.markDirty()
        end
    )

    -- DELETE (only if completed)
    if t.completed then
        local delTxt = " DELETE "
        local delX = x1 + cardW - #delTxt - 2

        ui.monitor.setCursorPos(delX, btnY)
        ui.monitor.setBackgroundColor(C.danger)
        ui.monitor.setTextColor(colors.white)
        ui.monitor.write(delTxt)

        addButton(
            delX,
            btnY,
            delX + #delTxt - 1,
            btnY,
            function()
                tasks.remove(ui.selected)
                ui.anim = 0
                ui.mode = "list"
                ui.selected = nil
                ui.markDirty()
            end
        )
    end

    if ui.anim < 1 then
        ui.markDirty()
    end
end

-- ---------- Draw List ----------
function ui.draw(tasks)
    ui.clear()
    tasks.sort()
    ui.page = math.min(ui.page, maxPages(tasks))

    -- Header
    fillLine(1, C.header)
    ui.monitor.setCursorPos(4, 1)
    ui.monitor.setTextColor(colors.black)
    ui.monitor.write("TASKS")

    ui.monitor.setCursorPos(ui.w - 8, 1)
    ui.monitor.write("Page " .. ui.page)

    local totalPages = maxPages(tasks)

    if ui.page > 1 then
        ui.monitor.setCursorPos(1, 1)
        ui.monitor.setBackgroundColor(colors.lightGray)
        ui.monitor.setTextColor(colors.black)
        ui.monitor.write(" < ")
        addButton(1, 1, 3, 1, function()
            ui.page = ui.page - 1
            ui.markDirty()
        end)
    end

    if ui.page < totalPages then
        ui.monitor.setCursorPos(ui.w - 2, 1)
        ui.monitor.setBackgroundColor(colors.lightGray)
        ui.monitor.setTextColor(colors.black)
        ui.monitor.write(" > ")
        addButton(ui.w - 2, 1, ui.w, 1, function()
            ui.page = ui.page + 1
            ui.markDirty()
        end)
    end

    -- Tasks
    local start = (ui.page - 1) * ui.tasksPerPage + 1
    local finish = math.min(#tasks.list, start + ui.tasksPerPage - 1)

    local y = 3
    local h = 3

    for i = start, finish do
        local t = tasks.list[i]
        local bg = t.completed and colors.green or priorityColor(t.priority)

        for r = 0, h - 1 do
            fillLine(y + r, bg)
        end

        ui.monitor.setCursorPos(3, y + 1)
        ui.monitor.setTextColor(colors.black)
        ui.monitor.write(t.title:sub(1, ui.w - 14))

        local bx1 = ui.w - 7
        local bx2 = ui.w

        for r = 0, h - 1 do
            ui.monitor.setCursorPos(bx1, y + r)
            ui.monitor.setBackgroundColor(C.doneBtn)
            ui.monitor.write(string.rep(" ", bx2 - bx1 + 1))
        end

        ui.monitor.setCursorPos(bx1 + 1, y + 1)
        ui.monitor.setTextColor(C.doneText)
        ui.monitor.write("DONE")

        addButton(bx1, y, bx2, y + h - 1, function()
            tasks.toggleComplete(i)
            ui.markDirty()
        end)

        addButton(1, y, bx1 - 1, y + h - 1, function()
            ui.selected = i
            ui.mode = "detail"
            ui.anim = 0
            ui.markDirty()
        end)

        y = y + h + 1
    end

    ui.dirty = false
end

-- ---------- Input ----------
function ui.handleTouch(x, y)
    for _, b in ipairs(ui.buttons) do
        if x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
            util.safe(b.action)
            return
        end
    end
end

-- ---------- Update ----------
function ui.update(tasks)
    if not ui.dirty then return end
    if ui.mode == "detail" then
        drawDetail(tasks)
    else
        ui.draw(tasks)
    end
end

return ui
