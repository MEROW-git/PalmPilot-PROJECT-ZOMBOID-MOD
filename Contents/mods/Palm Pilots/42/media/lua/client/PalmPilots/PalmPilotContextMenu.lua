require "PalmPilots/PalmPilotMainUI"
require "PalmPilots/PalmPilotOpenAction"
require "PalmPilots/PalmPilotEquipAction"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISInventoryPane"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISTimedActionQueue"

PalmPilots.ContextMenu = PalmPilots.ContextMenu or {}

require 'Hotbar/ISHotbar'

local function unwrap(entry)
    if instanceof(entry,"InventoryItem") then return entry end
    if type(entry)=="table" and entry.items then return entry.items[1] end
end

function PalmPilots.ContextMenu.open(item,playerNum)
    local player=getSpecificPlayer(playerNum)
    if not player then return end
    -- Admin clones initially inherit the source modData. Re-key the clone by
    -- native item ID before comparing it with either equipped hand.
    PalmPilots.Data.get(item)
    PalmPilots.Utils.log("Open requested for item "..tostring(item and item:getID()))

    local primary=player:getPrimaryHandItem()
    local secondary=player:getSecondaryHandItem()

    -- In multiplayer, the inventory row and equipped hand may be different
    -- Lua wrappers for the same network item.  Never queue a second equip in
    -- that case because vanilla treats it as a toggle and puts the item away.
    local held=PalmPilots.Utils.sameItem(primary,item) and primary
        or (PalmPilots.Utils.sameItem(secondary,item) and secondary)
    if held then
        PalmPilots.Utils.log("Opening already-equipped device")
        PalmPilots.MainUI.open(player,held)
        return
    end

    -- Move nested/container items into the main inventory before equipping.
    ISInventoryPaneContextMenu.transferIfNeeded(player,item)

    local function isPalmPilot(held)
        return held and held:getFullType()==PalmPilots.Constants.ITEM_TYPE
    end

    local equipPrimary
    if isPalmPilot(primary) then
        equipPrimary=true -- Replace the PalmPilot already in the primary hand.
    elseif isPalmPilot(secondary) then
        equipPrimary=false -- Replace it without disturbing the other hand.
    elseif not primary then
        equipPrimary=true -- Use the right hand when it is free.
    else
        equipPrimary=false -- Preserve the right-hand item and use the left.
    end

    -- A two-handed item cannot remain visually equipped while using the device.
    -- Unequip it first, then put the PalmPilot in the selected free/replacement hand.
    local other=equipPrimary and secondary or primary
    if other and (primary==secondary or other:isRequiresEquippedBothHands()) then
        ISTimedActionQueue.add(ISUnequipAction:new(player,other,50))
    end

    ISTimedActionQueue.add(PalmPilots.EquipAction:new(player,item,50,equipPrimary,
        false,false))
    ISTimedActionQueue.add(PalmPilots.OpenAction:new(player,item))
end

-- Give PalmPilots the same natural inventory double-click behavior as radios.
if not PalmPilots.ContextMenu.originalDblClick then
    PalmPilots.ContextMenu.originalDblClick=ISInventoryPane.doContextualDblClick
function ISInventoryPane:doContextualDblClick(item)
        if item and item:getFullType()==PalmPilots.Constants.ITEM_TYPE then
            PalmPilots.ContextMenu.open(item,self.player)
            return
        end
        return PalmPilots.ContextMenu.originalDblClick(self,item)
    end
end

local function ensureWorldModel(item)
    if item and item.setWorldStaticModel and not item:getWorldStaticItem() then
        item:setWorldStaticModel(PalmPilots.Constants.WORLD_MODEL)
    end
    return item and item:getWorldStaticItem() ~= nil
end

function PalmPilots.ContextMenu.place(item,playerNum)
    local player=getSpecificPlayer(playerNum)
    if not player then return end
    ensureWorldModel(item)
    ISInventoryPaneContextMenu.onPlaceItemOnGround({item},player)
end

local function hasOption(context,name)
    for _,option in ipairs(context.options or {}) do
        if option.name==name then return true end
    end
    return false
end

local function disableCloneOption(menu)
    if not menu then return end
    local cloneName=getText("ContextMenu_CloneItem")
    for _,option in ipairs(menu.options or {}) do
        if option.name==cloneName then
            option.notAvailable=true
            option.onSelect=nil
            local tooltip=ISInventoryPaneContextMenu.addToolTip()
            tooltip.description="PalmPilot cloning is disabled to protect multiplayer inventory state."
            option.toolTip=tooltip
        end
        if option.subOption then
            disableCloneOption(menu:getSubMenu(option.subOption))
        end
    end
end

function PalmPilots.ContextMenu.onFill(playerNum,context,items)
    if #items~=1 then return end
    local item=unwrap(items[1]); if not item or item:getFullType()~=PalmPilots.Constants.ITEM_TYPE then return end
    PalmPilots.Data.get(item)
    ensureWorldModel(item)
    local placeName=getText("ContextMenu_PlaceItemOnGround")
    if not hasOption(context,placeName) then
        context:addOption(placeName,item,PalmPilots.ContextMenu.place,playerNum)
    end
    context:addOption(getText("ContextMenu_PalmPilots_Open"),item,PalmPilots.ContextMenu.open,playerNum)
    disableCloneOption(context)
end

Events.OnFillInventoryObjectContextMenu.Add(PalmPilots.ContextMenu.onFill)

-- A PalmPilot attached to either belt slot acts as a one-key application:
-- pressing its hotbar number draws it and opens the UI. Pressing the same key
-- while it is open closes it; MainUI then returns it to its original slot.
if not PalmPilots.ContextMenu.originalHotbarActivateSlot then
    PalmPilots.ContextMenu.originalHotbarActivateSlot=ISHotbar.activateSlot
    function ISHotbar:activateSlot(slotIndex)
        local item=self.attachedItems and self.attachedItems[slotIndex] or nil
        if item and item:getFullType()==PalmPilots.Constants.ITEM_TYPE then
            local playerNum=self.chr:getPlayerNum()
            local open=PalmPilots.MainUI.instances[playerNum]
            if open and open.itemID==item:getID() then
                open:close()
            else
                PalmPilots.ContextMenu.open(item,playerNum)
            end
            return
        end
        return PalmPilots.ContextMenu.originalHotbarActivateSlot(self,slotIndex)
    end
end

-- Safety guard for callers that bypass the disabled context-menu option.
if not PalmPilots.ContextMenu.originalDebugCloneItem then
    PalmPilots.ContextMenu.originalDebugCloneItem=ISInventoryPaneContextMenu.onDebugCloneItem
    function ISInventoryPaneContextMenu.onDebugCloneItem(item,playerNum)
        if item and item:getFullType()==PalmPilots.Constants.ITEM_TYPE then
            return
        end
        return PalmPilots.ContextMenu.originalDebugCloneItem(item,playerNum)
    end
end
