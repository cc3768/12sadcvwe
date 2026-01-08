local util = {}

function util.safe(fn)
    local ok, err = pcall(fn)
    if not ok then
        print("ERROR:", err)
    end
end

function util.clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
end

return util

