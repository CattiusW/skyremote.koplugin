local WidgetContainer = require("ui/widget/container")
local Menu = require("ui/widget/menu")
local Dispatcher = require("device/dispatcher")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local DataStorage = require("datastorage")
local _ = require("gettext")

local SkyRemote = WidgetContainer:extend{
    name = "skyremote",
    cfg_file = "skyremote.json",
}

function SkyRemote:init()
    self.settings = DataStorage:loadSettings(self.cfg_file) or {
        ip = "192.168.1.100",
        bin_path = self.dir .. "/kindle_remote"
    }
    self:initAppMenu()
end

function SkyRemote:initAppMenu()
    Dispatcher:registerNamedCommand("sky_remote_menu", {
        category = "none",
        event = "SkyRemoteMenu",
        title = _("\u{f013} Sky Q Advanced Remote"),
        callback = function() self:showMainMenu() end,
    })
end

function SkyRemote:save_settings()
    DataStorage:saveSettings(self.cfg_file, self.settings)
end

function SkyRemote:send_command(cmd)
    local path = self.settings.bin_path
    os.execute("chmod +x " .. string.format("%q", path))
    
    local full_cmd = string.format("%q %q %s &", path, self.settings.ip, cmd)
    os.execute(full_cmd)
    
    UIManager:show(InfoMessage:new{ text = _("\u{f0e7} Dispatched: " .. cmd:upper()) })
end

function SkyRemote:showMainMenu()
    local main_items = {
        { text = _("\u{f11b} Open Remote Control Panel"), callback = function() self:showControlPanel() end },
        { text = _("\u{f013} Configure Settings"), callback = function() self:showSettingsPanel() end },
    }
    
    local main_menu = Menu:new{
        title = _("\u{f013} Sky Q Remote Utility"),
        item_table = main_items,
    }
    UIManager:show(main_menu)
end

function SkyRemote:showControlPanel()
    local control_items = {
        { text = _("\u{f011} POWER"), keep_menu_open = true, callback = function() self:send_command("power") end },
        { text = _("\u{f05a} INFO"), keep_menu_open = true, callback = function() self:send_command("i") end },
        { text = _("\u{f015} HOME"), keep_menu_open = true, callback = function() self:send_command("home") end },
        { text = _("--------------------------------------------"), enabled = false },
        { text = _("\u{f106} UP"), keep_menu_open = true, callback = function() self:send_command("up") end },
        { text = _("\u{f104} LEFT"), keep_menu_open = true, callback = function() self:send_command("left") end },
        { text = _("\u{f058} SELECT / OK"), keep_menu_open = true, callback = function() self:send_command("select") end },
        { text = _("\u{f105} RIGHT"), keep_menu_open = true, callback = function() self:send_command("right") end },
        { text = _("\u{f107} DOWN"), keep_menu_open = true, callback = function() self:send_command("down") end },
        { text = _("--------------------------------------------"), enabled = false },
        { text = _("\u{f060} DISMISS"), keep_menu_open = true, callback = function() self:send_command("dismiss") end },
        { text = _("\u{f060} BACKUP"), keep_menu_open = true, callback = function() self:send_command("backup") end },
    }
    
    local pad_title = string.format(_("\u{f11b} Sky Q Pad -- Target IP: %s"), self.settings.ip)
    local pad_menu = Menu:new{
        title = pad_title,
        item_table = control_items,
    }
    UIManager:show(pad_menu)
end

function SkyRemote:showSettingsPanel()
    local settings_items = {
        { text = string.format(_("\u{f0ac} Target IP: %s"), self.settings.ip), callback = function() self:promptManualIP() end },
        { text = string.format(_("\u{f07c} Binary Path: %s"), self.settings.bin_path), callback = function() self:promptCustomPath() end },
        { text = _("\u{f002} Scan Network Subnet"), callback = function() self:executeNetworkScan() end },
    }
    
    local settings_menu = Menu:new{
        title = _("\u{f013} Sky Q Parameters"),
        item_table = settings_items,
    }
    UIManager:show(settings_menu)
end

function SkyRemote:promptManualIP()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("\u{f0ac} Modify Device IP Target"),
        fields = {
            { description = _("Sky Q Box IPv4 Address"), text = self.settings.ip }
        },
        buttons = {
            { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
            { text = _("\u{f0c7} Save"), callback = function()
                local inputs = dialog:getFieldsText()
                if inputs and inputs and inputs ~= "" then
                    self.settings.ip = inputs
                    self:save_settings()
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new{ text = _("\u{f00c} IP Target Saved.") })
                end
            end }
        }
    }
    UIManager:show(dialog)
end

function SkyRemote:promptCustomPath()
    local dialog
    dialog = MultiInputDialog:new{
        title = _("\u{f07c} Alter Binary Location"),
        fields = {
            { description = _("Full Executable File Path"), text = self.settings.bin_path }
        },
        buttons = {
            { text = _("Cancel"), callback = function() UIManager:close(dialog) end },
            { text = _("\u{f0c7} Save"), callback = function()
                local inputs = dialog:getFieldsText()
                if inputs and inputs and inputs ~= "" then
                    self.settings.bin_path = inputs
                    self:save_settings()
                    UIManager:close(dialog)
                    UIManager:show(InfoMessage:new{ text = _("\u{f00c} Binary Path Saved.") })
                end
            end }
        }
    }
    UIManager:show(dialog)
end

function SkyRemote:executeNetworkScan()
    UIManager:show(InfoMessage:new{ text = _("\u{f012} Scanning subnet... Please wait...") })
    
    local handle = io.popen("ip route get 1.1.1.1 2>/dev/null")
    if not handle then return end
    local result = handle:read("*a")
    handle:close()
    
    local local_ip = result:match("src%s+(%d+%.%d+%.%d+%.%d+)")
    if not local_ip then
        UIManager:show(InfoMessage:new{ text = _("\u{f00d} Error: WiFi disconnected.") })
        return
    end
    
    local base_subnet = local_ip:match("(%d+%.%d+%.%d+%.)")
    local identified_box_target = nil
    
    for host_id = 1, 254 do
        local test_ip = base_subnet .. host_id
        local cmd = string.format("nc -z -w 1 %s 49160 2>/dev/null", test_ip)
        local exit_status = os.execute(cmd)
        
        if exit_status == 0 then
            identified_box_target = test_ip
            break
        end
    end
    
    if identified_box_target then
        self.settings.ip = identified_box_target
        self:save_settings()
        UIManager:show(InfoMessage:new{ text = string.format(_("\u{f00c} Found Box! Configured: %s"), identified_box_target) })
    else
        UIManager:show(InfoMessage:new{ text = _("\u{f00d} No box found. Check power or enter IP manually.") })
    end
end

return SkyRemote
