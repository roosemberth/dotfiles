{-# LANGUAGE DeriveDataTypeable #-}
import XMonad hiding ( (|||) )
import XMonad.Util.EZConfig(mkKeymap)

import System.Exit

import Data.List (isInfixOf, nub)
import Data.String (String)
import qualified Data.Map as M
import qualified Data.Monoid(Endo, All)

import qualified XMonad.Actions.GridSelect as GS
import qualified XMonad.Actions.DynamicWorkspaces as DW
import qualified XMonad.Prompt as PT
import qualified XMonad.Prompt.Window as PTW
import qualified XMonad.StackSet as W
import XMonad.Actions.CycleRecentWS

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


autoremoveEmptyWorkspaces :: [(a, X ())] -> [(a, X ())]
autoremoveEmptyWorkspaces = map fp
  where fp (keys, action) = (keys, DW.removeEmptyWorkspaceAfter action)

myKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@(XConfig {XMonad.modMask = modMask}) =
    M.fromList (
    -- mod-[0-9] %! Switch to workspace N
    -- mod-shift-[0-9] %! Move client to workspace N
    autoremoveEmptyWorkspaces (
      [((m .|. modMask, k), DW.withNthWorkspace f n)
          | (n, k) <- zip [0..] ([xK_1 .. xK_9] ++ [xK_0])
          , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]
    )
    ++
    -- mod-control-[0-9]       %! Switch to physical/Xinerama screens ...
    -- mod-control-shift-[0-9] %! Move client to screen 1, 2, or 3
    [((m .|. modMask .|. controlMask, k), (screenWorkspace n >>= flip whenJust (windows . f)))
        | (n, k) <- zip [0..] ([xK_1 .. xK_9] ++ [xK_0])
        , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    ) `M.union` mkKeymap conf (
    ( autoremoveEmptyWorkspaces
      [ ("M-<Escape>"      , DW.selectWorkspace myXPconfig)
      , ("M-<Backspace>"   , DW.addWorkspace "home")
      , ("M-t"             , DW.addWorkspace "temp")
      , ("M-S-="           , DW.addWorkspacePrompt myXPconfig)
      ]
    ) ++ (
      [ ("M-C-S-<Return>"  , action "launcher")
      , ("M-C-<Return>"    , action "ulauncher")
      , ("M-<Return>"      , spawn "urxvt -e tmux")
      , ("M-S-c"           , action "prScrAndPaste")
      , ("M-<F4>"          , kill)                                  -- %! Close the focused window
      , ("M-f"             , withFocused $ windows . flip W.float (W.RationalRect (1/6) (1/6) (2/3) (2/3)))
                                                                    -- %! Push window up to floating
      , ("M-S-f"           , withFocused $ windows . W.sink)        -- %! Push window back into tiling

      , ("M-<F2>"          , DW.renameWorkspace myXPconfig)
      , ("M-g"             , DW.withWorkspace myXPconfig (windows . W.shift))

      , ("M-n"             , refresh)                               -- %! Check if this can force a texture update to the window

      , ("M-b"             , sendMessage ToggleStruts)              -- %! Shrink the master area

      , ("M-M1-h"          , sendMessage $ pullGroup L)             -- %! Move window to the left subgroup
      , ("M-M1-j"          , sendMessage $ pullGroup D)             -- %! Move window to the down subgroup
      , ("M-M1-k"          , sendMessage $ pullGroup U)             -- %! Move window to the up subgroup
      , ("M-M1-l"          , sendMessage $ pullGroup R)             -- %! Move window to the right subgroup

      , ("M-S-p"           , withFocused $ sendMessage . MergeAll)  -- %! Merge focused windows into a subgroup
      , ("M-p"             , withFocused $ sendMessage . UnMerge)   -- %! Unmerge a subgroup into windows

      , ("M-<Tab>"         , cycleRecentWS [xK_Super_L] xK_Tab xK_grave)
      , ("M-w l"           , PTW.windowPrompt myXPconfig PTW.Goto PTW.allWindows)

      -- v These work even in sublayouts.
      , ("M-S-k"           , windows W.swapUp)                      -- %! Swap the focused window with the previous window
      , ("M-S-j"           , windows W.swapDown)                    -- %! Swap the focused window with the next window
      -- v These will skip hidden windows
      , ("M-k"             , focusUp)                               -- %! Move focus to the previous window
      , ("M-j"             , focusDown)                             -- %! Move focus to the next window
      , ("M-S-<Tab>"       , focusUp)                               -- %! Move focus to the previous window
      , ("M-<Tab>"         , focusDown)                             -- %! Move focus to the next window
      -- v These will not skip windows, thus effectively changing sublayout windows.
      , ("M-C-k"           , windows W.focusUp)                     -- %! Move focus to the previous window
      , ("M-C-j"           , windows W.focusDown)                   -- %! Move focus to the next window

      , ("M-h"             , sendMessage Shrink)                    -- %! Shrink the master area
      , ("M-l"             , sendMessage Expand)                    -- %! Expand the master area
      , ("M-,"             , sendMessage (IncMasterN 1))            -- %! Increment the number of windows in the master area
      , ("M-."             , sendMessage (IncMasterN (-1)))         -- %! Deincrement the number of windows in the master area
      , ("M-<Space>"       , sendMessage NextLayout)                -- %! Rotate through the available layout algorithms
      , ("M-w <Tab>"       , windows W.swapMaster)                  -- %! Swap the focused window and the master window
      , ("M-w S-<Tab>"     , windows W.focusMaster)                 -- %! Move focus to the master window

  -- TODO: Extract bindings shared by toSubl and sendMessage into another array and "compile" the both layouts...
  -- TODO: Include v in ^
      , ("M-a"             , sendMessage $ JumpToLayout "Tall")          -- %! Jump directly to layout
      , ("M-S-a"           , sendMessage $ JumpToLayout "Mirror Tall")   -- %! Jump directly to layout
      , ("M-s"             , sendMessage $ JumpToLayout "Full")          -- %! Jump directly to layout
      , ("M-d"             , sendMessage $ JumpToLayout "SimplestFloat") -- %! Jump directly to layout

      , ("M-C-h"           , toSubl Shrink)                         -- %! Shrink the master area
      , ("M-C-l"           , toSubl Expand)                         -- %! Expand the master area
      , ("M-C-,"           , toSubl (IncMasterN 1))                 -- %! Increment the number of windows in the master area
      , ("M-C-."           , toSubl (IncMasterN (-1)))              -- %! Deincrement the number of windows in the master area
      , ("M-C-<Space>"     , toSubl NextLayout)                     -- %! Rotate through the available layout algorithms
   -- , ("M-C-k"           , onGroup W.focusUp')                    -- %! Focus up window inside subgroup
   -- , ("M-C-j"           , onGroup W.focusDown')                  -- %! Focus down window inside subgroup
      , ("M-C-w <Tab>"     , onGroup swapMaster')                   -- %! Swap the focused window and the master window
      , ("M-C-w S-<Tab>"   , onGroup focusMaster')                  -- %! Focus down window inside subgroup

   -- , ("M-S-q"           , io (exitWith ExitSuccess))             -- %! Quit xmonad
      , ("M-C-S-q"         , action "reloadXMonad")                 -- %! Reload xmonad

      -- Consider using mod4+shift+{button1,button2} for prev, next workspace.

      -- I need to learn my new keyboard layout ^^
      , ("M-S-r"                , action "klayout")
      , ("M-S-t"                , action "restoreTmux")

      -- Scratchpads!
      , ("M-S-q"                     , namedScratchpadAction scratchpads "flyway")
      , ("M-q"                       , spawn "tmux detach-client -s flyway") -- "hide" flyway

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
      , ("M-<KP_End>"                , spawn "xbacklight -set 1")

      , ("M-<KP_Prior>"              , spawn "redshift -O 2000K")
      , ("M-<KP_Right>"              , spawn "redshift -O 6500K")

      , ("M-w w"                     , GS.goToSelected myGsConfig)

      , ("<F12>"                     , spawn "sleep 1 && xtrlock-pam")        -- %! Lock the screen
      ]
    )) where
      -- <Copied from SubLayout.hs...>
      -- should these go into XMonad.StackSet?
      focusMaster' st = let (f:fs) = W.integrate st in W.Stack f [] fs
      swapMaster' (W.Stack f u d) = W.Stack f [] $ reverse u ++ d
      -- </Copied from SubLayout.hs...>

-- Grid Select config
-- TODO: Change shown strings by something more verbose than zsh...
myGsConfig = GS.defaultGSConfig {
      GS.gs_cellheight = 75
    , GS.gs_cellwidth = 350
}

myXPconfig = PT.defaultXPConfig
        { PT.font              = "xft:Deja Vu Sans Mono:pixelsize=18"
        , PT.bgColor           = "black"
        , PT.fgColor           = "grey"
        , PT.fgHLight          = "black"
        , PT.bgHLight          = "grey"
        , PT.borderColor       = "lightblue"
        , PT.promptBorderWidth = 1
        , PT.position          = PT.Top -- ^ Position: 'Top', 'Bottom', or 'CenteredAt'
        , PT.height            = 26
        , PT.historyFilter     = nub
                               -- TODO: Add C-r for searching...
     -- , PT.promptKeymap      :: M.Map (KeyMask,KeySym) (XP ())  -- ^ Mapping from key combinations to actions
        , PT.completionKey     = (0, xK_Tab)
        , PT.autoComplete      = Nothing --Just 1      -- delay 1µs
        , PT.searchPredicate   = isInfixOf
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
        , workspaces         = ["home"]
        }


myPP = xmobarPP { ppCurrent = xmobarColor "#429942" "" . wrap "<" ">" }

-- Key binding to toggle the gap for the bar.
toggleStrutsKey XConfig {XMonad.modMask = modMask} = (modMask, xK_b)

main = xmonad =<< statusBar "xmobar" myPP toggleStrutsKey myConfig

-- vim: expandtab
