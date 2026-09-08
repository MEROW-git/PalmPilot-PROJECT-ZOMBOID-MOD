require "Items/ProceduralDistributions"
require "Items/Distributions"

PalmPilots.Loot = PalmPilots.Loot or {}

local ITEM_TYPE="PalmPilots.PalmPilot"

-- These are vanilla loot-table weights, not percentages. Because PalmPilot is
-- classified as Other loot, Build 42 also applies the world's Sandbox
-- Other Loot setting (including None) to these spawns.
local CONTAINER_RARE=5.00

local proceduralWeights={
    -- Use one clear rare weight across every appropriate container.
    OfficeDeskSecretary=CONTAINER_RARE,

    -- Electronics-store counters, cases, shelves, and storage boxes.
    ElectronicStoreCases=CONTAINER_RARE,
    ElectronicStoreComputers=CONTAINER_RARE,
    ElectronicStoreMisc=CONTAINER_RARE,
    ElectronicStorePhones=CONTAINER_RARE,
    StoreShelfElectronics=CONTAINER_RARE,
    CrateElectronics=CONTAINER_RARE,

    -- Ordinary offices, pawnshops, and wealthy home offices.
    DeskGeneric=CONTAINER_RARE,
    OfficeDesk=CONTAINER_RARE,
    OfficeCounter=CONTAINER_RARE,
    FilingCabinetGeneric=CONTAINER_RARE,
    PawnShopCases=CONTAINER_RARE,
    OfficeDeskHome=CONTAINER_RARE,
    OfficeDeskHomeClassy=CONTAINER_RARE,
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
