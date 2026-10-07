PalmPilots.HomeScreen = PalmPilots.HomeScreen or {}

function PalmPilots.HomeScreen.render(ui)
    ui:title(getText("UI_PalmPilots_Home"))
    local data = ui.data
    local name = data.deviceName ~= "" and data.deviceName or string.sub(data.deviceID, -12)
    ui:text(name, 132, 165, UIFont.Small)
    local battery=tonumber(data.batteryLevel) or 1
    -- icon_5 is the final warning while the device still has power. At zero
    -- the device shuts down, so no battery frame or PalmPilot UI is rendered.
    local batteryKey=battery>0.875 and "full" or (battery>0.625 and "high" or (battery>0.375 and "half" or (battery>0.05 and "low" or "critical")))
    local batteryTexture=ui.batteryTextures and ui.batteryTextures[batteryKey]
    if batteryTexture then ui:drawTextureScaled(batteryTexture,ui:s(458),ui:s(170),ui:s(48),ui:s(15),1,1,1,1) end
    ui:rightText(PalmPilots.Utils.formatGameClock(getGameTime()),592,165,UIFont.Small)
    -- Four compact columns leave room for Settings without pushing an icon
    -- into the handwriting area at the bottom of the LCD.
    local apps = {
        {"todo",116,200}, {"memo",239,200}, {"calculator",362,200}, {"calendar",485,200},
        {"snake",116,395}, {"chess",239,395}, {"beam",362,395}, {"settings",485,395},
    }
    for _, app in ipairs(apps) do
        local appName=app[1]
        ui:iconButton(ui.appTextures[appName],nil,app[2],app[3],110,145,function()
            if appName=="beam" then ui:showBeam() else ui:setScreen(appName) end
        end)
    end
    ui:centerText(getText("UI_PalmPilots_HomeHint"),364,562,UIFont.Small)
end
