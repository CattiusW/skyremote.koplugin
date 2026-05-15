local socket = require("socket")
local SkyQEngine = {
    ports = { 49160, 5900 },
    cached_ip = nil,
    cache_timeout = 3600  -- Cache for 1 hour (in seconds)
}

-- Raw button commands strictly optimized for streaming platform navigation
SkyQEngine.CMD = {
    power    = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 2, 4),
    home     = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 22),
    dismiss  = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 23),
    up       = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 1),
    down     = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 2),
    left     = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 3),
    right    = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 4),
    select   = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 21),
    play     = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 11),
    rewind   = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 15),
    fast_fwd = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 14),
    apps     = string.char(4, 1, 0, 0, 0, 0, 0, 0, 4, 1, 0, 0, 0, 0, 1, 8), -- Direct Apps sidebar toggle
}

function SkyQEngine.sendCommand(ip, command_bytes)
    if not ip or ip == "" then return false, "No IP Specified" end
    local tcp = socket.tcp()
    tcp:settimeout(1.2)
    
    for _, port in ipairs(SkyQEngine.ports) do
        local success, err = tcp:connect(ip, port)
        if success then
            tcp:send(command_bytes)
            tcp:close()
            return true
        end
    end
    tcp:close()
    return false, "Box Unreachable"
end

-- Verify cached IP is still reachable
function SkyQEngine.verifyCachedIP(ip)
    if not ip then return false end
    local tcp = socket.tcp()
    tcp:settimeout(0.5)  -- Quick timeout for verification
    
    for _, port in ipairs(SkyQEngine.ports) do
        local success = tcp:connect(ip, port)
        tcp:close()
        if success then return true end
        tcp = socket.tcp()
        tcp:settimeout(0.5)
    end
    tcp:close()
    return false
end

function SkyQEngine.scanSubnet()
    local probe = socket.udp()
    probe:setpeername("8.8.8.8", 80)
    local local_ip = probe:getsockname()
    probe:close()
    if not local_ip then return nil, "Wi-Fi Disconnected" end
    local prefix = local_ip:match("(%d+%.%d+%.%d+%.)")
    
    local sockets = {}
    for i = 1, 254 do
        local ip = prefix .. i
        local s = socket.tcp()
        s:settimeout(0)
        s:connect(ip, 49160)
        sockets[ip] = s
    end
    socket.select(nil, nil, 1.5)
    for ip, s in pairs(sockets) do
        local res, err = s:connect(ip, 49160)
        s:close()
        if res or err == "already connected" then return ip end
    end
    return nil, "No Sky Q Box found"
end

-- Find Sky Q box with caching. Pass force=true to ignore cache and do full scan
function SkyQEngine.findBox(force)
    -- Try cached IP first if available and not forcing a new scan
    if not force and SkyQEngine.cached_ip then
        if SkyQEngine.verifyCachedIP(SkyQEngine.cached_ip) then
            return SkyQEngine.cached_ip, "cached"
        end
        -- Cached IP is dead, clear it
        SkyQEngine.cached_ip = nil
    end
    
    -- Do full subnet scan
    local ip, err = SkyQEngine.scanSubnet()
    if ip then
        SkyQEngine.cached_ip = ip
        return ip, "scanned"
    end
    return nil, err
end

-- Clear cached IP manually (useful if user switches boxes)
function SkyQEngine.clearCache()
    SkyQEngine.cached_ip = nil
end

return SkyQEngine
