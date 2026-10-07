PalmPilots = PalmPilots or {}
PalmPilots.ZombieCarrier = PalmPilots.ZombieCarrier or {}
require "PalmPilots/PalmPilotSpawnSettings"

local Carrier=PalmPilots.ZombieCarrier
local ITEM_TYPE="PalmPilots.PalmPilot"
local ATTACHED_LOCATION="PalmPilot Right Hand"
local OFFICE_OUTFITS={
    OfficeWorker=true,
    OfficeWorkerSkirt=true,
}

-- Attached items do not fire the player-only OnEquipPrimary event. Matching
-- Bip01_Prop1 on the character and item models places the device in the hand.
local humanLocations=AttachedLocations.getGroup("Human")
humanLocations:getOrCreateLocation(ATTACHED_LOCATION):setAttachmentName("Bip01_Prop1")

-- Keep Lua reloads from registering duplicate event callbacks.
if Carrier.queueZombie then Events.OnZombieCreate.Remove(Carrier.queueZombie) end
if Carrier.equipQueuedZombies then Events.OnTick.Remove(Carrier.equipQueuedZombies) end
Carrier.pending={}
Carrier.tickHooked=false

local function passesCarrierRoll(zombie)
    local chance=PalmPilots.SpawnSettings.carrierChance()
    if chance<=0 then return false end
    -- The low bits are the persistent outfit variant (1-500). Using them makes
    -- the spawn decision stable across saves and multiplayer clients.
    local outfitID=tonumber(zombie:getPersistentOutfitID()) or 0
    if outfitID~=0 then
        local variant=outfitID%65536
        return variant%100<chance
    end
    return ZombRand(100)<chance
end

local function giveDevice(zombie)
    local modData=zombie:getModData()
    if modData.PalmPilotsOfficeCarrierChecked then return end
    modData.PalmPilotsOfficeCarrierChecked=true
    if ItemPickerJava.getLootModifier(ITEM_TYPE)<=0 then return end
    if not passesCarrierRoll(zombie) then return end

    local inventory=zombie:getInventory()
    local item=inventory and inventory:AddItem(ITEM_TYPE)
    if not item then return end

    modData.PalmPilotsOfficeCarrier=true
    zombie:setAttachedItem(ATTACHED_LOCATION,item)
end

function Carrier.equipQueuedZombies()
    for zombie in pairs(Carrier.pending) do
        Carrier.pending[zombie]=nil
        local outfit=zombie:getOutfitName()
        if OFFICE_OUTFITS[outfit] then giveDevice(zombie) end
    end
    Events.OnTick.Remove(Carrier.equipQueuedZombies)
    Carrier.tickHooked=false
end

function Carrier.queueZombie(zombie)
    if not zombie then return end
    Carrier.pending[zombie]=true
    if not Carrier.tickHooked then
        Carrier.tickHooked=true
        Events.OnTick.Add(Carrier.equipQueuedZombies)
    end
end

Events.OnZombieCreate.Add(Carrier.queueZombie)
