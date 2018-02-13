import XMonad hiding ( (|||) )
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

import XMonad.Layout hiding ( (|||) )
import XMonad.Layout.LayoutCombinators
import XMonad.Layout.SimplestFloat
import XMonad.Layout.SubLayouts as SL
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
    , ("volumeUp"     , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') +5%")
    , ("volumeDown"   , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') -5%")
    , ("volumeToggle" , "pactl set-sink-mute   $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') toggle")
    , ("reloadXMonad" , "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'xmonad config reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi")
    , ("prScrAndPaste", "capture_screen_and_paste.sh | xclip -selection clipboard; notify-send 'Screen captured' \"Available in /tmp/export.png and $(xclip -o -selection clipboard) (copied to clipboard)\"")
    , ("restoreTmux"  , "for session in $(tmux list-sessions | grep -oP '^[^:]+(?!.*attached)'); do setsid urxvt -e tmux attach -t $session &\n done")
    , ("klayout"      , "feh /Storage/tmp/Ergodox-Base.png")
    ]) M.! cmd

action :: String -> X ()
action action = spawn $ longCmds action

scratchpads = [
-- TODO: More scratchpads!: System status (spawn detached on boot?), soundctl, ???
      NS "flyway"  ("urxvt -title Scratchpad-flyway -e tmux new -As flyway")
        (title =? "Scratchpad-flyway") (customFloating $ W.RationalRect (1/6) (1/6) (2/3) (2/3))
 -- , NS "wrapper" (longCmds "wrapperCmd") (title =? "Scratchpad-Wrapper") doCenterFloat
    ] where role = stringProperty "WM_WINDOW_ROLE"

-- | @q =/ x@. if the result of @q@ does not equals @x@, return 'True'.
(=/) :: Eq a => Query a -> a -> Query Bool
q =/ x = fmap(/= x) q

myManageHook :: Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
    [ title     =? "launcher" --> doCenterFloat
    , title     =? "xmessage" --> doCenterFloat
    , className =? "Pinentry" --> doCenterFloat
    , className =? "Zenity"   --> doCenterFloat
    , className =? "mpv"      --> doCenterFloat
    , className =? "Shutter"  --> doCenterFloat
    , className =? "eog"      --> doCenterFloat
    , className =? "feh"      --> doFloatAt (7/10) (1/100)
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
    -- mod-[0-9] %! Switch to workspace N
    -- mod-shift-[0-9] %! Move client to workspace N
    [((m .|. modMask, k), windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) ([xK_1 .. xK_9] ++ [xK_0])
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]
    ++
    -- mod-control-[0-9]       %! Switch to physical/Xinerama screens ...
    -- mod-control-shift-[0-9] %! Move client to screen 1, 2, or 3
    [((m .|. modMask .|. controlMask, key), screenWorkspace sc >>= flip whenJust (windows . f))
        | (key, sc) <- zip ([xK_1 .. xK_9] ++ [xK_0]) [0..]
        , (f, m) <- zip [W.view, W.shift] [0, shiftMask]]

-- Grid Select config
-- TODO: Change shown strings by something more verbose than zsh...
myGsConfig = GS.defaultGSConfig {
      GS.gs_cellheight = 75
    , GS.gs_cellwidth = 350
}

layoutAlgorithms = tiled ||| Full ||| Mirror tiled ||| simplestFloat where
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
-- Boring windows fait n'importe quoi avec le floating...
                       $ windowNavigation $ subTabbed $ boringWindows
                       -- ^ Grouping mechanisms + tabs on sublayouts + skip hidden windows.
                       $ smartBorders
                       $ layoutAlgorithms

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
          ("M-C-S-<Return>"  , action "launcher")
        , ("M-C-<Return>"    , action "ulauncher")
        , ("M-<Return>"      , spawn "urxvt -e tmux")
        , ("M-S-c"           , action "prScrAndPaste")
        , ("M-S-x"           , spawn "xtrlock-pam")                         -- %! Lock the screen
        , ("M-<F4>"          , kill)                                  -- %! Close the focused window
        , ("M-S-g"           , withFocused $ windows . flip W.float (W.RationalRect (1/6) (1/6) (2/3) (2/3)))
                                                                      -- %! Push window up to floating
        , ("M-S-f"           , withFocused $ windows . W.sink)        -- %! Push window back into tiling

        , ("M-n"             , refresh)                               -- %! Check if this can force a texture update to the window

        , ("M-b"             , sendMessage ToggleStruts)              -- %! Shrink the master area

        , ("M-C-h"           , sendMessage $ pullGroup L)             -- %! Move window to the left subgroup
        , ("M-C-j"           , sendMessage $ pullGroup D)             -- %! Move window to the down subgroup
        , ("M-C-k"           , sendMessage $ pullGroup U)             -- %! Move window to the up subgroup
        , ("M-C-l"           , sendMessage $ pullGroup R)             -- %! Move window to the right subgroup

        , ("M-S-p"           , withFocused $ sendMessage . MergeAll)  -- %! Merge focused windows into a subgroup
        , ("M-p"             , withFocused $ sendMessage . UnMerge)   -- %! Unmerge a subgroup into windows

        -- v These work even in sublayouts.
        , ("M-S-k"           , windows W.swapUp)                      -- %! Swap the focused window with the previous window
        , ("M-S-j"           , windows W.swapDown)                    -- %! Swap the focused window with the next window
        -- v These will skip hidden windows
        , ("M-k"             , focusUp)                               -- %! Move focus to the previous window
        , ("M-j"             , focusDown)                             -- %! Move focus to the next window
        , ("M-S-<Tab>"       , focusUp)                               -- %! Move focus to the previous window
        , ("M-<Tab>"         , focusDown)                             -- %! Move focus to the next window
        -- v These will not skip windows, thus effectively changing sublayout windows.
        , ("M-M1-k"          , windows W.focusUp)                     -- %! Move focus to the previous window
        , ("M-M1-j"          , windows W.focusDown)                   -- %! Move focus to the next window

        , ("M-h"             , sendMessage Shrink)                    -- %! Shrink the master area
        , ("M-l"             , sendMessage Expand)                    -- %! Expand the master area
        , ("M-,"             , sendMessage (IncMasterN 1))            -- %! Increment the number of windows in the master area
        , ("M-."             , sendMessage (IncMasterN (-1)))         -- %! Deincrement the number of windows in the master area
        , ("M-<Space>"       , sendMessage NextLayout)                -- %! Rotate through the available layout algorithms
        , ("M-C-S-<Tab>"     , windows W.swapMaster)                  -- %! Swap the focused window and the master window
        , ("M-C-<Tab>"       , windows W.focusMaster)                 -- %! Move focus to the master window

    -- TODO: Extract bindings shared by toSubl and sendMessage into another array and "compile" the both layouts...
    -- TODO: Include v in ^
        , ("M-a"             , sendMessage $ JumpToLayout "Tall")          -- %! Jump directly to layout
        , ("M-s"             , sendMessage $ JumpToLayout "Full")          -- %! Jump directly to layout
        , ("M-d"             , sendMessage $ JumpToLayout "Mirror Tall")   -- %! Jump directly to layout
        , ("M-f"             , sendMessage $ JumpToLayout "SimplestFloat") -- %! Jump directly to layout

        , ("M-M1-h"          , toSubl Shrink)                         -- %! Shrink the master area
        , ("M-M1-l"          , toSubl Expand)                         -- %! Expand the master area
        , ("M-M1-,"          , toSubl (IncMasterN 1))                 -- %! Increment the number of windows in the master area
        , ("M-M1-."          , toSubl (IncMasterN (-1)))              -- %! Deincrement the number of windows in the master area
        , ("M-M1-<Space>"    , toSubl NextLayout)                     -- %! Rotate through the available layout algorithms
     -- , ("M-M1-k"          , onGroup W.focusUp')                    -- %! Focus up window inside subgroup
     -- , ("M-M1-j"          , onGroup W.focusDown')                  -- %! Focus down window inside subgroup
        , ("M-M1-<Tab>"      , onGroup focusMaster')                  -- %! Focus down window inside subgroup
        , ("M-M1-S-<Tab>"    , onGroup swapMaster')                   -- %! Swap the focused window and the master window

        , ("M-S-q"           , io (exitWith ExitSuccess))             -- %! Quit xmonad
        , ("M-q"             , action "reloadXMonad")                 -- %! Reload xmonad

        -- Consider using mod4+shift+{button1,button2} for prev, next workspace.

        -- I need to learn my new keyboard layout ^^
        , ("M-S-r"                , action "klayout")
        , ("M-S-t"                , action "restoreTmux")

        -- Scratchpads!
        , ("M-S-w"                     , namedScratchpadAction scratchpads "flyway")
        , ("M-w"                       , spawn "tmux detach-client -s flyway") -- "hide" flyway

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

        , ("<XF86MonBrightnessUp>"     , spawn "xbacklight -inc 10")
        , ("<XF86MonBrightnessDown>"   , spawn "xbacklight -dec 10")
        , ("C-<XF86AudioRaiseVolume>"  , spawn "xbacklight -inc 10")
        , ("C-<XF86AudioLowerVolume>"  , spawn "xbacklight -dec 10")

        , ("M-<KP_Prior>"              , spawn "redshift -O 2000K")
        , ("M-<KP_Right>"              , spawn "redshift -O 6500K")


        , ("M-S-'"                     , GS.goToSelected myGsConfig)
        ]
        where
         -- <Copied from SubLayout.hs...>
         -- should these go into XMonad.StackSet?
         focusMaster' st = let (f:fs) = W.integrate st in W.Stack f [] fs
         swapMaster' (W.Stack f u d) = W.Stack f [] $ reverse u ++ d
         -- </Copied from SubLayout.hs...>


myPP = xmobarPP { ppCurrent = xmobarColor "#429942" "" . wrap "<" ">" }

-- Key binding to toggle the gap for the bar.
toggleStrutsKey XConfig {XMonad.modMask = modMask} = (modMask, xK_b)

main = xmonad =<< statusBar "xmobar" myPP toggleStrutsKey myConfig

-- vim: expandtab
