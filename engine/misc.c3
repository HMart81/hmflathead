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

module engine::misc;

// region C3 modules
import std::io;
import std::core::mem, std::core::ascii;
import std::io::file;
import std::math;
import std::collections;
//import std::core::string;
import libc;
import game::main;
import game::actors::ent::pl;
import engine::logging::lgr;
import thirdparty::raylib5::rl;
import engine::physics::box2d;
import game::camview;
// end

alias Vec2f  = float[<2>];
alias Vec3f  = float[<3>];
alias Vec4f  = float[<4>];
alias Vec2i  = int[<2>];
alias Vec3i  = int[<3>];

// NOTE(HM) There's no Z or backward and forward, because this is 2D engine
const Vec2f VEC_UP    = {0.0f, -1.0f};
const Vec2f VEC_DOWN  = {0.0f,  1.0f};
const Vec2f VEC_LEFT  = {-1.0f, 0.0f};
const Vec2f VEC_RIGHT = {1.0f,  0.0f};


macro @makeVec2f(#x, #y) => (Vec2f){#x, #y};
macro @makeVec2fExt(#x) => (Vec2f){#x, #x};
//

macro endianSwap(x) {
    // NOTE(HM) this is used to swap the endianness of a 32-bit integer
    // this is used to convert from little-endian to big-endian and vice-versa
    return ((x << 24) |
            ((x & 0xFF00) << 8) | 
            ((x >> 8) & 0xFF00) |
            (x >> 24));
}

<*
    NOTE(HM) used to create a fourcc code from a string,
    this is used to create a fourcc code for file formats,
    do not use this macro with a string that is not 4 characters long.

  @param string : `string to convert to a fourcc code`
  @require string.len == 4
 *>
macro fourcc(string) {
    return (((uint)(string[0]) << 0) |
           ((uint)(string[1]) << 8) |
           ((uint)(string[2]) << 16) |
           ((uint)(string[3]) << 24));
}

// NOTE(HM) this is used to create a fourcc code from a string
// do not use this macro with a string that is not 4 characters long
// do not evaluates to a constant expression
//macro fourcc(string) => (*(uint*)(string));

macro @todo($a = 0) @builtin
{
    $if $feature(_DEBUG):
        unreachable("==> Not yet implemented! <==");
    $endif
}

<*
  @param $a : `start index`
  @param #b : `end index`
  @param [&in] arr : `array to iterate`
  @require arr.len > 0
  @require types::is_intlike($typeof($a)) && types::is_intlike($typeof(#b))
  @require $a >= 0 && #b < arr.len
 *>
macro @forange($a, #b, arr; @body(x, y)) @builtin
{
    for(usz index = (usz)$a; index <= (usz)#b; index++) {
        var it = (*arr)[index];
        @body(index, it);
    }
}


// TODO(HM) put this in a better place
fn KeyboardKey getKeyValueFromName(String name) @inline
{
    // NOTE(HM) this is used to get the key value from a string
    // like "KEY_A" or "KEY_LEFT" etc.
    //return rl::getKeyPressedFromName(stringTotempzstring(name));
    switch(name)
    {
        case "KEY_NULL":            return rl::KEY_NULL;
        case "KEY_APOSTROPHE":      return rl::KEY_APOSTROPHE;
        case "KEY_COMMA":           return rl::KEY_COMMA;
        case "KEY_MINUS":           return rl::KEY_MINUS;
        case "KEY_PERIOD":          return rl::KEY_PERIOD;
        case "KEY_SLASH":           return rl::KEY_SLASH;
        case "KEY_ZERO":            return rl::KEY_ZERO;
        case "KEY_ONE":             return rl::KEY_ONE;
        case "KEY_TWO":             return rl::KEY_TWO;
        case "KEY_THREE":           return rl::KEY_THREE;
        case "KEY_FOUR":            return rl::KEY_FOUR;
        case "KEY_FIVE":            return rl::KEY_FIVE;
        case "KEY_SIX":             return rl::KEY_SIX;
        case "KEY_SEVEN":           return rl::KEY_SEVEN;
        case "KEY_EIGHT":           return rl::KEY_EIGHT;
        case "KEY_NINE":            return rl::KEY_NINE;
        case "KEY_SEMICOLON":       return rl::KEY_SEMICOLON;
        case "KEY_EQUAL":           return rl::KEY_EQUAL;
        case "KEY_A":               return rl::KEY_A;
        case "KEY_B":               return rl::KEY_B;
        case "KEY_C":               return rl::KEY_C;
        case "KEY_D":               return rl::KEY_D;
        case "KEY_E":               return rl::KEY_E;
        case "KEY_F":               return rl::KEY_F;
        case "KEY_G":               return rl::KEY_G;
        case "KEY_H":               return rl::KEY_H;
        case "KEY_I":               return rl::KEY_I;
        case "KEY_J":               return rl::KEY_J;
        case "KEY_K":               return rl::KEY_K;
        case "KEY_L":               return rl::KEY_L;
        case "KEY_M":               return rl::KEY_M;
        case "KEY_N":               return rl::KEY_N;
        case "KEY_O":               return rl::KEY_O;
        case "KEY_P":               return rl::KEY_P;
        case "KEY_Q":               return rl::KEY_Q;
        case "KEY_R":               return rl::KEY_R;
        case "KEY_S":               return rl::KEY_S;
        case "KEY_T":               return rl::KEY_T;
        case "KEY_U":               return rl::KEY_U;
        case "KEY_V":               return rl::KEY_V;
        case "KEY_W":               return rl::KEY_W;
        case "KEY_X":               return rl::KEY_X;
        case "KEY_Y":               return rl::KEY_Y;
        case "KEY_Z":               return rl::KEY_Z;
        case "KEY_LEFT_BRACKET":    return rl::KEY_LEFT_BRACKET;
        case "KEY_BACKSLASH":       return rl::KEY_BACKSLASH;
        case "KEY_RIGHT_BRACKET":   return rl::KEY_RIGHT_BRACKET;
        case "KEY_GRAVE":           return rl::KEY_GRAVE;
        case "KEY_SPACE":           return rl::KEY_SPACE;
        case "KEY_ESCAPE":          return rl::KEY_ESCAPE;
        case "KEY_ENTER":           return rl::KEY_ENTER;
        case "KEY_TAB":             return rl::KEY_TAB;
        case "KEY_BACKSPACE":       return rl::KEY_BACKSPACE;
        case "KEY_INSERT":          return rl::KEY_INSERT;
        case "KEY_DELETE":          return rl::KEY_DELETE;
        case "KEY_RIGHT":           return rl::KEY_RIGHT;
        case "KEY_LEFT":            return rl::KEY_LEFT;
        case "KEY_DOWN":            return rl::KEY_DOWN;
        case "KEY_UP":              return rl::KEY_UP;
        case "KEY_PAGE_UP":         return rl::KEY_PAGE_UP;
        case "KEY_PAGE_DOWN":       return rl::KEY_PAGE_DOWN;
        case "KEY_HOME":            return rl::KEY_HOME;
        case "KEY_END":             return rl::KEY_END;
        case "KEY_CAPS_LOCK":       return rl::KEY_CAPS_LOCK;
        case "KEY_SCROLL_LOCK":     return rl::KEY_SCROLL_LOCK;
        case "KEY_NUM_LOCK":        return rl::KEY_NUM_LOCK;
        case "KEY_PRINT_SCREEN":    return rl::KEY_PRINT_SCREEN;
        case "KEY_PAUSE":           return rl::KEY_PAUSE;
        case "KEY_F1":              return rl::KEY_F1;
        case "KEY_F2":              return rl::KEY_F2;
        case "KEY_F3":              return rl::KEY_F3;
        case "KEY_F4":              return rl::KEY_F4;
        case "KEY_F5":              return rl::KEY_F5;
        case "KEY_F6":              return rl::KEY_F6;
        case "KEY_F7":              return rl::KEY_F7;
        case "KEY_F8":              return rl::KEY_F8;
        case "KEY_F9":              return rl::KEY_F9;
        case "KEY_F10":             return rl::KEY_F10;
        case "KEY_F11":             return rl::KEY_F11;
        case "KEY_F12":             return rl::KEY_F12;
        case "KEY_LEFT_SHIFT":      return rl::KEY_LEFT_SHIFT;
        case "KEY_LEFT_CONTROL":    return rl::KEY_LEFT_CONTROL;
        case "KEY_LEFT_ALT":        return rl::KEY_LEFT_ALT;
        case "KEY_LEFT_SUPER":      return rl::KEY_LEFT_SUPER;
        case "KEY_RIGHT_SHIFT":     return rl::KEY_RIGHT_SHIFT;
        case "KEY_RIGHT_CONTROL":   return rl::KEY_RIGHT_CONTROL;
        case "KEY_RIGHT_ALT":       return rl::KEY_RIGHT_ALT;
        case "KEY_RIGHT_SUPER":     return rl::KEY_RIGHT_SUPER;
        case "KEY_KB_MENU":         return rl::KEY_KB_MENU;
        case "KEY_KP_0":            return rl::KEY_KP_0;
        case "KEY_KP_1":            return rl::KEY_KP_1;
        case "KEY_KP_2":            return rl::KEY_KP_2;
        case "KEY_KP_3":            return rl::KEY_KP_3;
        case "KEY_KP_4":            return rl::KEY_KP_4;
        case "KEY_KP_5":            return rl::KEY_KP_5;
        case "KEY_KP_6":            return rl::KEY_KP_6;
        case "KEY_KP_7":            return rl::KEY_KP_7;
        case "KEY_KP_8":            return rl::KEY_KP_8;
        case "KEY_KP_9":            return rl::KEY_KP_9;
        case "KEY_KP_DECIMAL":      return rl::KEY_KP_DECIMAL;
        case "KEY_KP_DIVIDE":       return rl::KEY_KP_DIVIDE;
        case "KEY_KP_MULTIPLY":     return rl::KEY_KP_MULTIPLY;
        case "KEY_KP_SUBTRACT":     return rl::KEY_KP_SUBTRACT;
        case "KEY_KP_ADD":          return rl::KEY_KP_ADD;
        case "KEY_KP_ENTER":        return rl::KEY_KP_ENTER;
        case "KEY_KP_EQUAL":        return rl::KEY_KP_EQUAL;
        case "KEY_BACK":            return rl::KEY_BACK;
        case "KEY_MENU":            return rl::KEY_MENU;
        case "KEY_VOLUME_UP":       return rl::KEY_VOLUME_UP;
        case "KEY_VOLUME_DOWN":     return rl::KEY_VOLUME_DOWN;
        default:
            lgr::error(Where.FILE, "Unknown key name: %s", name);
            return rl::KEY_NULL; // unknown key
    }
}

const MINIMUM_SIZE_IN_PIXELS = 1;    //
const MINIMUM_SIZE_IN_METERS = 0.1f; // 10 cm

fn int metersToPixels(float meters) {
    if(meters <= 0.1f) {
        return MINIMUM_SIZE_IN_PIXELS;
    }
    return (int)(math::floor(meters) * main::DEFAULT_PIXELS_PER_METER);
}

fn float pixelsToMeters(int pixels) {
    if(pixels <= MINIMUM_SIZE_IN_METERS) return MINIMUM_SIZE_IN_METERS;
    
    float m = (float)(pixels / main::DEFAULT_PIXELS_PER_METER);
    if(m <= MINIMUM_SIZE_IN_METERS) {
        return MINIMUM_SIZE_IN_PIXELS;
    } else {
        return m;
    }
}

const Color INVISIBLE_COLOR = {0xFF, 0xFF, 0xFF, 0x00};
fn String printColor(Color color) @inline {
    return string::tformat("{%s,%s,%s,%s}", color.r, color.g, color.b, color.a);
} 

fn Vector2 Vec2f.toVector2(&self) => (Vector2) {self.x, self.y};

attrdef @Hardcode; // empty user attribute (Need to start with a uppercase...)
attrdef @Performance;
attrdef @Exported; // used mainly to mark external functions from static libraries that are accessible because got exported when compiled by VS, CC or GCC

// cardinal directions
const int COORD_180_NORTH =  90;
const int COORD_180_SOUTH = -90;
const int COORD_180_EAST  =   0;
const int COORD_180_WEST  = 180;
// ordinal
const int COORD_180_NOREAST =   45;
const int COORD_180_NORWEST =  135;
const int COORD_180_SOUEAST =  -45;
const int COORD_180_SOUWEST = -135;


const int COORD_360_NOREAST = 45;  // ordinal direction
const int COORD_360_NORTH   = 90;  // cardinal direction
const int COORD_360_NORWEST = 135; // ordinal direction
const int COORD_360_WEST    = 180; // cardinal direction
const int COORD_360_SOUWEST = 225; // ordinal direction
const int COORD_360_SOUTH   = 270; // cardinal direction
const int COORD_360_SOUEAST = 315; // ordinal direction
const int COORD_360_EAST    = 360; // cardinal direction

/***************************************************************************************
     + A bunch of diferent utility functions
 
    My own code or taken from/inspired by, other sources.
***************************************************************************************/



// region Debug Lines
alias ArrayOfLinesPtr @local = List{DebugLine*};
ArrayOfLinesPtr g_debugLines;

struct DebugLine {
    Vec2f startPos;
    Vec2f endPos;
    Color color;
    bool nodraw;
    int lifetime; // ms
}

fn void DebugLine.update(&self) @inline {
    if(self.lifetime < main::gpGame.time_ms) {
        self.nodraw = true;
    }
}

fn void DebugLine.draw(&self) @inline {
    //if(self.nodraw == false) rl::drawLineV(self.startPos.toVector2(), self.endPos.toVector2(), self.color);
    if(self.nodraw == false) draw_arrow(self.startPos, self.endPos, self.color);
}

fn void makeDebugLine(Vec2f start, Vec2f end, RColor color, int lifetime_ms = 5000) @inline {
    DebugLine* line = mem::new(DebugLine);
    line.startPos   = start;
    line.endPos     = end;
    line.color      = color;
    line.lifetime   = main::gpGame.time_ms + lifetime_ms;
    line.register();
}

fn void DebugLine.register(&self) @inline {
    g_debugLines.push(self);
}

fn void freeDebugLines() @inline {
    foreach(line: g_debugLines) {
        mem::free(line);
        line = null;
    }
    g_debugLines.free();
}

<*
 @param [&in] line : "pointer to a DebugLine"
*>
fn bool debugLineIsValid(DebugLine* line) {
    return (line.lifetime >= 1000) ? true : false;
}
// end_region Debug Lines

// some debug functions
fn void drawDebugPoint(Vec2f pos, Color color) @inline {
    rl::drawCircleV(pos.toVector2(), 3.0f, color);
}

fn void drawDebugLine(Vec2f start, Vec2f end, Color color) @inline {
    rl::drawLineV(start.toVector2(), end.toVector2(), color);
}

fn void drawDebugBox(Vec2f pos, Vec2f size, Color color) @inline {
    rl::drawRectangleV(pos.toVector2(), size.toVector2(), color);
}

// region MATH misc
macro float square(float x) {
    return x * x;
}

macro int sec2ms(x)   => (int)math::floor(x * 1000.0f);
macro float ms2sec(x) => ((float)x * 1000.0f);
macro float pixelsTometers(p) => (p / 10.0f);
macro float metersTopixels(m) => (m * 10.0f);

macro uint megaBytes2Bytes(x) => ((x) << 20);
macro uint bytes2MB(x)        => ((x) >> 20);
// macro float pixelsTopercent(x) => (x / 10.0f); // 1.0% = 10.0 pixels
// macro float percentTopixels(x) => (x * 10.0f);

// @performance!!!!!!!!!!!!!!
// macro float @percent(#p, $x) { 
    // var percent = (((float)$p * 1.0f) / 100.0f);
    // return  percent * $x;
// }

macro float @percent(float p, #x) => p * $x;

macro int @bit($x) => 1 << $x;

macro Vec2f worldToScreen(Vec2f wpos) => rl::getWorldToScreen2D(wpos, main::gpGame.cameraView);
macro Vec2f screenToWorld(spos) => rl::getScreenToWorld2D(wpos, main::gpGame.cameraView);
// end_region MATH misc

// region vec2 extensions
fn void Vec2f.scale(&self, float x, float y) @inline {
    (*self) = { self.x * x, self.y * y };
}

fn void Vec2f.scaleV(&self, Vec2f vec) @inline {
    self.scale(vec.x, vec.y);
}

fn void Vec2f.translate(&self, float x, float y) @inline {
    Matrix3f mat = {
        1, 0, 0,
        0, 1, 0,
        x, y, 1
    };
    
    (*self) = {
        mat.m00 * (*self)[0] + mat.m10 * (*self)[1] + mat.m20 ,
        mat.m01 * (*self)[0] + mat.m11 * (*self)[1] + mat.m21
    };
}

fn void Vec2f.translateV(&self, Vec2f vec) @inline {
    self.translate(vec.x, vec.y);
}
// end_region vec2 extensions

// region Matrix3f extensions
macro Matrix3f.getScale(&self) => (Vec2f){self.m00, self.m11};
macro Matrix3f.getTranslation(&self) => (Vec2f){self.m02, self.m12};
macro Matrix3f.getRotation(&self) => (Vec2f){self.m10, self.m01};
macro Vec2f Matrix3f.multiply(&self, Vec2f v) {
    Matrix3f m = self.transpose();
    Vec2f result = {m.m00 * v.x + m.m10 * v.y, m.m01 * v.x + m.m11 * v.y};
    return result;
}
// end_region Matrix3f extensions

// region box2d non exported functions
/// Make a rotation using an angle in radians
fn B2Rot makeRot(float radians) @inline
{
	B2CosSin cs = box2d::computeCosSin( radians );
	return (B2Rot){ cs.cosine, cs.sine };
}

fn B2Vec2 mulAdd( B2Vec2 a, float s, B2Vec2 b ) @inline
{
	return (B2Vec2){ a[0] + s * b[0], a[1] + s * b[1] };
}

/// Get the angle in radians in the range [-pi, pi]
fn float rot_GetAngle( B2Rot q ) => box2d::atan2( q.s, q.c );

/// Get the x-axis
fn B2Vec2 rot_GetXAxis( B2Rot q ) => (B2Vec2) { q.c, q.s };

/// Get the y-axis
fn B2Vec2 rot_GetYAxis( B2Rot q ) => (B2Vec2) { -q.s, q.c };
// end_region


// region raylib Rectangle extensions
macro Rectangle makeRect(Vec2f v1, Vec2f v2) => (Rectangle){v1.x, v1.y, v2.x, v2.y};

macro Vec2f Rectangle.getScreenPos(self) => worldToScreen(self.getPosition());

// NOTE(HM) This may return the exact same coords as put in if
// the camera is never moved around, as world coords and camera coords
// are very similar only the center/origin changes.
// UNTESTED!!!!!!!!!!!!!!!!!!!!!
fn Vec2f Rectangle.getPosCameraCoords(&self) @if ($defined(ENABLE_CAMERA_VIEW))
{
    Vec2f world_origin   = {0, 0};
    Vec2f cam_org        = main::gpGame.view.camera.target.toVec2f();
    Vec2f offset_vec_dir = cam_org - world_origin;
    float offset_len     = offset_vec_dir.length();
    
    return self.getPosition().toVec2f() * offset_vec_dir.normalize() * offset_len; 
}
// end_region raylib Rectangle extensions

// region Texture stuff
// WARNING(HM) Raylib doesn't support .tga's with RLE compression...
fn rl::Texture2D loadTexture(String image_path) @inline 
{
    assert(rl::isWindowReady() == true, "Window not ready! Unable to load texture");
    
    Texture2D tex = rl::loadTexture(stringTotempzstring(image_path));

$if $feature(_DEBUG):
    assert(rl::isTextureValid(tex));
    return tex;
$else
    lgr::warning(Where.FILE, "Failed to load Texture '%s' returning default texture...", image_path);
    return main::gpGame.default_texture;
$endif
}

fn bool rl::Texture2D.isInvalid(&self) @inline {
    if(self.id      == 0 &&  // OpenGL texture id
       self.width   == 0 &&  // Texture base width
       self.height  == 0 &&  // Texture base height
       self.mipmaps == 0 &&  // Mipmap levels, 1 by default
       self.format.ordinal  == 0 )   // Data format (PixelFormat type)
      {
        return true;
      }
        
    return false;
}
// end_region

// region Sound stuff
fn Sound loadSound(String asset_path) @inline {
    if(rl::isAudioDeviceReady()) {
        Sound sd = rl::loadSound(stringTotempzstring(asset_path));
        assert(rl::isSoundValid(sd));
        return sd;
    }
    
    lgr::warning(Where.FILE,  "Unable to load » %s", asset_path);
    return main::gpGame.default_sound;
}
// end_region

macro sec_since_init()  => main::gpGame.time_sec;
macro mili_since_init() => main::gpGame.time_ms;

macro bool recIsValid(rec) => ((getRecSize(rec).length() + getRecPos(rec).length()) > 0) ? true : false;

macro Rectangle @recFromVecs(#vec1, #vec2) => (Rectangle) {#vec1.x, #vec1.y, #vec2.x, #vec2.y};



//////////////////// shader stuff /////////////////
const String SHADER_INCLUDE = `
// default vertex layout locations
#define VERTEX_POSITION   0    // Shader location: vertex attribute: position
#define VERTEX_TEXCOORD01 1    // Shader location: vertex attribute: texcoord01
#define VERTEX_NORMAL     2    // Shader location: vertex attribute: normal
#define VERTEX_COLOR      3    // Shader location: vertex attribute: color
#define VERTEX_TANGENT    4    // Shader location: vertex attribute: tangent
#define VERTEX_TEXCOORD02 5    // Shader location: vertex attribute: texcoord02
// matrix locations
#define MATRIX_MVP        6    // Shader location: matrix uniform: model-view-projection
#define MATRIX_VIEW       7    // Shader location: matrix uniform: view (camera transform)
#define MATRIX_PROJECTION 8    // Shader location: matrix uniform: projection
#define MATRIX_MODEL      9    // Shader location: matrix uniform: model (transform)
#define MATRIX_NORMAL     10   // Shader location: matrix uniform: normal
#define VECTOR_VIEW       11   // Shader location: vector uniform: view
#define COLOR_DIFFUSE     12   // Shader location: vector uniform: diffuse color
#define COLOR_SPECULAR    13   // Shader location: vector uniform: specular color
#define COLOR_AMBIENT     14   // Shader location: vector uniform: ambient color
// texture samplers
#define MAP_ALBEDO        15   // Shader location: sampler2d texture: albedo (same as: SHADER_LOC_MAP_DIFFUSE)
#define MAP_METALNESS     16   // Shader location: sampler2d texture: metalness (same as: SHADER_LOC_MAP_SPECULAR)
#define MAP_NORMAL        17   // Shader location: sampler2d texture: normal
#define MAP_ROUGHNESS     18   // Shader location: sampler2d texture: roughness
#define MAP_OCCLUSION     19   // Shader location: sampler2d texture: occlusion
#define MAP_EMISSION      20   // Shader location: sampler2d texture: emission
#define MAP_HEIGHT        21   // Shader location: sampler2d texture: height
#define MAP_CUBEMAP       22   // Shader location: samplerCube texture: cubemap
#define MAP_IRRADIANCE    23   // Shader location: samplerCube texture: irradiance
#define MAP_PREFILTER     24   // Shader location: samplerCube texture: prefilter
#define MAP_BRDF          25   // Shader location: sampler2d texture: brdf
#define DEPTH0            26   // Shader location: sampler2d texture: depth map 0
#define DEPTH1            27   // Shader location: sampler2d texture: depth map 1
#define DEPTH2            28   // Shader location: sampler2d texture: depth map 2
#define DEPTH3            29   // Shader location: sampler2d texture: depth map 3
`;

const INCLUDE_DIRECTIVE @local = "#include";
const SHADER_HOME_PATH  @local = "shaders/";

fn String String.handleShaderIncludes(self) @local
{
    uint include_count = (uint)self.count(INCLUDE_DIRECTIVE);
    if(include_count > 0)
    {
        String[] lines = self.tsplit("\r\n");
        foreach(String line : lines)
        {
            if(line.is_empty()) continue; // skip empty lines
            if(line.starts_with("//")) continue; // skip comments
            if(line.starts_with("#"))
            {
                String[] tokens = line.tsplit(" ");
                foreach(String token : tokens) 
                {
                    if(token.is_empty()) continue; // skip empty tokens
                    token = token.trim(); // trim whitespace
                }

                String directive = tokens[0];
                if(directive != INCLUDE_DIRECTIVE) continue; // skip if not an include directive

                // NOTE(HM) we expect the include directive to be in the format: #include "path/to/include.inc"
                String include_path = tokens[1];
                String original_include_path = tokens[1].tcopy(); // keep the original path for later use

                if(include_path.contains(".\\") || include_path.contains("./")) {
                    // NOTE(HM) if the include path contains a slash or backslash, we will replace it with a forward slash
                    include_path = include_path.treplace("./", "\\").treplace(".\\", "\\");
                }

                if(include_path.starts_with("\"")) {
                    // NOTE(HM) remove the quotes
                    include_path = include_path.trim("\"");
                }
            
                include_path = SHADER_HOME_PATH.tconcat(include_path);

                assert(include_path.is_empty() == false, "Include path should not be empty!");

                // NOTE(HM) if the include path does not end with .inc, append it
                if(include_path.ends_with(".inc") == false) {
                    include_path = include_path.tconcat(".inc");
                }

                // NOTE(HM) now create the replace token, it will be used to detect the full include directive in the shader code
                // NOTE(HM) this will try to find the include directive text in the shader code, without caring about well-formedness
                String replace_directive = INCLUDE_DIRECTIVE.tconcat(" ").tconcat(original_include_path);

                assert(replace_directive.is_empty() == false, "replace directive should not be empty!");

                String? code_to_included = readEntireFileX(main::gpGame.app_base_folder.tconcat(include_path));
                if(catch excuse = code_to_included) {
                    lgr::error(Where.FILE, "Failed to include file: %s, error: %s", include_path, excuse);
                    // NOTE(HM) if the file is not found, we will just remove the include directive
                    self = self.treplace(replace_directive, "");
                    continue; // skip to next line
                }

                // NOTE(HM) else replace the full include directive with the code to include
                self = self.treplace(replace_directive, code_to_included.tconcat("\n"));
            }
        }
    }

    return self;
}

fn Shader loadShader(String vs_path, String fs_path) 
{
    // NOTE(HM) this is used to load a shader from a vertex and fragment shader file
    // if the paths are empty it will return the default shader
    if(vs_path.is_empty() && fs_path.is_empty()) {
       //lgr::warning(Where.FILE, "Both vertex and fragment shader paths are empty, returning default shaders: %s::%s:%s", $$MODULE, $$FUNCTION, $$LINE);
        return {}; // return empty shader will use raylib default shaders
    }

    //String include_marker = "#include \"defines.inc\"";
    
    // NOTE(HM) if the vertex shader path is empty, it will use the default raylib vertex shader
    String vs_shader_code;
    String fs_shader_code;

    if(vs_path.is_empty()) 
    {
        // NOTE(HM) if the vertex shader path is empty, we will try to load the custom fragment shader only
        fs_shader_code = readEntireFileX(fs_path)!!;
        if(fs_shader_code.is_empty()) {
            lgr::error(Where.FILE, "Failed to load fragment shader from path: %s", fs_path);
            return {}; // return empty shader will use raylib default shaders
        }

        fs_shader_code = fs_shader_code.handleShaderIncludes();
        //if(fs_shader_code.contains(include_marker)) fs_shader_code = fs_shader_code.treplace(include_marker, SHADER_INCLUDE);

        return rl::loadShaderFromMemory("", stringTotempzstring(fs_shader_code));
    }

    // NOTE(HM) if the vertex shader path is not empty, we will try to read the custom vertex shader
    vs_shader_code = readEntireFileX(vs_path)!!;
    if(vs_shader_code.is_empty()) {
        lgr::error(Where.FILE, "Failed to load vertex shader from path: %s", vs_path);
        vs_shader_code = ""; // if for some reason we fail to read our vertex shader, use the raylib default vertex shader
    }

    if(vs_shader_code.is_empty() && fs_path.is_empty()) {
        //lgr::warning(Where.FILE, "Both vertex and fragment shader paths are empty, returning default shaders: %s::%s:%s", $$MODULE, $$FUNCTION, $$LINE);
        return {}; // return empty shader will use raylib default shaders
    }

    //if(vs_shader_code.contains(include_marker)) vs_shader_code = vs_shader_code.treplace(include_marker, SHADER_INCLUDE);
    if(vs_shader_code != "") vs_shader_code = vs_shader_code.handleShaderIncludes();

    if(fs_path.is_empty()) 
    {
        // NOTE(HM) if the fragment shader path is empty, we will use the default raylib fragment shader
        return rl::loadShaderFromMemory(stringTotempzstring(vs_shader_code), "");
    } 
    else
    {
        fs_shader_code = readEntireFileX(fs_path)!!;
        if(fs_shader_code.is_empty()) {
            lgr::error(Where.FILE, "Failed to load fragment shader from path: %s", fs_path);
            // NOTE(HM) we will use the default raylib fragment shader then
            return rl::loadShaderFromMemory(stringTotempzstring(vs_shader_code), "");
        }
    }
    
    // else both shaders are not empty, so we can load them
    return rl::loadShaderFromMemory(stringTotempzstring(vs_shader_code), stringTotempzstring(fs_shader_code));
}

fn void Shader.setUniformFloatValue(self, String uniform_name, float value) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::ShdUniTyp.FLOAT);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeFloatValue(self, String attribute_name, float value) @inline {
    int locIndex = self.getAttributeLocation(stringTozstring(attribute_name));
    assert(locIndex >= 0, "Shader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::ShdUniTyp.FLOAT);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributelocFloatValue(self, int locIndex, float value) @inline {
    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, self.locs[locIndex], (void*)&value, rl::ShdUniTyp.FLOAT);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformFloatSliceValues(self, String uniform_name, float[] values) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::ShdUniTyp.FLOAT, values.len);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeFloatSliceValues(self, String attribute_name, float[] values) @inline {
    int locIndex = self.getAttributeLocation(stringTozstring(attribute_name));
    assert(locIndex >= 0, "Shader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::ShdUniTyp.FLOAT, values.len);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformIntValue(self, String uniform_name, int value) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::ShdUniTyp.INT);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeIntValue(self, String attribute_name, int value) @inline {
    int locIndex = self.getAttributeLocation(stringTozstring(attribute_name));
    assert(locIndex >= 0, "Shader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::ShdUniTyp.INT);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformIntSliceValues(self, String uniform_name, int[] values) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::ShdUniTyp.INT, values.len);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeIntSliceValues(self, String attribute_name, int[] values) @inline {
    int locIndex = self.getAttributeLocation(stringTozstring(attribute_name));
    assert(locIndex >= 0, "Shader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::ShdUniTyp.INT, values.len);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformVector2Value(self, String uniform_name, Vector2 vec) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)&vec, rl::ShdUniTyp.VEC2, 1);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeVector2Value(self, String attribute_name, Vector2 vec) @inline {
    int locIndex = self.getAttributeLocation(stringTozstring(attribute_name));
    assert(locIndex >= 0, "Shader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)&vec, rl::ShdUniTyp.VEC2, 1);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setAttributeLocValueV(self, int locIndex, float[] vec) @inline {
    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        if(vec.len == 2) 
        {
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::ShdUniTyp.VEC2, 1);
        } else if(vec.len == 3) {
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::ShdUniTyp.VEC3, 1);
        } else if(vec.len == 4) {   
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::ShdUniTyp.VEC4, 1);
        } else {
            lgr::warning(Where.FILE, "Shader attribute value vector must be of size 2, 3 or 4.");
        }
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformMatrixValue(self, String uniform_name, Matrix mat) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value matrix
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueMatrix(self, locIndex, mat);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

fn void Shader.setUniformTexture(self, String uniform_name, Texture2D tex) @inline {
    int locIndex = self.getUniformLocation(stringTozstring(uniform_name));
    assert(locIndex >= 0, "Shader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value texture
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueTexture(self, locIndex, tex);
    } else {
        lgr::warning(Where.FILE, "Shader is invalid, unable to set value.");
    }
}

//////////////////////////////////////////////////////////////////////////
// #region String custom extension
/////////////////////////////////////////////////////////////////////////
/*
example on how to use the string splitter

module string;

import std::io;

fn void main() {
    String s = ";string;to;split;";
    Splitter splitter = s.splitter(";");
    while (try split = splitter.next()) {
        io::printf("(%s)", split);
    }
    io::printn("");
    
    output: ()(string)(to)(split)()
}
*/

macro ZString stringTozstring(x) => x.zstr_copy(mem);
macro ZString stringTotempzstring(x) => x.zstr_tcopy();
macro String zstringTostring(x) => x.zstr_view();
macro String zstringTotempstring(x) => string::tformat(x);
macro String numbToStr(n) => string::new_format("%s", n);

macro bool String.is_empty(self) {
    if (self.len == 0) {
        return true;
    }
    return false;
}

// NOTE(HM) helper-function that returns true if the character c is a directory separator
//     on the current platform
macro bool isDirSeparator( c ) {
    if ( c == '/' ) {
        return true;
    }
    $switch:
        $case env::WIN32:
            if ( c == '\\' ) {
                return true;
            }
        $case env::AROS:
            if ( c == ':' ) {
                return true;
            }
    $endswitch
    
    return false;
}

fn ZString String.cpy_zpeace(self, int start, int len) {
    int i = self.len;
    if ( i == 0 || len <= 0 || start >= i ) {
        return "";
    }

    if ( start + len >= i ) {
        len = i - start;
    }
    String result = (String)self[start..len]; //string::tformat("%s", self[:(start + len)]);
    return result.zstr_tcopy();
}

// NOTE(HM) 
// If this is changed need to update VALID_ASSET_EXTENSIONS in asset.c3 as well.
const String[*] FILE_EXTENSIONS_ARRAY = {
    ".exe",
    ".txt",
    ".zip",
    ".7zip",
    ".ini",
    ".fnt",
    ".png",
    ".jpg",
    ".tga",
    ".vs",
    ".fs",
    ".wav",
    ".mp3",
    ".ogg"
};

fn String String.stripExtension(self) {
    bool known_extension = false;
    String needle;
    foreach(String ext : FILE_EXTENSIONS_ARRAY) {
        if(self.ends_with(ext)) {
            known_extension = true;
            needle = ext;
            break;
        }
    }
    
    if(known_extension) {
        return self.strip_end(needle);
    } else {
        lgr::warning(Where.FILE,  "Cannot strip extension is unkown: %s.", needle);
        return self; // do nothing
    }
}

macro String[] cut_by_newline(str) {
    $switch:
        $case env::POSIX:
            return str.tsplit("\r\n");
        $case env::WIN32:
            return str.tsplit("\n");
    $endswitch
}

macro String[] cut_by_spaces(str) => str.tsplit(" ");

macro void String.remove_spaces(&self) 
{
    *self = self.treplace(" ", ""); // remove all spaces
    // trim any white space at start and end leave only the middle if any
    // self = self.trim();
    // //
    // // see if we still have spaces else do nothing
    // if(self.has_spaces()) 
    // {
    //     char[] buffer;
    //     usz count;
    //     $foreach $i, $ch : self:
    //         $if $ch != ' ':
    //             buffer[$i] = $ch;
    //         $endif
    //     $endforeach
        
    //     buffer[count] = '\0';
    //     self.copy((String)buffer);
    // }
}

// NOTE(HM) my own string improvement....
// fn void String.extractFileBase(self, String *dest ) {

    // //
    // // back up until a \ or the start
    // //
    // int pos = self.len - 1;
    // while( ( pos > 0 ) && !isDirSeparator(self[ pos - 1 ]) ) {
        // pos--;
    // }

    // int start = pos;
    // while( ( pos < self.len ) && ( self[ pos ] != '.' ) ) {
        // pos++;
    // }
    // mem::copy(dest, self.cpy_zpeace( start, pos - start).str_view(), (usz)(pos - start));
// }

fn String String.extractFileBaseByCopy(self) { // using self you are passing by value use &self to pass by ref

    //back up until a \ or the start
    int pos = self.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(self[ pos - 1 ]) ) {
        pos--;
    }
    return self[pos..];
}

fn void String.extractFileBaseByRef(&self) { // using self you are passing by value use &self to pass by ref

    //back up until a \ or the start
    String copy = *self;
    int pos = copy.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(copy[ pos - 1 ]) ) {
        pos--;
    }

    int start = pos;
    (*self) = string::tformat("%s", copy[start..]);
}

fn String String.extractFileBase(&self) 
{

    //back up until a \ or the start
    String copy = self.tcopy();
    int pos = copy.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(copy[ pos - 1 ]) ) {
        pos--;
    }

    int start = pos;
    return (String)copy[start..];
}

// fn String getAssetNameFrom(String path) @inline {
    // return path.extractFileBaseByCopy();
// }

struct EntireFile @local {
    usz contents_size;
    void* contents;
}

// »Performance?
fn String? readEntireFileX(String filepath) 
{
    EntireFile _file;
    
    File data = file::open(filepath, "rb")!;
    defer (void)data.close();
    
    if(data.file != null)
    {
        _file.contents_size = data.seek(0, Seek.END)!;
        data.seek(0, SET)!; // return to the start
        _file.contents = mem::calloc(char.sizeof * _file.contents_size);
        char[] buffer = ((char*)_file.contents)[:_file.contents_size];
        data.read(buffer[:_file.contents_size])!;
        return ((String)buffer).tcopy();
    } else{
        lgr::error(Where.FILE, "Cannot open file: %s", filepath);
    }
    
    return (String)"";
}

fn String? readEntireFile(String filepath) @inline {
    char[] buffer;
    fault excuse = @catch(file::load_buffer(filepath, buffer));
    
    return string::format(mem, "%s", buffer);
}

fn int String.count_spaces(&self) @inline {
    int count = 0;

    foreach(ch : self) {
        if (ch == ' ') count++;
    }

    return count;
}

fn bool String.has_spaces(&self) @inline {
    if(self.count_spaces() > 0) return true;
    
    // else
    return false;
}
// #endregion String custom extensions

// #region raw strings/ZString utils
fn int ZString.count_spaces(&self) @inline {
    return self.str_view().count_spaces();
}

fn bool ZString.has_spaces(self, int* out_count) @inline {
    char* src = self;
    while(*src != '\0') 
    {
        if (ascii::is_space(*src)) (*out_count)++;
        src++;
    }

    return ((*out_count) > 0) ? true : false;
}
// #endregion raw strings utils

/////////////////////////////////////////////////////////////////////
////////////////// region PROFILING /////////////////////////////////
/////////////////////////////////////////////////////////////////////
// todo make this into a internal module?
<*
  @require rl::isWindowReady() == true "right now window most be initialized for Profiling to work"
*>
macro void @profile_zone(String name, bool on = true; @body()) {
$if $feature(_PROFILE):
    if(on) {
        var start_time = rl::getTime(); // in seconds
        defer
        {
            var current_time = rl::getTime();
            var value        = math::abs(start_time - current_time);
            String report    = string::tformat("Prof Zone-> [%s]\n{\n Func: %s\n Time: %s %s\n}", name, $$FUNC, value, ((float)value >= 1.0f) ? "sec" : "ms");
            io::printfn(report);
            /*@pool() {
                String time_type = "ms";
                if((float)value >= 1.0f) {
                    time_type = "sec";
                }
                io::printfn("Profile Zone -> [%s]\n{\n Func: %s\n Time: %s %s\n}", name, $$FUNC, value, time_type);
            };*/
        }
    }
$endif
    @body();
}

// deprected functions
<*
  @require rl::isWindowReady() == true "right now window most be initialized for Profiling to work"
  @return `start time of function`
*>
macro float @start_profile_zone() @builtin {
    return 0.0f;
/*
$if $feature(PROFILE):
    var ms = (float)rl::getTime() * 1000.0f;
    return ms;
$else
    return 0.0f;
$endif
*/
}

<*
 @require rl::isWindowReady() == true "right now window most be initialized for Profiling to work"
*>
macro @end_profile_zone(#start_time) @builtin {
/*
$if $feature(PROFILE):
        var ms    = (float)rl::getTime() * 1000.0f;
        var value = math::abs(math::ceil(#start_time /*in ms*/ - ms));
        bool print_sec = false;
        if(value >= 1000.0f) {
            value = value / 1000.0f;
            print_sec = true;
        }
        //main::gpGame.gameView.pushDebugText("Performance zone:\n [%s] = %s %s", name, value, (print_sec) ? "sec" : "ms");
        io::printfn("Performance zone:\n [%s] = %s %s", $$FUNC, value, (print_sec) ? "sec" : "ms");
$endif
*/
}

// end_region PROFILING //////////////////////////////////////////////////////////////////////////////////////////////////////////////


// region MISC
fn Vec2f dir_mul(pl::Move_Dir d, float a) @inline {
    return (Vec2f) { d.vec.x * a, d.vec.y * a };
}

fn void axis_scale(Matrix2f* mat, Vec2f vec) @inline {
    if(mat) {
        mat.m00 *= vec.x;
        mat.m11 *= vec.y;
    }
}


macro @printstruct(value)
{
    var $Type = $typeof(value);
    $if $Type.kindof != STRUCT:
        io::print(value);
    $else
        io::print("{\n");
        $foreach $i, $member : $Type.membersof:
            $if $i > 0:
                io::print(",\n");
            $endif

            $if $member.nameof != "":
                io::printf("    %s : ", $member.nameof);
                @printstruct($member.get(value));
            $endif
        $endforeach
        io::print("\n}\n");
    $endif
}

fn void draw_arrow(Vec2f start, Vec2f end, Color color, Vec2f arrow_size = {16.0f, 8.0f})
{
    /*
    //Draw a color-filled triangle (vertex in counter-clockwise order!)

    Vec2f v1, v2, v3, vdir;
    vdir = end - start;
    vdir = vdir.normalize();
    
    v1 = end;
    //
    v2 = end;
    v3 = end;
    /*
    v1 = v1 + vdir.rotate(90) * arrow_size.x / 2;
    v2 = end.toVec2f() + vdir * arrow_size.y;
    v3 = end.toVec2f();
    v3 = v3 + vdir.rotate(-90) * arrow_size.x / 2;
    */
    v1.translateV(vdir.rotate(90) * arrow_size.x / 2);
    v2.translateV(vdir * arrow_size.y);
    v3.translateV(vdir.rotate(-90) * arrow_size.x / 2);
    rl::drawTriangle(v1.toVector2(), v2.toVector2(), v3.toVector2(),  color);
    // draw the line removing the arrow len from the line lenght
    Vec2f _end = v1 - ((v1 - v3) / 2);
    rl::drawLineV(start.toVector2(), _end.toVector2(), color);
    */
}

macro mat2_identity() => matrix::IDENTITY2{float};

macro int fmin_to_sec(int minutes) 
{
    if (minutes <= 1) return 60; // returns 60 seconds

    return ((int)((float)minutes / 60.0f) * 60);
}

<*
  @require type <= uint.max "ulong most be within uint size"
*>
fn uint safeTruncateU64(ulong type) @inline => (uint)type;
<*
  @require type <= int.max "long most be within int size"
*>
fn int safeTruncateS64(long type) @inline => (int)type;

fn bool memory_is_equal(uint count, any ainit, any binit) {
    char* a = (char*)ainit.ptr;
    char* b = (char*)binit.ptr;
    while (count--) {
        if (*a++ != *b++) {
            return false;
        }
    }

    return true;
}

fn int roundFloatToInt( float value) @inline {
    int result = (int)(math::rint(value));
    return result;
}

// f64 to int64
fn long roundDoubleToLong(double value) @inline {
    long result = (long)math::rint(value);
    return result;
}

<*
 Convert an type to another type safely, returning an failure if there is a type mismatch.

 @param #value : `the value to convert to the given type.`
 @param $Type : `the type to convert to`
 @return `The value converted to its type.`
 @ensure @typeis(return, $Type*)
*>
macro @safeRoundCast(#value, $Type) => ($Type)libc::rint(#value);

macro @mapValueRangeToOther(#x, $in_min, $in_max, $out_min, $out_max)
{
    return ($typeof(#x))(#x - $in_min) * ($out_max - $out_min) / ($in_max - $in_min) + $out_min;
}

// macro @mapValueRangeToOtherX(#x, #in_min, #in_max, #out_min, #out_max)
// {
    // return ($typeof(#x))(#x - #in_min) * (#out_max - #out_min) / (#in_max - #in_min) + #out_min;
// }

macro clamp01f(x) => math::clamp((float)x, 0.0f, 1.0f);

macro float @clamp01fMapToRange(#x, #min, #max) {
    var result = 0.0f;
    var range  = (float)#max - (float)#min;
    if(range != 0.0f) {
        result = clamp01f((float)(#x - #min) / range);
    }
    return result;
}

macro @clampfBinormalMapToRange(#x, #min, #max) {
    return -1.0f + 2.0f * @clamp01fMapToRange(#x, #min, #max);
}

macro reverse_digits(num)
{
    var rev_num = 0;
    $for rev_num; num > 0; num = num / 10:
        rev_num = rev_num * 10 + num % 10;
    $endfor
    
    return rev_num;
}

// end_region MISC

/*
    fn void count_spaces2( char* src, int& out_count) {
        out_count = 0;

        while (*src != '\0') {
            if (isspace(*src)) out_count += 1;
            src++;
        }
    }
    //

    fn float get_angle_from_points_2d( Vec2f& startPos,  Vec2f& goalPos)
    {
        float fDx;
        float fDy;
        float result;

        fDx = goalPos.x - startPos.x;
        fDy = goalPos.y - startPos.y;
        if (fDx == 0)fDx = 0.00001;
        if (fDy == 0)fDy = 0.00001;


        if (fDx >= 0 && fDy < 0)
        {
            result = std::atanf(fDx / (-fDy));
        }
        else if (fDx >= 0 && fDy >= 0)
        {
            result = std::atanf(fDy / fDx) + (PI / 2);
        }
        else if (fDx < 0 && fDy >= 0)
        {
            result = std::atanf((-fDx) / fDy) + (PI / 2);
        }
        else if (fDx < 0 && fDy < 0)
        {
            result = std::atanf((-fDy) / (-fDx)) + (PI / 2) + PI;
        }
        return float(result);
    }

    fn int random_get_within_range(int min, int max)
    {
        int result = 0;
        int range = max - min;

        if (min == 0) {
            result = cMath::RandRectl(0, max); //random.RandomInt(max);
        }
        else if (min == -1 && max == 1)
        {
            result = (int)std::rint(cMath::RandRectf(-1.0, 1.0));
        }
        else
        {
            int randm = cMath::RandRectl(0, 0x7fff);
            result = min + (randm % (range + 1));
        }

        return int(result);
    }

    fn float random_get_within_range(float min, float max)
    {

        float result = 0;
        int range = (int)floorf(max - min);

        if (min == 0.0 && max > 1) {
            result = (float)cMath::RandRectl(0, (int)floorf(max));
        }
        if (min == 0.0 && max == 1.0) {
            result = cMath::RandRectf(0.0, 1.0);
        }
        else if (min == -1.0 && max == 1.0)
        {
            result = cMath::RandRectf(-1.0, 1.0);
        }
        else
        {
            float randm = (float)cMath::RandRectl(0, 0x7fff);
            //result = min + (float)(randm % (range + 1));

            // return the lost precision
            if(1) 
            { // NOTE(HM) not very tested, disable if necessary
                float fraction = max - floorf(max);
                if (fraction != 0.00f && fraction > 0.08f) {
                    result += fraction;
                }
            }
        }

        return float(result);
    }

    fn int reverse_digits(int num)
    {
        int rev_num = 0;
        while (num > 0)
        {
            rev_num = rev_num * 10 + num % 10;
            num = num / 10;
        }
        return rev_num;
    }

    // breaks a integer value like 1234 into individual numbers
    // WARNING(HM) make sure the numbers don't have leading zeros!!!
    // In C/C++, 0253 or any zero starting number IS A OCTAL number not a base 10 integer!!
    // fn void get_array_from_digits(int num, int** out, int size = 4)
    // {
        // int numb_size = 1000;
        // if (size > 4) {
            // numb_size = (int)pow(10.0, size);
        // }

        // assert(num > 0 && num >= numb_size && num <= INT32_MAX);

        // if (num > 0 && num >= numb_size && num <= INT32_MAX)
        // {
            // int tempNum = num;
            // back_repeat(4) // TODO
            // {
                // int number = tempNum % 10; // get the last char from num
                // tempNum = tempNum / 10; // remove the char from num and reuse num again now smaller
                // (*out)[i] = number;

                // if (i == 0 && number == 0) {
                    // LOG_WARNING("GetArrayFromDigits: found octal number '%i'.\n", num);
                // }
            // }
        // }
    // }

    //-----------------------------------------------------
    // ProjectOntoScreen
    //
    // Project a world position onto screen
    // NOTE(HM) based on a Prey src code utility 
    // @UNTESTED!!!!!!!!!!!!!
    //-----------------------------------------------------
    // fn Vec3f project_onto_screen( Vec3f& world, cGame& game, cCamera3D& camera) {
        // // pdc = projected device coordinates?
        // Vec3f pdc(-1000.0, -1000.0, -1.0);

        // // Convert world -> camera
        // cMatrixf camAxis;
        // camAxis.SetForward(camera.GetForward());
        // camAxis.SetRight(camera.GetRight());
        // camAxis.SetUp(camera.GetUp());
        
        // Vec3f view = cMath::MatrixMulDivideW(camAxis.GetTranspose(), (world - camera.GetPosition()));

        // // Orient from world coords to camera coords (look down +y)
        // var cam = Vec3f(-view.y, view.z, -view.x);

        // if (cam.y > 0.0) {
            // // Adjust for differing FOVs
            // float h, w, fov_x, fov_y;
            // w = game.GetGraphics()->GetLowLevel()->GetScreenSize().x;
            // h = game.GetGraphics()->GetLowLevel()->GetScreenSize().y;
            // fov_x = camera.GetFOV();
            // fov_y = fov_x; // ?????
            // float halfwidth  = w * 0.5f;
            // float halfheight = h * 0.5f;
            // float f = halfwidth / tan(fov_x * 0.5f * (PI / 180.0));
            // float g = halfheight / tan(fov_y * 0.5f * (PI / 180.0));

            // // Project onto screen
            // pdc.x = (cam.x * f / cam.y) + halfwidth;
            // pdc.z = (cam.z * g / cam.y) + halfheight;
            // pdc.y = cam.y;
        // }

        // return pdc;  // negative y indicates behind the view
    // }

    // derived from code from source engine SDK 2010, apart from my own code all other parts belong to respective owners
    // @untested!!!!!!!!!!!!!!!!!
    // fn void matrix_build_rotation_about_axis( Vec3f& vAxisOfRot, float angleDegrees, cMatrixf& dst)
    // {
        // float radians;
        // float axisXSquared;
        // float axisYSquared;
        // float axisZSquared;
        // float fSin;
        // float fCos;

        // fn float square(float value) => value * value;

        // radians = angleDegrees * (PI / 180.0);
        // fSin = sin(radians);
        // fCos = cos(radians);

        // axisXSquared = square(vAxisOfRot.x);
        // axisYSquared = square(vAxisOfRot.y);
        // axisZSquared = square(vAxisOfRot.z);

        // // Column 0:
        // dst.m[0][0] = axisXSquared + (1 - axisXSquared) * fCos;
        // dst.m[1][0] = vAxisOfRot.x * vAxisOfRot.y * (1 - fCos) + vAxisOfRot.z * fSin;
        // dst.m[2][0] = vAxisOfRot.z * vAxisOfRot.x * (1 - fCos) - vAxisOfRot.y * fSin;

        // // Column 1:
        // dst.m[0][1] = vAxisOfRot.x * vAxisOfRot.y * (1 - fCos) - vAxisOfRot.z * fSin;
        // dst.m[1][1] = axisYSquared + (1 - axisYSquared) * fCos;
        // dst.m[2][1] = vAxisOfRot.y * vAxisOfRot.z * (1 - fCos) + vAxisOfRot.x * fSin;

        // // Column 2:
        // dst.m[0][2] = vAxisOfRot.z * vAxisOfRot.x * (1 - fCos) + vAxisOfRot.y * fSin;
        // dst.m[1][2] = vAxisOfRot.y * vAxisOfRot.z * (1 - fCos) - vAxisOfRot.x * fSin;
        // dst.m[2][2] = axisZSquared + (1 - axisZSquared) * fCos;
    // }

    //-----------------------------------------------------------------------------
    // Purpose: Return the difference between two angles
    //-----------------------------------------------------------------------------
    fn float angle_diff(float destAngle, float srcAngle)
    {
        float delta;

        delta = destAngle - srcAngle;
        if (destAngle > srcAngle)
        {
            while (delta >= 180) delta -= 360;
        }
        else
        {
            while (delta <= -180) delta += 360;
        }
        return float(delta);
    }

    //-----------------------------------------------------------------------------
    // Purpose: Return the difference between two floats
    //-----------------------------------------------------------------------------
    fn float f32_get_diff(float f1, float f2) 
    {
        if (f1 > f2) {
            return f1 - f2;
        }
        else {
            return f2 - f1;
        }
    }

    //-----------------------------------------------------------------------------
    // Purpose: Return the difference between two int integers
    //-----------------------------------------------------------------------------
    fn int s32_get_diff(int s1, int s2)
    {
        if (s1 > s2) {
            return s1 - s2;
        }
        else {
            return s2 - s1;
        }
    }

    fn void move_toward(float& a, float b, float amount_increasing, float amount_decreasing = -1.0) {
        if (a > b) {
            if (amount_decreasing == -1.0) amount_decreasing = amount_increasing;

            a -= amount_decreasing;

            if (a < b) a = b;
        }
        else {
            a += amount_increasing;
            if (a > b) a = b;
        }
    }

    fn float move_toward_(float a, float b, float amount_increasing, float amount_decreasing = -1.0)
    {
        if (a > b) {
            if (amount_decreasing == -1.0) amount_decreasing = amount_increasing;

            a -= amount_decreasing;

            if (a < b) a = b;
        }
        else {
            a += amount_increasing;
            if (a > b) a = b;
        }

        return float(a);
    }

    fn void move_toward(float* a_pointer, float b, float dt, float rate_up, float rate_down = -1.0)
    {
        float a = *a_pointer;

        if (a > b) {
            if (rate_down == -1.0) rate_down = rate_up;
            a -= dt * rate_down;
            *a_pointer = a;
        }
        else if (a < b)
        {
            a += dt * rate_up;
            if (a > b) a = b;
            *a_pointer = a;
        }
    }

    fn Vec2f move_toward(Vec2f a, Vec2f b, float amount) 
    {
        Vec2f result;
        result.x = Move_Toward_(a.x, b.x, amount);
        result.y = Move_Toward_(a.y, b.y, amount);

        return Vec2f(result);
    }

    fn Vec3f move_toward(Vec3f a, Vec3f b, float amount) 
    {
        Vec3f result;
        result.x = Move_Toward_(a.x, b.x, amount);
        result.y = Move_Toward_(a.y, b.y, amount);
        result.z = Move_Toward_(a.z, b.z, amount);

        return Vec3f(result);
    }

//macro percent(double percent, float value) 
//{
    /*
    local_percent = cMath::Clamp(local_percent, 0.0, 100.0);
    float result = (local_percent / 100.0);
    return (result * value);
    */
    //return ((float)percent / 100.0) * value;
//}
