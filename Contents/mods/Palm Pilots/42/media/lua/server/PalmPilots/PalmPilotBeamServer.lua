require "PalmPilots/PalmPilotNetworkConstants"
require "PalmPilots/PalmPilotData"

PalmPilots.BeamServer = PalmPilots.BeamServer or {}
local Beam=PalmPilots.BeamServer
local N=PalmPilots.Network
local C=PalmPilots.Constants
local U=PalmPilots.Utils
local D=PalmPilots.Data

Beam.pending={}
Beam.lastCleanup=0

local function result(player,key)
    if player then sendServerCommand(player,C.MODULE,N.RESULT,
        {key=key,recipientOnlineID=player:getOnlineID()}) end
end

local function mainDeviceByID(player,itemID,deviceID,requireBeam)
    if not player or not player:getInventory() then return nil end
    local item=itemID and U.findItemByID(player,itemID) or nil
    if item and item:getFullType()==C.ITEM_TYPE then
        local data=D.get(item); if (not deviceID or data.deviceID==deviceID) and (not requireBeam or data.beamEnabled) then return item,data end
    end
    item=U.findDevice(player,deviceID,function(_,data) return not requireBeam or data.beamEnabled end)
    if item then return item,D.get(item) end
    return nil
end

local function validPlayer(player)
    return player and not player:isDead() and player:getOnlineID()>=0
end

local function validKind(kind)
    return kind=="task" or kind=="note" or kind=="all"
end

local function applyPayload(sourceData,targetData,kind,entryID)
    local applyArgs={deviceID=targetData.deviceID,kind=kind}
    if kind=="all" then
        local copies=D.copyAllEntries(sourceData)
        if #copies.todos==0 and #copies.notes==0 then return nil,"UI_PalmPilots_NoBeamData" end
        local applied={todos={},notes={}}
        for _,task in ipairs(copies.todos) do
            local entry=D.applyBeamEntry(targetData,task,"task")
            if entry then table.insert(applied.todos,entry) end
        end
        for _,note in ipairs(copies.notes) do
            local entry=D.applyBeamEntry(targetData,note,"note")
            if entry then table.insert(applied.notes,entry) end
        end
        applyArgs.todos=applied.todos; applyArgs.notes=applied.notes
    else
        local entry=D.findEntry(sourceData,kind,tostring(entryID or ""))
        if not entry then return nil,"UI_PalmPilots_EntryMissing" end
        local copy=D.copyEntry(entry,kind,sourceData.deviceID)
        if not copy then return nil,"UI_PalmPilots_BeamFailed" end
        local applied=D.applyBeamEntry(targetData,copy,kind)
        if not applied then return nil,"UI_PalmPilots_BeamFailed" end
        applyArgs.entry=applied
    end
    return applyArgs
end

local function groundDevice(sender,args)
    local x,y,z=tonumber(args.x),tonumber(args.y),tonumber(args.z)
    if not x or not y or not z or math.floor(sender:getZ())~=math.floor(z) then return nil end
    x,y,z=math.floor(x),math.floor(y),math.floor(z)
    local senderX,senderY=math.floor(sender:getX()),math.floor(sender:getY())
    if math.abs(senderX-x)>C.DEVICE_SCAN_RANGE or math.abs(senderY-y)>C.DEVICE_SCAN_RANGE then return nil end
    local square=getCell():getGridSquare(x,y,z)
    local objects=square and square:getWorldObjects() or nil
    if not objects then return nil end
    local wantedID=tonumber(args.targetItemID)
    local wantedDevice=tostring(args.targetDeviceID or "")
    for index=0,objects:size()-1 do
        local object=objects:get(index)
        if instanceof(object,"IsoWorldInventoryObject") then
            local item=object:getItem()
            if item and item:getID()==wantedID and item:getFullType()==C.ITEM_TYPE then
                local data=D.get(item)
                if data.deviceID==wantedDevice and data.beamEnabled then return item,data,object end
            end
        end
    end
    return nil
end

function Beam.localRequest(sender,args)
    if not validPlayer(sender) or not validKind(args.kind) then return end
    local source,sourceData=mainDeviceByID(sender,args.itemID,tostring(args.sourceDeviceID or ""))
    if not source then result(sender,"UI_PalmPilots_DeviceMissing"); return end
    local target,targetData,worldObject
    if args.targetScope=="inventory" then
        target,targetData=mainDeviceByID(sender,args.targetItemID,tostring(args.targetDeviceID or ""),true)
    elseif args.targetScope=="ground" then
        target,targetData,worldObject=groundDevice(sender,args)
    end
    if not target or target==source then result(sender,"UI_PalmPilots_DeviceOutOfRange"); return end
    local applyArgs,errorKey=applyPayload(sourceData,targetData,args.kind,args.entryID)
    if not applyArgs then result(sender,errorKey); return end
    target:getModData().PalmPilots=targetData
    if worldObject then
        worldObject:sendObjectChange(IsoObjectChange.SWAP_ITEM)
    elseif target:getContainer() then
        syncItemModData(sender,target)
    end
    applyArgs.silent=true
    applyArgs.recipientOnlineID=sender:getOnlineID()
    sendServerCommand(sender,C.MODULE,N.APPLY,applyArgs)
    result(sender,args.kind=="all" and "UI_PalmPilots_BeamAllSent" or "UI_PalmPilots_BeamSent")
end

function Beam.listTargets(sender)
    local targets={}; local players=getOnlinePlayers()
    for i=0,players:size()-1 do local other=players:get(i)
        if other~=sender and validPlayer(other) and U.sameFloor(sender,other) and U.distance(sender,other)<=C.BEAM_RANGE then
            local _,data=mainDeviceByID(other,nil,nil,true)
            if data then
                local name=other:getDisplayName().." - PalmPilot "..string.sub(data.deviceID,-6)
                if data.deviceName~="" then name=name.." ("..data.deviceName..")" end
                table.insert(targets,{onlineID=other:getOnlineID(),name=name})
            end
        end
    end
    sendServerCommand(sender,C.MODULE,N.TARGETS,
        {targets=targets,recipientOnlineID=sender:getOnlineID()})
end

function Beam.request(sender,args)
    if not validPlayer(sender) then return end
    local receiver=getPlayerByOnlineID(tonumber(args.targetOnlineID) or -1)
    if not validPlayer(receiver) or receiver==sender or not U.sameFloor(sender,receiver) or U.distance(sender,receiver)>C.BEAM_RANGE then result(sender,"UI_PalmPilots_InvalidReceiver"); return end
    local source,data=mainDeviceByID(sender,args.itemID,tostring(args.sourceDeviceID or ""))
    if not source then result(sender,"UI_PalmPilots_DeviceMissing"); return end
    if not validKind(args.kind) then result(sender,"UI_PalmPilots_BeamFailed"); return end
    local entry=nil
    if args.kind=="all" then
        if #data.todos==0 and #data.notes==0 then result(sender,"UI_PalmPilots_NoBeamData"); return end
    else
        entry=D.findEntry(data,args.kind,tostring(args.entryID or ""))
        if not entry then result(sender,"UI_PalmPilots_EntryMissing"); return end
        if args.kind=="task" and #entry.title>C.MAX_TASK_TEXT then result(sender,"UI_PalmPilots_BeamFailed"); return end
        if args.kind=="note" and (#entry.title>C.MAX_NOTE_TITLE or #entry.body>C.MAX_NOTE_BODY) then result(sender,"UI_PalmPilots_BeamFailed"); return end
    end
    if not mainDeviceByID(receiver,nil,nil,true) then result(sender,"UI_PalmPilots_BeamPrivate"); return end
    local pendingCount=0
    for _,pending in pairs(Beam.pending) do
        if pending.senderID==sender:getOnlineID() and not pending.used then
            pendingCount=pendingCount+1
        end
    end
    if pendingCount>=C.BEAM_MAX_PENDING_PER_PLAYER then
        result(sender,"UI_PalmPilots_BeamFailed")
        return
    end
    local requestID=U.newID("beam")
    Beam.pending[requestID]={id=requestID,senderID=sender:getOnlineID(),receiverID=receiver:getOnlineID(),sourceDeviceID=data.deviceID,
        sourceItemID=source:getID(),kind=args.kind,entryID=entry and entry.id or nil,expires=U.now()+C.BEAM_TIMEOUT_MS,used=false}
    local label=args.kind=="all" and getText("UI_PalmPilots_AllData") or entry.title
    sendServerCommand(receiver,C.MODULE,N.OFFER,{requestID=requestID,
        senderName=sender:getDisplayName(),label=label,kind=args.kind,
        recipientOnlineID=receiver:getOnlineID()})
end

function Beam.respond(receiver,args)
    local pending=Beam.pending[tostring(args.requestID or "")]
    if not pending or pending.used or pending.receiverID~=receiver:getOnlineID() then result(receiver,"UI_PalmPilots_BeamExpired"); return end
    pending.used=true; Beam.pending[pending.id]=nil
    local sender=getPlayerByOnlineID(pending.senderID)
    if not validPlayer(sender) or not validPlayer(receiver) or U.now()>pending.expires or not U.sameFloor(sender,receiver) or U.distance(sender,receiver)>C.BEAM_RANGE then
        result(receiver,"UI_PalmPilots_BeamExpired"); result(sender,"UI_PalmPilots_BeamExpired"); return
    end
    if args.accept~=true then result(sender,"UI_PalmPilots_BeamDeclined"); return end
    local source,sourceData=mainDeviceByID(sender,pending.sourceItemID,pending.sourceDeviceID)
    local target,targetData=mainDeviceByID(receiver,nil,tostring(args.receiverDeviceID or ""),true)
    if not source or not target then result(sender,"UI_PalmPilots_DeviceMissing"); result(receiver,"UI_PalmPilots_DeviceMissing"); return end
    local applyArgs={deviceID=targetData.deviceID,kind=pending.kind}
    if pending.kind=="all" then
        local copies=D.copyAllEntries(sourceData)
        if #copies.todos==0 and #copies.notes==0 then result(sender,"UI_PalmPilots_NoBeamData"); return end
        local applied={todos={},notes={}}
        for _,task in ipairs(copies.todos) do
            local entry=D.applyBeamEntry(targetData,task,"task")
            if entry then table.insert(applied.todos,entry) end
        end
        for _,note in ipairs(copies.notes) do
            local entry=D.applyBeamEntry(targetData,note,"note")
            if entry then table.insert(applied.notes,entry) end
        end
        applyArgs.todos=applied.todos
        applyArgs.notes=applied.notes
    else
        local entry=D.findEntry(sourceData,pending.kind,pending.entryID)
        if not entry then result(sender,"UI_PalmPilots_EntryMissing"); return end
        local copy=D.copyEntry(entry,pending.kind,sourceData.deviceID)
        if not copy then result(sender,"UI_PalmPilots_BeamFailed"); return end
        local applied=D.applyBeamEntry(targetData,copy,pending.kind)
        if not applied then result(sender,"UI_PalmPilots_BeamFailed"); return end
        applyArgs.entry=applied
    end
    target:getModData().PalmPilots=targetData
    syncItemModData(receiver,target)
    applyArgs.recipientOnlineID=receiver:getOnlineID()
    sendServerCommand(receiver,C.MODULE,N.APPLY,applyArgs)
    result(sender,pending.kind=="all" and "UI_PalmPilots_BeamAllSent" or "UI_PalmPilots_BeamSent")
end

function Beam.cleanup()
    local now=U.now(); if now-Beam.lastCleanup<1000 then return end; Beam.lastCleanup=now
    for id,pending in pairs(Beam.pending) do if now>pending.expires then
        local sender=getPlayerByOnlineID(pending.senderID); result(sender,"UI_PalmPilots_BeamExpired"); Beam.pending[id]=nil
    end end
end

Events.OnTick.Add(Beam.cleanup)
