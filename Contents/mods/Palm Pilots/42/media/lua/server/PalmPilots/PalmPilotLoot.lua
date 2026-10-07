require "Items/ProceduralDistributions"
require "Items/Distributions"
require "PalmPilots/PalmPilotSpawnSettings"

PalmPilots.Loot = PalmPilots.Loot or {}

local ITEM_TYPE="PalmPilots.PalmPilot"

-- These are vanilla loot-table weights, not percentages. A custom sandbox
-- choice compensates for Build 42's Other Loot modifier at roll time.
local containerWeight=PalmPilots.SpawnSettings.containerWeight()

local proceduralWeights={
    -- Use one clear rare weight across every appropriate container.
    OfficeDeskSecretary=containerWeight,

    -- Electronics-store counters, cases, shelves, and storage boxes.
    ElectronicStoreCases=containerWeight,
    ElectronicStoreComputers=containerWeight,
    ElectronicStoreMisc=containerWeight,
    ElectronicStorePhones=containerWeight,
    StoreShelfElectronics=containerWeight,
    CrateElectronics=containerWeight,

    -- Ordinary offices, pawnshops, and wealthy home offices.
    DeskGeneric=containerWeight,
    OfficeDesk=containerWeight,
    OfficeCounter=containerWeight,
    FilingCabinetGeneric=containerWeight,
    PawnShopCases=containerWeight,
    OfficeDeskHome=containerWeight,
    OfficeDeskHomeClassy=containerWeight,
}

local function setWeight(items,weight)
    if not items then return end
    for index=1,#items,2 do
        if items[index]==ITEM_TYPE then
            -- Also replaces the temporary common test weight after a Lua reload.
            items[index+1]=weight
            return
        end
    end
    table.insert(items,ITEM_TYPE)
    table.insert(items,weight)
end

for distribution,weight in pairs(proceduralWeights) do
    local target=ProceduralDistributions.list[distribution]
    if target then setWeight(target.items,weight) end
end
