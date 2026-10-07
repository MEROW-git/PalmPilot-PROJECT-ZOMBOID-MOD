require "PalmPilots/PalmPilotConstants"

PalmPilots.UIConfig = {
    image = "media/ui/PalmPilot/PalmPilot_Device.png",
    deadImage = "media/ui/PalmPilot/Die_PalmPilot_Device.png",
    imageWidth = 717,
    imageHeight = 1031,
    -- The device is capped at 62% of screen height. Change this to 0.55-0.75
    -- to make it smaller or larger without resizing the source PNG.
    maxScreenHeightRatio = 0.62,
    dragHandleHeight = 105,
    lcd = { x=106, y=111, w=516, h=675 },
    content = { x=124, y=132, w=480, h=622 },
    appIcons = {
        todo="media/ui/PalmPilot/app icon/Icon_Todo.png",
        memo="media/ui/PalmPilot/app icon/Icon_Memo.png",
        calculator="media/ui/PalmPilot/app icon/Icon_Calc.png",
        calendar="media/ui/PalmPilot/app icon/Icon_Calender.png",
        snake="media/ui/PalmPilot/app icon/Icon_Snake.png",
        chess="media/ui/PalmPilot/app icon/Icon_Chess.png",
        beam="media/ui/PalmPilot/app icon/Icon_Beam.png",
        settings="media/ui/PalmPilot/app icon/Icon_Setting.png",
    },
    batteryIcons = {
        critical="media/ui/PalmPilot/battery icon/icon_5.png",
        low="media/ui/PalmPilot/battery icon/icon_25.png",
        half="media/ui/PalmPilot/battery icon/icon_50.png",
        high="media/ui/PalmPilot/battery icon/icon_75.png",
        full="media/ui/PalmPilot/battery icon/icon_100.png",
    },
    snakeArrows = {
        up="media/ui/PalmPilot/arrow_key/up_key.png",
        down="media/ui/PalmPilot/arrow_key/down_key.png",
        left="media/ui/PalmPilot/arrow_key/left_key.png",
        right="media/ui/PalmPilot/arrow_key/right_key.png",
    },
    hardware = {
        applications={x=124,y=608,w=62,h=54}, calculator={x=548,y=608,w=62,h=54},
        -- Menu opens device settings; Find opens list sorting and filtering.
        menu={x=124,y=706,w=62,h=54}, find={x=548,y=706,w=62,h=54},
        power={x=26,y=854,w=44,h=67}, calendar={x=105,y=845,w=72,h=76},
        beam={x=219,y=845,w=72,h=76}, todo={x=435,y=845,w=72,h=76},
        memo={x=550,y=845,w=72,h=76}, up={x=326,y=846,w=78,h=45},
        down={x=326,y=909,w=78,h=45},
    },
    colors = {
        lcd={r=0.71,g=0.78,b=0.65,a=0.96}, ink={r=0.08,g=0.13,b=0.09,a=1},
        mid={r=0.25,g=0.32,b=0.24,a=1}, highlight={r=0.50,g=0.60,b=0.46,a=1},
    },
}
