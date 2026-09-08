require "PalmPilots/PalmPilotNetworkConstants"
require "PalmPilots/PalmPilotData"
require "PalmPilots/PalmPilotDialogs"

PalmPilots.Client = PalmPilots.Client or {}
local Client=PalmPilots.Client
local N=PalmPilots.Network

Client.waitingUIs=Client.waitingUIs or {}

local function localPlayerByOnlineID(onlineID)
    local wanted=tonumber(onlineID)
    for index=0,getNumActivePlayers()-1 do
        local player=getSpecificPlayer(index)
        if player and (wanted==nil or player:getOnlineID()==wanted) then return player end
    end
    return wanted==nil and getPlayer() or nil
end

local function playerNumForArgs(args)
    local player=localPlayerByOnlineID(args and args.recipientOnlineID)
    return player and player:getPlayerNum() or 0
end

function Client.syncDevice(ui)
    Client.syncItem(ui.player,ui.item,ui.data)
end

function Client.syncItem(player,item,data)
    if not isClient() then return end
    sendClientCommand(player,PalmPilots.Constants.MODULE,N.SYNC,{itemID=item:getID(),deviceID=data.deviceID,data=data})
end

local function deviceLabel(item,data)
    data=data or PalmPilots.Data.get(item)
    local label="PalmPilot "..string.sub(data.deviceID,-6)
    if data.deviceName~="" then label=label.." ("..data.deviceName..")" end
    return label
end

local function addInventoryDevices(container,source,result,seen)
    if not container then return end
    local items=container:getItems()
    for index=0,items:size()-1 do
        local item=items:get(index)
        if item:getFullType()==PalmPilots.Constants.ITEM_TYPE
                and not PalmPilots.Utils.sameItem(item,source) and not seen[item:getID()] then
            local data=PalmPilots.Data.get(item)
            if data.beamEnabled then
                seen[item:getID()]=true
                table.insert(result,{item=item,name=deviceLabel(item,data)})
            end
        end
        if instanceof(item,"InventoryContainer") then
            addInventoryDevices(item:getInventory(),source,result,seen)
        end
    end
end

function Client.scanLocalDevices(ui,force)
    local now=PalmPilots.Utils.now()
    if not force and ui.localDeviceScan and now-(ui.localDeviceScanTime or 0)<500 then return ui.localDeviceScan end
    local result,seen={},{}
    addInventoryDevices(ui.player:getInventory(),ui.item,result,seen)
    local range=PalmPilots.Constants.DEVICE_SCAN_RANGE
    local playerX,playerY,playerZ=math.floor(ui.player:getX()),math.floor(ui.player:getY()),math.floor(ui.player:getZ())
    for dx=-range,range do for dy=-range,range do
        local square=getCell():getGridSquare(playerX+dx,playerY+dy,playerZ)
        local objects=square and square:getWorldObjects() or nil
        if objects then for index=0,objects:size()-1 do
            local object=objects:get(index)
            if instanceof(object,"IsoWorldInventoryObject") then
                local item=object:getItem()
                if item and item:getFullType()==PalmPilots.Constants.ITEM_TYPE and item~=ui.item and not seen[item:getID()] then
                    local data=PalmPilots.Data.get(item)
                    if data.beamEnabled then
                        seen[item:getID()]=true
                        table.insert(result,{item=item,name=deviceLabel(item,data)})
                    end
                end
            end
        end end
    end end
    ui.localDeviceScan=result; ui.localDeviceScanTime=now
    return result
end

function Client.transferToLocalDevice(ui,targetItem)
    local available=false
    for _,target in ipairs(Client.scanLocalDevices(ui,true)) do if target.item==targetItem then available=true; break end end
    if not available then PalmPilots.Dialogs.message(getText("UI_PalmPilots_DeviceOutOfRange")); return end
    if isClient() then
        local targetData=PalmPilots.Data.get(targetItem)
        local world=targetItem:getWorldItem()
        local args={itemID=ui.item:getID(),sourceDeviceID=ui.data.deviceID,kind=ui.beamEntry.kind,
            entryID=ui.beamEntry.id,targetItemID=targetItem:getID(),targetDeviceID=targetData.deviceID,
            targetScope=world and "ground" or "inventory"}
        if world and world:getSquare() then
            local square=world:getSquare(); args.x=square:getX(); args.y=square:getY(); args.z=square:getZ()
        end
        sendClientCommand(ui.player,PalmPilots.Constants.MODULE,N.LOCAL_REQUEST,args)
        ui.beamEntry=nil; ui:setScreen("home")
        return
    end
    local source=PalmPilots.Data.findEntry(ui.data,ui.beamEntry.kind,ui.beamEntry.id)
    if not source then PalmPilots.Dialogs.message(getText("UI_PalmPilots_EntryMissing")); return end
    local targetData=PalmPilots.Data.get(targetItem)
    local copy=PalmPilots.Data.copyEntry(source,ui.beamEntry.kind,ui.data.deviceID)
    if not PalmPilots.Data.applyBeamEntry(targetData,copy,ui.beamEntry.kind) then
        PalmPilots.Dialogs.message(getText("UI_PalmPilots_BeamFailed")); return
    end
    targetItem:getModData().PalmPilots=targetData
    ui.beamEntry=nil
    ui:setScreen("home")
    PalmPilots.Dialogs.message(getText("UI_PalmPilots_BeamSent"))
end

function Client.transferAllToLocalDevice(ui,targetItem)
    local available=false
    for _,target in ipairs(Client.scanLocalDevices(ui,true)) do if target.item==targetItem then available=true; break end end
    if not available then PalmPilots.Dialogs.message(getText("UI_PalmPilots_DeviceOutOfRange")); return end
    if isClient() then
        local targetData=PalmPilots.Data.get(targetItem)
        local world=targetItem:getWorldItem()
        local args={itemID=ui.item:getID(),sourceDeviceID=ui.data.deviceID,kind="all",
            targetItemID=targetItem:getID(),targetDeviceID=targetData.deviceID,
            targetScope=world and "ground" or "inventory"}
        if world and world:getSquare() then
            local square=world:getSquare(); args.x=square:getX(); args.y=square:getY(); args.z=square:getZ()
        end
        sendClientCommand(ui.player,PalmPilots.Constants.MODULE,N.LOCAL_REQUEST,args)
        ui.beamAll=nil; ui:setScreen("home")
        return
    end
    local copies=PalmPilots.Data.copyAllEntries(ui.data)
    if #copies.todos==0 and #copies.notes==0 then PalmPilots.Dialogs.message(getText("UI_PalmPilots_NoBeamData")); return end
    local targetData=PalmPilots.Data.get(targetItem)
    for _,task in ipairs(copies.todos) do PalmPilots.Data.applyBeamEntry(targetData,task,"task") end
    for _,note in ipairs(copies.notes) do PalmPilots.Data.applyBeamEntry(targetData,note,"note") end
    targetItem:getModData().PalmPilots=targetData
    ui.beamAll=nil
    ui:setScreen("home")
    PalmPilots.Dialogs.message(getText("UI_PalmPilots_BeamAllSent"))
end

function Client.listTargets(ui)
    Client.waitingUIs[tostring(ui.player:getOnlineID())]=ui
    ui.beamTargetsLoading=isClient()
    ui.scroll=1
    Client.scanLocalDevices(ui,true)
    if isClient() then sendClientCommand(ui.player,PalmPilots.Constants.MODULE,N.LIST_TARGETS,{})
    else ui.beamTargets={}; ui.beamTargetsLoading=false end
end

function Client.requestBeam(ui,targetID,kind,entryID)
    if not isClient() then PalmPilots.Dialogs.message(getText("UI_PalmPilots_MPOnly")); return end
    sendClientCommand(ui.player,PalmPilots.Constants.MODULE,N.REQUEST,{itemID=ui.item:getID(),targetOnlineID=targetID,sourceDeviceID=ui.data.deviceID,kind=kind,entryID=entryID})
end

local function findLocalDevice(deviceID,preferredPlayer)
    local players={}
    if preferredPlayer then table.insert(players,preferredPlayer) end
    for i=0,getNumActivePlayers()-1 do
        local p=getSpecificPlayer(i)
        if p and p~=preferredPlayer then table.insert(players,p) end
    end
    for _,p in ipairs(players) do
        local item=PalmPilots.Utils.findDevice(p,deviceID)
        if item then return item end
        local range=PalmPilots.Constants.DEVICE_SCAN_RANGE
        local px,py,pz=math.floor(p:getX()),math.floor(p:getY()),math.floor(p:getZ())
        for dx=-range,range do for dy=-range,range do
            local square=getCell():getGridSquare(px+dx,py+dy,pz)
            local objects=square and square:getWorldObjects() or nil
            if objects then for index=0,objects:size()-1 do
                local object=objects:get(index)
                if instanceof(object,"IsoWorldInventoryObject") then
                    local groundItem=object:getItem()
                    if groundItem and groundItem:getFullType()==PalmPilots.Constants.ITEM_TYPE then
                        local data=PalmPilots.Data.get(groundItem)
                        if data.deviceID==deviceID then return groundItem end
                    end
                end
            end end
        end end
    end
end

local function firstMainDevice(player)
    return PalmPilots.Utils.findDevice(player,nil,function(_,data) return data.beamEnabled end)
end

local function offerAnswer(_,button,requestID,deviceID)
    local player=getSpecificPlayer(button.player or 0) or getPlayer()
    sendClientCommand(player,PalmPilots.Constants.MODULE,N.RESPOND,{requestID=requestID,accept=button.internal=="YES",receiverDeviceID=deviceID})
end

function Client.onServerCommand(module,command,args)
    if module~=PalmPilots.Constants.MODULE then return end
    args=type(args)=="table" and args or {}
    local recipient=localPlayerByOnlineID(args.recipientOnlineID)
    if command==N.TARGETS then
        local waiting=Client.waitingUIs[tostring(args.recipientOnlineID)]
        if waiting then
            waiting.beamTargets=args.targets or {}
            waiting.beamTargetsLoading=false
            Client.waitingUIs[tostring(args.recipientOnlineID)]=nil
        end
    elseif command==N.OFFER then
        if not recipient then return end
        local item=nil
        local open=PalmPilots.MainUI and PalmPilots.MainUI.instances[recipient:getPlayerNum()]
        if open and PalmPilots.Utils.ownsItem(recipient,open.item) then
            item=open.item
        else
            item=firstMainDevice(recipient)
        end
        if not item then return end
        local data=PalmPilots.Data.get(item)
        local text=getText("UI_PalmPilots_BeamOffer",args.senderName,args.label)
        PalmPilots.Dialogs.confirm(text,nil,offerAnswer,args.requestID,data.deviceID,
            recipient:getPlayerNum())
    elseif command==N.APPLY then
        local item=findLocalDevice(args.deviceID,recipient); if item then
            local data=PalmPilots.Data.get(item)
            if args.kind=="all" then
                for _,task in ipairs(args.todos or {}) do PalmPilots.Data.applyBeamEntry(data,task,"task") end
                for _,note in ipairs(args.notes or {}) do PalmPilots.Data.applyBeamEntry(data,note,"note") end
            else
                PalmPilots.Data.applyBeamEntry(data,args.entry,args.kind)
            end
            for _,open in pairs(PalmPilots.MainUI and PalmPilots.MainUI.instances or {}) do
                if open.itemID==item:getID() then
                    open.item=item
                    open.data=data
                    open.lastNativeBatteryLevel=data.batteryLevel
                    open.nextBatteryUpdate=0
                    if open.invalidateDataViews then open:invalidateDataViews()
                    else open.sortedCache=nil end
                end
            end
            if not args.silent then PalmPilots.Dialogs.message(
                getText(args.kind=="all" and "UI_PalmPilots_BeamAllReceived" or "UI_PalmPilots_BeamReceived"),
                playerNumForArgs(args)) end
        end
    elseif command==N.RESULT then PalmPilots.Dialogs.message(
        getText(args.key or "UI_PalmPilots_BeamFailed"),playerNumForArgs(args)) end
end

Events.OnServerCommand.Add(Client.onServerCommand)
