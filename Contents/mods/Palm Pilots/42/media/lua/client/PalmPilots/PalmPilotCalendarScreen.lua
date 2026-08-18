PalmPilots.CalendarScreen = PalmPilots.CalendarScreen or {}

-- Gregorian weekday, returned as 0=Sunday through 6=Saturday.
local function weekday(year, month, day)
    local offsets = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
    if month < 3 then year = year - 1 end
    return (year + math.floor(year / 4) - math.floor(year / 100) +
        math.floor(year / 400) + offsets[month] + day) % 7
end

local function changeMonth(ui, delta)
    local month = (ui.calendarMonth or 0) + delta
    local year = ui.calendarYear or getGameTime():getYear()
    while month < 0 do month = month + 12; year = year - 1 end
    while month > 11 do month = month - 12; year = year + 1 end
    ui.calendarMonth = month
    ui.calendarYear = year
    ui.calendarFollowingToday = false
end

local function showToday(ui)
    local gameTime = getGameTime()
    ui.calendarMonth = gameTime:getMonth()
    ui.calendarYear = gameTime:getYear()
    ui.calendarFollowingToday = true
end

function PalmPilots.CalendarScreen.render(ui)
    ui:title(getText("UI_PalmPilots_Calendar"))

    local gameTime = getGameTime()
    local currentYear = gameTime:getYear()
    local currentMonthZero = gameTime:getMonth()
    local currentDay = gameTime:getDay() + 1
    if ui.calendarFollowingToday == nil then ui.calendarFollowingToday = true end
    if ui.calendarFollowingToday then
        ui.calendarYear = currentYear
        ui.calendarMonth = currentMonthZero
    end

    local year = ui.calendarYear
    local monthZero = ui.calendarMonth
    local month = monthZero + 1
    local monthName = getText("UI_PalmPilots_Month_" .. tostring(month))
    local todayMonthName = getText("UI_PalmPilots_Month_" .. tostring(currentMonthZero + 1))

    ui:text(monthName .. " " .. tostring(year), 132, 180, UIFont.Medium)
    ui:rightText(PalmPilots.Utils.formatGameClock(gameTime),592,183,UIFont.Small)
    ui:fill(128, 216, 464, 2)

    local gridX, gridY = 128, 235
    local cellW, cellH = 66, 46
    for column = 0, 6 do
        ui:centerText(getText("UI_PalmPilots_Weekday_" .. tostring(column + 1)),
            gridX + column * cellW + cellW / 2, 225, UIFont.Small)
    end

    local firstWeekday = weekday(year, month, 1)
    local daysInMonth = gameTime:daysInMonth(year, monthZero)
    for date = 1, daysInMonth do
        local slot = firstWeekday + date - 1
        local column = slot % 7
        local row = math.floor(slot / 7)
        local x = gridX + column * cellW
        local y = gridY + row * cellH

        if year == currentYear and monthZero == currentMonthZero and date == currentDay then
            ui:fill(x + 3, y + 3, cellW - 6, cellH - 6, 1, 0.50, 0.60, 0.46)
            ui:box(x + 3, y + 3, cellW - 6, cellH - 6)
        end
        ui:centerText(tostring(date), x + cellW / 2, y + 12, UIFont.Small)
    end

    ui:fill(128, 515, 464, 2)
    ui:centerText(getText("UI_PalmPilots_Today") .. ": " .. todayMonthName .. " " ..
        tostring(currentDay) .. ", " .. tostring(currentYear), 360, 527, UIFont.Small)
    ui:button(getText("UI_PalmPilots_Previous"),125,555,100,34,
        function() changeMonth(ui,-1) end)
    ui:button(getText("UI_PalmPilots_Today"),231,555,100,34,
        function() showToday(ui) end)
    ui:button(getText("UI_PalmPilots_Next"),337,555,100,34,
        function() changeMonth(ui,1) end)
    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,
        function() ui:setScreen("home") end)
end
