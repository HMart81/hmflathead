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
import std::io, std::thread, std::os;
import std::math;
import std::ascii;
import std::math::complex;
import std::core::mem; // for malloc/new
import std::collections::list, std::collections::map, std::collections::tuple;
import libc;
import engine::input;
import engine::tokanizer::tok; // tokanizer
import engine::filesystem::fs;
import engine::gui;
import game::intro;
import game::gui::menu;
import engine::assets_api::asset; // for the asset system
import engine::assets_api::astmng; // asset manager
import engine::sys::reader::svg;
import game::material::manager::mtrmng; // material database
//
import thirdparty::wren;
import engine::sys::script_engine::scpt; // Script Engine (based on Wren language)
//
import game::assets::sprt; // sprites
//import game::assets::part; // particles
import game::serialize::svs; // save system
import game::logic::timer;
import engine::tools::editor;
import engine::logging::lgr;
import game::actors::ent::pl;  // player module
import engine::misc; // misc code
import game::camview;
import engine::sys::cvar;
import game::files::ini @public;
import game::effects::boid;
import game::lowlevel::bounds;
// third party libraries
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui/*, thirdparty::raygui5::rgui::style::dark*/;
import thirdparty::library::xml;
import thirdparty::microui::mu;  // micro ui
import engine::physics::box2d;
import thirdparty::tracy;
import thirdparty::tsoding::fg; // flaglib
// #endregion

// #region Constants
const TRACY_ENABLE_ZONE @if($feature(TRACY_ENABLE)) = 1;

/*
   ===== Game Scale Units =====
   
   1 meter = 10 pixels
   
   NOTE(HM): 
   Minimum scale for physics objects is 10 cm, this is a hard limit 
   imposed by box2d physics engine.
*/
const DEFAULT_PIXELS_PER_METER @public @Hardcode = 10;
const String MOUSE_IMAGE_NAME          @Hardcode = "pointer.png";
const String MOUSE_POINTER_MAT         @Hardcode = "gui/pointer"; // game assets folder
const GAME_CURSOR_SCALER               @Hardcode = 0.025f;
const int MAX_ENTITY_COUNT     @public @Hardcode = 1 << 12; //int.max;

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

fn bool resValuesSafe(int w_value, int h_value) @inline {
    if(w_value < SCREEN_RES[0].w || w_value > SCREEN_RES[SCREEN_RES.len - 1].w) return false;
    if(h_value < SCREEN_RES[0].h || h_value > SCREEN_RES[SCREEN_RES.len - 1].h) return false;
    
    return true;
}

fn int getResolutionIndexFromValues(int w, int h) @local @inline
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
Thread assetsLoadingThread;
Mutex  assetsLoadingMutex;
//
Thread introThread;
Mutex  introMutex;
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
const int MAX_VERSION                = 0;
const int MIN_VERSION                = 0;
const int BABY_VERSION               = 3;
const String GAME_NAME     @Hardcode = "hmflathead"; // TODO(HM) give me a final name!!!!
const String GAME_SUB_NAME @Hardcode = "engine"; // NOTE(HM) optional...
//
// #endregion Constants

// #region Alias
// DOC(HM) Alias definitions, always follow the same naming rules of the thing they are alising.
// If alising a type the alias name, should start uppercase, if alising a function, it should start lowercase, 
// if alising a Constant the alias also needs to be all caps, etc.

alias RColor         @public = rl::Color;
alias RShader        @public = rl::Shader;
alias StringTuple    @public = Tuple{String, String};
alias IniFileCMDList = List{StringTuple*};
alias asstManager    @public= astmng::assetManager;

// #endregion Alias

// #region Cvars
Cvar developer      @public = { "developer"     , CvarType.BOOLEAN, "0",    "enables developer mode"};
Cvar editor         @public = { "editor"        , CvarType.BOOLEAN, "0",    "enables the game editor (requires developer mode)"};
Cvar r_mode         @public = { "r_mode"        , CvarType.INT,     "-1",   "window resolution index 0.."};
Cvar r_showFPS      @public = { "r_showFPS"     , CvarType.BOOLEAN, "1",    "draws framerate on screen"};
Cvar r_fullscreen   @public = { "r_fullscreen"  , CvarType.INT,     "-1",   "screen mode 0 = window, 1 = borderless, 2 = dedicated, -1 = ini file setting"};
Cvar fs_base        @public = { "fs_base"       , CvarType.STRING,  "data", "default game base folder"};
Cvar fs_mod_name    @public = { "fs_mod_name"   , CvarType.STRING,  "",     "folder name of mod to run"};
Cvar fs_mod_base    @public = { "fs_mod_base"   , CvarType.STRING,  "",     "folder name for custom database of running mod"};
Cvar db_drawPhysics @public = { "db_drawPhysics", CvarType.BOOLEAN, "1",    "show debug visualization for world physics" };
// TODO(HM) disable editor cvar, when not used anymore
//Cvar r_window_resizable @public = { "r_window_resizable", CvarType.BOOLEAN,  "0",   "makes window resizable, window mode only."};

fn void register_cvars() @local 
{
    cvar::@register(&developer);
    cvar::@register(&editor);
    cvar::@register(&r_mode);
    cvar::@register(&r_showFPS);
    cvar::@register(&r_fullscreen);
    cvar::@register(&fs_base);
    cvar::@register(&fs_mod_name);
    cvar::@register(&fs_mod_base);
    cvar::@register(&db_drawPhysics);
    //cvar::@register(r_window_resizable);
    
    //if(cvar::cvars.len()) foreach(cv: cvar::cvars) {lgr::info(Where.CONSOLE, cv.name);}
}

fn void register_modulo_cvars() @local {
    register_cvars(); // main
    gui::register_cvars();
    intro::register_cvars();
    lgr::register_cvars();
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

// The type of menu gui set right now
enum EscReply {
   ESC_IGNORE,	// do nothing
   ESC_MAIN,	// start main menu GUI
   ESC_GUI		// set an explicit GUI
}

const usz GAME_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator gameArena @public;

struct Game (SaveSystemInterface) @local 
{
    bool should_update_entities;
    bool system_cursor_enabled;
    //int numEntitiesToDeactivate; // todo
    bool should_quit;
    bool msgbox_showing;
    bool is_modded_game; // is the game running a mod?
    
    
    IntroAnimation intro;
    bool intro_playing;
    
    // menus
    gui::Desktop* guiActive; // to handle all guis
    gui::Desktop* main_menu;
    //

    // microui
    mu::MU_Context* mu_ctx @if($feature(MICROUI_ENABLE)); // microui context, used for the micro ui system
    bool show_microui_test_frames @if($feature(MICROUI_ENABLE));

    // script engine
    ScriptEngine script_eng;

    GameMode mode;

    // ingame editor
    Editor editor;
    
    // defaults
    // required default assets
    Texture2D default_texture;
    Texture2D tex_white;
    Texture2D tex_black;
    Texture2D tex_gray;
    
    Shader    default_shader;
    Shader*   current_global_shader;
    Sound     default_sound;
    Music     default_music;
    Font      default_font;
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    Font* candara_font;
    Font* candara_light_font;
    Font* lucida_font;
    Font* trojan_pro_font;
    //
    
    String[] cursors;
    Sprite mouse_cursor;
    
    Player* main_player;
    pl::PersistentInfo playerPersistentInfo; // to save any info that the player carries along for each level
    RenderView view;

    
    struct screen {
        int id; // monitor id (index + 1)
        int index; // monitor index
        int  w;
        int  h;
        struct state {
            bool window;
            bool fullscreen;
            bool borderless;
        }
        Win32_HWND handle @if(env::WIN32); // window handle, used for win32 specific stuff
        bool vsync_hint;
        int  displayHz;
        int  multiSamples; // MSAA
    }

    List{Entity*} entityList;
    List{Sprite*} sprites;
    BoidManager boidManager1;
    
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
    
    float time_sec;
    int   time_ms;
    float dt;
    bool showMessageBox;
    int last_key_pressed;
    
    timer::Timer testTimer;
    //ParticleSpawner particleSpawner1;
}

Game local_game @local; // global game singleton
Game* gpGame @public = &local_game;

// ***********************
// #endregion game manager
// ***********************

fn void Game.freeGameEntities(&self) @inline {
    if(int count = (int)self.entityList.len()) {
        foreach(&it: self.entityList) if(it) (*it).kill();
        self.entityList.free();
        lgr::info(Where.FILE, "['%s'] Entities were cleared!", count);
        //lgr::info(Where.FILE,  "Done.");
    }
}

fn void Game.save(&self, SaveFile* file) @dynamic {
    svs::writeBool(file, self.should_update_entities);
    svs::writeBool(file, self.system_cursor_enabled);
    svs::writeBool(file, self.should_quit);
    svs::writeBool(file, self.msgbox_showing);
    svs::writeBool(file, self.is_modded_game);
    self.intro.save(file);
    svs::writeInt(file, self.mode.ordinal);
    svs::writeTexture2D(file, &self.default_texture);
    svs::writeShader(file, &self.default_shader);
    // should I save pointers!?
    //Shader*   current_global_shader;
    svs::writeSound(file, &self.default_sound);
    svs::writeMusic(file, &self.default_music);
    svs::writeFont(file,  &self.default_font);
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    //Font*  candara_font;
    //Font*  candara_light_font;
    //Font*  lucida_font;
    //Font*  trojan_pro_font;
    //
    
    svs::write(file, &self.cursors, self.cursors.len);
    self.mouse_cursor.save(file);
    
    //Player* main_player;
    self.playerPersistentInfo.save(file); // to save any info that the player carries along for each level
    self.view.save(file);
    
    svs::write(file, &self.screen, $sizeof(self.screen));
    svs::write(file, &self.entityList, $sizeof(self.entityList));
    svs::write(file, &self.sprites, $sizeof(self.sprites));
    self.boidManager1.save(file);
    
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
    self.testTimer.save(file);
}

fn void Game.reload(&self, SaveFile* file) @dynamic {
    svs::readBool(file, &self.should_update_entities);
    svs::readBool(file, &self.system_cursor_enabled);
    svs::readBool(file, &self.should_quit);
    svs::readBool(file, &self.msgbox_showing);
    svs::readBool(file, &self.is_modded_game);
    self.intro.reload(file);
    svs::readInt(file, &self.mode.ordinal);
    svs::readTexture2D(file, &self.default_texture);
    /*
    svs::readShader(file, &self.default_shader);
    // how to read pointers!?
    //Shader*   current_global_shader;
    svs::readSound(file, &self.default_sound);
    svs::readMusic(file, &self.default_music);
    svs::readFont(file,  &self.default_font);
    //
    
    // game fonts TODO(HM) We should chose only 2 for the final game...
    //Font*  candara_font;
    //Font*  candara_light_font;
    //Font*  lucida_font;
    //Font*  trojan_pro_font;
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

fn Shader getDefaultShaderCopy() @inline @public {
    return local_game.default_shader;
}

fn Shader* getDefaultShader() @inline @public {
    return &local_game.default_shader;
}

fn Shader* getCurrentGlobalShader() @inline @public {
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

fn bool Game.isPointInsideScreenView(&self, Vector2 point) {
    int w, h;
    w = self.screen.w;
    h = self.screen.h;
    
    Rectangle rec = {
    .x = 0,
    .y = 0,
    .width  = w,
    .height = h
    };
    
    return rl::checkCollisionPointRec(point, rec);
}

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
        lgr::fatal(Where.FILE, "Required asset: images//default.png failed to load!");
        return MISSING_REQUIRED_ASSET?;
    }
    
    Image white = rl::genImageColor(32, 32, rl::WHITE);
    self.tex_white = rl::loadTextureFromImage(white);
    rl::unloadImage(white);
    
    Image black = rl::genImageColor(32, 32, rl::BLACK);
    self.tex_black = rl::loadTextureFromImage(black);
    rl::unloadImage(black);
    
    Image gray = rl::genImageColor(32, 32, rl::GRAY);
    self.tex_gray = rl::loadTextureFromImage(gray);
    rl::unloadImage(gray);
    
    // get required default game shader
    /*self.default_shader = rl::loadShader(
        self.app_base_folder.tconcat("shaders//default.vs").zstr_tcopy(),
        self.app_base_folder.tconcat("shaders//default.fs").zstr_tcopy()
    );*/
    self.default_shader = misc::loadShader(
        self.app_base_folder.tconcat("shaders//default.vs"),
        self.app_base_folder.tconcat("shaders//default.fs")
    );
    if(rl::isShaderValid(self.default_shader) == false) {
        lgr::fatal(Where.FILE, "Required default shader not found in folder %s!", self.app_base_folder.tconcat("//shaders"));
        return MISSING_REQUIRED_ASSET?;
    }
    
    /*int test_tex_loc = rl::getShaderLocation(self.default_shader, "texture0");
    rl::setShaderValue(
        local_game.default_shader, 
        test_tex_loc, 
        &local_game.default_texture,
        ShdUniTyp.SAMPLER2D);*/
    self.current_global_shader = &self.default_shader;
    //self.current_global_shader.locs[ShdLocInd.MAP_ALBEDO] = test_tex_loc;
    //
        
    // load required default sound
    self.default_sound = rl::loadSound(self.app_base_folder.tconcat("sounds//default.wav").zstr_tcopy());
    if(rl::isSoundValid(self.default_sound)) {
        //$if $feature(_DEBUG):
            //if(rl::isAudioDeviceReady()) rl::playSound(self.default_sound);
        //$endif
    } else {
        lgr::fatal(Where.FILE, "Required default asset: \"sounds/default.wav\" failed to load!");
        return MISSING_REQUIRED_ASSET?;
    }
    
    // load required default music
    self.default_music = rl::loadMusicStream(self.app_base_folder.tconcat("music//default.mp3").zstr_tcopy());
    if(rl::isMusicValid(self.default_music) == false) {
        lgr::fatal(Where.FILE, "Required default asset: \"music/default.mp3\" failed to load!");
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
        lgr::info(Where.FILE, "['%s'] sprites were cleared!", count);
    }
    self.view.deinit();
    self.boidManager1.release();
    self.editor.deinit();
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

// #region Game Custom Cursor functions

fn void init_game_cursor() @inline
{
    local_game.mouse_cursor.initV(
        {0,0},
        {GAME_CURSOR_SCALER*gpGame.screen.h, GAME_CURSOR_SCALER*gpGame.screen.h},
        rl::WHITE,
        SpriteKind.CURSOR,
        MOUSE_POINTER_MAT
    );
}

// is this really needed now that i have a asset manager? 
fn void deinit_game_cursor() @inline {
    hide_game_cursor();
}

fn void set_game_cursor_size(int w, int h) @inline {
    local_game.mouse_cursor.setSize(w, h);
}

fn Vec2f getGameCursorSize() @public @inline => local_game.mouse_cursor.getSize();

fn void update_game_cursor(int screen_w, int screen_h) @public {

    // todo enable this code
    if(game_cursor_visible() == false) return;
    
    int x = rl::getMouseX(); // in world space
    int y = rl::getMouseY(); // in world space
    
    // prevent the cursor from going out the screen bounds
    if (x < 0) x = 0;
    if (x > screen_w) x = screen_w;
    if (y < 0) y = 0;
    if (y > screen_h) y = screen_h;
    //
    
    // update position
    //local_game.mouse_cursor.setPositionV({x, y});
    local_game.mouse_cursor.setPositionV(rl::getWorldToScreen2D({x, y}, local_game.view.camera).toVec2f());
    
    // update size
    // TODO do a better mouse cursor size dependent on screen size!!
    int cursor_h            = (int)local_game.mouse_cursor.getSizeY();
    int desired_cursor_size = (int)math::floor((GAME_CURSOR_SCALER * screen_h));
    if(cursor_h > desired_cursor_size) {
        set_game_cursor_size(desired_cursor_size, desired_cursor_size);
    }
}

fn void show_game_cursor() @public @inline {
    if(local_game.mouse_cursor.hidden()) local_game.mouse_cursor.show();
}

// NOTE(HM) only hides the cursor doesn't disable it, will still move behind the window.
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

fn EscReply handleESC( Desktop** gui ) 
{
	Player* player = local_game.getLocalPlayer();
	if ( player ) {
		if ( player.handleESC() ) {
			return EscReply.ESC_IGNORE;
		} else {
			return EscReply.ESC_MAIN;
		}
	}
	return EscReply.ESC_MAIN;
}

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
   $endif
    
    // handle ESC key press
    if (!local_game.guiActive && rl::isKeyPressed(rl::KEY_ESCAPE) &&
        !rl::isKeyDown(rl::KEY_LEFT_SHIFT) && !rl::isKeyDown(rl::KEY_RIGHT_SHIFT)) 
    {
		Desktop* gui;
        EscReply op = main::handleESC( &gui );
        if(op == ESC_GUI) {
            menu::setGUI(gui);
        } else if(op == ESC_MAIN) {
            menu::start(local_game.main_menu);
        } else {
            menu::setGUI(null); // disable any gui
        }
	}

$if $feature(MICROUI_ENABLE):
    // #region MicroUI initialization
    if(local_game.mu_ctx != null) 
    {
        float scroll_speed = -30.0f; // scroll speed for mouse wheel.
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
            //lgr::info(Where.CONSOLE, "Action BECAME triggered!!!!!!");
        }
    }
    /*
    if(input::gpManager.getActionByName("quit").fnDoubleTriggered(0.250f)) {
        lgr::info(Where.CONSOLE, "Quit Action DOUBLE triggered!!!!!!");
    }
    
    if(input::gpManager.getActionByName("quit").wasTriggered()) {
        lgr::info(Where.CONSOLE, "Quit Action WAS triggered!!!!!!");
    }*/
    
    if(rl::getKeyPressed()) {
        local_game.last_key_pressed = rl::getKeyPressed();
    }
}

fn void gameUpdate() @local 
{
    misc::@profile_zone("Game Update")
    {
    tracy::@zoneN("gameUpdate", 1)
    {
        // make game run at lower rate in case window loses focus
        if(rl::isWindowFocused())
        {
            if(local_game.screen.displayHz == 15)
            {
                local_game.screen.displayHz = rl::getMonitorRefreshRate(local_game.screen.id);
                rl::setTargetFPS(local_game.screen.displayHz);
            }
        }
        else if(local_game.screen.displayHz != 15)
        {
            $if !$feature(TRACY_ENABLE):
                local_game.screen.displayHz = 15;
                rl::setTargetFPS(local_game.screen.displayHz);
            $endif
        }
        
        gameHandleGeneralControls();

        if(editor.getBool() && local_game.editor.isOpened()) {
            local_game.editor.update();
        }
        
        // physics engine
        if(local_game.pause_phys_simulation == false) {
			//float deltaTime = rl::getFrameTime();
			box2d::world_Step(local_game.physWorldId, local_game.phys_time_step, local_game.phys_substep_count);
        }
        //
        
        // updates all fullscreen menus state like the main menu
        gui::gpDeskManager.update();
        
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
        local_game.boidManager1.update(rl::getScreenWidth(), rl::getScreenHeight(), local_game.dt);
        
        if(local_game.testTimer.alive()) {
            io::printfn("Timer time = %s!!!", local_game.testTimer.lifetime);
        } else { 
            //io::printfn("Timer run out press F2 to start again!!!");
            if (rgui::button((Rectangle) { 24, 24, 120, 30 }, "#191#Show Message")) local_game.showMessageBox = true;

            if (local_game.showMessageBox)
            {
                int result = rgui::messageBox((Rectangle) { 85, 70, 250, 100 },
                    "#191#Message Box", "Hi! This is a message!", "Nice;Cool");

                if (result >= 0) local_game.showMessageBox = false;
            }
        }
        
        // Todo handle more music but only one music should play at the same time...
        if(rl::isMusicValid(local_game.default_music)) {
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
            // remove dead entities
            foreach(int i, it : local_game.entityList) {
                if(it.alive == false) {
                    local_game.entityList.remove_at(i);
                    lgr::warning(Where.CONSOLE, "Entity '%s' was killed\n", it.name);
                }
            }
            
            // entity thinking
            foreach(usz i, ent: local_game.entityList) {
                if(i == 0 && ent.type == Player.typeid) {
                    assert(ent != null);
                    // Need to cast Entity* to Player* to call player think not Entity think...
                    ((Player*)ent).think(dt: local_game.dt);
                } else {
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
    }; // tracy
    }; // profile_zone
}

fn void gameReset() @local {
// for future
}

fn void drawGameVersion(int screenWidth, int screenHeight) @inline @local
{
    // draw game version
        const VERSION_FONT_SCALE = 12;
        ZString game_version     = string::tformat_zstr("version: (%s, %s, %s)", MAX_VERSION, MIN_VERSION, BABY_VERSION);
        int version_text_len     = rl::measureText(game_version, VERSION_FONT_SCALE);
        rl::drawText(
            game_version,
            (int)(screenWidth - (2.0f * version_text_len)), //(float)(font_w * libc::strlen(game_version))),
            (int)0.25f*screenHeight,
            VERSION_FONT_SCALE,
            {127, 127, 255, 255} // @Hardcode color
        );
}

fn void drawWorkInProgressMessage(int screen_w, int screen_h) @local 
{
    const RColor COLOR @Hardcode = {223, 196, 125, 127};
    Font* font = local_game.candara_font;
    if(!rl::isFontValid(*font))  font = &local_game.default_font;
    
    //int font_w = (int)font.recs.width;

    //String message   = string::tformat_zstr("Total entities alive: None");
    String message    = "WORK IN PROGRESS";
    int text_len      = rl::measureText(message.zstr_tcopy(), 12);
    int screen_middle = (int)math::floor(0.5f*screen_w);
    //int x = (int)(0.65f * ((float)(screen_middle + (font_w * message.len))));
    int x = (int)(0.60f * ((float)(screen_middle + text_len)));
    int y = (int)math::floor(0.01f*screen_h);
    rl::drawText(string::tformat_zstr("%s (Raylib %s)", message, rl::VERSION), x, y, 12, COLOR);
    //rl::drawTextEx(*font, string::tformat_zstr("%s (Raylib %s)", message, rl::VERSION), {x, y}, 12, 1.0f, rl::RED);
}

fn void drawGameOnScreenDebugInfo(int screen_w, int screen_h) @local
{
    if(gui::editor_enabled()) return;
    
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
    const rl::Color* COLOR = &rl::YELLOW;
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
    misc::@profile_zone("Game Draw", false)
    {
        local_game.view.renderToFBO();
        
        // Main Basic rendering
        rl::beginDrawing();
        
        rl::clearBackground({0x18, 0x18, 0x18, 0xFF});
        //rl::clearBackground(*(Color*)&&((uint[1]){ 0x181818FF }));
        
$if $feature(MICROUI_ENABLE):
        mu::process_frames(local_game.mu_ctx, rl::getFrameTime());

        if(local_game.show_microui_test_frames && mu::open_frames.len() == 0) {
            local_game.show_microui_test_frames = false; // disable microui focus if no frames are open
        }
$endif
        // draw the view FBO's
        if(rl::isShaderValid(*local_game.current_global_shader)) 
        {
            rl::@shaderMode(*local_game.current_global_shader) 
            {
                local_game.view.draw();
            };
        } 
        else 
        {
            // render using raylib default shader
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
        
        // this is where input pooling and swapping buffers happens
        rl::endDrawing();
        tracy::frameMark();
        
        // NOTE(HM) 1)
        // drawing after the frame buffer is swapped/updated
        // NOTE(HM) 2)
        // Not sure for what this is usefull, but I saw this when studing the Penumbra engine
        gameOnPostBufferSwap();
    }; // profile_zone
}

// NOTE(HM) Any code here draws before the game user interface
fn void gameOnPostSceneDraw(int screenWidth, int screenHeight) @local 
{
$if $feature(MICROUI_ENABLE) :
    MU_Command * cmd = null;
    while (local_game.mu_ctx.next_command(&cmd))
    {
      switch (cmd.type)
      {
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

// NOTE(HM) Any code here draws on top of the game user interface
// good place to put debug code...
fn void gameOnPostGUIDraw(int screenWidth, int screenHeight) @public 
{
    // draw game fps
    if(r_showFPS.getBool()) {
        rl::drawFPS((int)(0.93f * screenWidth), (int)(0.02f * screenHeight));
    }
    
    if(developer.getBool())
    {
        drawGameVersion(screenWidth, screenHeight);
        
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
    
    gui::gpDeskManager.draw(screenWidth, screenHeight);
    
    if(local_game.intro_playing) {
        intro::drawIntroAnimation(&local_game.intro, screenWidth, screenHeight);
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
    // TODO
}

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
            lgr::g_log.set("true"); 
        case "editor":
            editor.set("1");
        case "window": nextcase;
        case "w":      nextcase;
        case "win":
            int value = r_fullscreen.getInt();
            if(value > 0) {
                r_fullscreen.set("0");
                lgr::warning(Where.CONSOLE, "cmdline arg '%s' is overriding the value set by r_fullscreen.", cmd); 
            } else {
                lgr::warning(Where.CONSOLE, "cmdline arg '%s' is not doing anything as r_fullscreen is already zero.", cmd); 
            }
        default:
            lgr::warning(Where.CONSOLE, "Invalid cmdline argument '%s'!", cmd);
    }
}
/*
NOTE(HM) 
The first argument in a cmdline, is just the path to the executable, 
so if there's only one argument, there's no need to run handle_cmdline().
Also cmdline arguments require a full game restart, this may change, 
if and when I create a game console...
*/
fn void handle_cmdline(String[] args)
{
    if(args.len == 0 || args.len == 1) return;
    
    lgr::info(Where.FILE, "Handling cmd line args: %s\n", args);

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
                    lgr::warning(Where.CONSOLE, "rogue minus sign found in value of cmd \"%s\".", cmd_arg);
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
                    lgr::warning(Where.CONSOLE, "malformed string assigned to \"%s\", strings most be defined between two \"\".", arg, cmd_arg);
                    continue; // skip to next argument
                }
            case ascii::is_alpha(arg[0]):
                lgr::warning(Where.CONSOLE, "malformed string assigned to \"%s\", strings most be defined between two \"\".", arg, cmd_arg);
                continue;
            default:
                lgr::warning(Where.CONSOLE, "invalid value '%s' assigned to cmd '%s'.", arg, cmd_arg);
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
                        lgr::warning(Where.CONSOLE, "value %s in cmdline has a comma seperator.\n   -That is not supported for numbers, please use dot instead.", arg);
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
                        lgr::warning(Where.CONSOLE, "Unnable to convert value \"%s\" of cmdline arg \"%s\" to float value!", arg, cmd_arg);
                    }
                } else {
                    if(try value = arg.to_int()) 
                    {
                        ivalue = value;
                    } else {
                        lgr::warning(Where.CONSOLE, "Unnable to convert value \"%s\" of cmdline arg \"%s\" to integer value!", arg, cmd_arg);
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
                                lgr::g_log.set(arg);
                            } else { // clamp it
                                lgr::g_log.set("4");
                            }
                        } else {
                            lgr::g_log.set("0");
                        } 
                    case "r_mode":
                        if(ivalue >= 0 && ivalue <= SCREEN_RES.len - 1) 
                        {
                            r_mode.set(arg);
                        } else {
                            lgr::warning(Where.CONSOLE, "Ignoring cmdline arg '%s' invalid resolution index, expected '0..%s' found \"%s\".", cmd_arg, SCREEN_RES.len - 1, arg);
                        }
                    case "r_fullscreen":
                        if(ivalue >= 0 && ivalue <= 2) 
                        {
                            r_fullscreen.set(arg);
                        } else {
                            lgr::warning(Where.CONSOLE, "Ignoring cmdline arg '%s' invalid value, should be from '0..2'.", cmd_arg); 
                        }
                    default:
                        lgr::warning(Where.CONSOLE, "cmdline arg '%s' with value = %s is still not handled.", cmd_arg, arg);
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
                    lgr::warning(Where.CONSOLE, "cmdline arg '%s' with string = %s is still not handled.", cmd_arg, arg);
            }
        }
    }
}

// #endregion ARGS HANDLING ******************



/* This is where game execution begins */
fn void? gameOnStart(String[]* args) @local 
{
    local_game.mode = STARTING;
    String game_version = string::tformat("\"%s.%s.%s\"", MAX_VERSION, MIN_VERSION, BABY_VERSION);
    lgr::info(Where.FILE, "Game Version: %s\n", game_version);
    lgr::info(Where.FILE, "-------- THE <toname> ENGINE LOG ------------");
    
    // Handle cmdline arguments if any.
$if $feature(TSODING_FLAG):
    List{ZString} argv;
    defer argv.clear();
    for(int i = 0; i < args.len; i++) {
        argv.push((*args)[i].zstr_tcopy());
    }

    if (!fg::flag_parse(args.len, argv.to_tarray())) {
        //usage(stderr);
        fg::flag_print_error(&&io::stderr());
        return GAME_START_FAILED?;
        //exit(1);
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

    lgr::info(Where.FILE, "Initializing game:");
    lgr::info(Where.FILE, "---------------------------------------------");
    
    // TODO load the user.ini at this time?
    
// #region Paths/Folders Setup
    lgr::info(Where.FILE, "Registering game paths:");
    lgr::info(Where.FILE, "---------------------------------------------");
    String app_exe_path = (*args)[0];
    
    // Set the game name
    local_game.app_name = GAME_NAME;
    if(local_game.app_name != "")
    {
        if(GAME_SUB_NAME.len > 0)
        {
            local_game.app_name = local_game.app_name.tconcat(GAME_SUB_NAME);
        }
    } else {
        // take the name from the exe path
        local_game.app_name = fs::getFileNameWithoutExt(app_exe_path).tconcat("_app");
    }
    
    // Detect and Setup the work directory folder,
    // NOTE(HM) app_exe_path has the working dir encoded on it, but also includes the exe name, 
    //          rl::getWorkingDirectory() removes the name and gets the required path.
    // This also saves original work dir, in case a mod is being used.
    local_game.app_default_workdir = fs::getWorkingDirectory().tconcat("\\");
    if(fs::directoryExists(local_game.app_default_workdir)) 
    {
        lgr::info(Where.FILE, "\tWorking from default Dir: %s", local_game.app_default_workdir);
    } else { 
        return INVALID_WORK_DIR?; // will this ever happen?
    }
    // Detect and Setup the base folder where required game assets/data live.
    local_game.app_default_base_folder = local_game.app_default_workdir.tconcat(fs_base.getString()).tconcat("\\");
    
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
            lgr::warning(Where.FILE, "mod name: \"%s\" seems to be very small are you sure that is correct?", mod_name);
        }

        mods_dir = local_game.app_default_workdir.tconcat("mods");
        if(fs::directoryExists(mods_dir)) // look inside
        {
            mod_work_dir = mods_dir.tconcat("\\").tconcat(mod_name).tconcat("\\");
            // make sure mod work dir exists as well
            if(fs::directoryExists(mod_work_dir))
            {
                // set the game work dir to the mod work dir
                local_game.app_work_dir = mod_work_dir;
                // now set the game base dir for the mod base dir
                mod_base_folder = mod_work_dir.tconcat(fs_mod_base.getString()).tconcat("\\");
                // also make sure the mod base dir exists
                if(fs::directoryExists(mod_base_folder))
                {
                    local_game.app_base_folder = mod_base_folder;
                } else { 
                    lgr::warning(Where.FILE, "base directory for mod \"%s\" is missing cannot run mod!", mod_name);
                    mod_handling_failed = true;
                }
            } else { 
                lgr::warning(Where.FILE, "Work directory for mod \"%s\" is missing cannot run mod!", mod_name);
                mod_handling_failed = true;
            }
        } else {
            lgr::warning(Where.FILE, "Mod %s has to be run from inside folder \"mods\" but none was found at: %s", mod_name, local_game.app_default_workdir);
            mod_handling_failed = true;
        }

        if(mod_handling_failed)
        {
            lgr::warning(Where.FILE, "Mod handling failed, using default work dir: %s", local_game.app_default_workdir);
            local_game.app_work_dir    = local_game.app_default_workdir;
            local_game.app_base_folder = local_game.app_default_base_folder;
        }
    }
    
    // make sure required work dir exists
    if(fs::directoryExists(local_game.app_work_dir)) 
    {
        if(local_game.app_work_dir != local_game.app_default_workdir) 
        {
            lgr::info(Where.FILE,  "\tWorking now from Dir: %s", local_game.app_work_dir);
        }
    } else {
        return INVALID_WORK_DIR?;
    }
    
    // make sure required base folder exists
    if(fs::directoryExists(local_game.app_base_folder)) 
    {
        lgr::info(Where.FILE,  "\tBase Dir set to: %s", local_game.app_base_folder);
    } 
    else
    {
        if(local_game.is_modded_game) 
        {
            lgr::error(Where.FILE,`Required base folder inside %s not found!\n
                       A non-empty folder called '%s' (case sensitive) most exist!`, 
                       local_game.app_work_dir, 
                       (fs_mod_base.getString().len > 0) ? fs_mod_base.getString() : fs_base.getString(), 
                       local_game.app_name);
        } else {
            lgr::error(Where.FILE,`Required base folder inside %s not found!\n
                       A non-empty folder called '%s' (case sensitive) most exist.\n
                       Please reinstall game.`, local_game.app_work_dir, fs_base.getString(), local_game.app_name);
        }
        return NO_DATA_FOLDER?;
    }
    
    // get the home folder to save necessary game data
    local_game.app_save_folder = win32::getSystemSpecialPath(win32::SystemPath.PERSONAL);
    if(local_game.app_save_folder.len > 0)
    {
        // NOTE(HM) append the desired final folder 
        // and look in the OS user save directory, to see if folder is already there 
        // if not create it.
        local_game.app_save_folder = local_game.app_save_folder.tconcat("\\").tconcat(local_game.app_name);
        if(fs::directoryExists(local_game.app_save_folder)) 
        {
            lgr::info(Where.FILE, "\tUser Save folder set to: %s", local_game.app_save_folder);
        } else { // create it
            //Path? save_path = path::temp_new(save_folder)!;
            //bool? sucess    = path::mkdir(save_path);
            bool? sucess    = fs::makeDirectory(local_game.app_save_folder);
            if(catch excuse = sucess) 
            {
                lgr::warning(Where.FILE,"Failed to create user folder %s inside %s with excuse: %s", 
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
            lgr::warning(Where.FILE, "Failed to write to registry key: %s", reg_key);
            //return REGISTRY_WRITE_FAILED?;
        }
    }
    $endif // $if $defined(env::WIN32)

    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion


// #region InitRaylib library stuff
    
    // init rand count generator for rl
    rl::setRandomSeed(69);
    
    // window flags
    int window_flags = 0; // special windows flags for the rl window handling
    
    // support modern high dpi monitors
    window_flags |= (int)rl::FLAG_WINDOW_HIGHDPI;
    
    // TODO(HM)
    // Create a console here for error displaying...
    // Display help text in the console
    //  if any of char* helpArgs[] = { "--help", "-h", "-help", "-?", "/?" }; cvar is provided
    // Print engine version in the console

// #region Ini file handling
    lgr::info(Where.FILE, "Loading settings file:");
    lgr::info(Where.FILE, "---------------------------------------------");
    String ini_file_path = local_game.app_base_folder.tconcat(ini::SETTINGS_FILE_NAME);
    bool settings_file_missing = fs::fileExists(ini_file_path) == false;
    if (settings_file_missing) // create it with default settings
    {
        ini::create_default_settings_file(ini_file_path);
    }
    ini::Config settings_file;
    bool? settings_load_sucess = settings_file.load(ini_file_path, false);
    //ini::Config*? settings_file = ini::load(ini_file_path, false); //ini::load(SETTINGS_FILE_NAME);
    if( catch excuse = settings_load_sucess) {
        lgr::warning(Where.FILE, "Failed to load %s file with excuse: %s", ini_file_path, excuse);
        return excuse?;
    }
    defer if(settings_load_sucess) ini::unload(&settings_file);

    lgr::info(Where.FILE, "Settings file loaded: %s", ini_file_path);
    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion Ini file handling

    // log the amount of screen resolutions and their Mode
    lgr::info(Where.FILE, "Total video modes : %d", SCREEN_RES.len);
    lgr::info(Where.FILE, "Enumerating rendering video modes:");
    foreach(res: SCREEN_RES) {
        lgr::info(Where.FILE, "\t%s", res.str);
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
            lgr::warning(Where.FILE, "Array index overflow, r_mode = %d is not valid, setting to default: %d", res_index, DEFAULT_SCREEN_INDEX);
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
                lgr::warning(Where.FILE, "Custom resolution %dx%d not found in the list of video modes, using it as is.", w_value, h_value);
                local_game.screen.w = w_value;
                local_game.screen.h = h_value;
            }
            else 
            {
                local_game.screen.w = SCREEN_RES[res_index].w;
                local_game.screen.h = SCREEN_RES[res_index].h;
                lgr::info(Where.FILE, "Custom resolution %dx%d found in the list of video modes, using it.", 
                          local_game.screen.w, local_game.screen.h);
            }
        }
    }
    
    // at this point we should have a valid screen resolution
    if(res_index == -1 || local_game.screen.w <= 0 || local_game.screen.h <= 0) 
    {
        lgr::error(Where.FILE, "Invalid screen resolution %dx%d, cannot continue!", local_game.screen.w, local_game.screen.h);
        return INVALID_SCREEN_RESOLUTION?;
    }
    
    lgr::info(Where.FILE,  "Video mode set -> %s", SCREEN_RES[res_index].str);

    lgr::info(Where.FILE, "---------------------------------------------\n");
    lgr::info(Where.FILE, "Window settings:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // Vertical sync (this is a hint so may or may not apply...)
    if(try settings_file.getBool("vsync")) 
    {
        window_flags |= (int)rl::FLAG_VSYNC_HINT;
        local_game.screen.vsync_hint = true;
        lgr::info(Where.FILE, "VSync hint enabled. (This is a hint, not a guarantee!)");
    }
    
    // NOTE(HM) cvar r_fullscreen has top priority
    int fullscreen_choice = r_fullscreen.getInt();
    // NOTE(HM) if cvar was not set, see if the config file is overriding the value
    if(fullscreen_choice == -1) fullscreen_choice = settings_file.getInt("r_fullscreen")!;
    
    // prevent under or overflow
    if(fullscreen_choice < -1 || fullscreen_choice > 2) 
    {
        int choice = fullscreen_choice;
        lgr::warning(Where.FILE, "invalid value: %d for r_fullscreen, using default. Valid values are '-1, 0, 1, 2'", choice);
        if(choice < -1) {
            fullscreen_choice = -1;
        } else {
            fullscreen_choice = 2;
        }
    }
    
    switch(fullscreen_choice)
    {
        case 1:
            window_flags |= (int)rl::FLAG_FULLSCREEN_MODE;
            local_game.screen.state.fullscreen = true;
        case 2:
            window_flags |= (int)rl::FLAG_WINDOW_UNDECORATED;
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
                window_flags |= (int)rl::FLAG_MSAA_4X_HINT;
                local_game.screen.multiSamples = msaa_samples;
                lgr::info(Where.FILE, "4x MSAA hint enabled (as a hint, may not apply).");
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
lgr::info(Where.FILE, "---------------------------------------------\n");

// #region Window initialization
    lgr::info(Where.FILE, "Initializing window:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // set/apply the final window flags
    rl::setConfigFlags((ConfigFlag)window_flags);
    
    int screenWidth     = local_game.screen.w;
    int screenHeight    = local_game.screen.h;
    ZString window_name = string::tformat_zstr("%s version: (%s, %s, %s)", local_game.app_name.zstr_tcopy(), MAX_VERSION, MIN_VERSION, BABY_VERSION);
    
    //===============================//
    //========= Init Window ======== // 
    rl::initWindow(screenWidth, screenHeight, window_name);
    //============================== //
    
    if(rl::isWindowReady() == false) 
    {
        lgr::fatal(Where.FILE, "Failed to init rl window and OpenGL context!");
        return WINDOW_INIT_FAILED?;
    } else {
        lgr::info(Where.FILE, "Window initialized successfully.");

        if(local_game.screen.state.fullscreen == true)
        {
            lgr::info(Where.FILE,  "Game window set to Real/Dedicated Fullscreen mode.");
        }
        else if(local_game.screen.state.borderless == true)
        {
            lgr::info(Where.FILE,  "Game window set to Borderless fullscreen mode.");
        }
        else if(local_game.screen.state.window == true)
        {
            lgr::info(Where.FILE,  "Game window set to Windowed mode.");
        }
        else
        {
            unreachable("Game window is not set to any known state, this should never happen!");
            //return WINDOW_INIT_FAILED?;
        }
    }

$if env::WIN32:
    Win32_HWND window_handle = (Win32_HWND)rl::getWindowHandle();
    if(window_handle == null) 
    {
        lgr::fatal(Where.FILE, "Failed to get window handle!");
        //return WINDOW_HANDLE_FAILED?;
    } else {
        lgr::info(Where.FILE, "Window handle obtained successfully.");
        local_game.screen.handle = window_handle;
    }

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
    local_game.time_ms  = misc::sec2ms(local_game.time_sec);
    lgr::info(Where.FILE, "---------------------------------------------\n");

    // init raygui dark style
    // lgr::info(Where.FILE, "loading raygui dark style:");
    // lgr::info(Where.FILE, "---------------------------------------------\n");
    // rgui::style::dark::load();
    // lgr::info(Where.FILE, "- done -\n");

// #region MONITOR STATES
    lgr::info(Where.FILE, "Setting up monitor states:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // See how many monitors user has and change the window placement if necessary.
    // WARNING(HM) This is not guarantied to work for all multi-monitor setups, 
    // it seems that even glfw, that rl uses internally, fails to set the correct monitor on some setups :(
    int monitor_count = rl::getMonitorCount();
    if(monitor_count >= 2) // is multi-monitor setup
    {
        lgr::info(Where.FILE, "\tMulti-Monitor setup found:");
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
                int w = rl::getMonitorPhysicalWidth(i);
                int h = rl::getMonitorPhysicalHeight(i);
                Vec2f mpos = rl::getMonitorPosition(i).toVec2f();
                rl::Rectangle rect = {mpos.x, mpos.y, w, h};
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

            rl::setWindowMonitor(displayIndex);
            local_game.screen.index = displayIndex;
            local_game.screen.id = ++local_game.screen.index;
        }
    }
    
    lgr::info(Where.FILE,  "\tWindow put on monitor id: '%d'", local_game.screen.id);
    
    // @Todo 
    // support unlocked framerates? 
    // Support user setting frame rate on main menu?
    
    if(rl::isWindowFullscreen() && rl::isWindowFocused()) 
    {
        local_game.screen.displayHz = rl::getMonitorRefreshRate(local_game.screen.index);
        lgr::info(Where.FILE,  "\tGame set to %shz update rate.", local_game.screen.displayHz);
    } else {
        local_game.screen.displayHz = 15;
        lgr::info(Where.FILE,  "\tGame set to %shz update rate because lost focus.", local_game.screen.displayHz);
    }
    rl::setTargetFPS(local_game.screen.displayHz);

    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion MONITOR STATES

$if $feature(MICROUI_ENABLE):
    // #region MicroUI initialization
    lgr::info(Where.FILE, "Initializing MicroUI:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // NOTE(HM) This needs to be done before any microUI function requiring units is used!!!
    local_game.mu_ctx = mem::new(MU_Context);
    local_game.mu_ctx.init();
    local_game.mu_ctx.text_width  = &mu::text_width;
    local_game.mu_ctx.text_height = &mu::text_height;
    lgr::info(Where.FILE, "---------------------------------------------\n");
$endif
    
    lgr::info(Where.FILE, "Setting up game view:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // setup/init game view (for now is a static view)
    local_game.view.init(screenWidth, screenHeight);
    lgr::info(Where.FILE, "---------------------------------------------\n");

$if $feature(_DEBUG):
    // TODO(HM) On release version quit should only be done from main menu (or alt+f4...).
    // NOTE(HM) This needs to run after initWindow,
    //          it changes the default exit key (default was ESC key)
    //rl::setExitKey(rl::KEY_F10);
    String key_name = settings_file.getString("quit", "KEY_ESCAPE");
    rl::setExitKey(misc::getKeyValueFromName(key_name));
    lgr::info(Where.FILE, "Exit key set to: %s", key_name);
    lgr::info(Where.FILE, "---------------------------------------------\n");
$endif

// #endregion Window initialization

// #region physics engine
    lgr::info(Where.FILE, "Starting Box2D physics engine:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // TODO(HM) refactor this into a physics engine module that wraps box2d?
    B2Version version = box2d::getVersion();
    lgr::info(Where.FILE, "\tBox2D version: \"%d.%d.%d\"", version.major, version.minor, version.revision);
    
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
    if(box2d::world_IsValid(local_game.physWorldId)) {
        lgr::info(Where.FILE, "\tBox2D Started.");
    } else {
        lgr::error(Where.FILE, "Failed to start Box2D physics engine! Halting game initialization.");
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

    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion physics engine
    
// #region AUDIO DEVICE initialization
    lgr::info(Where.FILE, "Initializing Audio Device:");
    lgr::info(Where.FILE, "---------------------------------------------");

    rl::initAudioDevice();
    
    if(rl::isAudioDeviceReady()) 
    {
        if(rl::getMasterVolume() < 1.0f) {
            rl::setMasterVolume(1.0f);
            lgr::info(Where.FILE, "\tAudio Master Volume set to = %s", 1.0f);
        } else {
            float master_volume = rl::getMasterVolume();
            if(master_volume > 1.0f) {
                lgr::warning(Where.FILE, "\tAudio Master Volume is set to %.2f, this is not recommended!", master_volume);
                rl::setMasterVolume(1.0f); // clamp it
            } else {
                lgr::info(Where.FILE, "\tAudio Master Volume is = %.1f", master_volume);
            }
        }
    } else {
        lgr::warning(Where.FILE, "AudioDevice: Not ready, sound will be disabled! %s:%s", $$MODULE, $$FUNC );
    }

    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion AUDIO DEVICE initialization

    
// #region Asset manager
    lgr::info(Where.FILE, "Loading game assets:");
    lgr::info(Where.FILE, "---------------------------------------------");
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
    //mtr::Material default_mat;
    //default_mat.load(local_game.app_base_folder.tconcat("images/default.mtr"));
    //defer default_mat.free();
    
    // now that the assets are loaded get a pointer to the game fonts
    local_game.initFonts();
    //

    svg::SVGData svgfile;
    svgfile.path = local_game.app_base_folder.tconcat("levels/test.svg").copy(mem);
    if(svgfile.load()!) {
        lgr::info(Where.FILE, "SVG file loaded successfully: %s", svgfile.path);
        //svgfile.printTofile(local_game.app_base_folder.tconcat("levels/test.txt"));
        //svgfile.print();
    } else {
        lgr::warning(Where.FILE, "Failed to load SVG file: %s", svgfile.path);
    }
        
    lgr::info(Where.FILE,  "** done **");
    lgr::info(Where.FILE, "---------------------------------------------\n");
// #endregion Asset manager

$if $feature(WREN_ENABLE):
    lgr::info(Where.FILE, "Initializing Script Engine: %s", wren::VERSION_STRING);
    lgr::info(Where.FILE, "---------------------------------------------");
    // init the game editor defaults
    local_game.script_eng.init();
    local_game.script_eng.registerScripts(local_game.app_base_folder.tconcat(scpt::SCRIPT_FOLDER_NAME));
    Script* main = local_game.script_eng.getScript("main");
    if(main != null) {
        main.run();
    }
    lgr::info(Where.FILE, "---------------------------------------------\n");
$endif

    lgr::info(Where.FILE, "Initializing game editor:");
    lgr::info(Where.FILE, "---------------------------------------------");
    // init the game editor defaults
    local_game.editor.initDefaults();
    lgr::info(Where.FILE, "---------------------------------------------\n");

    // init intro stuff here
    // Todo(HM) create real pre loading logo videos?
    //
    // Set the current program mode to the intro mode
    local_game.mode = INTRO;
    intro::initIntroAnimation(&local_game.intro);
    
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
        lgr::fatal(Where.FILE, "Something went very wrong, failed to init Main Menu!");
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
    createGameInputActions(&settings_file);
    
    // Create the main Single Player
    // NOTE(HM) todo: the player and ingame entities should be created only at spawn of a level 
    // but right now, I don't have a concept of a "level" or game World.
    // TODO(HM) when possible make a dedicated spawn point entity for the player.
    lgr::info(Where.FILE,  "** Creating test player. **");
    local_game.main_player = pl::makePlayer(id: 1, color: rl::BLUE);
    // NOTE(HM) The first entity is always the main player1
    local_game.entityList.push((Entity*)local_game.main_player);
    lgr::info(Where.FILE,  "** Done **.");
    
    // local_game.particleSpawner1.init({
    //     0.5f*local_game.screen.w,
    //     0.85f*local_game.screen.h
    // });
    
    // Create test entities @delete
    lgr::info(Where.FILE,  "** Creating test entities. **");
    for(int i = 1; i <= 2; i++) {
        $if $defined(ENABLE_CAMERA_VIEW):
        Vec2f origin = local_game.view.camera.target.toVec2f();
        $else
        Vec2f origin;
        $endif
        origin.translateV(misc::VEC_UP * 100 * i);
        
        Entity* test_ent = ent::create_ex("", origin, rl::WHITE);
        test_ent.scaleV({16.0f, 16.0f});
        //test_ent.setTexture("figure.png");
        test_ent.setMaterial("figure");
    }
    
    lgr::info(Where.FILE,  "** Done. **");
    
    lgr::info(Where.FILE,  "** Enabling test entities brains. **");
    if(local_game.entityList.len() >= 1) {
        local_game.should_update_entities = true;
        
        // DELETE for testing only!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        foreach(ent : local_game.entityList) {
            Vec2f start = {0, 0};
            Vec2f end   = ent.getPosition();
            assert(start != end);
            if(ent.type != Player.typeid) {
                misc::makeDebugLine(start, end, rl::BLUE, 10000);
            } else {
                misc::makeDebugLine(start, end, rl::YELLOW, 10000);
            }
        }
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    }
    
    // init the boids system
    local_game.boidManager1.init();
    
    
    lgr::info(Where.FILE,  "** Done. **");
// #endregion Test game stuff
    
    local_game.should_quit = false;
    //if(local_game.numEntitiesToDeactivate) local_game.numEntitiesToDeactivate = 0;
    lgr::info(Where.FILE,  "Game Start Done Sucessfully.\n//**//");
}

fn void gameOnExit() @local 
{
    lgr::info(Where.FILE,  "Game shutdown starting.");
    deinit_game_cursor();
    // make sure to release all assets last, so you don't try to release a asset that is already released.
    asstManager.releaseAllAssets();
$if $feature(WREN_ENABLE):
    lgr::info(Where.FILE, "close Script Engine: %s", wren::VERSION_STRING);
    lgr::info(Where.FILE, "---------------------------------------------");
    local_game.script_eng.deinit();
    lgr::info(Where.FILE, "---------------------------------------------\n");
$endif
    // close physics engine
    box2d::deinitDebugDraw(&local_game.phys_debug);
    if(box2d::world_IsValid(local_game.physWorldId)) {
        lgr::info(Where.FILE, "Destroying physics engine.");
        box2d::destroyWorld(local_game.physWorldId);
        lgr::info(Where.FILE, "Done.");
    }
    //
    rl::closeAudioDevice();
    // debug_lines
    if(misc::g_debugLines.len())
    {
        misc::freeDebugLines();
    }
    rl::closeWindow();
    local_game.unload();
    //rl::memFree(memory_pool);
    //lgr::info(Where.FILE,  "clearing game singletons and log system!\n\t** Printing done on OS terminal from this point on **");
    lgr::info(Where.FILE,  "clearing game singletons!");
    clear_game_singletons();
    lgr::info(Where.FILE,  "Game shutdown done!!");
    lgr::closeLogFile();
}

fn void clear_game_singletons() @inline {
    gpGame = null; // clear pointer to game singleton
    //
    input::gpManager.free();
    input::gpManager = null;
    //
    gui::gpDeskManager.free();
    gui::gpDeskManager = null;
     lgr::info(Where.FILE,  "**done**");
}

fn void saveGame() {
    // look in the directory for the game save folder
    String save_folder = local_game.app_save_folder;
    if(fs::directoryExists(save_folder)) {
        String file_path = save_folder.tconcat("\\").tconcat(string::tformat("%s%s%s", local_game.app_name, local_game.time_ms, ".sav"));
        svs::SaveFile? save_file = svs::make_new(file_path);
        defer (void)svs::close(&save_file);
        if(catch excuse = save_file) {
            lgr::warning(Where.FILE, "Unable to save to file: %s with excuse: %s", file_path, excuse);
            return;
        }
        local_game.save(&save_file);
        lgr::info(Where.FILE,  "Saved \"%s\" to folder: %s", file_path, save_folder);
    } else {
        lgr::warning(Where.FILE,`Required save folder inside %s not found!\n
                    A folder called '%s' (case sensitive) most exist there!`,
                    local_game.app_save_folder, local_game.app_name);
        $if $feature(_DEBUG):
        unreachable();
        $endif
    }
}

fn void loadGame() {

    usz file_index;
    
    FilePathList files = fs::loadDirectoryFiles(local_game.app_save_folder);
    if(files.count == 0) {
        lgr::warning(Where.CONSOLE, "Failed to get save files from: %s.", local_game.app_save_folder);
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
         svs::SaveFile? save_file = svs::open(((ZString)files.paths[file_index]).str_view());
        defer (void)svs::close(&save_file);
        if(catch excuse = save_file) {
            lgr::warning(Where.FILE, "Unable to open save file: %s with excuse: %s", files.paths[file_index], excuse);
            return;
        }
        
        local_game.reload(&save_file);
    }  

/* 
    Path? path = path::temp_new(local_game.app_save_folder);
    if(catch excuse = path) {
        lgr::warning(Where.CONSOLE, "Failed to get home dir where save files are at with excuse: %s.", excuse);
        return;
    }
    
    PathList! files  = path::new_ls(path)!!; // new_ls only returns the filenames
    if(catch excuse = files) {
       lgr::warning(Where.CONSOLE, "Failed to get save files from home dir with excuse: %s.", excuse);
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
            lgr::warning(Where.FILE, "Unable to open save file: %s with excuse: %s", file_path, excuse);
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
fn void createGameInputActions(ini::Config* settings_file) @inline @local
{
    defer input::listActions();

    String key_name;

    $if $feature(_DEBUG):
    input::makeKeyboardAction("screenshots", rl::KEY_F2, rl::KEY_NULL, (ActionCallBack)&camview::moveScreenShots);
$endif

$if !$feature(_DEBUG):
    input::makeKeyboardAction("quit", misc::getKeyValueFromName(settings_file.getString("quit")), rl::KEY_NULL, (ActionCallBack)&input::quitGame);
$endif

    input::makeKeyboardAction("quicksave", misc::getKeyValueFromName(settings_file.getString("quicksave")), rl::KEY_NULL, (ActionCallBack)&saveGame);
    input::makeKeyboardAction("quickload", misc::getKeyValueFromName(settings_file.getString("quickload")), rl::KEY_NULL, (ActionCallBack)&loadGame);
    
    input::makeKeyboardAction("particles", rl::KEY_INSERT);

    // game main editor
    input::makeKeyboardAction("toggle_editor", rl::KEY_F1, rl::KEY_LEFT_SHIFT);

    // mouse actions
    input::makeMouseAction("Single Press", MouseButton.LEFT);
    input::makeMouseAction("Double Press", MouseButton.LEFT);
    // for the WIP game editor
    input::makeMouseAction("editor_select", MouseButton.LEFT, rl::KEY_LEFT_SHIFT);
}

////////////////////////////////// GAME LOOP ////////////////////////////////////////////////////////////////

fn void quitGame() @inline @public {
    local_game.should_quit = true;
}

fn void gameDoOneFrame() @local
{
    misc::@profile_zone("Game Loop")
    {
        while(rl::windowShouldClose() != true) 
        {
            //@pool()
            //{
                tracy::@messageL( "Tick" );
                tracy::@zoneN("Game loop", 1)
                {
                    float gameDoOneFrame_st = @start_profile_zone();
                    defer @end_profile_zone(gameDoOneFrame_st);
                    
                    if(local_game.should_quit) break;
                    
                    // update game timing
                    local_game.dt       = rl::getFrameTime(); // last frame time
                    local_game.time_sec = (float)rl::getTime();
                    local_game.time_ms  = misc::sec2ms(local_game.time_sec);

                    int screen_w = rl::getScreenWidth();
                    int screen_h = rl::getScreenHeight();
                    
                    gameUpdate();
                    gameDraw(screen_w, screen_h);
                }; // tracy scope end
           // };
        }
        
    };
    
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

//usz* memory_pool @local;

fn void pre_InitFunc() @init {
    io::printfn("/*******************************************\n");
    io::printfn("This should run BEFORE main entry function!\n");
    io::printfn("*******************************************\\\n");
    
    //uint value = misc::megaBytes2Bytes(1024);
    //memory_pool = (usz*)rl::memAlloc( value * uint.sizeof);
    gameArena.init(mem, GAME_ARENA_PAGE_SIZE);
    
    // Controls raylib console logging
    // Raylib library gets initialized here, because this function calls a raylib function
    // NOTE(HM) This means the MINIMUM log level not the only level to log
    // anything bellow this level will not log
    rl::setTraceLogLevel(rl::TraceLogLevel.INFO);
    
    // My own logging system
    // NOTE(HM) controls file and Console logging 
    // plus sets where the log file is saved as well.
    lgr::initGlobalLoggingDir(); 
    
    // This means the MINIMUM log level not the only level to log
    // anything bellow this level will not log
    lgr::setLogLevel(rl::TraceLogLevel.INFO);
    
}

fn int main(String[] args) @public
{
    tracy::set_thread_name("main_thread");
    
    fault excuse = @catch(gameOnStart(&args));
    if (excuse) {
        lgr::error(Where.CONSOLE, "Game initialization failed with excuse: %s", excuse);
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
        
        introMutex.init()!!;
        introThread.create(&playIntro, null)!!;
        introThread.detach()!!;
        
        // run the game loop
        gameDoOneFrame();
        // NOTE(HM) For clean program exit, do not put any code here between this two calls!!!
        // any per frame code should be inside gameDoOneFrame and exit code should be put inside gameOnExit.    
        gameOnExit();
    }
    
    // return to Operating System.
    return 0;
}

// NOTE(HM) invoking @finalizer is a best effort attempt by the OS and may not be called during abnormal shutdown.
fn void pos_MainFunc() @finalizer
{
    io::printfn("/*******************************************\n");
    io::printfn("This should run AFTER main entry function!\n");
    io::printfn("*******************************************\\\n");
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

fn int playIntro(void*) 
{
    tracy::set_thread_name("intro_thread");
    menu::stop();
    
    do {
        intro::play(&local_game.intro);
        local_game.intro_playing = true;
    } while(intro::updateIntroAnimation(&local_game.intro));
    
    local_game.intro_playing = false;
    //local_game.main_menu.show();
    // 
    // restarts from the main menu;
    disconnect();
    
    return 0;
}

// TODO rename to set_user_settings?
fn void parse_user_settings(Config* settings, int* window_flags)
{
    if(settings == null) return;
    
    foreach(section : settings.sections)
    {
        // handle empty sections
        if(section.cmds.is_empty()) {
            lgr::warning(Where.CONSOLE, "Cmd list of section %s is empty. Using defaults.", section.name, ini::SETTINGS_FILE_NAME);
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
                                    lgr::warning(Where.CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
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
                                        lgr::warning(Where.CONSOLE, "Unnable to convert value %s of cmd %s of section %s to int.", cmd_value, cmd_id, section.name);
                                    }
                                    
                                case "r_mode":
                                nextcase;
                                case "r_custom_width" :
                                nextcase;
                                case "r_custom_heigth":
                                nextcase;
                                case "maxFPS":
                                nextcase;
                                case "gamma":
                                nextcase;
                                case "brightness":
                                nextcase;
                                default:
                                    lgr::warning(Where.CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        case ini::FLOAT:
                            switch(cmd_id) 
                            {
                                case "unknown":
                                nextcase;
                                default:
                                    lgr::warning(Where.CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                            }
                        case ini::STRING:
                            switch(cmd_id) 
                            {
                                case "unknown":
                                nextcase;
                                default:
                                    lgr::warning(Where.CONSOLE, "Cmd \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
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
                            lgr::warning(Where.CONSOLE, "action \"%s = %s\" in file %s is still not handled.", cmd_id, cmd_value, ini::SETTINGS_FILE_NAME);
                    }
                }
            default:
                lgr::warning(Where.CONSOLE, "Found empty section %s in ini file %s.", section.name, ini::SETTINGS_FILE_NAME);
        }
    }
}

// #endregion
