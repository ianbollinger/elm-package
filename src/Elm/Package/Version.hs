module Elm.Package.Version where

import Control.Applicative ((<$>), (<*>))
import Data.Aeson
import Data.Binary
import Data.Char (isDigit)
import Data.Function (on)
import qualified Data.List as List
import qualified Data.Text as T

import qualified Elm.Compiler as Elm


elm :: Version
elm =
  case Elm.rawVersion of
    major : minor : patch : _ ->
        Version major minor patch

    [major, minor] ->
        Version major minor 0

    [major] ->
        Version major 0 0

    [] ->
        error "could not detect version of elm-compiler you are using"


data Version = Version
    { major :: Int
    , minor :: Int
    , patch :: Int
    }
    deriving (Eq, Ord)


initialVersion :: Version
initialVersion =
    Version 1 0 0

dummyVersion :: Version
dummyVersion =
    Version 0 0 0


bumpPatch :: Version -> Version
bumpPatch (Version major minor patch) =
    Version major minor (patch + 1)

bumpMinor :: Version -> Version
bumpMinor (Version major minor _patch) =
    Version major (minor + 1) 0

bumpMajor :: Version -> Version
bumpMajor (Version major _minor _patch) =
    Version (major + 1) 0 0


-- FILTERING

filterLatest :: (Ord a) => (Version -> a) -> [Version] -> [Version]
filterLatest characteristic versions =
    map last (List.groupBy ((==) `on` characteristic) (List.sort versions))


majorAndMinor :: Version -> (Int,Int)
majorAndMinor (Version major minor _patch) =
    (major, minor)


-- CONVERSIONS

toString :: Version -> String
toString (Version major minor patch) =
    show major ++ "." ++ show minor ++ "." ++ show patch


fromString :: String -> Maybe Version
fromString string =
      case splitNumbers string of
        Just [major, minor, patch] ->
            Just (Version major minor patch)
        _ -> Nothing
    where
      splitNumbers :: String -> Maybe [Int]
      splitNumbers ns =
          case span isDigit ns of
            ("", _) ->
                Nothing

            (numbers, []) ->
                Just [ read numbers ]

            (numbers, '.':rest) ->
                (read numbers :) <$> splitNumbers rest

            _ -> Nothing


instance Binary Version where
    get = Version <$> get <*> get <*> get
    put (Version major minor patch) =
        do put major
           put minor
           put patch


instance FromJSON Version where
    parseJSON (String text) =
        let string = T.unpack text in
        case fromString string of
          Just v -> return v
          Nothing ->
              fail $ unlines
                 [ "Dependency file has an invalid version number: " ++ string
                 , "Must have format MAJOR.MINOR.PATCH (e.g. 0.1.2)"
                 ]

    parseJSON _ =
        fail "Version number must be stored as a string."


instance ToJSON Version where
    toJSON version =
        toJSON (toString version)

