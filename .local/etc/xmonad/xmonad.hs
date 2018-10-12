import XMonad hiding ((|||))

import qualified Data.Map as M
import Codec.Binary.UTF8.String(encodeString)
import Control.Monad(liftM, mfilter)
import Data.Foldable(asum)
import Data.Maybe(fromMaybe, fromJust)
import Data.List
import Data.Monoid(Endo(..), mempty, mconcat)
import Data.Tuple(fst, snd, uncurry)
import System.Exit

import qualified XMonad.Actions.DynamicWorkspaces as DW
import qualified XMonad.Prompt as PT
import qualified XMonad.Prompt.Window as PTW
import qualified XMonad.StackSet as W
import qualified XMonad.Actions.UpdateFocus as UpF

import XMonad.Actions.CycleRecentWS(cycleWindowSets)
import XMonad.Actions.CycleWS(nextWS,prevWS)
import XMonad.Operations(rescreen, windows)
import XMonad.Prompt.Pass(passPrompt)
import XMonad.Prompt(XPConfig, XPrompt, mkComplFunFromList', mkXPrompt)
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
import XMonad.Layout.LayoutScreens(layoutSplitScreen)
import XMonad.Layout.NoBorders(lessBorders, smartBorders, Ambiguity(OnlyFloat))
import XMonad.Layout.SubLayouts(toSubl, subTabbed, pullGroup, GroupMsg(..))
import XMonad.Layout.WindowNavigation(windowNavigation, Direction2D(..))
import XMonad.Layout.Grid

actionsList :: M.Map String (X())
actionsList = M.fromList
  ((map (mapResult spawn) [
    ("klayout"      , "feh /Storage/tmp/Ergodox-Base.png")
  , ("launcher"     , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 170x10 -title launcher -e zsh")
  , ("mpv"          , "mpv \"$(xclip -o -selection clipboard)\" --load-unsafe-playlists  '--ytdl-format=bestvideo[height<=?2160]+bestaudio/best' --force-seekable --cache=1048576 --cache-seek-min=1048576")
  , ("reloadXMonad" , "if type xmonad; then xmonad --recompile && xmonad --restart && notify-send 'xmonad config reloaded'; else xmessage xmonad not in \\$PATH: \"$PATH\"; fi")
  , ("restoreTmux"  , "for session in $(tmux list-sessions | grep -oP '^[^:]+(?!.*attached)'); do setsid urxvt -e tmux attach -t $session &\n done")
  , ("ulauncher"    , "OLD_ZDOTDIR=${ZDOTDIR} ZDOTDIR=${XDG_CONFIG_HOME}/zsh/launcher/ urxvt -geometry 120x10 -title launcher -e zsh")
  , ("volumeDown"   , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') -5%")
  , ("volumeToggle" , "pactl set-sink-mute   $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') toggle")
  , ("volumeUp"     , "pactl set-sink-volume $(pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g') +5%")
  ]) ++ (map (mapResult cmdInTmpTmux) [
    ("dico"         , "dico \"$(read -e)\"")
  , ("wn"           , "wn \"$(read -e)\" -over")
  ])) where cmdInTmpTmux cmd = spawn $ "urxvt -title overlay -e tmux new '" ++ cmd ++ "; echo Press any key to exit && read'"
            mapResult fn (k, v) = (k, fn v)

action :: String -> X ()
action action = actionsList M.! action

data ActionRef = ActionRef String

instance XPrompt ActionRef where
    showXPrompt (ActionRef name) = name

actionsPrompt:: XPConfig -> X()
actionsPrompt c = mkXPrompt (ActionRef "") c (mkComplFunFromList' keys) $ runAction
  where keys = M.keys actionsList
        runAction ref = actionsList M.! ref

floatingOverlay = customFloating $ W.RationalRect (1/6) (1/6) (2/3) (2/3)

scratchpads = [
-- TODO: More scratchpads!: System status (spawn detached on boot?), soundctl, ???
      NS "flyway"  ("urxvt -title Scratchpad-flyway -e tmux new -As flyway")
        (title =? "Scratchpad-flyway") floatingOverlay
    ] where role = stringProperty "WM_WINDOW_ROLE"

centerFloatByTitle = [ "launcher", "xmessage" ]
centerFloatByClassNameLike =
  [ "Gajim" , "Gnome-calendar", "Gvncviewer"
  , "Pinentry", "Shutter", "Zenity"
  , "eog", "feh", "mpv", "vlc"
  ]

breakAtSublist :: Eq a => [a] -> [a] -> Maybe ([a], [a])
breakAtSublist sl l = gashAndRemoveSubListAtIdx <$> sublistIdx
  where subListIsAtIdx sl idx l = isPrefixOf sl $ drop idx l
        trisectL len1 len2 l = (take len1 l, take len2 $ drop len1 l, drop (len1 + len2) l)
        gashAndRemoveSubListAtIdx idx = (\(a, _, c) -> (a, c)) $ trisectL idx slLen l
        sublistIdx = findIndex (\i -> subListIsAtIdx sl i l) [0..(length l)-slLen]
        slLen = length sl

-- ## Windows title hints
-- If the window title is of the form `${wsh}|::|...` then `${wsh}` is used as a workspace hint and is resolved as follows:
-- If `${wsh}` is an existing workspace then use as is.
-- If `${wsh}` is of the form `(?<p1>.*)/(.*/)*...`; within the existing workspaces, we try to find one for whom hint is a
--  prefix path. If no existing workspace is found, we remove the last particle and recurse until the hint is empty. If
--  a workspace is found, we return the found prefix path (which may or may not exist).
-- Else return Nothing.
--
workspaceFromTitleHint :: String -> [String] -> Maybe String
workspaceFromTitleHint title wsNames = fst <$> (breakAtSublist "|::|" title) >>= wsFromNameHint
  where wsFromNameHint hintPath = mfilter (flip elem rootPaths . getRootPath) (Just hintPath) >>= findTarget
        rootPaths = nub $ map getRootPath wsNames
        getRootPath = head . splitDirectories
        findTarget :: String -> Maybe String
        findTarget hintPath = find subpathExists (mkparentpaths hintPath)  -- >>= (`find` wsNames) . isPrefixOf
        subpathExists s = or $ map (isPrefixOf s) wsNames
        mkparentpaths = reverse . scanl1 combine . splitDirectories

queryFromLookupInWindowSet :: (WindowSet -> Maybe b) -> [(b -> WindowSet -> WindowSet)] -> Query (Endo WindowSet)
queryFromLookupInWindowSet lu actions = doF $ \ws -> case lu ws of { Nothing -> ws; Just b -> batchActions b ws actions }
  where batchActions :: b -> a -> [b -> a -> a] -> a
        batchActions ws = foldl' (\z fn -> fn ws z)

myManageHook :: Query (Endo WindowSet)
myManageHook = composeAll $
    (map (--> doCenterFloat) [
      title ~~ flip elem centerFloatByTitle
    , className ~~ (flip any centerFloatByClassNameLike . isInfixOf)
    , className =? "Firefox" <&&> role ~~ (/= "browser")
    ]) ++ [
      title ~~ isInfixOf "overlay" --> floatingOverlay
    , namedScratchpadManageHook scratchpads
    , isFullscreen --> doFullFloat
--  , title >>= \t -> queryFromLookupInWindowSet (workspaceFromTitleHint t . getWorkspaces) [mkws, W.shift, W.greedyView]
    , manageDocks
    ] where role = stringProperty "WM_WINDOW_ROLE"
            (~~) :: (Query a) -> (a -> b) -> (Query b)
            (~~) = flip liftM
            getWorkspaces = map W.tag . W.workspaces
            mkws = addWorkspaceIfNotExist

wrapWindowToWorspaceInTitleHint :: X()
wrapWindowToWorspaceInTitleHint = withFocused $ (>>= XMonad.Operations.windows) . mkX
  where mkX :: Window -> X(WindowSet -> WindowSet)
        mkX = (appEndo <$>) . runQuery (title >>= mkQuery)
        mkQuery :: String -> Query(Endo WindowSet)
        mkQuery t = queryFromLookupInWindowSet (workspaceFromTitleHint t . getWorkspaces) [addWorkspaceIfNotExist, W.shift]
        getWorkspaces = map W.tag . W.workspaces

autoremoveEmptyWorkspaces :: [(a, X ())] -> [(a, X ())]
autoremoveEmptyWorkspaces = map fp
  where fp (keys, action) = (keys, DW.removeEmptyWorkspaceAfter action)

cycleRecentWS = cycleWindowSets options
 where options w = map (`W.view` w) (recentTags w)
       recentTags w = map W.tag $ (W.hidden w) ++ [W.workspace (W.current w)]

headSplitOn :: Eq a => a -> [a] -> [a]
headSplitOn c = takeWhile (/= c)

currentWsPath :: W.StackSet String l a sid sd -> String
currentWsPath w = takeDirectory $ W.tag $ W.workspace $ W.current w

cycleWsSibilings = cycleWindowSets options
 where options w = map (`W.view` w) (recentTags w)
       recentTags w = filter (isPrefixOf (currentWsPath w)) $ map W.tag $ (W.hidden w) ++ [W.workspace (W.current w)]

addWorkspaceIfNotExist :: String -> WindowSet -> WindowSet
addWorkspaceIfNotExist tag ws = if W.tagMember tag ws then ws else addWorkspace tag ws
  where addWorkspace tag ss@(W.StackSet { W.hidden = old }) = ss { W.hidden = (W.Workspace tag (cl ss) Nothing) : old }
        cl :: WindowSet -> Layout Window
        cl ss = W.layout $ W.workspace $ W.current ss

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
      , ("M-<Tab>"         , cycleWsSibilings [xK_Super_L] xK_Tab xK_1)
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
      , ("M-a"             , sendMessage $ JumpToLayout "Tall")     -- %! Jump directly to layout vertical
      , ("M-S-a"           , sendMessage $ JumpToLayout "Mirror Tall")   -- %! Jump directly to layout horizontal
      , ("M-s"             , sendMessage $ JumpToLayout "Full")     -- %! Jump directly to layout single window
      , ("M-d"             , sendMessage $ JumpToLayout "Grid")     -- %! Jump directly to layout grid
      , ("M-<F11>"         , wrapWindowToWorspaceInTitleHint)       -- %! See [windows title hints]
      , ("M-<F12>"         , rescreen)                              -- %! Force screens state update (eg. undo layoutSplitScreen)
      , ("M-S-<F12>"       , layoutSplitScreen 4 Grid)              -- %! Break a screen into 4 workspaces

      , ("M-h"             , sendMessage Shrink)                    -- %! Shrink the master area
      , ("M-l"             , sendMessage Expand)                    -- %! Expand the master area
      , ("M-,"             , sendMessage (IncMasterN 1))            -- %! Increment the number of windows in the master area
      , ("M-."             , sendMessage (IncMasterN (-1)))            -- %! Increment the number of windows in the master area
      , ("M-o"             , sendMessage (IncMasterN (-1)))            -- %! Increment the number of windows in the master area
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
      , ("M-r"                       , actionsPrompt myXPconfig { PT.autoComplete = Just 1 })

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

-- gimpLayout = withIM 0.11 (Role "gimp-toolbox") $ reflectHoriz
--       $ withIM 0.15 (Role "gimp-dock") (trackFloating simpleTabbed)

layoutAlgorithms = tiled ||| Full ||| Mirror tiled ||| Grid where
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
        , startupHook        = gnomeRegister >> UpF.adjustEventInput
        , terminal           = "urxvt -e tmux"
        , workspaces         = ["home"]
        }

gnomeRegister :: MonadIO m => m ()
gnomeRegister = io $ do
    x <- lookup "DESKTOP_AUTOSTART_ID" `fmap` getEnvironment
    whenJust x $ \sessionId -> safeSpawn "dbus-send"
            ["--session"
            ,"--print-reply=literal"
            ,"--dest=org.gnome.SessionManager"
            ,"/org/gnome/SessionManager"
            ,"org.gnome.SessionManager.RegisterClient"
            ,"string:xmonad"
            ,"string:"++sessionId]

wrap :: String -> String -> String -> String
wrap _ _ "" = ""
wrap l r m  = l ++ m ++ r

filterTags :: (i -> Bool) -> W.StackSet i l a s sd -> [i]
filterTags f s = filter f $ map W.tag $ W.workspaces s

pprWindowSet :: W.StackSet String l a s sd -> String
pprWindowSet s = intercalate " " [current, visibles, nHidden]
    where wsFamilySizeAndNameStr tag = show (length $ filterTags ((tag `isPrefixOf`) . takeDirectory) s) ++ "/" ++ tag
          current  = xmobarColor "#429942" "" $ wrap "<" ">" $ wsFamilySizeAndNameStr $ W.currentTag s
          visibles = intercalate " " $ map (wrap "(" ")" . wsFamilySizeAndNameStr . W.tag . W.workspace) (W.visible s)
          nRootWs = length . nub $ map (headSplitOn '/' . W.tag) (W.workspaces s)
          nHidden  = wrap "(+" ")" $ (show $ length $ W.hidden s) ++ "/" ++ (show nRootWs)

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
