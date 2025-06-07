/************************************ LICENSE *******************************************
# hmflathead GPL Source Code
# Copyright (C) 2025 Hilario Martins.
# 
# This file is part of the hmflathead GPL Source Code ("hmflathead Source Code")
# 
# hmflathead Source Code is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# hmflathead Source Code is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with hmflathead Source Code.  If not, see <http://www.gnu.org/licenses/>.
# 
# In addition, the hmflathead Source Code is also subject to certain additional terms. 
# You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License 
# which accompanied the hmflathead Source Code.  If not, please request a copy in writing from me at the address below.
# 
# If you have questions concerning this license or the applicable additional terms, you may contact in writing 
# Hilario Martins, Rua de Sanguinhedo 1010 4850-545 Vieira Do Minho Portugal.
# 
*********************************************************************************************************************************************/

// Add fields and methods for 2D rendering
// For example, you might have a method to draw a rectangle or a sprite

module engine::sys::render2d::r2d;

import std::io;
import thirdparty::raylib5::rl;
import game::assets::sprt;

/*
struct Render2D
{
    
}

fn void Render2D.init()
{
    // Initialization code for 2D rendering
    io::printfn("Render2D initialized");
}

fn void Render2D.deinit()
{
    // Deinitialization code for 2D rendering
    io::printfn("Render2D deinitialized");
}
*/

fn void drawPixel(int posX, int posY, Color color) @inline 
{
    rl::drawPixel(posX, posY, color);
}

// Draw a pixel (Vector version)
fn void drawPixelV(Vector2 position, Color color) @inline 
{
    rl::drawPixelV(position, color);
}

fn void drawLine(int startPosX, int startPosY, int endPosX, int endPosY, Color color) @inline 
{
    rl::drawLine(startPosX, startPosY, endPosX, endPosY, color);
}

// Draw a line (Vector version)
fn void drawLineV(Vector2 startPos, Vector2 endPos, Color color) @inline 
{
    rl::drawLineV(startPos, endPos, color);
}

// Draw a line defining thickness
fn void drawLineEx(Vector2 startPos, Vector2 endPos, float thick, Color color) @inline 
{
    rl::drawLineEx(startPos, endPos, thick, color);
}

// Draw lines sequence (using gl lines)
fn void drawLineStrip(Vector2* points, int pointCount, Color color) @inline 
{
    rl::drawLineStrip(points, pointCount, color);
}

// Draw a line using cubic-bezier curves in-out
fn void drawLineBezier(Vector2 startPos, Vector2 endPos, float thick, Color color) @inline 
{
    rl::drawLineBezier(startPos, endPos, thick, color);
}

// Draw lines sequence
fn void drawCircle(int centerX, int centerY, float radius, Color color) @inline 
{
    rl::drawCircle(centerX, centerY, radius, color);
}

// Draw a piece of a circle
fn void drawCircleSector(Vector2 center, float radius, float startAngle, float endAngle, int segments, Color color) @inline 
{
    rl::drawCircleSector(center, radius, startAngle, endAngle, segments, color);
}

// Draw circle sector outline
fn void drawCircleSectorLines(Vector2 center, float radius, float startAngle, float endAngle, int segments, Color color) @inline 
{
    rl::drawCircleSectorLines(center, radius, startAngle, endAngle, segments, color);
}

// Draw a gradient-filled circle
fn void drawCircleGradient(int centerX, int centerY, float radius, Color inner, Color outer) @inline 
{
    rl::drawCircleGradient(centerX, centerY, radius, inner, outer);
}

// Draw a color-filled circle (Vector version)
fn void drawCircleV(Vector2 center, float radius, Color color) @inline 
{
    rl::drawCircleV(center, radius, color);
}

// Draw circle outline
fn void drawCircleLines(int centerX, int centerY, float radius, Color color) @inline 
{
    rl::drawCircleLines(centerX, centerY, radius, color);
}

// Draw circle outline (Vector version)
fn void drawCircleLinesV(Vector2 center, float radius, Color color) @inline 
{
    rl::drawCircleLinesV(center, radius, color);
}

// Draw ellipse
fn void drawEllipse(int centerX, int centerY, float radiusH, float radiusV, Color color) @inline 
{
    rl::drawEllipse(centerX, centerY, radiusH, radiusV, color);
}

// Draw ellipse outline
fn void drawEllipseLines(int centerX, int centerY, float radiusH, float radiusV, Color color) @inline 
{
    rl::drawEllipseLines(centerX, centerY, radiusH, radiusV, color);
}

// Draw ring
fn void drawRing(Vector2 center, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, Color color) @inline 
{
    rl::drawRing(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
}

// Draw ring outline
fn void drawRingLines(Vector2 center, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, Color color) @inline 
{
    rl::drawRingLines(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
}

// Draw a color-filled rectangle
fn void drawRectangle(int posX, int posY, int width, int height, Color color) @inline 
{
    rl::drawRectangle(posX, posY, width, height, color);
}

// Draw a color-filled rectangle (Vector version)
fn void drawRectangleV(Vector2 position, Vector2 size, Color color) @inline 
{
    rl::drawRectangleV(position, size, color);
}

// Draw a color-filled rectangle
fn void drawRectangleRec(Rectangle rec, Color color) @inline 
{
    rl::drawRectangleRec(rec, color);
}

macro void @drawRect(#rect, color) => drawRectangleRec(#rect, color);

// Draw a color-filled rectangle with pro parameters
fn void drawRectanglePro(Rectangle rec, Vector2 origin, float rotation, Color color) @inline 
{
    rl::drawRectanglePro(rec, origin, rotation, color);
}

// Draw a vertical-gradient-filled rectangle
fn void drawRectangleGradientV(int posX, int posY, int width, int height, Color top, Color bottom) @inline 
{
    rl::drawRectangleGradientV(posX, posY, width, height, top, bottom);
}

// Draw a horizontal-gradient-filled rectangle
fn void drawRectangleGradientH(int posX, int posY, int width, int height, Color left, Color right) @inline 
{
    rl::drawRectangleGradientH(posX, posY, width, height, left, right);
}

// Draw a gradient-filled rectangle with custom vertex colors
fn void drawRectangleGradientEx(Rectangle rec, Color topLeft, Color bottomLeft, Color topRight, Color bottomRight) @inline 
{
    rl::drawRectangleGradientEx(rec, topLeft, bottomLeft, topRight, bottomRight);
}

// Draw rectangle outline
fn void drawRectangleLines(int posX, int posY, int width, int height, Color color) @inline 
{
    rl::drawRectangleLines(posX, posY, width, height, color);
}

// Draw rectangle outline with extended parameters
fn void drawRectangleLinesEx(Rectangle rec, float lineThick, Color color) @inline 
{
    rl::drawRectangleLinesEx(rec, lineThick, color);
}

// Draw rectangle with rounded edges
fn void drawRectangleRounded(Rectangle rec, float roundness, int segments, Color color) @inline 
{
    rl::drawRectangleRounded(rec, roundness, segments, color);
}

// Draw rectangle lines with rounded edges
fn void drawRectangleRoundedLines(Rectangle rec, float roundness, int segments, float lineThick, Color color) @inline 
{
    rl::drawRectangleRoundedLines(rec, roundness, segments, lineThick, color);
}

// Draw rectangle with rounded edges outline
fn void drawRectangleRoundedLinesEx(Rectangle rec, float roundness, int segments, float lineThick, Color color) @inline 
{
    rl::drawRectangleRoundedLinesEx(rec, roundness, segments, lineThick, color);
}

// Draw a color-filled triangle (vertex in counter-clockwise order!)
fn void drawTriangle(Vector2 v1, Vector2 v2, Vector2 v3, Color color) @inline 
{
    rl::drawTriangle(v1, v2, v3, color);
}

// Draw triangle outline (vertex in counter-clockwise order!)
fn void drawTriangleLines(Vector2 v1, Vector2 v2, Vector2 v3, Color color) @inline 
{
    rl::drawTriangleLines(v1, v2, v3, color);
}

// Draw a triangle fan defined by points (first vertex is the center)
fn void drawTriangleFan(Vector2 *points, int pointCount, Color color) @inline 
{
    rl::drawTriangleFan(points, pointCount, color);
}

// Draw a triangle strip defined by points
fn void drawTriangleStrip(Vector2 *points, int pointCount, Color color) @inline 
{
    rl::drawTriangleStrip(points, pointCount, color);
}

// Draw a regular polygon (Vector version)
fn void drawPoly(Vector2 center, int sides, float radius, float rotation, Color color) @inline 
{
    rl::drawPoly(center, sides, radius, rotation, color);
}

// Draw a polygon outline of n sides
fn void drawPolyLines(Vector2 center, int sides, float radius, float rotation, Color color) @inline 
{
    rl::drawPolyLines(center, sides, radius, rotation, color);
}

// Draw a polygon outline of n sides with extended parameters
fn void drawPolyLinesEx(Vector2 center, int sides, float radius, float rotation, float lineThick, Color color) @inline 
{
    rl::drawPolyLinesEx(center, sides, radius, rotation, lineThick, color);
}

// Splines drawing functions
// Draw spline: Linear, minimum 2 points
fn void drawSplineLinear(Vector2 *points, int pointCount, float thick, Color color) @inline 
{
    rl::drawSplineLinear(points, pointCount, thick, color);
}

// Draw spline: B-Spline, minimum 4 points
fn void drawSplineBasis(Vector2 *points, int pointCount, float thick, Color color) @inline 
{
    rl::drawSplineBasis(points, pointCount, thick, color);
}

// Draw spline: Catmull-Rom, minimum 4 points
fn void drawSplineCatmullRom(Vector2 *points, int pointCount, float thick, Color color) @inline 
{
    rl::drawSplineCatmullRom(points, pointCount, thick, color);
}

// Draw spline: Quadratic Bezier, minimum 3 points (1 control point): [p1, c2, p3, c4...]
fn void drawSplineBezierQuadratic(Vector2 *points, int pointCount, float thick, Color color) @inline 
{
    rl::drawSplineBezierQuadratic(points, pointCount, thick, color);
}

// Draw spline: Cubic Bezier, minimum 4 points (2 control points): [p1, c2, c3, p4, c5, c6...]
fn void drawSplineBezierCubic(Vector2 *points, int pointCount, float thick, Color color) @inline 
{
    rl::drawSplineBezierCubic(points, pointCount, thick, color);
}

// Draw spline segment: Linear, 2 points
fn void drawSplineSegmentLinear(Vector2 p1, Vector2 p2, float thick, Color color) @inline 
{
    rl::drawSplineSegmentLinear(p1, p2, thick, color);
}

// Draw spline segment: B-Spline, 4 points
fn void drawSplineSegmentBasis(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4, float thick, Color color) @inline 
{
    rl::drawSplineSegmentBasis(p1, p2, p3, p4, thick, color);
}

// Draw spline segment: Catmull-Rom, 4 points
fn void drawSplineSegmentCatmullRom(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4, float thick, Color color) @inline 
{
    rl::drawSplineSegmentCatmullRom(p1, p2, p3, p4, thick, color);
}

// Draw spline segment: Quadratic Bezier, 2 points, 1 control point
fn void drawSplineSegmentBezierQuadratic(Vector2 p1, Vector2 c2, Vector2 p3, float thick, Color color) @inline 
{
    rl::drawSplineSegmentBezierQuadratic(p1, c2, p3, thick, color);
}

// Draw spline segment: Cubic Bezier, 2 points, 2 control points
fn void drawSplineSegmentBezierCubic(Vector2 p1, Vector2 c2, Vector2 c3, Vector2 p4, float thick, Color color) @inline 
{
    rl::drawSplineSegmentBezierCubic(p1, c2, c3, p4, thick, color);
}

// Spline segment point evaluation functions, for a given t [0.0f .. 1.0f]
// Get (evaluate) spline point: Linear
fn Vector2 getSplinePointLinear(Vector2 startPos, Vector2 endPos, float t) @inline 
{
    return rl::getSplinePointLinear(startPos, endPos, t);
}

// Get (evaluate) spline point: B-Spline
fn Vector2 getSplinePointBasis(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4, float t) @inline 
{
    return rl::getSplinePointBasis(p1, p2, p3, p4, t);
}

// Get (evaluate) spline point: Catmull-Rom
fn Vector2 getSplinePointCatmullRom(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4, float t) @inline 
{
    return rl::getSplinePointCatmullRom(p1, p2, p3, p4, t);
}

// Get (evaluate) spline point: Quadratic Bezier
fn Vector2 getSplinePointBezierQuad(Vector2 p1, Vector2 c2, Vector2 p3, float t) @inline 
{
    return rl::getSplinePointBezierQuad(p1, c2, p3, t);
}

// Get (evaluate) spline point: Cubic Bezier
fn Vector2 getSplinePointBezierCubic(Vector2 p1, Vector2 c2, Vector2 c3, Vector2 p4, float t) @inline 
{
    return rl::getSplinePointBezierCubic(p1, c2, c3, p4, t);
}
