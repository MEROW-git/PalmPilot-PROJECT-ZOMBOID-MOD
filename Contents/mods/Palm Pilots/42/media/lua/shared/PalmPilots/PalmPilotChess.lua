-- Original chess implementation for the PalmPilot. No Palm OS binary is loaded.
PalmPilots = PalmPilots or {}
PalmPilots.Chess = PalmPilots.Chess or {}
local C = PalmPilots.Chess

local start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
local values = {p=100,n=320,b=330,r=500,q=900,k=20000}
local knight = {{1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2}}
local king = {{1,1},{1,0},{1,-1},{0,1},{0,-1},{-1,1},{-1,0},{-1,-1}}
local bishop = {{1,1},{1,-1},{-1,1},{-1,-1}}
local rook = {{1,0},{-1,0},{0,1},{0,-1}}

local function side(piece)
    if not piece then return nil end
    return piece==string.upper(piece) and "w" or "b"
end
local function opponent(color) return color=="w" and "b" or "w" end
local function index(file,rank) return (rank-1)*8+file end
local function coords(square) return (square-1)%8+1,math.floor((square-1)/8)+1 end
local function inside(file,rank) return file>=1 and file<=8 and rank>=1 and rank<=8 end
local function copy(state)
    local board={}
    for i=1,64 do board[i]=state.board[i] end
    return {board=board,turn=state.turn,castle=state.castle,ep=state.ep,
        half=state.half,full=state.full}
end

function C.new()
    return C.fromFEN(start)
end

function C.fromFEN(fen)
    if type(fen)~="string" or #fen>120 then return nil end
    local layout,turn,castle,ep,half,full=fen:match("^(%S+) ([wb]) (%S+) (%S+) (%d+) (%d+)$")
    if not layout or not (castle=="-" or castle:match("^[KQkq]+$")) then return nil end
    local board,rank,file={},8,1
    for character in layout:gmatch(".") do
        if character=="/" then
            if file~=9 or rank<=1 then return nil end
            rank=rank-1; file=1
        elseif character:match("^[1-8]$") then
            file=file+tonumber(character)
        elseif character:match("^[prnbqkPRNBQK]$") then
            if file>8 then return nil end
            board[index(file,rank)]=character; file=file+1
        else return nil end
        if file>9 then return nil end
    end
    if rank~=1 or file~=9 then return nil end
    local whiteKings,blackKings=0,0
    for i=1,64 do
        if board[i]=="K" then whiteKings=whiteKings+1 end
        if board[i]=="k" then blackKings=blackKings+1 end
    end
    if whiteKings~=1 or blackKings~=1 then return nil end
    local epSquare=nil
    if ep~="-" then
        local f,r=ep:match("^([a-h])([36])$")
        if not f then return nil end
        epSquare=index(string.byte(f)-96,tonumber(r))
    end
    half=tonumber(half); full=tonumber(full)
    if half>10000 or full<1 or full>10000 then return nil end
    return {board=board,turn=turn,castle=castle,ep=epSquare,half=half,full=full}
end

function C.toFEN(state)
    local ranks={}
    for rank=8,1,-1 do
        local row,empty="",0
        for file=1,8 do
            local piece=state.board[index(file,rank)]
            if piece then
                if empty>0 then row=row..empty; empty=0 end
                row=row..piece
            else empty=empty+1 end
        end
        if empty>0 then row=row..empty end
        ranks[#ranks+1]=row
    end
    local ep="-"
    if state.ep then
        local f,r=coords(state.ep)
        ep=string.char(96+f)..r
    end
    return table.concat(ranks,"/").." "..state.turn.." "..state.castle.." "..ep.." "..state.half.." "..state.full
end

function C.attacked(state,square,by)
    local board=state.board
    local file,rank=coords(square)
    local pawn=by=="w" and "P" or "p"
    local pawnRank=rank-(by=="w" and 1 or -1)
    for _,df in ipairs({-1,1}) do
        if inside(file+df,pawnRank) and board[index(file+df,pawnRank)]==pawn then return true end
    end
    for _,offset in ipairs(knight) do
        local f,r=file+offset[1],rank+offset[2]
        if inside(f,r) and board[index(f,r)]==(by=="w" and "N" or "n") then return true end
    end
    for _,offset in ipairs(king) do
        local f,r=file+offset[1],rank+offset[2]
        if inside(f,r) and board[index(f,r)]==(by=="w" and "K" or "k") then return true end
    end
    for _,directions in ipairs({{bishop,"b","q"},{rook,"r","q"}}) do
        for _,offset in ipairs(directions[1]) do
            local f,r=file+offset[1],rank+offset[2]
            while inside(f,r) do
                local piece=board[index(f,r)]
                if piece then
                    if side(piece)==by then
                        local kind=string.lower(piece)
                        if kind==directions[2] or kind==directions[3] then return true end
                    end
                    break
                end
                f=f+offset[1]; r=r+offset[2]
            end
        end
    end
    return false
end

function C.inCheck(state,color)
    local kingPiece=color=="w" and "K" or "k"
    for square=1,64 do
        if state.board[square]==kingPiece then return C.attacked(state,square,opponent(color)) end
    end
    return true
end

local function add(moves,from,to,special,promotion)
    moves[#moves+1]={from=from,to=to,special=special,promotion=promotion}
end

local function pseudo(state)
    local moves,board={},state.board
    local color=state.turn
    for from=1,64 do
        local piece=board[from]
        if piece and side(piece)==color then
            local kind=string.lower(piece)
            local file,rank=coords(from)
            if kind=="p" then
                local direction=color=="w" and 1 or -1
                local nextRank=rank+direction
                local promotionRank=color=="w" and 8 or 1
                local function pawnMove(to,special)
                    if nextRank==promotionRank then
                        for _,choice in ipairs({"q","r","b","n"}) do add(moves,from,to,special,choice) end
                    else add(moves,from,to,special) end
                end
                if inside(file,nextRank) and not board[index(file,nextRank)] then
                    pawnMove(index(file,nextRank))
                    local startRank=color=="w" and 2 or 7
                    if rank==startRank and not board[index(file,rank+2*direction)] then
                        add(moves,from,index(file,rank+2*direction))
                    end
                end
                for _,df in ipairs({-1,1}) do
                    local f=file+df
                    if inside(f,nextRank) then
                        local to=index(f,nextRank)
                        if board[to] and side(board[to])~=color and string.lower(board[to])~="k" then
                            pawnMove(to)
                        elseif to==state.ep and not board[to] then
                            local captured=board[index(f,rank)]
                            if captured==(color=="w" and "p" or "P") then pawnMove(to,"ep") end
                        end
                    end
                end
            else
                local directions=kind=="n" and knight or kind=="k" and king
                    or kind=="b" and bishop or kind=="r" and rook or nil
                if kind=="q" then
                    directions={}
                    for _,d in ipairs(bishop) do directions[#directions+1]=d end
                    for _,d in ipairs(rook) do directions[#directions+1]=d end
                end
                for _,offset in ipairs(directions) do
                    local f,r=file+offset[1],rank+offset[2]
                    while inside(f,r) do
                        local to=index(f,r)
                        local target=board[to]
                        if not target then add(moves,from,to)
                        elseif side(target)~=color and string.lower(target)~="k" then add(moves,from,to) end
                        if target or kind=="n" or kind=="k" then break end
                        f=f+offset[1]; r=r+offset[2]
                    end
                end
                if kind=="k" and not C.inCheck(state,color) then
                    local home=color=="w" and 1 or 8
                    local enemy=opponent(color)
                    local kingHome=index(5,home)
                    if from==kingHome then
                        local short=color=="w" and "K" or "k"
                        if state.castle:find(short,1,true) and board[index(8,home)]==(color=="w" and "R" or "r")
                                and not board[index(6,home)] and not board[index(7,home)]
                                and not C.attacked(state,index(6,home),enemy)
                                and not C.attacked(state,index(7,home),enemy) then
                            add(moves,from,index(7,home),"castle")
                        end
                        local long=color=="w" and "Q" or "q"
                        if state.castle:find(long,1,true) and board[index(1,home)]==(color=="w" and "R" or "r")
                                and not board[index(2,home)] and not board[index(3,home)] and not board[index(4,home)]
                                and not C.attacked(state,index(4,home),enemy)
                                and not C.attacked(state,index(3,home),enemy) then
                            add(moves,from,index(3,home),"castle")
                        end
                    end
                end
            end
        end
    end
    return moves
end

function C.apply(state,move)
    local nextState=copy(state)
    local board=nextState.board
    local piece=board[move.from]
    if not piece then return nil end
    local fromFile,fromRank=coords(move.from)
    local toFile,toRank=coords(move.to)
    local captured=board[move.to]
    board[move.from]=nil
    board[move.to]=move.promotion and (state.turn=="w" and string.upper(move.promotion) or move.promotion) or piece
    if move.special=="ep" then
        board[index(toFile,fromRank)]=nil
        captured=state.turn=="w" and "p" or "P"
    elseif move.special=="castle" then
        local rookFrom=toFile==7 and 8 or 1
        local rookTo=toFile==7 and 6 or 4
        board[index(rookTo,fromRank)]=board[index(rookFrom,fromRank)]
        board[index(rookFrom,fromRank)]=nil
    end
    local rights=state.castle
    local function removeRight(right) rights=rights:gsub(right,"") end
    if piece=="K" then removeRight("K"); removeRight("Q") end
    if piece=="k" then removeRight("k"); removeRight("q") end
    if move.from==index(1,1) or move.to==index(1,1) then removeRight("Q") end
    if move.from==index(8,1) or move.to==index(8,1) then removeRight("K") end
    if move.from==index(1,8) or move.to==index(1,8) then removeRight("q") end
    if move.from==index(8,8) or move.to==index(8,8) then removeRight("k") end
    nextState.castle=rights=="" and "-" or rights
    nextState.ep=nil
    if string.lower(piece)=="p" and math.abs(toRank-fromRank)==2 then
        nextState.ep=index(fromFile,(toRank+fromRank)/2)
    end
    nextState.half=(captured or string.lower(piece)=="p") and 0 or state.half+1
    nextState.full=state.full+(state.turn=="b" and 1 or 0)
    nextState.turn=opponent(state.turn)
    return nextState
end

function C.legalMoves(state)
    local legal={}
    for _,move in ipairs(pseudo(state)) do
        local nextState=C.apply(state,move)
        if nextState and not C.inCheck(nextState,state.turn) then legal[#legal+1]=move end
    end
    return legal
end

function C.status(state)
    local moves=C.legalMoves(state)
    if #moves==0 then return C.inCheck(state,state.turn) and "checkmate" or "stalemate" end
    if state.half>=100 then return "draw50" end
    return C.inCheck(state,state.turn) and "check" or "playing"
end

function C.findMove(state,from,to,promotion)
    for _,move in ipairs(C.legalMoves(state)) do
        if move.from==from and move.to==to and (not move.promotion or move.promotion==(promotion or "q")) then
            return move
        end
    end
    return nil
end

local function evaluate(state)
    local score=0
    for square=1,64 do
        local piece=state.board[square]
        if piece then
            local file,rank=coords(square)
            local kind=string.lower(piece)
            local center=(3.5-math.abs(file-4.5))+(3.5-math.abs(rank-4.5))
            local advance=side(piece)=="b" and 8-rank or rank-1
            local value=values[kind]+(kind=="p" and advance*4 or kind=="k" and 0 or center*3)
            score=score+(side(piece)=="b" and value or -value)
        end
    end
    return score
end

-- A bounded two-ply opponent: each candidate considers White's best reply.
-- No world state, random seed, or network command is involved.
function C.computerMove(state)
    if state.turn~="b" or state.half>=100 then return nil end
    local best,bestScore=nil,-math.huge
    for _,move in ipairs(C.legalMoves(state)) do
        local after=C.apply(state,move)
        local replies=C.legalMoves(after)
        local worst=math.huge
        if #replies==0 then
            worst=C.inCheck(after,"w") and 100000 or 0
        else
            for _,reply in ipairs(replies) do
                local replyState=C.apply(after,reply)
                local value=evaluate(replyState)
                if value<worst then worst=value end
            end
        end
        if worst>bestScore then best,bestScore=move,worst end
    end
    return best
end

C.square=index
C.coords=coords
