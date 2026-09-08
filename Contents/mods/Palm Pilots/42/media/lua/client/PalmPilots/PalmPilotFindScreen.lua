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
    local mode=S.mode(ui,context)
    local revision=ui and (ui.dataRevision or 0) or 0
    local count=#(list or {})
    local cache=ui and ui.sortedCache or nil
    if cache and cache.list==list and cache.context==context and cache.mode==mode
            and cache.revision==revision and cache.count==count then
        return cache.rows
    end

    local rows={}
    for index,entry in ipairs(list or {}) do
        table.insert(rows,{index=index,entry=entry,
            label=string.lower(tostring(labelFor(entry) or "")),
            date=PalmPilots.Utils.gameDateKey(entry.createdGame),
            tie=tostring(entry.id or index)})
    end
    table.sort(rows,function(left,right)
        if mode=="name_asc" and left.label~=right.label then return left.label<right.label end
        if mode=="name_desc" and left.label~=right.label then return left.label>right.label end
        if mode=="created_desc" and left.date~=right.date then return left.date>right.date end
        if mode=="created_asc" and left.date~=right.date then return left.date<right.date end
        return left.tie<right.tie
    end)
    if ui then
        ui.sortedCache={list=list,context=context,mode=mode,revision=revision,
            count=count,rows=rows}
    end
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
