-- Mock the server command boundary and native Build 42 stat sync.
local root="Contents/mods/Palm Pilots/42/media/lua/"
local realMs,worldMs=0,0
local values={boredom=50,unhappiness=30}
local broadcasts={}
local item={
    getID=function() return 101 end,
    getFullType=function() return "PalmPilots.PalmPilot" end,
    getCurrentUsesFloat=function(self) return self.charge or 1 end,
}
local player={
    getOnlineID=function() return 7 end,
    isDead=function(self) return self.dead or false end,
    getPrimaryHandItem=function(self) return self.hand end,
    getSecondaryHandItem=function() return nil end,
    getStats=function() return {
        remove=function(_,stat,amount)
            local previous=values[stat]
            values[stat]=math.max(0,previous-amount)
            return values[stat]~=previous
        end,
    } end,
    hand=item,
}
PalmPilots={
    Constants={ITEM_TYPE="PalmPilots.PalmPilot",MODULE="PalmPilots"},
    Network={SYNC="SyncDevice",SNAKE_MOOD="SnakeMood",CHESS_MOOD="ChessMood",LIST_TARGETS="ListTargets",
        REQUEST="BeamRequest",LOCAL_REQUEST="LocalBeamRequest",RESPOND="BeamRespond"},
    Utils={
        now=function() return realMs end,
        worldTimeMs=function() return worldMs end,
        findItemByID=function(_,id) return tonumber(id)==101 and item or nil end,
        sameItem=function(a,b) return a~=nil and a==b end,
    },
    Data={get=function() return {deviceID="device-101"} end},
    BeamServer={},
}
package.loaded["PalmPilots/PalmPilotBeamServer"]=true
Events={OnClientCommand={Add=function(callback) Events.callback=callback end}}
CharacterStat={BOREDOM="boredom",UNHAPPINESS="unhappiness"}
SyncPlayerStatsPacket={getBitMaskForStat=function(stat)
    return stat=="boredom" and 4 or 8
end}
function syncPlayerStats(target,mask)
    assert(target==player)
    broadcasts[#broadcasts+1]=mask
end
dofile(root.."server/PalmPilots/PalmPilotServerCommands.lua")

local function ping(session,override)
    local args={itemID=101,deviceID="device-101",session=session}
    if override then for key,value in pairs(override) do args[key]=value end end
    Events.callback("PalmPilots","SnakeMood",player,args)
end
local function advance(realDelta,worldDelta,session,override)
    realMs=realMs+realDelta
    worldMs=worldMs+worldDelta
    ping(session,override)
end
local function nearly(actual,expected)
    assert(math.abs(actual-expected)<0.00001,
        string.format("expected %.5f, got %.5f",expected,actual))
end

ping("run-1") -- First heartbeat establishes a server clock only.
nearly(values.boredom,50)
advance(3000,180000,"run-1")
nearly(values.boredom,49.4)
nearly(values.unhappiness,29.7)
assert(#broadcasts==1 and broadcasts[1]==12)

advance(3000,180000,"run-2") -- Resume/new run cannot bank time.
nearly(values.boredom,49.4)
advance(3000,180000,"run-2")
nearly(values.boredom,48.8)

advance(9000,540000,"run-2") -- Stale heartbeat starts a new interval.
nearly(values.boredom,48.8)
advance(3000,1200000,"run-2") -- Five game-minute cap.
nearly(values.boredom,47.8)
nearly(values.unhappiness,28.9)

player.hand=nil
advance(3000,180000,"run-2")
nearly(values.boredom,47.8)
player.hand=item
advance(3000,180000,"run-2") -- Invalid heartbeat cannot bank its interval.
nearly(values.boredom,47.8)
advance(3000,180000,"run-3",{deviceID="wrong"})
nearly(values.boredom,47.8)
item.charge=0
advance(3000,180000,"run-3")
nearly(values.boredom,47.8)
item.charge=1
advance(9000,180000,"run-3")
nearly(values.boredom,47.8)
player.dead=true
advance(3000,180000,"run-3")
nearly(values.boredom,47.8)
player.dead=false
advance(1000,60000,"run-4")
advance(1000,60000,"run-4") -- One-second sessions can earn relief.
nearly(values.boredom,47.6)
nearly(values.unhappiness,28.8)

local function chessPing(session,override)
    local args={itemID=101,deviceID="device-101",session=session}
    if override then for key,value in pairs(override) do args[key]=value end end
    Events.callback("PalmPilots","ChessMood",player,args)
end
realMs=realMs+1000; worldMs=worldMs+60000
chessPing("chess-1") -- Switching games starts a new server interval.
nearly(values.boredom,47.6)
realMs=realMs+1000; worldMs=worldMs+60000
chessPing("chess-1")
nearly(values.boredom,47.4)
nearly(values.unhappiness,28.7)
assert(broadcasts[#broadcasts]==12)
realMs=realMs+1000; worldMs=worldMs+60000
ping("run-4") -- Alternating game commands cannot claim both intervals.
nearly(values.boredom,47.4)
realMs=realMs+1000; worldMs=worldMs+60000
chessPing("chess-1")
nearly(values.boredom,47.4)
player.hand=nil
realMs=realMs+1000; worldMs=worldMs+60000
chessPing("chess-1")
nearly(values.boredom,47.4)
player.hand=item
realMs=realMs+1000; worldMs=worldMs+60000
chessPing("chess-1") -- An invalid heartbeat cannot bank its interval.
nearly(values.boredom,47.4)
print("Snake and Chess multiplayer mood command checks passed")
