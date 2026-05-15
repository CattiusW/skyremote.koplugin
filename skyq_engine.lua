local socket = require("socket")
local SkyQEngine = {
    ports = { 49160, 5900 }
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

return SkyQEngine
