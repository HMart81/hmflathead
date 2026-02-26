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

// NOTE(HM) This module is the main game view, it handles the rendering of the game world
// TODO(HM)
//       - Refactor this to use meters instead of pixels because of box2d physics, 
//       - also right now this code is very confusing.
//
// WARNING(HM) MOST OF THE SCREEN INFO BELLOW IS TOTALLY OUTDATED!!!

module game::camview;

// region modules
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
import game::main;
import engine::misc;
import engine::input;
import game::assets::sprite;
import game::actors::ent::plyr; // player
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import thirdparty::raylib5::rmath;
import game::serialize::svs; // save system
import game::lowlevel::bounds;
import game::material::mat;
import engine::logging::log;
import engine::physics::box2d;
import game::camview::postprocess::pp;
// end_region

/*
    NOTE(HM) 
    In raylib, using 2D camera, screen coordinates use a 2D Cartesian system 
    with the origin (0,0) at the top-left corner of the window.
    
    ** world view space **
    
    0,0___________
    | __ +x       |
    | |           |
    | +y          |
    |             |
    |             |
    |_____________|



    Unfortunatly OpenGL uses a different coordinate system
    with the origin (0,0) at the bottom-left corner of the window.
    And positive Y axis goes up, not down as in raylib screen space.

    ** rendering/draw view space **
     _____________
    | +y          |
    | |           |
    | |____ +x    |
    |             |
    |             |
    0,0___________|
    
    WARNING: This means that when displaying framebuffer textures, 
             the Y coordinate, will be inverted!!!
             And we will have to negate the Y axis when drawing the framebuffer texture.
             BUT Raylib functions getting 2D screen coordinates, like rl::getMouseY(), etc..., 
             will return the value has if Y is NOT inverted, so have that in mind!!!

    
    ** camera coordinate space **
    
     _____________
    |             |
    |      y      |
    | -x __|__ +x |
    |      |      |
    |     -y      |
    |_____________|
    
    CCW rotation (counter clockwise) using the right hand rule
    with +Z towards the viewer, it is also axis of rotation (not used for now...)
    
    
    ** entity/model space **
    
    [3D] (not used for now)
    
    Right handed coord system CCW rotation
    
    +z up
    ^
    |__> +y right
    
    +X is towards the viewer (this is also model forward)
    
    [2D] = (camera coordinate space)
    
    canonical view square
    | -1, 1   0, 1   1, 1 |   |      1     |
    | -1, 0   0, 0   1, 0 | = | -1___|___1 |
    | -1,-1   0,-1   1,-1 |   |     -1     |
*/

/*
  world_matrix:
    s = scale
    r = rotation
    t = translation

* column Major*
|sx ry tx|   |a c e|   |m00 m01 m02|
|rx sy ty| = |b d f| = |m10 m11 m12|
| 0  0  1|   |0 0 1|   |m20 m21 m22|
*/

const Matrix3f VIEW_AXIS_IDENTITY = {
    1.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 1.0f
};

alias gameptr = game::gpGame;

const int ENABLE_CAMERA_VIEW = 1;

typedef RenderTexture @private = inline RLRenderTexture2D;
alias RenderFunctionCallback = fn void(RenderView* view);

struct ViewLayer @private
{
    RenderTexture data;
}

<*
	Initializes the view layer with the given render texture.

	@param #width : "the x width of the render texture to use for this view layer"
	@param #height : "the y height of the render texture to use for this view layer"
	@require #width >= 32 && #height >= 32
*>
macro ViewLayer.@init(&self, #width, #height) {
	self.data = (RenderTexture)rl::loadRenderTexture(#width, #height);
}

struct RenderView (SaveSystemInterface)
{
    ViewLayer gameFrame;
    ViewLayer guiFrame;
    ViewLayer postGuiFrame;
    //RenderTexture shadowFrameBuffer; // not used yet
    ViewLayer debugFrame; // not used yet
    //
    RenderTexture* currentRender; // current render target/layer displayed
    bool taking_screenshot;
    HMPostProcess grayscale;
    bool enable_grayscale;
    //
    
    // render view size
    union {
        struct @packed {
            int w;
            int h;
        }
        Vec2i size;
    }
    // render view position/origin
    Vec2f origin;
    Vec2f default_origin;
    Bounds bounds;

    Matrix3f axis; // world to view axis transform matrix

    RLCamera2D camera  @if ($defined(ENABLE_CAMERA_VIEW));
    RLCamera3D camera3D @if ($defined(ENABLE_CAMERA3D_VIEW)); // not used for now...
}

fn void RenderView.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void RenderView.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void RenderView.init(&self, int screenWidth, int screenHeight) @inline 
{
    // @testing...
	self.gameFrame.@init(screenWidth, screenHeight);
    self.guiFrame.@init(screenWidth, screenHeight);
    self.postGuiFrame.@init(screenWidth, screenHeight);
    //self.shadowFrame.data  = (RenderLayer)rl::loadRenderTexture(screenWidth, screenHeight); // not used yet
    self.debugFrame.@init(screenWidth, screenHeight);
    //
    // NOTE(HM) used to point to the main render layer to be used for shaders and such if necessary
    self.currentRender = &self.gameFrame.data;

    self.grayscale.load("grayscale");
    
    self.w = screenWidth;
    self.h = screenHeight;
    
$if $defined(ENABLE_CAMERA_VIEW):
    // middle of the screen is the origin
    self.origin = { self.w / 2.0f, self.h / 2.0f };
    self.default_origin = self.origin;
    // sets camera view target and view direction
    // look at the origin
    self.camera.target = self.origin;
    // move the view axis center to be the target
    //self.axis.translate(self.camera.target.arr);
    
    // sets how far the camera is from the view target
    // right now theres no offset for the target
    self.camera.offset = self.camera.target;
   
    // NOTE(HM) To simplify things camera rotation will not be possible
    //self.camera.rotation = 0;
    //
    self.camera.zoom = 1.0f;
$endif

    self.axis = VIEW_AXIS_IDENTITY;
    {
        // flip Y axis to match the camera coordinate space
        self.axis.m11 = -1.0f;
    }

$if ($defined(ENABLE_CAMERA3D_VIEW)):
    float aspect_ratio = (float)screenWidth / (float)screenHeight;
    float fov_y = 45.0f;
    float camera_distance = 10.0f;
    // 3D camera view (not used for now...)
    self.camera.position = { self.w / 2.0f, self.h / 2.0f , 0.0f} + {0, 0, -1} * camera_distance; // RLCamera position
    self.camera.target = (RLVector3){ self.w / 2.0f, self.h / 2.0f , 0.0f};      // RLCamera looking at point
    self.camera.up = (RLVector3){ 0.0f, 1.0f, 0.0f };          // RLCamera up vector (rotation over its axis)
    /*
    float fovy;                     // RLCamera field-of-view apperture in Y (degrees) in perspective, used as near plane width in orthographic
    RLCameraProjection projection;    // RLCamera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
    */
    self.camera.fovy = fov_y;    
    self.camera.projection = rl::CAMERA_ORTHOGRAPHIC;

$endif

    // view bounds
    Vec2f bb_maxc = self.origin + misc::VEC_UP * (float)(self.h / 2) + misc::VEC_LEFT * (float)(self.w / 2);  
    RLRectangle bb_def = misc::makeRect(bb_maxc, {self.w, self.h});
    self.bounds.setRect(bb_def);
    
    // key actions
    input::makeKeyboardAction("cam_move_up",    rl::KEY_W);
    input::makeKeyboardAction("cam_move_left",  rl::KEY_A);
    input::makeKeyboardAction("cam_move_down",  rl::KEY_S);
    input::makeKeyboardAction("cam_move_right", rl::KEY_D);
    input::makeKeyboardAction("cam_zoom",       rl::KEY_Z);
    input::makeKeyboardAction("cam_reset",      rl::KEY_R);
    input::makeKeyboardAction("pp_graysacle",   rl::KEY_G);
}

fn void RenderView.deinit(&self)
{
     // Unload render texture (FBO)
    if(rl::isRenderTextureValid(self.gameFrame.data))    rl::unloadRenderTexture(self.gameFrame.data);
    if(rl::isRenderTextureValid(self.guiFrame.data))     rl::unloadRenderTexture(self.guiFrame.data);
    if(rl::isRenderTextureValid(self.postGuiFrame.data)) rl::unloadRenderTexture(self.postGuiFrame.data);
    self.currentRender = null;
    self.grayscale.unload();
}

fn void RenderView.debug(&self) 
{
    /*RLRectangle rec = {
        .x = self.origin.x,
        .y = self.origin.y,
        .width  = self.w,
        .height = self.h
    };
    
    rl::drawRectangleLinesEx(rec, 2.5f, rl::RED);
    String view_data_text = string::tformat("Screen Size: {%.2f, %.2f}", rec.width, rec.height);
    rl::drawText(view_data_text.zstr_tcopy(), 100, 10, 30, rl::RED);
    //rl::drawTextEx(*game::gpGame.candara_font, "TEXT DRAWN IN RENDER TEXTURE", {10, 30}, 16.0f, 2.0f, rl::COLOR_RED);
    //rl::drawLine((int)self.camera.target.x, -(int)rec.height*10, (int)self.camera.target.x, (int)rec.height*10, rl::COLOR_GREEN);
    //rl::drawCircleV(self.camera.target, 16.0f, rl::COLOR_RED);
    //rl::drawRectangle(-6000, 320, 13000, 8000, rl::DARKGRAY);*/
}

<*
    Renders to the given framebuffer layer using the provided callback function.
    
    @param callback : "the rendering function callback to use"
    @require callback != null
*>
fn void RenderView.renderFBO(&self, RenderFunctionCallback callback) @inline
{
    if(callback) {
        callback(self);
    }
}

// NOTE(HM) This was disabled because I found Raysan's
// hardcoded F12 key for the screenshot action, very annoying,
// and also didn't provided a way to override the folder 
// where the screenshot is saved, is always next to the .exe
fn void takeScreenShot() 
{
    unreachable();
    /*
    String shots_dir = game::gpGame.app_work_dir.tconcat("screenshots\\");
    if(fs::directoryExists(shots_dir) == false) {
        bool~ sucess = fs::makeDirectory(shots_dir);
        if(catch excuse = sucess) {
            log::warning(Where.FILE, "Cannot create screenshots directory at: %s!\n\t -> excuse: %s", 
                        shots_dir, excuse);
            $if $feature(_DEBUG):
                unreachable();
            $endif
        } 
    }
    
    int bytes_count;
    ZString shotname; // screenshot name
    ZString saved_shot_file;
    
    // count how many shots are in the screenshot folder
    uint file_count;
    RLFilePathList files = fs::loadDirectoryFilesEx(shots_dir, ".png", scanSubdirs: false);
    
    defer {
        // at the end return everything to defaults
        fs::unloadDirectoryFiles(files);
        //log::info(Where.CONSOLE, "current dir after all = %s", rl::getWorkingDirectory());
        if(bytes_count) {
            // return to main work dir
            fs::changeDirectory(game::gpGame.app_work_dir)!!;
            rl::unloadFileData(saved_shot_file);
            // and try to delete older file
            @catch(file::delete(shotname.str_view()));
        }
    }
    
    if(files.count) file_count = files.count++;
    shotname = string::tformat("screen%d.png", file_count).tcopy();
    rl::takeScreenshot(shotname); // saves it in the application .exe folder
    
    // move the image to the screenshot folder
    // first load image data to memory
    char[] shot = fs::fileLoadEntireBytes(shotname.str_view());
    defer {
        // unload the image data
        if(shot.len) fs::fileUnloadEntireBytes((ZString)shot);
    }
    if(shot.len) 
    {
        // then change to dir where you want to save the image
        if(fs::changeDirectory(shots_dir)!! == true) 
        {
            bool? sucess = fs::fileSaveEntireBytes(shotname, shot);
            if(catch excuse = sucess) {
                log::warning(Where.CONSOLE, "failed to transfer file %s to %s with excuse: %s", shotname, shots_dir, excuse);
            }
        }
    }
    */
}

fn void moveScreenShots() 
{
    String shots_dir = game::gpGame.app_work_dir.tconcat("screenshots\\");
    bool? sucess = fs::makeDirectory_IfNotExist(shots_dir);
    if(catch excuse = sucess) { // will ignore if the directory already exists
        log::warning(Where.FILE, "Cannot create screenshots directory at: %s!\n\t -> excuse: %s", 
                    shots_dir, excuse);
        $if $feature(_DEBUG):
            unreachable();
        $endif
    }
    
    // count how many shots are in the w folder then
    RLFilePathList files = fs::loadDirectoryFilesEx(game::gpGame.app_work_dir, ".png", scanSubdirs: false);
    for(int i = 0; i < files.count; i++) {
        // move the images to the screenshot folder
        String file_shot_path = ((ZString)files.paths[i]).str_view();
        char[] shot_data = file::load_temp(file_shot_path)!!;
        if(shot_data.len) {
            String file_name = shots_dir.tconcat(fs::getFileName(file_shot_path));
            @catch(file::save(file_name, shot_data));
            // delete old file
            @catch(file::delete(file_shot_path));
        }
    }
    
    fs::unloadDirectoryFiles(files);
}

fn void RenderView.showModelViewAxis(&self) 
{
    /*
    // RLMatrix, 4x4 components, column major, OpenGL style, right handed
    {                            identity RLMatrix     X   Y   Z
        float m0, m4, m8, m12;     1  0  0  0       sx   x   x  tx
        float m1, m5, m9, m13;     0  1  0  0   =    y  sy   y  ty
        float m2, m6, m10, m14;    0  0  1  0        z   z  sz  tz
        float m3, m7, m11, m15;    0  0  0  1        0   0   0   1
    }
    */
    RLMatrix axis = rl::getCameraMatrix2D(self.camera);
    
    // draw axis coords in camera space
    Vec2f axis_org, start, end, pox, poy;
    axis_org = self.getTarget();
    start    = axis_org;
    // +X coord
    end = start + (Vec2f) {axis.m0, axis.m1} * (0.10f * self.w);
    rl::drawLineV(start, end, rl::RED);
    // -X coord
    end = start + (Vec2f) {-axis.m0, axis.m1} * (0.10f * self.w);
    rl::drawLineV(start, end, {255, 50, 15, 127});
    // +Y coord arrow
    end = start + (Vec2f) {axis.m4, axis.m5} * (0.10f * self.h);
    rl::drawLineV(start, end, rl::GREEN);
    // -Y coord
    end = start + (Vec2f) {axis.m4, -axis.m5} * (0.10f * self.h);
    rl::drawLineV(start, end, {10, 255, 15, 127});
}

fn void RenderView.updateTarget(&self) @inline @if ($defined(ENABLE_CAMERA_VIEW))
{
    self.camera.target = self.getOrigin();
}

fn Vec2f RenderView.getTarget(&self) @inline @if ($defined(ENABLE_CAMERA_VIEW))
{
    return (Vec2f)self.camera.target;
}

fn void RenderView.setOrigin(&self, Vec2f new_pos) 
{
    //self.axis.m02 = new_pos.x;
    //self.axis.m12 = new_pos.y;
    self.origin = new_pos;
$if $defined(ENABLE_CAMERA_VIEW):
    self.updateTarget(); // this needs to run always after updating the camera pos
$endif
}

fn Vec2f RenderView.getOrigin(&self) @inline 
{
    //return self.axis.getTranslation();
    return self.origin;
}

fn void RenderView.resetCamera(&self) @if ($defined(ENABLE_CAMERA_VIEW))
{
    // reset camera position
    self.setOrigin(self.default_origin);
    // reset camera target
    self.camera.target = self.default_origin;
    // reset camera zoom
    self.camera.zoom = 1.0f;
    // reset camera offset
    self.camera.offset = self.camera.target;
}

fn void RenderView.cameraControls(&self) @if ($defined(ENABLE_CAMERA_VIEW))
{
$if $feature(_DEBUG):
    // RLCamera translation controls
    if (input::getAction("cam_move_up").fnIsTriggered()) {
        self.origin.y++;
    }
    if (input::getAction("cam_move_left").fnIsTriggered()) {
        self.origin.x++;
    }
    if (input::getAction("cam_move_down").fnIsTriggered()) {
        self.origin.y--;
    }
    if (input::getAction("cam_move_right").fnIsTriggered()) {
        self.origin.x--;
    }
$endif

    // if (rl::isMouseButtonDown(RLMouseButton.RIGHT))
    // {
        // RLVector2 delta = rl::getMouseDelta();
        // delta = rmath::vector2Scale(delta, -1.0f/self.camera.zoom);
        // self.camera.target = rmath::vector2Add(self.camera.target, delta);
    // }
    
    if (input::getAction("cam_zoom").fnIsTriggered())
    {
        float wheel_movement = rl::getMouseWheelMove();
        if (wheel_movement != 0)
        {
            // Get the world point that is under the mouse
            RLVector2 mousePos = rl::getMousePosition();
            RLVector2 mouseWorldPos = rl::getScreenToWorld2D(mousePos, self.camera);
            
            // Set the offset to where the mouse is in world space
            self.camera.offset = mousePos;

            // Set the target to match, so that the camera maps the world space point 
            // under the cursor to the screen space point under the cursor at any zoom
            self.camera.target = mouseWorldPos;
            
            // RLCamera zoom controls
            // Uses log scaling to provide consistent zoom speed
            self.camera.zoom = math::exp(math::ln(self.camera.zoom) + ((float)rl::getMouseWheelMove() * 0.1f));

            if (self.camera.zoom > 3.0f) { self.camera.zoom = 3.0f; }
            else { if (self.camera.zoom < 1.0f) self.camera.zoom = 1.0f; }

        }
    }
    
    // RLCamera reset (zoom && origin)
    if (input::getAction("cam_reset").fnIsTriggered()) {
        self.resetCamera();
    }
}

fn void RenderView.update(&self) 
{
    if(game::developer.getBool()) 
    {
        // for some stupid reason raysan from raylib hardcoded F12 to the screenshot action
        // so now I can't reuse that key for something else
        // if(!self.taking_screenshot && rl::isKeyDown(rl::KEY_F2)) {
            // self.taking_screenshot = true;
            // //takeScreenShot();
        // }
        
        // if(rl::isKeyReleased(rl::KEY_F2)) self.taking_screenshot = false;
$if $defined(ENABLE_CAMERA_VIEW): 
        self.cameraControls();
$endif
        self.updateBounds();
    }

    if (input::getAction("pp_graysacle").fnBecameTriggered()) {
        self.enable_grayscale = !self.enable_grayscale;
    }
}

fn void RenderView.updateBounds(&self) {
    @pool() {
        Vec2f bb_maxc = self.getTarget() + misc::VEC_UP * (float)(self.h / 2) + misc::VEC_LEFT * (float)(self.w / 2);  
        self.bounds.setRect(misc::makeRect(bb_maxc,{self.w, self.h}));
    };
}

fn B2AABBox RenderView.fromBoundsToPhysicsAABB(&self)
{
	B2AABBox bb;
	bb.lowerBound = self.bounds.minc; //rl::getScreenToWorld2D( { 0.0f, (float)self.h }, self.camera ).arr;
	bb.upperBound = self.bounds.maxc; //rl::getScreenToWorld2D( { (float)self.w, 0.0f }, self.camera ).arr;
	return bb;
}



int old_sort @local; // used to sort the sprites by their sort value

<*
    This renders the game world into a framebuffer layer.
    This is the main game rendering function, it draws all the game sprites and entities
    and also the physics debug drawing if enabled.

    @param [&in] view : "the view to render to the framebuffer layer" 
*>
fn void renderGameFBO(RenderView* view) @local 
{
	RLRenderTexture2D tex = (*view).gameFrame.data;
    rl::beginTextureMode(tex); // Enable drawing to a texture

        //rl::clearBackground(rl::WHITE);  // Clear texture background
        rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
        
$if $defined(ENABLE_CAMERA_VIEW):
        rl::beginMode2D(view.camera);
$endif

        // draw general game sprites
        if(game::gpGame.sprites.len()) 
        {
            foreach(sprite : game::gpGame.sprites)
            {
                if(sprite.kind == SpriteKind.CURSOR) { continue; } // skip game cursor sprite
                
                 bool out_of_view = !view.bounds.intersectsOther(&sprite.bounds);
                if(out_of_view) {
                    sprite.hide();
                } else if(sprite.hidden()) { 
                    sprite.show(); 
                } else {
                    if(sprite.hasMaterial())
                    {
                        int sort = sprite.mat.sort;
                        if(sort <= old_sort) 
                        {
                            // draw opaque sprites first
                            if(sprite.mat.flags.has_AlphaTest == false && !(sprite.mat.coverage & mat::COVERAGE_TRANSLUCENT)) 
                            {
                                sprite.draw();
                            } 
                            else // draw translucent sprites
                            {
                                sprite.draw();
                            }
                        }
                        old_sort = sort;
                    }
                    else // draw with no material using the default shader
                    {
                        sprite.draw(); 
                    }
                }
            }
        }
            
        // draw game entities
        if(game::gpGame.entityList.len()) 
        {
            foreach(ent : game::gpGame.entityList) 
            {
                bool ent_out_of_view = !view.bounds.intersectsOther(&ent.bounds);
                if(ent_out_of_view) {
                    ent.hide();
                } else if(ent.hidden()) { 
                    ent.show(); 
                } else {
                    ent.draw();
                }
            }
        }
        
        // draw the boid entities
        $if $defined(BOIDS_ENABLE):
        game::gpGame.boidManager1.draw();
        $endif
        
        // physics debug drawing
        // NOTE(HM) this is done here because I want it to draw
        // before/behind the gui and other debug stuff at the same time as the game entities.
        if(game::db_drawPhysics.getBool()) {
            game::gpGame.physWorldId.debugDraw(&game::gpGame.phys_debug);
        }

$if $defined(ENABLE_CAMERA_VIEW):
        rl::endMode2D();
$endif
    
    rl::endTextureMode(); // End drawing to texture (now we have a texture available for next passes)
}

<*
    // NOTE(HM) This renders AFTER the game layer
    
    @param [&in] view : "the view to render to the framebuffer layer" 
*>
fn void renderGuiFBO(RenderView* view) @local 
{
    RLRenderTexture2D tex = (*view).guiFrame.data;
	rl::@textureMode(tex) 
	{
        rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
$if $defined(ENABLE_CAMERA_VIEW):
        rl::@mode2D(view.camera) {
$if $feature(_DEBUG):
            //view.debug();
            //view.drawWorldSpaceCoords();
            view.drawCameraSpaceCoords();
$endif
            game::onGuiDraw(view.w, view.h);
        };
$endif
    }; // End drawing to texture (now we have a texture available for next passes)
}

<*
    // NOTE(HM) This renders AFTER the game gui layer
    
    @param [&in] view : "the view to render to the framebuffer layer" 
*>
fn void renderPostGuiFBO(RenderView* view) @local 
{
	RLRenderTexture2D tex = (*view).postGuiFrame.data;
	rl::@textureMode(tex)
	{
		rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
$if $defined(ENABLE_CAMERA_VIEW):
		rl::@mode2D(view.camera) 
		{
			game::onPostGUIDraw(view.w, view.h);

			$if $feature(VIDEO_PLAYBACK_ENABLE):
			if(game::gpGame.vidCabinet.movies.len()) 
			{
				// draw videos from video cabinet library
				foreach(movie : game::gpGame.vidCabinet.movies)
				{
					movie.renderFrame(view.origin, (Vec2f)view.size);
				}
			}
			$endif
		};
$endif
    }; // End drawing to texture (now we have a texture available for next passes)
}

<*
    // NOTE(HM) This renders AFTER the post gui layer
    // both the post gui and debug layers are used for debugging purposes
    // but the post gui layers is mostly used for text/line debugging
    // and the debug layer is used for visual debugging
    
    @param [&in] view : "the view to render to the framebuffer layer" 
*>
fn void renderDebugFBO(RenderView* view) @local 
{
	RLRenderTexture2D tex = (*view).debugFrame.data;
    rl::@textureMode(tex) {
        rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
$if $defined(ENABLE_CAMERA_VIEW):
        rl::@mode2D(view.camera) {
            // nothing for now...
        };
$endif
    }; // End drawing to texture (now we have a texture available for next passes)
}

fn void RenderView.renderToFBO(&self) @inline
{
    // render to the game layer
    if(self.enable_grayscale) {
        self.grayscale.@apply(self.currentRender) {
            self.renderFBO(&renderGameFBO);
        };
    } else {
        self.renderFBO(&renderGameFBO);
    }
    // render to the gui layer
    self.renderFBO(&renderGuiFBO);
    // render to the post gui layer
    self.renderFBO(&renderPostGuiFBO);
    // render to the debug layer
    self.renderFBO(&renderDebugFBO);
}

fn void RenderView.draw(&self) @inline 
{
    // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)

    // draw the game framebuffer
    rl::drawTextureRec(self.gameFrame.data.texture, { 0, 0, (float)self.w, (float)-self.h }, { 0, 0 }, rl::WHITE);
    // draw the gui framebuffer
    rl::drawTextureRec(self.guiFrame.data.texture, { 0, 0, (float)self.w, (float)-self.h }, { 0, 0 }, rl::WHITE);
    // draw the post gui framebuffer
    rl::drawTextureRec(self.postGuiFrame.data.texture, { 0, 0, (float)self.w, (float)-self.h }, { 0, 0 }, rl::WHITE);
    // draw the debug framebuffer
    rl::drawTextureRec(self.debugFrame.data.texture, { 0, 0, (float)self.w, (float)-self.h }, { 0, 0 }, rl::WHITE);
}

/*
* Row Major*
|sx ry tx|   |m00 m01 m02|
|rx sy ty| = |m10 m11 m12|
| 0  0  1|   |m20 m21 m22|
*/
fn Vec2f RenderView.fromWorldSpaceToView(&self, Vec2f vec) 
{
    // Matrix3f transform = VIEW_AXIS_IDENTITY;
    // transform.m02 *= vec.x;
    // transform.m12 *= vec.y;
    
    // transform =  self.axis.mul(transform);
    
    // return {transform.m02, transform.m12};
    return {0, 0};
}

// NOTE(HM) 
// Transforms the view coords from screen coords to -1 to 1
fn Vec2f RenderView.toCanonicalViewSpace(&self, Vec2i vec) 
{
    float x, y;
    int width  = self.currentRender.texture.width;
    int height = self.currentRender.texture.height;
    
    // map the coords to -1 to 1
    //x = misc::@mapValueRangeToOtherX(vec.x, 0, width, -1, 1);
    //y = misc::@mapValueRangeToOtherX(vec.y, 0, height,-1, 1);
    x = misc::@clampfBinormalMapToRange(vec.x, 0, width);
    y = misc::@clampfBinormalMapToRange(vec.y, 0, height);
    // io::printfn("[");
    // io::printfn("{%s, %s}", vec.x, vec.y);
    // io::printfn("Canonical X = %s", x);
    // io::printfn("Canonical Y = %s", y);
    // io::printfn("]");
    return {x, y};
}

fn void RenderView.drawWorldSpaceCoords(&self) @if($feature(_DEBUG)) 
{
    RLRectangle rec = {
        .x = 0,
        .y = 0,
        .width  = self.w,
        .height = self.h
    };
    
    // draw a box representing the world area
    rl::drawRectangleLinesEx(rec, 2.5f, rl::RED);
    // draw world coords
    Vec2f scr_org, start, end, pox, poy;
    scr_org = {0,0};
    start   = scr_org;
    start.x += (0.010 * rec.width);
    start.y += (0.010 * rec.height);
    // x coord arrow
    end = start + misc::VEC_RIGHT * (0.10 * rec.width);
    misc::draw_arrow(start, end, rl::RED);
    // label x coords
    pox = end;
    pox.translateV(misc::VEC_RIGHT * (0.010f * rec.width) + 3);
    // Y coord arrow
    end = start + misc::VEC_DOWN * (0.10 * rec.height);
    misc::draw_arrow(start, end, rl::GREEN);
    // label y coords
    poy = end;
    poy.translateV(misc::VEC_DOWN  * (0.010f * rec.height) + 3);
    //
    String x_coord, y_coord;
    x_coord = string::tformat("[%s]", rec.width);
    y_coord = string::tformat("[%s]", rec.height);
    // drawText(ZString text, int posX, int posY, int fontSize, RLColor color)
    rl::drawText(x_coord.zstr_tcopy(), (int)pox.x, (int)pox.y, 10, rl::RED);
    rl::drawText(y_coord.zstr_tcopy(), (int)poy.x, (int)poy.y, 10, rl::RED);
}

fn void RenderView.drawCameraSpaceCoords(&self) @if($defined(ENABLE_CAMERA_VIEW) && $feature(_DEBUG))
{
    self.showModelViewAxis();
    
    RLColor g = {0, 255, 0, 100};
    RLColor r = {255, 0, 0, 100};
    //rl::drawRectangleLinesEx(misc::makeRect(self.origin, {self.w, (float)-self.h}), 2.5f, rl::RED);
    if(bounds::db_showBounds.getBool()) {
        self.bounds.debugDraw();
    }
    // vertical line
    rl::drawLine((int)self.camera.target.x, -self.w*10, (int)self.camera.target.x, self.h*10, g);
    rl::drawText("-Y", (int)self.camera.target.x + 10, (int)(self.camera.target.y - (0.95f*(self.h/2.0f))), 10, g);
    // horizontal line
    rl::drawLine(-self.w*10, (int)self.camera.target.y, self.w*10, (int)self.camera.target.y, r);
    rl::drawText("+X", (int)(self.camera.target.x + (0.95f*(self.w/2.0f))), (int)self.camera.target.y + 10, 10, r);
    rl::drawCircleV(self.camera.target, 10.0f, rl::GREEN);
}


module game::camview::postprocess::pp;

import std::io;
import game::main;
import std::collections::list;
import thirdparty::raylib5::rl;
import engine::filesystem::fs;
import engine::sys::framework::glsl;
import engine::misc; // for @todo
import game::camview @public;

const SHADERS_FOLDER = "shaders/";
alias PostProcessList = List{HMPostProcess*};

PostProcessList pplist @local;

struct HMPostProcess
{
    String name;
    int id;
    RLShader shader;
}

<*
    Load a PostProcess shader
    shaders should be put inside the main shader folder no sub folder
    and only the name is passed to the function, no need for the path or extension.
    @param [in] _name : "name of the post process shader to load"
    @require _name != ""
*>
fn void HMPostProcess.load(&self, String _name) 
{
    String shader_path = game::gpGame.app_base_folder.tconcat(SHADERS_FOLDER).tconcat(_name);
    self.shader = glsl::loadShader("", shader_path.tconcat(".fs"));
    if(rl::isShaderValid(self.shader)) {
        self.name = _name.tcopy();
        self.id = (int)pplist.len(); // we use the past list lenght as the index. Because is 1 minus the current lenght like what indices are... 
        pplist.push(self);
    } else {
        unreachable("failed to load required post process shader %s!", _name);
    }
}

fn void HMPostProcess.unload(&self) 
{
    pplist[self.id] = null;
    if(rl::isShaderValid(self.shader))  glsl::unloadShader(&self.shader);
}

fn int getPostProcessIdxFromName(String _name) @inline 
{
    foreach(it : pplist) {
        if(it.name == _name) return it.id;
    }
    return -1;
}

fn HMPostProcess* getPostProcessFromID(int idx) @inline 
{
    return pplist[idx];
}

fn HMPostProcess* getPostProcessFromName(String _name) @inline 
{
    int indice = getPostProcessIdxFromName(_name);
    if(indice < 0) {
        io::printf("failed to find post process shader %s.", _name);
        return null;
    }
    return getPostProcessFromID(indice);
}

fn void HMPostProcess.update(&self) {
  @todo();
}

macro HMPostProcess.@apply(&self, RenderTexture* layer; @body) {
    self.shader.setUniformTexture("texture0", layer.texture);
    rl::@shaderMode(self.shader)
    {
        @body();
    };
}