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


module engine::physics::box2d;

import thirdparty::raylib5::rl;

/*
m_debugDraw = { DrawPolygonFcn,
				DrawSolidPolygonFcn,
				DrawCircleFcn,
				DrawSolidCircleFcn,
				DrawCapsuleFcn,
				DrawSolidCapsuleFcn,
				DrawSegmentFcn,
				DrawTransformFcn,
				DrawPointFcn,
				DrawStringFcn,
				bounds,
				false, // drawUsingBounds
				true,  // shapes
				true,  // joints
				false, // joint extras
				false, // aabbs
				false, // mass
				false, // contacts
				false, // colors
				false, // normals
				false, // impulse
				false, // friction
				this };
*/

<*
    @param [inout] dd "the debugDraw struct to init"
    @require dd != null
*>
fn void initDebugDraw(B2DebugDraw* dd) {
    //(*dd) = defaultDebugDraw();
    // draw callbacks
    dd.drawPolygon        = &dbgDrawPolygon;
    dd.drawSolidPolygon   = &dbgDrawSolidPolygon;
    dd.drawCircle         = &dbgDrawCircle;
    dd.drawSolidCircle    = &dbgDrawSolidCircle;
    //dd.drawCapsule      = &dbgDrawCapsule;
    //dd.drawSolidCapsule = &dbgDrawSolidCapsule;
    dd.drawSegment        = &dbgDrawLineSegment;
    //dd.drawTransform      = &dbgDrawTransform;
    dd.drawPoint          = &dbgDrawPoint;
    dd.drawString         = &dbgDrawString;
    //
    B2AABBox bounds = { { -float.max, -float.max }, { float.max, float.max } };
    dd.drawingBounds      = bounds;
    // drawing options
	dd.drawShapes         = true;
	//dd.drawJoints       = true;
	//dd.drawJointExtras  = true;
	dd.drawAABBs          = true;
	//dd.drawMass         = true;
	dd.drawContacts       = true;
	//dd.drawGraphColors      = true;
	//dd.drawContactNormals   = true;
	//dd.drawContactImpulses  = true;
	//dd.drawFrictionImpulses = true;
    
    // graphics context? for now is null
	//void* context;
    
}

<*
    @param [inout] dd "the debugDraw struct to deinit"
    @require dd != null
*>
fn void deinitDebugDraw(B2DebugDraw* dd) {
    if(dd.drawPolygon     ) dd.drawPolygon      = null;
    if(dd.drawSolidPolygon) dd.drawSolidPolygon = null;
    if(dd.drawCircle      ) dd.drawCircle       = null;
    if(dd.drawSolidCircle ) dd.drawSolidCircle  = null;
    if(dd.drawCapsule     ) dd.drawCapsule      = null;
    if(dd.drawSolidCapsule) dd.drawSolidCapsule = null;
    if(dd.drawSegment     ) dd.drawSegment      = null;
    if(dd.drawTransform   ) dd.drawTransform    = null;
    if(dd.drawPoint       ) dd.drawPoint        = null;
    if(dd.drawString      ) dd.drawString       = null;
    if(dd.context         ) dd.context          = null;
}

fn void dbgDrawPolygonLocal(B2Vec2* vertices, int vertexCount, Color tint) @local
{
    B2Vec2 p1 = vertices[vertexCount - 1];
    for ( int i = 0; i < vertexCount; ++i )
    {
        B2Vec2 p2 = vertices[i];
        rl::drawLineV(b2Vec2ToVector2f(p1), b2Vec2ToVector2f(p2), tint);
        p1 = p2;
    }
}

// Disabled because mulAdd, rotGetXAxis and rotGetYAxis are not 
// exported in the current static library box2d.lib.
// This functions (and many others in math_functions.h) 
// are not marked "B2_API" but "B2_INLINE" so their symbols (func names)
// don't get exported into the library when compiled.
// I have the source so I could change that myself, but then 
// I would need to maintain my own clone of the box2d library and updating would be a pita. :(
fn void dbgDrawTransformLocal(B2Transform transform) @local
{
    unreachable();
/*
	float k_axisScale = 0.2f;
	B2Vec2 p1 = transform.p;

	B2Vec2 p2 = box2d::math::mulAdd(p1, k_axisScale, box2d::math::rotGetXAxis(transform.q));
    rl::drawLineV(p1, p2, rl::RED);

	p2 = box2d::math::mulAdd(p1, k_axisScale, box2d::math::rotGetYAxis(transform.q));
    rl::drawLineV(p1, p2, rl::GREEN);
*/
}

fn Color hexColorToColor(int hexValue)
{
  Color rgbColor;
  rgbColor.r = (char)((hexValue >> 16) & 0xFF) / 255;  // Extract the RR byte
  rgbColor.g = (char)((hexValue >> 8) & 0xFF) / 255;   // Extract the GG byte
  rgbColor.b = (char)((hexValue) & 0xFF) / 255;        // Extract the BB byte

  return rgbColor;
}

/// Draw a closed polygon provided in CCW order.
fn void dbgDrawPolygon(B2Vec2* vertices, int vertexCount, B2HexColor color, void* context ) {
    //rl::drawLineStrip((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
    //drawPolygonLocal((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
}
/// Draw a solid closed polygon provided in CCW order.
fn void dbgDrawSolidPolygon(B2Transform transform, B2Vec2* vertices, int vertexCount, float radius, B2HexColor color, void* context ) {
    //rl::drawTriangleStrip((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
}
fn void dbgDrawCircle(B2Vec2 center, float radius, B2HexColor color, void* context ) {
    rl::drawCircleLinesV(b2Vec2ToVector2f(center), radius, hexColorToColor(color));
}
fn void dbgDrawSolidCircle(B2Transform transform, float radius, B2HexColor color, void* context ) {
    rl::drawCircleV(b2Vec2ToVector2f(transform.p), radius, hexColorToColor(color));
}
	//void ( *DrawCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
	//void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
fn void dbgDrawLineSegment(B2Vec2 p1, B2Vec2 p2, B2HexColor color, void* context ) {
    rl::drawLineV(b2Vec2ToVector2f(p1), b2Vec2ToVector2f(p2), hexColorToColor(color));
}

/// Draw a transform. Choose your own length scale.
fn void dbgDrawTransform(B2Transform transform, void* context) {
    dbgDrawTransformLocal(transform);
}

fn void dbgDrawPoint(B2Vec2 p, float size, B2HexColor color, void* context ) {
    dbgDrawCircle(p, size, color, context);
}
fn void dbgDrawString(B2Vec2 p, ZString s, void* context ) {
    rl::drawTextEx(rl::getFontDefault(), s, b2Vec2ToVector2f(p), 1.0f, 1.0f, rl::WHITE);
}
