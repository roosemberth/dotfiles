import XMonad hiding ((|||))

import qualified Data.Map as M
import qualified Data.Monoid(Endo)
import Codec.Binary.UTF8.String(encodeString)
import Control.Monad(liftM)
import Data.List(elemIndex, intercalate, intersperse, isInfixOf, isPrefixOf, nub, splitAt, stripPrefix)
import Data.Maybe(fromMaybe)
import System.Exit

import qualified XMonad.Actions.DynamicWorkspaces as DW
import qualified XMonad.Prompt as PT
import qualified XMonad.Prompt.Window as PTW
import qualified XMonad.StackSet as W
import qualified XMonad.Actions.UpdateFocus as UpF
import XMonad.Actions.CycleRecentWS(cycleWindowSets)
import XMonad.Actions.CycleWS(nextWS,prevWS)
import XMonad.Prompt.Pass(passPrompt)
import XMonad.Prompt(XPConfig, mkXPrompt)
import XMonad.Prompt.Workspace(Wor(Wor), workspacePrompt)

import XMonad.Hooks.DynamicLog(xmobarColor, xmobarStrip)
import XMonad.Hooks.EwmhDesktops(ewmh, fullscreenEventHook)
import XMonad.Hooks.ManageDocks(docks, manageDocks, avoidStruts, ToggleStruts(..))
import XMonad.Hooks.ManageHelpers(doCenterFloat, doFloatAt, doFullFloat, isFullscreen)
import XMonad.Hooks.UrgencyHook(readUrgents)

import qualified XMonad.Util.NamedWindows as NW
import XMonad.Util.EZConfig(mkKeymap)
import XMonad.Util.NamedScratchpad(customFloating, namedScratchpadAction, namedScratchpadManageHook, NamedScratchpad(NS))
import XMonad.Util.Run(spawnPipe, hPutStrLn)

import XMonad.Layout hiding ((|||))
import XMonad.Layout.BoringWindows (boringWindows, focusUp, focusDown)
import XMonad.Layout.LayoutCombinators((|||), JumpToLayout(..))
import XMonad.Layout.LayoutModifier(ModifiedLayout)
import XMonad.Layout.NoBorders(lessBorders, smartBorders, Ambiguity(OnlyFloat))
import XMonad.Layout.SimplestFloat(simplestFloat)
import XMonad.Layout.SubLayouts(toSubl, subTabbed, pullGroup, GroupMsg(..))
import XMonad.Layout.WindowNavigation(windowNavigation, Direction2D(..))
import XMonad.Layout.Grid

-- Contains long complicated shell commands used all over the config.
longCmds :: String -> String
longCmds cmd = (M.fromList $ [
      ("launcher"     , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 170x10 -title launcher -e zsh")
    , ("ulauncher"    , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 120x10 -title launcher -e zsh")
    , ("volumeUp"     , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') +5%")
    , ("volumeDown"   , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') -5%")
    , ("volumeToggle" , "pactl set-sink-mute   $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') toggle")
    , ("reloadXMonad" , "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'xmonad config reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi")
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

cycleRecentWS = cycleWindowSets options
 where options w = map (W.view `flip` w) (recentTags w)
       recentTags w = map W.tag $ (W.hidden w) ++ [W.workspace (W.current w)]

headSplitOn :: Eq a => a -> [a] -> [a]
headSplitOn c = takeWhile (/= c)

currentTopic :: W.StackSet [Char] l a sid sd -> [Char]
currentTopic w = headSplitOn ':' $ W.tag $ W.workspace (W.current w)

cycleTopicWS = cycleWindowSets options
 where options w = map (W.view `flip` w) (recentTags w)
       recentTags w = filter (isPrefixOf (currentTopic w)) $ map W.tag $ (W.hidden w) ++ [W.workspace (W.current w)]

selectWorkspace :: X ()
selectWorkspace = workspacePrompt myXPconfig { PT.autoComplete = Just 1 } $ \w ->
                  do s <- gets windowset
                     if W.tagMember w s
                       then windows $ W.greedyView w
                       else DW.addWorkspace w

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
      [ ("M-<Escape>"      , selectWorkspace) -- %! Quickjump
      , ("M-<Tab>"         , cycleTopicWS [xK_Super_L] xK_Tab xK_1)
      , ("M-<Backspace>"   , DW.addWorkspace "home")
      , ("M-t"             , DW.addWorkspace "temp")
      , ("M-S-="           , DW.addWorkspacePrompt myXPconfig)
      , ("M-<F5>"          , prevWS)
      , ("M-<F6>"          , nextWS)
      , ("<F10>"           , PTW.windowPrompt myXPconfig PTW.Goto PTW.allWindows)
      , ("M-S-<Tab>"       , cycleRecentWS [xK_Super_L] xK_Tab xK_1)
      , ("M-S-<Escape>"    , DW.selectWorkspace myXPconfig { PT.autoComplete = Just 1 }) -- %! Quickjump
      ]
    ) ++ (
      [ ("M-C-S-<Return>"  , action "launcher")
      , ("M-C-<Return>"    , action "ulauncher")
      , ("M-<Return>"      , spawn "urxvt -e tmux")
      , ("M-<Print>"       , spawn "screen-capture.sh")
      , ("M-<F4>"          , kill)                                  -- %! Close the focused window
                                                                    -- %! Push window up to floating
      , ("M-f"             , withFocused $ windows . flip W.float (W.RationalRect (1/6) (1/6) (2/3) (2/3)))
      , ("M-S-f"           , withFocused $ windows . W.sink)        -- %! Push window back into tiling

      , ("M-b"             , sendMessage ToggleStruts)              -- %! Collapse/Expand the status bar zone
      , ("M-n"             , refresh)                               -- %! ???

      -- v Candidates to a workspace cluster (M-S-w *).
      , ("M-<F2>"          , DW.renameWorkspace myXPconfig)
      , ("M-g"             , DW.withWorkspace myXPconfig (windows . W.shift))

      -- v These operations act on windows cluster (M-w *).
      , ("M-w S-m"         , withFocused $ sendMessage . MergeAll)  -- %! Merge focused windows into a subgroup
      , ("M-w m"           , withFocused $ sendMessage . UnMerge)   -- %! Unmerge a subgroup into windows
      , ("M-w <Tab>"       , windows W.swapMaster)                  -- %! Swap the focused window and the master window
      , ("M-w S-<Tab>"     , windows W.focusMaster)                 -- %! Move focus to the master window

      -- v These work even in sublayouts.
      , ("M-S-k"           , windows W.swapUp)                      -- %! Swap the focused window with the previous window
      , ("M-S-j"           , windows W.swapDown)                    -- %! Swap the focused window with the next window
      -- v These will skip hidden windows
      , ("M-k"             , focusUp)                               -- %! Move focus to the previous window
      , ("M-j"             , focusDown)                             -- %! Move focus to the next window
      -- v FIXME: These shortcuts should only wotk inside the sublayout.
      , ("M-C-k"           , windows W.focusUp)                     -- %! Move focus to the previous window
      , ("M-C-j"           , windows W.focusDown)                   -- %! Move focus to the next window

      -- Sublayout grouping
      , ("M-M1-h"          , sendMessage $ pullGroup L)             -- %! Move window to the left subgroup
      , ("M-M1-j"          , sendMessage $ pullGroup D)             -- %! Move window to the down subgroup
      , ("M-M1-k"          , sendMessage $ pullGroup U)             -- %! Move window to the up subgroup
      , ("M-M1-l"          , sendMessage $ pullGroup R)             -- %! Move window to the right subgroup

      -- TODO: Extract bindings shared by toSubl and sendMessage into another array and "compile" the both layouts...
      -- TODO: Include v in ^
      , ("M-a"             , sendMessage $ JumpToLayout "Tall")          -- %! Jump directly to layout
      , ("M-S-a"           , sendMessage $ JumpToLayout "Mirror Tall")   -- %! Jump directly to layout
      , ("M-s"             , sendMessage $ JumpToLayout "Full")          -- %! Jump directly to layout
      , ("M-d"             , sendMessage $ JumpToLayout "SimplestFloat") -- %! Jump directly to layout

      , ("M-h"             , sendMessage Shrink)                    -- %! Shrink the master area
      , ("M-l"             , sendMessage Expand)                    -- %! Expand the master area
      , ("M-,"             , sendMessage (IncMasterN 1))            -- %! Increment the number of windows in the master area
      , ("M-."             , sendMessage (IncMasterN (-1)))         -- %! Deincrement the number of windows in the master area
      , ("M-<Space>"       , sendMessage NextLayout)                -- %! Rotate through the available layout algorithms

      , ("M-C-h"           , toSubl Shrink)                         -- %! Shrink the master area
      , ("M-C-l"           , toSubl Expand)                         -- %! Expand the master area
      , ("M-C-,"           , toSubl (IncMasterN 1))                 -- %! Increment the number of windows in the master area
      , ("M-C-."           , toSubl (IncMasterN (-1)))              -- %! Deincrement the number of windows in the master area
      , ("M-C-<Space>"     , toSubl NextLayout)                     -- %! Rotate through the available layout algorithms

   -- , ("M-S-q"           , io (exitWith ExitSuccess))             -- %! Quit xmonad
      , ("M-C-S-q"         , action "reloadXMonad")                 -- %! Reload xmonad

      -- Consider using mod4+shift+{button1,button2} for prev, next workspace.

      -- Tools
      , ("M-S-r"                     , action "klayout")
      , ("M-S-t"                     , action "restoreTmux")
      , ("M-p"                       , passPrompt myXPconfig)

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
      , ("M-S-<KP_Prior>"            , spawn "redshift -O 6500K")
      , ("M-<KP_Right>"              , spawn "xbacklight -set 1")
      , ("M-S-<KP_Right>"            , spawn "xbacklight -set 100")
      , ("M-<KP_End>"                , spawn "xrandr --output eDP1 --auto --below DP-1-2 --below DP-1-3")
      , ("M-S-<KP_End>"              , spawn "xrandr --output eDP1 --off")
      , ("M-<KP_Down>"               , spawn "xrandr --output DP-1-2 --auto --above eDP1")
      , ("M-S-<KP_Down>"             , spawn "xrandr --output DP-1-2 --off")
      , ("M-<KP_Next>"               , spawn "xrandr --output DP-1-3 --auto --above eDP1")
      , ("M-S-<KP_Next>"             , spawn "xrandr --output DP-1-3 --off")

      , ("<F7>"                      , spawn "xset s off")
      , ("S-<F7>"                    , spawn "xset s on")
      , ("<F12>"                     , spawn "sleep 0.1; xset s activate")
      , ("M-<F7>"                    , spawn "sm")
      ]
    )) where
      -- <Copied from SubLayout.hs...>
      -- should these go into XMonad.StackSet?
      focusMaster' st = let (f:fs) = W.integrate st in W.Stack f [] fs
      swapMaster' (W.Stack f u d) = W.Stack f [] $ reverse u ++ d
      -- </Copied from SubLayout.hs...>

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
        , PT.autoComplete      = Nothing
        , PT.searchPredicate   = isInfixOf
        }

layoutAlgorithms = tiled ||| Full ||| Mirror tiled ||| Grid ||| simplestFloat where
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

myConfig = ewmh $ defaultConfig
        { borderWidth        = 1
        , focusFollowsMouse  = True
        , focusedBorderColor = "#ff0000"
        , handleEventHook    = fullscreenEventHook <+> UpF.focusOnMouseMove
        , keys               = myKeys
        , layoutHook         = myLayout
        , manageHook         = myManageHook <+> manageHook defaultConfig
        , modMask            = mod4Mask
        , normalBorderColor  = "#1b1b2e"
        , startupHook        = UpF.adjustEventInput
        , terminal           = "urxvt -e tmux"
        , workspaces         = ["home"]
        }

wrap :: String -> String -> String -> String
wrap _ _ "" = ""
wrap l r m  = l ++ m ++ r

filterTags :: (i -> Bool) -> W.StackSet i l a s sd -> [i]
filterTags f s = filter f $ map W.tag $ W.workspaces s

pprWindowSet :: W.StackSet [Char] l a s sd -> String
pprWindowSet s = intercalate " " [current, visibles, nHidden]
    where topicSiblings = filterTags (isInfixOf $ currentTopic s) s
          tagAndTopicSiblingsStr tag = show (length $ filterTags (isInfixOf $ headSplitOn ':' tag) s) ++ "/" ++ tag
          current  = xmobarColor "#429942" "" $ wrap "<" ">" $ tagAndTopicSiblingsStr $ W.currentTag s
          visibles = intercalate " " $ map (wrap "(" ")" . tagAndTopicSiblingsStr . W.tag . W.workspace) (W.visible s)
          nTopics = length . nub $ map (headSplitOn ':' . W.tag) (W.workspaces s)
          nHidden  = wrap "(+" ")" $ (show $ length $ W.hidden s) ++ "/" ++ (show nTopics)

dynamicLogString = do
    winset <- gets windowset
    urgentW <- readUrgents -- TODO: Handle urgent windows
    wintitle <- maybe (return "") (fmap show . NW.getName) . W.peek $ winset

    let workspaces = pprWindowSet winset
    let layout     = description . W.layout . W.workspace . W.current $ winset
    let title      = xmobarColor "green" "" $ xmobarStrip wintitle

    return $ encodeString . intercalate " : " . filter (not . null) $ [ workspaces , layout , title ]

main = do
    xmobar <- spawnPipe "xmobar"
    xmonad $ docks $ myConfig { logHook = dynamicLogString >>= io . hPutStrLn xmobar }

-- vim: expandtab
