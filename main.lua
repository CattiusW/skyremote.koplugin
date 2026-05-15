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
    self.box_ip = G_reader_settings:readSetting("skyq_box_ip") or ""
    self:addToMainMenu()
end

function SkyQRemotePlugin:executeAction(command_bytes)
    local success, error_msg = SkyQEngine.sendCommand(self.box_ip, command_bytes)
    if not success then self:showAlert("Error: " .. error_msg) end
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
}

function SkyQRemoteWindow:init()
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
        -- Top Row: Core Application and Base Navigation Entry Shortcuts
        HorizontalGroup:new{
            makeButton("APPS 📱", "apps", 0.24),
            makeButton("⌂ HOME", "home", 0.24),
            makeButton("↩ BACK", "dismiss", 0.24),
        },
        -- Power Management Line Block
        HorizontalGroup:new{
            makeButton("⏻ POWER TOGGLE", "power", 0.76)
        },
        -- Structural D-Pad Hub Controls
        HorizontalGroup:new{ makeButton("▲ UP", "up") },
        HorizontalGroup:new{
            makeButton("◀ LEFT", "left"),
            makeButton("[ OK ]", "select"),
            makeButton("RIGHT ▶", "right"),
        },
        HorizontalGroup:new{ makeButton("▼ DOWN", "down") },
        -- Media Streaming Control Playback Scrubber Row
        HorizontalGroup:new{
            makeButton("⏪ REW", "rewind", 0.22),
            makeButton("⏯ PLAY", "play", 0.32),
            makeButton("FFW ⏩", "fast_fwd", 0.22),
        },
        -- Quick Dismiss Modal Link Element
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
    self = layout
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
                    local new_ip = input_dialog:getFields()
                    if new_ip and new_ip ~= "" then
                        self.box_ip = new_ip
                        G_reader_settings:saveSetting("skyq_box_ip", new_ip)
                        UIManager:close(input_dialog)
                    end
                end
            }
        }
    }
    UIManager:show(input_dialog)
end

function SkyQRemotePlugin:addToMainMenu()
    self.ui.menu:registerWidget("skyq_remote_root", {
        text = "Streaming Media Panel",
        path = {"tools"},
        sub_menu = {
            { text = "📺 Open Stream Controller UI", action = function() self:openRemotePanel() end },
            { text = "🔍 Auto Scan for Sky Q Box", action = function() self:runAutodiscovery() end },
            { text = "⚙️ Manual IP Edit...", action = function() self:configureIP() end },
        }
    })
end

return SkyQRemotePlugin
