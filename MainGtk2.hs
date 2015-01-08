{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, FlexibleInstances #-}

module Main (main) where

import Graphics.UI.Gtk as GTK
import Data.IORef
import Control.Monad.Trans

import Board
import MyBoard

data Options = Options {
	seed :: Int,
	size :: (Int, Int),
	firstClick :: (Int, Int)
}

data ProgramState = ProgramState {
	mainWindow :: Window,
	optionsWindow :: Window,
	board :: MyBoard,
	buttons :: [[Button]],
	options :: Options
}

dummyProgramState :: IO ProgramState
dummyProgramState = do
	mainW <- windowNew
	optionsW <- windowNew
	let b = initialize 0 (0,0) (0,0)
	let opt = Options 0 (0,0) (0,0)
	return $ ProgramState mainW optionsW b [[]] opt

main :: IO ()
main = do
	initGUI
	ps <- dummyProgramState
	ref <- newIORef ps
	buildOptionsWindow ref
	buildMainWindow ref
	showOptionsWindow ref
	mainGUI

showMainWindow :: IORef ProgramState -> IO ()
showMainWindow ref = do
	ps <- readIORef ref
	widgetShowAll (mainWindow ps)
	widgetHide (optionsWindow ps)

showOptionsWindow :: IORef ProgramState -> IO ()
showOptionsWindow ref = do
	ps <- readIORef ref
	widgetShowAll (optionsWindow ps)
	widgetHide (mainWindow ps)

buildMainWindow :: IORef ProgramState -> IO Window
buildMainWindow ref = do
	ps <- readIORef ref
	let w = mainWindow ps
	onDestroy w mainQuit
	return w

buildOptionsWindow :: IORef ProgramState -> IO Window
buildOptionsWindow ref = do
	-- init
	ps <- readIORef ref
	let w = optionsWindow ps
	vbox <- vBoxNew False 0
	labelSeed <- labelNew $ Just "Seed"
	entrySeed <- entryNew
	labelSize <- labelNew $ Just "Size"
	entrySize <- entryNew
	labelClick <- labelNew $ Just "First click"
	entryClick <- entryNew
	buttonOk <- buttonNewWithLabel "New"
	-- event callback
	onClicked buttonOk $ do
		seed <- entryGetText entrySeed :: IO [Char]
		size <- entryGetText entrySize :: IO [Char]
		click <- entryGetText entryClick :: IO [Char]
		let opt = Options (read seed) (read size) (read click)
		let b = initialize (read seed) (read size) (read click)
		let newPS = ProgramState (mainWindow ps) (optionsWindow ps) b (buttons ps) opt
		writeIORef ref newPS
		buildTable ref
		showMainWindow ref
	-- put objects in container
	containerAdd vbox labelSeed
	containerAdd vbox entrySeed
	containerAdd vbox labelSize
	containerAdd vbox entrySize
	containerAdd vbox labelClick
	containerAdd vbox entryClick
	containerAdd vbox buttonOk
	-- window
	GTK.set w [containerChild := vbox ]
	onDestroy w mainQuit
	return w

buildTable :: IORef ProgramState -> IO ()
buildTable ref = do
	ps <- readIORef ref
	let b = board ps
	table <- tableNew (width b) (height b) True
	let w = mainWindow ps
	GTK.set w [ containerChild := table ]
	buttonTable <- cellsToTable 0 (val b) table ref
	writeIORef ref $ ProgramState w (optionsWindow ps) b buttonTable (options ps)
	updateTable ref

cellsToTable :: Int -> [[Cell]] -> Table -> IORef ProgramState -> IO [[Button]]
cellsToTable _ [] _ _ = return []
cellsToTable i (xs:xss) table ref = do
	buttonTable <- cellsToTable (i+1) xss table ref
	buttonList <- cellsToRow (i, 0) xs table ref
	let newButtonTable = buttonList : buttonTable
	return newButtonTable

cellsToRow :: (Int, Int) -> [Cell] -> Table -> IORef ProgramState -> IO [Button]
cellsToRow _ [] _ _ = return []
cellsToRow (i, j) (x:xs) table ref = do
	buttonList <- cellsToRow (i, (j+1)) xs table ref
	button <- buttonNew
	button `on` buttonPressEvent $ tryEvent $ do
		LeftButton <- eventButton
		ps <- liftIO $ readIORef ref
		let newBoard = click (i, j) (board ps)
		liftIO $ writeIORef ref $ ProgramState (mainWindow ps) (optionsWindow ps) newBoard (buttons ps) (options ps)
		liftIO $ updateTable ref
	button `on` buttonPressEvent $ tryEvent $ do
		RightButton <- eventButton
		ps <- liftIO $ readIORef ref
		let newBoard = flag (i, j) (board ps)
		liftIO $ writeIORef ref $ ProgramState (mainWindow ps) (optionsWindow ps) newBoard (buttons ps) (options ps)
		liftIO $ updateTable ref
	let newButtonList = button : buttonList
	tableAttachDefaults table button i (i+1) j (j+1)
	return newButtonList

updateTable :: IORef ProgramState -> IO ()
updateTable ref = do
	ps <- readIORef ref
	let buttonTable = buttons ps
	let b = val $ board ps
	updateRow 0 b buttonTable
	putStrLn $ show $ board ps

updateRow :: Int -> [[Cell]] -> [[Button]] -> IO ()
updateRow _ [] _ = return ()
updateRow i (xs:xss) buttonTable = do
	updateRow (i+1) xss buttonTable
	updateCell (i, 0) xs buttonTable

updateCell :: (Int, Int) -> [Cell] -> [[Button]] -> IO ()
updateCell _ [] _ = return ()
updateCell (i,j) (x:xs) buttonTable = do
	updateCell (i, (j+1)) xs buttonTable
	cellToButton x ((buttonTable!!i)!!j)


-- create a gtk button from a cell
cellToButton :: Cell -> Button -> IO ()
cellToButton (Masked _) button = do
	emptyButton button
	image <- imageNewFromFile "masked.png"
	buttonSetImage button image
cellToButton (Flagged _) button = do
	emptyButton button
	image <- imageNewFromFile "flag.png"
	buttonSetImage button image
cellToButton (Clicked (-1)) button = do
	emptyButton button
	image <- imageNewFromFile "mine.png"
	buttonSetImage button image
cellToButton (Clicked x) button = do
	emptyButton button
	buttonSetLabel button (show x)

emptyButton :: Button -> IO ()
emptyButton button = do
	children <- containerGetChildren button
	containerForeach button (containerRemove button)
