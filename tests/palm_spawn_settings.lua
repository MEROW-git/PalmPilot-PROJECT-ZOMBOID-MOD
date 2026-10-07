local root="Contents/mods/Palm Pilots/42/media/lua/"
package.path=root.."shared/?.lua;"..package.path
package.loaded["Items/ProceduralDistributions"]=true
package.loaded["Items/Distributions"]=true

PalmPilots={}
local names={"OfficeDeskSecretary","ElectronicStoreCases","ElectronicStoreComputers",
    "ElectronicStoreMisc","ElectronicStorePhones","StoreShelfElectronics",
    "CrateElectronics","DeskGeneric","OfficeDesk","OfficeCounter",
    "FilingCabinetGeneric","PawnShopCases","OfficeDeskHome","OfficeDeskHomeClassy"}
ProceduralDistributions={list={}}
for _,name in ipairs(names) do
    ProceduralDistributions.list[name]={items={"Base.Other",10,
        "PalmPilots.PalmPilot",999}}
end
SandboxVars={OtherLootNew=3}
ItemPickerJava={getLootModifier=function() return SandboxVars.OtherLootNew end}

local function nearly(actual,expected)
    assert(math.abs(actual-expected)<0.00001,
        string.format("expected %.5f, got %.5f",expected,actual))
end
local function checkWeights(mode,other,expected)
    SandboxVars.PalmPilots=mode and {SpawnRate=mode} or nil
    SandboxVars.OtherLootNew=other
    dofile(root.."server/PalmPilots/PalmPilotLoot.lua")
    for _,name in ipairs(names) do
        local items=ProceduralDistributions.list[name].items
        assert(#items==4,"reload duplicated the PalmPilot entry")
        nearly(items[4],expected)
    end
end

checkWeights(nil,3,5) -- Existing saves keep the exact original table weight.
checkWeights(2,3,0) -- None.
checkWeights(3,3,5*0.1/3) -- Very Rare under High Other Loot.
checkWeights(4,3,5*0.3/3) -- Rare under High Other Loot.
checkWeights(5,3,5/3) -- Normal under High Other Loot.
checkWeights(6,3,5*1.5/3) -- Common under High Other Loot.
checkWeights(4,0.6,5*0.3/0.6) -- Same custom effective rate at low Other Loot.
checkWeights(4,0,0) -- The game's Other Loot None gate remains effective.
checkWeights(999,3,5) -- Bad or missing values safely use original behavior.

local function event()
    return {Add=function() end,Remove=function() end}
end
Events={OnZombieCreate=event(),OnTick=event()}
AttachedLocations={getGroup=function()
    return {getOrCreateLocation=function()
        return {setAttachmentName=function() end}
    end}
end}
dofile(root.."shared/PalmPilots/PalmPilotZombieCarrier.lua")
local Carrier=PalmPilots.ZombieCarrier
local function carrierRoll(mode,other,variant)
    SandboxVars.PalmPilots={SpawnRate=mode}
    SandboxVars.OtherLootNew=other
    local spawned=false
    local data={}
    local zombie={
        getPersistentOutfitID=function() return variant end,
        getModData=function() return data end,
        getOutfitName=function() return "OfficeWorker" end,
        getInventory=function() return {AddItem=function()
            spawned=true
            return {type="PalmPilots.PalmPilot"}
        end} end,
        setAttachedItem=function() end,
    }
    Carrier.queueZombie(zombie)
    Carrier.equipQueuedZombies()
    return spawned
end

assert(carrierRoll(1,3,49))
assert(not carrierRoll(1,3,50))
assert(not carrierRoll(2,3,0))
assert(carrierRoll(3,3,4))
assert(not carrierRoll(3,3,5))
assert(carrierRoll(4,3,14))
assert(not carrierRoll(4,3,15))
assert(carrierRoll(6,3,74))
assert(not carrierRoll(6,3,75))
assert(not carrierRoll(6,0,0)) -- Other Loot None still gates natural carriers.
print("PalmPilot spawn setting checks passed")
