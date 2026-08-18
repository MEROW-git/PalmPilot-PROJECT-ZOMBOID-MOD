require "PalmPilots/PalmPilotBeamServer"

PalmPilots.ServerCommands = PalmPilots.ServerCommands or {}
local Server=PalmPilots.ServerCommands
local N=PalmPilots.Network
local C=PalmPilots.Constants

Server.commandTimes=Server.commandTimes or {}
local commandIntervals={
    [N.SYNC]=50,
    [N.LIST_TARGETS]=250,
    [N.REQUEST]=500,
    [N.LOCAL_REQUEST]=250,
    [N.RESPOND]=250,
}

local function allowCommand(player,command)
    if not player then return false end
    local interval=commandIntervals[command] or 0
    if interval<=0 then return true end
    local key=tostring(player:getOnlineID())..":"..tostring(command)
    local now=PalmPilots.Utils.now()
    local previous=Server.commandTimes[key]
    if previous and now-previous<interval then return false end
    Server.commandTimes[key]=now
    return true
end

local function sync(player,args)
    if type(args)~="table" or type(args.data)~="table" then return end
    local item=PalmPilots.Utils.findItemByID(player,args.itemID)
    if not item or item:getFullType()~=C.ITEM_TYPE then PalmPilots.Utils.log("Rejected device sync: item not owned"); return end
    local current=PalmPilots.Data.get(item)
    if current.deviceID~=tostring(args.deviceID or "") then PalmPilots.Utils.log("Rejected device sync: ID mismatch"); return end
    local clean=PalmPilots.Data.sanitize(args.data,false)
    if clean.deviceID~=tostring(args.deviceID or "") or clean.deviceID=="" then PalmPilots.Utils.log("Rejected device sync: invalid ID"); return end
    clean.deviceID=current.deviceID
    clean.boundItemID=current.boundItemID
    if clean.batteryLevel>current.batteryLevel then
        clean.batteryLevel=current.batteryLevel
        clean.batteryInstalled=current.batteryInstalled
    end
    item:getModData().PalmPilots=clean
    PalmPilots.Data.setBatteryLevel(item,clean,clean.batteryLevel)
    PalmPilots.Data.updateTooltip(item,clean)
    -- This is the same inventory item with updated data, not a replacement.
    -- sendReplaceItemInContainer() makes Build 42 remove an equipped item from
    -- the player's hand, which closes the PalmPilot UI immediately.  Sync the
    -- mod data and native drainable fields without changing item identity.
    syncItemModData(player,item)
    syncItemFields(player,item)
end

function Server.onClientCommand(module,command,player,args)
    if module~=C.MODULE then return end
    args=type(args)=="table" and args or {}
    if not allowCommand(player,command) then return end
    if command==N.SYNC then sync(player,args)
    elseif command==N.LIST_TARGETS then PalmPilots.BeamServer.listTargets(player)
    elseif command==N.REQUEST then PalmPilots.BeamServer.request(player,args)
    elseif command==N.LOCAL_REQUEST then PalmPilots.BeamServer.localRequest(player,args)
    elseif command==N.RESPOND then PalmPilots.BeamServer.respond(player,args) end
end

Events.OnClientCommand.Add(Server.onClientCommand)
