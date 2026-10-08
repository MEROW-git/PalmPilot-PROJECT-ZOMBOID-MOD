require "PalmPilots/PalmPilotChess"

PalmPilots.ChessScreen = PalmPilots.ChessScreen or {}
local S = PalmPilots.ChessScreen
local Chess = PalmPilots.Chess
local U = PalmPilots.Utils
-- The playable LCD ends above the application keys at y=608.
local BOARD_X,BOARD_Y,CELL = 188,182,44
local CONTROLS_Y,CONTROLS_HEIGHT = 548,38
local THINK_MS,MOVE_MS,LAST_MOVE_MS = 1000,520,1800
local ACTIVE_MS,MOOD_SAMPLE_MS,MOOD_PING_MS = 30000,250,1000
local MAX_MOOD_ELAPSED_MS = 30000
local BOREDOM_RELIEF_PER_HOUR,UNHAPPINESS_RELIEF_PER_HOUR = 12,6

local function game(ui)
    if not ui.chess or ui.chess.fen~=ui.data.chessFEN then
        local state=Chess.fromFEN(ui.data.chessFEN) or Chess.new()
        ui.chess={state=state,status=Chess.status(state),fen=ui.data.chessFEN,
            selected=nil,legalTargets=nil,promotion=nil,
            thinkStart=state.turn=="b" and U.now() or nil}
    end
    return ui.chess
end

local function stopMood(session)
    session.moodSession=nil
    session.lastMoodWorld=nil
    session.lastMoodSample=nil
    session.lastMoodPing=nil
    session.lastActivity=nil
end

function S.leave(ui)
    local session=ui.chess
    if not session then return end
    stopMood(session)
    session.animation=nil
    session.thinkStart=nil
    session.selected=nil
    session.legalTargets=nil
end

local function activePlay(session)
    local now=U.now()
    if not session.moodSession or not session.lastActivity
            or now-session.lastActivity>ACTIVE_MS then
        session.moodSession=U.newID("chess")
        session.lastMoodWorld=U.worldTimeMs()
        session.lastMoodSample=now
        session.lastMoodPing=nil
    end
    session.lastActivity=now
end

local function updateMood(ui,session,now)
    if not session.moodSession then return end
    if now-(session.lastActivity or now)>ACTIVE_MS
            or session.status~="playing" and session.status~="check" then
        stopMood(session)
        return
    end
    if now-(session.lastMoodSample or now)<MOOD_SAMPLE_MS then return end
    session.lastMoodSample=now
    local worldNow=U.worldTimeMs()
    local elapsed=math.min(math.max(0,worldNow-(session.lastMoodWorld or worldNow)),
        MAX_MOOD_ELAPSED_MS)
    session.lastMoodWorld=worldNow
    if isClient() then
        if not session.lastMoodPing or now-session.lastMoodPing>=MOOD_PING_MS then
            session.lastMoodPing=now
            sendClientCommand(ui.player,PalmPilots.Constants.MODULE,
                PalmPilots.Network.CHESS_MOOD,{itemID=ui.itemID,
                    deviceID=ui.deviceID,session=session.moodSession})
        end
        return
    end
    if elapsed<=0 or not ui.player then return end
    local stats=ui.player:getStats()
    if not stats then return end
    local hours=elapsed/3600000
    stats:remove(CharacterStat.BOREDOM,BOREDOM_RELIEF_PER_HOUR*hours)
    stats:remove(CharacterStat.UNHAPPINESS,UNHAPPINESS_RELIEF_PER_HOUR*hours)
end

local function commit(ui,state,move)
    local session=game(ui)
    if move then
        local captured=move.special=="ep" and (session.state.turn=="w" and "p" or "P")
            or session.state.board[move.to]
        if captured then
            local key=captured==string.upper(captured) and "chessCapturedWhite" or "chessCapturedBlack"
            ui.data[key]=ui.data[key] or {}
            if #ui.data[key]<16 then ui.data[key][#ui.data[key]+1]=captured end
        end
    else
        ui.data.chessCapturedWhite={}
        ui.data.chessCapturedBlack={}
    end
    session.state=state
    session.status=Chess.status(state)
    session.fen=Chess.toFEN(state)
    session.selected=nil
    session.legalTargets=nil
    session.promotion=nil
    session.animation=nil
    session.thinkStart=state.turn=="b" and U.now() or nil
    session.lastMove=move and {from=move.from,to=move.to,at=U.now()} or nil
    if session.status~="playing" and session.status~="check" then stopMood(session) end
    ui.data.chessFEN=session.fen
    -- The computer now waits before replying, so persist the human move too.
    -- Its later reply is well outside the server's 50 ms sync throttle.
    ui:save()
end

function S.tick(ui)
    local session=game(ui)
    local now=U.now()
    updateMood(ui,session,now)
    if session.state.turn~="b" or session.status~="playing"
            and session.status~="check" then return end
    if session.animation then
        if now-session.animation.start>=MOVE_MS then
            local move=session.animation.move
            commit(ui,Chess.apply(session.state,move),move)
        end
        return
    end
    if not session.thinkStart then session.thinkStart=now; return end
    if now-session.thinkStart<THINK_MS then return end
    local move=Chess.computerMove(session.state)
    if move then session.animation={move=move,start=now} end
end

local function chooseSquare(ui,square)
    local session=game(ui)
    local state=session.state
    if state.turn~="w" or session.promotion then return end
    local piece=state.board[square]
    if piece and piece==string.upper(piece) then
        if session.selected==square then
            session.selected=nil
            session.legalTargets=nil
            return
        end
        activePlay(session)
        session.selected=square
        session.legalTargets={}
        for _,move in ipairs(Chess.legalMoves(state)) do
            if move.from==square then session.legalTargets[move.to]=true end
        end
        return
    end
    if not session.selected then return end
    local move=Chess.findMove(state,session.selected,square,"q")
    if not move then session.selected=nil; session.legalTargets=nil; return end
    activePlay(session)
    if move.promotion then
        session.promotion={from=session.selected,to=square}
        return
    end
    commit(ui,Chess.apply(state,move),move)
end

local function drawPiece(ui,piece,x,y)
    local texture=ui.chessPieceTextures and ui.chessPieceTextures[piece]
    if texture then
        ui:drawTextureScaled(texture,ui:s(x+1),ui:s(y+1),
            ui:s(CELL-2),ui:s(CELL-2),1,1,1,1)
        return
    end
    -- Keep the board playable if an asset fails to load.
    local letter=string.upper(piece)
    if piece==letter then ui:centerText(letter,x+CELL/2,y+8,UIFont.Medium)
    else ui:lightText(letter,x+CELL/2-7,y+8,UIFont.Medium) end
end

local function drawCaptured(ui,pieces,x)
    for index,piece in ipairs(pieces or {}) do
        if index>16 then break end
        local column=(index-1)%2
        local row=math.floor((index-1)/2)
        local px=x+column*33
        local py=BOARD_Y+row*43
        local texture=ui.chessPieceTextures and ui.chessPieceTextures[piece]
        if texture then
            ui:drawTextureScaled(texture,ui:s(px),ui:s(py),ui:s(32),ui:s(39),1,1,1,1)
        else
            ui:centerText(string.upper(piece),px+16,py+8,UIFont.Small)
        end
    end
end

function S.render(ui)
    local session=game(ui)
    local state=session.state
    local now=U.now()
    if session.lastMove and now-session.lastMove.at>LAST_MOVE_MS then session.lastMove=nil end
    ui:title(getText("UI_PalmPilots_Chess"))
    local status=session.status
    local label
    if session.promotion then label=getText("UI_PalmPilots_ChessPromote")
    elseif status=="checkmate" then
        label=state.turn=="w" and getText("UI_PalmPilots_ChessLost") or getText("UI_PalmPilots_ChessWon")
    elseif status=="stalemate" or status=="draw50" then
        label=getText("UI_PalmPilots_ChessDraw")
    elseif session.animation then label=getText("UI_PalmPilots_ChessMoving")
    elseif status=="check" then
        label=state.turn=="w" and getText("UI_PalmPilots_ChessCheck") or getText("UI_PalmPilots_ChessComputerCheck")
    else
        label=state.turn=="w" and getText("UI_PalmPilots_ChessYourTurn") or getText("UI_PalmPilots_ChessThinking")
    end
    local statusY=120+(48-getTextManager():getFontHeight(UIFont.Small)/ui.scale)/2
    ui:rightText(ui:fitText(label,320,UIFont.Small),596,statusY,UIFont.Small)

    drawCaptured(ui,ui.data.chessCapturedWhite,119)
    drawCaptured(ui,ui.data.chessCapturedBlack,543)

    local moving=session.animation and session.animation.move or nil
    for rank=8,1,-1 do
        for file=1,8 do
            local square=Chess.square(file,rank)
            local x=BOARD_X+(file-1)*CELL
            local y=BOARD_Y+(8-rank)*CELL
            local dark=(file+rank)%2==0
            if session.selected==square then
                ui:fill(x,y,CELL,CELL,1,0.82,0.89,0.51)
            elseif moving and (moving.from==square or moving.to==square) then
                ui:fill(x,y,CELL,CELL,1,0.77,0.83,0.46)
            elseif session.lastMove and (session.lastMove.from==square
                    or session.lastMove.to==square) then
                ui:fill(x,y,CELL,CELL,1,0.66,0.75,0.47)
            elseif dark then
                ui:fill(x,y,CELL,CELL,1,0.48,0.57,0.44)
            else
                ui:fill(x,y,CELL,CELL,1,0.72,0.79,0.67)
            end
            ui:box(x,y,CELL,CELL)
            if session.legalTargets and session.legalTargets[square] then
                ui:box(x+4,y+4,CELL-8,CELL-8)
            end
            local piece=state.board[square]
            if piece and not (moving and (moving.from==square or moving.to==square)) then
                drawPiece(ui,piece,x,y)
            end
            if session.selected==square then
                ui:box(x+2,y+2,CELL-4,CELL-4)
                ui:box(x+3,y+3,CELL-6,CELL-6)
            end
            ui.buttons[#ui.buttons+1]={x=x,y=y,w=CELL,h=CELL,
                callback=function() chooseSquare(ui,square) end}
        end
    end
    ui:box(BOARD_X,BOARD_Y,CELL*8,CELL*8)
    if moving then
        local fromFile,fromRank=Chess.coords(moving.from)
        local toFile,toRank=Chess.coords(moving.to)
        local progress=math.min(1,math.max(0,(now-session.animation.start)/MOVE_MS))
        progress=progress*progress*(3-2*progress)
        local x=BOARD_X+(fromFile-1+(toFile-fromFile)*progress)*CELL
        local y=BOARD_Y+(8-fromRank+(fromRank-toRank)*progress)*CELL
        drawPiece(ui,state.board[moving.from],x,y)
    end

    if session.promotion then
        for i,choice in ipairs({"q","r","b","n"}) do
            ui:button(string.upper(choice),204+(i-1)*84,CONTROLS_Y,66,CONTROLS_HEIGHT,function()
                local pending=session.promotion
                local move=pending and Chess.findMove(state,pending.from,pending.to,choice)
                if move then activePlay(session); commit(ui,Chess.apply(state,move),move) end
            end)
        end
    else
        ui:button(getText("UI_PalmPilots_ChessNew"),204,CONTROLS_Y,145,CONTROLS_HEIGHT,function()
            stopMood(session)
            commit(ui,Chess.new())
        end)
        ui:button(getText("UI_PalmPilots_Back"),379,CONTROLS_Y,145,CONTROLS_HEIGHT,function()
            ui:setScreen("home")
        end)
    end
end
