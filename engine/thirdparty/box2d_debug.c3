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
import engine::sys::render2d::r2d;
import engine::misc;
import game::camview;

//fn Color hexToColor( int c, float alpha = 1.0f ) @local
//{
	//return { (char)(( c >> 16 ) & 0xFF), (char)( ( c >> 8 ) & 0xFF ), (char)( c & 0xFF ), (char)( 0xFF * alpha ) };
//}

fn Color hexToColor(B2HexColor hexValue)
{
  Color rgbColor = { 0, 0, 0, 255 }; // Initialize with default values
  rgbColor.r = (char)((hexValue >> 16) & 0xFF);  // Extract the RR byte
  rgbColor.g = (char)((hexValue >> 8) & 0xFF);   // Extract the GG byte
  rgbColor.b = (char)((hexValue) & 0xFF);        // Extract the BB byte

  return rgbColor;
}

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
    @param [inout] dd : "the debugDraw struct to init"
    @param [in] view : "the view where to draw the stuff"
    @require dd != null && view != null
*>
fn void initDebugDraw(B2DebugDraw* dd, RenderView* view) {
    (*dd) = defaultDebugDraw();
    // draw callbacks
    dd.drawPolygon        = &dbgDrawPolygon;
    dd.drawSolidPolygon   = &dbgDrawSolidPolygon;
    dd.drawCircle         = &dbgDrawCircle;
    dd.drawSolidCircle    = &dbgDrawSolidCircle;
    //dd.drawCapsule      = &dbgDrawCapsule;
    //dd.drawSolidCapsule = &dbgDrawSolidCapsule;
    dd.drawSegment        = &dbgDrawLineSegment;
    dd.drawTransform      = &dbgDrawTransform;
    dd.drawPoint          = &dbgDrawPoint;
    dd.drawString         = &dbgDrawString;
    //
    B2AABBox bounds = view.fromBoundsToPhysicsAABB(); //{ { -float.max, -float.max }, { float.max, float.max } };
    dd.drawingBounds      = bounds;
    // drawing options
    dd.useDrawingBounds   = true;
	dd.drawShapes         = true;
	//dd.drawJoints       = true;
	//dd.drawJointExtras  = true;
	dd.drawAABBs          = true;
	dd.drawMass           = true;
	dd.drawContacts       = true;
	//dd.drawGraphColors      = true;
	//dd.drawContactNormals   = true;
	//dd.drawContactImpulses  = true;
	//dd.drawFrictionImpulses = true;
    
    // graphics context? for now is null
	//void* context;
    
}

<*
    @param [inout] dd : "the debugDraw struct to deinit"
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
       r2d::drawLineV(p1.toVector2fast(), p2.toVector2fast(), tint);
        p1 = p2;
    }
}

fn void dbgDrawTransformLocal(B2Transform transform) @local
{
	float k_axisScale = 0.2f;
	B2Vec2 p1 = transform.p;

	B2Vec2 p2 = misc::mulAdd(p1, k_axisScale, misc::rot_GetXAxis(transform.q));
   r2d::drawLineV(p1.toVector2fast(), p2.toVector2fast(), rl::RED);

	p2 = misc::mulAdd(p1, k_axisScale, misc::rot_GetYAxis(transform.q));
   r2d::drawLineV(p1.toVector2fast(), p2.toVector2fast(), rl::GREEN);
}

<*
    Draw a closed polygon provided in CCW order.
    
    @param [in] vertices : "polygon vertices"
    @param vertexCount   : "amount of vertices"
    @param color         : "polygon color passed as a hexValue"
    @param [in] context  : "opengl/drawing context is null by default"
    @require vertices != null
*>
fn void dbgDrawPolygon(B2Vec2* vertices, int vertexCount, B2HexColor color, void* context = null ) {
    //rl::drawLineStrip((Vector2*)vertices, vertexCount,rl::BLUE);
   r2d::drawTriangleStrip((Vector2*)vertices, vertexCount, /*rl::BLUE*/ hexToColor(color));
    //Color c = hexToColor(color);
    //dbgDrawPolygonLocal(vertices, vertexCount,r2d::BLUE);
}
/// Draw a solid closed polygon provided in CCW order.
fn void dbgDrawSolidPolygon(B2Transform transform, B2Vec2* vertices, int vertexCount, float radius, B2HexColor color, void* context ) {
   r2d::drawTriangleStrip((rl::Vector2*)vertices, vertexCount, hexToColor(color));
}
fn void dbgDrawCircle(B2Vec2 center, float radius, B2HexColor color, void* context ) {
   r2d::drawCircleLinesV(center.toVector2fast(), radius, hexToColor(color));
}
fn void dbgDrawSolidCircle(B2Transform transform, float radius, B2HexColor color, void* context ) {
   r2d::drawCircleV(transform.p.toVector2fast(), radius, hexToColor(color));
}
	//void ( *DrawCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
	//void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
fn void dbgDrawLineSegment(B2Vec2 p1, B2Vec2 p2, B2HexColor color, void* context ) {
   r2d::drawLineV(p1.toVector2fast(), p2.toVector2fast(), hexToColor(color));
}

/// Draw a transform. Choose your own length scale.
fn void dbgDrawTransform(B2Transform transform, void* context) {
    dbgDrawTransformLocal(transform);
}

fn void dbgDrawPoint(B2Vec2 p, float size, B2HexColor color, void* context ) {
    dbgDrawCircle(p, size, color, context);
}
fn void dbgDrawString(B2Vec2 p, ZString s, void* context ) {
   rl::drawTextEx(rl::getFontDefault(), s, p.toVector2fast(), 1.0f, 1.0f, rl::WHITE);
}
