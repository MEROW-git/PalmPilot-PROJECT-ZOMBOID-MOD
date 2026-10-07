require "PalmPilots/PalmPilotBeamServer"

PalmPilots.ServerCommands = PalmPilots.ServerCommands or {}
local Server=PalmPilots.ServerCommands
local N=PalmPilots.Network
local C=PalmPilots.Constants

Server.commandTimes=Server.commandTimes or {}
local commandIntervals={
    [N.SYNC]=50,
    [N.SNAKE_MOOD]=1000,
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

-- Snake runs in the client UI. In multiplayer the server owns the mood stats:
-- each valid heartbeat awards only elapsed server game time, with a short
-- expiry and a cap so pauses, disconnects and time jumps cannot bank relief.
local SNAKE_MOOD_TIMEOUT_MS=8000
local SNAKE_MOOD_MAX_ELAPSED_MS=5*60*1000
local SNAKE_BOREDOM_PER_HOUR=12
local SNAKE_UNHAPPINESS_PER_HOUR=6
Server.snakeMoodSessions=Server.snakeMoodSessions or {}

local function snakeMood(player,args)
    local id=player:getOnlineID()
    if type(args)~="table" or type(args.session)~="string"
            or #args.session<1 or #args.session>80 or player:isDead() then
        Server.snakeMoodSessions[id]=nil
        return
    end
    local item=PalmPilots.Utils.findItemByID(player,args.itemID)
    if not item or item:getFullType()~=C.ITEM_TYPE
            or not (PalmPilots.Utils.sameItem(item,player:getPrimaryHandItem())
                or PalmPilots.Utils.sameItem(item,player:getSecondaryHandItem()))
            or item:getCurrentUsesFloat()<=0 then
        Server.snakeMoodSessions[id]=nil
        return
    end
    local data=PalmPilots.Data.get(item)
    if data.deviceID~=tostring(args.deviceID or "") then
        Server.snakeMoodSessions[id]=nil
        return
    end

    local now=PalmPilots.Utils.now()
    local worldNow=PalmPilots.Utils.worldTimeMs()
    local previous=Server.snakeMoodSessions[id]
    Server.snakeMoodSessions[id]={session=args.session,itemID=item:getID(),
        realTime=now,worldTime=worldNow}
    if not previous or previous.session~=args.session or previous.itemID~=item:getID()
            or now-previous.realTime>SNAKE_MOOD_TIMEOUT_MS then return end
    local elapsed=math.min(math.max(0,worldNow-previous.worldTime),
        SNAKE_MOOD_MAX_ELAPSED_MS)
    if elapsed<=0 then return end
    local stats=player:getStats()
    if not stats then return end
    local hours=elapsed/3600000
    local boredomChanged=stats:remove(CharacterStat.BOREDOM,
        SNAKE_BOREDOM_PER_HOUR*hours)
    local unhappinessChanged=stats:remove(CharacterStat.UNHAPPINESS,
        SNAKE_UNHAPPINESS_PER_HOUR*hours)
    if boredomChanged or unhappinessChanged then
        local mask=SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.BOREDOM)
            +SyncPlayerStatsPacket.getBitMaskForStat(CharacterStat.UNHAPPINESS)
        syncPlayerStats(player,mask)
    end
end

function Server.onClientCommand(module,command,player,args)
    if module~=C.MODULE then return end
    args=type(args)=="table" and args or {}
    if not allowCommand(player,command) then return end
    if command==N.SYNC then sync(player,args)
    elseif command==N.SNAKE_MOOD then snakeMood(player,args)
    elseif command==N.LIST_TARGETS then PalmPilots.BeamServer.listTargets(player)
    elseif command==N.REQUEST then PalmPilots.BeamServer.request(player,args)
    elseif command==N.LOCAL_REQUEST then PalmPilots.BeamServer.localRequest(player,args)
    elseif command==N.RESPOND then PalmPilots.BeamServer.respond(player,args) end
end

Events.OnClientCommand.Add(Server.onClientCommand)
