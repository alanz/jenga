{-# LANGUAGE OverloadedStrings #-}

module Jenga.Git
  ( setupGitSubmodules
  ) where

import           Control.Monad.Trans.Either (EitherT, handleIOEitherT)

import qualified Data.Text as T

import           Jenga.Config
import           Jenga.Git.Command
import           Jenga.Stack
import           Jenga.Types

import           Network.URI (parseURI, uriPath)

import           System.Directory (createDirectoryIfMissing, doesDirectoryExist, withCurrentDirectory)
import           System.FilePath ((</>), dropExtension)


setupGitSubmodules :: ModulesDirPath ->  [StackGitRepo] -> EitherT JengaError IO ()
setupGitSubmodules smp =
  mapM_ (setupSubmodule smp)


setupSubmodule :: ModulesDirPath -> StackGitRepo -> EitherT JengaError IO ()
setupSubmodule smp gitrepo = do
  handleIOEitherT (JengaIOError "setupSubmodule" (unModulesDirPath smp)) $ do
    createDirectoryIfMissing False $ unModulesDirPath smp
    let dir = buildSubmoduleDir smp gitrepo
    exists <- doesDirectoryExist dir
    if exists
      then updateSubmodule dir gitrepo
      else addSubmodule dir gitrepo



buildSubmoduleDir :: ModulesDirPath -> StackGitRepo -> FilePath
buildSubmoduleDir (ModulesDirPath smp) gitrepo =
  case parseURI (T.unpack $ sgrUrl gitrepo) of
    Nothing -> error $ "Not able to parse " ++ show (sgrUrl gitrepo)
    Just uri ->
      case split (== '/') $ uriPath uri of
        ["",  _, name] -> smp </> dropExtension name
        xs -> error $ "buildSubmoduleDir: Bad git repo user/project: " ++ show xs

split :: (a -> Bool) -> [a] -> [[a]]
split p =
  splitter
  where
    splitter [] = []
    splitter xs =
      case break p xs of
        (h, []) -> [h]
        (h, t) -> h : splitter (drop 1 t)


updateSubmodule :: FilePath -> StackGitRepo -> IO ()
updateSubmodule dir gitrepo = do
  putStrLn $ "Updating submodule '" ++ dir ++ "' to commit " ++ T.unpack (T.take 10 $ sgrCommit gitrepo)
  withCurrentDirectory dir $ do
    gitUpdate
    gitCheckoutCommit $ T.unpack (sgrCommit gitrepo)

addSubmodule :: FilePath -> StackGitRepo -> IO ()
addSubmodule dir gitrepo = do
  putStrLn $ "Adding submodule '" ++ dir ++ "' at commit " ++ T.unpack (T.take 10 $ sgrCommit gitrepo)
  gitAddSubmodule dir $ T.unpack (sgrUrl gitrepo)
  withCurrentDirectory dir $
    gitCheckoutCommit $ T.unpack (sgrCommit gitrepo)
