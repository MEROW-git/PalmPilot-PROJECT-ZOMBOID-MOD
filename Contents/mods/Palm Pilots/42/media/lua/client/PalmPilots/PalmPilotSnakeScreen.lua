PalmPilots.SnakeScreen = PalmPilots.SnakeScreen or {}
local S = PalmPilots.SnakeScreen
local MOVE_INTERVAL_MS = 220
local MAX_MOOD_ELAPSED_MS = 30000
local BOREDOM_RELIEF_PER_HOUR = 12
local UNHAPPINESS_RELIEF_PER_HOUR = 6

local function same(a,b) return a.x==b.x and a.y==b.y end

function S.reset(ui)
    ui.snake={body={{x=9,y=8},{x=8,y=8},{x=7,y=8}},dir={x=1,y=0},nextDir={x=1,y=0},food=nil,score=0,running=false,paused=false,last=0,dead=false}
    S.food(ui)
end

function S.food(ui)
    local s=ui.snake
    for _=1,200 do local p={x=ZombRand(20),y=ZombRand(16)}; local clear=true
        for _,part in ipairs(s.body) do if same(p,part) then clear=false; break end end
        if clear then s.food=p; return end
    end
end

function S.direction(ui,x,y)
    local s=ui.snake; if not s then return end
    if s.dir.x+x~=0 or s.dir.y+y~=0 then s.nextDir={x=x,y=y} end
end

local function relieveMood(ui,elapsed)
    if elapsed<=0 or not ui.player then return end
    local stats=ui.player:getStats()
    if not stats then return end
    local hours=math.min(elapsed,MAX_MOOD_ELAPSED_MS)/3600000
    stats:remove(CharacterStat.BOREDOM,BOREDOM_RELIEF_PER_HOUR*hours)
    stats:remove(CharacterStat.UNHAPPINESS,UNHAPPINESS_RELIEF_PER_HOUR*hours)
end

function S.tick(ui)
    local s=ui.snake; if not s or not s.running or s.paused or s.dead then return end
    local now=PalmPilots.Utils.now(); if now-s.last<MOVE_INTERVAL_MS then return end; s.last=now; s.dir=s.nextDir
    local worldNow=PalmPilots.Utils.worldTimeMs()
    local elapsed=math.max(0,worldNow-(s.lastMoodWorld or worldNow))
    s.lastMoodWorld=worldNow
    local head={x=s.body[1].x+s.dir.x,y=s.body[1].y+s.dir.y}
    if head.x<0 or head.x>=20 or head.y<0 or head.y>=16 then s.dead=true; s.running=false; return end
    for _,part in ipairs(s.body) do if same(head,part) then s.dead=true; s.running=false; return end end
    table.insert(s.body,1,head)
    if same(head,s.food) then s.score=s.score+10; if s.score>ui.data.snakeHighScore then ui.data.snakeHighScore=s.score; ui:save() end; S.food(ui)
    else table.remove(s.body) end
    relieveMood(ui,elapsed)
end

function S.render(ui)
    if not ui.snake then S.reset(ui) end; S.tick(ui); local s=ui.snake
    ui:title(getText("UI_PalmPilots_Snake")); ui:text(getText("UI_PalmPilots_Score")..": "..s.score,130,174,UIFont.Small)
    ui:rightText(getText("UI_PalmPilots_HighScore")..": "..ui.data.snakeHighScore,580,174,UIFont.Small)
    ui:box(134,205,440,352)
    for _,part in ipairs(s.body) do ui:fill(136+part.x*21.8,207+part.y*21.8,19,19) end
    if s.food then ui:box(136+s.food.x*21.8,207+s.food.y*21.8,19,19) end
    if s.dead then ui:centerText(getText("UI_PalmPilots_GameOver"),354,370,UIFont.Large) end
    ui:button(s.running and (s.paused and getText("UI_PalmPilots_Resume") or getText("UI_PalmPilots_Pause")) or getText("UI_PalmPilots_Start"),170,565,105,32,function()
        if s.dead then S.reset(ui); s=ui.snake end
        if not s.running then s.running=true; s.last=0; s.lastMoodWorld=PalmPilots.Utils.worldTimeMs()
        else s.paused=not s.paused; s.lastMoodWorld=PalmPilots.Utils.worldTimeMs() end
    end)
    ui:button(getText("UI_PalmPilots_Restart"),305,565,105,32,function() S.reset(ui) end)
    ui:button(getText("UI_PalmPilots_Back"),440,565,105,32,function() ui:setScreen("home") end)

    ui:imageButton(ui.arrowTextures.up,332,625,64,64,function() S.direction(ui,0,-1) end)
    ui:imageButton(ui.arrowTextures.left,264,690,64,64,function() S.direction(ui,-1,0) end)
    ui:imageButton(ui.arrowTextures.down,332,690,64,64,function() S.direction(ui,0,1) end)
    ui:imageButton(ui.arrowTextures.right,400,690,64,64,function() S.direction(ui,1,0) end)
end
