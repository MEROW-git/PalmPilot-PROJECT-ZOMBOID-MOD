PalmPilots.FindScreen = PalmPilots.FindScreen or {}
local S=PalmPilots.FindScreen

local VALID_MODES={
    name_asc=true,
    name_desc=true,
    created_desc=true,
    created_asc=true,
}

local function contextFor(ui)
    if ui.findReturnScreen=="memo" then return "memo" end
    if ui.findTodoList then return "checklist" end
    return "todo"
end

function S.mode(ui,context)
    local modes=ui.data.uiPrefs.sortModes
    local mode=type(modes)=="table" and modes[context] or nil
    return VALID_MODES[mode] and mode or "created_asc"
end

function S.sorted(ui,list,context,labelFor)
    local rows={}
    for index,entry in ipairs(list or {}) do
        table.insert(rows,{index=index,entry=entry})
    end
    local mode=S.mode(ui,context)
    table.sort(rows,function(left,right)
        local leftLabel=string.lower(tostring(labelFor(left.entry) or ""))
        local rightLabel=string.lower(tostring(labelFor(right.entry) or ""))
        local leftDate=PalmPilots.Utils.gameDateKey(left.entry.createdGame)
        local rightDate=PalmPilots.Utils.gameDateKey(right.entry.createdGame)
        if mode=="name_asc" and leftLabel~=rightLabel then return leftLabel<rightLabel end
        if mode=="name_desc" and leftLabel~=rightLabel then return leftLabel>rightLabel end
        if mode=="created_desc" and leftDate~=rightDate then return leftDate>rightDate end
        if mode=="created_asc" and leftDate~=rightDate then return leftDate<rightDate end
        return tostring(left.entry.id or left.index)<tostring(right.entry.id or right.index)
    end)
    return rows
end

local function returnToList(ui)
    local screen=ui.findReturnScreen or "todo"
    local todoList=ui.findTodoList
    ui.screen=screen
    ui.todoList=screen=="todo" and todoList or nil
    ui.findReturnScreen=nil
    ui.findTodoList=nil
    ui.selected=nil
    ui.viewNote=nil
    ui.scroll=1
end

local function choose(ui,mode)
    ui.data.uiPrefs.sortModes=type(ui.data.uiPrefs.sortModes)=="table"
        and ui.data.uiPrefs.sortModes or {}
    ui.data.uiPrefs.sortModes[contextFor(ui)]=mode
    ui:save()
    returnToList(ui)
end

function S.open(ui)
    local origin=ui.screen
    if origin~="todo" and origin~="memo" then origin="todo" end
    ui.findReturnScreen=origin
    ui.findTodoList=origin=="todo" and ui.todoList or nil
    ui.screen="find"
    ui.selected=nil
    ui.viewNote=nil
    ui.scroll=1
end

function S.render(ui)
    ui:title(getText("UI_PalmPilots_Find"))
    local context=contextFor(ui)
    local contextKey=context=="memo" and "UI_PalmPilots_Memo"
        or (context=="checklist" and "UI_PalmPilots_Checklist" or "UI_PalmPilots_Todo")
    ui:text(getText("UI_PalmPilots_SortFor",getText(contextKey)),140,195,UIFont.Medium)
    local current=S.mode(ui,context)
    local options={
        {"name_asc","UI_PalmPilots_NameAZ"},
        {"name_desc","UI_PalmPilots_NameZA"},
        {"created_desc","UI_PalmPilots_CreatedNewest"},
        {"created_asc","UI_PalmPilots_CreatedOldest"},
    }
    for index,option in ipairs(options) do
        local label=getText(option[2])
        if current==option[1] then label="> "..label end
        ui:button(label,140,245+(index-1)*58,440,44,function() choose(ui,option[1]) end)
    end
    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() returnToList(ui) end)
end
