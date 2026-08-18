PalmPilots.BeamScreen = PalmPilots.BeamScreen or {}
local S=PalmPilots.BeamScreen

function S.count(ui)
    local count=#PalmPilots.Client.scanLocalDevices(ui,false)
    count=count+#(ui.beamTargets or {})
    return count
end

function S.visible(ui)
    return (ui.beamEntry or ui.beamAll) and 6 or 5
end

function S.render(ui)
    ui:title(getText("UI_PalmPilots_Beam"))
    local devices=PalmPilots.Client.scanLocalDevices(ui,false)
    local targets=ui.beamTargets or {}
    if not ui.beamEntry and not ui.beamAll then
        ui:wrappedText(getText("UI_PalmPilots_BeamInstructions"),140,185,430,0,3)
        local nearby={}
        for _,device in ipairs(devices) do table.insert(nearby,device.name) end
        for _,target in ipairs(targets) do table.insert(nearby,target.name) end
        ui:text(getText("UI_PalmPilots_NearbyDevices")..": "..tostring(#nearby),140,255,UIFont.Medium)
        if #nearby==0 then ui:text(getText("UI_PalmPilots_NoNearbyDevices"),145,300,UIFont.Small) end
        local visible=5
        local maximum=math.max(1,#nearby-visible+1)
        local first=math.max(1,math.min(maximum,ui.scroll or 1))
        ui.scroll=first
        local shown=math.min(visible,#nearby-first+1)
        for row=0,shown-1 do
            local index=first+row
            ui:box(140,285+row*48,440,40)
            ui:text(nearby[index],152,295+row*48,UIFont.Small)
        end
        ui:scrollBar(#nearby,first,visible)
        local beamAllY=math.max(360,math.min(525,297+shown*48))
        ui:button(getText("UI_PalmPilots_BeamAll"),140,beamAllY,150,38,function()
            if #(ui.data.todos or {})==0 and #(ui.data.notes or {})==0 then
                PalmPilots.Dialogs.message(getText("UI_PalmPilots_NoBeamData")); return
            end
            ui.beamAll=true
            PalmPilots.Client.listTargets(ui)
        end)
        ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() ui:setScreen("home") end); return
    end
    ui:text(getText("UI_PalmPilots_SelectReceiver"),140,185,UIFont.Medium)
    if #targets==0 and #devices==0 then ui:text(getText("UI_PalmPilots_NoReceivers"),150,250,UIFont.Small) end
    local entries={}
    for _,device in ipairs(devices) do table.insert(entries,{localItem=device.item,name=device.name}) end
    for _,target in ipairs(targets) do table.insert(entries,{receiver=target,name=target.name}) end
    local visible=6
    local maximum=math.max(1,#entries-visible+1)
    local first=math.max(1,math.min(maximum,ui.scroll or 1))
    ui.scroll=first
    for row=0,visible-1 do
        local entry=entries[first+row]
        if not entry then break end
        local targetItem=entry.localItem
        local receiver=entry.receiver
        ui:button(entry.name,145,220+row*50,410,42,function()
            if receiver then
                local kind,entryID
                if ui.beamAll then
                    kind="all"
                else
                    kind=ui.beamEntry.kind
                    entryID=ui.beamEntry.id
                end
                PalmPilots.Client.requestBeam(ui,receiver.onlineID,kind,entryID)
                ui.beamEntry=nil; ui.beamAll=nil; ui:setScreen("home")
                return
            end
            if ui.beamAll then PalmPilots.Client.transferAllToLocalDevice(ui,targetItem)
            else PalmPilots.Client.transferToLocalDevice(ui,targetItem) end
        end)
    end
    ui:scrollBar(#entries,first,visible)
    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() ui.beamEntry=nil; ui.beamAll=nil; ui:setScreen("home") end)
end
