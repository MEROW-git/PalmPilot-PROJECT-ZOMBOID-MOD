PalmPilots.CalculatorScreen = PalmPilots.CalculatorScreen or {}
local S = PalmPilots.CalculatorScreen

function S.reset(ui)
    ui.calc={display="0",stored=nil,operator=nil,newNumber=true,error=false}
end

local function number(ui, value)
    local c=ui.calc; if c.error then S.reset(ui); c=ui.calc end
    if c.newNumber then c.display=value=="." and "0." or value; c.newNumber=false
    elseif value=="." then if not string.find(c.display,".",1,true) then c.display=c.display.."." end
    elseif #c.display<14 then c.display=(c.display=="0" and value or c.display..value) end
end

local function calculate(c)
    if not c.operator or c.stored==nil then return true end
    local rhs=tonumber(c.display) or 0; local result
    if c.operator=="+" then result=c.stored+rhs elseif c.operator=="-" then result=c.stored-rhs
    elseif c.operator=="*" then result=c.stored*rhs elseif rhs==0 then c.display=getText("UI_PalmPilots_DivZero"); c.error=true; return false
    else result=c.stored/rhs end
    c.display=tostring(math.floor(result)==result and math.floor(result) or result)
    if #c.display>14 then c.display=string.format("%.7g",result) end
    return true
end

local function press(ui,key)
    local c=ui.calc
    if string.find("0123456789",key,1,true) or key=="." then number(ui,key)
    elseif key=="C" then S.reset(ui)
    elseif key=="BS" then if not c.newNumber and not c.error then c.display=#c.display>1 and string.sub(c.display,1,-2) or "0" end
    elseif key=="NEG" then if not c.error and tonumber(c.display) then c.display=tostring(-(tonumber(c.display))) end
    elseif key=="=" then if calculate(c) then c.operator=nil; c.stored=nil; c.newNumber=true end
    else if not c.error then if c.operator and not c.newNumber then calculate(c) end; c.stored=tonumber(c.display) or 0; c.operator=key; c.newNumber=true end end
end

function S.key(ui,key) press(ui,key) end

function S.render(ui)
    if not ui.calc then S.reset(ui) end
    ui:title(getText("UI_PalmPilots_Calculator"))

    ui:fill(132,183,452,66,1,0.67,0.74,0.62)
    ui:fill(132,183,452,3); ui:fill(132,246,452,3)
    ui:fill(132,183,3,66); ui:fill(581,183,3,66)
    ui:rightText(ui.calc.display,566,196,UIFont.Large)

    -- Editing controls stay together above the keypad instead of occupying
    -- the application title bar.
    ui:pixelButton("+/-",140,260,130,40,function() press(ui,"NEG") end,UIFont.Medium)
    ui:pixelButton("<",294,260,130,40,function() press(ui,"BS") end,UIFont.Medium)
    ui:pixelButton("C",448,260,130,40,function() press(ui,"C") end,UIFont.Medium)

    local rows={
        {{"7","7"},{"8","8"},{"9","9"}},
        {{"4","4"},{"5","5"},{"6","6"}},
        {{"1","1"},{"2","2"},{"3","3"}},
    }
    local xs={140,294,448}
    for row,values in ipairs(rows) do
        for col,definition in ipairs(values) do
            local label,key=definition[1],definition[2]
            ui:pixelButton(label,xs[col],310+(row-1)*50,130,44,function() press(ui,key) end,UIFont.Large)
        end
    end

    ui:pixelButton("0",140,460,284,44,function() press(ui,"0") end,UIFont.Large)
    ui:pixelButton(".",448,460,130,44,function() press(ui,".") end,UIFont.Large)

    -- All arithmetic operators form one dedicated row below the numbers.
    local operators={{"+","+"},{"-","-"},{"X","*"},{"/","/"},{"=","="}}
    local operatorX={132,224,316,408,500}
    for index,definition in ipairs(operators) do
        local label,key=definition[1],definition[2]
        ui:pixelButton(label,operatorX[index],510,84,40,function() press(ui,key) end,UIFont.Large)
    end

    ui:button(getText("UI_PalmPilots_Back"),483,555,82,34,function() ui:setScreen("home") end)
end
