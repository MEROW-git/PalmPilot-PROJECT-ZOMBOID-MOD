-- Exercise the actual client invitation and state handlers with a local UI.
PalmPilots={Constants={MODULE="PalmPilots",ITEM_TYPE="PalmPilots.PalmPilot"},
    Network={CHESS_TARGETS_REQUEST="ChessTargetsRequest",CHESS_TARGETS="ChessTargets",
        CHESS_INVITE="ChessInvite",CHESS_OFFER="ChessOffer",CHESS_REPLY="ChessReply",
        CHESS_MOVE="ChessMove",CHESS_STATE="ChessState",CHESS_LEAVE="ChessLeave",
        CHESS_END="ChessEnd"},Utils={},Data={},Dialogs={}}
package.loaded["PalmPilots/PalmPilotNetworkConstants"]=true
package.loaded["PalmPilots/PalmPilotData"]=true
package.loaded["PalmPilots/PalmPilotDialogs"]=true
dofile("Contents/mods/Palm Pilots/42/media/lua/shared/PalmPilots/PalmPilotChess.lua")
package.loaded["PalmPilots/PalmPilotChess"]=true
local item={id=101,data={deviceID="device-101",beamEnabled=true,batteryLevel=1}}
function item:getID() return self.id end
function item:getFullType() return PalmPilots.Constants.ITEM_TYPE end
function item:getCurrentUsesFloat() return 1 end
local player={}
function player:getOnlineID() return 7 end
function player:getPlayerNum() return 0 end
function player:getPrimaryHandItem() return nil end
function player:getSecondaryHandItem() return item end
getNumActivePlayers=function() return 1 end
getSpecificPlayer=function(index) return index==0 and player or nil end
getPlayer=function() return player end
isClient=function() return true end
getText=function(key) return key end
PalmPilots.Data.get=function(owned) return owned.data end
PalmPilots.Utils.findItemByID=function(owner,id)
    return owner==player and tonumber(id)==101 and item or nil
end
PalmPilots.Utils.now=function() return 1000 end
local commands={}
sendClientCommand=function(owner,module,command,args)
    assert(owner==player and module=="PalmPilots")
    commands[#commands+1]={command=command,args=args}
end
local messages={}
PalmPilots.Dialogs.message=function(value) messages[#messages+1]=value end
PalmPilots.Dialogs.confirm=function(value,_,callback,arg1)
    PalmPilots.Dialogs.offer={text=value,callback=callback,arg1=arg1}
end
local ui={screen="home",item=item,itemID=101,deviceID="device-101",
    player=player,playerNum=0,data={chessFEN="solo-saved-position"}}
function ui:setScreen(screen) self.screen=screen; self.chessView="menu" end
PalmPilots.MainUI={instances={[0]=ui},open=function() error("unneeded UI reopen") end}
Events={OnServerCommand={Add=function(callback) Events.clientCallback=callback end}}
dofile("Contents/mods/Palm Pilots/42/media/lua/client/PalmPilots/PalmPilotChessScreen.lua")
dofile("Contents/mods/Palm Pilots/42/media/lua/client/PalmPilots/PalmPilotClientCommands.lua")
local Client=PalmPilots.Client
Client.onServerCommand("PalmPilots","ChessOffer",
    {recipientOnlineID=7,requestID="invite-1",senderName="Friend"})
assert(PalmPilots.Dialogs.offer and PalmPilots.Dialogs.offer.arg1=="invite-1",
    "secondary-hand PalmPilot receives offer")
PalmPilots.Dialogs.offer.callback(nil,{player=0,internal="YES"},"invite-1")
assert(commands[#commands].command=="ChessReply"
    and commands[#commands].args.itemID==101
    and commands[#commands].args.accept,"offer acceptance names held device")
local FEN=PalmPilots.Chess.toFEN(PalmPilots.Chess.new())
Client.onServerCommand("PalmPilots","ChessState",{recipientOnlineID=7,
    sessionID="match-1",itemID=101,deviceID="device-101",color="b",
    fen=FEN,revision=0,capturedWhite={},capturedBlack={}})
assert(ui.screen=="chess" and ui.chessView=="board" and ui.chess.color=="b",
    "server state opens Black's board")
assert(ui.data.chessFEN=="solo-saved-position","live match does not change solo save")
Client.onServerCommand("PalmPilots","ChessEnd",{recipientOnlineID=7,
    sessionID="match-1",key="UI_PalmPilots_ChessDisconnectedRange"})
assert(ui.chessView=="disconnected" and ui.chess==nil,"server end shows disconnected screen")
assert(ui.chessDisconnectedKey=="UI_PalmPilots_ChessDisconnectedRange",
    "range reason is displayed on the PalmPilot")
assert(#messages==0,"open Chess screen does not get a duplicate modal")
ui.closed=true
Client.onServerCommand("PalmPilots","ChessEnd",{recipientOnlineID=7,
    sessionID="match-2",key="UI_PalmPilots_ChessDisconnected"})
assert(messages[#messages]=="UI_PalmPilots_ChessDisconnected",
    "put-away device still shows a disconnected message")
print("Live Chess client command checks passed")
