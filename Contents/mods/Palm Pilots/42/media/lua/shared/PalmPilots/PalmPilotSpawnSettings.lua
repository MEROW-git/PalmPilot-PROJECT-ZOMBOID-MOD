PalmPilots = PalmPilots or {}
PalmPilots.SpawnSettings = PalmPilots.SpawnSettings or {}

local Spawn=PalmPilots.SpawnSettings
local ITEM_TYPE="PalmPilots.PalmPilot"
local BASE_CONTAINER_WEIGHT=5
local BASE_CARRIER_CHANCE=50
-- Custom rates target the equivalent of Normal Other Loot (1.0). The
-- original option continues to use the game's unmodified Other Loot rate.
local MULTIPLIERS={[2]=0,[3]=0.1,[4]=0.3,[5]=1,[6]=1.5}

function Spawn.mode()
    local value=SandboxVars and SandboxVars.PalmPilots
        and tonumber(SandboxVars.PalmPilots.SpawnRate) or 1
    if value~=math.floor(value) or value<1 or value>6 then return 1 end
    return value
end

function Spawn.containerWeight()
    local multiplier=MULTIPLIERS[Spawn.mode()]
    if not multiplier then return BASE_CONTAINER_WEIGHT end
    if multiplier==0 then return 0 end
    -- Build 42 multiplies procedural weights by OtherLootNew when rolling.
    -- Compensate here so High Other Loot does not inflate a custom rate.
    local other=SandboxVars and tonumber(SandboxVars.OtherLootNew)
        or ItemPickerJava.getLootModifier(ITEM_TYPE)
    if not other or other<=0 then return 0 end
    return BASE_CONTAINER_WEIGHT*multiplier/other
end

function Spawn.carrierChance()
    local multiplier=MULTIPLIERS[Spawn.mode()]
    if not multiplier then return BASE_CARRIER_CHANCE end
    return math.min(100,BASE_CARRIER_CHANCE*multiplier)
end
