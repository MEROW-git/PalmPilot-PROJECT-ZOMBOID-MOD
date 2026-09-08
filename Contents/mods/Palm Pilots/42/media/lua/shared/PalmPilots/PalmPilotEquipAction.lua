require "TimedActions/ISEquipWeaponAction"
require "PalmPilots/PalmPilotConstants"

-- Vanilla's hotbar detach event always overrides the primary-hand model with
-- the detached item. For a secondary-hand PalmPilot that produces a visible
-- right-hand hop and briefly hides the weapon. Preserve the primary model and
-- place the PalmPilot directly in the secondary-hand model instead.
PalmPilots.EquipAction = ISEquipWeaponAction:derive("PalmPilotsEquipAction")
local EquipAction=PalmPilots.EquipAction

function EquipAction:animEvent(event,parameter)
    if event=="detachConnect" and self.fromHotbar and not self.primary
            and not self.twoHands then
        local hotbar=getPlayerHotbar(self.character:getPlayerNum())
        hotbar.chr:removeAttachedItem(self.item)
        self:setOverrideHandModels(self.character:getPrimaryHandItem(),self.item)
        self:overrideWeaponType()
        if self.maxTime==-1 then self:forceComplete() end
        return
    end
    ISEquipWeaponAction.animEvent(self,event,parameter)
end

function EquipAction:new(character,item,maxTime,primary,twoHands,alwaysTurnOn)
    return ISEquipWeaponAction.new(self,character,item,maxTime,primary,twoHands,
        alwaysTurnOn)
end
