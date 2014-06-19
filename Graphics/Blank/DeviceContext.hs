{-# LANGUAGE OverloadedStrings #-}
module Graphics.Blank.DeviceContext where

import Graphics.Blank.Size
import Graphics.Blank.JavaScript
import Control.Concurrent.STM
import Control.Monad

import qualified Web.Scotty.Comet as KC

import Graphics.Blank.Events
import Data.Monoid((<>))
import qualified Data.Text as T

-- | 'Context' is our abstact handle into a specific 2d-context inside a browser.
-- Note that the JavaScript API concepts of 2D-Context and Canvas
-- are conflated in blank-canvas. Therefore, there is no 'getContext' method,
-- rather 'getContext' is implied (when using 'send').

data Context = Context
        { theComet    :: KC.Document                -- ^ The mechansims for sending commands
        , eventQueue  :: EventQueue                 -- ^ A single (typed) event queue
        , ctx_width   :: !Int
        , ctx_height  :: !Int
        , ctx_devicePixelRatio :: !Int
        }

instance Size Context where
        width  = fromIntegral . ctx_width
        height = fromIntegral . ctx_height

instance Image Context where { jsImage = jsImage . deviceCanvasContext }

deviceCanvasContext :: Context -> CanvasContext
deviceCanvasContext cxt = CanvasContext 0 (ctx_width cxt) (ctx_height cxt)

-- ** 'devicePixelRatio' returns the Device Pixel Ratio as used. Typically, the browser ignore devicePixelRatio in the canvas,
--   which can make fine details and text look fuzzy. Using the query "?hd" on the URL, blank-canvas attempts
--   to use the native devicePixelRatio, and if successful, 'devicePixelRatio' will return a number other than 1.
--   You can think of devicePixelRatio as the line width to use to make lines look one pixel wide.

devicePixelRatio ::  Context -> Int
devicePixelRatio = ctx_devicePixelRatio

-- | internal command to send a message to the canvas.
sendToCanvas :: Context -> ShowS -> IO ()
sendToCanvas cxt cmds = do
        KC.send (theComet cxt) $ "try{" <> T.pack (cmds "}catch(e){alert('JavaScript Failure: '+e.message);}")

-- | wait for any event
wait :: Context -> IO Event
wait c = atomically $ readTChan (eventQueue c)

-- | get the next event if it exists
tryGet :: Context -> IO (Maybe Event)
tryGet cxt = atomically $ do
    b <- isEmptyTChan (eventQueue cxt)
    if b 
    then return Nothing
    else liftM Just $ readTChan (eventQueue cxt)

-- | 'flush' all the current events, returning them all to the user.
flush :: Context -> IO [Event]
flush cxt = atomically $ loop
  where loop = do 
          b <- isEmptyTChan (eventQueue cxt)
          if b then return [] else do
                 e <- readTChan (eventQueue cxt)
                 es <- loop
                 return (e : es)
