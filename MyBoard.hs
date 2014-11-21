module MyBoard where

import Data.Vector as Vec hiding ((++), concat, set, replicate, take, elem, map, concatMap, filter, length)
import System.Random

import Board

-- a cell is
-- flagged, mine or not
-- clicked, mine (-1) or number of adjacent mine
-- masked, mine or not
data Cell = Flagged Bool | Clicked Int | Masked Bool deriving (Eq)

data MyBoard = MyBoard { 
  val :: Vector Cell,
  width :: Int,
  height :: Int
}

instance Show Cell where
  show (Flagged _) = "F"
  show (Clicked x) 
    | x == -1 = "M"
    | otherwise = show x
  show (Masked _) = " "

-- display a beautiful board
instance Show MyBoard where
  show b 
    | height b == 0 = boundariesH
    | otherwise = boundariesH
                  ++ (concatMap ('|':) $ map show $ toList xs) ++ "|\n" -- values for this line
                  ++ (show (MyBoard xss w newH)) -- rest of the board
                  where (xs, xss) = Vec.splitAt w (val b)
                        w = width b
                        newH = (height b)-1
                        boundariesH = '+' : (concat $ replicate w "-+") ++ "\n"

-- remove duplicates and one specified exception in a iterate-generated list (one at a time)
filterDuplicates :: Eq a => a -> [(a, b)] -> [(a, b)]
filterDuplicates exception aList = [x|(Just x, _, _) <- iterate getNext (Nothing, aList, [])]
  where getNext (_, x:xs, used)
          | fst x `elem` used || fst x == exception = (Nothing, xs, used)
          | otherwise = (Just x, xs, (fst x):used)

-- generate a list of random ints of size "n" in range "range" excluding duplicates and "exception"
generateUniqueRandom :: (Random a, Eq a, RandomGen b) => a -> (a, a) -> Int -> b -> [a]
generateUniqueRandom exception range n = map fst . take n . filterDuplicates exception . iterate getNext . randomR range
  where getNext = randomR range . snd

instance Board MyBoard Cell where
  -- initialize the board using a list of unique random numbers excluding the first click.
  -- random numbers are used as indices of mines in the board
  initialize seed (width,height) (c1,c2) = click (c1,c2) (MyBoard vec width height)
    where vec = generate sizeVec (\i -> if i `elem` randomList then (Masked True) else (Masked False)) 
          sizeVec = width*height
          randomList = generateUniqueRandom firstClick (0, sizeVec) nbOfMines (mkStdGen seed)
          nbOfMines = sizeVec `div` 4 -- 4 is a magic number !
          firstClick = c1*width + c2

  -- get a cell of the board
  get (x, y) b = (val b) ! (x*(width b) + y)
  -- set a cell of the board
  set (x, y) a b 
    | x < 0 || y < 0 || x >= w || y >= h = b
    | otherwise = MyBoard ((val b) // [(i, a)]) w h
      where i = x*w + y
            w = width b
            h = height b

  -- click on a cell
  -- if masked -> click
  -- if flagged or clicked -> impossible to click
  -- if clicked and 0 adjacent mines -> click on all adjacent cells
  click (x, y) b
    | nbOfAdjacentMines /= 0 = newBoard
    | otherwise = Prelude.foldr (\x acc -> if (get x acc) == (Masked False) then click x acc else acc) newBoard neighboursIndex
      where nbOfAdjacentMines = length $ filter (\c -> c == (Masked True) || c == (Flagged True) || c == (Clicked (-1))) neighbours
            newBoard = set (x, y) (newValue oldValue) b
            neighboursIndex = [(i, j) | i <- [(x-1)..(x+1)], j <- [(y-1)..(y+1)], i >= 0, i < w, j >= 0, j < h, (i, j) /= (x, y)]
            neighbours = [get i b | i <- neighboursIndex]
            w = width b
            h = height b
            oldValue = get (x, y) b
            newValue (Masked True) = (Clicked (-1))
            newValue (Masked False) = (Clicked nbOfAdjacentMines)
            newValue _ = oldValue

  -- flag a cell
  -- if masked -> flag
  -- if flagged -> mask
  -- if clicked -> impossible to flag
  flag (x, y) b = set (x, y) (newValue oldValue) b
    where oldValue = get (x, y) b
          newValue (Masked x) = (Flagged x)
          newValue (Flagged x) = (Masked x)
          newValue _ = oldValue
  -- check if game is won
  -- if each flagged cell is a mine and each clicked cell is not a mine and there are no masked cell
  won b = Vec.foldr wonCell True $ val b
    where wonCell (Flagged m) acc = acc && m == True
          wonCell (Masked _) _ = False
          wonCell (Clicked x) acc = acc && x >= 0
  -- check if game is lost
  -- if a clicked cell is a mine
  lost b = Vec.foldr lostCell False $ val b
    where lostCell (Flagged _) acc = acc || False
          lostCell (Masked _) acc = acc || False
          lostCell (Clicked a) acc  = acc || (a == -1)
  -- click on every cell to show the entire board at the end of game
  reveal b = Prelude.foldr click b [(i, j) | i <- [0..(width b)], j <- [0..(height b)]]