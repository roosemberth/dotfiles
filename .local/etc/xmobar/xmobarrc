Config {
      font               = "xft:Deja Vu Sans Mono:pixelsize=18"
    , bgColor            = "black"
    , fgColor            = "grey"
    , position           = TopW L 100
    , hideOnStart        = False
    , allDesktops        = True
    , overrideRedirect   = True
    , pickBroadest       = False
    , persistent         = True
    , alignSep           = "}{"
    , commands =
        [ Run BatteryP ["BAT0"]
            [ "--template", "<acstatus>"
            , "--Low"     , "10"
            , "--High"    , "80"
            , "--low"     , "red"
            , "--normal"  , "darkorange"
            , "--high"    , "darkgreen"
            , "-f"        , "AC/online"
            , "--"
                , "-o"  , "<left> (<timeleft>)"
                , "-O"  , "<fc=#dAA520>Charging (<left>)</fc>"
                , "-i"  , "<fc=orange>Charged</fc>"
            ] 60
        , Run DiskU [("/", "▣:<free>"), ("/home", "▣:<free>")]
            [ "--Low"   , "10"
            , "--High"  , "50"
            , "--low"   , "red"
            , "--high"  , "darkgreen"
            ] 100
        , Run Network "wlp4s0"
            [ "--template" , "☫<tx>▲<rx>▼"
            , "-S"         , "True"       -- Show units
            , "-m"         , "6"
            , "--Low"      , "0"          -- units: B/s
            , "--High"     , "1048576"    -- units: B/s
            , "--low"      , "darkred"
            , "--normal"   , "darkgreen"
            , "--high"     , "darkorange"
            ] 25
        , Run Network "enp0s31f6"
            [ "--template" , "|↯<tx>▲<rx>▼"
            , "-S"         , "True"       -- Show units
            , "-m"         , "6"
            , "--Low"      , "0"          -- units: B/s
            , "--High"     , "1048576"    -- units: B/s
            , "--low"      , "darkred"
            , "--normal"   , "darkgreen"
            , "--high"     , "darkorange"
            ] 20
        , Run MultiCpu
            [ "--template" , ":<total0>%|<total1>%|<total2>%|<total3>%|<total4>%|<total5>%|<total6>%|<total7>%"
            , "-m"         , "2"
            , "--Low"      , "40"         -- units: %
            , "--High"     , "85"         -- units: %
            , "--low"      , "darkgreen"
            , "--normal"   , "darkred"
            , "--high"     , "darkorange"
            ] 10
        , Run CoreTemp
            [ "--template" , "<core0>°C"
            , "-m"         , "2"
            , "--Low"      , "70"        -- units: °C
            , "--High"     , "80"        -- units: °C
            , "--low"      , "darkgreen"
            , "--normal"   , "red"
            , "--high"     , "darkorange"
            ] 50
        , Run Memory
            [ "--template" ,"Mem: <usedratio>%"
            , "--Low"      , "20"        -- units: %
            , "--High"     , "90"        -- units: %
            , "--low"      , "darkgreen"
            , "--normal"   , "darkorange"
            , "--high"     , "darkred"
            ] 10
        , Run Com "sh" ["-c", "awk '{print $1, $2, $3 }' /proc/loadavg"] "loadavg" 10
        , Run Com "sh" ["-c", "hostname"] "hostname" 600
        , Run Com "sh" ["-c", "ip route | grep -oP 'default.*via \\K[^ ]+' | tr '\\n' '|'"] "intip" 50
        , Run Com "sh" ["-c", "mpc | head -n -2 | sed 's,.*/,,' | cut -c-40"] "mpd" 50
        , Run Com "sh" ["-c", "timew :yes get dom.active.{duration,tag.1,tag.2} 2>/dev/null || echo None"] "task" 50
        , Run Com "sh" ["-c", "xset q | grep 'Screen Saver' -A 2 | grep -oP 'timeout: *\\K[^ ]+'"] "screentimeout" 5
        , Run Date "%a %b %_d %Y <fc=#ee9a00>%H:%M:%S</fc>" "date" 10
        , Run StdinReader
        ]
    , template = "%task% -- %StdinReader% -- %mpd% } %wlp2s0%%enp0s31f6% { |%intip%|%loadavg%|%multicpu%|%coretemp%|%memory%| %disku% | ☽ %screentimeout% | %battery% ><fc=#d6d68f>%date%</fc>"
}
-- vim: set filetype=haskell :
