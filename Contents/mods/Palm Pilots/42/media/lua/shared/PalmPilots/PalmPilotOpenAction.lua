require "TimedActions/ISBaseTimedAction"
require "PalmPilots/PalmPilotUtils"

-- Build 42 discovers queued timed-action classes in both client and server Lua.
-- UI-only vanilla actions also live in shared, while perform() remains client-only.
PalmPilots.OpenAction = ISBaseTimedAction:derive("PalmPilotsOpenAction")
local OpenAction=PalmPilots.OpenAction

function OpenAction:resolveItem()
    local item=PalmPilots.Utils.findItemByID(self.character,self.itemID)
    if item and item:getFullType()==PalmPilots.Constants.ITEM_TYPE then
        self.item=item
        return item
    end
    return nil
end

function OpenAction:isValid()
    -- In multiplayer, the server-authoritative equip can reach the client a
    -- few frames after the next queued action begins.  Requiring the item to
    -- already appear in a hand here cancels the open action without an error.
    -- Ownership is the stable validity condition; MainUI follows the hand
    -- state after the equip packet arrives.
    return self:resolveItem()~=nil
end

function OpenAction:perform()
    local item=self:resolveItem()
    -- Match vanilla UI-opening actions: finish/remove this action before
    -- adding a UI that may itself queue work or synchronize inventory data.
    ISBaseTimedAction.perform(self)
    if not isServer() and item and PalmPilots.MainUI then
        PalmPilots.Utils.log("Open action completed for item "..tostring(item:getID()))
        PalmPilots.MainUI.open(self.character,item)
    end
end

function OpenAction:notifyFailure()
    if self.failureNotified then return end
    self.failureNotified=true
    if not isServer() and PalmPilots.Dialogs then
        local item=self:resolveItem()
        local primary=self.character and self.character:getPrimaryHandItem()
        local secondary=self.character and self.character:getSecondaryHandItem()
        PalmPilots.Utils.log("Open action cancelled: item="..tostring(self.itemID)
            .." owned="..tostring(item~=nil)
            .." primary="..tostring(primary and primary:getID())
            .." secondary="..tostring(secondary and secondary:getID())
            .." multiplayer="..tostring(isClient()))
        PalmPilots.Dialogs.message(getText("UI_PalmPilots_OpenFailed"),
            self.character and self.character:getPlayerNum() or 0)
    end
end

function OpenAction:stop()
    self:notifyFailure()
    ISBaseTimedAction.stop(self)
end

function OpenAction:forceCancel()
    self:notifyFailure()
end

function OpenAction:getDuration()
    return 1
end

function OpenAction:new(character,item)
    local o=ISBaseTimedAction.new(self,character)
    o.item=item
    o.itemID=item and item:getID() or -1
    o.maxTime=1
    o.stopOnWalk=false
    o.stopOnRun=true
    -- Match vanilla equip: aiming must not cancel only the follow-up open.
    o.stopOnAim=false
    o.useProgressBar=false
    return o
end
