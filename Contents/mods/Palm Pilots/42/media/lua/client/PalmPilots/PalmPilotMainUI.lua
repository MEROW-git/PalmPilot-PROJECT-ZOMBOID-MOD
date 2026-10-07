require "ISUI/ISPanel"
require "PalmPilots/PalmPilotData"
require "PalmPilots/PalmPilotUIConfig"
require "PalmPilots/PalmPilotHomeScreen"
require "PalmPilots/PalmPilotTodoScreen"
require "PalmPilots/PalmPilotMemoScreen"
require "PalmPilots/PalmPilotCalculatorScreen"
require "PalmPilots/PalmPilotCalendarScreen"
require "PalmPilots/PalmPilotSnakeScreen"
require "PalmPilots/PalmPilotChessScreen"
require "PalmPilots/PalmPilotBeamScreen"
require "PalmPilots/PalmPilotSettingsScreen"
require "PalmPilots/PalmPilotFindScreen"
require "PalmPilots/PalmPilotClientCommands"

PalmPilots.MainUI = ISPanel:derive("PalmPilotsMainUI")
local MainUI=PalmPilots.MainUI
local Config=PalmPilots.UIConfig
local Ink=Config.colors.ink

require 'TimedActions/ISUnequipAction'
require 'TimedActions/ISTimedActionQueue'

MainUI.instances={}

-- ISUI calls update every rendered frame. Keep only cheap state checks there;
-- Java item writes and fallback inventory scans run at bounded intervals.
local ITEM_RESOLVE_INTERVAL_MS=350
local BATTERY_UPDATE_INTERVAL_MS=250

local function matchesItemID(item,itemID)
    if not item or itemID==nil then return false end
    local current=tonumber(item:getID())
    local wanted=tonumber(itemID)
    return current~=nil and wanted~=nil and current==wanted
end

local function keyHandler(key)
    for _,ui in pairs(MainUI.instances) do if ui and ui:getIsVisible() then ui:handleKey(key) end end
end

function MainUI.open(player,item)
    if not player or not item or item:getFullType()~=PalmPilots.Constants.ITEM_TYPE then return end
    local data=PalmPilots.Data.get(item)
    local playerNum=player:getPlayerNum(); local old=MainUI.instances[playerNum]
    if old then old:close() end
    local scale=math.min(1,(getCore():getScreenHeight()*Config.maxScreenHeightRatio)/Config.imageHeight)
    local width,height=Config.imageWidth*scale,Config.imageHeight*scale
    local positionX=tonumber(data.uiPrefs.positionX) or (getCore():getScreenWidth()-width)/2
    local positionY=tonumber(data.uiPrefs.positionY) or (getCore():getScreenHeight()-height)/2
    positionX=math.max(0,math.min(getCore():getScreenWidth()-width,positionX))
    positionY=math.max(0,math.min(getCore():getScreenHeight()-height,positionY))
    local ui=MainUI:new(positionX,positionY,width,height,player,item,scale,data)
    ui:initialise(); ui:addToUIManager(); MainUI.instances[playerNum]=ui
    Events.OnKeyPressed.Remove(keyHandler); Events.OnKeyPressed.Add(keyHandler)
    ui:save()
end

function MainUI:new(x,y,w,h,player,item,scale,data)
    local o=ISPanel.new(self,x,y,w,h); o.background=false; o.player=player; o.playerNum=player:getPlayerNum(); o.item=item
    o.data=data or PalmPilots.Data.get(item); o.itemID=item:getID(); o.deviceID=o.data.deviceID
    local hotbar=getPlayerHotbar and getPlayerHotbar(player:getPlayerNum()) or nil
    -- Equipped-from-hotbar items keep their attached slot while temporarily
    -- held. Remember that state so closing the UI can return the device.
    o.returnToHotbar=hotbar and hotbar:isItemAttached(item) and item:getAttachedSlot()>=0 or false
    -- Server-authoritative multiplayer equip can arrive shortly after the
    -- queued open action completes.  Do not close the UI during that window.
    o.handGraceUntil=PalmPilots.Utils.now()+2000
    o.scale=scale; o.screen="home"; o.buttons={}; o.pressed=nil; o.moving=false
    o.dead=o.data.batteryLevel<=0; o.lastNativeBatteryLevel=o.data.batteryLevel
    o.lastBatteryTick=PalmPilots.Utils.worldTimeMs()
    o.lastBatterySave=PalmPilots.Utils.now()
    o.lastItemResolve=nil; o.nextBatteryUpdate=0
    o.dataRevision=0; o.sortedCache=nil
    o.texture=getTexture(Config.image); o.deadTexture=getTexture(Config.deadImage); o.artMissing=not o.texture
    o.appTextures={}
    for app,path in pairs(Config.appIcons) do
        o.appTextures[app]=getTexture(path)
        if not o.appTextures[app] then PalmPilots.Utils.log("Missing app icon: "..path) end
    end
    o.chessPieceTextures={}
    for piece,path in pairs(Config.chessPieces) do
        o.chessPieceTextures[piece]=getTexture(path)
        if not o.chessPieceTextures[piece] then PalmPilots.Utils.log("Missing Chess piece: "..path) end
    end
    o.arrowTextures={}
    for direction,path in pairs(Config.snakeArrows) do
        o.arrowTextures[direction]=getTexture(path)
        if not o.arrowTextures[direction] then PalmPilots.Utils.log("Missing Snake arrow: "..path) end
    end
    o.batteryTextures={}
    for level,path in pairs(Config.batteryIcons) do
        o.batteryTextures[level]=getTexture(path)
        if not o.batteryTextures[level] then PalmPilots.Utils.log("Missing battery icon: "..path) end
    end
    if o.artMissing then PalmPilots.Utils.log("Missing device artwork: 42/media/ui/PalmPilot/PalmPilot_Device.png") end
    if not o.deadTexture then PalmPilots.Utils.log("Missing dead device artwork: 42/media/ui/PalmPilot/Die_PalmPilot_Device.png") end
    return o
end

function MainUI:invalidateDataViews()
    self.dataRevision=(self.dataRevision or 0)+1
    self.sortedCache=nil
end

function MainUI:resolveItem(force)
    if not self.player or not self.itemID then return nil end
    local now=PalmPilots.Utils.now()
    local primary=self.player:getPrimaryHandItem()
    local secondary=self.player:getSecondaryHandItem()
    local item=matchesItemID(primary,self.itemID) and primary
        or (matchesItemID(secondary,self.itemID) and secondary or nil)

    -- A held item is the common path and needs no recursive inventory scan.
    -- During the multiplayer equip grace period, scan at most a few times.
    if not item then
        if not force and self.lastItemResolve
                and now-self.lastItemResolve<ITEM_RESOLVE_INTERVAL_MS then
            return self.item
        end
        self.lastItemResolve=now
        item=PalmPilots.Utils.findItemByID(self.player,self.itemID)
    else
        self.lastItemResolve=now
    end
    if not item or item:getFullType()~=PalmPilots.Constants.ITEM_TYPE then return nil end
    local wrapperChanged=item~=self.item
    local data=wrapperChanged and PalmPilots.Data.get(item) or self.data
    if not data or data.deviceID~=self.deviceID then return nil end
    if wrapperChanged then
        self.item=item
        self.data=data
        self.lastNativeBatteryLevel=data.batteryLevel
        self.nextBatteryUpdate=0
        self:invalidateDataViews()
    end
    return item
end

function MainUI:close()
    if self.closed then return end; self.closed=true
    if self.screen=="chess" then PalmPilots.ChessScreen.leave(self) end
    local returnItem=nil
    if self.data then
        self.data.uiPrefs.lastScreen=self.screen
        if self.player and not self.player:isDead() and self:resolveItem(true) then
            self:save()
            local hotbar=getPlayerHotbar and getPlayerHotbar(self.playerNum) or nil
            local held=PalmPilots.Utils.sameItem(self.player:getPrimaryHandItem(),self.item)
                or PalmPilots.Utils.sameItem(self.player:getSecondaryHandItem(),self.item)
            if self.returnToHotbar and held and hotbar and hotbar:isItemAttached(self.item) then
                returnItem=self.item
            end
        end
    end
    self:setVisible(false); self:removeFromUIManager(); MainUI.instances[self.playerNum]=nil
    local any=false; for _,ui in pairs(MainUI.instances) do if ui then any=true end end
    if not any then Events.OnKeyPressed.Remove(keyHandler) end
    if returnItem then
        ISTimedActionQueue.add(ISUnequipAction:new(self.player,returnItem,20))
    end
end

function MainUI:update()
    ISPanel.update(self)
    if not self.player or self.player:isDead() or not self:resolveItem() then self:close(); return end
    -- The screen represents the PalmPilot currently being held. Close it as
    -- soon as another item replaces that device in both hands.
    local held=PalmPilots.Utils.sameItem(self.player:getPrimaryHandItem(),self.item)
        or PalmPilots.Utils.sameItem(self.player:getSecondaryHandItem(),self.item)
    if held then
        self.handGraceUntil=nil
    elseif not self.handGraceUntil or PalmPilots.Utils.now()>=self.handGraceUntil then
        self:close(); return
    end
    -- Walking is safe, but put the PalmPilot away as soon as the character
    -- starts running or sprinting so the UI cannot obstruct an escape.
    if self.player:isPlayerMoving()
            and (self.player:isRunning() or self.player:isSprinting()) then
        self:close(); return
    end
    local now=PalmPilots.Utils.now()
    if now>=(self.nextBatteryUpdate or 0) then
        self.nextBatteryUpdate=now+BATTERY_UPDATE_INTERVAL_MS
        self:refreshNativeBattery()
        if not self.dead and not self:updateBattery() then return end
    end
    if self.dead then return end
    if self.screen=="snake" then PalmPilots.SnakeScreen.tick(self) end
    if self.screen=="chess" then PalmPilots.ChessScreen.tick(self) end
end

function MainUI:refreshNativeBattery()
    if not instanceof(self.item,"DrainableComboItem") then return end
    local native=math.max(0,math.min(1,tonumber(self.item:getCurrentUsesFloat()) or 0))
    local previous=tonumber(self.lastNativeBatteryLevel)
    if previous and math.abs(native-previous)<0.000001 then return end

    self.lastNativeBatteryLevel=native
    self.data.batteryLevel=native
    self.data.batteryInstalled=native>0
    if native<=0 then
        self.dead=true
        self.screen="dead"
    elseif self.dead then
        self.dead=false
        self.screen="home"
        self.lastBatteryTick=PalmPilots.Utils.worldTimeMs()
    end
    self.item:getModData().PalmPilots=self.data
    PalmPilots.Data.updateTooltip(self.item,self.data)
    PalmPilots.Client.syncDevice(self)
end

function MainUI:updateBattery()
    local now=PalmPilots.Utils.worldTimeMs()
    -- Do not cap elapsed time: fast-forward may advance many game minutes
    -- between UI updates, and all of that screen-on time consumes charge.
    local elapsed=math.max(0,now-(self.lastBatteryTick or now))
    self.lastBatteryTick=now
    if elapsed>0 then
        local level=math.max(0,(tonumber(self.data.batteryLevel) or 1)
            - elapsed/PalmPilots.Constants.BATTERY_LIFE_MS)
        self.lastNativeBatteryLevel=PalmPilots.Data.setBatteryLevel(self.item,self.data,
            level)
    end
    local saveNow=PalmPilots.Utils.now()
    if saveNow-(self.lastBatterySave or saveNow)>=30000 then self:save() end
    if self.data.batteryLevel<=0 then
        self.dead=true; self.screen="dead"; self:save(); return false
    end
    return true
end

function MainUI:setScreen(screen)
    if screen~="todo" or self.screen~="todo" then self.todoList=nil end
    if self.screen=="chess" and screen~="chess" then PalmPilots.ChessScreen.leave(self) end
    self.screen=screen; self.scroll=1; self.selected=nil; self.viewNote=nil; self.bodyScroll=0
    if screen~="snake" and self.snake then self.snake.running=false end
end

function MainUI:save()
    self:invalidateDataViews()
    self.lastBatterySave=PalmPilots.Utils.now()
    self.item:getModData().PalmPilots=self.data
    self.lastNativeBatteryLevel=PalmPilots.Data.setBatteryLevel(self.item,self.data,self.data.batteryLevel)
    PalmPilots.Data.updateTooltip(self.item,self.data)
    PalmPilots.Client.syncDevice(self)
end

function MainUI:beginBeam(kind,id)
    self.beamAll=nil; self.beamEntry={kind=kind,id=id}; self:setScreen("beam")
    PalmPilots.Client.listTargets(self)
end

function MainUI:showBeam()
    self.beamEntry=nil; self.beamAll=nil; self.beamTargets={}; self:setScreen("beam")
    PalmPilots.Client.listTargets(self)
end

function MainUI:s(v) return v*self.scale end
function MainUI:fill(x,y,w,h,a,r,g,b) self:drawRect(self:s(x),self:s(y),self:s(w),self:s(h),a or 1,r or Ink.r,g or Ink.g,b or Ink.b) end
function MainUI:box(x,y,w,h) self:drawRectBorder(self:s(x),self:s(y),self:s(w),self:s(h),1,Ink.r,Ink.g,Ink.b) end
function MainUI:text(value,x,y,font) self:drawText(tostring(value or ""),self:s(x),self:s(y),Ink.r,Ink.g,Ink.b,1,font or UIFont.Small) end
function MainUI:rightText(value,x,y,font) self:drawTextRight(tostring(value or ""),self:s(x),self:s(y),Ink.r,Ink.g,Ink.b,1,font or UIFont.Small) end
function MainUI:centerText(value,x,y,font) self:drawTextCentre(tostring(value or ""),self:s(x),self:s(y),Ink.r,Ink.g,Ink.b,1,font or UIFont.Small) end

function MainUI:fitText(value,maxWidth,font)
    local text=tostring(value or "")
    local textManager=getTextManager()
    font=font or UIFont.Small
    if textManager:MeasureStringX(font,text)/self.scale<=maxWidth then return text end
    local suffix="..."
    while #text>0 and textManager:MeasureStringX(font,text..suffix)/self.scale>maxWidth do
        text=string.sub(text,1,-2)
    end
    return text..suffix
end

function MainUI:title(value)
    self:fill(116,120,496,48,1,Config.colors.highlight.r,Config.colors.highlight.g,Config.colors.highlight.b)
    local font=UIFont.Medium
    local fontHeight=getTextManager():getFontHeight(font)/self.scale
    self:text(value,130,120+(48-fontHeight)/2,font); self:box(116,120,496,48)
end

function MainUI:button(label,x,y,w,h,callback)
    local entry={x=x,y=y,w=w,h=h,callback=callback}; table.insert(self.buttons,entry)
    if self.pressed and self.pressed.x==x and self.pressed.y==y and self.pressed.w==w and self.pressed.h==h then self:fill(x,y,w,h,1,0.32,0.40,0.30) else self:fill(x,y,w,h,1,0.63,0.71,0.58) end
    local font=UIFont.Small
    local fontHeight=getTextManager():getFontHeight(font)/self.scale
    self:box(x,y,w,h); self:centerText(label,x+w/2,y+(h-fontHeight)/2,font)
    return entry
end

function MainUI:pixelButton(label,x,y,w,h,callback,font)
    local entry={x=x,y=y,w=w,h=h,callback=callback}; table.insert(self.buttons,entry)
    local down=self.pressed and self.pressed.x==x and self.pressed.y==y and self.pressed.w==w and self.pressed.h==h
    local shade=down and 0.48 or 0.69
    self:fill(x+3,y+3,w-6,h-6,1,shade,shade+0.06,shade-0.03)
    self:fill(x+6,y,w-12,3)
    self:fill(x+3,y+3,3,3)
    self:fill(x,y+6,3,h-12)
    self:fill(x+3,y+h-6,3,3)
    self:fill(x+6,y+h-3,w-12,3)
    self:fill(x+w-6,y+h-6,3,3)
    self:fill(x+w-3,y+6,3,h-12)
    self:fill(x+w-6,y+3,3,3)
    local labelFont=font or UIFont.Medium
    local fontHeight=getTextManager():getFontHeight(labelFont)/self.scale
    self:centerText(label,x+w/2,y+(h-fontHeight)/2,labelFont)
    return entry
end

function MainUI:lightText(value,x,y,font)
    local color=Config.colors.lcd
    self:drawText(tostring(value or ""),self:s(x),self:s(y),color.r,color.g,color.b,1,font or UIFont.Small)
end

function MainUI:iconButton(texture,label,x,y,w,h,callback)
    local entry={x=x,y=y,w=w,h=h,callback=callback}; table.insert(self.buttons,entry)
    local down=self.pressed and self.pressed.x==x and self.pressed.y==y and self.pressed.w==w and self.pressed.h==h
    if down then self:fill(x,y,w,h,0.55,0.40,0.49,0.37) end
    local iconSize=math.min(w,h-22)
    local iconX=x+(w-iconSize)/2
    if texture then self:drawTextureScaled(texture,self:s(iconX),self:s(y),self:s(iconSize),self:s(iconSize),down and 0.75 or 1,1,1,1)
    else self:box(iconX,y,iconSize,iconSize); self:centerText("?",x+w/2,y+iconSize/2-10,UIFont.Large) end
    if label and label~="" then self:centerText(label,x+w/2,y+iconSize+2,UIFont.Small) end
    return entry
end

function MainUI:imageButton(texture,x,y,w,h,callback)
    local entry={x=x,y=y,w=w,h=h,callback=callback}; table.insert(self.buttons,entry)
    local down=self.pressed and self.pressed.x==x and self.pressed.y==y and self.pressed.w==w and self.pressed.h==h
    if down then self:fill(x-2,y-2,w+4,h+4,0.60,0.40,0.49,0.37) end
    if texture then self:drawTextureScaled(texture,self:s(x),self:s(y),self:s(w),self:s(h),down and 0.65 or 1,1,1,1)
    else self:box(x,y,w,h); self:centerText("?",x+w/2,y+h/2-10,UIFont.Medium) end
    return entry
end

function MainUI:listRow(index,y,label,selected,checked,callback,doubleCallback,detail)
    local entry=self:button("",128,y,464,42,function() self.selected=index; callback() end)
    entry.key="row:"..self.screen..":"..tostring(index)
    entry.doubleCallback=doubleCallback
    if selected then self:box(124,y-3,472,48) end
    local font=UIFont.Small
    local fontHeight=getTextManager():getFontHeight(font)/self.scale
    local textY=y+(42-fontHeight)/2
    local boxY=y+(42-18)/2
    self:box(137,boxY,18,18); if checked then self:fill(141,boxY+4,10,10) end
    local detailWidth=detail and getTextManager():MeasureStringX(font,detail)/self.scale or 0
    local shown=self:fitText(label,detail and (398-detailWidth) or 414,font)
    self:text(shown,166,textY,font)
    if detail and detail~="" then self:rightText(detail,580,textY,font) end
    if checked then
        local strikeWidth=math.min(detail and 260 or 390,
            getTextManager():MeasureStringX(font,shown)/self.scale)
        self:fill(164,textY+fontHeight/2,strikeWidth,2)
    end
end

function MainUI:plainListRow(index,y,label,selected,callback,doubleCallback,detail)
    local entry=self:button("",128,y,464,42,function() self.selected=index; callback() end)
    entry.key="row:"..self.screen..":"..tostring(self.todoList or "root")..":"..tostring(index)
    entry.doubleCallback=doubleCallback
    if selected then self:box(124,y-3,472,48) end
    local font=UIFont.Small
    local fontHeight=getTextManager():getFontHeight(font)/self.scale
    local textY=y+(42-fontHeight)/2
    local detailWidth=detail and getTextManager():MeasureStringX(font,detail)/self.scale or 0
    local shown=self:fitText(label,detail and (422-detailWidth) or 438,font)
    self:text(shown,142,textY,font)
    if detail and detail~="" then self:rightText(detail,580,textY,font) end
end

function MainUI:scrollBar(count,first,visible)
    if count<=visible then return end
    local h=400; self:box(594,190,10,h); local thumb=math.max(28,h*(visible/count)); local y=190+(h-thumb)*((first-1)/(count-visible))
    self:fill(596,y+2,6,thumb-4)
end

function MainUI:wrappedText(value,x,y,width,lineOffset,maxLines)
    local words={}; for word in tostring(value or ""):gmatch("%S+") do table.insert(words,word) end
    local lines,current={},""
    for _,word in ipairs(words) do local trial=current=="" and word or current.." "..word
        if getTextManager():MeasureStringX(UIFont.Small,trial)>self:s(width) and current~="" then table.insert(lines,current); current=word else current=trial end
    end
    if current~="" then table.insert(lines,current) end
    for i=1,maxLines do if lines[i+(lineOffset or 0)] then self:text(lines[i+(lineOffset or 0)],x,y+(i-1)*25,UIFont.Small) end end
end

function MainUI:prerender()
    self.buttons={}
    local dead=self.dead or self.data.batteryLevel<=0
    local deviceTexture=dead and self.deadTexture or self.texture
    if deviceTexture then self:drawTextureScaled(deviceTexture,0,0,self.width,self.height,1,1,1,1)
    else self:drawRect(0,0,self.width,self.height,0.95,0.16,0.18,0.16); self:drawRect(self:s(106),self:s(111),self:s(516),self:s(675),1,0.71,0.78,0.65) end
    if dead then
        -- A flat battery shows only the dead hardware artwork. The power
        -- button remains a convenient way to dismiss the otherwise inert UI.
        self:hardwareButton(Config.hardware.power,function() self:close() end)
        return
    end
    local screen=PalmPilots.HomeScreen
    if self.screen=="todo" then screen=PalmPilots.TodoScreen elseif self.screen=="memo" then screen=PalmPilots.MemoScreen
    elseif self.screen=="calculator" then screen=PalmPilots.CalculatorScreen elseif self.screen=="calendar" then screen=PalmPilots.CalendarScreen
    elseif self.screen=="snake" then screen=PalmPilots.SnakeScreen
    elseif self.screen=="chess" then screen=PalmPilots.ChessScreen
    elseif self.screen=="beam" then screen=PalmPilots.BeamScreen
    elseif self.screen=="settings" then screen=PalmPilots.SettingsScreen end
    if self.screen=="find" then screen=PalmPilots.FindScreen end
    screen.render(self)
    local hw=Config.hardware
    self:hardwareButton(hw.applications,function() self:setScreen("home") end)
    self:hardwareButton(hw.calculator,function() self:setScreen("calculator") end)
    self:hardwareButton(hw.menu,function() self:setScreen("settings") end)
    self:hardwareButton(hw.power,function() self:close() end)
    self:hardwareButton(hw.calendar,function() self:setScreen("calendar") end)
    self:hardwareButton(hw.beam,function() self:showBeam() end)
    self:hardwareButton(hw.memo,function() self:setScreen("memo") end)
    self:hardwareButton(hw.todo,function() self.todoList=nil; self:setScreen("todo") end)
    self:hardwareButton(hw.up,function() self:scrollBy(-1) end)
    self:hardwareButton(hw.down,function() self:scrollBy(1) end)
    self:hardwareButton(hw.find,function()
        if self.screen~="find" then PalmPilots.FindScreen.open(self) end
    end)
end

function MainUI:hardwareButton(rect,callback)
    local entry={x=rect.x,y=rect.y,w=rect.w,h=rect.h,callback=callback}; table.insert(self.buttons,entry)
    if self.pressed and self.pressed.x==rect.x and self.pressed.y==rect.y and self.pressed.w==rect.w and self.pressed.h==rect.h then self:drawRect(self:s(rect.x),self:s(rect.y),self:s(rect.w),self:s(rect.h),0.25,0.2,0.9,0.7) end
end

function MainUI:scrollBy(delta)
    if self.screen=="memo" and self.viewNote then self.bodyScroll=math.max(0,(self.bodyScroll or 0)+delta); return end
    local count=self.screen=="todo" and PalmPilots.TodoScreen.count(self)
        or self.screen=="memo" and #self.data.notes
        or self.screen=="beam" and PalmPilots.BeamScreen.count(self) or 0
    local visible=self.screen=="todo" and 7
        or self.screen=="beam" and PalmPilots.BeamScreen.visible(self) or 8
    self.scroll=math.max(1,math.min(math.max(1,count-visible+1),(self.scroll or 1)+delta))
end

local function hit(button,x,y) return x>=button.x and y>=button.y and x<button.x+button.w and y<button.y+button.h end
function MainUI:onMouseDown(x,y)
    x,y=x/self.scale,y/self.scale
    for _,button in ipairs(self.buttons) do if hit(button,x,y) then self.pressed=button; return true end end
    if y<=Config.dragHandleHeight then self.moving=true; self:bringToTop() end
    return true
end
function MainUI:onMouseUp(x,y)
    if self.moving then self.moving=false; self:savePosition(); return true end
    x,y=x/self.scale,y/self.scale; local pressed=self.pressed; self.pressed=nil
    if pressed and hit(pressed,x,y) then
        local now=PalmPilots.Utils.now()
        if pressed.doubleCallback and self.lastClickKey==pressed.key and now-(self.lastClickTime or 0)<=350 then
            self.lastClickKey=nil; self.lastClickTime=0; pressed.doubleCallback()
        else
            pressed.callback()
            if pressed.doubleCallback then self.lastClickKey=pressed.key; self.lastClickTime=now end
        end
    end
    return true
end
function MainUI:onMouseDoubleClick(x,y)
    x,y=x/self.scale,y/self.scale
    for _,button in ipairs(self.buttons) do
        if button.doubleCallback and hit(button,x,y) then
            self.pressed=nil; self.lastClickKey=nil; self.lastClickTime=0
            button.doubleCallback(); return true
        end
    end
    return true
end
function MainUI:moveBy(dx,dy)
    if not self.moving then return end
    local maxX=math.max(0,getCore():getScreenWidth()-self.width)
    local maxY=math.max(0,getCore():getScreenHeight()-self.height)
    self:setX(math.max(0,math.min(maxX,self:getX()+dx)))
    self:setY(math.max(0,math.min(maxY,self:getY()+dy)))
end
function MainUI:savePosition()
    self.data.uiPrefs.positionX=math.floor(self:getX())
    self.data.uiPrefs.positionY=math.floor(self:getY())
    self:save()
end
function MainUI:onMouseMove(dx,dy) self:moveBy(dx,dy); return true end
function MainUI:onMouseMoveOutside(dx,dy) self:moveBy(dx,dy); return true end
function MainUI:onMouseUpOutside() self.pressed=nil; if self.moving then self.moving=false; self:savePosition() end; return true end
function MainUI:onMouseWheel(delta) self:scrollBy(delta); return true end

function MainUI:handleKey(key)
    if key==Keyboard.KEY_ESCAPE then self:close(); return end
    if key==Keyboard.KEY_SPACE then
        -- Do not steal spaces while the player is naming a task or writing a memo.
        if not PalmPilots.Dialogs or not PalmPilots.Dialogs.hasActiveDialog() then self:close() end
        return
    end
    if self.screen=="snake" then
        if key==Keyboard.KEY_UP then PalmPilots.SnakeScreen.direction(self,0,-1)
        elseif key==Keyboard.KEY_DOWN then PalmPilots.SnakeScreen.direction(self,0,1)
        elseif key==Keyboard.KEY_LEFT then PalmPilots.SnakeScreen.direction(self,-1,0)
        elseif key==Keyboard.KEY_RIGHT then PalmPilots.SnakeScreen.direction(self,1,0) end
    end
end

-- Names exposed for skinning/extensions and documented reusable LCD primitives.
MainUI.LCDButton=MainUI.button
MainUI.PixelButton=MainUI.pixelButton
MainUI.AppIconButton=MainUI.iconButton
MainUI.ImageButton=MainUI.imageButton
MainUI.ListRow=MainUI.listRow
MainUI.PlainListRow=MainUI.plainListRow
MainUI.Checkbox=MainUI.listRow
MainUI.ScrollBar=MainUI.scrollBar
