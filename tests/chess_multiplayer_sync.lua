-- Exercise the real client command and server save handler with mocked game objects.
local root="Contents/mods/Palm Pilots/42/media/lua/"
package.path=root.."shared/?.lua;"..package.path
PalmPilots={}
require "PalmPilots/PalmPilotData"
require "PalmPilots/PalmPilotNetworkConstants"
local Chess=PalmPilots.Chess
local Data=PalmPilots.Data
local clock=1000
local broadcasts=0
local item={modData={}}
function item:getID() return 101 end
function item:getFullType() return PalmPilots.Constants.ITEM_TYPE end
function item:getModData() return self.modData end
function item:setTooltip() end
local player={getOnlineID=function() return 7 end}
instanceof=function() return false end
PalmPilots.Utils.now=function() return clock end
PalmPilots.Utils.findItemByID=function(_,id)
    return tonumber(id)==101 and item or nil
end
syncItemModData=function(target,owned)
    assert(target==player and owned==item)
    broadcasts=broadcasts+1
end
syncItemFields=function(target,owned)
    assert(target==player and owned==item)
end
Events={
    OnClientCommand={Add=function(callback) Events.serverCallback=callback end},
    OnServerCommand={Add=function(callback) Events.clientCallback=callback end},
}
PalmPilots.BeamServer={}
package.loaded["PalmPilots/PalmPilotBeamServer"]=true
package.loaded["PalmPilots/PalmPilotDialogs"]=true
dofile(root.."server/PalmPilots/PalmPilotServerCommands.lua")
dofile(root.."client/PalmPilots/PalmPilotClientCommands.lua")
isClient=function() return true end
sendClientCommand=function(target,module,command,args)
    assert(target==player)
    Events.serverCallback(module,command,target,args)
end

local initial=Data.sanitize({deviceID="device-101",boundItemID="101"},false)
item.modData.PalmPilots=initial
local function square(name)
    return Chess.square(string.byte(name,1)-96,tonumber(name:sub(2,2)))
end
local function play(state,from,to)
    local move=Chess.findMove(state,square(from),square(to))
    assert(move,"missing test move "..from..to)
    return Chess.apply(state,move)
end
local state=Chess.new()
state=play(state,"e2","e4")
state=play(state,"d7","d5")
state=play(state,"e4","d5")
local clientData=Data.sanitize({deviceID="device-101",boundItemID="101",
    chessFEN=Chess.toFEN(state),chessCapturedWhite={},chessCapturedBlack={"p"}},false)
PalmPilots.Client.syncItem(player,item,clientData)
assert(broadcasts==1,"server broadcasted the first Chess save")
assert(item.modData.PalmPilots.chessFEN==Chess.toFEN(state),"server kept position")
assert(item.modData.PalmPilots.chessCapturedBlack[1]=="p","server kept captured pawn")

local reply=Chess.computerMove(state)
assert(reply,"Black has a legal reply")
state=Chess.apply(state,reply)
clientData.chessFEN=Chess.toFEN(state)
PalmPilots.Client.syncItem(player,item,clientData)
assert(broadcasts==1,"server throttles an immediate duplicate sync")
clock=clock+1000
PalmPilots.Client.syncItem(player,item,clientData)
assert(broadcasts==2,"server broadcasted delayed Black reply")
assert(item.modData.PalmPilots.chessFEN==Chess.toFEN(state),"server kept Black reply")
assert(item.modData.PalmPilots.chessCapturedBlack[1]=="p","capture list survived reply")

clock=clock+1000
clientData.deviceID="wrong-device"
PalmPilots.Client.syncItem(player,item,clientData)
assert(broadcasts==2,"server rejects a mismatched device identity")
print("Chess multiplayer save command checks passed")
