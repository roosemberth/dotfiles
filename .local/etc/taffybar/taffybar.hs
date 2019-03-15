{-# LANGUAGE OverloadedStrings #-}
module Main where

import Control.Monad.IO.Class (liftIO)
import qualified Data.Text as T

import System.Taffybar.Context (TaffyIO)
import System.Taffybar.Util

import System.Taffybar
import System.Taffybar.Hooks
import System.Taffybar.Information.CPU
import System.Taffybar.Information.Memory
import System.Taffybar.SimpleConfig
import System.Taffybar.Widget
import System.Taffybar.Widget.Generic.PollingGraph
import System.Taffybar.Widget.Generic.PollingLabel
import System.Taffybar.Widget.Util
import System.Taffybar.Widget.Layout
import System.Taffybar.Widget.Workspaces

transparent = (0.0, 0.0, 0.0, 0.0)
yellow1 = (0.9453125, 0.63671875, 0.2109375, 1.0)
yellow2 = (0.9921875, 0.796875, 0.32421875, 1.0)
green1 = (0, 1, 0, 1)
green2 = (1, 0, 1, 0.5)
taffyBlue = (0.129, 0.588, 0.953, 1)
orange = (1, 0.5, 0, 0.8)

myGraphConfig =
  defaultGraphConfig
  { graphPadding = 0
  , graphBorderWidth = 0
  , graphWidth = 75
  , graphBackgroundColor = transparent
  , graphLabel = Nothing
  }

netCfg = myGraphConfig { graphDataColors = [yellow1, yellow2] }
memCfg = myGraphConfig { graphDataColors = [taffyBlue] }
cpuCfg = myGraphConfig { graphDataColors = [green1, green2] }

cpuCallback = do
  (_, systemLoad, totalLoad) <- cpuLoad
  return [totalLoad, systemLoad]

customLayoutTitle title = text
  where text = if "Tabbed" `T.isPrefixOf` title
                then highlight "00FF00" (T.drop 7 title)
                else highlight "FF0000" title
        highlight color text = T.pack $ "<span fgcolor='#" ++ color ++ "'>" ++ T.unpack text ++ "</span>"

formatMemoryUsageRatio :: Double -> T.Text
formatMemoryUsageRatio n = T.pack $ "Mem: " ++ (show $ roundInt val) ++ "%"
  where roundInt :: Double -> Int
        roundInt = round
        val = n * 100

main = do
  let myWorkspacesConfig =
        defaultWorkspacesConfig
        { minIcons = 0
        , widgetGap = 0
        , showWorkspaceFn = hideEmpty
        , urgentWorkspaceState = True
        }
      workspaces = workspacesNew myWorkspacesConfig
      layout = layoutNew $ LayoutConfig $ return . customLayoutTitle
      windows = windowsNew defaultWindowsConfig
          -- See https://github.com/taffybar/gtk-sni-tray#statusnotifierwatcher
          -- for a better way to set up the sni tray
      tray = sniTrayThatStartsWatcherEvenThoughThisIsABadWayToDoIt
      myConfig = defaultSimpleTaffyConfig
        { startWidgets = map (>>= buildContentsBox) [layout] ++ [workspaces]
        , centerWidgets = map (>>= buildContentsBox) [windows]
        , endWidgets = map (>>= buildContentsBox)
          [ textClockNew Nothing "%a %b %_d %H:%M:%S" 1
          , batteryIconNew
          , textBatteryNew "$percentage$ ($time$)"
          , tray
          , networkGraphNew netCfg Nothing
          , pollingLabelNew "Mem" 1 $ parseMeminfo >>= return . (formatMemoryUsageRatio . memoryUsedRatio)
          , pollingGraphNew cpuCfg 0.5 cpuCallback
          , fsMonitorNew 500 ["/"]
       -- , mpris2New
          ]
        , barPosition = Top
        , barPadding = 0
        , barHeight = 30
        , widgetSpacing = 0
        }
  dyreTaffybar $ withBatteryRefresh $ withLogServer $ withToggleServer $
               toTaffyConfig myConfig
