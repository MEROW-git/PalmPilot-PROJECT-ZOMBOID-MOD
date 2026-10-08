PalmPilots = {}
dofile("Contents/mods/Palm Pilots/42/media/lua/shared/PalmPilots/PalmPilotChess.lua")
local C=PalmPilots.Chess

local function equal(actual,expected,label)
    assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function nearly(actual,expected,label)
    assert(math.abs(actual-expected)<0.00001,
        (label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
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
state=C.fromFEN("4k3/8/8/8/3p4/2PP4/8/4K3 b - - 0 1")
assert(not C.findMove(state,sq("d4"),sq("d3")),"Black pawn cannot capture straight ahead")
assert(C.findMove(state,sq("d4"),sq("c3")),"Black pawn may capture diagonally")
state=C.fromFEN("4k3/8/8/8/3p4/3P4/8/4K3 w - - 0 1")
assert(not C.findMove(state,sq("d3"),sq("d4")),"White pawn cannot capture straight ahead")
state=C.fromFEN("4k3/8/8/8/1p6/8/2P5/4K3 w - - 0 1")
state=play(state,"c2","c4")
local blackEnPassant=C.findMove(state,sq("b4"),sq("c3"))
assert(blackEnPassant and blackEnPassant.special=="ep","Black can capture a two-step pawn en passant")
state=C.apply(state,blackEnPassant)
equal(state.board[sq("c3")],"p","Black en passant destination")
equal(state.board[sq("c4")],nil,"Black en passant removes White pawn beside destination")
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
equal(#PalmPilots.Data.sanitize({chessFEN="broken",chessCapturedWhite={"P"}},false).chessCapturedWhite,
    0,"invalid position clears stale captures")
local captureState=C.new()
captureState=play(captureState,"e2","e4")
captureState=play(captureState,"d7","d5")
captureState=play(captureState,"e4","d5")
local migrated=PalmPilots.Data.sanitize({chessFEN=C.toFEN(captureState)},false)
equal(#migrated.chessCapturedWhite,0,"old save infers no captured White pieces")
equal(migrated.chessCapturedBlack[1],"p","old save infers captured Black pawn")
local cleaned=PalmPilots.Data.sanitize({chessFEN=C.toFEN(captureState),
    chessCapturedWhite={"P","k","R",13},chessCapturedBlack={}},false)
equal(#cleaned.chessCapturedWhite,2,"invalid captured pieces removed")
equal(cleaned.chessCapturedWhite[1],"P","saved White captures kept")
equal(#cleaned.chessCapturedBlack,0,"explicit empty capture list kept")

getText=function(key) return key end
UIFont={Small=1,Medium=2}
getTextManager=function() return {getFontHeight=function() return 16 end} end
local realMs,worldMs=10000,0
local mood={boredom=50,unhappiness=30}
local clientMode=false
local sent={}
PalmPilots.Utils.now=function() return realMs end
PalmPilots.Utils.worldTimeMs=function() return worldMs end
PalmPilots.Utils.newID=function(prefix) return prefix.."-"..realMs end
CharacterStat={BOREDOM="boredom",UNHAPPINESS="unhappiness"}
isClient=function() return clientMode end
sendClientCommand=function(player,module,command,args)
    sent[#sent+1]={module=module,command=command,args=args}
end
PalmPilots.Constants.MODULE="PalmPilots"
PalmPilots.Network={CHESS_MOOD="ChessMood"}
dofile("Contents/mods/Palm Pilots/42/media/lua/client/PalmPilots/PalmPilotChessScreen.lua")
local ui={data={chessFEN=C.toFEN(C.new())},buttons={},saves=0,scale=1,
    chessView="menu"}
ui.player={getStats=function() return {remove=function(_,stat,amount)
    mood[stat]=math.max(0,mood[stat]-amount)
end} end}
ui.itemID=101
ui.deviceID="device-101"
ui.chessPieceTextures={}
for piece in ("KQBNRPkqbnrp"):gmatch(".") do ui.chessPieceTextures[piece]="texture:"..piece end
for _,method in ipairs({"title","centerText","fill","box","button","lightText"}) do
    ui[method]=function(self,...) end
end
ui.s=function(self,value) return value end
ui.drawTextureScaled=function(self,texture,x,y,w,h)
    self.textureCalls=(self.textureCalls or 0)+1
    self.lastTextureCall={texture=texture,x=x,y=y,w=w,h=h}
    self.drawnTextures=self.drawnTextures or {}
    self.drawnTextures[#self.drawnTextures+1]=self.lastTextureCall
end
ui.button=function(self,label,x,y,w,h,callback)
    self.buttons[#self.buttons+1]={label=label,x=x,y=y,w=w,h=h,callback=callback}
end
ui.rightText=function(self,value,x,y) self.statusText={value=value,x=x,y=y} end
ui.fitText=function(self,value) return value end
ui.save=function(self) self.saves=self.saves+1 end
ui.scrollBar=function() end
ui.buttons={}
PalmPilots.ChessScreen.render(ui)
assert(#ui.buttons==4,"Chess entry menu has Continue, New game, Multiplayer, and Back")
assert(ui.buttons[1].label=="UI_PalmPilots_ChessContinue","continue is the first option")
ui.chessView="lobby"
ui.chessTargets={}
for index=1,6 do ui.chessTargets[index]={name="Player "..index,onlineID=index} end
ui.scroll=2
ui.buttons={}
PalmPilots.ChessScreen.render(ui)
assert(ui.buttons[1].label=="Player 2" and #ui.buttons==7,
    "nearby Chess list scrolls beyond five players")
ui.chessView="menu"
ui.buttons={}
PalmPilots.ChessScreen.render(ui)
ui.buttons[1].callback()
equal(ui.chessView,"board","Continue opens the saved solo board")
local function renderAndCheck(expectedStatus)
    ui.buttons={}
    ui.statusText=nil
    ui.drawnTextures={}
    PalmPilots.ChessScreen.render(ui)
    equal(ui.statusText.value,expectedStatus,"status shown in title bar")
    assert(ui.statusText.x>400 and ui.statusText.y>=120 and ui.statusText.y<168,"status is in title bar")
    for _,button in ipairs(ui.buttons) do
        assert(button.x>=116 and button.x+button.w<=612,"Chess button outside display width")
        assert(button.y>=168 and button.y+button.h<608,"Chess button below playable screen")
    end
end
local function hasSprite(texture,side)
    for _,call in ipairs(ui.drawnTextures or {}) do
        if call.texture==texture and ((side=="left" and call.x<188)
                or (side=="right" and call.x>=540)) then return true end
    end
    return false
end
renderAndCheck("UI_PalmPilots_ChessYourTurn")
assert(#ui.buttons==66,"board and two controls rendered")
assert(ui.textureCalls==32,"all starting pieces use sprites")
local function clickSquare(name)
    ui.buttons={}
    PalmPilots.ChessScreen.render(ui)
    local f,r=C.coords(sq(name))
    local x,y=188+(f-1)*44,182+(8-r)*44
    for _,button in ipairs(ui.buttons) do
        if button.x==x and button.y==y then button.callback(); return end
    end
    error("missing UI square "..name)
end
clickSquare("e2")
equal(ui.chess.selected,sq("e2"),"selected piece highlighted")
assert(ui.chess.legalTargets[sq("e3")] and ui.chess.legalTargets[sq("e4")],"legal destinations highlighted")
clickSquare("e4")
equal(C.fromFEN(ui.data.chessFEN).board[sq("e4")],"P","UI commits player move")
equal(ui.saves,1,"player move saved before delayed reply")
PalmPilots.ChessScreen.tick(ui)
equal(C.fromFEN(ui.data.chessFEN).turn,"b","computer does not move immediately")
realMs=realMs+750; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
equal(C.fromFEN(ui.data.chessFEN).turn,"b","computer still thinking")
assert(mood.boredom<50 and mood.unhappiness<30,"active Chess reduces mood stats")
nearly(mood.boredom,49.9,"single-player Chess boredom cap")
nearly(mood.unhappiness,29.95,"single-player Chess unhappiness cap")
realMs=realMs+300; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
nearly(mood.boredom,49.8,"continued Chess boredom relief")
assert(ui.chess.animation,"computer move begins animation")
renderAndCheck("UI_PalmPilots_ChessMoving")
local animationStart=ui.lastTextureCall
realMs=realMs+260
renderAndCheck("UI_PalmPilots_ChessMoving")
local animationMiddle=ui.lastTextureCall
assert(animationStart.x~=animationMiddle.x or animationStart.y~=animationMiddle.y,
    "computer piece visibly travels between squares")
equal(C.fromFEN(ui.data.chessFEN).turn,"b","position waits for animation")
realMs=realMs+270
PalmPilots.ChessScreen.tick(ui)
equal(C.fromFEN(ui.data.chessFEN).turn,"w","UI commits computer move")
equal(ui.saves,2,"both delayed moves saved")
assert(ui.chess.lastMove and ui.chess.lastMove.from and ui.chess.lastMove.to,
    "computer's move remains highlighted")
ui.chess=nil
renderAndCheck("UI_PalmPilots_ChessYourTurn")
equal(ui.chess.state.board[sq("e4")],"P","UI reloads saved game")
ui.data.chessFEN="4k3/P7/8/8/8/8/8/4K3 w - - 0 1"
ui.chess=nil
clickSquare("a7")
clickSquare("a8")
renderAndCheck("UI_PalmPilots_ChessPromote")
equal(#ui.buttons,68,"board and four promotion controls rendered")
for _,button in ipairs(ui.buttons) do
    if button.label=="Q" then button.callback(); break end
end
equal(ui.chess.state.board[sq("a8")],"Q","UI promotion choice")
ui.data.chessFEN="4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1"
ui.data.chessCapturedWhite={}
ui.data.chessCapturedBlack={}
ui.chess=nil
clickSquare("e4")
clickSquare("d5")
equal(ui.data.chessCapturedBlack[1],"p","White capture records Black piece")
renderAndCheck("UI_PalmPilots_ChessThinking")
assert(hasSprite("texture:p","right"),"captured Black pawn drawn right of board")
ui.chess=nil
renderAndCheck("UI_PalmPilots_ChessThinking")
assert(hasSprite("texture:p","right"),"captured piece survives reopening")

ui.data.chessFEN="4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"
ui.data.chessCapturedWhite={}
ui.data.chessCapturedBlack={}
ui.chess=nil
clickSquare("e5")
clickSquare("d6")
equal(ui.data.chessCapturedBlack[1],"p","en passant records captured pawn")

ui.data.chessFEN="4k3/8/8/8/8/8/3p4/2R3K1 b - - 0 1"
ui.data.chessCapturedWhite={}
ui.data.chessCapturedBlack={}
ui.chess=nil
PalmPilots.ChessScreen.tick(ui)
local blackCapture=C.findMove(ui.chess.state,sq("d2"),sq("c1"),"q")
assert(blackCapture,"test position allows Black capture")
ui.chess.animation={move=blackCapture,start=realMs-520}
renderAndCheck("UI_PalmPilots_ChessMoving")
local targetVisible=false
for _,call in ipairs(ui.drawnTextures) do
    if call.texture=="texture:R" and call.x==188+2*44+1 and call.y==182+7*44+1 then
        targetVisible=true
    end
end
assert(targetVisible,"capture target remains visible while Black piece travels")
PalmPilots.ChessScreen.tick(ui)
equal(ui.data.chessCapturedWhite[1],"R","Black capture records White piece")
renderAndCheck("UI_PalmPilots_ChessCheck")
assert(hasSprite("texture:R","left"),"captured White rook drawn left of board")
for _,button in ipairs(ui.buttons) do
    if button.label=="UI_PalmPilots_ChessNew" then button.callback(); break end
end
equal(#ui.data.chessCapturedWhite,0,"new game clears captured White pieces")
equal(#ui.data.chessCapturedBlack,0,"new game clears captured Black pieces")
ui.data.chessFEN="4k3/8/8/8/1pP5/8/8/4K3 b - c3 0 1"
ui.chess=nil
PalmPilots.ChessScreen.tick(ui)
local enPassantCapture=C.findMove(ui.chess.state,sq("b4"),sq("c3"))
assert(enPassantCapture and enPassantCapture.special=="ep","Black UI position allows en passant")
ui.chess.animation={move=enPassantCapture,start=realMs-520}
PalmPilots.ChessScreen.tick(ui)
equal(ui.data.chessCapturedWhite[1],"P","Black en passant records captured White pawn")
equal(ui.chess.lastMove.capture,sq("c4"),"en passant marks the pawn's captured square")
renderAndCheck("UI_PalmPilots_ChessEnPassant")
local before=mood.boredom
PalmPilots.ChessScreen.leave(ui)
realMs=realMs+1000; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
equal(mood.boredom,before,"leaving Chess stops mood relief")

clientMode=true
ui.data.chessFEN=C.toFEN(C.new())
ui.chess=nil
clickSquare("e2")
realMs=realMs+250; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
assert(#sent==1 and sent[1].command=="ChessMood","multiplayer sends Chess heartbeat")
equal(mood.boredom,before,"client does not change mood stats")
realMs=realMs+1100; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
assert(#sent==2 and sent[2].args.session==sent[1].args.session,
    "multiplayer heartbeat keeps session")
realMs=realMs+31000; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
equal(#sent,2,"inactive Chess sends no heartbeat")
clickSquare("d2")
realMs=realMs+250; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
assert(#sent==3 and sent[3].args.session~=sent[1].args.session,
    "new Chess interaction starts a fresh mood session")
PalmPilots.ChessScreen.leave(ui)
realMs=realMs+1100; worldMs=worldMs+60000
PalmPilots.ChessScreen.tick(ui)
equal(#sent,3,"leaving Chess stops heartbeats")

-- A saved Black turn resumes with a fresh think delay after leaving the app.
clientMode=false
ui.data.chessFEN=C.toFEN(play(C.new(),"e2","e4"))
ui.chess=nil
PalmPilots.ChessScreen.tick(ui)
realMs=realMs+1000
PalmPilots.ChessScreen.tick(ui)
assert(ui.chess.animation,"saved Black turn starts an animation")
PalmPilots.ChessScreen.leave(ui)
assert(not ui.chess.animation,"leaving cancels an unfinished animation")
realMs=realMs+1000
PalmPilots.ChessScreen.tick(ui)
assert(not ui.chess.animation and ui.chess.state.turn=="b","reopened game thinks again")
realMs=realMs+1000
PalmPilots.ChessScreen.tick(ui)
assert(ui.chess.animation,"computer resumes after a fresh delay")
realMs=realMs+520
PalmPilots.ChessScreen.tick(ui)
equal(ui.chess.state.turn,"w","saved game completes delayed computer turn")
local soloFEN=ui.data.chessFEN
local sentMove,closedMatch
PalmPilots.Client={
    moveChess=function(_,sessionID,move) sentMove={sessionID=sessionID,move=move} end,
    leaveChess=function(_,sessionID) closedMatch=sessionID end,
}
clientMode=true
local multiplayerPosition=play(C.new(),"e2","e4")
PalmPilots.ChessScreen.receiveState(ui,{sessionID="match-1",color="b",
    fen=C.toFEN(multiplayerPosition),revision=1,capturedWhite={},capturedBlack={}})
equal(ui.chessView,"board","incoming match opens Chess board")
renderAndCheck("UI_PalmPilots_ChessYourMove")
clickSquare("e7")
clickSquare("e5")
assert(sentMove and sentMove.sessionID=="match-1"
    and sentMove.move.from==sq("e7") and sentMove.move.to==sq("e5"),
    "Black move is sent to server")
equal(ui.data.chessFEN,soloFEN,"live match leaves solo save untouched")
PalmPilots.ChessScreen.receiveEnd(ui,{sessionID="match-1"})
equal(ui.chessView,"menu","ended match returns to Chess menu")
assert(ui.chess==nil,"ended match clears live board")
PalmPilots.ChessScreen.receiveState(ui,{sessionID="match-2",color="w",
    fen=C.toFEN(C.new()),revision=0,capturedWhite={},capturedBlack={}})
PalmPilots.ChessScreen.leave(ui)
equal(closedMatch,"match-2","leaving an active match notifies server")
print("Chess rules: all checks passed")
