-- |
-- Module      :  Text.MMark.Extension.TableOfContents
-- Copyright   :  © 2017–2018 Mark Karpov
-- License     :  BSD 3 clause
--
-- Maintainer  :  Mark Karpov <markkarpov92@gmail.com>
-- Stability   :  experimental
-- Portability :  portable
--
-- Place this markup in markdown document where you want table of contents
-- to be inserted:
--
-- > ```toc
-- > ```
--
-- You may use something different than @\"toc\"@ as the info string of the
-- code block.

{-# LANGUAGE LambdaCase #-}

module Text.MMark.Extension.TableOfContents
  ( Toc
  , tocScanner
  , toc )
where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Maybe (maybeToList)
import Data.Text (Text)
import Text.MMark.Extension (Extension, Block (..), Inline (..), Bni)
import qualified Control.Foldl        as L
import qualified Data.List.NonEmpty   as NE
import qualified Text.MMark.Extension as Ext

-- | An opaque type representing table of contents produced by the
-- 'tocScanner' scanner.

newtype Toc = Toc [(Int, NonEmpty Inline)]

-- | The scanner builds table of contents 'Toc' that can then be passed to
-- 'toc' to obtain an extension that renders the table of contents in HTML.

tocScanner
  :: (Int -> Bool)
     -- ^ Whether to include a header of this level (1–6)
  -> L.Fold Bni Toc
tocScanner p = fmap (Toc . ($ [])) . Ext.scanner id $ \xs block ->
  case block of
    Heading1 x -> f 1 x xs
    Heading2 x -> f 2 x xs
    Heading3 x -> f 3 x xs
    Heading4 x -> f 4 x xs
    Heading5 x -> f 5 x xs
    Heading6 x -> f 6 x xs
    _          -> xs
  where
    f n a as =
      if p n
        then as . ((n, a):)
        else as

-- | Create an extension that replaces a certain code block with previously
-- constructed table of contents.

toc
  :: Text -- ^ Label of the code block to replace by the table of contents
  -> Toc  -- ^ Previously generated by 'tocScanner'
  -> Extension
toc label (Toc xs) = Ext.blockTrans $ \case
  old@(CodeBlock mlabel _) ->
    case NE.nonEmpty xs of
      Nothing -> old
      Just ns ->
        if mlabel == pure label
          then renderToc ns
          else old
  other -> other

-- | Construct 'Bni' for a table of contents from given collection of
-- headers. This is a non-public helper.

renderToc :: NonEmpty (Int, NonEmpty Inline) -> Bni
renderToc = UnorderedList . NE.unfoldr f
  where
    f ((n,x) :| xs) =
      let (sitems, fitems) = span ((> n) . fst) xs
          url = Ext.headerFragment (Ext.headerId x)
      in ( Naked (Link x url Nothing :| [])
           : maybeToList (renderToc <$> NE.nonEmpty sitems)
         , NE.nonEmpty fitems )
