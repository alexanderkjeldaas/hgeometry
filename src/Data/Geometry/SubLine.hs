{-# LANGUAGE TemplateHaskell  #-}
module Data.Geometry.SubLine where

import           Control.Applicative
import qualified Data.Foldable as F
import qualified Data.Traversable as T
import Control.Lens
import Data.Ext
import Data.Geometry.Interval
import Data.Geometry.Line.Internal
import Data.Geometry.Point
import Data.Geometry.Properties
import Data.Geometry.Vector
import Data.Maybe
import Data.Range

import Data.Vinyl

--------------------------------------------------------------------------------

-- | Part of a line. The interval is ranged based on the unit-vector of the
-- line l, and s.t.t zero is the anchorPoint of l.
data SubLine d p r = SubLine { _line     :: Line d r
                             , _subRange :: Interval p r
                             }

makeLenses ''SubLine

type instance Dimension (SubLine d p r) = d
type instance NumType   (SubLine d p r) = r


-- instance Functor (SubLine d p) where
--   fmap = T.fmapDefault

-- instance F.Foldable (SubLine d p) where
--   foldMap = T.foldMapDefault

-- instance T.Traversable (SubLine d p) where
--   traverse f (SubLine l r) = SubLine <$> T.traverse l
--                                      <*> T.traverse f r

-- instance Functor (SubLine d p) where
--   fmap f (SubLine l r) = SubLine ()


-- | Get the point at the given position along line, where 0 corresponds to the
-- anchorPoint of the line, and 1 to the point anchorPoint .+^ directionVector
pointAt              :: (Num r, Arity d) => r -> Line d r -> Point d r
pointAt a (Line p v) = p .+^ (a *^ v)

-- | Annotate the subRange with the actual ending points
fixEndPoints    :: (Num r, Arity d) => SubLine d p r -> SubLine d (Point d r :+ p) r
fixEndPoints sl = sl&subRange %~ f
  where
    ptAt           = flip pointAt (sl^.line)
    label (c :+ e) = (c :+ (ptAt c :+ e))
    f (Interval (Range l u)) = Interval $ Range (l&unEndPoint %~ label)
                                                (u&unEndPoint %~ label)


-- | given point p on line (Line q v), Get the scalar lambda s.t.
-- p = q + lambda v
toOffset              :: (Eq r, Fractional r, Arity d) => Point d r -> Line d r -> r
toOffset p (Line q v) = fromJust $ scalarMultiple (q .-. p) v

type instance IntersectionOf (SubLine 2 p r) (SubLine 2 q r) = [ NoIntersection
                                                               , Point 2 r
                                                               , SubLine 2 () r
                                                               ]


instance (Ord r, Fractional r) =>
         (SubLine 2 p r) `IsIntersectableWith` (SubLine 2 p r) where

  nonEmptyIntersection = defaultNonEmptyIntersection

  (SubLine l r) `intersect` (SubLine m s) = match (l `intersect` m) $
         (H $ \NoIntersection -> coRec NoIntersection)
      :& (H $ \p@(Point _)    -> if (toOffset p l) `inInterval` r
                                    &&
                                    (toOffset p m) `inInterval` s
                                 then coRec p
                                 else coRec NoIntersection)
      :& (H $ \l              -> match (r `intersect` s') $
                                      (H $ \NoIntersection -> coRec NoIntersection)
                                   :& (H $ \i              -> coRec $ SubLine l (f i))
                                   :& RNil
           )
      :& RNil
    where
      s' = shiftLeft' (toOffset (m^.anchorPoint) l) s

      f (Interval r') = Interval $ fmap (set extra ()) r'
