-- Run with Lua 5.3 or Fengari. Exercise the real Snake screen with mocked UI
-- and Build 42 character stats; no game save or network transport is needed.
local realMs,worldMs=0,0
local values={boredom=50,unhappiness=30}
local stats={}
function stats:remove(stat,amount)
    assert(values[stat]~=nil,"unexpected character stat")
    values[stat]=math.max(0,values[stat]-amount)
end

PalmPilots={Utils={
    now=function() return realMs end,
    worldTimeMs=function() return worldMs end,
}}
CharacterStat={BOREDOM="boredom",UNHAPPINESS="unhappiness"}
UIFont={Small=1,Large=2}
function getText(key) return key end
function ZombRand(maximum) return maximum-1 end

local screenPath="Contents/mods/Palm Pilots/42/media/lua/client/PalmPilots/PalmPilotSnakeScreen.lua"
dofile(screenPath)
local S=PalmPilots.SnakeScreen
local ui={
    player={getStats=function() return stats end},
    data={snakeHighScore=0},
    arrowTextures={up=1,left=1,down=1,right=1},
    buttons={},
}
function ui:title() end
function ui:text() end
function ui:rightText() end
function ui:box() end
function ui:fill() end
function ui:centerText() end
function ui:imageButton() end
function ui:save() error("mood effect should not write device data") end
function ui:setScreen() end
function ui:button(label,x,y,w,h,callback) self.buttons[label]=callback end

local function nearly(actual,expected)
    assert(math.abs(actual-expected)<0.00001,
        string.format("expected %.5f, got %.5f",expected,actual))
end
local function advance(realDelta,worldDelta)
    realMs=realMs+realDelta
    worldMs=worldMs+worldDelta
    S.tick(ui)
end

S.render(ui)
ui.buttons.UI_PalmPilots_Start()
advance(220,60000)
nearly(values.boredom,49.9) -- 30-second cap on a delayed update
nearly(values.unhappiness,29.95)
assert(ui.snake.score==0 and ui.data.snakeHighScore==0)

advance(220,0) -- Game time is paused: no relief.
nearly(values.boredom,49.9)
S.render(ui)
ui.buttons.UI_PalmPilots_Pause()
advance(10000,600000)
nearly(values.boredom,49.9)
S.render(ui)
ui.buttons.UI_PalmPilots_Resume()
advance(220,60000) -- Resume does not award the paused interval.
nearly(values.boredom,49.8)

values.boredom=0.01
values.unhappiness=0.01
advance(220,60000)
nearly(values.boredom,0)
nearly(values.unhappiness,0)

ui.snake.body[1]={x=19,y=8}
ui.snake.dir={x=1,y=0}
ui.snake.nextDir={x=1,y=0}
advance(220,60000) -- Hitting the wall ends the run without a reward.
assert(ui.snake.dead and not ui.snake.running)
nearly(values.boredom,0)
nearly(values.unhappiness,0)

values.boredom=10
values.unhappiness=10
S.render(ui)
ui.buttons.UI_PalmPilots_Restart()
advance(1000,60000) -- Restart leaves Snake stopped until Start is pressed.
nearly(values.boredom,10)
nearly(values.unhappiness,10)
print("Snake mood checks passed")
