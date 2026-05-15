local WidgetContainer = require("ui/widget/widgetcontainer")
local InputContainer = require("ui/widget/inputcontainer")
local UIManager = require("ui/uimanager")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local InfoMessage = require("ui/widget/infomessage")
local Button = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local VerticalGroup = require("ui/widget/verticalgroup")
local G_reader_settings = require("luasettings")
local Screen = require("device").screen
local SkyQEngine = require("skyq_engine")

local SkyQRemotePlugin = WidgetContainer:extend{
    name = "skyq_remote",
    box_ip = nil,
}

function SkyQRemotePlugin:init()
    -- FIX: Native KOReader object lifecycle base initialization mandatory requirement
    WidgetContainer.init(self)
    self.box_ip = G_reader_settings:readSetting("skyq_box_ip") or ""
    self:addToMainMenu()
end

function SkyQRemotePlugin:executeAction(command_bytes)
    local success, error_msg = SkyQEngine.sendCommand(self.box_ip, command_bytes)
    if not success then self:showAlert("Error: " .. tostring(error_msg)) end
end

function SkyQRemotePlugin:runAutodiscovery()
    self:showAlert("Scanning network for Sky Q...")
    local discovered_ip, err = SkyQEngine.scanSubnet()
    if discovered_ip then
        self.box_ip = discovered_ip
        G_reader_settings:saveSetting("skyq_box_ip", discovered_ip)
        self:showAlert("Connected to Box at: " .. discovered_ip)
    else
        self:showAlert("Scan failed: " .. tostring(err))
    end
end

function SkyQRemotePlugin:showAlert(text)
    local info = InfoMessage:new{ text = text }
    UIManager:show(info)
end

local SkyQRemoteWindow = InputContainer:extend{
    align = "center",
    valign = "center",
    is_popout = true, -- FIX: Prevents underlying background screen artifacts from corrupting panel redraws
}

function SkyQRemoteWindow:init()
    -- FIX: InputContainer initialization setup prevents application execution failure loops
    InputContainer.init(self)
    
    local function makeButton(label, cmd_key, width_ratio)
        return Button:new{
            text = label,
            width = math.floor(Screen:getWidth() * (width_ratio or 0.28)),
            height = 75,
            margin = 5,
            show_parent = self,
            callback = function() self.plugin:executeAction(SkyQEngine.CMD[cmd_key]) end,
        }
    end

    local layout = VerticalGroup:new{
        align = "center",
        HorizontalGroup:new{
            makeButton("APPS ", "apps", 0.24),
            makeButton("HOME", "home", 0.24),
            makeButton("BACK", "dismiss", 0.24),
        },
        HorizontalGroup:new{
            makeButton("⏻ POWER TOGGLE", "power", 0.76)
        },
        HorizontalGroup:new{ makeButton("▲ UP", "up") },
        HorizontalGroup:new{
            makeButton("◀ LEFT", "left"),
            makeButton("[ OK ]", "select"),
            makeButton("RIGHT ▶", "right"),
        },
        HorizontalGroup:new{ makeButton("▼ DOWN", "down") },
        HorizontalGroup:new{
            makeButton("REW", "rewind", 0.22),
            makeButton("PLAY", "play", 0.32),
            makeButton("FFW", "fast_fwd", 0.22),
        },
        HorizontalGroup:new{
            Button:new{
                text = "✕ CLOSE PANEL",
                width = math.floor(Screen:getWidth() * 0.76),
                height = 75,
                margin = 12,
                callback = function() UIManager:close(self) end,
            }
        }
    }
    
    self:setChild(layout)
    -- FIX: Forces the wrapper module dimension footprints to accurately wrap layout geometries
    self.dimen = layout:getSize()
end

function SkyQRemotePlugin:openRemotePanel()
    if not self.box_ip or self.box_ip == "" then
        self:showAlert("Run Network Scan first to map your target TV box.")
        return
    end
    local remote_window = SkyQRemoteWindow:new{ plugin = self }
    UIManager:show(remote_window)
end

function SkyQRemotePlugin:configureIP()
    local input_dialog
    input_dialog = MultiInputDialog:new{
        title = "IP Target Configuration",
        fields = {{ text = self.box_ip, input_type = "number" }},
        buttons = {
            { text = "Cancel", id = "close", action = function() UIManager:close(input_dialog) end },
            {
                text = "Save", id = "save", is_default = true,
                action = function()
                    local fields = input_dialog:getFields()
                    -- FIX: Evaluates deep internal text instances using API value fetching models instead of reading direct table pointers
                    if fields and fields[1] then
                        local new_ip = fields[1]:getText()
                        if new_ip and new_ip ~= "" then
                            self.box_ip = new_ip
                            G_reader_settings:saveSetting("skyq_box_ip", new_ip)
                        end
                    end
                    UIManager:close(input_dialog)
                end
            }
        }
    }
    UIManager:show(input_dialog)
end

function SkyQRemotePlugin:addToMainMenu()
    -- FIX: Direct injection workaround hook structure used to safely map entries into KOReader plugins sub-menu space
    local Dispatcher = require("device/dispatcher")
    Dispatcher:registerAction("skyq_remote_open", {
        category = "tools",
        title = "Streaming Media Panel",
        event = "SkyQRemoteOpen",
        callback = function() self:openRemotePanel() end,
    })
end

return SkyQRemotePlugin
