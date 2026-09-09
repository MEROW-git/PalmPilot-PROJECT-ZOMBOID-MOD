require "TimedActions/ISEquipWeaponAction"
require "PalmPilots/PalmPilotConstants"

-- Vanilla's hotbar detach event always overrides the primary-hand model with
-- the detached item. For a secondary-hand PalmPilot that produces a visible
-- right-hand hop and briefly hides the weapon. Preserve the primary model and
-- place the PalmPilot directly in the secondary-hand model instead.
-- NetTimedAction reconstructs actions using the global named by Type + ".new".
-- Keeping only PalmPilots.EquipAction leaves that server lookup unresolved.
PalmPilotsEquipAction = ISEquipWeaponAction:derive("PalmPilotsEquipAction")
PalmPilots.EquipAction = PalmPilotsEquipAction
local EquipAction=PalmPilots.EquipAction

function EquipAction:setOverrideHandModels(primaryHand,secondaryHand,resetModel)
    -- Vanilla sets these models in BOTH animEvent() and perform(). Redirect
    -- both without replacing its authoritative complete()/sendEquip() path.
    if self.fromHotbar and not self.primary and not self.twoHands then
        primaryHand=self.character:getPrimaryHandItem()
        secondaryHand=self.item
    end
    ISBaseTimedAction.setOverrideHandModels(self,primaryHand,secondaryHand,resetModel)
end

function EquipAction:animEvent(event,parameter)
    -- Detach visuals use client-only hotbar APIs, never the server emulator.
    if isServer() then return end
    ISEquipWeaponAction.animEvent(self,event,parameter)
end

function EquipAction:new(character,item,maxTimeInit,primary,twoHands,alwaysTurnOn)
    -- Build 42 serializes fields by constructor parameter NAME. maxTime is
    -- adjusted on the client; maxTimeInit must stay unchanged for the server.
    return ISEquipWeaponAction.new(self,character,item,maxTimeInit,primary,twoHands,
        alwaysTurnOn)
end
