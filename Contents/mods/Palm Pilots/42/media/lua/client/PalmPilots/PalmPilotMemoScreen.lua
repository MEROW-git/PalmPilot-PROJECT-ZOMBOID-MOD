require "PalmPilots/PalmPilotDialogs"
require "PalmPilots/PalmPilotFindScreen"

PalmPilots.MemoScreen = PalmPilots.MemoScreen or {}
local S = PalmPilots.MemoScreen
local C = PalmPilots.Constants

local function beamLabel(entry,label)
    if entry.beamStatus=="new" then return label.." ("..getText("UI_PalmPilots_BeamNew")..")" end
    if entry.beamStatus=="update" then return label.." ("..getText("UI_PalmPilots_BeamUpdate")..")" end
    return label
end

local function bodyDone(ctx, button, note)
    if button.internal ~= "OK" then return end
    local body = button.parent.entry:getText() or ""
    if #body > C.MAX_NOTE_BODY then body=string.sub(body,1,C.MAX_NOTE_BODY) end
    if note then
        PalmPilots.Data.detachBeamEntry(note)
        note.body=body; note.edited=PalmPilots.Utils.now()
    else table.insert(ctx.data.notes, PalmPilots.Data.makeNote(ctx.pendingTitle, body)) end
    ctx.pendingTitle=nil; ctx:save()
end

local function titleDone(ctx, button, note)
    if button.internal ~= "OK" then return end
    local title=PalmPilots.Utils.clampText(button.parent.entry:getText(),C.MAX_NOTE_TITLE)
    if title=="" then PalmPilots.Dialogs.message(getText("UI_PalmPilots_EmptyText")); return end
    title=PalmPilots.Data.uniqueEntryTitle(ctx.data,"note",title,note and note.id or nil)
    if note then
        PalmPilots.Data.detachBeamEntry(note)
        note.title=title
        PalmPilots.Dialogs.input(getText("UI_PalmPilots_NoteBody"),note.body,C.MAX_NOTE_BODY,true,ctx,bodyDone,note)
    else ctx.pendingTitle=title; PalmPilots.Dialogs.input(getText("UI_PalmPilots_NoteBody"),"",C.MAX_NOTE_BODY,true,ctx,bodyDone) end
end

local function deleteDone(ctx,button,index)
    if button.internal=="YES" then table.remove(ctx.data.notes,index); ctx.selected=nil; ctx.viewNote=nil; ctx:save() end
end

function S.render(ui)
    ui:title(getText("UI_PalmPilots_Memo"))
    local list=ui.data.notes
    if ui.viewNote and list[ui.viewNote] then
        local note=list[ui.viewNote]; ui:text(beamLabel(note,note.title),132,180,UIFont.Medium)
        ui:wrappedText(note.body,132,225,445,ui.bodyScroll or 0,12)
    else
        local first=ui.scroll or 1
        local ordered=PalmPilots.FindScreen.sorted(ui,list,"memo",function(note) return note.title end)
        for row=0,7 do local rowData=ordered[first+row]
            local index=rowData and rowData.index or nil
            local note=rowData and rowData.entry or nil
            if note then
            ui:plainListRow(index,188+row*46,beamLabel(note,note.title),ui.selected==index,
                function() ui.selected=index end,
                function()
                    ui.selected=index; ui.viewNote=index; ui.bodyScroll=0
                    if note.beamStatus then note.beamStatus=nil; ui:save() end
                end,PalmPilots.Utils.formatGameDate(note.createdGame))
        end end
        ui:scrollBar(#list,first,8)
    end
    ui:button(getText("UI_PalmPilots_New"),125,555,82,34,function() PalmPilots.Dialogs.input(getText("UI_PalmPilots_NoteTitle"),"",C.MAX_NOTE_TITLE,false,ui,titleDone) end)
    ui:button(getText("UI_PalmPilots_Edit"),213,555,82,34,function() local n=list[(ui.viewNote or ui.selected or 0)]; if n then PalmPilots.Dialogs.input(getText("UI_PalmPilots_NoteTitle"),n.title,C.MAX_NOTE_TITLE,false,ui,titleDone,n) end end)
    ui:button(getText("UI_PalmPilots_Delete"),301,555,88,34,function() local i=ui.viewNote or ui.selected; if list[i or 0] then PalmPilots.Dialogs.confirm(getText("UI_PalmPilots_ConfirmDelete"),ui,deleteDone,i) end end)
    ui:button(getText("UI_PalmPilots_Beam"),395,555,82,34,function() local i=ui.viewNote or ui.selected; if list[i or 0] then ui:beginBeam("note",list[i].id) end end)
    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() if ui.viewNote then ui.viewNote=nil else ui:setScreen("home") end end)
end
