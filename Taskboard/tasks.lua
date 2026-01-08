--========================================
-- tasks.lua
-- Task data + persistence (DB-backed)
--========================================

local tasks = {}

--====================
-- Config
--====================
local DB_FILE = "tasks.db"

--====================
-- State
--====================
tasks.list = {}

--====================
-- Internal helpers
--====================
local function save()
    local f = fs.open(DB_FILE, "w")
    if not f then
        error("Failed to open task DB for writing")
    end
    f.write(textutils.serialize(tasks.list))
    f.close()
end

local function load()
    if not fs.exists(DB_FILE) then
        tasks.list = {}
        return
    end

    local f = fs.open(DB_FILE, "r")
    if not f then
        error("Failed to open task DB for reading")
    end

    local data = f.readAll()
    f.close()

    local parsed = textutils.unserialize(data)
    if type(parsed) ~= "table" then
        error("Task DB is corrupted or invalid")
    end

    tasks.list = parsed
end

--====================
-- Public API
--====================
function tasks.init()
    load()
end

function tasks.add(title, description, priority)
    table.insert(tasks.list, {
        title = title,
        description = description or "",
        priority = priority or 2,
        completed = false
    })
    save()
end

function tasks.remove(index)
    if tasks.list[index] then
        table.remove(tasks.list, index)
        save()
    end
end

function tasks.toggleComplete(index)
    if tasks.list[index] then
        tasks.list[index].completed = not tasks.list[index].completed
        save()
    end
end

function tasks.sort()
    table.sort(tasks.list, function(a, b)
        if a.completed ~= b.completed then
            return not a.completed
        end
        return (a.priority or 2) > (b.priority or 2)
    end)
end

return tasks
