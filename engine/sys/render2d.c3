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
import engine::misc;
import engine::filesystem::fs;
import engine::logging::log;
import game::assets::sprt;
import game::main;
import thirdparty::raylib5::rl;

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

fn void drawPixel(int posX, int posY, RLColor color) @inline 
{
    rl::drawPixel(posX, posY, color);
}

// Draw a pixel (Vector version)
fn void drawPixelV(RLVector2 position, RLColor color) @inline 
{
    rl::drawPixelV(position, color);
}

fn void drawLine(int startPosX, int startPosY, int endPosX, int endPosY, RLColor color) @inline 
{
    rl::drawLine(startPosX, startPosY, endPosX, endPosY, color);
}

// Draw a line (Vector version)
fn void drawLineV(RLVector2 startPos, RLVector2 endPos, RLColor color) @inline 
{
    rl::drawLineV(startPos, endPos, color);
}

// Draw a line defining thickness
fn void drawLineEx(RLVector2 startPos, RLVector2 endPos, float thick, RLColor color) @inline 
{
    rl::drawLineEx(startPos, endPos, thick, color);
}

// Draw lines sequence (using gl lines)
fn void drawLineStrip(RLVector2* points, int pointCount, RLColor color) @inline 
{
    rl::drawLineStrip(points, pointCount, color);
}

// Draw a line using cubic-bezier curves in-out
fn void drawLineBezier(RLVector2 startPos, RLVector2 endPos, float thick, RLColor color) @inline 
{
    rl::drawLineBezier(startPos, endPos, thick, color);
}

// Draw lines sequence
fn void drawCircle(int centerX, int centerY, float radius, RLColor color) @inline 
{
    rl::drawCircle(centerX, centerY, radius, color);
}

// Draw a piece of a circle
fn void drawCircleSector(RLVector2 center, float radius, float startAngle, float endAngle, int segments, RLColor color) @inline 
{
    rl::drawCircleSector(center, radius, startAngle, endAngle, segments, color);
}

// Draw circle sector outline
fn void drawCircleSectorLines(RLVector2 center, float radius, float startAngle, float endAngle, int segments, RLColor color) @inline 
{
    rl::drawCircleSectorLines(center, radius, startAngle, endAngle, segments, color);
}

// Draw a gradient-filled circle
fn void drawCircleGradient(int centerX, int centerY, float radius, RLColor inner, RLColor outer) @inline 
{
    rl::drawCircleGradient(centerX, centerY, radius, inner, outer);
}

// Draw a color-filled circle (Vector version)
fn void drawCircleV(RLVector2 center, float radius, RLColor color) @inline 
{
    rl::drawCircleV(center, radius, color);
}

// Draw circle outline
fn void drawCircleLines(int centerX, int centerY, float radius, RLColor color) @inline 
{
    rl::drawCircleLines(centerX, centerY, radius, color);
}

// Draw circle outline (Vector version)
fn void drawCircleLinesV(RLVector2 center, float radius, RLColor color) @inline 
{
    rl::drawCircleLinesV(center, radius, color);
}

// Draw ellipse
fn void drawEllipse(int centerX, int centerY, float radiusH, float radiusV, RLColor color) @inline 
{
    rl::drawEllipse(centerX, centerY, radiusH, radiusV, color);
}

// Draw ellipse outline
fn void drawEllipseLines(int centerX, int centerY, float radiusH, float radiusV, RLColor color) @inline 
{
    rl::drawEllipseLines(centerX, centerY, radiusH, radiusV, color);
}

// Draw ring
fn void drawRing(RLVector2 center, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, RLColor color) @inline 
{
    rl::drawRing(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
}

// Draw ring outline
fn void drawRingLines(RLVector2 center, float innerRadius, float outerRadius, float startAngle, float endAngle, int segments, RLColor color) @inline 
{
    rl::drawRingLines(center, innerRadius, outerRadius, startAngle, endAngle, segments, color);
}

// Draw a color-filled rectangle
fn void drawRectangle(int posX, int posY, int width, int height, RLColor color) @inline 
{
    rl::drawRectangle(posX, posY, width, height, color);
}

// Draw a color-filled rectangle (Vector version)
fn void drawRectangleV(RLVector2 position, RLVector2 size, RLColor color) @inline 
{
    rl::drawRectangleV(position, size, color);
}

// Draw a color-filled rectangle
fn void drawRectangleRec(RLRectangle rec, RLColor color) @inline 
{
    rl::drawRectangleRec(rec, color);
}

macro void @drawRect(#rect, color) => drawRectangleRec(#rect, color);

// Draw a color-filled rectangle with pro parameters
fn void drawRectanglePro(RLRectangle rec, RLVector2 origin, float rotation, RLColor color) @inline 
{
    rl::drawRectanglePro(rec, origin, rotation, color);
}

// Draw a vertical-gradient-filled rectangle
fn void drawRectangleGradientV(int posX, int posY, int width, int height, RLColor top, RLColor bottom) @inline 
{
    rl::drawRectangleGradientV(posX, posY, width, height, top, bottom);
}

// Draw a horizontal-gradient-filled rectangle
fn void drawRectangleGradientH(int posX, int posY, int width, int height, RLColor left, RLColor right) @inline 
{
    rl::drawRectangleGradientH(posX, posY, width, height, left, right);
}

// Draw a gradient-filled rectangle with custom vertex colors
fn void drawRectangleGradientEx(RLRectangle rec, RLColor topLeft, RLColor bottomLeft, RLColor topRight, RLColor bottomRight) @inline 
{
    rl::drawRectangleGradientEx(rec, topLeft, bottomLeft, topRight, bottomRight);
}

// Draw rectangle outline
fn void drawRectangleLines(int posX, int posY, int width, int height, RLColor color) @inline 
{
    rl::drawRectangleLines(posX, posY, width, height, color);
}

// Draw rectangle outline with extended parameters
fn void drawRectangleLinesEx(RLRectangle rec, float lineThick, RLColor color) @inline 
{
    rl::drawRectangleLinesEx(rec, lineThick, color);
}

// Draw rectangle with rounded edges
fn void drawRectangleRounded(RLRectangle rec, float roundness, int segments, RLColor color) @inline 
{
    rl::drawRectangleRounded(rec, roundness, segments, color);
}

// Draw rectangle lines with rounded edges
fn void drawRectangleRoundedLines(RLRectangle rec, float roundness, int segments, float lineThick, RLColor color) @inline 
{
    rl::drawRectangleRoundedLines(rec, roundness, segments, lineThick, color);
}

// Draw rectangle with rounded edges outline
fn void drawRectangleRoundedLinesEx(RLRectangle rec, float roundness, int segments, float lineThick, RLColor color) @inline 
{
    rl::drawRectangleRoundedLinesEx(rec, roundness, segments, lineThick, color);
}

// Draw a color-filled triangle (vertex in counter-clockwise order!)
fn void drawTriangle(RLVector2 v1, RLVector2 v2, RLVector2 v3, RLColor color) @inline 
{
    rl::drawTriangle(v1, v2, v3, color);
}

// Draw triangle outline (vertex in counter-clockwise order!)
fn void drawTriangleLines(RLVector2 v1, RLVector2 v2, RLVector2 v3, RLColor color) @inline 
{
    rl::drawTriangleLines(v1, v2, v3, color);
}

// Draw a triangle fan defined by points (first vertex is the center)
fn void drawTriangleFan(RLVector2 *points, int pointCount, RLColor color) @inline 
{
    rl::drawTriangleFan(points, pointCount, color);
}

// Draw a triangle strip defined by points
fn void drawTriangleStrip(RLVector2 *points, int pointCount, RLColor color) @inline 
{
    rl::drawTriangleStrip(points, pointCount, color);
}

// Draw a regular polygon (Vector version)
fn void drawPoly(RLVector2 center, int sides, float radius, float rotation, RLColor color) @inline 
{
    rl::drawPoly(center, sides, radius, rotation, color);
}

// Draw a polygon outline of n sides
fn void drawPolyLines(RLVector2 center, int sides, float radius, float rotation, RLColor color) @inline 
{
    rl::drawPolyLines(center, sides, radius, rotation, color);
}

// Draw a polygon outline of n sides with extended parameters
fn void drawPolyLinesEx(RLVector2 center, int sides, float radius, float rotation, float lineThick, RLColor color) @inline 
{
    rl::drawPolyLinesEx(center, sides, radius, rotation, lineThick, color);
}

// Splines drawing functions
// Draw spline: Linear, minimum 2 points
fn void drawSplineLinear(RLVector2 *points, int pointCount, float thick, RLColor color) @inline 
{
    rl::drawSplineLinear(points, pointCount, thick, color);
}

// Draw spline: B-Spline, minimum 4 points
fn void drawSplineBasis(RLVector2 *points, int pointCount, float thick, RLColor color) @inline 
{
    rl::drawSplineBasis(points, pointCount, thick, color);
}

// Draw spline: Catmull-Rom, minimum 4 points
fn void drawSplineCatmullRom(RLVector2 *points, int pointCount, float thick, RLColor color) @inline 
{
    rl::drawSplineCatmullRom(points, pointCount, thick, color);
}

// Draw spline: Quadratic Bezier, minimum 3 points (1 control point): [p1, c2, p3, c4...]
fn void drawSplineBezierQuadratic(RLVector2 *points, int pointCount, float thick, RLColor color) @inline 
{
    rl::drawSplineBezierQuadratic(points, pointCount, thick, color);
}

// Draw spline: Cubic Bezier, minimum 4 points (2 control points): [p1, c2, c3, p4, c5, c6...]
fn void drawSplineBezierCubic(RLVector2 *points, int pointCount, float thick, RLColor color) @inline 
{
    rl::drawSplineBezierCubic(points, pointCount, thick, color);
}

// Draw spline segment: Linear, 2 points
fn void drawSplineSegmentLinear(RLVector2 p1, RLVector2 p2, float thick, RLColor color) @inline 
{
    rl::drawSplineSegmentLinear(p1, p2, thick, color);
}

// Draw spline segment: B-Spline, 4 points
fn void drawSplineSegmentBasis(RLVector2 p1, RLVector2 p2, RLVector2 p3, RLVector2 p4, float thick, RLColor color) @inline 
{
    rl::drawSplineSegmentBasis(p1, p2, p3, p4, thick, color);
}

// Draw spline segment: Catmull-Rom, 4 points
fn void drawSplineSegmentCatmullRom(RLVector2 p1, RLVector2 p2, RLVector2 p3, RLVector2 p4, float thick, RLColor color) @inline 
{
    rl::drawSplineSegmentCatmullRom(p1, p2, p3, p4, thick, color);
}

// Draw spline segment: Quadratic Bezier, 2 points, 1 control point
fn void drawSplineSegmentBezierQuadratic(RLVector2 p1, RLVector2 c2, RLVector2 p3, float thick, RLColor color) @inline 
{
    rl::drawSplineSegmentBezierQuadratic(p1, c2, p3, thick, color);
}

// Draw spline segment: Cubic Bezier, 2 points, 2 control points
fn void drawSplineSegmentBezierCubic(RLVector2 p1, RLVector2 c2, RLVector2 c3, RLVector2 p4, float thick, RLColor color) @inline 
{
    rl::drawSplineSegmentBezierCubic(p1, c2, c3, p4, thick, color);
}

// Spline segment point evaluation functions, for a given t [0.0f .. 1.0f]
// Get (evaluate) spline point: Linear
fn RLVector2 getSplinePointLinear(RLVector2 startPos, RLVector2 endPos, float t) @inline 
{
    return rl::getSplinePointLinear(startPos, endPos, t);
}

// Get (evaluate) spline point: B-Spline
fn RLVector2 getSplinePointBasis(RLVector2 p1, RLVector2 p2, RLVector2 p3, RLVector2 p4, float t) @inline 
{
    return rl::getSplinePointBasis(p1, p2, p3, p4, t);
}

// Get (evaluate) spline point: Catmull-Rom
fn RLVector2 getSplinePointCatmullRom(RLVector2 p1, RLVector2 p2, RLVector2 p3, RLVector2 p4, float t) @inline 
{
    return rl::getSplinePointCatmullRom(p1, p2, p3, p4, t);
}

// Get (evaluate) spline point: Quadratic Bezier
fn RLVector2 getSplinePointBezierQuad(RLVector2 p1, RLVector2 c2, RLVector2 p3, float t) @inline 
{
    return rl::getSplinePointBezierQuad(p1, c2, p3, t);
}

// Get (evaluate) spline point: Cubic Bezier
fn RLVector2 getSplinePointBezierCubic(RLVector2 p1, RLVector2 c2, RLVector2 c3, RLVector2 p4, float t) @inline 
{
    return rl::getSplinePointBezierCubic(p1, c2, c3, p4, t);
}

//////////////////////////////////
// Simple debug drawing functions

// Draw a debug point at the specified position with the given color
fn void drawDebugPoint(Vec2f pos, RLColor color) @inline {
    rl::drawCircleV(*((RLVector2*)&pos), 3.0f, color);
}

// Draw a debug line from start to end position with the specified color
fn void drawDebugLine(Vec2f start, Vec2f end, RLColor color) @inline {
    rl::drawLineV(*((RLVector2*)&start), *((RLVector2*)&end), color);
}

// Draw a debug rectangle at the specified position with the given size and color
fn void drawDebugBox(Vec2f pos, Vec2f size, RLColor color) @inline {
    rl::drawRectangleV(*((RLVector2*)&pos), *((RLVector2*)&size), color);
}


///////////////////////////////////////
// RLTexture2D misc functions
<*
    Load a texture from the specified path.
    @param texture_path : `the path to the texture file relative to the textures directory`
    @require texture_path.len > 0 && rl::isWindowReady() == true
    @ensure rl::isTextureValid(return) == true
*>
fn RLTexture2D loadTexture(String texture_path)
{
    //assert(rl::isWindowReady() == true, "Window not ready! Unable to load texture");
    
    String path = main::gpGame.app_base_folder.tconcat(texture_path);
    assert(path.len > 0, "RLTexture path is empty! Unable to load texture");
    assert(fs::fileExists(path), "RLTexture file does not exist: %s", path);


$if $feature(_DEBUG):
    RLTexture2D tex = rl::loadTexture(path.zstr_tcopy());
    if(rl::isTextureValid(tex)) {
        return tex;
    } else {
        log::warning(Where.FILE, "Failed to load RLTexture '%s' returning default texture...", texture_path);
        return main::gpGame.default_texture;
    }
$else
    // In release mode, we can skip the debug checks for performance
    return rl::loadTexture(path.zstr_tcopy());
$endif
}