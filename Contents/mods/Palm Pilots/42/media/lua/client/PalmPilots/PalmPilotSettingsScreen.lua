PalmPilots.SettingsScreen = PalmPilots.SettingsScreen or {}
local S=PalmPilots.SettingsScreen
local C=PalmPilots.Constants

local function nicknameDone(ui,button)
    if button.internal~="OK" then return end
    ui.data.deviceName=PalmPilots.Utils.clampText(button.parent.entry:getText(),C.MAX_DEVICE_NAME)
    ui.localDeviceScan=nil
    ui:save()
end

function S.render(ui)
    ui:title(getText("UI_PalmPilots_Settings"))

    ui:text(getText("UI_PalmPilots_DeviceNickname"),140,195,UIFont.Medium)
    ui:box(140,230,440,48)
    local nickname=ui.data.deviceName~="" and ui.data.deviceName or getText("UI_PalmPilots_NotSet")
    ui:text(nickname,154,242,UIFont.Small)
    ui:wrappedText(getText("UI_PalmPilots_NicknameHint"),140,292,440,0,2)
    ui:button(getText("UI_PalmPilots_ChangeNickname"),140,345,210,40,function()
        PalmPilots.Dialogs.input(getText("UI_PalmPilots_DeviceNickname"),ui.data.deviceName,C.MAX_DEVICE_NAME,false,ui,nicknameDone)
    end)
    ui:button(getText("UI_PalmPilots_ClearNickname"),370,345,210,40,function()
        ui.data.deviceName=""
        ui.localDeviceScan=nil
        ui:save()
    end)

    ui:text(getText("UI_PalmPilots_BeamPrivacy"),140,425,UIFont.Medium)
    local enabled=ui.data.beamEnabled ~= false
    ui:button(getText(enabled and "UI_PalmPilots_BeamOn" or "UI_PalmPilots_BeamOff"),140,460,210,44,function()
        ui.data.beamEnabled=not enabled
        ui.localDeviceScan=nil
        ui:save()
    end)
    ui:wrappedText(getText(enabled and "UI_PalmPilots_BeamOnHint" or "UI_PalmPilots_BeamOffHint"),370,460,210,0,3)

    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() ui:setScreen("home") end)
end
