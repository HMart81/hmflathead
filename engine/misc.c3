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

module game::misc::hm;

// region C3 modules
import std::io;
import std::core::mem; // for malloc/new std::mem
import std::io::file;
import std::math;
import std::collections;
//import std::core::string;
import libc;
// end

// region custom modules
import game::main;
import game::actors::ent::pl;
import raylib5::rl;
// end

def Vec2i  = int[<2>];
def Vec3i  = int[<3>];

// NOTE(HM) There's not Z or back and forward, because this is 2D engine
// in camera space!!!!!!!!!
const Vec2f VEC_UP    = { 0.0f,-1.0f};
const Vec2f VEC_DOWN  = { 0.0f, 1.0f};
const Vec2f VEC_LEFT  = {-1.0f, 0.0f};
const Vec2f VEC_RIGHT = { 1.0f, 0.0f};
//

const Color INVISIBLE_COLOR = {0xFF, 0xFF, 0xFF, 0x00};

fn Vector2 Vec2f.toVector2(&self) => Vector2{self.x, self.y};

def @Hardcode = {}; // empty user attribute (Need to start with a uppercase...)
def @Performance = {};

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


macro void @drawRect(#rect, color) => rl::drawRectangleRec(#rect, color);


// region Debug Lines
def ArrayOfLinesPtr = List(<DebugLine*>) @local;
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

<*
* @param [in] line "pointer to a DebugLine"
* @ensure line != null
*>
fn bool debugLineIsValid(DebugLine* line) {
    return (line.lifetime >= 1000) ? true : false;
}
// end_region Debug Lines

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

// region raylib Rectangle extensions
macro Vec2f getRecSize(rec) => {rec.width, rec.height};
macro Vec2f getRecPos(rec) => {rec.x, rec.y}; // world pos
macro Vec2f getRecScreenPos(rec) => worldToScreen(getRecPos(rec));

// NOTE(HM) This may return the exact same coords as put in if
// the camera is never moved around, as world coords and camera coords
// are very similar only the center/origin changes.
// UNTESTED!!!!!!!!!!!!!!!!!!!!!
fn Vec2f Rectangle.getPosCameraCoords(&self) {
    Vec2f world_origin   = {0, 0};
    Vec2f cam_org        = main::gpGame.view.camera.target.toVec2f();
    Vec2f offset_vec_dir = cam_org - world_origin;
    float offset_len     = offset_vec_dir.length();
    
    return self.getPos().toVec2f() * offset_vec_dir.normalize() * offset_len; 
}
// end_region raylib Rectangle extensions

// region Texture stuff
// NOTE(HM) Raylib doesn't support .tga's with RLE compression...
fn rl::Texture2D loadTexture(String image_path) @inline {
    if(rl::isWindowReady()) {
        Texture2D tex = rl::loadTexture(stringTotempzstring(image_path));
        assert(rl::isTextureValid(tex));
        return tex;
    }
    
    main::gameWarning("Unable to load » %s", image_path);
    return main::gpGame.default_texture;
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
    
    main::filelgr.log(TraceLogLevel.WARNING, "Unable to load » %s", asset_path);
    return main::gpGame.default_sound;
}
// end_region

macro sec_since_init()  => main::gpGame.time_sec;
macro mili_since_init() => main::gpGame.time_ms;

macro bool recIsValid(rec) => ((getRecSize(rec).length() + getRecPos(rec).length()) > 0) ? true : false;

macro Rectangle @recFromVecs(#vec1, #vec2) => Rectangle {#vec1.x, #vec1.y, #vec2.x, #vec2.y};

// region String custom extension
macro ZString stringTozstring(x) => x.zstr_copy();
macro ZString stringTotempzstring(x) => x.zstr_tcopy();
macro String zstringTostring(x) => x.zstr_view();
macro String zstringTotempstring(x) => string::tformat(x);
macro String numbToStr(n) => string::new_format("%s", n);

// NOTE(HM) helper-function that returns true if the character c is a directory separator
//     on the current platform
macro bool isDirSeparator( c ) {
    if ( c == '/' ) {
        return true;
    }
    
    $switch
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
    return result.zstr_copy();
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
        main::filelgr.log(TraceLogLevel.WARNING, "Cannot strip extension is unkown: %s.", needle);
        return self; // do nothing
    }
}

macro String[] cut_by_newline(str) {
    $switch
        $case env::POSIX:
            return str.split("\r\n");
        $case env::WIN32:
            return str.split("\n");
    $endswitch
}

macro String[] cut_by_spaces(str) {
	return str.split(" ");
}

macro void String.remove_spaces(&self) {
    // trim any white space at start and end leave only the middle if any
    self = self.trim();
    //
    // now see if he still have spaces else do nothing
    if(self.has_spaces()) {
        char[] buffer;
        usz count;
        $foreach ($i, $ch : self)
            $if $ch != ' ':
                buffer[$i] = $ch;
            $endif
        $endforeach
        
        buffer[count] = '\0';
        self.copy((String)buffer);
    }
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
    (*self) = string::new_format("%s", copy[start..]);
}

// fn String getAssetNameFrom(String path) @inline {
    // return path.extractFileBaseByCopy();
// }

struct EntireFile @local {
    usz contents_size;
    void* contents;
}

// »Performance?
fn String! readEntireFileX(String filepath) {
    EntireFile _file;
    
    File data = file::open(filepath, "rb")!;
    defer (void)data.close();
    
    if(data.file != null) {
        _file.contents_size = data.seek(0, Seek.END)!;
        data.seek(0, SET)!; // return to the start
        _file.contents = mem::calloc(char.sizeof * (_file.contents_size + char.sizeof));
        char[]* buffer = &&((char*)_file.contents)[:_file.contents_size + 1];
        data.read(*buffer)!;
        //(*buffer)[_file.contents_size] = 0;
        return (String)(*buffer);
        
        // String result = (String)mem::temp_new_array(char, _file.contents_size);
        // for(usz i; i < _file.contents_size; i++) {
            // result[i] = *((char*)_file.contents + i);
        // }
        // return result;
        //return string::new_format("%s", (String)_file.contents[:_file.contents_size]);
    } else{
        main::filelgr.log(TraceLogLevel.ERROR, "Cannot open file: %s", filepath);
    }
    
    return (String)"";
}

fn String! readEntireFile(String filepath) @inline {
    return (String)file::load_new(filepath)!;
}

fn int String.count_spaces(&self) @inline {
    int count = 0;

    foreach(ch : self) {
        if (ch == ' ') count++;
    }

    return count;
}

fn bool String.has_spaces(&self) {
    if(self.count_spaces() > 0) return true;
    
    // else
    return false;
}
// end_region String custom extensions

// region raw strings/ZString utils
fn int ZString.count_spaces(&self) @inline {
    return self.str_view().count_spaces();
}
// end_region raw strings utils
    

// for easy cast search 
// macro cast($Type, exprs) @deprecated
// {
    // return ($Type)exprs;
// }

// region PROFILING /////////////////////////////////////////////////
// todo make this into a internal module?

<*
 * @require rl::isWindowReady() == true "right now window most be initialized for Profiling to work"
 * @return `start time of function`
*>
macro float @start_profile_zone() @builtin {
$if $feature(PROFILE):
    var ms = (float)rl::getTime() * 1000.0f;
    return ms;
$else
    return 0.0f;
$endif
}

<*
 * @require rl::isWindowReady() == true "right now window most be initialized for Profiling to work"
 * @param [in] start_time `The function start time`
*>
macro @end_profile_zone(#start_time) @builtin {
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
}

// end_region PROFILING //////////////////////////////////////////////////////////////////////////////////////////////////////////////


// region MISC
fn Vec2f dir_mul(pl::Move_Dir d, float a) @inline {
    return Vec2f { d.vec.x * a, d.vec.y * a };
}

fn void axis_scale(Matrix2f* mat, Vec2f vec) @inline {
    if(mat) {
        mat.m00 *= vec.x;
        mat.m11 *= vec.y;
    }
}


fn void draw_arrow(Vec2f start, Vec2f end, Color color, Vec2f arrow_size = {16.0f, 8.0f})
{
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
}

macro mat2_identity() => matrix::IDENTITY2(<float>);

macro int fmin_to_sec(int minutes) 
{
    if (minutes <= 1) return 60; // returns 60 seconds

    return ((int)((float)minutes / 60.0f) * 60);
}

<*
 * @require type <= uint.max "ulong most be within uint size"
*>
fn uint safeTruncateU64(ulong type) @inline => (uint)type;
<*
 * @require type <= int.max "long most be within int size"
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

 @param #value `the value to convert to the given type.`
 @param $Type `the type to convert to`
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
    if(range != 0.0f){
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
    $for(rev_num; num > 0; num = num / 10)
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

    fn int has_spaces( char* src) {
        while (*src != '\0') {
            if (isspace(*src)) return TRUE;
            src++;
        }

        return FALSE;
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

macro percent(double percent, float value) 
{
    /*
    local_percent = cMath::Clamp(local_percent, 0.0, 100.0);
    float result = (local_percent / 100.0);
    return (result * value);
    */
    //return ((float)percent / 100.0) * value;
//}
