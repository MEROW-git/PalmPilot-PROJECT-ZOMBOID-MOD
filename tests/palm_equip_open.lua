-- Lua 5.3 / Fengari regression harness. Uses the installed game's vanilla
-- actions, with mocked players/inventories/network transport (not a live MP test).
-- Run: fengari tests/palm_equip_open.lua "E:/SteamLibrary/steamapps/common/ProjectZomboid"
local game = assert(arg[1], "Pass the Project Zomboid installation directory")
local mod = "Contents/mods/Palm Pilots/42/media/lua/"
package.path = mod.."shared/?.lua;"..mod.."client/?.lua;"
    ..game.."/media/lua/shared/?.lua;"..package.path

local server, attached, opened, messages, models = false, false, 0, 0, nil
local queue = {}
function isServer() return server end
function isClient() return not server end
function instanceof(item, class) return item and item.class == class end
function getText(key) return key end
ItemTag = {WEARABLE="wearable", REPLACE_PRIMARY="replace", LIGHTER="lighter"}
ItemType = {RADIO="radio"}
local player = {primary=nil, secondary=nil}
local inventory = {items={}}
function inventory:getItemWithID(id)
    for _, item in ipairs(self.items) do if item:getID()==id then return item end end
end
function inventory:getItems()
    return {size=function() return #self.items end,
        get=function(_, i) return self.items[i+1] end}
end
function inventory:setDrawDirty() end
function player:getInventory() return inventory end
function player:getPlayerNum() return 0 end
function player:getPrimaryHandItem() return self.primary end
function player:getSecondaryHandItem() return self.secondary end
function player:setPrimaryHandItem(item) self.primary=item end
function player:setSecondaryHandItem(item) self.secondary=item end
function player:isTimedActionInstant() return self.instant or false end
function player:removeAttachedItem() end
function player:getClothingItem_Back() return nil end
function player:isEquippedClothing() return false end
function player:getCurrentSquare() return nil end
function player:setIsFarming() end
function player:isRunning() return self.running or false end
function player:isSprinting() return false end
local hotbar = {chr=player, isItemAttached=function() return attached end}
function getPlayerHotbar() assert(not server, "Server accessed client hotbar"); return hotbar end
function getPlayerInventory() return {refreshBackpacks=function() end} end
function getSpecificPlayer() return player end
local sentEquip=0
function sendEquip() sentEquip=sentEquip+1 end
ISLogSystem={logAction=function() end}
ISTimedActionQueue={
    add=function(action) queue[#queue+1]=action end,
    getTimedActionQueue=function() return {
        onCompleted=function() end, resetQueue=function() end,
    } end,
}

local function item(id)
    return {
        getID=function() return id end,
        getFullType=function() return "PalmPilots.PalmPilot" end,
        getName=function() return "PalmPilot" end,
        isRequiresEquippedBothHands=function() return false end,
        getContainer=function() return inventory end,
        IsInventoryContainer=function() return false end,
        hasTag=function() return false end,
        setJobDelta=function() end,
        canBeActivated=function() return false end,
        getCurrentUsesFloat=function() return 1 end,
    }
end
local device, hammer = item(101), item(102)
hammer.getFullType=function() return "Base.Hammer" end
inventory.items={device,hammer}

require "PalmPilots/PalmPilotEquipAction"
require "PalmPilots/PalmPilotOpenAction"
-- No moodle/body damage mocks: simulate a duration multiplier deterministically.
ISBaseTimedAction.adjustMaxTime=function(_, value) return value*1.5 end
PalmPilots.MainUI={instances={}, open=function(_, found)
    assert(found==inventory:getItemWithID(101)); opened=opened+1
end}
PalmPilots.Dialogs={message=function() messages=messages+1 end}
PalmPilots.Data={get=function() end}
package.loaded["PalmPilots/PalmPilotMainUI"]=true
ISInventoryPaneContextMenu={transferIfNeeded=function(_, found)
    if not inventory:getItemWithID(found:getID()) then queue[#queue+1]={Type="transfer"} end
end}
ISInventoryPane={doContextualDblClick=function() end}
ISUnequipAction={new=function(_, _, found) return {Type="unequip",item=found} end}
ISHotbar={activateSlot=function() end}
Events={OnFillInventoryObjectContextMenu={Add=function() end}}
for _, name in ipairs({"ISUI/ISInventoryPaneContextMenu", "ISUI/ISInventoryPane",
    "TimedActions/ISUnequipAction", "TimedActions/ISTimedActionQueue", "Hotbar/ISHotbar"}) do
    package.loaded[name]=true
end
require "PalmPilots/PalmPilotContextMenu"

local passed, failed=0,0
local function test(name, run)
    server=false; attached=false; player.primary=nil; player.secondary=nil
    player.instant=false; player.running=false
    inventory.items={device,hammer}; queue={}; opened=0; messages=0; models=nil; sentEquip=0
    local ok, err=pcall(run)
    if ok then passed=passed+1; print("PASS "..name)
    else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local function visualAction(primary)
    attached=true; player.primary=hammer
    local action=PalmPilots.EquipAction:new(player,device,50,primary,false,false)
    action.action={setOverrideHandModelsObject=function(_, a,b) models={a,b} end,
        overrideWeaponType=function() end, restoreWeaponType=function() end,
        forceComplete=function() end}
    return action
end
-- Mirrors NetTimedAction.set()/parse(): constructor parameter names identify
-- instance fields, and the server resolves the class using the action's Type.
local function roundTrip(action)
    local class=assert(_G[action.Type], "Server cannot resolve "..action.Type)
    local values={class}
    local count=debug.getinfo(class.new,"u").nparams
    for i=2,count do
        local name=debug.getlocal(class.new,i)
        values[i]=action[name]
    end
    server=true
    return class.new(table.unpack(values,1,count))
end

test("equip class is resolvable by multiplayer Type", function()
    assert(_G[PalmPilots.EquipAction.Type]==PalmPilots.EquipAction)
end)
test("network constructor preserves unadjusted duration", function()
    local action=PalmPilots.EquipAction:new(player,device,50,false,false,false)
    action.maxTime=75 -- ISBaseTimedAction.create has adjusted the client duration.
    local remote=roundTrip(action)
    assert(remote.maxTime==50, "Client-adjusted duration was serialized")
    assert(remote:getDuration()==50)
    assert(remote.primary==false and remote.twoHands==false and remote.alwaysTurnOn==false)
end)
test("server reconstructs and equips secondary, preserving hammer", function()
    player.primary=hammer
    local remote=roundTrip(PalmPilots.EquipAction:new(player,device,50,false,false,false))
    assert(remote:isValid())
    assert(remote:complete())
    assert(player.primary==hammer and player.secondary==device and sentEquip==1)
end)
test("server reconstructs and equips primary", function()
    local remote=roundTrip(PalmPilots.EquipAction:new(player,device,50,true,false,false))
    assert(remote:complete())
    assert(player.primary==device and player.secondary==nil and sentEquip==1)
end)
test("server animation event does not call client hotbar API", function()
    local action=PalmPilots.EquipAction:new(player,device,50,false,false,false)
    server=true
    action:animEvent("detachConnect","")
end)
test("secondary belt detach keeps hammer model", function()
    local action=visualAction(false)
    action:animEvent("detachConnect","")
    assert(models[1]==hammer and models[2]==device)
end)
test("secondary belt completion keeps hammer model", function()
    local action=visualAction(false)
    action:perform()
    assert(models[1]==hammer and models[2]==device)
end)
test("primary belt draw retains vanilla model behavior", function()
    local action=visualAction(true)
    action:animEvent("detachConnect","")
    assert(models[1]==device and models[2]==nil)
end)
test("free right hand queues primary equip then open", function()
    PalmPilots.ContextMenu.open(device,0)
    assert(#queue==2 and queue[1].primary==true and queue[2].Type==PalmPilots.OpenAction.Type)
end)
test("hammer queues secondary equip without unequipping hammer", function()
    player.primary=hammer
    PalmPilots.ContextMenu.open(device,0)
    assert(#queue==2 and queue[1].primary==false)
end)
test("two-handed weapon is unequipped before opening", function()
    player.primary=hammer; player.secondary=hammer
    PalmPilots.ContextMenu.open(device,0)
    assert(#queue==3 and queue[1].Type=="unequip" and queue[2].primary==false)
end)
test("equipped network wrapper opens without another equip", function()
    player.primary=device
    PalmPilots.ContextMenu.open(item(101),0)
    assert(#queue==0 and opened==1)
end)
test("container transfer is queued before equip and open", function()
    inventory.items={hammer}
    PalmPilots.ContextMenu.open(device,0)
    assert(#queue==3 and queue[1].Type=="transfer" and queue[2].item==device)
end)
test("open accepts owned item while equip packet is pending", function()
    local action=PalmPilots.OpenAction:new(player,device)
    assert(action:isValid())
    action:perform()
    assert(opened==1 and messages==0)
end)
test("open resolves replacement inventory wrapper by ID", function()
    local action=PalmPilots.OpenAction:new(player,device)
    inventory.items={item(101)}
    assert(action:isValid() and action.item==inventory.items[1])
    action:perform()
    assert(opened==1)
end)
test("missing item cannot open UI", function()
    local action=PalmPilots.OpenAction:new(player,device)
    inventory.items={hammer}
    assert(not action:isValid())
    action:perform()
    assert(opened==0)
end)
test("aiming flag agrees with vanilla equip action", function()
    local action=PalmPilots.OpenAction:new(player,device)
    assert(action.stopOnAim==false and action.stopOnRun==true)
end)
test("queue cancellation reports once and does not open", function()
    local action=PalmPilots.OpenAction:new(player,device)
    action:forceCancel(); action:stop()
    assert(messages==1 and opened==0)
end)
test("server cannot display a UI or failure dialog", function()
    server=true
    local action=PalmPilots.OpenAction:new(player,device)
    action:perform(); action:forceCancel()
    assert(opened==0 and messages==0)
end)
print(string.format("%d passed, %d failed (mocked protocol; live multiplayer still requires testing)",passed,failed))
if failed>0 then os.exit(1) end
