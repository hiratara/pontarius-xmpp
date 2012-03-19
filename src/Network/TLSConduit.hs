module Network.TLSConduit
       ( tlsinit
       , module TLS
       , module TLSExtra
       )
       where

import Control.Applicative
import Control.Monad.Trans

import Crypto.Random

import Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Conduit

import Network.TLS as TLS
import Network.TLS.Extra as TLSExtra

import System.IO(Handle)
import System.Random

import System.IO

tlsinit
  :: (MonadIO m, ResourceIO m1) =>
     TLSParams -> Handle
     -> m (Source m1 ByteString, Sink ByteString m1 ())
tlsinit tlsParams handle = do
    gen <- liftIO $ (newGenIO :: IO SystemRandom) -- TODO: Find better random source?
    clientContext <- client tlsParams gen handle
    handshake clientContext
    let src = sourceIO
               (return clientContext)
               bye
               (\con -> IOOpen <$> recvData con)
    let snk = sinkIO
                (return clientContext)
                (\_ -> return ())
                (\ctx dt -> sendData ctx (BL.fromChunks [dt]) >> return IOProcessing)
                (\_ -> return ())
    return (src $= conduitStdout , snk)

-- TODO: remove

conduitStdout :: ResourceIO m
            => Conduit BS.ByteString m BS.ByteString
conduitStdout = conduitIO
    (return ())
    (\_ -> return ())
    (\_ bs -> do
        liftIO $ BS.hPut stdout bs
        return $ IOProducing [bs])
    (const $ return [])