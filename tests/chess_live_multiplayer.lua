-- Server-authoritative two-player Chess with mocked Build 42 transport.
PalmPilots={Constants={MODULE="PalmPilots",ITEM_TYPE="PalmPilots.PalmPilot",BEAM_RANGE=3},
    Network={CHESS_TARGETS="ChessTargets",CHESS_OFFER="ChessOffer",
        CHESS_STATE="ChessState",CHESS_END="ChessEnd"},Utils={},Data={}}
package.loaded["PalmPilots/PalmPilotNetworkConstants"]=true
package.loaded["PalmPilots/PalmPilotData"]=true
dofile("Contents/mods/Palm Pilots/42/media/lua/shared/PalmPilots/PalmPilotChess.lua")
package.loaded["PalmPilots/PalmPilotChess"]=true
local C=PalmPilots.Chess
local U=PalmPilots.Utils
local clock,nextID=1000,0
U.now=function() return clock end
U.newID=function(prefix) nextID=nextID+1; return prefix.."-"..nextID end
U.sameFloor=function(a,b) return math.floor(a.z)==math.floor(b.z) end
U.distance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
U.findItemByID=function(player,id)
    return player.item:getID()==tonumber(id) and player.item or nil
end
PalmPilots.Data.get=function(item) return item.data end

local function player(id,x,hand)
    local item={id=100+id,data={beamEnabled=true,batteryLevel=1,
        deviceID="device-"..id},uses=1}
    function item:getID() return self.id end
    function item:getFullType() return PalmPilots.Constants.ITEM_TYPE end
    function item:getCurrentUsesFloat() return self.uses end
    local p={id=id,x=x,y=0,z=0,item=item,hand=hand,dead=false}
    function p:getOnlineID() return self.id end
    function p:getDisplayName() return "Player "..self.id end
    function p:isDead() return self.dead end
    function p:getPrimaryHandItem() return self.hand=="primary" and self.item or nil end
    function p:getSecondaryHandItem() return self.hand=="secondary" and self.item or nil end
    function p:getInventory() return {} end
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    return p
end
local white=player(1,0,"primary")
local black=player(2,2,"secondary")
local stranger=player(3,20,"primary")
local players={[1]=white,[2]=black,[3]=stranger}
getPlayerByOnlineID=function(id) return players[id] end
getOnlinePlayers=function() return {
    size=function() return 3 end,
    get=function(_,index) return players[index+1] end,
} end
local packets={}
sendServerCommand=function(recipient,module,command,args)
    assert(module=="PalmPilots" and recipient.id==args.recipientOnlineID)
    packets[#packets+1]={recipient=recipient.id,command=command,args=args}
end
Events={OnTick={Add=function(callback) Events.cleanup=callback end}}
dofile("Contents/mods/Palm Pilots/42/media/lua/server/PalmPilots/PalmPilotChessServer.lua")
local S=PalmPilots.ChessServer
local function packet(command,recipient)
    for index=#packets,1,-1 do
        local p=packets[index]
        if p.command==command and p.recipient==recipient then return p.args end
    end
end
local function argsFor(p) return {itemID=p.item.id,deviceID=p.item.data.deviceID} end
local function sq(name)
    return C.square(string.byte(name,1)-96,tonumber(name:sub(2,2)))
end

S.listTargets(white,argsFor(white))
assert(#packet("ChessTargets",1).targets==1,"only held, powered PalmPilot within Beam range is listed")
assert(packet("ChessTargets",1).targets[1].onlineID==2,"secondary-hand device is visible")
S.invite(white,{itemID=white.item.id,deviceID=white.item.data.deviceID,targetOnlineID=2})
local invitation=packet("ChessOffer",2)
assert(invitation and invitation.requestID,"recipient gets invitation")
S.reply(black,{requestID=invitation.requestID,accept=true,
    itemID=black.item.id,deviceID=black.item.data.deviceID})
local initial=packet("ChessState",1)
assert(initial and initial.color=="w" and packet("ChessState",2).color=="b",
    "both players receive assigned colors")
assert(initial.fen==C.toFEN(C.new()),"both players begin from server position")
assert(white.item.data.chessFEN==nil and black.item.data.chessFEN==nil,
    "live match does not overwrite either solo save")
local match=initial.sessionID
S.move(black,{sessionID=match,from=sq("e7"),to=sq("e5")})
assert(packet("ChessState",1).revision==0,"Black cannot move on White's turn")
S.move(stranger,{sessionID=match,from=sq("e2"),to=sq("e4")})
assert(packet("ChessState",1).revision==0,"nonparticipant cannot move")
S.move(white,{sessionID=match,from=sq("e2"),to=sq("e5")})
assert(packet("ChessState",1).revision==0,"illegal pawn leap rejected")
S.move(white,{sessionID=match,from=sq("e2"),to=sq("e4")})
assert(packet("ChessState",1).revision==1,"legal White move broadcast")
S.move(white,{sessionID=match,from=sq("d2"),to=sq("d4")})
assert(packet("ChessState",1).revision==1,"White cannot move twice")
S.move(black,{sessionID=match,from=sq("d7"),to=sq("d5")})
assert(packet("ChessState",2).revision==2,"legal Black move broadcast")
S.move(white,{sessionID=match,from=sq("e4"),to=sq("d5")})
assert(packet("ChessState",1).capturedBlack[1]=="p","capture appears for both players")
assert(packet("ChessState",2).capturedBlack[1]=="p","capture list synced")
black.x=4
clock=clock+1000
Events.cleanup()
assert(packet("ChessEnd",1).sessionID==match,"moving beyond three tiles ends match")
assert(not S.sessions[match] and not S.byPlayer[1] and not S.byPlayer[2],
    "server releases match after range exit")
print("Live Chess multiplayer server checks passed")
