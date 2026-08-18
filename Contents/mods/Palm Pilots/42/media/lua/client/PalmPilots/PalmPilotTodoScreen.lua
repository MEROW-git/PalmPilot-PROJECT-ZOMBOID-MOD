require "PalmPilots/PalmPilotDialogs"
require "PalmPilots/PalmPilotFindScreen"

PalmPilots.TodoScreen = PalmPilots.TodoScreen or {}
local S = PalmPilots.TodoScreen
local C = PalmPilots.Constants

local function beamLabel(entry,label)
    if entry.beamStatus=="new" then return label.." ("..getText("UI_PalmPilots_BeamNew")..")" end
    if entry.beamStatus=="update" then return label.." ("..getText("UI_PalmPilots_BeamUpdate")..")" end
    return label
end

local function currentList(ui)
    if not ui.todoList then return nil end
    for _, taskList in ipairs(ui.data.todos) do
        if taskList.id == ui.todoList then return taskList end
    end
    ui.todoList = nil
    return nil
end

function S.count(ui)
    local taskList = currentList(ui)
    return taskList and #taskList.items or #ui.data.todos
end

local function listNameDone(ui, button, taskList)
    if button.internal ~= "OK" then return end
    local title = PalmPilots.Utils.clampText(button.parent.entry:getText(), C.MAX_TASK_TEXT)
    if title == "" then PalmPilots.Dialogs.message(getText("UI_PalmPilots_EmptyText")); return end
    title=PalmPilots.Data.uniqueEntryTitle(ui.data,"task",title,taskList and taskList.id or nil)
    if taskList then
        PalmPilots.Data.detachBeamEntry(taskList)
        taskList.title = title
    else table.insert(ui.data.todos, PalmPilots.Data.makeTask(title)) end
    ui:save()
end

local function itemDone(ui, button, item)
    if button.internal ~= "OK" then return end
    local text = PalmPilots.Utils.clampText(button.parent.entry:getText(), C.MAX_TASK_TEXT)
    if text == "" then PalmPilots.Dialogs.message(getText("UI_PalmPilots_EmptyText")); return end
    local taskList = currentList(ui)
    if not taskList then return end
    PalmPilots.Data.detachBeamEntry(taskList)
    if item then item.text = text
    else table.insert(taskList.items, PalmPilots.Data.makeChecklistItem(text)) end
    ui:save()
end

local function deleteListDone(ui, button, index)
    if button.internal ~= "YES" then return end
    table.remove(ui.data.todos, index)
    ui.selected = nil
    ui:save()
end

local function deleteItemDone(ui, button, index)
    if button.internal ~= "YES" then return end
    local taskList = currentList(ui)
    if not taskList then return end
    PalmPilots.Data.detachBeamEntry(taskList)
    table.remove(taskList.items, index)
    ui.selected = nil
    ui:save()
end

local function openList(ui, taskList)
    if taskList.beamStatus then
        taskList.beamStatus=nil
        ui:save()
    end
    ui.todoList = taskList.id
    ui.selected = nil
    ui.scroll = 1
end

local function actionButtons(ui, list, isInside)
    ui:button(getText("UI_PalmPilots_New"),125,555,82,34,function()
        PalmPilots.Dialogs.input(getText(isInside and "UI_PalmPilots_ChecklistItem" or "UI_PalmPilots_TaskListName"),
            "",C.MAX_TASK_TEXT,false,ui,isInside and itemDone or listNameDone)
    end)
    ui:button(getText("UI_PalmPilots_Edit"),213,555,82,34,function()
        local entry=list[ui.selected or 0]
        if entry then
            PalmPilots.Dialogs.input(getText(isInside and "UI_PalmPilots_ChecklistItem" or "UI_PalmPilots_TaskListName"),
                isInside and entry.text or entry.title,C.MAX_TASK_TEXT,false,ui,
                isInside and itemDone or listNameDone,entry)
        end
    end)
    ui:button(getText("UI_PalmPilots_Delete"),301,555,88,34,function()
        if list[ui.selected or 0] then
            PalmPilots.Dialogs.confirm(getText("UI_PalmPilots_ConfirmDelete"),ui,
                isInside and deleteItemDone or deleteListDone,ui.selected)
        end
    end)
    ui:button(getText("UI_PalmPilots_Beam"),395,555,82,34,function()
        local taskList = isInside and currentList(ui) or list[ui.selected or 0]
        if taskList then ui:beginBeam("task",taskList.id) end
    end)
    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function()
        if isInside then ui.todoList=nil; ui.selected=nil; ui.scroll=1
        else ui:setScreen("home") end
    end)
end

function S.render(ui)
    local taskList = currentList(ui)
    local title = taskList and beamLabel(taskList,taskList.title) or getText("UI_PalmPilots_Todo")
    local hint = getText(taskList and "UI_PalmPilots_ChecklistHint" or "UI_PalmPilots_TaskListHint")
    ui:title(title)
    local smallHeight = getTextManager():getFontHeight(UIFont.Small) / ui.scale
    local titleWidth = getTextManager():MeasureStringX(UIFont.Medium,title) / ui.scale
    local hintWidth = getTextManager():MeasureStringX(UIFont.Small,hint) / ui.scale
    if 130 + titleWidth + 12 < 596 - hintWidth then
        ui:rightText(hint,596,120+(48-smallHeight)/2,UIFont.Small)
    end
    local list = taskList and taskList.items or ui.data.todos
    local context=taskList and "checklist" or "todo"
    local ordered=PalmPilots.FindScreen.sorted(ui,list,context,
        function(entry) return taskList and entry.text or entry.title end)
    local first = ui.scroll or 1
    for row=0,6 do
        local rowData=ordered[first+row]
        local index,entry=rowData and rowData.index or nil,rowData and rowData.entry or nil
        if entry then
            local y = 188 + row * 50
            local detail=PalmPilots.Utils.formatGameDate(entry.createdGame)
            if taskList then
                ui:listRow(index,y,entry.text,ui.selected==index,entry.checked,
                    function() ui.selected=index end,
                    function()
                        PalmPilots.Data.detachBeamEntry(taskList)
                        entry.checked=not entry.checked; ui.selected=index; ui:save()
                    end,detail)
            else
                ui:plainListRow(index,y,beamLabel(entry,entry.title),ui.selected==index,
                    function() ui.selected=index end,
                    function() openList(ui,entry) end,detail)
            end
        end
    end
    ui:scrollBar(#list,first,7)
    actionButtons(ui,list,taskList ~= nil)
end
