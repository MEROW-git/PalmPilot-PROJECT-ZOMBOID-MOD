PalmPilots = {}
dofile("Contents/mods/Palm Pilots/42/media/lua/shared/PalmPilots/PalmPilotChess.lua")
local C=PalmPilots.Chess

local function equal(actual,expected,label)
    assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function sq(name)
    return C.square(string.byte(name,1)-96,tonumber(name:sub(2,2)))
end
local function play(state,from,to,promotion)
    local move=C.findMove(state,sq(from),sq(to),promotion)
    assert(move,"illegal test move: "..from..to)
    return C.apply(state,move)
end
local function perft(state,depth)
    if depth==0 then return 1 end
    local count=0
    for _,move in ipairs(C.legalMoves(state)) do count=count+perft(C.apply(state,move),depth-1) end
    return count
end

local state=C.new()
equal(C.toFEN(state),"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1","starting FEN")
equal(perft(state,1),20,"initial perft 1")
equal(perft(state,2),400,"initial perft 2")
equal(perft(state,3),8902,"initial perft 3")
assert(not C.findMove(state,sq("e2"),sq("e5")),"illegal pawn leap")
state=play(state,"e2","e4")
equal(C.toFEN(C.fromFEN(C.toFEN(state))),C.toFEN(state),"FEN reload")
local ai=C.computerMove(state)
assert(ai and C.findMove(state,ai.from,ai.to,ai.promotion),"computer must choose legal move")

state=C.fromFEN("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
state=play(state,"e1","g1")
equal(state.board[sq("f1")],"R","castling rook")
equal(state.board[sq("h1")],nil,"castling rook source")
state=C.fromFEN("4kr2/8/8/8/8/8/8/R3K2R w KQ - 0 1")
assert(not C.findMove(state,sq("e1"),sq("g1")),"cannot castle through check")

state=C.fromFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
state=play(state,"e5","d6")
equal(state.board[sq("d5")],nil,"en passant capture")
equal(state.board[sq("d6")],"P","en passant destination")
state=C.fromFEN("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
state=play(state,"a7","a8","n")
equal(state.board[sq("a8")],"N","underpromotion")

state=C.new()
state=play(state,"f2","f3")
state=play(state,"e7","e5")
state=play(state,"g2","g4")
state=play(state,"d8","h4")
equal(C.status(state),"checkmate","fool's mate")
assert(not C.fromFEN("not a position"),"invalid saved game rejected")

package.path="Contents/mods/Palm Pilots/42/media/lua/shared/?.lua;"..package.path
require "PalmPilots/PalmPilotData"
local saved=C.toFEN(play(C.new(),"d2","d4"))
local data=PalmPilots.Data.sanitize({chessFEN=saved,snakeHighScore=40},false)
equal(data.chessFEN,saved,"device save keeps chess position")
equal(data.snakeHighScore,40,"device save keeps existing score")
equal(PalmPilots.Data.sanitize({chessFEN="broken"},false).chessFEN,C.toFEN(C.new()),"invalid device position resets")

getText=function(key) return key end
UIFont={Small=1,Medium=2}
dofile("Contents/mods/Palm Pilots/42/media/lua/client/PalmPilots/PalmPilotChessScreen.lua")
local ui={data={chessFEN=C.toFEN(C.new())},buttons={},saves=0}
for _,method in ipairs({"title","centerText","fill","box","button","lightText"}) do
    ui[method]=function(self,...) end
end
ui.button=function(self,label,x,y,w,h,callback)
    self.buttons[#self.buttons+1]={x=x,y=y,w=w,h=h,callback=callback}
end
ui.save=function(self) self.saves=self.saves+1 end
local function clickSquare(name)
    ui.buttons={}
    PalmPilots.ChessScreen.render(ui)
    local f,r=C.coords(sq(name))
    local x,y=172+(f-1)*48,205+(8-r)*48
    for _,button in ipairs(ui.buttons) do
        if button.x==x and button.y==y then button.callback(); return end
    end
    error("missing UI square "..name)
end
clickSquare("e2")
clickSquare("e4")
equal(C.fromFEN(ui.data.chessFEN).board[sq("e4")],"P","UI commits player move")
PalmPilots.ChessScreen.tick(ui)
equal(C.fromFEN(ui.data.chessFEN).turn,"w","UI commits computer move")
equal(ui.saves,1,"completed turn saved once")
ui.chess=nil
ui.buttons={}
PalmPilots.ChessScreen.render(ui)
equal(ui.chess.state.board[sq("e4")],"P","UI reloads saved game")
print("Chess rules: all checks passed")
