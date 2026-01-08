--========================================
-- Task Manager Installer (Pastebin)
--========================================

if not http then
    error("HTTP is disabled. Enable http.enabled = true in CC:Tweaked config.")
end

local BASE_DIR = "task_manager"

local FILES = {
    main       = "eNA8MisR",
    tasks      = "UELeMUzw",
    ui_monitor = "P6ughPkH",
    ui_shell   = "F69gqx3c",
    util       = "xgfH44Gz",
}

--====================
-- Helpers
--====================
local function fetchPaste(id)
    local url = "https://pastebin.com/raw/" .. id
    local h = http.get(url)
    if not h then
        return nil, "Failed to fetch Pastebin ID: " .. id
    end
    local data = h.readAll()
    h.close()
    return data
end

local function writeFile(path, data)
    local f = fs.open(path, "w")
    if not f then
        return false
    end
    f.write(data)
    f.close()
    return true
end

--====================
-- Install Start
--====================
print("Installing Task Manager...")
print("Target directory: /" .. BASE_DIR)

if not fs.exists(BASE_DIR) then
    fs.makeDir(BASE_DIR)
    print("Created directory:", BASE_DIR)
else
    print("Directory already exists, updating files")
end

for name, pasteId in pairs(FILES) do
    print("Downloading", name .. ".lua", "...")

    local data, err = fetchPaste(pasteId)
    if not data then
        error(err)
    end

    local path = fs.combine(BASE_DIR, name .. ".lua")
    if not writeFile(path, data) then
        error("Failed to write file: " .. path)
    end

    print("✔ Installed", name .. ".lua")
end

print("\nInstallation complete!")
print("Run with:")
print("cd " .. BASE_DIR)
print("main")
