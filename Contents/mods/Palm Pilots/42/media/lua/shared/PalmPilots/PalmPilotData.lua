require "PalmPilots/PalmPilotUtils"
require "PalmPilots/PalmPilotChess"

PalmPilots.Data = PalmPilots.Data or {}
local D = PalmPilots.Data
local U = PalmPilots.Utils
local C = PalmPilots.Constants

function D.updateTooltip(item, data)
    if not item or not item.setTooltip then return end
    data=data or (item:getModData() and item:getModData().PalmPilots)
    local nickname=type(data)=="table" and U.clampText(data.deviceName,C.MAX_DEVICE_NAME) or ""
    if nickname=="" then
        item:setTooltip(nil)
    else
        -- Build 42 stores this field for later tooltip rendering. Passing a
        -- formatted translation here caused the server to store the key and
        -- the client to display its unresolved "%1$s" argument.
        item:setTooltip("This PalmPilot belongs to: "..nickname)
    end
end

local function cleanBatteryLevel(value)
    value = tonumber(value)
    if value == nil then return 1 end
    return math.max(0, math.min(1, value))
end

local function cleanGameDate(value)
    if type(value)~="table" then return U.captureGameDate() end
    local current=U.captureGameDate()
    return {
        year=math.floor(tonumber(value.year) or current.year),
        month=math.max(1,math.min(12,math.floor(tonumber(value.month) or current.month))),
        day=math.max(1,math.min(31,math.floor(tonumber(value.day) or current.day))),
        hour=math.max(0,math.min(23,math.floor(tonumber(value.hour) or current.hour))),
        minute=math.max(0,math.min(59,math.floor(tonumber(value.minute) or current.minute))),
    }
end

local function nativeItemID(item)
    return item and tostring(item:getID()) or ""
end

local function deviceIDForItem(item)
    return "device-item-" .. nativeItemID(item)
end

function D.setBatteryLevel(item, data, value)
    local level=cleanBatteryLevel(value)
    data.batteryLevel=level
    data.batteryInstalled=level>0
    if item and instanceof(item,"DrainableComboItem") then item:setUsedDelta(level) end
    return level
end

local function cleanChecklistItem(item)
    if type(item) ~= "table" then return nil end
    local text = U.clampText(item.text, C.MAX_TASK_TEXT)
    if text == "" then return nil end
    return { id=tostring(item.id or U.newID("item")), text=text, checked=item.checked == true,
        created=tonumber(item.created) or U.now(), createdGame=cleanGameDate(item.createdGame) }
end

local function cleanTask(task)
    if type(task) ~= "table" then return nil end
    local title = U.clampText(task.title or task.text, C.MAX_TASK_TEXT)
    if title == "" then return nil end
    local cleaned = { id=tostring(task.id or U.newID("task")), title=title, items={},
        created=tonumber(task.created) or U.now(), createdGame=cleanGameDate(task.createdGame),
        priority=tonumber(task.priority) or 0,
        sourceDeviceID=task.sourceDeviceID and tostring(task.sourceDeviceID) or nil,
        sourceEntryID=task.sourceEntryID and tostring(task.sourceEntryID) or nil,
        beamStatus=(task.beamStatus=="new" or task.beamStatus=="update") and task.beamStatus or nil }
    if type(task.items) == "table" then
        for _, item in ipairs(task.items) do
            if #cleaned.items>=C.MAX_CHECKLIST_ITEMS then break end
            local clean = cleanChecklistItem(item)
            if clean then table.insert(cleaned.items, clean) end
        end
    end
    return cleaned
end

local function cleanNote(note)
    if type(note) ~= "table" then return nil end
    local title = U.clampText(note.title, C.MAX_NOTE_TITLE)
    local body = tostring(note.body or "")
    if #body > C.MAX_NOTE_BODY then body = string.sub(body, 1, C.MAX_NOTE_BODY) end
    if title == "" then return nil end
    return { id=tostring(note.id or U.newID("note")), title=title, body=body,
        created=tonumber(note.created) or U.now(), createdGame=cleanGameDate(note.createdGame),
        edited=tonumber(note.edited) or U.now(),
        sourceDeviceID=note.sourceDeviceID and tostring(note.sourceDeviceID) or nil,
        sourceEntryID=note.sourceEntryID and tostring(note.sourceEntryID) or nil,
        beamStatus=(note.beamStatus=="new" or note.beamStatus=="update") and note.beamStatus or nil }
end

local function uniqueTitleFromUsed(used,title,maxLength)
    if not used[title] then return title end
    local number=1
    while true do
        local suffix="-"..tostring(number)
        local base=string.sub(title,1,math.max(0,maxLength-#suffix))
        local candidate=base..suffix
        if not used[candidate] then return candidate end
        number=number+1
    end
end

local function normalizeEntryTitles(list,maxLength)
    local used={}
    for _,entry in ipairs(list) do
        entry.title=uniqueTitleFromUsed(used,entry.title,maxLength)
        used[entry.title]=true
    end
end

local function cleanUIPrefs(raw)
    raw=type(raw)=="table" and raw or {}
    local prefs={}
    local x,y=tonumber(raw.positionX),tonumber(raw.positionY)
    if x then prefs.positionX=math.floor(x) end
    if y then prefs.positionY=math.floor(y) end
    local screens={home=true,todo=true,memo=true,calculator=true,calendar=true,
        snake=true,chess=true,beam=true,settings=true,find=true}
    if screens[raw.lastScreen] then prefs.lastScreen=raw.lastScreen end
    local modes={name_asc=true,name_desc=true,created_desc=true,created_asc=true}
    if type(raw.sortModes)=="table" then
        prefs.sortModes={}
        for _,context in ipairs({"todo","checklist","memo"}) do
            local mode=raw.sortModes[context]
            if modes[mode] then prefs.sortModes[context]=mode end
        end
    end
    return prefs
end

local startingPieces={P=8,N=2,B=2,R=2,Q=1,p=8,n=2,b=2,r=2,q=1}
local capturedOrder={"Q","R","B","N","P","q","r","b","n","p"}

local function inferCaptured(state)
    local remaining={}
    for square=1,64 do
        local piece=state.board[square]
        if piece then remaining[piece]=(remaining[piece] or 0)+1 end
    end
    local white,black={},{}
    for _,piece in ipairs(capturedOrder) do
        local missing=math.max(0,startingPieces[piece]-(remaining[piece] or 0))
        local list=piece==string.upper(piece) and white or black
        for _=1,missing do list[#list+1]=piece end
    end
    -- A promoted pawn is no longer on the board. Avoid counting one as a
    -- capture when the board has an extra queen, rook, bishop, or knight.
    for _,side in ipairs({{white,"P",{"Q","R","B","N"}},
            {black,"p",{"q","r","b","n"}}}) do
        local extra=0
        for _,piece in ipairs(side[3]) do
            extra=extra+math.max(0,(remaining[piece] or 0)-startingPieces[piece])
        end
        for index=#side[1],1,-1 do
            if extra==0 then break end
            if side[1][index]==side[2] then table.remove(side[1],index); extra=extra-1 end
        end
    end
    return white,black
end

local function cleanCaptured(raw,white,fallback)
    if type(raw)~="table" then return fallback end
    local cleaned={}
    local allowed=white and "PNBRQ" or "pnbrq"
    for index=1,math.min(#raw,16) do
        local piece=raw[index]
        if type(piece)=="string" and #piece==1 and allowed:find(piece,1,true) then
            cleaned[#cleaned+1]=piece
        end
    end
    return cleaned
end

function D.sanitize(raw, createID)
    raw = type(raw) == "table" and raw or {}
    local savedChessState=PalmPilots.Chess.fromFEN(raw.chessFEN)
    local chessState=savedChessState or PalmPilots.Chess.new()
    local inferredWhite,inferredBlack=inferCaptured(chessState)
    local data = {
        schemaVersion=C.SCHEMA_VERSION,
        deviceID=tostring(raw.deviceID or (createID and U.newID("device") or "")),
        boundItemID=tostring(raw.boundItemID or ""),
        todos={}, notes={}, snakeHighScore=math.max(0, math.floor(tonumber(raw.snakeHighScore) or 0)),
        chessFEN=PalmPilots.Chess.toFEN(chessState),
        chessCapturedWhite=cleanCaptured(savedChessState and raw.chessCapturedWhite,true,inferredWhite),
        chessCapturedBlack=cleanCaptured(savedChessState and raw.chessCapturedBlack,false,inferredBlack),
        uiPrefs=cleanUIPrefs(raw.uiPrefs),
        deviceName=U.clampText(raw.deviceName, C.MAX_DEVICE_NAME),
        batteryLevel=cleanBatteryLevel(raw.batteryLevel),
        batteryInstalled=raw.batteryInstalled ~= false,
        -- Beam is enabled by default so existing PalmPilots keep their current
        -- behaviour after upgrading to the privacy setting.
        beamEnabled=raw.beamEnabled ~= false,
    }
    if type(raw.todos) == "table" then
        local imported = {}
        local scanned=0
        for _, task in ipairs(raw.todos) do
            scanned=scanned+1
            if scanned>C.MAX_TASK_LISTS+C.MAX_CHECKLIST_ITEMS then break end
            if #data.todos>=C.MAX_TASK_LISTS then break end
            if type(task) == "table" and (type(task.items) == "table" or task.title ~= nil) then
                local clean=cleanTask(task); if clean then table.insert(data.todos, clean) end
            else
                -- Schema 1 stored every checkbox directly in todos. Preserve those
                -- rows as checklist items inside one migrated task list.
                local clean=cleanChecklistItem(task)
                if clean and #imported<C.MAX_CHECKLIST_ITEMS then table.insert(imported, clean) end
            end
        end
        if #imported > 0 then
            if #data.todos>=C.MAX_TASK_LISTS then table.remove(data.todos) end
            table.insert(data.todos, 1, {id=U.newID("task"), title="Imported Tasks",
                items=imported, created=U.now(), createdGame=U.captureGameDate(), priority=0})
        end
    end
    if type(raw.notes) == "table" then
        for _, note in ipairs(raw.notes) do
            if #data.notes>=C.MAX_NOTES then break end
            local clean=cleanNote(note); if clean then table.insert(data.notes, clean) end
        end
    end
    normalizeEntryTitles(data.todos,C.MAX_TASK_TEXT)
    normalizeEntryTitles(data.notes,C.MAX_NOTE_TITLE)
    return data
end

function D.get(item)
    if not item or item:getFullType() ~= C.ITEM_TYPE then return nil end
    -- Saved inventory items retain the script properties they were created
    -- with. Upgrade PalmPilots created before the 3D model was introduced.
    if item.setWorldStaticModel and (not item:getWorldStaticItem()) then
        item:setWorldStaticModel(C.WORLD_MODEL)
    end
    local modData = item:getModData()
    local oldData=modData.PalmPilots
    local oldSchema=type(oldData)=="table" and tonumber(oldData.schemaVersion) or 0
    modData.PalmPilots = D.sanitize(oldData, true)
    local itemID=nativeItemID(item)
    if oldSchema<7 or modData.PalmPilots.boundItemID~=itemID then
        -- Admin Clone Item copies modData, including deviceID. The native item
        -- ID is unique, so bind identity to it and deterministically re-key a
        -- copied PalmPilot on both the client and server.
        modData.PalmPilots.deviceID=deviceIDForItem(item)
        modData.PalmPilots.boundItemID=itemID
    end
    if instanceof(item,"DrainableComboItem") then
        if oldSchema<6 then
            -- Migrate the custom battery state once into Build 42's native
            -- drainable charge used by Insert/Remove Battery recipes.
            D.setBatteryLevel(item,modData.PalmPilots,
                modData.PalmPilots.batteryInstalled and modData.PalmPilots.batteryLevel or 0)
        else
            D.setBatteryLevel(item,modData.PalmPilots,item:getCurrentUsesFloat())
        end
    end
    D.updateTooltip(item, modData.PalmPilots)
    return modData.PalmPilots
end

function D.set(item, raw)
    if not item or item:getFullType() ~= C.ITEM_TYPE then return nil end
    local current = D.get(item)
    local clean = D.sanitize(raw, false)
    clean.deviceID = current.deviceID
    clean.boundItemID = current.boundItemID
    item:getModData().PalmPilots = clean
    D.setBatteryLevel(item,clean,clean.batteryLevel)
    D.updateTooltip(item, clean)
    return clean
end

function D.findEntry(data, kind, id)
    local list = kind == "task" and data.todos or (kind == "note" and data.notes or nil)
    if not list then return nil end
    for index, entry in ipairs(list) do if entry.id == id then return entry, index end end
    return nil
end

function D.uniqueEntryTitle(data,kind,title,skipID)
    local list=kind=="task" and data.todos or (kind=="note" and data.notes or {})
    local used={}
    for _,entry in ipairs(list) do
        if not skipID or entry.id~=skipID then used[tostring(entry.title or "")]=true end
    end
    local maxLength=kind=="task" and C.MAX_TASK_TEXT or C.MAX_NOTE_TITLE
    return uniqueTitleFromUsed(used,title,maxLength)
end

function D.makeTask(text)
    return cleanTask({id=U.newID("task"), title=text, items={}, created=U.now()})
end

function D.makeChecklistItem(text)
    return cleanChecklistItem({id=U.newID("item"), text=text, created=U.now()})
end

function D.makeNote(title, body)
    return cleanNote({id=U.newID("note"), title=title, body=body, created=U.now(), edited=U.now()})
end

function D.detachBeamEntry(entry)
    if not entry then return end
    entry.sourceDeviceID=nil
    entry.sourceEntryID=nil
    entry.beamStatus=nil
end

function D.copyEntry(entry, kind, sourceDeviceID)
    local copy = U.copyTable(entry)
    copy.id = U.newID(kind)
    -- Keep the original entry identity across repeated beams and forwarding.
    -- The receiver still gets its own local id, but these two fields identify
    -- which remote entry should be updated instead of duplicated.
    copy.sourceDeviceID = entry.sourceDeviceID or sourceDeviceID
    copy.sourceEntryID = entry.sourceEntryID or entry.id
    copy.beamStatus = "new"
    copy.created = U.now()
    if kind == "note" then copy.edited = copy.created end
    return kind == "task" and cleanTask(copy) or cleanNote(copy)
end

local function sameBeamContent(left,right,kind)
    if kind=="note" then
        return left.title==right.title and tostring(left.body or "")==tostring(right.body or "")
    end
    if left.title~=right.title or #(left.items or {})~=#(right.items or {}) then return false end
    for index,item in ipairs(left.items or {}) do
        local other=(right.items or {})[index]
        if not other or item.text~=other.text or (item.checked==true)~=(other.checked==true) then return false end
    end
    return true
end

function D.applyBeamEntry(data, incoming, kind)
    local list = kind == "task" and data.todos or (kind == "note" and data.notes or nil)
    if not list or type(incoming) ~= "table" then return nil end
    local clean = kind == "task" and cleanTask(incoming) or cleanNote(incoming)
    if not clean then return nil end
    local sourceVersion=U.copyTable(clean)

    local existingIndex=nil
    if clean.sourceDeviceID and clean.sourceEntryID then
        for index,entry in ipairs(list) do
            if entry.sourceDeviceID==clean.sourceDeviceID
                    and entry.sourceEntryID==clean.sourceEntryID then
                existingIndex=index
                break
            end
        end
    end

    -- Schema 7 Beam copies knew the source device but not the source entry.
    -- Adopt an exact legacy match so upgrading does not add one more copy.
    if not existingIndex and clean.sourceDeviceID then
        for index,entry in ipairs(list) do
            if entry.sourceDeviceID==clean.sourceDeviceID and not entry.sourceEntryID
                    and sameBeamContent(entry,clean,kind) then
                existingIndex=index
                break
            end
        end
    end

    if existingIndex then
        local existing=list[existingIndex]
        clean.id=existing.id
        clean.created=existing.created
        clean.createdGame=existing.createdGame
        clean.beamStatus="update"
        clean.title=D.uniqueEntryTitle(data,kind,clean.title,clean.id)
        list[existingIndex]=clean

        -- Remove only byte-for-byte equivalent legacy Beam copies. Entries
        -- with different text or checklist state remain untouched.
        for index=#list,1,-1 do
            local entry=list[index]
            if index~=existingIndex and entry.sourceDeviceID==clean.sourceDeviceID
                    and not entry.sourceEntryID and sameBeamContent(entry,sourceVersion,kind) then
                table.remove(list,index)
                if index<existingIndex then existingIndex=existingIndex-1 end
            end
        end
        return clean,"update",existingIndex
    end

    clean.beamStatus="new"
    clean.title=D.uniqueEntryTitle(data,kind,clean.title,nil)
    table.insert(list,clean)
    return clean,"new",#list
end

function D.copyAllEntries(data)
    local copies={todos={},notes={}}
    for _,task in ipairs(data and data.todos or {}) do
        local copy=D.copyEntry(task,"task",data.deviceID)
        if copy then table.insert(copies.todos,copy) end
    end
    for _,note in ipairs(data and data.notes or {}) do
        local copy=D.copyEntry(note,"note",data.deviceID)
        if copy then table.insert(copies.notes,copy) end
    end
    return copies
end
