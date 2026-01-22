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

// NOTE(HM) This is the main game module, is where the game initializes almost all its systems and where the entry point is
module game::main @private;

// #region imports
import libc;
import std::io, std::thread, std::os;
import std::time;
import std::math;
import std::ascii;
import std::math::complex;
import std::core::mem; // for malloc/new
import std::collections::list, std::collections::map, std::collections::pair;
import engine::input;
import engine::tokanizer::tok; // tokanizer
import engine::filesystem::fs;
import engine::gui, engine::gui::desktop::desk;
import game::gui::menu;
import game::intro;
import engine::assets_api::asset; // for the asset system
import engine::assets_api::astmng; // asset manager
import engine::sys::reader::svg;
import game::material::manager::mtrmng; // material database
import engine::sys::framework::language::lang;
import engine::sys::framework::backends::bkend; // graphics backend interface
import engine::sys::framework::platform::platf; // platform specific stuff
//
import thirdparty::wren;
import engine::sys::script_engine::scpt; // Script Engine (based on Wren language)
import engine::sys::framework::glsl;
import thirdparty::angel; // AngelScript engine
//
import game::assets::sprite;
//import game::assets::part; // particles
import game::serialize::svs; // save system
import game::logic::timer;
import engine::tools::editor;
import engine::logging::log;
import game::actors::ent::plyr;  // player module
import engine::misc; // misc code
import game::camview;
import engine::sys::cvar;
// config file types
import game::files::ini @public;
import std::collections::object;
import std::encoding::json;
//
import game::effects::boid;
import game::lowlevel::bounds;
// third party libraries
import thirdparty::raylib5::rl, thirdparty::raylib5::rl::rlgl;
import thirdparty::raygui5::rgui, thirdparty::raygui5::rgui::style::dark;
import thirdparty::library::xml;
import thirdparty::microui::mu;  // micro ui
import engine::physics::box2d;
import thirdparty::tracy;
import thirdparty::tsoding::flg; // simple flag library
import thirdparty::mujs; // micro java script
import thirdparty::scripting::lua; // lua script
import thirdparty::scripting::umka; // umka script
import engine::sys::videoplay::vid; // video playing
// #endregion

// #region Constants
const TRACY_ENABLE_ZONE @if($feature(TRACY_ENABLE)) = 1;
const SCRIPT_ENGINE = true; // use the new script engine
/*
   ===== Game Scale Units =====
   
   1 unit = 1 meter = 100 pixels
   
   NOTE(HM): 
   Minimum scale for physics objects is 10 units (10 cm), this is a hard limit 
   imposed by box2d physics engine.
*/
const UNITS_METER @public = 1;
const UNITS_PIXEL @public = 2;
const CURRENT_UNITS @public = UNITS_METER; // default units are meters

const DEFAULT_UNITS_PER_METER @public @Hardcode = 1.0f;
const DEFAULT_PIXELS_PER_METER @public @Hardcode = 100.0f; // 100 pixels per meter
const DEFAULT_UNITS_PER_PIXEL @public @Hardcode = DEFAULT_UNITS_PER_METER / DEFAULT_PIXELS_PER_METER; // 0.01 units per pixel


const String MOUSE_IMAGE_NAME @Hardcode = "pointer.png";
const String MOUSE_POINTER_MAT_NAME @Hardcode = "gui/pointer"; // game assets folder
const GAME_CURSOR_SCALER               @Hardcode = 0.025f;
const int MAX_ENTITY_COUNT     @public @Hardcode = 1 << 12; //int.max;

const MIN_DISPLAY_HZ_FACTOR @Hardcode = 0.13f; // if the display hz is bellow this factor of the monitor hz, we set it to the minimum
const MIN_DISPLAY_HZ  @Hardcode = 15;   // minimum display hz
const MAX_DISPLAY_HZ  @Hardcode = 500;  // maximum display hz


/**************** DOC ********************************************
    - You can also do resolutions values like this:
        int w = 16*120;
        int w = 9*120;
        16 and 9 are the image ratio and 120 is the scaling factor
        in this case this will produce 1920x1080 res.
    - You can also do it like this:
        float ratio = 160.0f / 900.0f;
        int vertPixels = 1080;
        int w = (int)(vertPixels*ratio)
        int h = vertPixels;
******************************************************************/
struct ScreenRes
{
    String str;
    int w;
    int h;
}

const ScreenRes[*] SCREEN_RES = {
    {"Mode  0: 320x240"  , 320,  240  },
    {"Mode  1: 400x300"  , 400,  300  },
    {"Mode  2: 512x384"  , 512,  384  },
    {"Mode  3: 640x480"  , 640,  480  },
    {"Mode  4: 800x600"  , 800,  600  },
    {"Mode  5: 1024x768" , 1024, 768  },
    {"Mode  6: 1152x864" , 1152, 864  },
    {"Mode  7: 1280x1024", 1280, 1024 },
    {"Mode  8: 1600x1200", 1600, 1200 },
    {"Mode  9: 1280x720" , 1280, 720  }, // HD
    {"Mode 10: 1366x768" , 1366, 768  },
    {"Mode 11: 1440x900" , 1440, 900  },
    {"Mode 12: 1400x1050", 1400, 1050 },
    {"Mode 13: 1600x900" , 1600, 900  },
    {"Mode 14: 1680x1050", 1680, 1050 },
    {"Mode 15: 1920x1080", 1920, 1080 }, // Full HD
    {"Mode 16: 1920x1200", 1920, 1200 },
    {"Mode 17: 2048x1152", 2048, 1152 },
    {"Mode 18: 2560x1600", 2560, 1600 },
    {"Mode 19: 3200x2400", 3200, 2400 },
    {"Mode 20: 3840x2160", 3840, 2160 },
    {"Mode 21: 4096x2304", 4096, 2304 },
    {"Mode 22: 2880x1800", 2880, 1800 },
    {"Mode 23: 2560x1440", 2560, 1440 }, // Ultra HD
    {"Mode 24: 1680x720" , 1680, 720  }, // to be able to test ultra wide in 1080p 16:9 screens
    {"Mode 25: 2560x1080", 2560, 1080 },
    {"Mode 26: 3072x1728", 3072, 1728 },
    {"Mode 27: 3200x1800", 3200, 1800 },
    {"Mode 28: 3440x1440", 3440, 1440 },
    {"Mode 29: 3840x1600", 3840, 1600 }, // 4K
    {"Mode 30: 5120x2880", 5120, 2880 },
    {"Mode 31: 5760x3240", 5760, 3240 },
    {"Mode 32: 7680x4320", 7680, 4320 }, // 8K
};

const usz DEFAULT_SCREEN_INDEX     = 9;
const ScreenRes DEFAULT_SCREEN_REZ = SCREEN_RES[DEFAULT_SCREEN_INDEX];

fn bool resValuesSafe(int w_value, int h_value) @inline @nodiscard 
{
    if(w_value < SCREEN_RES[0].w || w_value > SCREEN_RES[SCREEN_RES.len - 1].w) return false;
    if(h_value < SCREEN_RES[0].h || h_value > SCREEN_RES[SCREEN_RES.len - 1].h) return false;
    
    return true;
}

fn int getResolutionIndexFromValues(int w, int h) @local @inline @nodiscard
{
    if(resValuesSafe(w, h))
    {
        foreach(i, &res: SCREEN_RES) {
            if(res.w == w && res.h == h) return (int)i;
        }
    }

    // if we reach here, the resolution is not found
    return -1;
}


<*
    @param #index : "the index of a resolution on the resolution array"
    @require #index >= 0 && #index < ScreenRes.len
    @ensure return != null
*>
macro ScreenRes* @getResolutionFromIndex(#index) => &ScreenRes[#index];


// multithreading 
// *unused*
const int NUM_THREADS = 3;
//Mutex  assetsLoadingMutex;
//Thread assetsLoadingThread;
//
Mutex  introMutex;
Thread introThread;
//

// TODO make font sizes dependent on the screen size?
const int SMALL_FONT_SIZE   @Hardcode @public = 6;
const int DEFAULT_FONT_SIZE @Hardcode @public = 10;
const int BIG_FONT_SIZE     @Hardcode @public = 14;

const PHYS_DEFAULT_SUBSTEPS        = 4;
const PHYS_DEFAULT_TIMESTEP        = 1.0f / 60.0f; // 60fps @Hardcode
// world/game gravity info (still not used for anything...)
const B2Vec2 GRAVITY_VEC           = {0.0f, -10.0f};
const float GRAVITY_VALUE          = 9.80665f; // meters/sec2
const Vec2f DEFAULT_WORLD_CENTER   = {0, 0}; // top left coorner of screen (this is contrary to OpenGL that is lower left corner)
//

// Game Info
import engine::sys::licensee;
alias lic = module engine::sys::licensee;
//

// #endregion Constants

// #region Alias
// DOC(HM) Alias definitions, always follow the same naming rules of the thing they are alising.
// If alising a type the alias name, should start uppercase, if alising a function, it should start lowercase, 
// if alising a Constant the alias also needs to be all caps, etc.

alias RShader        @public = rl::RLShader;
alias StringPair     @public = Pair{String, String};
alias IniFileCMDList = List{StringPair*};
alias asstManager    @public= astmng::assetManager;

// #endregion Alias

// #region Cvars
Cvar developer      @public = { "developer"     , CvarType.BOOL, "0",    "enables developer mode"};
Cvar editor         @public = { "editor"        , CvarType.BOOL, "0",    "enables the game editor (requires developer mode)"};
Cvar r_mode         @public = { "r_mode"        , CvarType.INT,     "-1",   "index of window resolution [0 to 32], -1 = ini file setting"};
Cvar r_showFPS      @public = { "r_showFPS"     , CvarType.BOOL, "1",    "draws framerate on screen"};
Cvar r_noSplashPic  @public = { "r_noSplashPic" , CvarType.BOOL, "1",    "disables the splash image at game start"};
Cvar r_fullscreen   @public = { "r_fullscreen"  , CvarType.INT,     "-1",   "screen mode 0 = window, 1 = borderless, 2 = dedicated, -1 = ini file setting"};
Cvar r_fps_unlocked @public = { "r_unlockFps"   , CvarType.BOOL, "false", "sets if the fps is unlocked (true) or locked to the monitor refresh rate (false)"};
Cvar r_max_fps      @public = { "r_max_fps"     , CvarType.INT,     "-1",   "sets the maximum fps when fps is unlocked, -1 = monitor refresh rate"};
Cvar fs_base        @public = { "fs_base"       , CvarType.STRING,  "data", "default game base folder"};
Cvar fs_mod_name    @public = { "fs_mod_name"   , CvarType.STRING,  "",     "folder name of mod to run"};
Cvar fs_mod_base    @public = { "fs_mod_base"   , CvarType.STRING,  "",     "folder name for custom database of running mod"};
Cvar db_drawPhysics @public = { "db_drawPhysics", CvarType.BOOL, "1",    "show debug visualization for world physics" };
Cvar s_noaudio      @public = { "s_noaudio"     , CvarType.BOOL, "0",    "disables all audio"};
Cvar fl_help        @public = { "help"          , CvarType.BOOL, "0",    "shows help message"};
Cvar dbg_stats      @public = { "dbg_stats"     , CvarType.BOOL, "0",    "shows various debug things on screen"};
// TODO(HM) disable editor cvar, when not used anymore
//Cvar r_window_resizable @public = { "r_window_resizable", CvarType.BOOL,  "0",   "makes window resizable, window mode only."};

fn void register_cvars() @local 
{
    cvar::@register(&developer);
    cvar::@register(&editor);
    cvar::@register(&r_mode);
    cvar::@register(&r_showFPS);
    cvar::@register(&r_noSplashPic);
    cvar::@register(&r_fullscreen);
    cvar::@register(&r_fps_unlocked);
    cvar::@register(&r_max_fps);
    cvar::@register(&fs_base);
    cvar::@register(&fs_mod_name);
    cvar::@register(&fs_mod_base);
    cvar::@register(&db_drawPhysics);
    cvar::@register(&s_noaudio);
    cvar::@register(&fl_help);
    cvar::@register(&dbg_stats);
    
    //if(cvar::cvars.len()) foreach(cv: cvar::cvars) {log::info(Where.CONSOLE, cv.name);}
}

fn void register_modulo_cvars() @local {
    register_cvars(); // main
    gui::register_cvars();
    intro::register_cvars();
    log::register_cvars();
    ent::register_cvars();
    bounds::register_cvars();
    editor::register_cvars();
}

// #endregion Cvars

faultdef WINDOW_INIT_FAILED, 
         MISSING_REQUIRED_ASSET,
         INVALID_SCREEN_RESOLUTION,
         GAME_START_FAILED,
         INVALID_WORK_DIR,
         NO_USER_SAVE_FOLDER,
         NO_DATA_FOLDER;

enum GameMode @public 
{
    NONE,
    STARTING,
    INTRO,
    MENU,
    PLAYING,
    EDITOR
}

// ********************
// #region game manager
// ********************

const usz GAME_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator gameArena @public;

struct Game (SaveSystemInterface/*, IGame*/) @local 
{
    bool should_update_entities;
    bool system_cursor_enabled;
    bool should_quit;
    bool msgbox_showing;
    bool is_modded_game; // is the game running a mod?
    
    ConfigFile settings_file; // game settings file, used to get or save the game settings
    
    IntroAnimation intro;
    
    LANGData langdict;

    // menus
    Desktop* guiActive; // to handle all guis
    Desktop* main_menu;
    //

    // video player
    VideoPlayer* vidplayer;

    // microui
    mu::MU_Context* mu_ctx @if($feature(MICROUI_ENABLE)); // microui context, used for the micro ui system
    bool show_microui_test_frames @if($feature(MICROUI_ENABLE));
    bool show_statistics @if($feature(MICROUI_ENABLE)); // show statistics window
    RLTexture2D mu_font_atlas @if($feature(MICROUI_ENABLE)); // microui font texture

    // script engine
    ScriptEngine script_eng;
    //
    // mujs script engine
    State* mujs_state @if($feature(MUJS_ENABLE)); // mujs context
    //
    // LUA script engine
    LUAState* lua_state @if($feature(LUA_ENABLE)); // lua context
    LUADebug* lua_debug @if($feature(LUA_ENABLE)); // lua debug context
    //

    GameMode mode;

    // ingame editor
    Editor editor;
    
    // defaults
    // required default assets
    RLTexture2D default_texture;
    RLTexture2D tex_white;
    RLTexture2D tex_black;
    RLTexture2D tex_gray;
    
    RLShader    default_shader;
    RLShader*   current_global_shader;
    RLSound     default_sound;
    RLMusic     default_music;
    int      pause_all_music; // to pause all music on demand
    RLFont      default_font;
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    RLFont* candara_font;
    RLFont* candara_light_font;
    RLFont* lucida_font;
    RLFont* trojan_pro_font;
    //
    
    String[] cursors; // list of game cursors, used to load the game cursors from the assets folder
    HMSprite mouse_cursor;
    
    Player* main_player;
    PersistentInfo playerPersistentInfo; // to save any info that the player carries along for each level
    RenderView view;

    BackendRender render; // graphics backend interface
    struct screen 
    {
        int index; // monitor index
        int id; // monitor id (index + 1)
        int  w;
        int  h;
        float width_in_meters;
        float height_in_meters;
        Vec2f center;

        struct state {
            bool window;
            bool fullscreen;
            bool borderless;
        }

        bool vsync_hint;
        int  displayHz;
        int  multiSamples; // MSAA
    }

    List{Entity*} entityList; // list of all entities in the game, used to iterate all entities every frame
    List{Entity*} thinkingEntities; // entities that are thinking this frame, used to avoid iterating all entities every frame
    List{Entity*} activeEntities; // entities that are active this frame, used to avoid iterating all entities every frame
    List{Entity*} entitiesToDeactivate; // entities that are marked for deactivation this frame, used to avoid iterating all entities every frame
    List{Entity*} entitiesToRemove; // entities that are marked for removal this frame, used to avoid iterating all entities every frame
    List{HMSprite*} sprites;

    // BoidManager
    BoidManager boidManager1 @if($defined(BOIDS_ENABLE));
    
    MaterialDataBase mtrDB;
    
    // physics engine world
    B2WorldId physWorldId;
    bool pause_phys_simulation;
    float phys_time_step;
    int phys_substep_count; // simulation quality;
    B2DebugDraw phys_debug;
    
    B2BodyId    phys_grd_bodyid;
    B2Polygon   phys_grd_box;
    //
    
    String app_name;
    
    String app_default_workdir; // usefull if a mod is set
    String app_default_base_folder; // usefull if a mod is set
    
    String app_work_dir;
    String app_base_folder;
    
    String app_save_folder;

    // save game message
    bool showSaveMessage;
    int  saveMessageTime; // time (in ms) to show the save message
    
    // raygui message box stuff
    MessageBox warningBox;
    MessageBox errorBox;
    MessageBox infoBox;

    bool showMessageBox;
    String titleMsgBox;
    String msgBoxText;
    //
    float time_sec;
    int   time_ms;
    float dt;
    bool fps_unlocked;
    int max_fps;
    int last_key_pressed;
    
    timer::Timer testTimer;
    //ParticleSpawner particleSpawner1;
}

/*************** global game singleton ***************/
Game local_game @local; 
Game* gpGame @public = &local_game;
/*****************************************************/

// ***********************
// #endregion game manager
// ***********************

fn void Game.freeGameEntities(&self) @inline {
    if(int count = (int)self.entityList.len()) {
        foreach(&it: self.entityList) if(it) (*it).kill();
        self.entityList.free();
        log::info(FILE, "['%s'] Entities were cleared!", count);
        //log::info(FILE,  "Done.");
    }
}

fn void Game.save(&self, SaveFile* file) @dynamic {
    svs::writeBool(file, self.should_update_entities);
    svs::writeBool(file, self.system_cursor_enabled);
    svs::writeBool(file, self.should_quit);
    svs::writeBool(file, self.msgbox_showing);
    svs::writeBool(file, self.is_modded_game);
    svs::writeInt(file, self.mode.ordinal);
    svs::writeTexture2D(file, &self.default_texture);
    svs::writeShader(file, &self.default_shader);
    // should I save pointers!?
    //RLShader*   current_global_shader;
    svs::writeSound(file, &self.default_sound);
    svs::writeMusic(file, &self.default_music);
    svs::writeFont(file,  &self.default_font);
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    //RLFont*  candara_font;
    //RLFont*  candara_light_font;
    //RLFont*  lucida_font;
    //RLFont*  trojan_pro_font;
    //
    
    svs::write(file, &self.cursors, self.cursors.len);
    self.mouse_cursor.save(file);
    
    //Player* main_player;
    self.playerPersistentInfo.save(file); // to save any info that the player carries along for each level
    self.view.save(file);
    
    svs::write(file, &self.screen, $sizeof(self.screen));
    svs::write(file, &self.entityList, $sizeof(self.entityList));
    svs::write(file, &self.sprites, $sizeof(self.sprites));

    $if $defined(BOIDS_ENABLE):
    self.boidManager1.save(file);
    $endif

    svs::writeString(file, self.app_name);
    svs::writeString(file, self.app_default_workdir); // usefull if a mod is set
    svs::writeString(file, self.app_default_base_folder); // usefull if a mod is set
    svs::writeString(file, self.app_work_dir);
    svs::writeString(file, self.app_base_folder);
    svs::writeString(file, self.app_save_folder);
    svs::writeFloat(file,  self.time_sec);
    svs::writeInt(file,    self.time_ms);
    svs::writeFloat(file,  self.dt);
    svs::writeBool(file,   self.showMessageBox);
    svs::writeInt(file,    self.last_key_pressed);
    //self.testTimer.save(file);
}

fn void Game.reload(&self, SaveFile* file) @dynamic {
    svs::readBool(file, &self.should_update_entities);
    svs::readBool(file, &self.system_cursor_enabled);
    svs::readBool(file, &self.should_quit);
    svs::readBool(file, &self.msgbox_showing);
    svs::readBool(file, &self.is_modded_game);
    svs::readInt(file, &self.mode.ordinal);
    svs::readTexture2D(file, &self.default_texture);
    /*
    svs::readShader(file, &self.default_shader);
    // how to read pointers!?
    //RLShader*   current_global_shader;
    svs::readSound(file, &self.default_sound);
    svs::readMusic(file, &self.default_music);
    svs::readFont(file,  &self.default_font);
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    //RLFont*  candara_font;
    //RLFont*  candara_light_font;
    //RLFont*  lucida_font;
    //RLFont*  trojan_pro_font;
    //
    
    svs::readSlice(file, &self.cursors);
    self.mouse_cursor.reload(file);
    
    //Player* main_player;
    self.playerPersistentInfo.reload(file); // to save any info that the player carries along for each level
    self.view.reload(file);
    
    svs::read(file, &self.screen, @sizeof(self.screen));
    svs::readList(file, &self.entityList);
    svs::readList(file, &self.sprites);
    self.boidManager1.reload(file);
    
    svs::readString(file, &self.app_name);
    svs::readString(file, &self.app_default_workdir); // usefull if a mod is set
    svs::readString(file, &self.app_default_base_folder); // usefull if a mod is set
    svs::readString(file, &self.app_work_dir);
    svs::readString(file, &self.app_base_folder);
    svs::readString(file, &self.app_save_folder);
    svs::readFloat(file,  &self.time_sec);
    svs::readInt(file,    &self.time_ms);
    svs::readFloat(file,  &self.dt);
    svs::readBool(file,   &self.showMessageBox);
    svs::readInt(file,    &self.last_key_pressed);
    self.testTimer.reload(file);
    */
}

<*
 @require(self.entityList.len() >= 1)
*>
fn Player* Game.getLocalPlayer(&self) @public @inline {
    return (Player*)self.entityList[0];
}

fn RLShader getDefaultShaderCopy() @inline @public {
    return local_game.default_shader;
}

fn RLShader* getDefaultShader() @inline @public {
    return &local_game.default_shader;
}

fn RLShader* getCurrentGlobalShader() @inline @public {
    return local_game.current_global_shader;
}

fn Vec2f Game.getScreenCenterPos(&self) {
    return (Vec2f) { (float)rl::getScreenWidth() / 2, (float)rl::getScreenHeight() / 2 };
}

fn Vec2i Game.getScreenCenterPosI(&self) {
    return (Vec2i) { rl::getScreenWidth() / 2, rl::getScreenHeight() / 2 };
}

<*
 @require(self.entityList.len() >= 2)
*>
fn Entity* Game.getEntityByName(&self, String name) {
    foreach(i, ent : self.entityList) {
        if(ent.name == name) return self.entityList[i];
    }
    
    return null;
}

fn bool Game.isPointInsideScreenView(&self, RLVector2 point) {
    int w, h;
    w = self.screen.w;
    h = self.screen.h;
    
    RLRectangle rec = {
    .x = 0,
    .y = 0,
    .width  = w,
    .height = h
    };
    
    return rl::checkCollisionPointRec(point, rec);
}


//////////// Message box stuff based on raygui

alias MessageBoxList = List{MessageBox*};
MessageBoxList messageBoxs;
List{usz} messageBoxsIndecesToRemove;

const DEFAULT_MESSAGE_BOX_TEXT_SIZE = 10;
const DEFAULT_MESSAGE_BOX_H = 100;
const DEFAULT_MESSAGE_BOX_W = 250;
const DEFAULT_MESSAGE_BOX_MARGIN = 20;

enum MessageBoxType : const inline int
{
    NONE,
    INFO,
    WARN,
    ERROR
}

struct MessageBox 
{
    int type;
    String message;
    float text_len;
    RLRectangle box;
    bool initted;
    bool isVisible;
    bool show;
    bool setupDone;
    bool shouldRemove;
}

fn void MessageBox.init(&self, int type) {
    if(self.initted) return;
    self.type = type;
    int w = local_game.screen.w / 2;
    w -= (int)DEFAULT_MESSAGE_BOX_W / 2;
    int h = local_game.screen.h / 2;
    h -= (int)DEFAULT_MESSAGE_BOX_H / 2;
    self.box.height = h;
    self.box.width  = w;
    self.initted = true;
    self.register();
}

fn void MessageBox.updateSize(&self) @inline {
    if(self.text_len > self.box.width) self.box.width = self.text_len + DEFAULT_MESSAGE_BOX_MARGIN;
}

fn void MessageBox.setMessage(&self, String msg) {
    self.message  = msg;
    self.text_len = rl::measureText(self.message.zstr_tcopy(), DEFAULT_MESSAGE_BOX_TEXT_SIZE);
    self.updateSize();
}

fn void MessageBox.register(&self) @local => messageBoxs.push(self);

fn void MessageBox.delete(&self) {
    if(self.isVisible) self.isVisible = false;
    messageBoxs.remove_item(self);
}

fn void MessageBox.open(&self) => self.show = true;
fn void MessageBox.close(&self, bool kill = false) {
    self.show = false;
    if(kill) self.shouldRemove = true;
}

fn void MessageBox.draw(&self) 
{
    if (self.show)
    {
        self.isVisible = true;
        float x, y;
        x = self.box.width;
        y = self.box.height;
        ZString msg_title;
        switch(self.type)
        {
            case MessageBoxType.WARN:
                msg_title = string::tformat_zstr("%s%s","#220#", "Warn");
            case MessageBoxType.ERROR:
                msg_title = string::tformat_zstr("%s%s","#152#", "Error");
            case MessageBoxType.INFO:
            default:
                msg_title = string::tformat_zstr("%s%s","#191#", "Info");
        }
        int result = rgui::messageBox((RLRectangle) {x, y, self.box.width, self.box.height},
            title: msg_title, 
            message: local_game.msgBoxText.zstr_tcopy(), 
            buttons: "close");
            if(result >= 0) self.show = false;
    } else {
        self.isVisible = false;
    }
}

fn void drawMsgBox(int w, int h) @public 
{
    if (local_game.showMessageBox)
    {
        float box_h = 100;
        float box_width = 250;
        float text_len = rl::measureText(local_game.msgBoxText.zstr_tcopy(), 10);
        if(text_len > 250) box_width = (float)text_len + 20.0f;
        w /= 2;
        w -= (int)box_width / 2;
        h /= 2;
        h -= (int)box_h / 2;
        int result = rgui::messageBox((RLRectangle) {w, h, box_width, box_h},
            string::tformat_zstr("%s%s","#191#", local_game.titleMsgBox), local_game.msgBoxText.zstr_tcopy(), "close");

        if (result >= 0) local_game.showMessageBox = false;
    }
}

///////////////////////////////////////////////////


/*
fn void Game.updateScreenSize(&self, int rez_index) @inline @deprecated {
    self.screen.w = SCREEN_RES[rez_index].w;
    self.screen.h = SCREEN_RES[rez_index].h;
    rl::setWindowSize(self.screen.w,  self.screen.h);
}
*/

fn void Game.initFonts(&self) @inline {
    self.candara_font       = asstManager.getFont("candara.fnt");
    self.candara_light_font = asstManager.getFont("candara_light.fnt");
    self.lucida_font        = asstManager.getFont("lucida.fnt");
    self.trojan_pro_font    = asstManager.getFont("trojan_pro.fnt");
}

fn void Game.clearFonts(&self) @inline {
    // we dont unload the fonts here, because they are unloaded by the asset manager
    //rl::unloadFont(self.candara_font);
    self.candara_font       = null;
    self.candara_light_font = null;
    self.lucida_font        = null;
    self.trojan_pro_font    = null;
}


fn void? Game.loadDefaultAssets(&self) 
{
    // get required default game texture
    self.default_texture = rl::loadTexture(self.app_base_folder.tconcat("images//default.png").zstr_tcopy());
    if(self.default_texture.isInvalid()) {
        log::fatal(FILE, "Required asset: images//default.png failed to load!");
        return MISSING_REQUIRED_ASSET?;
    }
    
    RLImage white = rl::genImageColor(32, 32, rl::WHITE);
    self.tex_white = rl::loadTextureFromImage(white);
    rl::unloadImage(white);
    
    RLImage black = rl::genImageColor(32, 32, rl::BLACK);
    self.tex_black = rl::loadTextureFromImage(black);
    rl::unloadImage(black);
    
    RLImage gray = rl::genImageColor(32, 32, rl::GRAY);
    self.tex_gray = rl::loadTextureFromImage(gray);
    rl::unloadImage(gray);
    
    // get required default game shader
    /*self.default_shader = rl::loadShader(
        self.app_base_folder.tconcat("shaders//default.vs").zstr_tcopy(),
        self.app_base_folder.tconcat("shaders//default.fs").zstr_tcopy()
    );*/
    self.default_shader = glsl::loadShader(
        self.app_base_folder.tconcat("shaders//default.vs"),
        self.app_base_folder.tconcat("shaders//default.fs")
    );
    if(rl::isShaderValid(self.default_shader) == false) {
        log::fatal(FILE, "Required default shader not found in folder %s!", self.app_base_folder.tconcat("//shaders"));
        return MISSING_REQUIRED_ASSET?;
    }
    
    /*int test_tex_loc = rl::getShaderLocation(self.default_shader, "texture0");
    rl::setShaderValue(
        local_game.default_shader, 
        test_tex_loc, 
        &local_game.default_texture,
        RLShdUniTyp.SAMPLER2D);*/
    self.current_global_shader = &self.default_shader;
    //self.current_global_shader.locs[RLShdLocInd.MAP_ALBEDO] = test_tex_loc;
    //
        
    // load required default sound
    self.default_sound = rl::loadSound(self.app_base_folder.tconcat("sounds//default.wav").zstr_tcopy());
    if(rl::isSoundValid(self.default_sound)) {
        //$if $feature(_DEBUG):
            //if(rl::isAudioDeviceReady()) rl::playSound(self.default_sound);
        //$endif
    } else {
        log::fatal(FILE, "Required default asset: \"sounds/default.wav\" failed to load!");
        return MISSING_REQUIRED_ASSET?;
    }
    
    // load required default music
    self.default_music = rl::loadMusicStream(self.app_base_folder.tconcat("music//default.mp3").zstr_tcopy());
    if(rl::isMusicValid(self.default_music) == false) {
        log::fatal(FILE, "Required default asset: \"music/default.mp3\" failed to load!");
        return MISSING_REQUIRED_ASSET?;
    }
    
    // get the default game font
    local_game.default_font = rl::getFontDefault();
}

fn void Game.unloadDefaultAssets(&self) {
    rl::unloadTexture(self.default_texture);
    rl::unloadTexture(self.tex_white);
    rl::unloadTexture(self.tex_black);
    rl::unloadTexture(self.tex_gray);
    rl::unloadShader(self.default_shader);
    self.current_global_shader = null;
    rl::unloadSound(self.default_sound);
    rl::unloadMusicStream(self.default_music);
    rl::unloadFont(self.default_font);
}

fn void? Game.loadSettingsFile(&self)
{
    String settings_path = local_game.app_save_folder.tconcat("settings.ini");
    if(!fs::fileExists(settings_path)) {
        log::warning(FILE, "Settings file not found, creating default settings file at: %s", settings_path);
        File data = ini::create_default_settings_fileEx(settings_path)!!;
        defer data.close()!!;
        if(!local_game.settings_file.loadEx(data, settings_path)) {
            log::fatal(FILE, "Failed to load settings file at: %s", settings_path);
            return ini::FAILED_READ_FILE?;
        }
        // set default settings
        ini::setBool(&local_game.settings_file, "video", "fullscreen", false);
        ini::setInt(&local_game.settings_file, "video", "resolution_width", SCREEN_RES[DEFAULT_SCREEN_INDEX].w);
        ini::setInt(&local_game.settings_file, "video", "resolution_height", SCREEN_RES[DEFAULT_SCREEN_INDEX].h);
        ini::setInt(&local_game.settings_file, "video", "vsync", 1);
        ini::setInt(&local_game.settings_file, "audio", "master_volume", 100);
        ini::setInt(&local_game.settings_file, "audio", "music_volume", 80);
        ini::setInt(&local_game.settings_file, "audio", "sfx_volume", 80);
        // save file
        if(!ini::saveConfigFile(&local_game.settings_file)) {
            log::fatal(FILE, "Failed to save default settings file at: %s", settings_path);
            return ini::FAILED_OPEN_FILE?;
        }
    }
    // load settings file
    bool? settings_load_sucess = local_game.settings_file.load(settings_path, false);
    if(catch excuse = settings_load_sucess) {
        log::warning(FILE, "Failed to load %s file with excuse: %s", settings_path, excuse);
        return excuse?;
    }
}

fn void Game.unload(&self) {
    self.clearFonts();
    // clear material database
    self.mtrDB.clear();
    self.freeGameEntities();
    self.unloadDefaultAssets();

$if $feature(MICROUI_ENABLE):
    if(self.mu_ctx) {
        mem::free(self.mu_ctx);
        self.mu_ctx = null;
    }
$endif
    
    if(self.main_menu) {
        self.main_menu.deinit();
        self.main_menu = null;
    }
    
    if(self.current_global_shader) {
        self.current_global_shader = null;
    }
    
    if(self.main_player) self.main_player = null;
    
    if(usz count = self.sprites.len()) {
        foreach(&it: self.sprites) if(it) (*it).deinit();
        self.sprites.free();
        log::info(FILE, "['%s'] sprites were cleared!", count);
    }
    self.view.deinit();

    $if $defined(BOIDS_ENABLE):
    self.boidManager1.release();
    $endif

    self.editor.deinit();
}

// The type of menu gui set right now
enum ESCReply : char {
	IGNORE,	// do nothing
	MAIN,	// start main menu GUI
	GUI		// set an explicit GUI
}

fn ESCReply Game.handleESC(&self, Desktop** gui ) @dynamic
{
	Player* player = self.getLocalPlayer();
	if ( player ) {
		if ( player.handleESC() ) {
			return ESCReply.IGNORE;
		} else {
			return ESCReply.MAIN;
		}
	}
	return ESCReply.MAIN;
}

// #region System OS Cursor

fn void enable_system_cursor() @inline @public
{
    rl::enableCursor();
    local_game.system_cursor_enabled = true;
}

fn void disable_system_cursor() @inline @public
{
    rl::disableCursor();
    local_game.system_cursor_enabled = false;
}

fn bool system_cursor_enabled() @public @inline 
{
    return local_game.system_cursor_enabled;
}

fn bool system_cursor_disabled() @public @inline 
{
    return !system_cursor_enabled();
}

fn void show_system_cursor() @public {
    if(system_cursor_disabled()) enable_system_cursor();
    if(rl::isCursorHidden()) rl::showCursor();
}

// NOTE(HM) only hides the OS cursor visuals, doesn't disable it,
// it will still move in the background.
fn void hide_system_cursor() @public {
    if(rl::isCursorHidden()) return; 
    //else 
    rl::hideCursor();
}

fn bool system_cursor_visible() @public @inline {
    return !rl::isCursorHidden();
}

// #endregion System OS Cursor

///////////////////////////////////////
// #region Game Custom Cursor functions

fn void init_game_cursor() @inline
{
    local_game.mouse_cursor.initV(
        pos: {0,0}, // position in pixel units
        size: {
            0.45f, // width in game units
            0.45f  // height in game units
        },
        color: rl::WHITE,
        kind: SpriteKind.CURSOR,
        material_name: MOUSE_POINTER_MAT_NAME
    );
}

// is this really needed now that i have a asset manager? 
fn void deinit_game_cursor() @inline {
    hide_game_cursor();
}

fn void set_game_cursor_size(float w, float h) @inline {
    local_game.mouse_cursor.setSize(w, h);
}

fn Vec2f getGameCursorSize() @public @inline => local_game.mouse_cursor.getSize();

fn void update_game_cursor(int screen_w, int screen_h) @public 
{
    if(game_cursor_hidden()) return;
    
    int x = rl::getMouseX(); // in world space pixel coordinates
    int y = rl::getMouseY(); // in world space pixel coordinates
    
    // prevent the cursor from going out the screen bounds
    if (x < 0) x = 0;
    if (x > screen_w) x = screen_w;
    if (y < 0) y = 0;
    if (y > screen_h) y = screen_h;
    //
    
    // update position
    //local_game.mouse_cursor.setPositionV({x, y});
    local_game.mouse_cursor.setPositionV(rl::getWorldToScreen2D({x, y}, local_game.view.camera));
    
    // update size
    // TODO do a better mouse cursor size dependent on screen size!!
    float cursor_h = local_game.mouse_cursor.getSizeY();
    float desired_cursor_size = math::floor((GAME_CURSOR_SCALER * misc::pixelsToMeters(screen_h)));
    if(cursor_h > desired_cursor_size) {
        set_game_cursor_size(desired_cursor_size, desired_cursor_size);
    }
}

fn void show_game_cursor() @public @inline 
{
    if(local_game.mouse_cursor.hidden()) local_game.mouse_cursor.show();
}

fn void draw_game_cursor() @local @inline
{
    if(game_cursor_visible()) 
    {
        hide_system_cursor(); // hide operating system cursor
        foreach(sprite : local_game.sprites) 
        {
            if(sprite.kind == SpriteKind.CURSOR) 
            {
                sprite.draw();
            }
        }
    }
}

// NOTE(HM) only hides the cursor doesn't disable it, will still move regardless of visibility.
fn void hide_game_cursor() @public @inline {
    if(game_cursor_visible()) local_game.mouse_cursor.hide();
}

fn bool game_cursor_visible() @public @inline {
    return !local_game.mouse_cursor.hidden();
}

fn bool game_cursor_hidden() @public @inline {
    return !game_cursor_visible();
}

// #endregion Game Custom Cursor functions

// todo change all direct raylib input handling to use the actions system
fn void gameHandleGeneralControls() @local
{
    input::gpManager.update();
    
    //if(rl::isKeyPressed(rl::KEY_F1) && !local_game.msgbox_showing) {
        //local_game.msgbox_showing = true;
    //}
    
    if (rl::isKeyPressed(rl::KEY_P)) {
        local_game.pause_phys_simulation = !local_game.pause_phys_simulation;
    }

    if(input::Action* toggle_editor = input::getAction("toggle_editor")) {
        if(toggle_editor.fnBecameTriggered() && (local_game.mode != STARTING && local_game.mode != INTRO)) {
            if(editor.getBool()) 
            {
                if(local_game.editor.isOpened()) {
                    local_game.editor.close();
                } else {
                    local_game.editor.open();
                }
            }
        }
    }

    $if $feature(MICROUI_ENABLE):
        if(rl::isKeyPressed(rl::KEY_F2)) {
            local_game.show_microui_test_frames = !local_game.show_microui_test_frames;
        }

        if(rl::isKeyPressed(rl::KEY_F4)) {
            local_game.show_statistics = !local_game.show_statistics;
        }
   $endif
    
    // handle ESC key press
    if (!local_game.guiActive && rl::isKeyPressed(rl::KEY_ESCAPE) &&
        !rl::isKeyDown(rl::KEY_LEFT_SHIFT) && !rl::isKeyDown(rl::KEY_RIGHT_SHIFT)) 
    {
		Desktop* gui;
        ESCReply op = local_game.handleESC( &gui );
        if(op == ESCReply.GUI) {
            menu::setGUI(gui);
        } else if(op == ESCReply.MAIN) {
            menu::start(local_game.main_menu);
        } else {
            menu::setGUI(null); // disable any gui
        }
	}

$if $feature(MICROUI_ENABLE):
    // #region MicroUI initialization
    if(local_game.mu_ctx != null) 
    {
        //float scroll_speed = -30.0f; // scroll speed for mouse wheel.
        local_game.mu_ctx.forward_mouse_input();
        local_game.mu_ctx.forward_text_input();
        local_game.mu_ctx.forward_keyboard_input();
    }
$endif
    
    /*
    if(rl::isKeyPressed(rl::KEY_SPACE)) {
        if(rl::isMusicReady(local_game.default_music)) {
            rl::stopMusicStream(local_game.default_music);
            rl::playMusicStream(local_game.default_music);
        }
    }
    */

    
    if(rl::isKeyPressed(rl::KEY_G)) {
        menu::exit();
    }

$if $feature(MUJS_ENABLE):
     if(rl::isKeyPressed(rl::KEY_F6)) 
     {
        // TODO(HM) make a file watcher for scripts and automatically reload them
        // DELETE(HM) just a developer code for hot reload of the main script file.
        if(local_game.mujs_state)
        {
            mujs::@try(local_game.mujs_state)
            {
                int ret = local_game.mujs_state.runScript(local_game.app_base_folder.tconcat("scripts/main.js"));
                assert(ret == 0);
            };
        }
    }
$endif
    
        
    // exit game
    //if(rl::isKeyPressed(rl::KEY_F10)) {
        //libc::exit(0); // do not use, doesn't do necessary clean up.
        
        //local_game.should_quit = true;
    //}

/*  
    if( rl::isWindowReady() &&
        rl::isWindowFocused() &&
        rl::isWindowFullscreen() == false &&
        rl::isKeyDown(rl::KEY_LEFT_ALT)) 
    {
        Vec2f current_screen_res = {
            rl::getScreenWidth(),
            rl::getScreenHeight()
        };
        
        int curr_index;
        
        foreach(int index , &it : SCREEN_RES) {
            if(current_screen_res.x == it.w &&
               current_screen_res.y == it.h) {
                curr_index = index;
                break;
            }
        }
        
        if(rl::isKeyDown(rl::KEY_UP)) 
        {
            curr_index++;
            if(curr_index >= SCREEN_RES.len) curr_index = 0;
        }
        else if(rl::isKeyDown(rl::KEY_DOWN)) 
        {
            curr_index--;
            if(curr_index < 0) curr_index = SCREEN_RES.len-1;
        }
        
        local_game.updateScreenSize(curr_index);
    }
*/

    
    
    if(input::Action* action = input::getAction("particles")) {
        if(action.fnBecameTriggered()) {
             unreachable();
            //if(local_game.particleSpawner1.isActive() == false) local_game.particleSpawner1.activate();
            //log::info(Where.CONSOLE, "Action BECAME triggered!!!!!!");
        }
    }
    /*
    if(input::gpManager.getActionByName("quit").fnDoubleTriggered(0.250f)) {
        log::info(Where.CONSOLE, "Quit Action DOUBLE triggered!!!!!!");
    }
    
    if(input::gpManager.getActionByName("quit").wasTriggered()) {
        log::info(Where.CONSOLE, "Quit Action WAS triggered!!!!!!");
    }*/
    
    if(rl::getKeyPressed()) {
        local_game.last_key_pressed = rl::getKeyPressed();
    }
}

fn void gameUpdate() @local 
{
    misc::@profile_zone("Game Update")
    {
    $if $feature(_DEBUG):
        const CHOICE = 1;
    $else
        const CHOICE = 0;
    $endif
    tracy::@zoneN("gameUpdate", CHOICE)
    {
        // make game run at lower rate in case window loses focus
        int runningHz = rl::getFPS();
        int max_fps = local_game.max_fps;
        if(max_fps <= 0) {
            max_fps = math::clamp(local_game.max_fps, MIN_DISPLAY_HZ, local_game.screen.displayHz);
        }
        int targetHz = (local_game.fps_unlocked && max_fps > 0) ? max_fps : local_game.screen.displayHz;
        if(rl::isWindowFocused())
        {
            if(runningHz <= MIN_DISPLAY_HZ)
            {
                if(targetHz > MAX_DISPLAY_HZ) targetHz = MAX_DISPLAY_HZ;
                rl::setTargetFPS(targetHz);
                local_game.pause_all_music = 0;
            }
        }
        else if(runningHz > MIN_DISPLAY_HZ) // lost focus
        {
            //$if !$feature(TRACY_ENABLE):
                rl::setTargetFPS(MIN_DISPLAY_HZ);
                local_game.pause_all_music = 1;
            //$endif
        }
        //////////
        
        gameHandleGeneralControls();

        if(editor.getBool() && local_game.editor.isOpened()) {
            local_game.editor.update();
        }
        
        // physics engine
        if(local_game.pause_phys_simulation == false && rl::isWindowFocused()) {
			//float deltaTime = rl::getFrameTime();
			local_game.physWorldId.step(local_game.phys_time_step, local_game.phys_substep_count);
        }
        //

$if $defined(SCRIPT_ENGINE):
        local_game.script_eng.update();
$endif
        
        // updates all fullscreen menus state like the main menu
        desk::gpManager.update();
        
        // if(rl::isCursorOnScreen()) {
            // io::printfn("on screen id: %s", rl::getCurrentMonitor());
        // } else {
            // io::printfn("NOT ON SCREEN!!!!!");
        // }
        
        local_game.view.update();
        
        // done on sprite.c3 now
        //update_game_cursor(local_game.screen.w, local_game.screen.h);
        
        // TODO(HM) Make a seperate function to update various timers?
        local_game.testTimer.update();
        
        // boids
        $if $defined(BOIDS_ENABLE):
        local_game.boidManager1.update(rl::getScreenWidth(), rl::getScreenHeight(), local_game.dt);
        $endif

        if(local_game.testTimer.alive()) {
            //io::printfn("Timer time = %s!!!", local_game.testTimer.lifetime);
        } else { 
            //io::printfn("Timer run out press F2 to start again!!!");
            if (rgui::button((RLRectangle) { 24, 24, 120, 30 }, "#191#Show Message")) local_game.showMessageBox = true;

            if (local_game.showMessageBox)
            {
                int result = rgui::messageBox((RLRectangle) { 85, 70, 250, 100 },
                    "#191#Message Box", "Hi! This is a message!", "Nice;Cool");

                if (result >= 0) local_game.showMessageBox = false;
            }
        }
        
        // Todo handle more music but only one music should play at the same time...
        if(rl::isMusicValid(local_game.default_music)) 
        {
            if(rl::isMusicStreamPlaying(local_game.default_music))
            {
                if(local_game.pause_all_music && !rl::isWindowFocused()) {
                    rl::pauseMusicStream(local_game.default_music);
                }
            } 
            else if(rl::isWindowFocused() && local_game.pause_all_music == 0 && 
                    local_game.mode != GameMode.PLAYING &&
                    local_game.mode != GameMode.EDITOR &&
                    local_game.mode != GameMode.STARTING &&
                    local_game.mode == GameMode.MENU)
            {
                // play music stream
                rl::resumeMusicStream(local_game.default_music);
            }

            // Update music buffer with new stream data
            rl::updateMusicStream(local_game.default_music);
        }
        
        // update game sprites
        if(local_game.sprites.len()) {
            foreach(sprite : local_game.sprites) {
                //if(sprite.kind == SpriteKind.CURSOR && game_cursor_visible()) {
                    //sprite.update();
                //} else {
                    // generic sprite
                    sprite.update();
                //}
            }
        }
        
        if(local_game.should_update_entities)
        {
            // remove all dead entities
            if(local_game.entitiesToRemove.len()) 
            {
                foreach(ent : local_game.entitiesToRemove)
                {
                    if(ent.isDead())
                    {
                        usz i = local_game.entityList.index_of(ent)!!;
                        usz old_size = local_game.entityList.len();
                        local_game.entityList.remove_at(i);
                        usz new_size = old_size - 1;
                        if(new_size == 0) {
                            log::info(FILE, "All entities were destroyed!");
                        } else {
                            log::info(FILE, "Entity '%s' was removed from the game! Remaining entities: %d", ent.name, new_size);
                        }
                        local_game.entityList._update_size_change(old_size, new_size);
                    }
                    local_game.entitiesToRemove.remove_at(local_game.entitiesToRemove.index_of(ent)!!);
                }
                local_game.entitiesToRemove.clear();
            }
            
            ////////////////////////////////////////////
            // entity thinking
            foreach(ent: local_game.thinkingEntities)
            {
                if(ent == null) 
                {
                    unreachable("Entity in thinking list is null!");
                }

                if(ent.isDead()) 
                {
                    log::error(FILE, "Entity '%s' was in thinking list but is dead!\n", ent.name);
                    local_game.thinkingEntities.remove_at(local_game.thinkingEntities.index_of(ent)!!);
                    continue;
                }

                if(ent.type == Player.typeid) 
                {
                    assert(ent != null);
                    // Need to cast Entity* to Player* to call player think not Entity think...
                    ((Player*)ent).think(dt: local_game.dt);
                } 
                else // all other entities
                {
                    assert(ent != null);
                    ent.think(dt: local_game.dt);
                }
            }
            //
        }
        
        if(misc::g_debugLines.len()) {
            foreach(line : misc::g_debugLines) {
                line.update();
            }
        }

        // update message box's
        if(messageBoxs.len()) {
            messageBoxsIndecesToRemove.clear();

            foreach(i, box : messageBoxs) {
                if(box.shouldRemove && !box.isVisible) {
                    messageBoxsIndecesToRemove.push(i);
                } else if(box.shouldRemove && box.isVisible) {
                    log::warning(CONSOLE, "Message box set to remove but still visible!!!");
                    unreachable();
                }
            }

            if(messageBoxsIndecesToRemove.len()) {
                foreach(i : messageBoxsIndecesToRemove) {
                    messageBoxs.remove_at(i);
                }
            }
        }
    }; // tracy
    }; // profile_zone
}

fn void gameReset() @local {
    @todo("reset game state");
}

fn void drawGameVersion(Vec2i at_pos) @inline @local
{
    // draw game version
    const RLColor COLOR @Hardcode = {127, 127, 255, 255};
    const VERSION_FONT_SCALE = 12;
    //ZString game_version     = string::tformat_zstr("version: (%s, %s, %s)", lic::MAX_VERSION, lic::MIN_VERSION, lic::BABY_VERSION);
    //int version_text_len     = rl::measureText(game_version, VERSION_FONT_SCALE);
    rl::drawText(
        string::tformat_zstr("game version: %s", lic::@game_version()),
        //(int)(screenWidth - (2.0f * version_text_len)), //(float)(font_w * libc::strlen(game_version))),
        //(int)0.25f*screenHeight,
        at_pos.x,
        at_pos.y,
        VERSION_FONT_SCALE,
        COLOR
    );
}

fn void drawWorkInProgressMessage(int screen_w, int screen_h) @local 
{
    const RLColor COLOR @Hardcode = {223, 196, 125, 127};
    RLFont* font = local_game.candara_font;
    if(!font) unreachable("Required font for WIP message is missing!");
    if(!rl::isFontValid(*font))  font = &local_game.default_font;
    if(!font) unreachable("Trying to use default font for WIP message but it is missing!");
    
    //int font_w = (int)font.recs.width;

    //String message   = string::tformat_zstr("Total entities alive: None");
    String message    = "WORK IN PROGRESS";
    int text_len      = rl::measureText(message.zstr_tcopy(), 12);
    int screen_middle = (int)math::floor(0.5f*screen_w);
    //int x = (int)(0.65f * ((float)(screen_middle + (font_w * message.len))));
    int x = (int)(0.60f * ((float)(screen_middle + text_len)));
    int y = (int)math::floor(0.01f*screen_h);
    rl::drawText(string::tformat_zstr("%s (uses Raylib %s)", message, rl::VERSION), x, y, 12, COLOR);
    //rl::drawTextEx(*font, string::tformat_zstr("%s (Raylib %s)", message, rl::VERSION), {x, y}, 12, 1.0f, rl::RED);
    drawGameVersion({x, y + 16});
}

fn void drawGameOnScreenDebugInfo(int screen_w, int screen_h) @local
{
    if(guieditor::enabled() || (!dbg_stats.getBool() && !local_game.show_statistics)) return;
    
    ZString slot1;
    ZString slot2;
    ZString slot3;
    ZString slot4;
    ZString slot5;
    ZString slot6;
    ZString slot7;
    ZString slot8;
    ZString slot9;
    ZString slot10;
    ZString slot11;
    ZString slot12;

    // slot 1

    if (int entity_count = (int)local_game.entityList.len()) {
        slot1 = string::tformat_zstr("Total entities alive: %d", entity_count);
        //slot1 = (String)io::bprintf(&buffer, "Total entities alive: %d", entity_count)!!;
    } else {
        slot1 = string::tformat_zstr("Total entities alive: None");
    }
    
    //sprintf(slot3, "Player view is Zoomed: %s", (view_is_Zoomed) ? "^2TRUE" : "^1FALSE");
    slot2 = string::tformat_zstr("Game Mode = %s ", local_game.mode);
    //slot3 = string::tformat_zstr("Screen W/H: [%d | %d] ", screen_w, screen_h);
    slot3 = string::tformat_zstr("Game time: %d(ms) ", local_game.time_ms);
    slot4 = string::tformat_zstr("Mouse delta X: %.2f ", rl::getMouseDelta().x);
    slot5 = string::tformat_zstr("Mouse delta Y: %.2f ", rl::getMouseDelta().y);
    slot6 = string::tformat_zstr("Mouse Y: %.2f ", rl::getMousePosition().y); // same as rl::getMouseY()
    slot7 = string::tformat_zstr("Mouse X: %.2f ", rl::getMousePosition().x); // same as rl::getMouseX()
    slot8 = string::tformat_zstr("Debug Lines count: %d", misc::g_debugLines.len());
    //slot8 = string::tformat_zstr("Window Focus State: %s", (rl::isWindowFocused()) ? "focused" : "unfocused");
    slot9 = string::tformat_zstr("Key Press: %s", local_game.last_key_pressed);
    slot10 = string::tformat_zstr("Canonical mouse coords = %s", local_game.view.toCanonicalViewSpace(rl::getMousePosition().toVec2i()));
    slot11 = string::tformat_zstr("current menu: %s", (local_game.guiActive) ? local_game.guiActive.getName() : "none");
    slot12 = string::tformat_zstr("none");
    
    // switch (action)
    // {
    // case ACTION_FROBBING:
        // sprintf(slot12, "Interaction: ^1%s", "FROBBING");
        // break;
    // case ACTION_GRABBING:
        // sprintf(slot12, "Interaction: ^1%s", "GRABBING");
        // break;
    // case ACTION_HIDDING:
        // sprintf(slot12, "Interaction: ^1%s", "HIDDING");
        // break;
    // case ACTION_PICKING_OBJCT:
        // sprintf(slot12, "Interaction: ^1%s", "PICKING_OBJCT");
        // break;
    // case ACTION_SAVING:
        // sprintf(slot12, "Interaction: ^1%s", "SAVING");
        // break;
    // case ACTION_PUSHING:
        // sprintf(slot12, "Interaction: ^1%s", "PUSHING");
        // break;
    // default:
        // sprintf(slot12, "Interaction: ^1%s", "NULL");
        // break;
    // }
    
    RenderView* view = &local_game.view;
    const rl::RLColor* COLOR = &rl::YELLOW;
    int x = (int)math::floor(0.01f*view.w);
    int y = view.h;
    
    rl::drawText(slot1, x, (int)math::floor(0.01f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot2, x, (int)math::floor(0.03f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot3, x, (int)math::floor(0.05f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot4, x, (int)math::floor(0.07f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot5, x, (int)math::floor(0.09f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot6, x, (int)math::floor(0.11f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot7, x, (int)math::floor(0.13f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot8, x, (int)math::floor(0.15f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot9, x, (int)math::floor(0.17f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot10, x, (int)math::floor(0.19f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot11, x, (int)math::floor(0.21f*y), SMALL_FONT_SIZE, *COLOR);
    rl::drawText(slot12, x, (int)math::floor(0.23f*y), SMALL_FONT_SIZE, *COLOR);
    //***************************************************************************************************************************************
    
    // draw gui coords
    /*rl::drawRectangle(0, 0, 8, 8, rl::SKYBLUE);
    Vec2f x_line_end = {0.85f*screen_w, 0.0f};
    rl::drawLineV({0.0f, 0.0f}, x_line_end, rl::RED);
    rl::drawText(
        string::tformat_zstr("width = %s", screen_w), 
        (int)x_line_end.x + 5, // x
        (int)x_line_end.y, // y
        12,
        rl::WHITE//{127, 127, 127, 127}
    );
    */
    // TODO(HM) make this work
    // misc::draw_arrow({0.0f, 0.0f}, {0.85f*screen_w, 0.0f}, rl::RED);
}

// local Game functions NOTE(HM) local cannot be overriden when importing modules
fn void gameDraw(int screenWidth, int screenHeight) @local 
{
    //float gameDraw_start = @start_profile_zone();
    //defer @end_profile_zone(gameDraw_start);
    misc::@profile_zone("Game Draw", OFF)
    {
        // 1) render to "offline" frame buffer objects/images in the background
        local_game.view.renderToFBO();
        
        // Main Basic rendering
        //rl::beginDrawing();
        rl::@drawing() 
        {
            local_game.render.setBackGroundColor({0x18, 0x18, 0x18, 0xFF});
            //rl::clearBackground(*(RLColor*)&&((uint[1]){ 0x181818FF }));

            // 2) render the view FBO's rendered above into the back buffer
            if(rl::isShaderValid(*local_game.current_global_shader)) 
            {
                //(*local_game.current_global_shader).setUniformTexture("_currentRender", local_game.view.currentRender.texture);
                rl::@shaderMode(*local_game.current_global_shader) 
                {
                    local_game.view.draw();
                };
            } 
            else // render using raylib default shader
            {
                local_game.view.draw();
            }
            
            // NOTE(HM) 
            // drawing after the scene is draw but before the GUI
            gameOnPostSceneDraw(screenWidth, screenHeight);
            //
            //gameOnGuiDraw(screenWidth, screenHeight);
            // NOTE(HM) 
            // drawing after the GUI is draw
            //gameOnPostGUIDraw(screenWidth, screenHeight);

            // draw message box's
            if(messageBoxs.len()) {
                foreach(box : messageBoxs ) {
                    box.draw();
                }
            }
            
            // this is where input pooling and swapping buffers happens
            //rl::endDrawing();
        };
        tracy::frameMark();
        
        // NOTE(HM) 1)
        // drawing after the frame buffer are swapped/updated
        // NOTE(HM) 2)
        // Not sure this is usefull for, I saw this function when studing 
        // the HPL1 engine from where I got some of the ideas, 
        // so just here for the time I understand and have use for this.
        gameOnPostBufferSwap();
    }; // profile_zone
}

// NOTE(HM) Any code here draws before the game user interface
fn void gameOnPostSceneDraw(int screenWidth, int screenHeight) @local 
{
$if $feature(MICROUI_ENABLE) :
    // process microui panels/frames
    mu::process_frames(local_game.mu_ctx, rl::getFrameTime());

    if(local_game.show_microui_test_frames && mu::open_frames.len() == 0) {
        local_game.show_microui_test_frames = false; // disable microui focus if no frames are open
    }
    // NOTE(HM) microui context end, should be called 
    // before calling the followiong microui commands
    // that is done inside mu::process_frames()::@render() function.

    MU_Command * cmd = null;
    while (local_game.mu_ctx.next_command(&cmd))
    {
      switch (cmd.type)
      {
        case mu::MU_COMMAND_JUMP: io::printfn("MU_COMMAND_JUMP");
        case mu::MU_COMMAND_TEXT: mu::draw_text((ZString)&cmd.text.str, cmd.text.pos, cmd.text.color);
        case mu::MU_COMMAND_RECT: mu::draw_rect(cmd.rect.rect, cmd.rect.color);
        case mu::MU_COMMAND_ICON: mu::draw_icon(cmd.icon.id, cmd.icon.rect, cmd.icon.color);
        case mu::MU_COMMAND_CLIP: mu::set_clip_rect(cmd.clip.rect);
      }
    }
    // Make sure we end any lingering scissor mode.
   // Without this precaution it's possible for clipping to persist into the next frame 
   // and obstruct stuff until the next clip command from microui is handled!
   //rl::endScissorMode();
$endif

    // draw game cursor sprite
    draw_game_cursor();
}

// NOTE(HM) Any code here draws on top of the game user interface
// good place to put debug code...
fn void gameOnPostGUIDraw(int screenWidth, int screenHeight) @public 
{
    // draw game fps and frametime
    if(r_showFPS.getBool()) {
        int x = (int)((0.93f * screenWidth) - 120.0f);
        int y = (int)(0.02f * screenHeight);
        rl::drawTextEx(
            *local_game.candara_font,
            string::tformat_zstr("OpenGL v%s, FPS: %d", rl::glsl_version(), rl::getFPS()), 
            (RLVector2){(float)x, (float)y}, 18.0f, 1.0f, 
            rl::LIME
        );
        rl::drawTextEx(
            *local_game.candara_font,
            string::tformat_zstr("frametime: %.2f ms", rl::getFrameTime()*1000), 
            (RLVector2){(float)x, (float)y + 18}, 16.0f, 1.0f, 
            rl::LIME
        );
        //rl::drawFPS((int)(0.93f * screenWidth), (int)(0.02f * screenHeight));
    }

    // draw raygui message box error
    drawMsgBox(screenWidth, screenHeight);
    
    if(developer.getBool())
    {
        drawWorkInProgressMessage(screenWidth, screenHeight);

        if(editor.getBool()) {
            local_game.editor.draw(screenWidth, screenHeight);
        }
        
        if(local_game.mode == EDITOR || local_game.mode == PLAYING) {
            drawGameOnScreenDebugInfo(screenWidth, screenHeight);
        }
        
        // draw debug_lines 
        // NOTE(HM) should this be allowed in normal gaming as well?
        if(misc::g_debugLines.len()) {
            foreach(line : misc::g_debugLines) {
                line.draw();
            }
        }
    }
}

fn void gameOnGuiDraw(int screenWidth, int screenHeight) @public @inline {
    
    desk::gpManager.draw(screenWidth, screenHeight);
    
    if(local_game.intro.should_play) {
        intro::drawAnimation(&local_game.intro, screenWidth, screenHeight);
    }

    if(local_game.showSaveMessage && 
       local_game.mode != STARTING && 
       local_game.mode != INTRO &&
       local_game.time_ms <= local_game.saveMessageTime) 
    {
        //rgui::drawNotification((RLRectangle){(float)(screenWidth - 220), 20.0f, 200.0f, 30.0f}, "#191#Game Saved!", 2.0f);
        String message = "Game Saved!";
        int text_size = rl::measureText(message.zstr_tcopy(), 20);
        int x = screenWidth / 2 - (text_size / 2);
        int y = screenHeight / 2 - 10;
        rl::drawTextEx(
            *local_game.candara_font,
            string::tformat_zstr("%s", message), 
            (RLVector2){(float)x, (float)y}, 20.0f, 1.0f, 
            rl::LIME
        );
    } else {
        local_game.showSaveMessage = false;
    }
    
    // // update & draw cursor sprite
    // if(game_cursor_visible()) {
    //     hide_system_cursor();
    //     foreach(sprite : local_game.sprites) {
    //         if(sprite.kind == SpriteKind.CURSOR) {
    //             sprite.draw();
    //         }
    //     }
    // }
    
    if(local_game.msgbox_showing) {
        ZString message_box_title = rgui::iconText(Icon.INFO, "Message Box"); // "#191#Message Box"
        int sucess = rgui::messageBox({ (float)screenWidth/2, (float)screenHeight/2, 512, 128 }, message_box_title, "F1 key was pressed once", "OK");
        if(sucess >= 0) {
            local_game.msgbox_showing = false;
        }
    }
}

fn void gameOnPostBufferSwap() @local @inline {
    // NOTE(HM) Any extra rendering code here 
    // draws after the raylib frame buffer is swapped/updated
    //example:
        // drawMyExtraStuff();
        //rl::endDrawing(); // swap buffers again and poll input events
        //rl::waitTime(16); // milliseconds 1 frame (requires enabling manual frame control in raylib)
    // TODO
}

//////////////////////////////////////////////////////////////////
// #region ARGS HANDLING ************************

fn void handle_boolean_cmd(String cmd) @inline 
{
    // NOTE(HM) changing this cmds values will require a full game restart.
    // special bool cmds (comands with no values, who's existance is enough to be set to true)
    switch(cmd)
    {
        case "developer":
            developer.set("1");
        case "g_log":
            log::g_log.set("true"); 
        case "editor":
            editor.set("1");
        case "window": nextcase;
        case "w":      nextcase;
        case "win":
            int value = r_fullscreen.getInt();
            if(value > 0) {
                r_fullscreen.set("0");
                log::warning(CONSOLE, "cmdline arg '%s' is overriding the value set by r_fullscreen.", cmd); 
            } else {
                log::warning(CONSOLE, "cmdline arg '%s' is not doing anything as r_fullscreen is already zero.", cmd); 
            }
        default:
            log::warning(CONSOLE, "Invalid cmdline argument '%s'!", cmd);
    }
}

/*
NOTE(HM) 
The first argument in a cmdline, is just the path to the executable, 
so if there's only one argument, there's no need to run handle_cmdline().
Also cmdline arguments require a full game restart, this may change, 
if I ever create a developer console...
*/
fn void handle_cmdline(String[] args)
{
    if(args.len <= 1) return;
    
    log::info(FILE, "Handling cmd line args: %s\n", args[1..]);

    String cmd_arg;

    foreach(arg_index, arg : args)
    {
        // skip first argument, is only the path to the executable or its name.
        if(arg_index == 0) continue;
        
        // skip equals sign or a space
        if(arg == "=" || arg == " ") continue;
        
        bool cmd_is_boolean, 
             arg_is_number, 
             arg_is_string, 
             invalid_value_arg,
             single_char_value;
        
        single_char_value = arg.len == 1;

        // start of a command
        if(arg.starts_with("+"))
        {
            cmd_arg = arg.trim("+");
            
            // if the next cmd starts with a plus then the current cmd has no assignment operator
            // or extra value and should be considered a boolean argument.
            cmd_is_boolean = (args[arg_index + 1].starts_with("+")) ? true : false;
            
            if(cmd_is_boolean) {
                handle_boolean_cmd(cmd_arg);
            }
            
            continue; // skip to the next argument
        }
        
        // from here should be the value assigned to a cmd
        switch
        {
            case ascii::is_digit(arg[0]):
                arg_is_number = true;
                if(single_char_value) break;
                // else
                foreach(ch: arg) 
                {
                    if(ascii::is_digit(ch) == false && ch != '.') 
                    {
                        arg_is_number = false;
                        nextcase default;
                    }
                }
            case arg.starts_with("-"): // negative numbers
                if(single_char_value) 
                {
                    log::warning(CONSOLE, "rogue minus sign found in value of cmd \"%s\".", cmd_arg);
                    continue; // skip to next argument
                }

                arg_is_number = true;
                for(int i = 1; i < arg.len; i++) 
                {
                    char ch = arg[i];
                    if(ascii::is_digit(ch) == false && ch != '.') 
                    {
                        arg_is_number = false;
                        nextcase default;
                    }
                }
            case arg.starts_with("\""):
                if(!single_char_value && arg.ends_with("\"")) 
                {
                    arg_is_string = true;
                } else {
                    log::warning(CONSOLE, "malformed string assigned to \"%s\", strings most be defined between two \"\".", arg, cmd_arg);
                    continue; // skip to next argument
                }
            case ascii::is_alpha(arg[0]):
                log::warning(CONSOLE, "malformed string assigned to \"%s\", strings most be defined between two \"\".", arg, cmd_arg);
                continue;
            default:
                log::warning(CONSOLE, "invalid value '%s' assigned to cmd '%s'.", arg, cmd_arg);
                continue;
        }
        
        if(arg_is_number)
        {
            bool arg_is_float;
            
            if(!single_char_value) 
            {
                // detect floats
                foreach(ch : arg) 
                {
                    if(ch == '.') 
                    {
                        arg_is_float = true;
                        break;
                    }
                    
                    if(ch == ',') 
                    {
                        log::warning(CONSOLE, "value %s in cmdline has a comma seperator.\n   -That is not supported for numbers, please use dot instead.", arg);
                        invalid_value_arg = true;
                    }
                }
            }
            
            bool valid_value = !invalid_value_arg;
            if(valid_value) {
                int ivalue;
                float fvalue;
                    
                if(arg_is_float) 
                {
                    if(try value = arg.to_float()) 
                    {
                        fvalue = value;
                    } else {
                        log::warning(CONSOLE, "Unnable to convert value \"%s\" of cmdline arg \"%s\" to float value!", arg, cmd_arg);
                    }
                } else {
                    if(try value = arg.to_int()) 
                    {
                        ivalue = value;
                    } else {
                        log::warning(CONSOLE, "Unnable to convert value \"%s\" of cmdline arg \"%s\" to integer value!", arg, cmd_arg);
                    }
                }
                
                // NOTE(HM) changing this cmds values will require a full game restart.
                switch(cmd_arg)
                {
                    case "g_log":
                        if(ivalue >= 1)
                        {
                            if(ivalue <= 4)
                            {
                                log::g_log.set(arg);
                            } else { // clamp it
                                log::g_log.set("4");
                            }
                        } else {
                            log::g_log.set("0");
                        } 
                    case "r_mode":
                        if(ivalue >= 0 && ivalue <= SCREEN_RES.len - 1) 
                        {
                            r_mode.set(arg);
                        } else {
                            log::warning(CONSOLE, "Ignoring cmdline arg '%s' invalid resolution index, expected '0..%s' found \"%s\".", cmd_arg, SCREEN_RES.len - 1, arg);
                        }
                    case "r_fullscreen":
                        if(ivalue >= 0 && ivalue <= 2) 
                        {
                            r_fullscreen.set(arg);
                        } else {
                            log::warning(CONSOLE, "Ignoring cmdline arg '%s' invalid value, should be from '0..2'.", cmd_arg); 
                        }
                    default:
                        log::warning(CONSOLE, "cmdline arg '%s' with value = %s is still not handled.", cmd_arg, arg);
                }
            }
        }
        else if(arg_is_string)
        {
            switch(cmd_arg)
            {
                case "fs_base":
                    fs_base.set(arg);
                case "fs_mod_name":
                    fs_mod_name.set(arg);
                case "fs_mod_base":
                    fs_mod_base.set(arg);
                default:
                    log::warning(CONSOLE, "cmdline arg '%s' with string = %s is still not handled.", cmd_arg, arg);
            }
        }
    }
}

fn void print_game_version() @local @inline {
    log::info(FILE, "---------------------------------------------");
    log::info(FILE, "Game Version: %s", lic::@game_version());
    log::info(FILE, "---------------------------------------------\n");
}

// #endregion ARGS HANDLING ******************
//////////////////////////////////////////////////////////////////

/* This is where game execution begins */
fn void? gameOnStart(String[]* args) @local 
{
    local_game.mode = STARTING;
    
    print_game_version();
    
    // Handle cmdline arguments if any.
$if $feature(TSODING_FLAG):
    List{ZString} argv;
    defer argv.clear();
    for(int i = 0; i < args.len; i++) {
        argv.push((*args)[i].zstr_tcopy());
    }

    if (!flg::flag_parse(args.len, argv.to_tarray())) {
        usage();
        flg::print_error(&&io::stderr());
        return GAME_START_FAILED?;
    }
$else
    handle_cmdline(*args);
$endif
     // NOTE(HM) 
    // This will save cvars in a global array for later looping through if needed
    register_modulo_cvars();

    //
    // ******* Main Game Start *******
    //

    log::info(FILE, "Initializing game:");
    log::info(FILE, "---------------------------------------------");
    
    // TODO load the user.ini at this time?

    if(fl_help.getBool()) 
    {
        cvar::printCvars();
        // TODO(HM) print key actions and cmdline args as well
        //usage(); todo make this function a reality...
    }
    
// #region Paths/Folders Setup
    log::info(FILE, "Registering game paths:");
    log::info(FILE, "---------------------------------------------");
    String app_exe_path = (*args)[0];
    
    // Set the game name
    local_game.app_name = lic::GAME_NAME;
    if(local_game.app_name != "")
    {
        if(lic::GAME_SUB_NAME.len > 0)
        {
            local_game.app_name = local_game.app_name.tconcat(lic::GAME_SUB_NAME);
        }
    } else {
        // take the name from the exe path
        local_game.app_name = fs::getFileNameWithoutExt(app_exe_path).tconcat("_app");
    }
    
    // Detect and Setup the work directory folder,
    // NOTE(HM) app_exe_path has the working dir encoded on it, but also includes the exe name, 
    //          rl::getWorkingDirectory() removes the name and gets the required path.
    // This also saves original work dir, in case a mod is being used.
    local_game.app_default_workdir = fs::getWorkingDirectory();
    if(fs::directoryExists(local_game.app_default_workdir))
    {
        log::info(FILE, "\tWorking from default Dir: %s", local_game.app_default_workdir);
    } else { 
        return INVALID_WORK_DIR?; // will this ever happen?
    }
    // Detect and Setup the base folder where required game assets/data live.
    local_game.app_default_base_folder = local_game.app_default_workdir.tconcat(fs_base.getString()).tconcat(platf::PATHSEPERATOR_STR);
    
    local_game.app_work_dir    = local_game.app_default_workdir;
    local_game.app_base_folder = local_game.app_default_base_folder;
    
    // NOTE(HM) support for mods.
    // WARNING(HM) This is needs more testing...
    bool using_mod     = fs_mod_name.getString().len > 0;
    local_game.is_modded_game = using_mod;
    if(using_mod)
    {
        String mods_dir, mod_name, mod_work_dir, mod_base_folder;
        bool mod_handling_failed;

        mod_name = fs_mod_name.getString();
        if(mod_name.len <= 2) {
            log::warning(FILE, "mod name: \"%s\" seems to be very small are you sure that is correct?", mod_name);
        }

        mods_dir = local_game.app_default_workdir.tconcat("mods");
        if(fs::directoryExists(mods_dir)) // look inside
        {
            mod_work_dir = mods_dir.tconcat(platf::PATHSEPERATOR_STR).tconcat(mod_name).tconcat(platf::PATHSEPERATOR_STR);
            // make sure mod work dir exists as well
            if(fs::directoryExists(mod_work_dir))
            {
                // set the game work dir to the mod work dir
                local_game.app_work_dir = mod_work_dir;
                // now set the game base dir for the mod base dir
                mod_base_folder = mod_work_dir.tconcat(fs_mod_base.getString()).tconcat(platf::PATHSEPERATOR_STR);
                // also make sure the mod base dir exists
                if(fs::directoryExists(mod_base_folder))
                {
                    local_game.app_base_folder = mod_base_folder;
                } else { 
                    log::warning(FILE, "base directory for mod \"%s\" is missing cannot run mod!", mod_name);
                    mod_handling_failed = true;
                }
            } else { 
                log::warning(FILE, "Work directory for mod \"%s\" is missing cannot run mod!", mod_name);
                mod_handling_failed = true;
            }
        } else {
            log::warning(FILE, "Mod %s has to be run from inside folder \"mods\" but none was found at: %s", mod_name, local_game.app_default_workdir);
            mod_handling_failed = true;
        }

        if(mod_handling_failed)
        {
            log::warning(FILE, "Mod handling failed, using default work dir: %s", local_game.app_default_workdir);
            local_game.app_work_dir    = local_game.app_default_workdir;
            local_game.app_base_folder = local_game.app_default_base_folder;
        }
    }
    
    // make sure required work dir exists
    if(fs::directoryExists(local_game.app_work_dir)) 
    {
        if(local_game.app_work_dir != local_game.app_default_workdir) 
        {
            log::info(FILE,  "\tWorking now from Dir: %s", local_game.app_work_dir);
        }
    } else {
        return INVALID_WORK_DIR?;
    }
    
    // make sure required base folder exists
    if(fs::directoryExists(local_game.app_base_folder)) 
    {
        log::info(FILE,  "\tBase Dir set to: %s", local_game.app_base_folder);
    } 
    else
    {
        if(local_game.is_modded_game) 
        {
            log::error(FILE,`Required base folder inside %s not found!\n
                       A non-empty folder called '%s' (case sensitive) most exist!`, 
                       local_game.app_work_dir, 
                       (fs_mod_base.getString().len > 0) ? fs_mod_base.getString() : fs_base.getString(), 
                       local_game.app_name);
        } else {
            log::error(FILE,`Required base folder inside %s not found!\n
                       A non-empty folder called '%s' (case sensitive) most exist.\n
                       Please reinstall game.`, local_game.app_work_dir, fs_base.getString(), local_game.app_name);
        }
        return NO_DATA_FOLDER?;
    }
    
    // get the home folder to save necessary game data
    local_game.app_save_folder = win32::getSystemSpecialPath(win32::PERSONAL_FOLDER_MY_GAMES);
    if(local_game.app_save_folder.len > 0)
    {
        // NOTE(HM) append the desired final folder 
        // and look in the OS user save directory, to see if folder is already there 
        // if not create it.
        local_game.app_save_folder = local_game.app_save_folder.tconcat(platf::PATHSEPERATOR_STR).tconcat(local_game.app_name);
        if(fs::directoryExists(local_game.app_save_folder)) 
        {
            log::info(FILE, "\tUser Save folder set to: %s", local_game.app_save_folder);
        } else { // create it
            //Path? save_path = path::temp_new(save_folder)!;
            //bool? sucess    = path::mkdir(save_path);
            bool? sucess    = fs::makeDirectory_IfNotExist(local_game.app_save_folder);
            if(catch excuse = sucess) 
            {
                log::warning(FILE,"Failed to create user folder %s inside %s with excuse: %s", 
                           local_game.app_name, local_game.app_save_folder, excuse);
                return NO_USER_SAVE_FOLDER?;
            }
        }
    }

    // test writting to the register
    $if $defined(env::WIN32):
    {
        // NOTE(HM) this is only for windows, to test if we can write to the registry
        // and if the user has permissions to do so.
        String reg_key = "Software\\HMartSoftware\\unnnamed\\settings\\";
        String reg_value = "TestValue";
        String reg_data = "TestData";
        
        if(!win32::writeRegistryValue(reg_key, reg_value, reg_data)) {
            log::warning(FILE, "Failed to write to registry key: %s", reg_key);
            //return REGISTRY_WRITE_FAILED?;
        }
    }
    $endif // $if $defined(env::WIN32)

    log::info(FILE, "---------------------------------------------\n");
// #endregion

////////////////////////////////////////////////////
    // show splash screen
    if(r_noSplashPic.getBool() == false) showSplashScreenImage();
////////////////////////////////////////////////////

// #region InitRaylib library stuff
    
    // init rand count generator for rl
    rl::setRandomSeed(69);
    
    // window flags
    RLConfigFlag window_flags; // special windows flags for the rl window handling
    
    // support modern high dpi monitors (replaces the need for manual use of GetWindowScaleDPI() functionality)
    //window_flags |= (int)rl::FLAG_WINDOW_HIGHDPI;
    bkend::setWindowFlag(&window_flags, rl::FLAG_WINDOW_HIGHDPI);
    
    // TODO(HM)
    // Create a console here for error displaying...
    // Display help text in the console
    //  if any of char* helpArgs[] = { "--help", "-h", "-help", "-?", "/?" }; cvar is provided
    // Print engine version in the console

// #region Ini file handling
    log::info(FILE, "Loading settings file:");
    log::info(FILE, "---------------------------------------------");
    String ini_file_path = local_game.app_base_folder.tconcat(ini::SETTINGS_FILE_NAME);
    bool settings_file_missing = fs::fileExists(ini_file_path) == false;
    if (settings_file_missing) // create it with default settings
    {
        ini::create_default_settings_file(ini_file_path);
    }
    
    // load the settings file
    ConfigFile* settings_file = &local_game.settings_file;
    bool? settings_load_sucess = settings_file.load(ini_file_path, false);
    //ConfigFile*? settings_file = ini::load(ini_file_path, false); //ini::load(SETTINGS_FILE_NAME);
    if( catch excuse = settings_load_sucess) {
        log::warning(FILE, "Failed to load %s file with excuse: %s", ini_file_path, excuse);
        settings_file = null;
        return excuse?;
    }
    //defer if(settings_load_sucess) ini::unload(&settings_file);

    @off() 
    {
        // Test json file reading
        File? file = fs::openFile(fs::getWorkingDirectory().tconcat("prefs.data"));
        if( catch excuse = file) {
            log::warning(FILE, "Failed to load json file with excuse: %s", excuse);
            return excuse?;
        }
        //String jstext = fs::fileLoadEntireText(fs::getWorkingDirectory().tconcat("prefs.data"));
        Object*? config = json::tparse(&file);
        //Object*? config = json::tparse_string(jstext)!;
        if(catch excuse = config) {
            log::warning(FILE, "Failed to parse json file with excuse: %s", excuse);
            return excuse?;
        }
        config.map.@each(; String key, value) {
            io::printfn("%s -> %s", key, value);
        };
        // !json
    };

    log::info(FILE, "Settings file loaded: %s", ini_file_path);
    log::info(FILE, "---------------------------------------------\n");
// #endregion Ini file handling

    // set game language
    if(settings_file.hasSection("game")) 
    {
        local_game.langdict.type = settings_file.getString("language");
        assert(local_game.langdict.type != "");
        Path? langs_path = path::temp(local_game.app_base_folder.tconcat("langs\\local.lang"))!;
        if(try local_game.langdict.load(langs_path.str_view())) {
            log::info(FILE, "languages data file loaded sucessfully.\n\t-> %s", langs_path!);
            log::info(FILE, "---------------------------------------------\n");
        } else {
            unreachable("failed to load languages data file: %s!!", langs_path!);
        }
    } else {
        //settings_file.addSection(settings_file.createSection("game"));
        //settings_file.addToSection("game", mem::new(IniCMD, {"language", "pt"}));
        unreachable("invalid ini file, required [game] section was not found!!");
    }

    // change raylib log level
    // NOTE(HM) this will override the default log level set before in pre_InitFunc()
    if(settings_file.getBool("log")! == true)
    {
        String log_mode = settings_file.getString("log_level");
        switch(log_mode)
        {
            case "info": log::setLogLevel(RLTraceLogLevel.INFO);
            case "warn": log::setLogLevel(RLTraceLogLevel.WARNING);
            case "error": log::setLogLevel(RLTraceLogLevel.ERROR);
            case "fatal": log::setLogLevel(RLTraceLogLevel.FATAL);
            default:
                // NOTE(HM) default is set to INFO
                log::setLogLevel(RLTraceLogLevel.WARNING);
                log::warning(FILE, "Unknown logging option '%s' setting to default WARNING level.", log_mode);
        }
    }
    else if(settings_file.getBool("log")! == false)
    {
        // NOTE(HM) disable raylib logging
        log::setLogLevel(RLTraceLogLevel.NONE);
        log::info(FILE, "Logging disabled.");
    }

    // log the amount of screen resolutions and their Mode
    log::info(FILE, "Total video modes : %d", SCREEN_RES.len);
    log::info(FILE, "Enumerating rendering video modes:");
    foreach(res: SCREEN_RES) {
        log::info(FILE, "\t%s", res.str);
    }
    
    // default screen resolution
    local_game.screen.w = DEFAULT_SCREEN_REZ.w;
    local_game.screen.h = DEFAULT_SCREEN_REZ.h;
    
    // NOTE(HM): 
    // If we set r_mode at game start in the cmdline, it will have top priority 
    // and will override the value, written in the ini file 
    // and also replace the value, originally assigned to the r_mode cvar.
    int res_index = r_mode.getInt();
    if(res_index != -1)
    {
        // first prevent array overflow
        if(res_index >= SCREEN_RES.len) {
            log::warning(FILE, "Array index overflow, r_mode = %d is not valid, setting to default: %d", res_index, DEFAULT_SCREEN_INDEX);
            res_index = DEFAULT_SCREEN_INDEX;
        }

        local_game.screen.w = SCREEN_RES[res_index].w;
        local_game.screen.h = SCREEN_RES[res_index].h;
    }
    // NOTE(HM): If cmdline/cvar was NOT set or is -1,
    // then look into the ini file for its r_mode instead.
    else
    {
        // DOC(HM) '!' at the expression end, is the same as doing:
        // int? res_index  = settings_file.getInt("r_mode");
        // if(catch excuse = res_index ) { return excuse; }

        if(settings_file.getInt("r_mode")! == -1)
        {
            int w_value, h_value;
            // use ini defined custom resolutions
            if(try value =  settings_file.getInt("r_custom_width"))  w_value = value;
            if(try value =  settings_file.getInt("r_custom_heigth")) h_value = value;
            
            // see if the custom resolution exists in the list of resolutions
            // NOTE(HM) if the custom resolution is not found, it will return -1
            res_index = getResolutionIndexFromValues(w_value, h_value);
            if(res_index == -1) 
            {
                log::warning(FILE, "Custom resolution %dx%d not found in the list of video modes, using it as is.", w_value, h_value);
                local_game.screen.w = w_value;
                local_game.screen.h = h_value;
            }
            else 
            {
                local_game.screen.w = SCREEN_RES[res_index].w;
                local_game.screen.h = SCREEN_RES[res_index].h;
                log::info(FILE, "Custom resolution %dx%d found in the list of video modes, using it.", 
                          local_game.screen.w, local_game.screen.h);
            }
        }
    }
    
    // at this point we should have a valid screen resolution
    if(res_index == -1 || local_game.screen.w <= 0 || local_game.screen.h <= 0) 
    {
        log::error(FILE, "Invalid screen resolution %dx%d, cannot continue!", local_game.screen.w, local_game.screen.h);
        return INVALID_SCREEN_RESOLUTION?;
    }
    
    log::info(FILE,  "Video mode set -> %s", SCREEN_RES[res_index].str);

    log::info(FILE, "---------------------------------------------\n");
    log::info(FILE, "Window settings:");
    log::info(FILE, "---------------------------------------------");
    // Vertical sync (this is a hint so may or may not apply...)
    if(try settings_file.getBool("vsync")) 
    {
        //window_flags |= (int)rl::FLAG_VSYNC_HINT;
        bkend::setWindowFlag(&window_flags, rl::FLAG_VSYNC_HINT);
        local_game.screen.vsync_hint = true;
        log::info(FILE, "VSync hint enabled. (This is a hint, not a guarantee!)");
    }
    
    // NOTE(HM) cvar r_fullscreen has top priority
    int fullscreen_choice = r_fullscreen.getInt();
    // NOTE(HM) if cvar was not set, see if the config file is overriding the value
    if(fullscreen_choice == -1) fullscreen_choice = settings_file.getInt("r_fullscreen")!;
    
    // prevent under or overflow
    if(fullscreen_choice < -1 || fullscreen_choice > 2) 
    {
        int choice = fullscreen_choice;
        log::warning(FILE, "invalid value: %d for r_fullscreen, using default. Valid values are '-1, 0, 1, 2'", choice);
        if(choice < -1) {
            fullscreen_choice = -1;
        } else {
            fullscreen_choice = 2;
        }
    }
    
    switch(fullscreen_choice)
    {
        case 1:
            //window_flags |= (int)rl::FLAG_FULLSCREEN_MODE;
            bkend::setWindowFlag(&window_flags, rl::FLAG_FULLSCREEN_MODE);
            local_game.screen.state.fullscreen = true;
        case 2:
            //window_flags |= (int)rl::FLAG_WINDOW_UNDECORATED;
            bkend::setWindowFlag(&window_flags, rl::FLAG_WINDOW_UNDECORATED);
            local_game.screen.state.borderless = true;
        default: // fullscreen_choice -1 or 0
            local_game.screen.state.window = true;
    }
    
    // DOC(HM) 
    // Multi-sampling AA (ONLY 0 or 4x is supported by Raylib, there's no inbetween)
    if(local_game.screen.state.fullscreen) 
    {
        if(try msaa_samples = settings_file.getInt("msaa")) 
        {
            if(msaa_samples > 0) 
            {
                //window_flags |= (int)rl::FLAG_MSAA_4X_HINT;
                bkend::setWindowFlag(&window_flags, rl::FLAG_MSAA_4X_HINT);
                local_game.screen.multiSamples = msaa_samples;
                log::info(FILE, "4x MSAA hint enabled (as a hint, may not apply).");
            }
        }
    }
    
    // NOTE(HM) Decided to disable the ability to resize the window to simplify things
    // if(local_game.screen.state.window) {
        // if(try settings_file.getBoolValue("r_window_resizable")) {
            // window_flags |= rl::FLAG_WINDOW_RESIZABLE;
            // local_game.screen.state.resizable = true;
        // }
    // }
    log::info(FILE, "---------------------------------------------\n");

// #region Window initialization
    log::info(FILE, "Initializing window:");
    log::info(FILE, "---------------------------------------------");
    // set/apply the final window flags
    //rl::setConfigFlags((RLConfigFlag)window_flags);
    
    int screenWidth     = local_game.screen.w;
    int screenHeight    = local_game.screen.h;
    ZString window_name = string::tformat_zstr("%s version: (%s, %s, %s)", local_game.app_name.zstr_tcopy(), lic::MAX_VERSION, lic::MIN_VERSION, lic::BABY_VERSION);
    
    //===============================//
    //========= Init Window ======== //
    $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
        WindowHandle window = local_game.render.createWindow(
            title: window_name.str_view(),
            width: screenWidth,
            height: screenHeight,
            flags: window_flags
        )!;

        log::info(FILE, "Window initialized successfully.");

        if(local_game.screen.state.fullscreen == true)
        {
            log::info(FILE,  "Game window set to Real/Dedicated Fullscreen mode.");
        }
        else if(local_game.screen.state.borderless == true)
        {
            log::info(FILE,  "Game window set to Borderless fullscreen mode.");
        }
        else if(local_game.screen.state.window == true)
        {
            log::info(FILE,  "Game window set to Windowed mode.");
        }
        else
        {
            unreachable("Game window is not set to any known state, this should never happen!");
            //return WINDOW_INIT_FAILED?;
        }
    $else
        rl::initWindow(screenWidth, screenHeight, window_name);
        //============================== //
        
        if(rl::isWindowReady() == false) 
        {
            log::fatal(FILE, "Failed to init rl window and OpenGL context!");
            return WINDOW_INIT_FAILED?;
        } else {
            log::info(FILE, "Window initialized successfully.");

            if(local_game.screen.state.fullscreen == true)
            {
                log::info(FILE,  "Game window set to Real/Dedicated Fullscreen mode.");
            }
            else if(local_game.screen.state.borderless == true)
            {
                log::info(FILE,  "Game window set to Borderless fullscreen mode.");
            }
            else if(local_game.screen.state.window == true)
            {
                log::info(FILE,  "Game window set to Windowed mode.");
            }
            else
            {
                unreachable("Game window is not set to any known state, this should never happen!");
                //return WINDOW_INIT_FAILED?;
            }
        }
    $endif

    local_game.screen.width_in_meters = misc::pixelsToMeters(screenWidth);
    local_game.screen.height_in_meters = misc::pixelsToMeters(screenHeight);
    local_game.screen.center = {screenWidth/2.0f,screenHeight/2.0f};

    // rlgl init
    //rlgl::init(screenWidth, screenHeight);

$if env::WIN32:
    /*
		Force the main thread to always run on CPU 0.
		This is done because on some systems QueryPerformanceCounter returns a bit different counter values
		on the different CPUs (contrary to what it's supposed to do), which can cause negative frame times
		if the thread is scheduled on the other CPU in the next frame. This can cause very jerky behavior and
		appear as if frames return out of order.
	*/
	win32::setThreadAffinityMask(win32::getCurrentThread(), 1);
$endif

    // NOTE(HM) Gameplay timing, is always counted since initWindow above;
    local_game.time_sec = (float)rl::getTime();
    local_game.time_ms  = misc::@sec2ms(local_game.time_sec);
    log::info(FILE, "---------------------------------------------\n");

    // init raygui dark style (needs to be done after raylib window is initialized)
    log::info(FILE, "loading raygui dark style:");
    log::info(FILE, "---------------------------------------------\n");
    rgui::style::dark::load();
    log::info(FILE, "- done -\n");

// #region MONITOR STATES
    log::info(FILE, "Setting up monitor states:");
    log::info(FILE, "---------------------------------------------");
    // See how many monitors user has and change the window placement if necessary.
    // WARNING(HM) This is not guarantied to work for all multi-monitor setups, 
    // it seems that even glfw, that rl uses internally, fails to set the correct monitor on some setups :(
    int monitor_count = rl::getMonitorCount();
    if(monitor_count >= 2) // is multi-monitor setup
    {
        log::info(FILE, "\tMulti-Monitor setup found:");
        bool chose_screen_pos_by_mouse = true; // @Hardcode
        if(chose_screen_pos_by_mouse)
        {
            // enable_system_cursor();
            // int monitor_index = monitor_count - 1;
            // do {
                 // if(monitor_index >= 0) rl::setWindowMonitor(monitor_index--);
            // } while(rl::isCursorOnScreen() == false);
            
            // current_monitor = monitor_index;
            
            int displayIndex;
            // try to put the window on the display the mousecursor is currently on
                
            int x = rl::getMouseX();
            int y = rl::getMouseY();

            for (int i = 0; i < monitor_count; ++i) 
            {
                int w,h;
                Vec2f mpos;
                $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
                    w = local_game.render.getMonitorPhysicalWidth(i);
                    h = local_game.render.getMonitorPhysicalHeight(i);
                    mpos = local_game.render.getMonitorPosition(i);
                $else
                    w = rl::getMonitorPhysicalWidth(i);
                    h = rl::getMonitorPhysicalHeight(i);
                    mpos = rl::getMonitorPosition(i);
                $endif
                rl::RLRectangle rect = {mpos.x, mpos.y, w, h};
                if ( x >= rect.x && x < rect.x + rect.width
                    && y >= rect.y && y < rect.y + rect.height )
                {
                    displayIndex = i;
                    break;
                }
            }
            
            if(displayIndex < 0 && displayIndex > (monitor_count - 1))
            {
                // NOTE(HM) If all else fails, set the game to first monitor index
                displayIndex = 0;
            }

            local_game.screen.index = displayIndex;
            local_game.screen.id    = displayIndex + 1;
            $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
                local_game.render.setMainMonitor(local_game.screen.index);
            $else
                rl::setWindowMonitor(local_game.screen.index);
            $endif
        }
    }
    
    log::info(FILE, "\tWindow put on monitor id: '%d' name: '%s", local_game.screen.id, rl::getMonitorName(local_game.screen.index));
    
    // @Todo 
    // Support user setting frame rate on main menu?
    $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
        local_game.screen.displayHz = local_game.render.getMonitorRefreshRate(local_game.screen.index);
    $else
        local_game.screen.displayHz = rl::getMonitorRefreshRate(local_game.screen.index);
    $endif
    local_game.fps_unlocked     = r_fps_unlocked.getBool();
    local_game.max_fps          = r_max_fps.getInt();

    if(/*rl::isWindowFullscreen() &&*/rl::isWindowFocused()) 
    {
        if(local_game.fps_unlocked && local_game.max_fps > 0)
        {
            if(local_game.max_fps < MIN_DISPLAY_HZ) {
                local_game.max_fps = MIN_DISPLAY_HZ;
            } 
            else if(local_game.max_fps > MAX_DISPLAY_HZ) {
                local_game.max_fps = MAX_DISPLAY_HZ; // to prevent extreme values
            }
            rl::setTargetFPS(local_game.max_fps);
            log::info(FILE,  "\tGame set to unlocked framerate with a max of %shz.", local_game.max_fps);
            if(local_game.max_fps > local_game.screen.displayHz) {
                log::info(FILE,  "\tNote: max fps is higher than monitor speed of %s hz, tearing may occur!", local_game.screen.displayHz);
                log::info(FILE,  "\t      consider enabling vsync or lowering max fps using fps limiter in the main menu.");
                log::info(FILE,  "\t      (you can also set a custom max fps value using r_max_fps in the ini file).");
                log::info(FILE,  "\t      (or set 'r_fps_unlocked' to false in the ini file, to use current set monitor hz)");
                log::warning(FILE,  "\t      (changing these settings will require a game restart).");
                log::warning(FILE,  "\t      (running the game at a rate above display rate, is wastefull the monitor cannot display those frames to you).");
            }
        }
        else //if((!local_game.fps_unlocked || local_game.fps_unlocked) && local_game.max_fps <= 0)
        {
            // set the target fps to monitor set hz (framerate)
            rl::setTargetFPS(local_game.screen.displayHz);
            log::info(FILE,  "\tSetting game to display update rate of %shz.", local_game.screen.displayHz);
        }
    } 
    else if(local_game.screen.state.window || local_game.screen.state.borderless) // and lost focus
    {
        int val = (int)(MIN_DISPLAY_HZ_FACTOR * local_game.screen.displayHz);
        if(val < MIN_DISPLAY_HZ) val = MIN_DISPLAY_HZ;
        rl::setTargetFPS(val); // save resources when not focused
        log::info(FILE,  "\tGame set to %shz update rate because lost focus.", val);
    }
    

    log::info(FILE, "---------------------------------------------\n");
// #endregion MONITOR STATES

$if $feature(MICROUI_ENABLE):
    // #region MicroUI initialization
    log::info(FILE, "Initializing MicroUI:");
    log::info(FILE, "---------------------------------------------");
    // NOTE(HM) This needs to be done before any microUI function requiring units is used!!!
    local_game.mu_ctx = mem::new(MU_Context);
    local_game.mu_ctx.init();
    local_game.mu_ctx.text_width  = &mu::text_width;
    local_game.mu_ctx.text_height = &mu::text_height;
    local_game.mu_font_atlas = rl::loadTexture(local_game.app_base_folder.tconcat("images\\mu_atlas.png").zstr_tcopy());
    log::info(FILE, "---------------------------------------------\n");
$endif
    
    log::info(FILE, "Setting up game view:");
    log::info(FILE, "---------------------------------------------");
    // setup/init game view (for now is a static view)
    local_game.view.init(screenWidth, screenHeight);
    log::info(FILE, "---------------------------------------------\n");

$if $feature(_DEBUG):
    // TODO(HM) On release version quit should only be done from main menu (or alt+f4...).
    // NOTE(HM) This needs to run after initWindow,
    //          it changes the default exit key (default was ESC key)
    //rl::setExitKey(rl::KEY_F10);
    String key_name = settings_file.getString("quit", "KEY_ESCAPE");
    rl::setExitKey(input::getKeyCodeFromStr(key_name));
    log::info(FILE, "Exit key set to: %s", key_name);
    log::info(FILE, "---------------------------------------------\n");
$endif

// #endregion Window initialization

//  init video player
    local_game.vidplayer = vid::initVideoPlayer(local_game.app_base_folder.tconcat("videos/"));
    if(local_game.vidplayer) {
        local_game.vidplayer.registerVideos()!;
    }

// #region physics engine
    log::info(FILE, "Starting Physics Engine:");
    log::info(FILE, "---------------------------------------------");
    // TODO(HM) refactor this into a physics engine module that wraps box2d?
    B2Version version = box2d::getVersion();
    log::info(FILE, "\tBox2D version: \"%d.%d.%d\"", version.major, version.minor, version.revision);
    
    // NOTE(HM) This needs to be done before any box2d function requiring units is used!!!
	box2d::setLengthUnitsPerMeter(DEFAULT_PIXELS_PER_METER);
    
    // physics quality and performance options
    local_game.phys_time_step     = PHYS_DEFAULT_TIMESTEP;
    // NOTE(HM) Using fewer sub-steps increases performance but accuracy suffers. 
    // Likewise, using more sub-steps decreases performance but improves the quality of your simulation.
    local_game.phys_substep_count = PHYS_DEFAULT_SUBSTEPS;
    
    // 
    B2WorldDef physWorld   = box2d::defaultWorldDef();
    //physWorld.gravity      = GRAVITY_VEC;
    // NOTE(HM) Realistic gravity is achieved by multiplying gravity by the length unit.
	physWorld.gravity[1]    = GRAVITY_VALUE * DEFAULT_PIXELS_PER_METER;
    //
	local_game.physWorldId = box2d::createWorld(&physWorld);
    if(local_game.physWorldId.isValid()) {
        log::info(FILE, "\tBox2D Started.");
    } else {
        log::error(FILE, "Failed to start Box2D physics engine! Halting game initialization.");
        unreachable();
    }
    
    // create a static ground entity
    B2BodyDef  grd_bodydef = box2d::defaultBodyDef();
    int screen_half_x      = (int)0.5f * local_game.screen.w;
    Vec2f pos              = DEFAULT_WORLD_CENTER + misc::VEC_RIGHT * screen_half_x;
    pos                   += misc::VEC_DOWN * (0.75f* local_game.screen.h);
    grd_bodydef.position   = (B2Vec2)pos;//.toVector2();
    local_game.phys_grd_bodyid  = box2d::createBody(local_game.physWorldId, &grd_bodydef);
    //
    local_game.phys_grd_box     = box2d::makeBox(20.0f, 10.0f);
    B2ShapeDef  grd_shpdef      = box2d::defaultShapeDef();
    box2d::createPolygonShape(local_game.phys_grd_bodyid, &grd_shpdef, &local_game.phys_grd_box);
    
    box2d::initDebugDraw(&local_game.phys_debug, &local_game.view);

    log::info(FILE, "---------------------------------------------\n");
// #endregion physics engine
    
// #region AUDIO DEVICE initialization
    log::info(FILE, "Initializing Audio Device:");
    log::info(FILE, "---------------------------------------------");

    rl::initAudioDevice();
    
    if(rl::isAudioDeviceReady()) 
    {
        if(rl::getMasterVolume() < 1.0f) 
        {
            rl::setMasterVolume(1.0f);
            log::info(FILE, "\tAudio Master Volume set to = %s", 1.0f);
        } else {
            float master_volume = rl::getMasterVolume();
            if(master_volume > 1.0f) {
                log::warning(FILE, "\tAudio Master Volume is set to %.2f, this is not recommended!", master_volume);
                rl::setMasterVolume(1.0f); // clamp it
            } else {
                log::info(FILE, "\tAudio Master Volume is = %.1f", master_volume);
            }
        }
    } else {
        log::warning(FILE, "AudioDevice: Not ready, sound will be disabled! %s:%s", $$MODULE, $$FUNC );
    }

    log::info(FILE, "---------------------------------------------\n");
// #endregion AUDIO DEVICE initialization

// #region Asset manager
    log::info(FILE, "Loading game assets:");
    log::info(FILE, "---------------------------------------------");
    // first load default assets
    @catch(local_game.loadDefaultAssets());
    //
    // now load all other assets and catch a error if any
    @catch(astmng::loadAssets());
    
    // new material testing
    // load all material files from the material folder
    mtrmng::loadMaterialFilesTo(&local_game.mtrDB)!!;
    local_game.mtrDB.listMTRs();
    local_game.mtrDB.data[0].printMaterials();
    //mtr::RLMaterial default_mat;
    //default_mat.load(local_game.app_base_folder.tconcat("images/default.mtr"));
    //defer default_mat.free();
    
    // now that the assets are loaded get a pointer to the game fonts
    local_game.initFonts();
    //

    svg::SVGData svgfile;
    svgfile.path = local_game.app_base_folder.tconcat("levels/test.svg").copy(mem);
    if(svgfile.load()!) {
        log::info(FILE, "SVG file loaded successfully: %s", svgfile.path);
        //svgfile.printTofile(local_game.app_base_folder.tconcat("levels/test.txt"));
        //svgfile.print();
    } else {
        log::warning(FILE, "Failed to load SVG file: %s", svgfile.path);
    }
        
    log::info(FILE,  "** done **");
    log::info(FILE, "---------------------------------------------\n");
// #endregion Asset manager

$if $defined(SCRIPT_ENGINE):
    log::info(FILE, "Initializing Script Engine:");
    log::info(FILE, "---------------------------------------------");
    // init the game editor defaults
    local_game.script_eng.init();
    if(Script* main = local_game.script_eng.getScript("main")) {
        main.compile_run();
    }
    log::info(FILE, "---------------------------------------------\n");
$endif

    // test mujs initialization
$if $feature(MUJS_ENABLE):
    local_game.mujs_state = mujs::new_state();
    if(local_game.mujs_state) 
    {
        log::info(CONSOLE, "mujs script engine initialized successfully. > %s", local_game.mujs_state);
        int ret;
        ret = local_game.mujs_state.initStdLib();
        if(ret != 0) {
            log::warning(CONSOLE, "mujs script engine failed to init stdlib with code: %d", ret);
        }
        
        mujs::@try(local_game.mujs_state)
        {
            ret = local_game.mujs_state.runScript(local_game.app_base_folder.tconcat("scripts/main.js"));
            local_game.mujs_state.runFunction("hello", mujs::ISGLOBAL);
            //any[*] _args = { any_make(&&5, int.typeid), any_make(&&5, int.typeid) };
            local_game.mujs_state.runFunction("testwithargs", mujs::ISGLOBAL, 5, 5);
        };
        log::info(CONSOLE, "mujs script main.js run returned: %d", ret);
    } else {
        log::warning(CONSOLE, "Failed to initialize mujs script engine!");
    }
$endif

    // test LUA initialization
$if $feature(LUA_ENABLE):
    lua::createVirtualMachine(&local_game.lua_state);
    if(local_game.lua_state) 
    {
        log::info(CONSOLE, "lua script engine initialized successfully.");
        local_game.lua_debug = mem::new(LUADebug);


        // register needed paths in lua environment
        lua::registerGameLuaGlobals();
        /*lua::registerGlobalType("g_baseFolder", any_make(&gpGame.app_base_folder, String.typeid));
        lua::registerGlobalType("g_timeSc", any_make(&local_game.time_sec, float.typeid));
        lua::registerGlobalType("g_timeMs", any_make(&gpGame.time_ms, int.typeid));
        lua::registerGlobalType("g_deltaTime", any_make(&gpGame.dt, float.typeid));*/

        lua::runModulefunction("main", "init", 0);
        //int status = local_game.lua_state.@loadfile(local_game.app_base_folder.tconcat("scripts/main.lua"));
        /*bool status = local_game.lua_state.dofile(local_game.app_base_folder.tconcat("scripts/main.lua"));
        if(lua::check(local_game.lua_state, (int)status))
        {
            @off() 
            {
                // init the main.lua script
                if(local_game.lua_state.isfunction(-1)) 
                {
                    // call it
                    int r = local_game.lua_state.pcall(0, -1, 0);
                    if (lua::check(local_game.lua_state, r))
                    {
                        log::warning(CONSOLE, "'module' main.lua initialized sucessfully.");
                    } else {
                        log::warning(CONSOLE, "Failed to run 'module' main.lua!");
                    }
                }
                // get the main table
                TValue tp = local_game.lua_state.getglobal("main");
                local_game.lua_state.pop(1); // remove the nil value in the stack after the table
                if(local_game.lua_state.istable(-1)) 
                {
                    //lua::dumpstack(local_game.lua_state);
                    local_game.lua_state.pushstring("init");
                    local_game.lua_state.gettable(-2); // get main.init function
                    if(local_game.lua_state.isfunction(-1)) 
                    {
                        // call main.init()
                        int r = local_game.lua_state.pcall(0, 1, 0);
                        if (lua::check(local_game.lua_state, r))
                        {
                            // get return value
                            if(local_game.lua_state.isboolean(-1))
                            {
                                bool init_sucess = (bool)local_game.lua_state.toboolean(-1);
                                if(init_sucess) {
                                    log::info(CONSOLE, "'init' function in main.lua script ran sucessfully.");
                                } else {
                                    log::warning(CONSOLE, "'init' function in main.lua script failed to run sucessfully!");
                                }
                            } else {
                                log::warning(CONSOLE, "'init' function in main.lua script did not return a boolean value!");
                            }
                            // Remove the function and all its data from the stack
                            lua::clearStack(local_game.lua_state);
                        }
                    } else {
                        log::warning(CONSOLE, "Failed to find 'init' function in main.lua script!");
                        local_game.lua_state.pop(1); // remove the nil value in the stack after the function
                    }
                    //lua::clearStack(local_game.lua_state);
                }
            };
            // If no errors, we can run the loaded chunk
            // NOTE(HM) this will push the main module into the stack
            lua::runModulefunction("main", "init", 0);
        }*/
    } else {
        log::warning(CONSOLE, "Failed to initialize lua script engine!");
    }
$endif

$if $feature(UMKA_ENABLE):
    /*
    Umka* umkaContext = umka::alloc();
    String umScriptMain = local_game.app_base_folder.tconcat("scripts/main.um");
    String umfiledata = fs::fileLoadEntireText(umScriptMain);
    //if(catch excuse = umkaContext.init("main.um", umfiledata.zstr_tcopy(), 1024*1024, null, 0, null, false, false)) {
     UmkaScriptInitData inidata =
    {
        .fileName = umScriptMain.zstr_tcopy(),
        .sourceString = null, 
        .stackSize = 1024*1024, // 2MB (amount of stack memory for the context)
        .reserved = null, // unused 
        .argc = 0, // script flags count passed during game initialization if any...
        .argv = null, // script flags cmds passed during game initialization if any...
        .fileSystemEnabled = false, // todo find whats this...
        .implLibsEnabled = false // todo find whats this...
    };
    if(catch excuse = umkaContext.init(&inidata)) {
        log::info(CONSOLE, "failed to initialize umka script engine!!");
    } else {
        log::info(CONSOLE, "umka script engine initialized successfully.");
        log::info(CONSOLE, "\tCompiling main umka script.");
        bool umkaOk = umkaContext.compile();
        if (umkaOk)
        {
            log::info(CONSOLE, "\tSucess.");
            umkaContext.run();
        }
        else
        {
            UmkaError *error = umkaContext.getError();
            log::info(CONSOLE, "Umka error %s (%d, %d): %s\n", error.fileName, error.line, error.pos, error.msg);
        }
    }
    */
$endif

    log::info(FILE, "Initializing game editor:");
    log::info(FILE, "---------------------------------------------");
    // init the game editor defaults
    local_game.editor.initDefaults();
    log::info(FILE, "-done-");
    log::info(FILE, "---------------------------------------------\n");

    // init intro stuff here
    // Todo(HM) create real pre loading logo videos?
    //
    // Set the current program mode to the intro mode
    local_game.mode = INTRO;
    intro::initAnimation(&local_game.intro);
    
    // Load custom shader to be used on some parts drawing
    // NOTE 1: Using GLSL 330 shader version, on OpenGL ES 2.0 use GLSL 100 shader version
    // NOTE 2: Defining 0 (NULL) for vertex shader forces usage of internal rl default vertex shader
    //ZString shader_path = string::tformat_zstr("./data/shaders/basic%d.fs", rl::glsl_version());
    //local_game.default_shader = rl::loadShader("", shader_path);
    
    //if(rl::isShaderReady(local_game.default_shader))
    //{
        // doesn't work please study https://github.com/raysan5/rl/wiki/rl-generic-uber-shader-and-custom-shaders
        //float time  = 0.0f;
        //local_game.def_shader_time_loc = rl::getShaderLocation(local_game.default_shader, "uTime");
        //rl::setShaderValue(local_game.default_shader, local_game.def_shader_time_loc, &time, rl::SHADER_UNIFORM_FLOAT);
    //}
// #endregion InitRaylib stuff
    
// #region MAIN MENU 
    // NOTE(HM) Create main menu here but don't show it now
    local_game.main_menu = menu::mainMenuCreate(screenWidth, screenHeight);
    if(local_game.main_menu == null) {
        log::fatal(FILE, "Something went very wrong, failed to init Main Menu!");
        unreachable("!!!!!!!!! Failed to create main menu. !!!!!!!!!!!!!!");
    }
// #endregion MAIN MENU

    if(developer.getBool() && local_game.mode == EDITOR)
    {
        if(game_cursor_visible()) hide_game_cursor();
        if(!system_cursor_enabled()) enable_system_cursor();
        show_system_cursor();
    } else {
        if(system_cursor_enabled()) disable_system_cursor();
    }

    // TODO(HM) do this only in the main menu
    // custom game cursor
    if(local_game.mode == MENU) 
    {
        // just in case...
        if(system_cursor_enabled()) disable_system_cursor();
        init_game_cursor();
        //show_game_cursor(); now done in menus.c3
    }
    
// #region Test game stuff
    createGameInputActions(settings_file);

    if(fl_help.getBool())
    {
        input::printKeyActions();
    }
    
    // Create the main Single Player
    // NOTE(HM) todo: the player and ingame entities should be created only at spawn of a level 
    // but right now, I don't have a concept of a "level" or game World.
    // TODO(HM) when possible make a dedicated spawn point entity for the player.
    log::info(FILE,  "** Creating test player. **");
    local_game.main_player = plyr::makePlayer(id: 1, color: rl::BLUE);
    // NOTE(HM) The first entity is always the main player1
    local_game.entityList.push((Entity*)local_game.main_player);
    log::info(FILE,  "** Done **.");
    
    // local_game.particleSpawner1.init({
    //     0.5f*local_game.screen.w,
    //     0.85f*local_game.screen.h
    // });
    
    // Create test entities @delete
    log::info(FILE,  "** Creating test entities. **");
    for(int i = 1; i <= 2; i++) 
    {
        $if $defined(ENABLE_CAMERA_VIEW):
            Vec2f origin = local_game.view.origin;
        $else
            Vec2f origin;
        $endif
        origin = origin + misc::VEC_UP * 100 * i;
        
        Entity* test_ent = ent::create_ex(string::tformat("Entity%s", i), origin, rl::WHITE);
        test_ent.setMaterial("figure");
    }
    
    log::info(FILE,  "** Done. **");
    
    log::info(FILE,  "** Enabling test entities brains. **");
    if(local_game.entityList.len() >= 1) {
        local_game.should_update_entities = true;
    }
    
    // init the boids system
    $if $defined(BOIDS_ENABLE):
    local_game.boidManager1.init();
    $endif
    
    log::info(FILE,  "** Done. **");
// #endregion Test game stuff
    
    local_game.should_quit = false;
    log::info(FILE,  "Game Start Done Sucessfully.\n//**//");
}

fn void gameOnExit() @local 
{
    log::info(FILE,  "Game shutdown starting.");
    deinit_game_cursor();
    // make sure to release all assets last, so you don't try to release a asset that is already released.
    asstManager.releaseAllAssets();

$if $feature(WREN_ENABLE):
    log::info(FILE, "close wren Script Engine: %s", wren::VERSION_STRING);
    log::info(FILE, "---------------------------------------------");
    local_game.script_eng.deinit();
    log::info(FILE, "wren Script Engine closed.");
    log::info(FILE, "---------------------------------------------\n");
$endif

$if $feature(ANGEL_ENABLE):
    log::info(FILE, "close angel Script Engine: %s", angel::VERSION_STRING);
    log::info(FILE, "---------------------------------------------");
    if(local_game.asEngine != null) {
        local_game.asEngine.release();
        local_game.asEngine = null;
        log::info(FILE, "angel Script Engine closed.");
    }
    log::info(FILE, "---------------------------------------------\n");
$endif

$if $feature(MUJS_ENABLE):
    log::info(FILE, "close mujs Script Engine: %s", mujs::VERSION_STRING);
    log::info(FILE, "---------------------------------------------");
    if(local_game.mujs_state) {
        local_game.mujs_state.gc(mujs::GC_NOREPORT); // run a full garbage collection cycle
        local_game.mujs_state.free();
        local_game.mujs_state = null;
        log::info(FILE, "mujs Script closed.");
    }
    log::info(FILE, "---------------------------------------------\n");
$endif

$if $feature(LUA_ENABLE):
    /*
    lua_State * L = luaL_newstate(); 
      luaL_dostring(L, "a = 10 + 5"); 
      lua_getglobal(L, "a"); 
      int i = lua_tointeger(L, -1); 
      printf("%d\n", i); 
      lua_close(L); 
    */
    if(local_game.lua_state) 
    {
        log::info(FILE, "close lua Script: %s", lua::VERSION_STR);
        log::info(FILE, "---------------------------------------------");
        if(local_game.lua_debug != null) {
            mem::free(local_game.lua_debug);
            local_game.lua_debug = null;
        }
        local_game.lua_state.close();
        local_game.lua_state = null;
        log::info(FILE, "lua script engine closed.");
        log::info(FILE, "---------------------------------------------\n");
    }
$endif

    // close physics engine
    box2d::deinitDebugDraw(&local_game.phys_debug);
    if(local_game.physWorldId.isValid()) {
        log::info(FILE, "Destroying physics engine.");
        box2d::destroyWorld(local_game.physWorldId);
        log::info(FILE, "Done.");
    }
    //

    if(local_game.vidplayer) {
        vid::deinitVideoPlayer(local_game.vidplayer);
    }

    rl::closeAudioDevice();

    // clear language dictionair
    local_game.langdict.destroy();

    //
    if(local_game.settings_file.isModified())
    {
        // save the settings file
        log::info(FILE, "Saving settings file: %s", local_game.settings_file.path);
        if(local_game.settings_file.save()) {
            log::info(FILE, "Settings file saved successfully.");
        } else {
            log::warning(FILE, "Failed to save settings file.");
        }
    }
    ini::unload(&local_game.settings_file);
    //
    // debug_lines
    if(misc::g_debugLines.len())
    {
        misc::freeDebugLines();
    }

    $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
        local_game.render.shutdown();
    $else
        //rlgl::close();
        rl::closeWindow();
    $endif

    // DELETE THIS
    /*RLImage img = {
        .data = &mu::atlas_texture,
        .width = 128,
        .height = 128,
        .format = RLPixelFormat.UNCOMPRESSED_GRAYSCALE,
        .mipmaps = 1
    };

    //RLTexture2D texture = LoadTextureFromImage(img);
    if(rl::isImageValid(img)) {
        log::warning(FILE, "Exporting mu atlas texture to file: %s", local_game.app_base_folder.tconcat("images/").tconcat("mu_atlas.png"));
        rl::exportImage(img, local_game.app_base_folder.tconcat("images/").tconcat("mu_atlas.png").zstr_tcopy());
    }*/
    //

    local_game.unload();
    //rl::memFree(memory_pool);
    //log::info(FILE,  "clearing game singletons and log system!\n\t** Printing done on OS terminal from this point on **");
    log::info(FILE,  "clearing game singletons!");
    clear_game_singletons();
    log::info(FILE,  "Game shutdown done!!");
    log::closeLogFile();
}

fn void clear_game_singletons() @inline {
    gpGame = null; // clear pointer to game singleton
    //
    input::gpManager.free();
    input::gpManager = null;
    //
    desk::gpManager.free();
    desk::gpManager = null;
    log::info(FILE,  "**done**");
}

fn void saveGame()
{
    // look in the directory for the game save folder
    String save_folder = local_game.app_save_folder;
    if(fs::directoryExists(save_folder)) {
        String file_path = save_folder.tconcat(platf::PATHSEPERATOR_STR).tconcat(string::tformat("%s%s%s", local_game.app_name, local_game.time_ms, ".sav"));
        SaveFile? save_file = svs::make_new(file_path);
        defer (void)svs::close(&save_file);
        if(catch excuse = save_file) {
            log::warning(FILE, "Unable to save to file: %s with excuse: %s", file_path, excuse);
            return;
        }
        // save the game state to the file
        // #### TODO ENABLE THIS LATER!!!!! #####
        @off() { local_game.save(&save_file); };
        // ######################################
        log::info(FILE,  "Saved \"%s\" to folder: %s", file_path, save_folder);
        //todo show some ui message that the game was saved
        local_game.showSaveMessage = true;
        local_game.saveMessageTime = local_game.time_ms + 2000; // show for 2 seconds
    } else {
        log::warning(FILE,`Required save folder inside %s not found!\n
                    A folder called '%s' (case sensitive) most exist there!`,
                    local_game.app_save_folder, local_game.app_name);
        $if $feature(_DEBUG):
        unreachable();
        $endif
    }
}

fn void loadGame() 
{
    usz file_index;
    
    RLFilePathList files = fs::loadDirectoryFiles(local_game.app_save_folder);
    if(files.count == 0) {
        log::warning(CONSOLE, "Failed to get save files from: %s.", local_game.app_save_folder);
        return;
    }
    
    if(files.count >= 2) 
    {
        CLong prev_modtime;
        for(int i = 0; i < files.count; i++)
        {
            ZString file_path = (ZString)files.paths[i];
            if (fs::isDirectory(file_path.str_view())) continue;
            
            CLong modtime = fs::getFileModTime(file_path.str_view());
            
            if(modtime > prev_modtime) {
                prev_modtime = modtime;
                file_index = i;
            }
        }
    }
    
    // load the newer file then
    if(files.count) {
        SaveFile? save_file = svs::open(((ZString)files.paths[file_index]).str_view());
        defer (void)svs::close(&save_file);
        if(catch excuse = save_file) {
            log::warning(FILE, "Unable to open save file: %s with excuse: %s", files.paths[file_index], excuse);
            return;
        }
        
        local_game.reload(&save_file);
    }  

/* 
    Path? path = path::temp_new(local_game.app_save_folder);
    if(catch excuse = path) {
        log::warning(CONSOLE, "Failed to get home dir where save files are at with excuse: %s.", excuse);
        return;
    }
    
    PathList! files  = path::new_ls(path)!!; // new_ls only returns the filenames
    if(catch excuse = files) {
       log::warning(CONSOLE, "Failed to get save files from home dir with excuse: %s.", excuse);
        return;
    }
    
    if(files.len() == 1) {
       // load the only existing file
    } else {
        foreach (i, f : files)
        {
            // must append the file name to the path to get the full name to check with in is_dir
            if (path::is_dir(path.temp_append(f.path_string)!!))
            {
                //io::printfn("%s: is dir.", f);
                continue;
            }
            
            CLong modtime = rl::getFileModTime(f.path_string.zstr_tcopy());
            
            if(modtime > newer_modtime) {
                newer_modtime = modtime;
                file_index = i;
            }
        }
    }
    
    // load the newer file then
    if(newer_modtime) {
        String file_path = files[file_index].path_string;
        svs::SaveFile! save_file = svs::open(file_path);
        defer (void)svs::close(&save_file);
        if(catch excuse = save_file) {
            log::warning(FILE, "Unable to open save file: %s with excuse: %s", file_path, excuse);
            return;
        }
        
        local_game.reload(&save_file);
    }  
*/
}

<*
 @param [in] settings_file : "the ini file to read the game input actions from."
 @require settings_file != null
*>
fn void createGameInputActions(ConfigFile* settings_file) @inline @local
{
    defer input::listActions();

    String key_name;

    $if $feature(_DEBUG):
    input::makeKeyboardAction("screenshots", rl::KEY_F2, rl::KEY_NULL, (ActionCallBack)&camview::moveScreenShots);
$endif

$if !$feature(_DEBUG):
    //input::makeKeyboardAction("quit", input::getKeyCodeFromStr(settings_file.getString("quit")), rl::KEY_NULL, (ActionCallBack)&input::quitGame);
	input::@makeAction({.name = "quit", .kind = KEYBOARD, 
		.key1 = input::getKeyCodeFromStr(settings_file.getString("quit")), 
		.func = &quitGame});
$endif

    input::makeKeyboardAction("quicksave", input::getKeyCodeFromStr(settings_file.getString("quicksave")), rl::KEY_NULL, (ActionCallBack)&saveGame);
    input::makeKeyboardAction("quickload", input::getKeyCodeFromStr(settings_file.getString("quickload")), rl::KEY_NULL, (ActionCallBack)&loadGame);
    
    input::makeKeyboardAction("particles", rl::KEY_INSERT);

    // game main editor
    input::makeKeyboardAction("toggle_editor", rl::KEY_F1, rl::KEY_LEFT_SHIFT);

    // mouse actions
    input::makeMouseAction("Single Press", RLMouseButton.LEFT);
    input::makeMouseAction("Double Press", RLMouseButton.LEFT);
    // for the WIP game editor
    input::makeMouseAction("editor_select", RLMouseButton.LEFT, rl::KEY_LEFT_SHIFT);
}

////////////////////////////////// GAME LOOP ////////////////////////////////////////////////////////////////

fn void quitGame() @inline @public {
    local_game.should_quit = true;
}

fn void waitFrame(int msec = misc::sec2ms(1.0f / local_game.screen.displayHz)) @local {
    ulong sleep_time = (ulong)(msec);
    //ulong sleep_time = (ulong)(misc::sec2ms(1.0f / local_game.screen.displayHz) - local_game.dt);
    //log::info(CONSOLE, "Sleeping for %d ms to cap framerate to %d hz", sleep_time, local_game.screen.displayHz);
    thread::sleep_ms(sleep_time);
}

fn void gameDoOneFrame() @local
{
    misc::@profile_zone("Game Loop")
    {
        $if $feature(BACKEND_RAYLIB) || $feature(BACKEND_RGFW):
        while(rl::windowShouldClose() != true) 
        {
            //@pool()
            //{
                tracy::@messageL( "Tick" );
                tracy::@zoneN("Game loop", 1)
                {
                    @profile_zone("gameDoOneFrame", OFF)
                    {

                        if(local_game.should_quit) break;
                        
                        // update game timing
                        local_game.dt       = rl::getFrameTime(); // last frame time
                        local_game.time_sec = (float)rl::getTime();
                        local_game.time_ms  = misc::@sec2ms(local_game.time_sec);

                        $if $feature(LUA_ENABLE):
                        lua::updateGameLuaGlobals();
                        $endif

                        int screen_w = rl::getScreenWidth();
                        int screen_h = rl::getScreenHeight();
                        
                        gameUpdate();
                        gameDraw(screen_w, screen_h);

                        /*if(r_fps_unlocked.getBool() && r_max_fps.getInt() > 0)
                        {
                            int max_fps = r_max_fps.getInt();
                            if(max_fps > 240) {
                                max_fps = 240; // clamp to max 240 fps
                            }
                            // NOTE(HM) this will cap the framerate to the user defined value
                            waitFrame(misc::sec2ms(1.0f / max_fps));
                        }*/
                    }; // end @profile_zone
                }; // tracy scope end
           // };
        }
        $else
            bkend::@renderLoop(local_game.render) 
            {
                tracy::@messageL( "Tick" );
                tracy::@zoneN("Game loop", 1)
                {
                    @profile_zone("gameDoOneFrame", OFF)
                    {
                        if(local_game.should_quit) break;
                        
                        // update game timing
                        local_game.dt       = rl::getFrameTime(); // last frame time
                        local_game.time_sec = (float)rl::getTime();
                        local_game.time_ms  = misc::@sec2ms(local_game.time_sec);

                        $if $feature(LUA_ENABLE):
                        lua::updateGameLuaGlobals();
                        $endif

                        int screen_w = rl::getScreenWidth();
                        int screen_h = rl::getScreenHeight();
                        
                        gameUpdate();
                        gameDraw(screen_w, screen_h);
                    }; // end @profile_zone
                }; // tracy scope end
            };
        $endif
    };
    
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

//usz* memory_pool @local;

fn void pre_InitFunc() @init 
{
    io::printfn("/*******************************************\n");
    io::printfn("This should run %s%s%s main entry function!\n", ansi::color_rgb(171, 218, 217), "BEFORE", Ansi.RESET);
    io::printfn("*******************************************\\\n");
    
    //uint value = misc::megaBytes2Bytes(1024);
    //memory_pool = (usz*)rl::memAlloc( value * uint.sizeof);
    gameArena.init(mem, GAME_ARENA_PAGE_SIZE);
    
    // Controls raylib console logging
    // NOTE(HM) Raylib library/context gets initialized here!!
    // This is because is the first call from raylib we make.
    // NOTE(HM) This means the MINIMUM level not the only level that will log
    // anything bellow this level will not log
    // WARNING(HM) MAY BE OVERRIDEN LATER BY THE INI FILE SETTING!!!
$if $defined(_DEBUG):
    rl::setTraceLogLevel(RLTraceLogLevel.ALL);
$else
    rl::setTraceLogLevel(RLTraceLogLevel.ERROR);
$endif
    
    // ************* My own logging system ****************
    // RLTraceLogLevel means the MINIMUM log level, 
    // not the only level to log, anything bellow this level will not log.
    // WARNING(HM) MAY BE OVERRIDEN LATER BY THE INI FILE SETTING!!!
    log::init(RLTraceLogLevel.INFO);
    // *********************************************************

    local_game.warningBox.init(MessageBoxType.WARN);
    local_game.errorBox.init(MessageBoxType.ERROR);
    local_game.infoBox.init(MessageBoxType.INFO);

    showSettingsWindow();

    log::info(FILE, "-------- THE <toname> ENGINE LOG ------------");
    DateTime date = datetime::now();
    log::info(FILE, "\t%s of %s of %s at %sh:%sm", date.day, date.month, date.year, date.hour, date.min);
    log::info(FILE, "---------------------------------------------");
    log::info(FILE, "---------------------------------------------\n"); 

    // print machine info
    misc::printMachineInfo();

    win32::setPhysicalWorkMemory(192 << 20, 1024 << 20); // set min 192mb and max 1gb physical memory usage for this process
}

fn void usage() @local @if($feature(TSODING_FLAG))
{
    log::info(CONSOLE, "Usage: %s [options]", flg::program_name());
    log::info(CONSOLE, "Options:");
    flg::print_options();
}


//********** ENTRY FUNCTION ******************************
fn int main(String[] args) @public @if($feature(_DEBUG))
{ // with console
    return mainEntryFunc(args);
}

fn int main(String[] args) @public @winmain @if($feature(_RELEASE)) 
{ // without console
    return mainEntryFunc(args);
}

fn int mainEntryFunc(String[] args)
{
$if $feature(TRACY_ENABLE):
    tracy::set_thread_name("main_thread"); 
$endif

$if $feature(TSODING_FLAG):
    ZString* version = flg::flag_bool("version", false, "Print engine version");
    ZString* help    = flg::flag_bool("help", false, "Show this help message");
$endif

    fault excuse = @catch(gameOnStart(&args));
    if (excuse) {
        log::error(FILE, "Game initialization failed with excuse: %s", excuse);
        return -1;
    } else {
        //assetsLoadingMutex.init()!!;
        //assetsLoadingThread.create(&loadAssets, null)!!;
        //assetsLoadingThread.detach()!!;
        
        /*Thread[] threads = mem::temp_new_array(Thread, os::num_cpu());
        foreach (&t : threads) {
            t.create(&loadAssets, null)!!;
            // The thread resources will be cleaned up when the thread exits.
            t.detach()!!;
        }*/
        
        // Play the intro in a separate thread
        introMutex.init()!!; // used to protect intro state
        introThread.create(&playIntro, null)!!; // create and run intro thread
        introThread.detach()!!; // detach it so it runs independently and cleans up itself on exit

        // NOTE(HM) 
        // using .join hangs the game, I think this is because 
        // intro thread will block the main game thread and 
        // intro needs the main thread to run to display itself and update the window.
        //assert(introThread.join()!! == 0);
        //introMutex.destroy()!!;
        
        // run the game loop
        gameDoOneFrame();
        // NOTE(HM) For clean program exit, do not put any code here! 
        // Between this two calls!!!
        // Any per frame code should be put inside gameDoOneFrame 
        // and exit code should be put inside gameOnExit.    
        gameOnExit();
    }
    
    // return to Operating System.
    return 0;
}

// NOTE(HM) invoking @finalizer is a best effort attempt by the OS and may not be called during abnormal shutdown.
fn void pos_MainFunc() @finalizer
{
    io::printfn("/*******************************************\n");
    io::printfn("This should run %s%s%s main entry point function returns!\n", ansi::color_rgb(171, 218, 217), "AFTER", Ansi.RESET);
    io::printfn("*******************************************\\\n");
    libc::system("pause");
}


// #region testing area

// fn int loadAssets(void* args) {
    // assetsLoadingMutex.lock()!!;
    // io::printfn("created thread");
    // assetsLoadingMutex.unlock()!!;
    // return 0;
// }

// Stops all gameplay and goes to main menu
fn void disconnect() 
{
	menu::stop();
	menu::start(local_game.main_menu);
    
    // todo handle music and audio
	//if ( soundSystem ) {
		//soundSystem->SetMute( false );
	//}
}

// you can change the splash screen image. 
// Make sure your image is sized to 600 x 200 pixels
fn void showSplashScreenImage()
{
    int flags @noinit;
    // NOTE(HM) this function is not used right now
    // because I want to show a video intro instead of a static image.
    // But you can use it if you want to show a static image.
    String splash_path = local_game.app_base_folder.tconcat("images/splash.bmp");
    if(fs::fileExists(splash_path)) 
    {
        rl::RLImage splash_img = rl::loadImage(splash_path.zstr_tcopy());
        if(splash_img.data != null)
        {
            if(splash_img.width != 600 && splash_img.height != 200) 
            {
                $if $feature(_DEBUG):
                    unreachable("Splash image size is not 600x200 pixels!");
                $else
                    log::warning(FILE, "Splash image size is not 600x200 pixels, got %dx%d", splash_img.width, splash_img.height);
                $endif
            }
            flags = 0;
            flags |= (int)rl::FLAG_WINDOW_UNDECORATED;
            // set/apply the final window flags
            rl::setConfigFlags((RLConfigFlag)flags);
            rl::initWindow(600, 200, "");
            rl::setWindowMonitor(0); // set to first monitor
            rl::setTargetFPS(24); // set to 24 fps
            rl::RLTexture2D texture = rl::loadTextureFromImage(splash_img);
            float time_start = (float)rl::getTime();
            // show the image for X seconds
            while(!rl::windowShouldClose()) 
            {
                if(((float)rl::getTime() - time_start) > 2.0f) break;
                // draw
                rl::beginDrawing();
                rl::clearBackground(rl::RAYWHITE);
                rl::drawTexture(texture, (600 - texture.width)/2, (200 - texture.height)/2, rl::WHITE);
                rl::endDrawing();
            }
            //rl::beginDrawing();
            //rl::drawTexture(texture, (local_game.screen.w - texture.width)/2, (local_game.screen.h - texture.height)/2, rl::WHITE);
            // wait some time to let the user see the logo
            //rl::waitTime(5000); // wait 2 seconds
            //rl::endDrawing();
            rl::unloadImage(splash_img);
            rl::unloadTexture(texture);
            rl::clearWindowState((int)rl::FLAG_WINDOW_UNDECORATED);
            rl::closeWindow();
        } else {
            log::warning(CONSOLE, "Failed to load splash image: %s", splash_path);
        }
    } else {
        log::warning(CONSOLE, "Splash image not found: %s", splash_path);
    }
}


// ============================================================================================
const SETTINGS_WINDOW_WIDTH  @local = 400;
const SETTINGS_WINDOW_HEIGHT @local = 300;
const SETTINGS_WINDOW_X @local = 0;
const SETTINGS_WINDOW_Y @local = 0;
// global settings window state
bool show_settings_window @public = true;
<*
  Microui settings window
  Shown before game start for user to configure some options
  @param [&in] ctx : "The current MicroUI context."
 *> 
fn void settings_window(MU_Context* ctx) //@inline
{
    // TODO(HM) FINISH THIS LATER!!! 
    // - show a image/logo at the top of the window
    // see demoscene apps from cocoon for a example.
    // - solve the bugs and add more settings here
    // like audio volume, key bindings, 
    // add apply button to apply changes, etc...
    show_settings_window = ctx.@make_window("Settings", mu::rect(SETTINGS_WINDOW_X, SETTINGS_WINDOW_Y, SETTINGS_WINDOW_WIDTH, SETTINGS_WINDOW_HEIGHT))
    {
        MU_Container *win = ctx.get_current_container();
        win.rect.w = math::max(win.rect.w, 240);
        win.rect.h = math::max(win.rect.h, 300);

        if (ctx.header("Video Options")) 
        {
            win = ctx.get_current_container();
            ZString buf;
            ctx.layout_row(2, (int[]) { 54, -1 }, 0);
            ctx.label("Position:");
            buf = string::tformat_zstr("%d, %d", win.rect.x, win.rect.y); ctx.label(buf);
            ctx.label("Size:");
            buf = string::tformat_zstr("%d, %d", win.rect.w, win.rect.h); ctx.label(buf);
        }

        if (ctx.header("Sound Options"))
        {
            win = ctx.get_current_container();
            ZString buf;
            ctx.layout_row(2, (int[]) { 54, -1 }, 0);
            ctx.label("Position:");
            buf = string::tformat_zstr("%d, %d", win.rect.x, win.rect.y); ctx.label(buf);
            ctx.label("Size:");
            buf = string::tformat_zstr("%d, %d", win.rect.w, win.rect.h); ctx.label(buf);
        }

        if (ctx.header("Control Options"))
        {
            win = ctx.get_current_container();
            ZString buf;
            ctx.layout_row(2, (int[]) { 54, -1 }, 0);
            ctx.label("Position:");
            buf = string::tformat_zstr("%d, %d", win.rect.x, win.rect.y); ctx.label(buf);
            ctx.label("Size:");
            buf = string::tformat_zstr("%d, %d", win.rect.w, win.rect.h); ctx.label(buf);
        }
        
        /*ctx.@make_rows(1, &&(int[*]) { -1 }, -25)
        {
            MU_Container *panel;
            ctx.@make_panel("Video Options")
            {
                bool submitted = false;
                panel = ctx.get_current_container();
                ctx.@make_rows(10, &&(int[*]) { -1 }, -1)
                {
                    ZString gpu_name = string::tformat_zstr("%s", "AMD RX 9060 XT 16GB"); //rl::getGLRenderer();
                    ctx.label("Adapter:"); 
                    ctx.label(gpu_name);
                    //
                    ctx.label("Screen Resolution:");
                    CChar[32] buffer_width;
                    CChar[32] buffer_height;
                    if(ctx.textbox(&buffer_width, 32) & MU_Res.SUBMIT)
                    {
                        ctx.set_focus(ctx.last_id);
                        submitted = false; // reset submitted flag
                    }
                    ctx.label("x");
                    ctx.textbox(&buffer_height, 32);
                    ctx.label("Display Hz:");
                    CChar[5] buffer_hz;
                    ctx.textbox(&buffer_hz, 5);
                    //
                    int choice = 0;
                    // todo support more fullscreen modes like borderless windowed
                    ctx.checkbox("Fullscreen:", &choice);
                    if(choice) {
                        r_fullscreen.set("1");
                    } else {
                        if(r_fullscreen.getInt()) r_fullscreen.set("0");
                    }
                    choice = 0;
                    //ctx.checkbox("VSync:", &main::gpGame.vsync);
                };
            };
        };*/
    };
}
// ============================================================================================


fn void showSettingsWindow()
{
$if $feature(MICROUI_ENABLE):
    ZString font_path = rl::getApplicationDirectory().str_view().tconcat("data\\images\\mu_atlas.png").zstr_tcopy();

    MU_Context* mu_ctx = mem::tnew(MU_Context);
    mu_ctx.init();
    mu_ctx.text_width  = &mu::text_width;
    mu_ctx.text_height = &mu::text_height;

    int flags;
    flags |= (int)rl::FLAG_WINDOW_UNDECORATED;
    // set/apply the final window flags
    rl::setConfigFlags((RLConfigFlag)flags);
    rl::initWindow(SETTINGS_WINDOW_WIDTH, SETTINGS_WINDOW_HEIGHT, "");
    RLTexture2D mu_font_atlas = rl::loadTexture(font_path);
    rl::setWindowMonitor(0); // set to first monitor
    rl::setTargetFPS(24); // set to 24 fps

    while(!rl::windowShouldClose())
    {
        if(show_settings_window == false) break;

        //mu::process_frames(mu_ctx, rl::getFrameTime());

        mu_ctx.forward_mouse_input();
        mu_ctx.forward_text_input();
        mu_ctx.forward_keyboard_input();

        rl::@drawing()
        {
            rl::clearBackground(rl::RAYWHITE);

            mu::@render(mu_ctx)
            {
                mu_ctx.run(&settings_window);
            };
            // NOTE(HM) microui context end, should be called before calling this microui commands
            // that is done inside @render() function.

            MU_Command * cmd = null;
            while (mu_ctx.next_command(&cmd))
            {
                switch (cmd.type)
                {
                    case mu::MU_COMMAND_JUMP: io::printfn("MU_COMMAND_JUMP");
                    case mu::MU_COMMAND_TEXT: mu::draw_text((ZString)&cmd.text.str, cmd.text.pos, cmd.text.color);
                    case mu::MU_COMMAND_RECT: 
                    {
                        mu::draw_rect(cmd.rect.rect, cmd.rect.color);
                    } 
                    case mu::MU_COMMAND_ICON: 
                    {
                        //mu::draw_icon(cmd.icon.id, cmd.icon.rect, cmd.icon.color);
                        int id = cmd.icon.id;
                        MU_Rect _rect = cmd.icon.rect;
                        RLColor color = cmd.icon.color;

                        MU_Rect src = mu::ICONS[id];
                        int x = _rect.x + (_rect.w - src.w) / 2;
                        int y = _rect.y + (_rect.h - src.h) / 2;
                        // Assuming cmd->icon.id corresponds to a valid icon in the MicroUI icon set
                        // Here we would draw the icon based on its ID and rectangle
                        // For simplicity, we can use a placeholder drawing function
                        //draw_rect(rect(x, y, src.w, src.h), color); // Placeholder for actual icon drawing logic
                        rl::setBlendFactors(rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD);
                        rl::@blendMode(RLBlendMode.CUSTOM) 
                        //rl::@blendMode(RLBlendMode.ALPHA_PREMUL) 
                        {
                            rl::drawTexturePro(
                             texture: mu_font_atlas,
                             source: (RLRectangle){src.x, src.y, src.w, src.h},
                             dest: (RLRectangle){x, y, src.w, src.h},
                             origin: (RLVector2){0, 0}, 
                             rotation: 0.0f, 
                             tint: color);
                        };
                    }
                    case mu::MU_COMMAND_CLIP: mu::set_clip_rect(cmd.clip.rect);
                }
            }
        };
    }
    rl::unloadTexture(mu_font_atlas);
    rl::clearWindowState((int)rl::FLAG_WINDOW_UNDECORATED);
    rl::closeWindow();
$endif;
}

fn int playIntro(void*) 
{
    tracy::set_thread_name("intro_thread");
    introMutex.lock()!!;
    defer introMutex.unlock()!!;

    menu::stop();

    bool run = intro::play(&local_game.intro);
    if(run) 
    {
        while(local_game.intro.should_play) {
            intro::update(&local_game.intro);
            thread::sleep_ms(16);
        }
    }

     // cleanup
    intro::deinitAnimation(&local_game.intro);
    
    //local_game.main_menu.show();
    // 
    // restarts from the main menu;
    disconnect();
    
    return 0;
}

// TODO rename to set_user_settings?
fn void parse_user_settings(ConfigFile* settings, int* window_flags)
{
    if(settings == null) return;
    
    foreach(section : settings.sections)
    {
        // handle empty sections
        if(section.cmds.is_empty()) {
            log::warning(CONSOLE, "Cmd list of section %s is empty. Using defaults.", section.name, ini::SETTINGS_FILE_NAME);
            continue;
        }
        
        switch(section.name)
        {
            case "video":
                foreach(it : section.cmds)
                {
                    int        cmd_type  = it.type;
                    String     cmd_id    = it.cmd.first;
                    String     cmd_value = it.cmd.second;
                    
                    switch(cmd_type) 
                    {
                        case ini::BOOLEAN:
                            switch(cmd_id) 
                            {
                                case "developer":
                                nextcase;
                                default:
                                    log::warning(CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        case ini::INT:
                            switch(cmd_id) 
                            {
                                case "vsync":
                                    (*window_flags) |= (int)rl::FLAG_VSYNC_HINT;
                                case "fullscreen":
                                    if( try value = cmd_value.to_int()) {
                                        if(value == 1) {
                                            (*window_flags) |= (int)rl::FLAG_FULLSCREEN_MODE;
                                        } else if( value == 2) {
                                            (*window_flags) |= (int)rl::FLAG_WINDOW_UNDECORATED;
                                        }
                                    } else {
                                        log::warning(CONSOLE, "Unnable to convert value %s of cmd %s of section %s to int.", cmd_value, cmd_id, section.name);
                                    }
                                    
                                case "maxFPS":
                                    if( try value = cmd_value.to_int()) {
                                        if(value > 0) {
                                            //rl::setTargetFPS(value);
                                            r_max_fps.set(cmd_value);
                                            log::warning(FILE, "Cvar 'r_max_fps' value got changed to %s by cmd %s of section %s.", cmd_value, cmd_id, section.name);
                                        }
                                    } else {
                                        log::warning(FILE, "Unnable to convert value %s of cmd %s of section %s to int.", cmd_value, cmd_id, section.name);
                                    }
                                case "r_mode":
                                nextcase;
                                case "r_custom_width" :
                                nextcase;
                                case "r_custom_heigth":
                                nextcase;
                                case "gamma":
                                nextcase;
                                case "brightness":
                                nextcase;
                                default:
                                    log::warning(CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        case ini::FLOAT:
                            switch(cmd_id) 
                            {
                                case "unknown":
                                nextcase;
                                default:
                                    log::warning(CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        case ini::STRING:
                            switch(cmd_id) 
                            {
                                case "unknown":
                                nextcase;
                                default:
                                    log::warning(CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        default:
                            unreachable();
                    }
                }
            case "keys":
                foreach(it : section.cmds) {
                    String     cmd_id    = it.cmd.first;
                    String     cmd_value = it.cmd.second;
                    
                    assert(it.type == ini::STRING);
                    
                    switch(cmd_id) {
                        case "move_up":
                        nextcase;
                        case "move_down":
                        nextcase;
                        case "move_left" :
                        nextcase;
                        case "move_right":
                        nextcase;
                        case "quit":
                        nextcase;
                        case "editor":
                        default:
                            log::warning(CONSOLE, "action \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                    }
                }
            default:
                log::warning(CONSOLE, "Found empty section %s in ini file %s.", section.name, ini::SETTINGS_FILE_NAME);
        }
    }
}

// #endregion
