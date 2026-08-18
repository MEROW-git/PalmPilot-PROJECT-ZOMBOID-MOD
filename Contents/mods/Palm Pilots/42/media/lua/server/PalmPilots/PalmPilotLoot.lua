require "Items/ProceduralDistributions"
require "Items/Distributions"

PalmPilots.Loot = PalmPilots.Loot or {}

local ITEM_TYPE="PalmPilots.PalmPilot"

-- These are vanilla loot-table weights, not percentages. Because PalmPilot is
-- classified as Other loot, Build 42 also applies the world's Sandbox
-- Other Loot setting (including None) to these spawns.
local EXECUTIVE_VERY_RARE=0.20
local ELECTRONICS_VERY_RARE=0.10
local EXTREMELY_RARE=0.02
local ZOMBIE_RARE=1.00

local proceduralWeights={
    -- Specialized professional/executive-office desk: best container chance.
    OfficeDeskSecretary=EXECUTIVE_VERY_RARE,

    -- Electronics-store counters, cases, shelves, and storage boxes.
    ElectronicStoreCases=ELECTRONICS_VERY_RARE,
    ElectronicStoreComputers=ELECTRONICS_VERY_RARE,
    ElectronicStoreMisc=ELECTRONICS_VERY_RARE,
    ElectronicStorePhones=ELECTRONICS_VERY_RARE,
    StoreShelfElectronics=ELECTRONICS_VERY_RARE,
    CrateElectronics=ELECTRONICS_VERY_RARE,

    -- Ordinary offices, pawnshops, and wealthy home offices.
    DeskGeneric=EXTREMELY_RARE,
    OfficeDesk=EXTREMELY_RARE,
    OfficeCounter=EXTREMELY_RARE,
    FilingCabinetGeneric=EXTREMELY_RARE,
    PawnShopCases=EXTREMELY_RARE,
    OfficeDeskHome=EXTREMELY_RARE,
    OfficeDeskHomeClassy=EXTREMELY_RARE,
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

-- Businessperson zombies use vanilla outfit distributions. This costs no
-- per-tick scan and inherits vanilla loot/Sandbox handling.
local businessOutfits={
    "Outfit_OfficeWorker",
    "Outfit_OfficeWorkerSkirt",
}

for _,outfit in ipairs(businessOutfits) do
    local target=SuburbsDistributions and SuburbsDistributions.all
        and SuburbsDistributions.all[outfit]
    if target then setWeight(target.items,ZOMBIE_RARE) end
end
