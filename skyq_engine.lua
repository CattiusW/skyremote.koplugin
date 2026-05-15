local socket = require("socket")
local SkyQEngine = {
    ports = { 49160 },
    cached_ip = nil,
    cache_timeout = 3600
}

-- Mapped directly to your structural main.lua keys using corrected dual-phase byte arrays
SkyQEngine.CMD = {
    power    = string.char(0),
    home     = string.char(1),
    dismiss  = string.char(7), -- Acts as the hardware Back/Dismiss command layout
    up       = string.char(2),
    down     = string.char(3),
    left     = string.char(4),
    right    = string.char(5),
    select   = string.char(6),
    play     = string.char(64),
    rewind   = string.char(66),
    fast_fwd = string.char(67),
    apps     = string.char(1),   -- Fallback to Home if native apps sidebar isn't supported via IP
}

function SkyQEngine.sendCommand(ip, command_byte)
    if not ip or ip == "" then return false, "No IP Specified" end
    if not command_byte or command_byte == "" then return false, "Invalid Command Key" end
    
    local code = string.byte(command_byte)
    local tcp = socket.tcp()
    tcp:settimeout(1.5)
    
    local success, err = tcp:connect(ip, 49160)
    if not success then
        tcp:close()
        return false, "Box Connection Timeout"
    end

    -- Mandatory Handshake Sequence: Consume security buffers sent by the Sky Q hardware
    local handshake1, h1_err = tcp:receive(12)
    if not handshake1 then tcp:close() return false, "Handshake 1 Fail: " .. tostring(h1_err) end
    
    tcp:send("") -- Structural mirror acknowledgment pulse
    
    local handshake2, h2_err = tcp:receive(10)
    if not handshake2 then tcp:close() return false, "Handshake 2 Fail: " .. tostring(h2_err) end

    -- Phase 1: Transmit Key Down (Press Button) Packet Frame
    local press_packet = string.char(3, 0, 0, 0, 1, 1, math.floor(code / 256), code % 256)
    local _, p_err = tcp:send(press_packet)
    if p_err then tcp:close() return false, "Press State Drop" end

    -- Phase 2: Transmit Key Up (Release Button) Packet Frame
    local release_packet = string.char(3, 0, 0, 0, 1, 0, math.floor(code / 256), code % 256)
    local _, r_err = tcp:send(release_packet)
    if r_err then tcp:close() return false, "Release State Drop" end

    tcp:close()
    return true
end

function SkyQEngine.verifyCachedIP(ip)
    if not ip or ip == "" then return false end
    local tcp = socket.tcp()
    tcp:settimeout(0.5)
    local success = tcp:connect(ip, 49160)
    tcp:close()
    return success and true or false
end

function SkyQEngine.scanSubnet()
    local probe = socket.udp()
    -- Non-routing query to safely capture local infrastructure gateway details
    probe:setpeername("8.8.8.8", 80)
    local local_ip = probe:getsockname()
    probe:close()
    if not local_ip then return nil, "Wi-Fi Disconnected" end
    
    local prefix = local_ip:match("(%d+%.%d+%.%d+%.)")
    local sockets = {}
    
    for i = 1, 254 do
        local ip = prefix .. i
        local s = socket.tcp()
        s:settimeout(0) -- Non-blocking instant state allocation loop
        s:connect(ip, 49160)
        sockets[ip] = s
    end
    
    socket.select(nil, nil, 1.2) -- Allocation safety timeout window
    
    for ip, s in pairs(sockets) do
        local res, err = s:connect(ip, 49160)
        s:close()
        if res or err == "already connected" then 
            return ip 
        end
    end
    return nil, "Sky Q Box missing from local subnet paths"
end

function SkyQEngine.findBox(force)
    if not force and SkyQEngine.cached_ip then
        if SkyQEngine.verifyCachedIP(SkyQEngine.cached_ip) then
            return SkyQEngine.cached_ip, "cached"
        end
        SkyQEngine.cached_ip = nil
    end
    
    local ip, err = SkyQEngine.scanSubnet()
    if ip then
        SkyQEngine.cached_ip = ip
        return ip, "scanned"
    end
    return nil, err
end

function SkyQEngine.clearCache()
    SkyQEngine.cached_ip = nil
end

return SkyQEngine
