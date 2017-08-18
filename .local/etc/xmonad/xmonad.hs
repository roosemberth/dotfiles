import XMonad
import XMonad.Util.EZConfig(additionalKeysP)

import System.Exit

import Data.String (String)
import qualified Data.Map as M
import qualified Data.Monoid(Endo, All)

import qualified XMonad.StackSet as W
import qualified XMonad.Actions.GridSelect as GS

import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.DynamicLog
import XMonad.Util.NamedScratchpad

import XMonad.Layout
import XMonad.Layout.SubLayouts
import XMonad.Layout.WindowNavigation
import XMonad.Layout.BoringWindows
import XMonad.Layout.NoBorders
--import XMonad.Layout.Simplest
--import XMonad.Layout.Circle

-- Contains long complicated shell commands used all over the config.
longCmds :: String -> String
longCmds cmd = (M.fromList $ [
      ("launcher"     , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 170x10 -title launcher -e zsh")
    , ("ulauncher"    , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 120x10 -title launcher -e zsh")
    , ("wrapperCmd"   , "urxvt -title Scratchpad-Wrapper -geometry 425x113 -fn \"xft:dejavu sans mono:size=12:antialias=false\" -e tmuxinator start wrapper")
    , ("volumeUp"     , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') +5%")
    , ("volumeDown"   , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') -5%")
    , ("volumeToggle" , "pactl set-sink-mute   $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') toggle")
    , ("reloadXMonad" , "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'xmonad config reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi")
    , ("prScrAndPaste", "capture_screen_and_paste.sh | xclip -selection clipboard; notify-send 'Screen captured' \"Available in /tmp/export.png and $(xclip -o -selection clipboard) (copied to clipboard)\"")
    ]) M.! cmd

action :: String -> X ()
action action = spawn $ longCmds action

scratchpads =
    [
-- TODO: Split wrapper into multiple scratchpads!
      NS "wrapper" (longCmds "wrapperCmd") (title =? "Scratchpad-Wrapper") doCenterFloat
--  , NS "stardict" "stardict" (className =? "Stardict") (customFloating $ W.RationalRect (1/6) (1/6) (2/3) (2/3))
    ] where role = stringProperty "WM_WINDOW_ROLE"

-- | @q =/ x@. if the result of @q@ does not equals @x@, return 'True'.
(=/) :: Eq a => Query a -> a -> Query Bool
q =/ x = fmap(/= x) q

myManageHook :: Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
    [ title     =? "launcher" --> doCenterFloat
    , title     =? "xmessage" --> doCenterFloat
    , className =? "Zenity"   --> doCenterFloat
    , className =? "mpv"      --> doCenterFloat
    , className =? "Shutter"  --> doCenterFloat
    , className =? "eog"      --> doCenterFloat
    , className =? "Gvncviewer" --> doCenterFloat
    , className =? "Gajim"   <&&> role =? "roster"    --> doFloatAt (3000/3480) (104/2160)
    , className =? "Gajim"   <&&> role =? "messages"  --> doFloatAt (2000/3480) (550/2160)
    , className =? "Gajim"    --> doCenterFloat
    , className =? "Firefox" <&&> role =/ "browser"   --> doCenterFloat
    , title     =? ".*float.*"--> doCenterFloat
    , isFullscreen            --> doFullFloat -- Maybe whitelist fullscreen-allowed applications?
    , namedScratchpadManageHook scratchpads
    , manageDocks
    ] where role = stringProperty "WM_WINDOW_ROLE"

myKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@(XConfig {XMonad.modMask = modMask}) = M.fromList $
    -- mod-[1..9] %! Switch to workspace N
    -- mod-shift-[1..9] %! Move client to workspace N
    [((m .|. modMask, k), windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) ([xK_1 .. xK_9] ++ [xK_0])
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]
    ++
    -- mod-{w,e,r} %! Switch to physical/Xinerama screens 1, 2, or 3
    -- mod-shift-{w,e,r} %! Move client to screen 1, 2, or 3
    [((m .|. modMask, key), screenWorkspace sc >>= flip whenJust (windows . f))
        | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..]
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]

-- Grid Select config
-- TODO: Change shown strings by something more verbose than zsh...
myGsConfig = GS.defaultGSConfig {
      GS.gs_cellheight = 25
    , GS.gs_cellwidth = 150
}

defaultLayout = tiled ||| Mirror tiled ||| Full where
     -- default tiling algorithm partitions the screen into two panes
     tiled   = Tall nmaster delta ratio
     -- The default number of windows in the master pane
     nmaster = 1
     -- Default proportion of screen occupied by master pane
     ratio   = 1/2
     -- Percent of screen to increment by when resizing panes
     delta   = 3/100

-- Subtabbing Layouts
myLayout = avoidStruts $ lessBorders OnlyFloat
--                       $ windowNavigation $ boringWindows
-- Boring windows fait n'importe quoi avec le floating...
--                       $ subLayout [0,1,2] (layoutHook defaultConfig)
                       $ defaultLayout

-- no boring windows
doFocusUp   = windows W.focusUp
doFocusDown = windows W.focusDown
-- boring windows
--doFocusUp   = focusUp
--doFocusDown = focusDown

myConfig = defaultConfig
        { borderWidth        = 1
        , terminal           = "urxvt -e tmux"
        , normalBorderColor  = "#1b1b2e"
        , focusedBorderColor = "#ff0000"
        , focusFollowsMouse  = False
        , modMask            = mod4Mask
        , keys               = myKeys
        , handleEventHook    = fullscreenEventHook
        , manageHook         = myManageHook <+> manageHook defaultConfig
        , layoutHook         = myLayout
        } `additionalKeysP` [
          ("M-C-<Return>"    , action "launcher")
        , ("M-C-S-<Return>"  , action "ulauncher")
        , ("M-<Return>"      , spawn "urxvt -e tmux")
        , ("M-S-a"           , spawn "xtrlock")                       -- %! Lock the screen
        , ("M-<F4>"          , kill)                                  -- %! Close the focused window
        , ("M-S-c"           , kill)                                  -- %! Close the focused window
        , ("M-f"             , withFocused $ windows . W.sink)        -- %! Push window back into tiling
        , ("M-t"             , withFocused $ windows . W.sink)        -- %! Push window back into tiling

        , ("M-n"             , refresh)                               -- %! Resize viewed windows to the correct size

        , ("M-k"             , doFocusUp)                             -- %! Move focus to the previous window
        , ("M-j"             , doFocusDown)                           -- %! Move focus to the next window
        , ("M-a"             , windows W.focusMaster)                 -- %! Move focus to the master window
        , ("M-b"             , sendMessage ToggleStruts)              -- %! Shrink the master area

        , ("M-C-h"           , sendMessage $ pullGroup L)             -- %! Move window to the left subgroup
        , ("M-C-j"           , sendMessage $ pullGroup D)             -- %! Move window to the down subgroup
        , ("M-C-k"           , sendMessage $ pullGroup U)             -- %! Move window to the up subgroup
        , ("M-C-l"           , sendMessage $ pullGroup R)             -- %! Move window to the right subgroup

        , ("M-u"             , withFocused $ sendMessage . MergeAll)  -- %! Merge focused windows into a subgroup
        , ("M-p"             , withFocused $ sendMessage . UnMerge)   -- %! Unmerge a subgroup into windows
        , ("M-i"             , onGroup W.focusUp'  )                  -- %! Focus up window inside subgroup
        , ("M-o"             , onGroup W.focusDown')                  -- %! Focus down window inside subgroup

--        , ("M-S-<Space>"     , windows W.swapMaster)                  -- %! Swap the focused window and the master window
        , ("M-S-j"           , windows W.swapDown  )                  -- %! Swap the focused window with the next window
        , ("M-S-k"           , windows W.swapUp    )                  -- %! Swap the focused window with the previous window

        , ("M-S-h"           , toSubl Shrink)                         -- %! Shrink the master area
        , ("M-S-l"           , toSubl Expand)                         -- %! Expand the master area
        , ("M-S-,"           , toSubl (IncMasterN 1))                 -- %! Increment the number of windows in the master area
        , ("M-S-."           , toSubl (IncMasterN (-1)))              -- %! Deincrement the number of windows in the master area
        , ("M-S-<Space>"     , toSubl NextLayout)                     -- %! Rotate through the available layout algorithms

        -- FIXME!
        -- Workaround: toSubl won't call sendMessage if window is not in a sublayout.
        , ("M-h"             , sendMessage Shrink)                    -- %! Shrink the master area
        , ("M-l"             , sendMessage Expand)                    -- %! Expand the master area
        , ("M-,"             , sendMessage (IncMasterN 1))            -- %! Increment the number of windows in the master area
        , ("M-."             , sendMessage (IncMasterN (-1)))         -- %! Deincrement the number of windows in the master area
        , ("M-<Space>"       , sendMessage NextLayout)                -- %! Rotate through the available layout algorithms

        , ("M-S-q"           , io (exitWith ExitSuccess))             -- %! Quit xmonad
        , ("M-q"             , action "reloadXMonad")                 -- %! Reload xmonad

        , ("M-S-s"           , action "prScrAndPaste")

        -- Consider using mod4+shift+{button1,button2} for prev, next workspace.
        -- Scratchpads!
        , ("M-M1-e"                    , namedScratchpadAction scratchpads "wrapper")

        , ("S-<XF86AudioRaiseVolume>"  , action "volumeUp")
        , ("S-<XF86AudioLowerVolume>"  , action "volumeDown")
        , ("S-<XF86AudioMute>"         , action "volumeToggle")

        , ("<XF86AudioMicMute>"        , spawn "mpc toggle")
        , ("<XF86AudioMute>"           , spawn "mpc toggle")
        , ("S-<XF86AudioPlay>"         , spawn "mpc toggle")
        , ("M1-<XF86AudioRaiseVolume>" , spawn "mpc next")
        , ("M1-<XF86AudioLowerVolume>" , spawn "mpc prev")
        , ("<XF86AudioNext>"           , spawn "mpc next")
        , ("<XF86AudioPrev>"           , spawn "mpc prev")

        , ("<XF86MonBrightnessUp>"     , spawn "backlight +10")
        , ("<XF86MonBrightnessDown>"   , spawn "backlight -10")
        , ("C-<XF86AudioRaiseVolume>"  , spawn "backlight +10")
        , ("C-<XF86AudioLowerVolume>"  , spawn "backlight -10")
        , ("M-S-'"                     , GS.goToSelected myGsConfig)
        ]


-- Custom PP, configure it as you like. It determines what is being written to the bar.
myPP = xmobarPP { ppCurrent = xmobarColor "#429942" "" . wrap "<" ">" }

-- Key binding to toggle the gap for the bar.
toggleStrutsKey XConfig {XMonad.modMask = modMask} = (modMask, xK_b)

main = xmonad =<< statusBar "xmobar" myPP toggleStrutsKey myConfig
-- vim: expandtab
