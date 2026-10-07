require "PalmPilots/PalmPilotChess"

PalmPilots.ChessScreen = PalmPilots.ChessScreen or {}
local S = PalmPilots.ChessScreen
local Chess = PalmPilots.Chess
-- The playable LCD ends above the application keys at y=608.
local BOARD_X,BOARD_Y,CELL = 188,182,44
local CONTROLS_Y,CONTROLS_HEIGHT = 548,38

local function game(ui)
    if not ui.chess or ui.chess.fen~=ui.data.chessFEN then
        local state=Chess.fromFEN(ui.data.chessFEN) or Chess.new()
        ui.chess={state=state,status=Chess.status(state),
            fen=ui.data.chessFEN,selected=nil,promotion=nil}
    end
    return ui.chess
end

local function commit(ui,state)
    local session=game(ui)
    session.state=state
    session.status=Chess.status(state)
    session.fen=Chess.toFEN(state)
    session.selected=nil
    session.promotion=nil
    ui.data.chessFEN=session.fen
    -- Save a completed player/computer turn in one sync. The server throttles
    -- device syncs that arrive less than 50 ms apart.
    if state.turn=="w" or session.status~="playing" and session.status~="check" then
        ui:save()
    end
end

function S.tick(ui)
    local session=game(ui)
    if session.state.turn~="b" or session.status~="playing"
            and session.status~="check" then return end
    local move=Chess.computerMove(session.state)
    if move then commit(ui,Chess.apply(session.state,move)) end
end

local function chooseSquare(ui,square)
    local session=game(ui)
    local state=session.state
    if state.turn~="w" or session.promotion then return end
    local piece=state.board[square]
    if piece and piece==string.upper(piece) then
        session.selected=square
        return
    end
    if not session.selected then return end
    local move=Chess.findMove(state,session.selected,square,"q")
    if not move then session.selected=nil; return end
    if move.promotion then
        session.promotion={from=session.selected,to=square}
        return
    end
    commit(ui,Chess.apply(state,move))
end

function S.render(ui)
    local session=game(ui)
    local state=session.state
    ui:title(getText("UI_PalmPilots_Chess"))
    local status=session.status
    local label
    if status=="checkmate" then
        label=state.turn=="w" and getText("UI_PalmPilots_ChessLost") or getText("UI_PalmPilots_ChessWon")
    elseif status=="stalemate" or status=="draw50" then
        label=getText("UI_PalmPilots_ChessDraw")
    elseif status=="check" then
        label=state.turn=="w" and getText("UI_PalmPilots_ChessCheck") or getText("UI_PalmPilots_ChessComputerCheck")
    else
        label=state.turn=="w" and getText("UI_PalmPilots_ChessYourTurn") or getText("UI_PalmPilots_ChessThinking")
    end
    if session.promotion then label=getText("UI_PalmPilots_ChessPromote") end
    local statusY=120+(48-getTextManager():getFontHeight(UIFont.Small)/ui.scale)/2
    ui:rightText(ui:fitText(label,320,UIFont.Small),596,statusY,UIFont.Small)
    for rank=8,1,-1 do
        for file=1,8 do
            local square=Chess.square(file,rank)
            local x=BOARD_X+(file-1)*CELL
            local y=BOARD_Y+(8-rank)*CELL
            local dark=(file+rank)%2==0
            if session.selected==square then
                ui:fill(x,y,CELL,CELL,1,0.43,0.54,0.38)
            elseif dark then
                ui:fill(x,y,CELL,CELL,1,0.48,0.57,0.44)
            else
                ui:fill(x,y,CELL,CELL,1,0.72,0.79,0.67)
            end
            ui:box(x,y,CELL,CELL)
            local piece=state.board[square]
            if piece then
                local white=piece==string.upper(piece)
                if white then
                    ui:fill(x+6,y+5,32,34,1,0.86,0.90,0.79)
                    ui:box(x+6,y+5,32,34)
                else
                    ui:fill(x+6,y+5,32,34,1,0.31,0.40,0.29)
                end
                local letter=string.upper(piece)
                if white then ui:centerText(letter,x+CELL/2,y+8,UIFont.Medium)
                else ui:lightText(letter,x+CELL/2-7,y+8,UIFont.Medium) end
            end
            ui.buttons[#ui.buttons+1]={x=x,y=y,w=CELL,h=CELL,
                callback=function() chooseSquare(ui,square) end}
        end
    end
    ui:box(BOARD_X,BOARD_Y,CELL*8,CELL*8)
    if session.promotion then
        for i,choice in ipairs({"q","r","b","n"}) do
            ui:button(string.upper(choice),204+(i-1)*84,CONTROLS_Y,66,CONTROLS_HEIGHT,function()
                local pending=session.promotion
                local move=pending and Chess.findMove(state,pending.from,pending.to,choice)
                if move then commit(ui,Chess.apply(state,move)) end
            end)
        end
    else
        ui:button(getText("UI_PalmPilots_ChessNew"),204,CONTROLS_Y,145,CONTROLS_HEIGHT,function()
            commit(ui,Chess.new())
        end)
        ui:button(getText("UI_PalmPilots_Back"),379,CONTROLS_Y,145,CONTROLS_HEIGHT,function()
            ui:setScreen("home")
        end)
    end
end
