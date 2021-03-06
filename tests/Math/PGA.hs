{- HSlice. 
 - Copyright 2020 Julia Longtin
 -
 - This program is free software: you can redistribute it and/or modify
 - it under the terms of the GNU Affero General Public License as published by
 - the Free Software Foundation, either version 3 of the License, or
 - (at your option) any later version.
 -
 - This program is distributed in the hope that it will be useful,
 - but WITHOUT ANY WARRANTY; without even the implied warranty of
 - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 - GNU Affero General Public License for more details.

 - You should have received a copy of the GNU Affero General Public License
 - along with this program.  If not, see <http://www.gnu.org/licenses/>.
 -}

-- Shamelessly stolen from ImplicitCAD.

module Math.PGA (linearAlgSpec, geomAlgSpec, proj2DGeomAlgSpec, facetSpec) where

-- Be explicit about what we import.
import Prelude (($), Bool(True, False), (<$>), length, Either(Left, Right), foldl, head, sqrt)

-- Hspec, for writing specs.
import Test.Hspec (describe, Spec, it)

import Data.Maybe (fromJust, Maybe(Just, Nothing))

-- The numeric type in HSlice.
import Graphics.Slicer (ℝ)

-- A euclidian point.
import Graphics.Slicer.Math.Definitions(Point2(Point2), Contour(PointSequence), roundPoint2)

-- Our Geometric Algebra library.
import Graphics.Slicer.Math.GeometricAlgebra (GNum(GEZero, GEPlus, G0), GVal(GVal), GVec(GVec), addValPair, subValPair, addVal, subVal, addVecPair, subVecPair, mulScalarVec, divVecScalar, scalarPart, vectorPart, (•), (∧), (⋅))

-- Our 2D Projective Geometric Algebra library.
import Graphics.Slicer.Math.PGA (PPoint2(PPoint2), PLine2(PLine2), eToPPoint2, eToPLine2, join2PPoint2, translatePerp, pointOnPerp, distancePPointToPLine, pPointsOnSameSideOfPLine)

import Graphics.Slicer.Math.Line (makeLineSegsLooped, pointsFromLineSegs, LineSeg(LineSeg))

-- Our Contour library.
import Graphics.Slicer.Math.Contour (contourContainsContour, getContours)
import Graphics.Slicer.Machine.Contour (shrinkContour, expandContour)

-- Our Infill library.
import Graphics.Slicer.Machine.Infill (InfillType(Horiz, Vert), makeInfill)

-- Our Facet library.
import Graphics.Slicer.Math.Face (convexMotorcycles, leftRegion, rightRegion, Node(Node), Spine(Spine), Face(Face), makeFirstNodes, Motorcycle(Motorcycle), StraightSkeleton(StraightSkeleton), findStraightSkeleton, facesFromStraightSkeleton, addLineSegs, NodeTree(NodeTree), averageNodes, getFirstArc)

-- Our Utility library, for making these tests easier to read.
import Math.Util ((-->))

-- Default all numbers in this file to being of the type ImplicitCAD uses for values.
default (ℝ)

linearAlgSpec :: Spec
linearAlgSpec = do
  describe "Contours" $ do
    it "contours made from a list of point pairs retain their order" $
      getContours cl1 --> [c1]
    it "contours made from an out of order list of point pairs is put into order" $
      getContours oocl1 --> [c1]
    it "contours converted from points to lines then back to points give the input list" $
      pointsFromLineSegs (makeLineSegsLooped cp1) --> Right cp1
    it "a bigger contour containing a smaller contour is detected by contourContainsContour" $
      contourContainsContour c1 c2 --> True
    it "a smaller contour contained in a bigger contour is not detected by contourContainsContour" $
      contourContainsContour c2 c1 --> False
    it "two contours that do not contain one another are not detected by contourContainsContour" $
      contourContainsContour c1 c3 --> False
    it "a contour shrunk has the same amount of points as the input contour" $
      length ( pointsOfContour $ fromJust $ shrinkContour 0.1 [] c1) --> length (pointsOfContour c1)
    it "a contour shrunk by zero is the same as the input contour" $
      fromJust (shrinkContour 0 [] c1) --> c1
    it "a contour expanded has the same amount of points as the input contour" $
      length (pointsOfContour $ fromJust $ expandContour 0.1 [] c1) --> length (pointsOfContour c1)
    it "a contour shrunk and expanded is about equal to where it started" $
      (roundPoint2 <$> pointsOfContour (fromJust $ expandContour 0.1 [] $ fromJust $ shrinkContour 0.1 [] c2)) --> roundPoint2 <$> pointsOfContour c2
  describe "Infill" $ do
    it "infills exactly one line inside of a box big enough for only one line (Horizontal)" $
      makeInfill c1 [] 0.5 Horiz --> [[LineSeg (Point2 (0,0.5)) (Point2 (1,0))]]
    it "infills exactly one line inside of a box big enough for only one line (Vertical)" $
      makeInfill c1 [] 0.5 Vert --> [[LineSeg (Point2 (0.5,0)) (Point2 (0,1))]]
  describe "Translation" $ do
    it "a translated line translated back is the same line" $
      translatePerp (translatePerp (eToPLine2 l1) 1) (-1) --> eToPLine2 l1
    it "a projection on the perpendicular bisector of an axis aligned line is on the other axis (1 of 2)" $
      pointOnPerp (LineSeg (Point2 (0,0)) (Point2 (0,1))) (Point2 (0,0)) 1 --> Point2 (-1,0)
    it "a projection on the perpendicular bisector of an axis aligned line is on the other axis (2 of 2)" $
      pointOnPerp (LineSeg (Point2 (0,0)) (Point2 (1,0))) (Point2 (0,0)) 1 --> Point2 (0,1)
    it "the distance between a point at (1,1) and a line on the X axis is 1" $
      distancePPointToPLine (eToPPoint2 $ Point2 (1,1)) (eToPLine2 $ LineSeg (Point2 (0,0)) (Point2 (1,0))) --> 1
    it "the distance between a point at (2,2) and a line on the Y axis is 2" $
      distancePPointToPLine (eToPPoint2 $ Point2 (2,2)) (eToPLine2 $ LineSeg (Point2 (0,0)) (Point2 (0,-1))) --> 2
  where
    -- FIXME: reversing this breaks the infill tests?
    cp1 = [Point2 (1,0), Point2 (1,1), Point2 (0,1), Point2 (0,0)]
    oocl1 = [(Point2 (1,0), Point2 (0,0)), (Point2 (0,1), Point2 (1,1)), (Point2 (0,0), Point2 (0,1)), (Point2 (1,1), Point2 (1,0))]
    cl1 = [(Point2 (0,0), Point2 (0,1)), (Point2 (0,1), Point2 (1,1)), (Point2 (1,1), Point2 (1,0)), (Point2 (1,0), Point2 (0,0))]
    l1 = LineSeg (Point2 (1,1)) (Point2 (2,2))
    c1 = PointSequence cp1
    c2 = PointSequence [Point2 (0.75,0.25), Point2 (0.75,0.75), Point2 (0.25,0.75), Point2 (0.25,0.25)]
    c3 = PointSequence [Point2 (3,0), Point2 (3,1), Point2 (2,1), Point2 (2,0)]
    pointsOfContour (PointSequence contourPoints) = contourPoints

geomAlgSpec :: Spec
geomAlgSpec = do
  describe "GVals" $ do
    -- 1e1+1e1 = 2e1
    it "adds two values with a common basis vector" $
      addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> [GVal 2 [GEPlus 1]]
    -- 1e1+1e2 = e1+e2
    it "adds two values with different basis vectors" $
      addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2]) --> [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 2e1-1e1 = e1
    it "subtracts two values with a common basis vector" $
      subValPair (GVal 2 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 1]]
    -- 1e1-1e2 = e1-e2
    it "subtracts two values with different basis vectors" $
      subValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2]) --> [GVal 1 [GEPlus 1], GVal (-1) [GEPlus 2]]
    -- 1e1-1e1 = 0
    it "subtracts two identical values with a common basis vector and gets nothing" $
      subValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 1]) --> []
    -- 1e0+1e1+1e2 = e0+e1+e2
    it "adds a value to a list of values" $
      addVal [GVal 1 [GEZero 1], GVal 1 [GEPlus 1]] (GVal 1 [GEPlus 2]) --> [GVal 1 [GEZero 1], GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 2e1+1e2-1e1 = e1+e2
    it "subtracts a value from a list of values" $
      subVal [GVal 2 [GEPlus 1], GVal 1 [GEPlus 2]] (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]]
    -- 1e1+1e2-1e1 = e2
    it "subtracts a value from a list of values, eliminating an entry with a like basis vector" $
      subVal [GVal 1 [GEPlus 1], GVal 1 [GEPlus 2]] (GVal 1 [GEPlus 1]) --> [GVal 1 [GEPlus 2]]
  describe "GVecs" $ do
    -- 1e1+1e1 = 2e1
    it "adds two (multi)vectors" $
      addVecPair (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 1]]) --> GVec [GVal 2 [GEPlus 1]]
    -- 1e1-1e1 = 0
    it "subtracts a (multi)vector from another (multi)vector" $
      subVecPair (GVec [GVal 1 [GEPlus 1]]) (GVec [GVal 1 [GEPlus 1]]) --> GVec []
    -- 2*1e1 = 2e1
    it "multiplies a (multi)vector by a scalar" $
      mulScalarVec 2 (GVec [GVal 1 [GEPlus 1]]) --> GVec [GVal 2 [GEPlus 1]]
    -- 2e1/2 = e1
    it "divides a (multi)vector by a scalar" $
      divVecScalar (GVec [GVal 2 [GEPlus 1]]) 2 --> GVec [GVal 1 [GEPlus 1]]
    -- 1e1|1e2 = 0
    it "the dot product of two orthoginal basis vectors is nothing" $
      GVec [GVal 1 [GEPlus 1]] ⋅ GVec [GVal 1 [GEPlus 2]] --> GVec []
    it "the dot product of two vectors is comutative (a⋅b == b⋅a)" $
      GVec (addValPair (GVal 1 [GEPlus 1]) (GVal 1 [GEPlus 2])) ⋅ GVec (addValPair (GVal 2 [GEPlus 2]) (GVal 2 [GEPlus 2])) -->
      GVec (addValPair (GVal 2 [GEPlus 1]) (GVal 2 [GEPlus 2])) ⋅ GVec (addValPair (GVal 1 [GEPlus 2]) (GVal 1 [GEPlus 2]))
    -- 2e1|2e1 = 4
    it "the dot product of a vector with itsself is it's magnitude squared" $
      scalarPart (GVec [GVal 2 [GEPlus 1]] ⋅ GVec [GVal 2 [GEPlus 1]]) --> 4
    -- (2e1^1e2)|(2e1^1e2) = -4
    it "the dot product of a bivector with itsself is the negative of magnitude squared" $
      scalarPart (GVec [GVal 2 [GEPlus 1, GEPlus 2]] ⋅ GVec [GVal 2 [GEPlus 1, GEPlus 2]]) --> (-4)
    -- 1e1^1e1 = 0
    it "the wedge product of two identical vectors is nothing" $
      vectorPart (GVec [GVal 1 [GEPlus 1]] ∧ GVec [GVal 1 [GEPlus 1]]) --> GVec []
    it "the wedge product of two vectors is anti-comutative (u∧v == -v∧u)" $
      GVec [GVal 1 [GEPlus 1]] ∧ GVec [GVal 1 [GEPlus 2]] -->
      GVec [GVal (-1) [GEPlus 2]] ∧ GVec [GVal 1 [GEPlus 1]]
  describe "Operators" $ do
    it "the multiply operations that should result in nothing all result in nothing" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 ] --> GVec []
    it "the multiply operations that should result in 1 all result in 1" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEPlus 1]]
                                 , GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEPlus 2]]
                                 ] --> GVec [GVal 2 [G0]]
    it "the multiply operations that should result in -1 all result in -1" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal (-1) [G0]]
    it "the multiply operations that should result in e0 all result in e0" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 2]]
                                 ] --> GVec [GVal 2 [GEZero 1]]
    it "the multiply operations that should result in e1 all result in e1" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 2]]
                                 ] --> GVec [GVal 1 [GEPlus 1]]
    it "the multiply operations that should result in e2 all result in e2" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal 1 [GEPlus 2]]
    it "the multiply operations that should result in e01 all result in e01" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEPlus 1]]
                                 , GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 2]]
                                 ] --> GVec [GVal 4 [GEZero 1, GEPlus 1]]
    it "the multiply operations that should result in e02 all result in e02" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal 2 [GEZero 1, GEPlus 2]]
    it "the multiply operations that should result in e12 all result in e12" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEPlus 2]]
                                 ] --> GVec [GVal 1 [GEPlus 1, GEPlus 2]]
    it "the multiply operations that should result in e012 all result in e012" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEZero 1]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1]] • GVec [GVal 1 [GEPlus 2]]
                                 , GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1]]
                                 ] --> GVec [GVal 4 [GEZero 1, GEPlus 1, GEPlus 2]]
    it "the multiply operations that should result in -e0 all result in -e0" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal (-4) [GEZero 1]]
    it "the multiply operations that should result in -e1 all result in -e1" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal (-1) [GEPlus 1]]
    it "the multiply operations that should result in -e2 all result in -e2" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1]]
                                 ] --> GVec [GVal (-1) [GEPlus 2]]
    it "the multiply operations that should result in -e01 all result in -e01" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1, GEPlus 2]]
                                 ] --> GVec [GVal (-2) [GEZero 1, GEPlus 1]]
    it "the multiply operations that should result in -e02 all result in -e02" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEZero 1]]
                                 , GVec [GVal 1 [GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEZero 1, GEPlus 1]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1]]
                                 ] --> GVec [GVal (-4) [GEZero 1, GEPlus 2]]
    it "the multiply operations that should result in -e12 all result in -e12" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 2]] • GVec [GVal 1 [GEPlus 1]]
                                 ] --> GVec [GVal (-1) [GEPlus 1, GEPlus 2]]
    it "the multiply operations that should result in -e012 all result in -e012" $
      foldl addVecPair (GVec []) [
                                   GVec [GVal 1 [GEPlus 1]] • GVec [GVal 1 [GEZero 1, GEPlus 2]]
                                 , GVec [GVal 1 [GEZero 1, GEPlus 2]] • GVec [GVal 1 [GEPlus 1]]
                                 ] --> GVec [GVal (-2) [GEZero 1, GEPlus 1, GEPlus 2]]

proj2DGeomAlgSpec :: Spec
proj2DGeomAlgSpec = do
  describe "Points" $ do
    -- ((1e0^1e1)+(-1e0^1e2)+(1e1+1e2))|((-1e0^1e1)+(1e0^1e2)+(1e1+1e2)) = -1
    it "the dot product of any two projective points is -1" $
      scalarPart (rawPPoint2 (1,1) ⋅ rawPPoint2 (-1,-1)) --> (-1)
  describe "Lines" $ do
    -- (-2e2)*2e1 = 4e12
    it "the intersection of a line along the X axis and a line along the Y axis is the origin point" $
      (\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (-1,0)) (Point2 (2,0)))) ∧ (\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (0,-1)) (Point2 (0,2)))) --> GVec [GVal 4 [GEPlus 1, GEPlus 2]]
    -- (-2e0+1e1)^(2e0-1e2) = -1e01+2e02-e12
    it "the intersection of a line two points above the X axis, and a line two points to the right of the Y axis is at (2,2) in the upper right quadrant" $
      vectorPart ((\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (2,0)) (Point2 (0,1)))) ∧ (\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (0,2)) (Point2 (1,0))))) -->
      GVec [GVal (-2) [GEZero 1, GEPlus 1], GVal 2 [GEZero 1, GEPlus 2], GVal (-1) [GEPlus 1, GEPlus 2]]
    -- (2e0+1e1-1e2)*(2e0+1e1-1e2) = 2
    it "the geometric product of two overlapping lines is only a Scalar" $
      scalarPart ((\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (-1,1)) (Point2 (1,1)))) • (\(PLine2 a) -> a) (eToPLine2 (LineSeg (Point2 (-1,1)) (Point2 (1,1))))) --> 2.0
    it "A line constructed from a line segment is equal to one constructed from joining two points" $
      eToPLine2 (LineSeg (Point2 (0,0)) (Point2 (1,1))) --> join2PPoint2 (eToPPoint2 (Point2 (0,0))) (eToPPoint2 (Point2 (1,1)))
    it "two points on the same side of a line show as being on the same side of the line" $
      pPointsOnSameSideOfPLine (eToPPoint2 (Point2 (-1,0))) (eToPPoint2 (Point2 (-1,-1))) (eToPLine2 (LineSeg (Point2 (0,0)) (Point2 (0,1)))) --> Just True
    it "two points on different sides of a line show as being on different sides of a line" $
      pPointsOnSameSideOfPLine (eToPPoint2 (Point2 (-1,0))) (eToPPoint2 (Point2 (1,0))) (eToPLine2 (LineSeg (Point2 (0,0)) (Point2 (0,1)))) --> Just False
  where
    rawPPoint2 (x,y) = (\(PPoint2 v) -> v) $ eToPPoint2 (Point2 (x,y))

facetSpec :: Spec
facetSpec = do
  describe "Motorcycles" $ do
    it "finds the inside motorcycle of a 90 degree angle(toward, away)(to the left)" $
      getFirstArc (LineSeg (Point2 (0,1.0)) (Point2 (0.0,-1.0))) (LineSeg (Point2 (0,0)) (Point2 (1.0,0.0))) --> PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])
    it "finds the inside motorcycle of a 90 degree angle(toward, away)(to the right)" $
      getFirstArc (LineSeg (Point2 (0,1.0)) (Point2 (0.0,-1.0))) (LineSeg (Point2 (0,0)) (Point2 (-1.0,0.0))) --> PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])
    it "finds the inside motorcycle of a 135 degree angle(toward, away)(to the left)" $
      getFirstArc (LineSeg (Point2 (0,1.0)) (Point2 (0.0,-1.0))) (LineSeg (Point2 (0,0)) (Point2 (1.0,-1.0))) --> PLine2 (GVec [GVal (0.3826834323650899) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]])
    it "finds the inside motorcycle of a 135 degree angle(toward, away)(to the right)" $
      getFirstArc (LineSeg (Point2 (0,1.0)) (Point2 (0.0,-1.0))) (LineSeg (Point2 (0,0)) (Point2 (-1.0,-1.0))) --> PLine2 (GVec [GVal (0.3826834323650899) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])

    it "finds the inside motorcycle for a given pair of line segments (first corner)" $
      makeFirstNodes corner1 --> [Node (Left ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))),
                                              (LineSeg (Point2 (1.0,1.0)) (Point2 (-1.0,-1.0)))))
                                        (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])))
                                 ]
    it "finds the inside motorcycle for a given pair of line segments (second corner)" $
      makeFirstNodes corner2 --> [Node (Left ((LineSeg (Point2 (1.0,1.0)) (Point2 (-1.0,-1.0))),
                                              (LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,-1.0)))))
                                        (Just (PLine2 (GVec [GVal (-1.0) [GEPlus 2]])))
                                 ]
    it "finds the inside motorcycle for a given pair of line segments (third corner)" $
      makeFirstNodes corner3 --> [Node (Left ((LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,-1.0))),
                                              (LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                        (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])))
                                 ]
    it "finds the inside motorcycle for a given pair of line segments (fourth corner)" $
      makeFirstNodes corner4 --> [Node (Left ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))),
                                              (LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0)))))
                                        (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                 ]
    it "finds the intersecting line resulting from two nodes (corner3 and corner4)" $
      averageNodes (head $ makeFirstNodes corner3) (head $ makeFirstNodes corner4) --> Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])),
                                                                                                    (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]]))])
                                                                                              (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (0.19509032201612836) [GEPlus 2]])))
    it "finds one convex motorcycle in a simple shape" $
      convexMotorcycles c1 --> [Motorcycle (LineSeg (Point2 (1.0,-1.0)) (Point2 (-1.0,1.0))) (LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,-1.0))) (PLine2 (GVec [GVal (-2.0) [GEPlus 1]]))]
    it "finds the straight skeleton of the left side of our first simple shape." $
      leftRegion  c0 (head $ convexMotorcycles c0) --> leftRegion c4 (head $ convexMotorcycles c4)
    it "finds the straight skeleton of the right side of our first simple shape." $
      rightRegion c0 (head $ convexMotorcycles c0) --> rightRegion c4 (head $ convexMotorcycles c4)
    it "finds the straight skeleton of the left side of our first simple shape." $
      leftRegion  c1 (head $ convexMotorcycles c1) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))), (LineSeg (Point2 (1.0,1.0)) (Point2 (0,-2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (1.0,1.0)) (Point2 (0,-2.0))),(LineSeg (Point2 (1.0,-1.0)) (Point2 (-1.0,1.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (0.3826834323650897) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (0.3826834323650897) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (0.19509032201612836) [GEPlus 1], GVal (0.9807852804032305) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the right side of our first simple shape." $
      rightRegion c1 (head $ convexMotorcycles c1) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,-1.0))), (LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (-0.3826834323650897) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0))), (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (-0.3826834323650897) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (0.19509032201612836) [GEPlus 1], GVal (-0.9807852804032305) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the left side of our second simple shape." $
      leftRegion  c2 (head $ convexMotorcycles c2) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0))), (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))), (LineSeg (Point2 (1.0,1.0)) (Point2 (-1.0,-1.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (-0.9807852804032305) [GEPlus 1], GVal (0.19509032201612836) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the right side of our second simple shape." $
      rightRegion c2 (head $ convexMotorcycles c2) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,-1.0))),(LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))),(LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (0.9238795325112867) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (0.19509032201612836) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the left side of our third simple shape." $
      leftRegion  c3 (head $ convexMotorcycles c3) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))),(LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0))),(LineSeg (Point2 (-1.0,1.0)) (Point2 (1.0,-1.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (-0.3826834323650897) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (-0.3826834323650897) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (-0.19509032201612836) [GEPlus 1], GVal (-0.9807852804032305) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the right side of our third simple shape." $
      rightRegion c3 (head $ convexMotorcycles c3) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,1.0))), (LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (0.3826834323650897) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0))),(LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (0.3826834323650897) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (-0.19509032201612836) [GEPlus 1], GVal (0.9807852804032305) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the left side of our fourth simple shape." $
      leftRegion  c4 (head $ convexMotorcycles c4) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0))), (LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))), (LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of the right side of our fourth simple shape." $
      rightRegion c4 (head $ convexMotorcycles c4) --> NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0))),(LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]])))
                                                                  ,Node (Left  ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))),(LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  ]
                                                                , [Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]])),
                                                                                (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))])
                                                                          (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (-0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]])))
                                                                  ]
                                                                ]
    it "finds the straight skeleton of our first simple shape." $
      findStraightSkeleton c0 [] --> StraightSkeleton [[NodeTree [ [Node (Left  ((LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0))),(LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                   ,Node (Left  ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))), (LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]])))
                                                                   ]
                                                                 , [Node (Right [(PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ,NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0))), (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]])))
                                                                   ,Node (Left  ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))), (LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                   ]
                                                                 , [Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal  (-0.9238795325112867) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (-0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ,NodeTree [ [Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0))), (LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (2.0) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ]] []
    it "finds the straight skeleton of our fifth simple shape." $
      findStraightSkeleton c5 [] --> StraightSkeleton [[NodeTree [ [Node (Left  ((LineSeg (Point2 (2.0,0.0)) (Point2 (-1.0,-1.0))), (LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-0.5411961001461969) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (0.3826834323650899) [GEPlus 2]])))
                                                                  , Node (Left  ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))), (LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]])))
                                                                  ]
                                                                 , [Node (Right [(PLine2 (GVec [GVal (-0.5411961001461969) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (0.3826834323650899) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (-0.7653668647301793) [GEZero 1], GVal (0.9238795325112867) [GEPlus 1], GVal (-0.38268343236508967) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ,NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0))), (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]])))
                                                                   ,Node (Left  ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))), (LineSeg (Point2 (1.0,1.0)) (Point2 (1.0,-1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (0.5411961001461969) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (0.3826834323650899) [GEPlus 2]])))
                                                                   ]
                                                                  ,[Node (Right [(PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (0.5411961001461969) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (0.3826834323650899) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (0.7653668647301793) [GEZero 1], GVal (-0.9238795325112867) [GEPlus 1], GVal (-0.38268343236508967) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ,NodeTree [ [Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0))), (LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (2.0) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                       ,NodeTree [ [Node (Left  ((LineSeg (Point2 (1.0,1.0)) (Point2 (1.0,-1.0))), (LineSeg (Point2 (2.0,0.0)) (Point2 (-1.0,-1.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-2.0) [GEPlus 2]])))
                                                                   ]
                                                                 ]
                                                        ]] []
    it "finds the straight skeleton of our sixth simple shape." $
      findStraightSkeleton c6 [] --> StraightSkeleton [[NodeTree [ [Node (Left ((LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0))),  (LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  , Node (Left ((LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0))),  (LineSeg (Point2 (1.0,-1.0)) (Point2 (-0.5,0.0)))))
                                                                          (Just (PLine2 (GVec [GVal 0.7071067811865475 [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])))
                                                                  , Node (Left ((LineSeg (Point2 (1.0,-1.0)) (Point2 (-0.5,0.0))), (LineSeg (Point2 (0.5,-1.0)) (Point2 (-0.5,1.0)))))
                                                                          (Just (PLine2 (GVec [GVal (-0.9510565162951536) [GEZero 1], GVal (0.8506508083520399) [GEPlus 1], GVal (-0.5257311121191337) [GEPlus 2]])))
                                                                   ],
                                                                   [Node (Right [(PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.9510565162951536) [GEZero 1], GVal (0.8506508083520399) [GEPlus 1], GVal (-0.5257311121191337) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (-0.606432399999752) [GEZero 1], GVal (0.9932897335288758) [GEPlus 1], GVal (0.11565251949756605) [GEPlus 2]])))
                                                                   ],
                                                                   [Node (Right [(PLine2 (GVec [GVal (-0.606432399999752) [GEZero 1], GVal (0.9932897335288758) [GEPlus 1], GVal (0.11565251949756605) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (-0.6961601101968017) [GEZero 1], GVal 0.328526568895664 [GEPlus 1], GVal 0.9444947292227959 [GEPlus 2]])))
                                                                   ]
                                                                 ],
                                                        NodeTree [ [Node (Left  ((LineSeg (Point2 (0.0,0.0)) (Point2 (-0.5,-1.0))), (LineSeg (Point2 (-0.5,-1.0)) (Point2 (-0.5,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (0.9510565162951536) [GEZero 1], GVal (0.8506508083520399) [GEPlus 1], GVal (0.5257311121191337) [GEPlus 2]])))
                                                                  , Node (Left  ((LineSeg (Point2 (-0.5,-1.0)) (Point2 (-0.5,0.0))), (LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0)))))
                                                                           (Just (PLine2 (GVec [GVal 0.7071067811865475 [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                  , Node (Left  ((LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0))), (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))))
                                                                           (Just (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]])))
                                                                   ]
                                                                 , [Node (Right [(PLine2 (GVec [GVal (0.9510565162951536) [GEZero 1], GVal (0.8506508083520399) [GEPlus 1], GVal (0.5257311121191337) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal 0.7071067811865475 [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal (0.606432399999752) [GEZero 1], GVal (0.9932897335288758) [GEPlus 1], GVal (-0.11565251949756605) [GEPlus 2]])))
                                                                   ]
                                                                 , [Node (Right [(PLine2 (GVec [GVal (0.606432399999752) [GEZero 1], GVal (0.9932897335288758) [GEPlus 1], GVal (-0.11565251949756605) [GEPlus 2]])),
                                                                                 (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (-0.7071067811865475) [GEPlus 2]]))])
                                                                           (Just (PLine2 (GVec [GVal 0.6961601101968017 [GEZero 1], GVal 0.328526568895664 [GEPlus 1], GVal (-0.9444947292227959) [GEPlus 2]])))
                                                                   ]
                                                                 ],
                                                        NodeTree [ [Node (Left ((LineSeg (Point2 (0.5,-1.0)) (Point2 (-0.5,1.0))), (LineSeg (Point2 (0.0,0.0)) (Point2 (-0.5,-1.0)))))
                                                                         (Just (PLine2 (GVec [GVal (-2.0) [GEPlus 1]])))]]
                                                       ]] []
    it "finds faces (out of order) from a straight skeleton" $
      facesFromStraightSkeleton (findStraightSkeleton c0 []) --> [ Face (LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)))
                                                                        (PLine2 (GVec [GVal (-0.541196100146197) [GEZero 1], GVal (0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]]))
                                                                        []
                                                                        (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))
                                                                 , Face (LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)))
                                                                        (PLine2 (GVec [GVal (-0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))
                                                                        []
                                                                        (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]]))
                                                                 , Face (LineSeg (Point2 (1.0,1.0)) (Point2 (0.0,-2.0)))
                                                                        (PLine2 (GVec [GVal (0.7071067811865475) [GEPlus 1], GVal (0.7071067811865475) [GEPlus 2]]))
                                                                        [(PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]]))]
                                                                        (PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (-0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]]))
                                                                 , Face (LineSeg (Point2 (0.0,0.0)) (Point2 (-1.0,1.0)))
                                                                        (PLine2 (GVec [GVal (0.541196100146197) [GEZero 1], GVal (-0.3826834323650897) [GEPlus 1], GVal (-0.9238795325112867) [GEPlus 2]]))
                                                                        [(PLine2 (GVec [GVal (0.4870636221857319) [GEZero 1], GVal (-0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]]))]
                                                                        (PLine2 (GVec [GVal 2.0    [GEPlus 2]]))
                                                                 , Face (LineSeg (Point2 (-1.0,-1.0)) (Point2 (1.0,1.0)))
                                                                        (PLine2 (GVec [GVal 2.0    [GEPlus 2]]))
                                                                        []
                                                                        (PLine2 (GVec [GVal (-0.4870636221857319) [GEZero 1], GVal (0.9807852804032305) [GEPlus 1], GVal (-0.19509032201612836) [GEPlus 2]]))
                                                                        ]
-- VERIFYME: works, but i don't yet trust it's output.
--    it "places lines on a set of faces" $
--      (addLineSegs 0.25 Nothing <$> facesFromStraightSkeleton (findStraightSkeleton c0 [])) --> [([], Nothing)]
    it "finds faces from a triangle" $
      facesFromStraightSkeleton (findStraightSkeleton triangle []) --> [Face (LineSeg (Point2 (1.0,1.73205080756887729)) (Point2 (1.0,-1.7320508075688772)))
                                                                             (PLine2 (GVec [GVal (-1.0000000000000002) [GEZero 1], GVal (0.5000000000000001) [GEPlus 1], GVal (0.8660254037844387) [GEPlus 2]]))
                                                                             []
                                                                             (PLine2 (GVec [GVal (1.0) [GEZero 1], GVal (-1.0) [GEPlus 1]])),
                                                                        Face (LineSeg (Point2 (2.0,0.0)) (Point2 (-2.0,0.0)))
                                                                             (PLine2 (GVec [GVal (0.5000000000000001) [GEPlus 1], GVal (-0.8660254037844387) [GEPlus 2]]))
                                                                             []
                                                                             (PLine2 (GVec [GVal (-1.0000000000000002) [GEZero 1], GVal (0.5000000000000001) [GEPlus 1], GVal (0.8660254037844387) [GEPlus 2]])),
                                                                        Face (LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,1.7320508075688772)))
                                                                             (PLine2 (GVec [GVal (1.0) [GEZero 1], GVal (-1.0) [GEPlus 1]]))
                                                                             []
                                                                             (PLine2 (GVec [GVal (0.5000000000000001) [GEPlus 1], GVal (-0.8660254037844387) [GEPlus 2]]))]
    it "places lines on a triangle" $
      (addLineSegs 0.25 Nothing <$> facesFromStraightSkeleton (findStraightSkeleton triangle [])) --> [([
                                                                                                           (LineSeg (Point2 (2.21650635094611,-0.12500000000000003)) (Point2 (-1.2165063509461098,2.107050807568877))),
                                                                                                           (LineSeg (Point2 (2.6495190528383294,-0.37500000000000006)) (Point2 (-1.6495190528383294,2.857050807568877)))
                                                                                                        ],
                                                                                                        Just [Face (LineSeg (Point2 (2.866025403784439,-0.5000000000000001)) (Point2 (-1.8660254037844388,3.232050807568877)))
                                                                                                                   (PLine2 (GVec [GVal (-1.0000000000000002) [GEZero 1], GVal (0.5000000000000001) [GEPlus 1], GVal (0.8660254037844387) [GEPlus 2]]))
                                                                                                                   []
                                                                                                                   (PLine2 (GVec [GVal (1.0) [GEZero 1], GVal (-1.0) [GEPlus 1]]))
                                                                                                             ])
                                                                                                      ,([
                                                                                                           (LineSeg (Point2 (-0.21650635094610962,-0.125)) (Point2 (2.4330127018922196,0.0))),
                                                                                                           (LineSeg (Point2 (-0.6495190528383289,-0.375)) (Point2 (3.299038105676658,0.0)))
                                                                                                        ],
                                                                                                        Just [Face (LineSeg (Point2 (-0.8660254037844385,-0.5)) (Point2 (3.732050807568877,0.0)))
                                                                                                                   (PLine2 (GVec [GVal (0.5000000000000001) [GEPlus 1], GVal (-0.8660254037844387) [GEPlus 2]]))
                                                                                                                   []
                                                                                                                   (PLine2 (GVec [GVal (-1.0000000000000002) [GEZero 1], GVal (0.5000000000000001) [GEPlus 1], GVal (0.8660254037844387) [GEPlus 2]]))])
                                                                                                      ,([
                                                                                                           (LineSeg (Point2 (1.0,1.9820508075688772)) (Point2 (-1.2165063509461096,-2.107050807568877))),
                                                                                                           (LineSeg (Point2 (1.0,2.4820508075688773)) (Point2 (-1.649519052838329,-2.857050807568877)))
                                                                                                        ],Just [Face (LineSeg (Point2 (1.0,2.732050807568877)) (Point2 (-1.8660254037844388,-3.232050807568877)))
                                                                                                                     (PLine2 (GVec [GVal (1.0) [GEZero 1], GVal (-1.0) [GEPlus 1]]))
                                                                                                                     []
                                                                                                                     (PLine2 (GVec [GVal (0.5000000000000001) [GEPlus 1], GVal (-0.8660254037844387) [GEPlus 2]]))])
                                                                                                      ]

    where
      -- c0 - c4 are the contours of a square around the origin with a 90 degree chunk missing, rotated 0, 90, 180, 270 and 360 degrees:
      --    __
      --    \ |
      --    /_|
      --
      c0 = PointSequence [Point2 (-1,1), Point2 (1,1), Point2 (1,-1), Point2 (-1,-1), Point2 (0,0)]
      c1 = PointSequence [Point2 (-1,1), Point2 (1,1), Point2 (1,-1), Point2 (0,0), Point2 (-1,-1)]
      c2 = PointSequence [Point2 (-1,1), Point2 (1,1), Point2 (0,0), Point2 (1,-1), Point2 (-1,-1)]
      c3 = PointSequence [Point2 (-1,1), Point2 (0,0), Point2 (1,1), Point2 (1,-1), Point2 (-1,-1)]
      c4 = PointSequence [Point2 (0,0), Point2 (-1,1), Point2 (1,1), Point2 (1,-1), Point2 (-1,-1)]
      c5 = PointSequence [Point2 (0,0), Point2 (-1,1), Point2 (1,1), Point2 (2,0), Point2 (1,-1), Point2 (-1,-1)]
      c6 = PointSequence [Point2 (-1,1), Point2 (1,1), Point2 (1,-1), Point2 (0.5,-1), Point2 (0,0), Point2 (-0.5,-1), Point2 (-1,-1)]
      -- A simple triangle.
      triangle = PointSequence [Point2 (0,0), Point2 (1,sqrt 3), Point2 (2,0)]
      -- The next corners are part of a square around the origin with a piece missing: (think: c2 from above)
      --    __  <-- corner 1
      --   | /
      --   | \
      --   ~~~  <-- corner 3
      --   ^-- corner 4
      -- the top side, and the entry to the convex angle of a 2x2 square around the origin, with a slice missing.
      corner1 = [ LineSeg (Point2 (-1.0,1.0)) (Point2 (2.0,0.0)), LineSeg (Point2 (1.0,1.0)) (Point2 (-1.0,-1.0))]
      -- the entry and the exit to the convex angle of a 2x2 square around the origin, with a slice missing.
      corner2 = [ LineSeg (Point2 (1.0,1.0)) (Point2 (-1.0,-1.0)), LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,-1.0))]
      -- the exit to the convex angle and the bottom of a 2x2 square around the origin, with a slice missing.
      corner3 = [ LineSeg (Point2 (0.0,0.0)) (Point2 (1.0,-1.0)), LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0))]
      -- the bottom and the left side of a 2x2 square around the origin, with a slice missing.
      corner4 = [ LineSeg (Point2 (1.0,-1.0)) (Point2 (-2.0,0.0)), LineSeg (Point2 (-1.0,-1.0)) (Point2 (0.0,2.0))]
