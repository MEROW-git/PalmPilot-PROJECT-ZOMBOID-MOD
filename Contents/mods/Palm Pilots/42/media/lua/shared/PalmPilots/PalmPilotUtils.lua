require "PalmPilots/PalmPilotConstants"

PalmPilots.Utils = PalmPilots.Utils or {}
local U = PalmPilots.Utils
local C = PalmPilots.Constants

function U.log(message)
    print("[PalmPilots] " .. tostring(message))
end

function U.trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function U.clampText(value, maximum)
    local text = U.trim(value)
    if #text > maximum then text = string.sub(text, 1, maximum) end
    return text
end

function U.now()
    if getTimestampMs then return getTimestampMs() end
    return math.floor((getGameTime():getWorldAgeHours() or 0) * 3600000)
end

-- Battery consumption must follow the simulation clock so Project Zomboid's
-- fast-forward speeds accelerate it and pausing stops it.
function U.worldTimeMs()
    return math.floor((getGameTime():getWorldAgeHours() or 0) * 3600000)
end

function U.formatGameClock(gameTime)
    gameTime = gameTime or getGameTime()
    local time = gameTime:getTimeOfDay()
    local hour = math.floor(time)
    local minute = math.floor((time % 1) * 60)
    if getCore():getOptionClock24Hour() then
        return string.format("%02d:%02d",hour,minute)
    end
    local suffix = hour >= 12 and getText("UI_PalmPilots_PM") or getText("UI_PalmPilots_AM")
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return string.format("%02d:%02d %s",displayHour,minute,suffix)
end

function U.captureGameDate(gameTime)
    gameTime=gameTime or getGameTime()
    local time=gameTime:getTimeOfDay()
    local hour=math.floor(time)
    local minute=math.floor((time-hour)*60)
    return {
        year=math.floor(gameTime:getYear()),
        month=math.floor(gameTime:getMonth())+1,
        day=math.floor(gameTime:getDay())+1,
        hour=math.max(0,math.min(23,hour)),
        minute=math.max(0,math.min(59,minute)),
    }
end

function U.gameDateKey(stamp)
    if type(stamp)~="table" then return 0 end
    return (tonumber(stamp.year) or 0)*100000000
        +(tonumber(stamp.month) or 0)*1000000
        +(tonumber(stamp.day) or 0)*10000
        +(tonumber(stamp.hour) or 0)*100
        +(tonumber(stamp.minute) or 0)
end

function U.formatGameDate(stamp)
    if type(stamp)~="table" then return "" end
    local year=math.floor(tonumber(stamp.year) or 0)
    local month=math.floor(tonumber(stamp.month) or 0)
    local day=math.floor(tonumber(stamp.day) or 0)
    local hour=math.max(0,math.min(23,math.floor(tonumber(stamp.hour) or 0)))
    local minute=math.max(0,math.min(59,math.floor(tonumber(stamp.minute) or 0)))
    if getCore():getOptionClock24Hour() then
        return string.format("%d/%d/%d %02d:%02d",day,month,year,hour,minute)
    end
    local suffix=hour>=12 and getText("UI_PalmPilots_PM") or getText("UI_PalmPilots_AM")
    local displayHour=hour%12
    if displayHour==0 then displayHour=12 end
    return string.format("%d/%d/%d %d:%02d %s",day,month,year,displayHour,minute,suffix)
end

function U.newID(prefix)
    return tostring(prefix or "id") .. "-" .. tostring(U.now()) .. "-" .. tostring(ZombRand(1000000))
end

function U.distance(a, b)
    local dx, dy = a:getX() - b:getX(), a:getY() - b:getY()
    return math.sqrt(dx * dx + dy * dy)
end

function U.sameFloor(a, b)
    return a and b and math.floor(a:getZ()) == math.floor(b:getZ())
end

local function scanContainer(container, callback)
    if not container then return nil end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local found = callback(item)
        if found then return found end
        if instanceof(item, "InventoryContainer") then
            found = scanContainer(item:getInventory(), callback)
            if found then return found end
        end
    end
    return nil
end

function U.findDevice(player, deviceID, predicate)
    if not player or not player:getInventory() then return nil end
    return scanContainer(player:getInventory(), function(item)
        if item:getFullType() ~= C.ITEM_TYPE then return nil end
        -- Resolve clone identity before comparing IDs. This lets inventory
        -- scans distinguish admin-cloned PalmPilots even before either one is
        -- opened manually.
        local root = PalmPilots.Data and PalmPilots.Data.get and PalmPilots.Data.get(item)
            or item:getModData().PalmPilots
        if root and (not deviceID or root.deviceID == deviceID)
                and (not predicate or predicate(item,root)) then return item end
        return nil
    end)
end

function U.findItemByID(player, itemID)
    if not player or not player:getInventory() then return nil end
    local wanted=tonumber(itemID)
    return scanContainer(player:getInventory(), function(item)
        if item:getID()==wanted then return item end
        return nil
    end)
end

-- Multiplayer may expose separate Lua wrappers for the same network item.
-- Native item IDs survive wrapper changes and, unlike deviceID modData, are
-- not copied by Admin Clone Item.
function U.sameItem(a, b)
    if a == b then return a ~= nil end
    if not a or not b then return false end
    local aID=tonumber(a:getID())
    local bID=tonumber(b:getID())
    return aID and bID and aID >= 0 and aID == bID or false
end

function U.ownsItem(player, item)
    if not player or not item then return false end
    local owned=U.findItemByID(player,item:getID())
    return owned~=nil and owned:getFullType()==C.ITEM_TYPE
end

function U.copyTable(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = U.copyTable(child) end
    return result
end
