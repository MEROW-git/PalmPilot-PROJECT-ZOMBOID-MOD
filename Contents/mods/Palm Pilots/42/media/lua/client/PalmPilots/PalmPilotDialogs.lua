require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"

PalmPilots.Dialogs = PalmPilots.Dialogs or {}
local Dialogs = PalmPilots.Dialogs

local function center(dialog)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:setX((getCore():getScreenWidth() - dialog.width) / 2)
    dialog:setY((getCore():getScreenHeight() - dialog.height) / 2)
    dialog:bringToTop()
end

function Dialogs.message(text, playerNum)
    local dialog = ISModalDialog:new(0, 0, 420, 140, text, false, nil, nil,
        tonumber(playerNum) or 0)
    center(dialog)
    Dialogs.activeDialog = dialog
    return dialog
end

function Dialogs.confirm(text, target, callback, arg1, arg2, playerNum)
    -- Build 42 constructor order is player, param1, param2 after the callback.
    local dialog = ISModalDialog:new(0, 0, 420, 150, text, true, target, callback,
        tonumber(playerNum) or 0, arg1, arg2)
    center(dialog)
    Dialogs.activeDialog = dialog
    return dialog
end

function Dialogs.input(title, value, maxChars, multiline, target, callback, arg1, playerNum)
    -- ISTextBox places its entry at half of the constructor height, then resizes
    -- itself around the controls. A large starting height therefore creates a
    -- large blank strip above the entry. Keep that layout seed compact; the
    -- final height still expands automatically for multi-line memo bodies.
    local width = multiline and 520 or 440
    local dialog = ISTextBox:new(0, 0, width, 70, title, value or "", target,
        callback, tonumber(playerNum) or 0, arg1)
    dialog:setMultipleLine(multiline == true)
    dialog:setNumberOfLines(multiline and 8 or 1)
    -- Build 42's setter touches javaObject too early when called before initialise.
    -- Set the field directly; ISTextBox:initialise applies it to the entry safely.
    dialog.maxLines = multiline and 30 or 1
    dialog.maxChars = maxChars
    center(dialog)
    dialog.entry:focus()
    Dialogs.activeDialog = dialog
    return dialog
end

function Dialogs.hasActiveDialog()
    local dialog = Dialogs.activeDialog
    return dialog ~= nil and dialog.getIsVisible ~= nil and dialog:getIsVisible()
end

-- Reusable aliases used by screens; rows, checkboxes, and scroll bars are drawn
-- by the device renderer so they inherit its exact LCD scaling.
Dialogs.ConfirmationDialog = Dialogs.confirm
Dialogs.MessageDialog = Dialogs.message
Dialogs.TextInput = Dialogs.input
