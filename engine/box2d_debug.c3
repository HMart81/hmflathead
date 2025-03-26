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

module engine::physics::box2d::dbg;

import raylib5::rl;

// region DEBUG

/// These colors are used for debug draw.
///	See https://www.rapidtables.com/web/color/index.html
enum HexColor : int (inline int value)
{
	ALICE_BLUE           = 0xf0f8ff,
	ANTIQUE_WHITE        = 0xfaebd7,
	AQUA                 = 0x00ffff,
	AQUAMARINE           = 0x7fffd4,
	AZURE                = 0xf0ffff,
	BEIGE                = 0xf5f5dc,
	BISQUE               = 0xffe4c4,
	BLACK                = 0x000000,
	BLANCHED_ALMOND      = 0xffebcd,
	BLUE                 = 0x0000ff,
	BLUE_VIOLET          = 0x8a2be2,
	BROWN                = 0xa52a2a,
	BURLYWOOD            = 0xdeb887,
	CADET_BLUE           = 0x5f9ea0,
	CHARTREUSE           = 0x7fff00,
	CHOCOLATE            = 0xd2691e,
	CORAL                = 0xff7f50,
	CORN_FLOWER_BLUE     = 0x6495ed,
	CORN_SILK            = 0xfff8dc,
	CRIMSON              = 0xdc143c,
	CYAN                 = 0x00ffff,
	DARK_BLUE            = 0x00008b,
	DARK_CYAN            = 0x008b8b,
	DARK_GOLDENROD       = 0xb8860b,
	DARK_GRAY            = 0xa9a9a9,
	DARK_GREEN           = 0x006400,
	DARK_KHAKI           = 0xbdb76b,
	DARK_MAGENTA         = 0x8b008b,
	DARK_OLIVEGREEN      = 0x556b2f,
	DARK_ORANGE          = 0xff8c00,
	DARK_ORCHID          = 0x9932cc,
	DARK_RED             = 0x8b0000,
	DARK_SALMON          = 0xe9967a,
	DARK_SEAGREEN        = 0x8fbc8f,
	DARK_SLATEBLUE       = 0x483d8b,
	DARK_SLATEGRAY       = 0x2f4f4f,
	DARK_TURQUOISE       = 0x00ced1,
	DARK_VIOLET          = 0x9400d3,
	DEEP_PINK            = 0xff1493,
	DEEP_SKYBLUE         = 0x00bfff,
	DIMGRAY              = 0x696969,
	DODGERBLUE           = 0x1e90ff,
	FIREBRICK            = 0xb22222,
	FLORALWHITE          = 0xfffaf0,
	FORESTGREEN          = 0x228b22,
	FUCHSIA              = 0xff00ff,
	GAINSBORO            = 0xdcdcdc,
	GHOSTWHITE           = 0xf8f8ff,
	GOLD                 = 0xffd700,
	GOLDENROD            = 0xdaa520,
	GRAY                 = 0xbebebe,
	GRAY1                = 0x1a1a1a,
	GRAY2                = 0x333333,
	GRAY3                = 0x4d4d4d,
	GRAY4                = 0x666666,
	GRAY5                = 0x7f7f7f,
	GRAY6                = 0x999999,
	GRAY7                = 0xb3b3b3,
	GRAY8                = 0xcccccc,
	GRAY9                = 0xe5e5e5,
	GREEN                = 0x00ff00,
	GREENYELLOW          = 0xadff2f,
	HONEYDEW             = 0xf0fff0,
	HOTPINK              = 0xff69b4,
	INDIANRED            = 0xcd5c5c,
	INDIGO               = 0x4b0082,
	IVORY                = 0xfffff0,
	KHAKI                = 0xf0e68c,
	LAVENDER             = 0xe6e6fa,
	LAVENDERBLUSH        = 0xfff0f5,
	LAWNGREEN            = 0x7cfc00,
	LEMONCHIFFON         = 0xfffacd,
	LIGHTBLUE            = 0xadd8e6,
	LIGHTCORAL           = 0xf08080,
	LIGHTCYAN            = 0xe0ffff,
	LIGHTGOLDENROD       = 0xeedd82,
	LIGHTGOLDENRODYELLOW = 0xfafad2,
	LIGHTGRAY            = 0xd3d3d3,
	LIGHTGREEN           = 0x90ee90,
	LIGHTPINK            = 0xffb6c1,
	LIGHTSALMON          = 0xffa07a,
	LIGHTSEAGREEN        = 0x20b2aa,
	LIGHTSKYBLUE         = 0x87cefa,
	LIGHTSLATEBLUE       = 0x8470ff,
	LIGHTSLATEGRAY       = 0x778899,
	LIGHTSTEELBLUE       = 0xb0c4de,
	LIGHTYELLOW          = 0xffffe0,
	LIME                 = 0x00ff00,
	LIMEGREEN            = 0x32cd32,
	LINEN                = 0xfaf0e6,
	MAGENTA              = 0xff00ff,
	MAROON               = 0xb03060,
	MEDIUMAQUAMARINE     = 0x66cdaa,
	MEDIUMBLUE           = 0x0000cd,
	MEDIUMORCHID         = 0xba55d3,
	MEDIUMPURPLE         = 0x9370db,
	MEDIUMSEAGREEN       = 0x3cb371,
	MEDIUMSLATEBLUE      = 0x7b68ee,
	MEDIUMSPRINGGREEN    = 0x00fa9a,
	MEDIUMTURQUOISE      = 0x48d1cc,
	MEDIUMVIOLETRED      = 0xc71585,
	MIDNIGHTBLUE         = 0x191970,
	MINTCREAM            = 0xf5fffa,
	MISTYROSE            = 0xffe4e1,
	MOCCASIN             = 0xffe4b5,
	NAVAJOWHITE          = 0xffdead,
	NAVY                 = 0x000080,
	NAVYBLUE             = 0x000080,
	OLDLACE              = 0xfdf5e6,
	OLIVE                = 0x808000,
	OLIVEDRAB            = 0x6b8e23,
	ORANGE               = 0xffa500,
	ORANGERED            = 0xff4500,
	ORCHID               = 0xda70d6,
	PALEGOLDENROD        = 0xeee8aa,
	PALEGREEN            = 0x98fb98,
	PALETURQUOISE        = 0xafeeee,
	PALEVIOLETRED        = 0xdb7093,
	PAPAYAWHIP           = 0xffefd5,
	PEACHPUFF            = 0xffdab9,
	PERU                 = 0xcd853f,
	PINK                 = 0xffc0cb,
	PLUM                 = 0xdda0dd,
	POWDERBLUE           = 0xb0e0e6,
	PURPLE               = 0xa020f0,
	REBECCAPURPLE        = 0x663399,
	RED                  = 0xff0000,
	ROSYBROWN            = 0xbc8f8f,
	ROYALBLUE            = 0x4169e1,
	SADDLEBROWN          = 0x8b4513,
	SALMON               = 0xfa8072,
	SANDYBROWN           = 0xf4a460,
	SEAGREEN             = 0x2e8b57,
	SEASHELL             = 0xfff5ee,
	SIENNA               = 0xa0522d,
	SILVER               = 0xc0c0c0,
	SKYBLUE              = 0x87ceeb,
	SLATEBLUE            = 0x6a5acd,
	SLATEGRAY            = 0x708090,
	SNOW                 = 0xfffafa,
	SPRINGGREEN          = 0x00ff7f,
	STEELBLUE            = 0x4682b4,
	TAN                  = 0xd2b48c,
	TEAL                 = 0x008080,
	THISTLE              = 0xd8bfd8,
	TOMATO               = 0xff6347,
	TURQUOISE            = 0x40e0d0,
	VIOLET               = 0xee82ee,
	VIOLETRED            = 0xd02090,
	WHEAT                = 0xf5deb3,
	WHITE                = 0xffffff,
	WHITESMOKE           = 0xf5f5f5,
	YELLOW               = 0xffff00,
	YELLOWGREEN          = 0x9acd32,
	BOX2DRED             = 0xdc3132,
	BOX2DBLUE            = 0x30aebf,
	BOX2DGREEN           = 0x8cc924,
	BOX2DYELLOW          = 0xffee8c
}

<*
This struct holds callbacks you can implement to draw a Box2D world.
*>
def DrawPolygonCallback      = fn void(Vec2*,int,HexColor,void* ctx = null);
def DrawSolidPolygonCallback = fn void(box2d::Transform,Vec2*,int,float,HexColor,void* ctx = null);
def DrawCircleCallback       = fn void(Vec2,float,HexColor,void* ctx = null);
def DrawSolidCircleCallback  = fn void(box2d::Transform,float,HexColor,void* ctx = null);
def DrawCapsuleCallback      = fn void(Vec2,Vec2,float,HexColor,void* ctx = null);
def DrawSolidCapsuleCallback = fn void(Vec2,Vec2,float,HexColor,void* ctx = null);
def DrawSegmentCallback      = fn void(Vec2,Vec2,HexColor,void* ctx = null);
def DrawTransformCallback    = fn void(box2d::Transform,void* ctx = null);
def DrawPointCallback        = fn void(Vec2,float,HexColor,void* ctx = null);
def DrawStringCallback       = fn void(Vec2,ZString,void* ctx = null);

struct DebugDraw
{
	/// Draw a closed polygon provided in CCW order.
	//void ( *DrawPolygon )( const Vec2* vertices, int vertexCount, b2HexColor color, void* context );
    DrawPolygonCallback drawPolygon;
	/// Draw a solid closed polygon provided in CCW order.
	//void ( *DrawSolidPolygon )( box2d::Transform transform, const Vec2* vertices, int vertexCount, float radius, b2HexColor color, void* context );
    DrawSolidPolygonCallback drawSolidPolygon; 
	//void ( *DrawCircle )( Vec2 center, float radius, b2HexColor color, void* context );
    DrawCircleCallback drawCircle;
	//void ( *DrawSolidCircle )( box2d::Transform transform, float radius, b2HexColor color, void* context );
    DrawSolidCircleCallback drawSolidCircle;
	//void ( *DrawCapsule )( Vec2 p1, Vec2 p2, float radius, b2HexColor color, void* context );
    DrawCapsuleCallback drawCapsule;
	//void ( *DrawSolidCapsule )( Vec2 p1, Vec2 p2, float radius, b2HexColor color, void* context );
    DrawSolidCapsuleCallback drawSolidCapsule;
	/// Draw a line segment.
	//void ( *DrawSegment )( Vec2 p1, Vec2 p2, b2HexColor color, void* context );
    DrawSegmentCallback drawSegment;
	/// Draw a transform. Choose your own length scale.
	//void ( *DrawTransform )( box2d::Transform transform, void* context );
    DrawTransformCallback drawTransform;
	//void ( *DrawPoint )( Vec2 p, float size, b2HexColor color, void* context );
    DrawPointCallback drawPoint;
	//void ( *DrawString )( Vec2 p, const char* s, void* context );
    DrawStringCallback drawString;
    
	/// Bounds to use if restricting drawing to a rectangular region
	AABBox drawingBounds;

	/// Option to restrict drawing to a rectangular region. May suffer from unstable depth sorting.
	bool useDrawingBounds;

	/// Option to draw shapes
	bool drawShapes;

	/// Option to draw joints
	bool drawJoints;

	/// Option to draw additional information for joints
	bool drawJointExtras;

	/// Option to draw the bounding boxes for shapes
	bool drawAABBs;

	/// Option to draw the mass and center of mass of dynamic bodies
	bool drawMass;

	/// Option to draw contact points
	bool drawContacts;

	/// Option to visualize the graph coloring used for contacts and joints
	bool drawGraphColors;

	/// Option to draw contact normals
	bool drawContactNormals;

	/// Option to draw contact normal impulses
	bool drawContactImpulses;

	/// Option to draw contact friction impulses
	bool drawFrictionImpulses;

	/// User context that is passed as an argument to drawing callback functions
	void* context;
}

extern fn DebugDraw defaultDebugDraw() @extern("b2DefaultDebugDraw");

// end_region DEBUG

<*
    @param [inout] dd "the debugDraw struct to init"
    @require dd != null
*>
fn void initDebugDraw(DebugDraw* dd) {
    //(*dd) = defaultDebugDraw();
    // draw callbacks
    dd.drawPolygon        = &drawPolygon;
    dd.drawSolidPolygon   = &drawSolidPolygon;
    dd.drawCircle         = &drawCircle;
    dd.drawSolidCircle    = &drawSolidCircle;
    //dd.drawCapsule      = &drawCapsule;
    //dd.drawSolidCapsule = &drawSolidCapsule;
    dd.drawSegment        = &drawLineSegment;
    //dd.drawTransform      = &drawTransform;
    dd.drawPoint          = &drawPoint;
    dd.drawString         = &drawString;
    //
    
    // drawing options
	dd.drawShapes           = true;
	//dd.drawJoints         = true;
	//dd.drawJointExtras      = true;
	dd.drawAABBs            = true;
	//dd.drawMass             = true;
	dd.drawContacts         = true;
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
fn void deinitDebugDraw(DebugDraw* dd) {
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

fn void drawPolygonLocal(Vec2* vertices, int vertexCount, Color tint) @local
{
    Vec2 p1 = vertices[vertexCount - 1];
    for ( int i = 0; i < vertexCount; ++i )
    {
        Vec2 p2 = vertices[i];
        rl::drawLineV(p1, p2, tint);
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
fn void drawTransformLocal(box2d::Transform transform) @local
{
    unreachable();
/*
	float k_axisScale = 0.2f;
	Vec2 p1 = transform.p;

	Vec2 p2 = box2d::math::mulAdd(p1, k_axisScale, box2d::math::rotGetXAxis(transform.q));
    rl::drawLineV(p1, p2, rl::RED);

	p2 = box2d::math::mulAdd(p1, k_axisScale, box2d::math::rotGetYAxis(transform.q));
    rl::drawLineV(p1, p2, rl::GREEN);
*/
}

macro Color hexColorToColor(int hexValue)
{
  Color rgbColor;
  rgbColor.r = (char)((hexValue >> 16) & 0xFF) / 255;  // Extract the RR byte
  rgbColor.g = (char)((hexValue >> 8) & 0xFF) / 255;   // Extract the GG byte
  rgbColor.b = (char)((hexValue) & 0xFF) / 255;        // Extract the BB byte

  return rgbColor;
}

macro Vector2 vec2ToVector2(Vec2 vec) {
    return (Vector2){vec.x, vec.y};
}


/// Draw a closed polygon provided in CCW order.
fn void drawPolygon(Vec2* vertices, int vertexCount, HexColor color, void* context ) {
    //rl::drawLineStrip((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
    drawPolygonLocal((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
}
/// Draw a solid closed polygon provided in CCW order.
fn void drawSolidPolygon(box2d::Transform transform, Vec2* vertices, int vertexCount, float radius, HexColor color, void* context ) {
    rl::drawTriangleStrip((rl::Vector2*)vertices, vertexCount, hexColorToColor(color));
}
fn void drawCircle(Vec2 center, float radius, HexColor color, void* context ) {
    rl::drawCircleLinesV(vec2ToVector2(center), radius, hexColorToColor(color));
}
fn void drawSolidCircle(box2d::Transform transform, float radius, HexColor color, void* context ) {
    rl::drawCircleV(vec2ToVector2(transform.p), radius, hexColorToColor(color));
}
	//void ( *DrawCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
	//void ( *DrawSolidCapsule )( b2Vec2 p1, b2Vec2 p2, float radius, b2HexColor color, void* context );
fn void drawLineSegment(Vec2 p1, Vec2 p2, HexColor color, void* context ) {
    rl::drawLineV(vec2ToVector2(p1), vec2ToVector2(p2), hexColorToColor(color));
}

/// Draw a transform. Choose your own length scale.
fn void drawTransform(box2d::Transform transform, void* context) {
    drawTransformLocal(transform);
}

fn void drawPoint(Vec2 p, float size, HexColor color, void* context ) {
    drawCircle(p, size, color, context);
}
fn void drawString(Vec2 p, ZString s, void* context ) {
    rl::drawTextEx(rl::getFontDefault(), s, vec2ToVector2(p), 1.0f, 1.0f, rl::WHITE);
}
