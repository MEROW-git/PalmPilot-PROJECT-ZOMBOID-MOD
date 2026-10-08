require "PalmPilots/PalmPilotNetworkConstants"
require "PalmPilots/PalmPilotData"
require "PalmPilots/PalmPilotChess"

PalmPilots.ChessServer = PalmPilots.ChessServer or {}
local S=PalmPilots.ChessServer
local C=PalmPilots.Constants
local N=PalmPilots.Network
local U=PalmPilots.Utils
local D=PalmPilots.Data
local Chess=PalmPilots.Chess

S.pending=S.pending or {}
S.sessions=S.sessions or {}
S.byPlayer=S.byPlayer or {}
S.lastCleanup=S.lastCleanup or 0
local INVITE_MS=15000

local function send(player,command,args)
    if player then
        args.recipientOnlineID=player:getOnlineID()
        sendServerCommand(player,C.MODULE,command,args)
    end
end

local function heldDevice(player,itemID,deviceID)
    if not player or player:isDead() or player:getOnlineID()<0 then return nil end
    for index=1,2 do
        local item=index==1 and player:getPrimaryHandItem() or player:getSecondaryHandItem()
        if item and item:getFullType()==C.ITEM_TYPE
                and (not itemID or item:getID()==tonumber(itemID))
                and U.findItemByID(player,item:getID()) then
            local data=D.get(item)
            if data.beamEnabled and data.batteryLevel>0
                    and item:getCurrentUsesFloat()>0
                    and (not deviceID or data.deviceID==deviceID) then return item,data end
        end
    end
end

local function inRange(a,b)
    return a and b and a~=b and not a:isDead() and not b:isDead()
        and U.sameFloor(a,b) and U.distance(a,b)<=C.BEAM_RANGE
end

local function pair(session)
    return getPlayerByOnlineID(session.whiteID),getPlayerByOnlineID(session.blackID)
end

local function disconnectReason(session)
    local white,black=pair(session)
    if not white or not black or white:isDead() or black:isDead() then
        return "UI_PalmPilots_ChessDisconnected"
    end
    if not inRange(white,black) then
        return "UI_PalmPilots_ChessDisconnectedRange"
    end
    if not heldDevice(white,session.whiteItemID,session.whiteDeviceID)
            or not heldDevice(black,session.blackItemID,session.blackDeviceID) then
        return "UI_PalmPilots_ChessDisconnectedDevice"
    end
    return nil
end

local function endSession(session,key)
    S.sessions[session.id]=nil
    S.byPlayer[session.whiteID]=nil
    S.byPlayer[session.blackID]=nil
    local white,black=pair(session)
    send(white,N.CHESS_END,{sessionID=session.id,key=key})
    send(black,N.CHESS_END,{sessionID=session.id,key=key})
end

local function capture(session,move)
    local piece=session.state.board[move.to]
    if move.special=="ep" then piece=session.state.turn=="w" and "p" or "P" end
    if not piece then return end
    local list=piece==string.upper(piece) and session.capturedWhite or session.capturedBlack
    if #list<16 then list[#list+1]=piece end
end

local function stateFor(session,player)
    local color=player:getOnlineID()==session.whiteID and "w" or "b"
    local opponent=getPlayerByOnlineID(color=="w" and session.blackID or session.whiteID)
    return {sessionID=session.id,color=color,fen=Chess.toFEN(session.state),
        status=Chess.status(session.state),opponent=opponent and opponent:getDisplayName() or "",
        capturedWhite=session.capturedWhite,capturedBlack=session.capturedBlack,
        lastMove=session.lastMove,revision=session.revision,
        itemID=color=="w" and session.whiteItemID or session.blackItemID,
        deviceID=color=="w" and session.whiteDeviceID or session.blackDeviceID}
end

local function broadcast(session)
    local white,black=pair(session)
    send(white,N.CHESS_STATE,stateFor(session,white))
    send(black,N.CHESS_STATE,stateFor(session,black))
end

function S.listTargets(sender,args)
    if not heldDevice(sender,args.itemID,args.deviceID) then
        send(sender,N.CHESS_TARGETS,{targets={}}); return
    end
    local targets={}
    local players=getOnlinePlayers()
    for i=0,players:size()-1 do
        local other=players:get(i)
        if inRange(sender,other) and not S.byPlayer[other:getOnlineID()]
                and heldDevice(other) then
            targets[#targets+1]={onlineID=other:getOnlineID(),name=other:getDisplayName()}
        end
    end
    send(sender,N.CHESS_TARGETS,{targets=targets})
end

function S.invite(sender,args)
    local receiver=getPlayerByOnlineID(tonumber(args.targetOnlineID) or -1)
    local item,data=heldDevice(sender,args.itemID,args.deviceID)
    if not item or not inRange(sender,receiver) or not heldDevice(receiver)
            or S.byPlayer[sender:getOnlineID()] or S.byPlayer[receiver:getOnlineID()] then
        send(sender,N.CHESS_END,{key="UI_PalmPilots_ChessUnavailable"}); return
    end
    for _,pending in pairs(S.pending) do
        if pending.senderID==sender:getOnlineID() or pending.receiverID==sender:getOnlineID()
                or pending.senderID==receiver:getOnlineID()
                or pending.receiverID==receiver:getOnlineID() then
            send(sender,N.CHESS_END,{key="UI_PalmPilots_ChessBusy"}); return
        end
    end
    local id=U.newID("chess-invite")
    S.pending[id]={senderID=sender:getOnlineID(),receiverID=receiver:getOnlineID(),
        itemID=item:getID(),deviceID=data.deviceID,expires=U.now()+INVITE_MS}
    send(receiver,N.CHESS_OFFER,{requestID=id,senderName=sender:getDisplayName()})
end

function S.reply(receiver,args)
    local id=tostring(args.requestID or "")
    local pending=S.pending[id]
    if not pending or pending.receiverID~=receiver:getOnlineID() then return end
    S.pending[id]=nil
    local sender=getPlayerByOnlineID(pending.senderID)
    if args.accept~=true then
        send(sender,N.CHESS_END,{key="UI_PalmPilots_ChessDeclined"}); return
    end
    local source,sourceData=heldDevice(sender,pending.itemID,pending.deviceID)
    local target,targetData=heldDevice(receiver,args.itemID,args.deviceID)
    if U.now()>pending.expires or not inRange(sender,receiver) or not source or not target
            or S.byPlayer[pending.senderID] or S.byPlayer[pending.receiverID] then
        send(sender,N.CHESS_END,{key="UI_PalmPilots_ChessUnavailable"})
        send(receiver,N.CHESS_END,{key="UI_PalmPilots_ChessUnavailable"})
        return
    end
    local session={id=U.newID("chess-match"),whiteID=pending.senderID,
        blackID=pending.receiverID,whiteItemID=source:getID(),
        blackItemID=target:getID(),whiteDeviceID=sourceData.deviceID,
        blackDeviceID=targetData.deviceID,state=Chess.new(),capturedWhite={},
        capturedBlack={},revision=0}
    S.sessions[session.id]=session
    S.byPlayer[session.whiteID]=session.id
    S.byPlayer[session.blackID]=session.id
    broadcast(session)
end

function S.move(player,args)
    local id=S.byPlayer[player:getOnlineID()]
    if not id or id~=tostring(args.sessionID or "") then return end
    local session=S.sessions[id]
    if not session then return end
    local disconnected=disconnectReason(session)
    if disconnected then endSession(session,disconnected); return end
    local color=player:getOnlineID()==session.whiteID and "w" or "b"
    if session.state.turn~=color or Chess.status(session.state)~="playing"
            and Chess.status(session.state)~="check" then return end
    local from,to=tonumber(args.from),tonumber(args.to)
    if not from or not to or from%1~=0 or to%1~=0
            or from<1 or from>64 or to<1 or to>64 then return end
    local promotion=tostring(args.promotion or "q")
    if not promotion:match("^[qrbn]$") then return end
    local move=Chess.findMove(session.state,from,to,promotion)
    if not move then return end
    capture(session,move)
    session.state=Chess.apply(session.state,move)
    session.revision=session.revision+1
    session.lastMove={from=move.from,to=move.to,special=move.special}
    broadcast(session)
end

function S.leave(player,args)
    local id=S.byPlayer[player:getOnlineID()]
    if id and id==tostring(args.sessionID or "") then
        local session=S.sessions[id]
        if session then
            S.sessions[session.id]=nil
            S.byPlayer[session.whiteID]=nil
            S.byPlayer[session.blackID]=nil
            local white,black=pair(session)
            local reason="UI_PalmPilots_ChessDisconnected"
            send(white,N.CHESS_END,{sessionID=id,
                key=(white~=player or args.reason=="closed") and reason or nil})
            send(black,N.CHESS_END,{sessionID=id,
                key=(black~=player or args.reason=="closed") and reason or nil})
        end
    end
end

function S.cleanup()
    local now=U.now()
    if now-S.lastCleanup<1000 then return end
    S.lastCleanup=now
    for id,pending in pairs(S.pending) do
        if now>pending.expires then
            S.pending[id]=nil
            send(getPlayerByOnlineID(pending.senderID),N.CHESS_END,
                {key="UI_PalmPilots_ChessExpired"})
        end
    end
    for _,session in pairs(S.sessions) do
        local disconnected=disconnectReason(session)
        if disconnected then endSession(session,disconnected) end
    end
end

Events.OnTick.Add(S.cleanup)
