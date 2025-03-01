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

module game::camview;

// region c3 modules
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
// end_region

// region custom modules
import engine::misc;
import game::main;
import game::assets::sprt; // sprite
import game::actors::ent::pl;
import engine::filesystem::fs;
import raylib5::rl;
import raygui5::rgui;
import raylib5::rmath;
import game::serialize::svs; // save system
import engine::logging::lgr;
// end_region

/*
    NOTE(HM) 
    
    ** world view space **
    
    0,0___________
    | __ +x       |
    | |           |
    | +y          |
    |             |
    |             |
    |_____________|
    
    world_matrix:
    s = scale
    r = rotation
    t = translation
    |1 0 0| = |sx ry 0|
    |0 1 0|   |rx sy 0|
    |0 0 1|   |tx ty 1|
    
    ** camera coordinate space **
    
     _____________
    |             |
    |     -y      |
    | -x __|__ +x |
    |      |      |
    |     +y      |
    |_____________|
    
    -z is towards the viewer (not used for now...)
    
    ** entity/model space **
    
    [3D]
    
    +z up
    ^
    |__> +x right
    
    +y is towards the viewer (this is also model forward)
    
    [2D] = (camera coordinate space)
    
    canonical view square
    | -1,-1   0,-1   1,-1 |   |     -1     |
    | -1, 0   0, 0   1, 0 | = | -1___|___1 |
    | -1, 1   0, 1   1, 1 |   |      1     |
*/

/*
* Row Major*
|sx ry tx|   |m00 m01 m02|
|rx sy ty| = |m10 m11 m12|
| 0  0  1|   |m20 m21 m22|
*/

const Matrix3f VIEW_AXIS_IDENTITY = {
    1.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 1.0f
};

def gameptr = main::gpGame;

const bool ENABLE_CAMERA_VIEW = true;

enum ZoomMode : char @if ($defined(ENABLE_CAMERA_VIEW))
{
    MOUSE_WHEEL,
    MOUSE_MOVE
}

distinct RenderLayer = inline RenderTexture2D;

def RenderFunctionCallback = fn void(RenderLayer* layer, int w = 0, int h = 0);

struct RenderView (SaveSystemInterface)
{
    RenderLayer sceneFrameBuffer;
    RenderLayer guiFrameBuffer;
    RenderLayer postGuiFrameBuffer;
    // function pointers
    RenderFunctionCallback guiFrameBufferCallback;
    RenderFunctionCallback postGuiFrameBufferCallback;
    //
    RenderLayer* currentRender;
    bool taking_screenshot;
    
    Matrix3f axis; // view axis
    
    Camera2D camera    @if ($defined(ENABLE_CAMERA_VIEW));
    ZoomMode zoom_mode @if ($defined(ENABLE_CAMERA_VIEW));
}

fn void RenderView.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void RenderView.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void RenderView.init(&self, int screenWidth, int screenHeight) @inline {
    // @testing...
    self.sceneFrameBuffer   = (RenderLayer)rl::loadRenderTexture(screenWidth, screenHeight);
    self.guiFrameBuffer     = (RenderLayer)rl::loadRenderTexture(screenWidth, screenHeight);
    self.postGuiFrameBuffer = (RenderLayer)rl::loadRenderTexture(screenWidth, screenHeight);
    //
    self.guiFrameBufferCallback     = &renderGuiFBO;
    self.postGuiFrameBufferCallback = &renderPostGuiFBO;
    // NOTE(HM) used to point to the main render layer to be used for shaders and such if necessary
    self.currentRender              = &self.sceneFrameBuffer;
    
    self.axis = VIEW_AXIS_IDENTITY;
    
$if $defined(ENABLE_CAMERA_VIEW):
    // sets camera view target and view direction
    self.camera.target = { screenWidth / 2.0f, screenHeight / 2.0f };
    // move the view axis center to be the target 
    self.axis.translate(self.camera.target.toVec2f());
    
    // sets how far the camera is from the view target
    // right now theres no offset for the target
    self.camera.offset = self.camera.target;
   
    // NOTE(HM) To simplify things camera rotation will not be possible
    self.camera.rotation = 0.0f;
    //
    self.camera.zoom = 1.0f;
    self.zoom_mode   = MOUSE_WHEEL;
$endif

}

fn void RenderView.deinit(&self) {
     // Unload render texture (FBO)
    rl::unloadRenderTexture(self.sceneFrameBuffer);
    rl::unloadRenderTexture(self.guiFrameBuffer);
    rl::unloadRenderTexture(self.postGuiFrameBuffer);
    self.guiFrameBufferCallback     = null;
    self.postGuiFrameBufferCallback = null;
    self.currentRender              = null;
}

fn void RenderView.debug(&self) {
    Rectangle rec = {
        .x = 0,
        .y = 0,
        .width  = self.currentRender.texture.width,
        .height = self.currentRender.texture.height
    };
    
    rl::drawRectangleLinesEx(rec, 2.5f, rl::RED);
    String view_data_text = string::tformat("Screen Size: {%.2f, %.2f}", rec.width, rec.height);
    rl::drawText(view_data_text.zstr_copy(), 100, 10, 30, rl::RED);
    //rl::drawTextEx(*main::gpGame.candara_font, "TEXT DRAWN IN RENDER TEXTURE", {10, 30}, 16.0f, 2.0f, rl::COLOR_RED);
    //rl::drawLine((int)self.camera.target.x, -(int)rec.height*10, (int)self.camera.target.x, (int)rec.height*10, rl::COLOR_GREEN);
    //rl::drawCircleV(self.camera.target, 16.0f, rl::COLOR_RED);
    //rl::drawRectangle(-6000, 320, 13000, 8000, rl::DARKGRAY);
}


// NOTE(HM) This is now really inconvinient
// This is because I found Raysan decided to not give a way 
// to overrride the screenshot key, inlike the quit key,
// so if I use this with another key than F12 or 
// I call rl::takeScreenshot() I will take TWO screenshots!! :(
fn void takeScreenShot() {
    unreachable();
    String shots_dir = main::gpGame.app_work_dir.tconcat("screenshots\\");
    if(fs::directoryExists(shots_dir) == false) {
        bool! sucess = fs::makeDirectory(shots_dir);
        if(catch excuse = sucess) {
            lgr::warning(Where.FILE, "Cannot create screenshots directory at: %s!\n\t -> excuse: %s", 
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
    FilePathList files = fs::loadDirectoryFilesEx(shots_dir, ".png", scanSubdirs: false);
    
    defer {
        // at the end return everything to defaults
        fs::unloadDirectoryFiles(files);
        //lgr::info(Where.CONSOLE, "current dir after all = %s", rl::getWorkingDirectory());
        if(bytes_count) {
            // return to main work dir
            fs::changeDirectory(main::gpGame.app_work_dir)!!;
            rl::unloadFileData(saved_shot_file);
            // and try to delete older file
            @catch(file::delete(shotname.str_view()));
        }
    }
    
    if(files.count) file_count = files.count++;
    shotname = string::tformat("screen%d.png", file_count).zstr_copy();
    rl::takeScreenshot(shotname); // saves it in the application .exe folder
    
    // move the image to the screenshot folder
    // first load image data to memory
    saved_shot_file = (ZString)rl::loadFileData(shotname, &bytes_count);
    char[] shot = fs::fileLoadEntireBytes(shotname.str_view());
    if(bytes_count) {
        // then change to dir where you want to save the image
        if(fs::changeDirectory(shots_dir)!! == true) {
            bool sucess = rl::saveFileData(shotname, (void*)saved_shot_file, bytes_count);
            if( sucess == false) {
                lgr::warning(Where.CONSOLE, "failed to transfer file %s to %s", shotname, shots_dir);
            }
        }
    }
}

fn void moveScreenShots() {
    String shots_dir = main::gpGame.app_work_dir.tconcat("screenshots\\");
    if(fs::directoryExists(shots_dir) == false) {
        bool! sucess = fs::makeDirectory(shots_dir);
        if(catch excuse = sucess) {
            lgr::warning(Where.FILE, "Cannot create screenshots directory at: %s!\n\t -> excuse: %s", 
                        shots_dir, excuse);
            $if $feature(_DEBUG):
                unreachable();
            $endif
        } 
    }
    
    int bytes_count;
    ZString shotname; // screenshot name
    char[] shot_data;
    
    // count how many shots are in the w folder
    FilePathList files = fs::loadDirectoryFilesEx(main::gpGame.app_work_dir, ".png", scanSubdirs: false);
    for(int i = 0; i < files.count; i++) {
        // move the images to the screenshot folder
        String file_shot_path = string::tformat("%s", (ZString)files.paths[i]);
        shot_data = file::load_temp(file_shot_path)!!;
        if(shot_data.len) {
            String file_name = shots_dir.tconcat(fs::getFileName(file_shot_path));
            @catch(file::save(file_name, shot_data));
            // delete old file
            @catch(file::delete(file_shot_path));
        }
    }
    
    fs::unloadDirectoryFiles(files);
}

fn void RenderView.showAxis(&self) {
    // draw axis coords
    Vec2f axis_org, start, end, pox, poy;
    axis_org = self.getOrigin();
    start    = axis_org;
    // +X coord
    end = start + misc::VEC_RIGHT * (0.10f * gameptr.screen.w);
    misc::draw_arrow(start, end, rl::RED);
    // -X coord
    end = start + misc::VEC_LEFT * (0.10f * gameptr.screen.w);
    rl::drawLineV(start.toVector2(), end.toVector2(), {255, 50, 15, 127});
    // +Y coord arrow
    end = start + misc::VEC_DOWN * (0.10f * gameptr.screen.h);
    misc::draw_arrow(start, end, rl::GREEN);
    // -Y coord
    end = start + misc::VEC_UP * (0.10f * gameptr.screen.h);
    rl::drawLineV(start.toVector2(), end.toVector2(), {10, 255, 15, 127});
}

fn void RenderView.updateAxis(&self, Vec2f new_origin) @inline {
    self.axis.translate(new_origin);
}

/*
* Row Major*
|sx ry tx|   |m00 m01 m02|
|rx sy ty| = |m10 m11 m12|
| 0  0  1|   |m20 m21 m22|
*/
fn Vec2f RenderView.getOrigin(&self) @inline {
    return {self.axis.m02, self.axis.m12};
}

fn void RenderView.cameraControls(&self) @inline {
$if $feature(_DEBUG):
    // Camera translation controls
    if (rl::isKeyDown(rl::KEY_A)) {
        self.camera.target.x--;
        self.updateAxis(self.camera.target.toVec2f());
    }
    if (rl::isKeyDown(rl::KEY_D)) {
        self.camera.target.x++;
        self.updateAxis(self.camera.target.toVec2f());
    }
    if (rl::isKeyDown(rl::KEY_W)) {
        self.camera.target.y--;
        self.updateAxis(self.camera.target.toVec2f());
    }
    if (rl::isKeyDown(rl::KEY_S)) {
        self.camera.target.y++;
        self.updateAxis(self.camera.target.toVec2f());
    }
$endif
    
    if (rl::isKeyPressed(rl::KEY_ONE)) {
        self.zoom_mode = (self.zoom_mode == MOUSE_MOVE) ? MOUSE_WHEEL : MOUSE_MOVE;
    }

    if (rl::isMouseButtonDown(MouseButton.RIGHT))
    {
        Vector2 delta = rl::getMouseDelta();
        delta = rmath::vector2Scale(delta, -1.0f/self.camera.zoom);
        self.camera.target = rmath::vector2Add(self.camera.target, delta);
    }
    
    switch(self.zoom_mode)
    {
        case MOUSE_WHEEL:
            float wheel = rl::getMouseWheelMove();
            if (wheel != 0)
            {
                // Get the world point that is under the mouse
                Vector2 mouseWorldPos = rl::getScreenToWorld2D(rl::getMousePosition(), self.camera);

                // Set the offset to where the mouse is
                self.camera.offset = rl::getMousePosition();

                // Set the target to match, so that the camera maps the world space point 
                // under the cursor to the screen space point under the cursor at any zoom
                self.camera.target = mouseWorldPos;

                // Zoom increment
                float scaleFactor = 1.0f + (0.25f*math::abs(wheel));
                if (wheel < 0) scaleFactor = 1.0f/scaleFactor;
                self.camera.zoom = math::clamp(self.camera.zoom*scaleFactor, 0.125f, 64.0f);
            }
        case MOUSE_MOVE:
            // Zoom based on mouse left click
            if (rl::isMouseButtonPressed(MouseButton.LEFT))
            {
                // Get the world point that is under the mouse
                Vector2 mouseWorldPos = rl::getScreenToWorld2D(rl::getMousePosition(), self.camera);

                // Set the offset to where the mouse is
                self.camera.offset = rl::getMousePosition();

                // Set the target to match, so that the camera maps the world space point 
                // under the cursor to the screen space point under the cursor at any zoom
                self.camera.target = mouseWorldPos;
            }
            if (rl::isMouseButtonDown(MouseButton.LEFT))
            {
                // Zoom increment
                float deltaX = rl::getMouseDelta().x;
                float scaleFactor = 1.0f + (0.01f*math::abs(deltaX));
                if (deltaX < 0) scaleFactor = 1.0f/scaleFactor;
                self.camera.zoom = math::clamp(self.camera.zoom*scaleFactor, 0.125f, 64.0f);
            }
            default:
    }
        
    // Camera zoom controls
    self.camera.zoom += (rl::getMouseWheelMove() * 0.05f);

    if (self.camera.zoom > 3.0f) {
        self.camera.zoom = 3.0f;
    } else if (self.camera.zoom < 0.1f) {
        self.camera.zoom = 0.1f;
    }
    
    // Camera reset (zoom and rotation)
    if (rl::isKeyPressed(rl::KEY_R))
    {
        self.camera.target   = { main::gpGame.screen.w / 2.0f, main::gpGame.screen.h / 2.0f };
        self.camera.zoom     = 1.0f;
        self.camera.rotation = 0.0f; // this should be always 0.0f...
    }
}

fn void RenderView.update(&self) {
    if(main::developer.getBool()) {
        // for some stupid reason raysan from raylib hardcoded F12 to the screenshot action
        // if(!self.taking_screenshot && rl::isKeyDown(rl::KEY_F2)) {
            // self.taking_screenshot = true;
            // //takeScreenShot();
        // }
        
        // if(rl::isKeyReleased(rl::KEY_F2)) self.taking_screenshot = false;
        
        self.cameraControls();
    }
}

fn void renderSceneFBO(RenderView* view, RenderLayer* layer) @local {
    rl::beginTextureMode(*layer);       // Enable drawing to a texture
        //rl::clearBackground(rl::COLOR_WHITE);  // Clear texture background
        rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
        
$if $feature(ENABLE_CAMERA_VIEW):
        rl::beginMode2D(self.camera);
$endif

        // draw general game sprites
        if(main::gpGame.sprites.len()) {
            foreach(sprite : main::gpGame.sprites) {
                bool not_game_cursor = sprite.kind != SpriteKind.CURSOR;
                if(not_game_cursor) {
                    sprite.draw();
                }
            }
        }
            
        // draw game entities
        if(main::gpGame.entityList.len()) {
            foreach(ent : main::gpGame.entityList) {
                if(ent.alive) {
                    ent.draw();
                }
            }
        }
        
        main::gpGame.boidManager1.draw();
        
$if $feature(_DEBUG):
        //view.debug();
        view.drawWorldSpaceCoords(layer.texture.width, layer.texture.height);
        view.drawCameraSpaceCoords(layer.texture.width, layer.texture.height);
$endif

$if $feature(ENABLE_CAMERA_VIEW):
        rl::endMode2D();
$endif
    
    rl::endTextureMode(); // End drawing to texture (now we have a texture available for next passes)
}

fn void renderGuiFBO(RenderLayer* layer, int w, int h) @inline {
    rl::beginTextureMode(*layer);
    rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
$if $feature(ENABLE_CAMERA_VIEW):
        rl::beginMode2D(self.camera);
$endif
        main::gameOnGuiDraw(w, h);
$if $feature(ENABLE_CAMERA_VIEW):
        rl::endMode2D();
$endif
    rl::endTextureMode(); // End drawing to texture (now we have a texture available for next passes)
}

// NOTE(HM) This renders AFTER the game gui layer
fn void renderPostGuiFBO(RenderLayer* layer, int w, int h) @inline {
    rl::beginTextureMode(*layer);
    rl::clearBackground(rl::fade(rl::WHITE, 0.0f));
$if $feature(ENABLE_CAMERA_VIEW):
        rl::beginMode2D(self.camera);
$endif
        main::gameOnPostGUIDraw(w, h);
$if $feature(ENABLE_CAMERA_VIEW):
        rl::endMode2D();
$endif
    rl::endTextureMode(); // End drawing to texture (now we have a texture available for next passes)
}

fn void RenderView.renderToFBO(&self, int screenWidth, int screenHeight) @inline {
    // region main scene render
    renderSceneFBO(self, &self.sceneFrameBuffer);
    // end_region main scene render
    
    // region GUI Frame Buffer
    self.guiFrameBufferCallback(&self.guiFrameBuffer, screenWidth, screenHeight);
    // end_region GUI Frame Buffer
    
    // region POST GUI Frame Buffer
    self.postGuiFrameBufferCallback(&self.postGuiFrameBuffer, screenWidth, screenHeight);
    // end_region POST GUI Frame Buffer
}

fn void RenderView.draw(&self, int screenWidth, int screenHeight) @inline {
    // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
    rl::drawTextureRec(self.sceneFrameBuffer.texture, { 0, 0, (float)screenWidth, (float)-screenHeight }, { 0, 0 }, rl::WHITE);
    rl::drawTextureRec(self.guiFrameBuffer.texture, { 0, 0, (float)screenWidth, (float)-screenHeight }, { 0, 0 }, rl::WHITE);
    rl::drawTextureRec(self.postGuiFrameBuffer.texture, { 0, 0, (float)screenWidth, (float)-screenHeight }, { 0, 0 }, rl::WHITE);
}

/*
* Row Major*
|sx ry tx|   |m00 m01 m02|
|rx sy ty| = |m10 m11 m12|
| 0  0  1|   |m20 m21 m22|
*/
fn Vec2f RenderView.fromWorldSpaceToView(&self, Vec2f vec) {
    Matrix3f transform = VIEW_AXIS_IDENTITY;
    transform.m02 *= vec.x;
    transform.m12 *= vec.y;
    
    transform =  self.axis.mul(transform);
    
    return {transform.m02, transform.m12};
}

// NOTE(HM) 
// Transforms the view coords from screen coords to -1 to 1
fn Vec2f RenderView.toCanonicalViewSpace(&self, Vec2i vec) {
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

fn void RenderView.drawWorldSpaceCoords(&self, int screenWidth, int screenHeight) @inline @if($feature(_DEBUG)) {
    Rectangle rec = {
        .x = 0,
        .y = 0,
        .width  = screenWidth,
        .height = screenHeight
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
    // drawText(ZString text, int posX, int posY, int fontSize, Color color)
    rl::drawText(x_coord.zstr_copy(), (int)pox.x, (int)pox.y, 10, rl::RED);
    rl::drawText(y_coord.zstr_copy(), (int)poy.x, (int)poy.y, 10, rl::RED);
}

fn void RenderView.drawCameraSpaceCoords(&self, int screenWidth, int screenHeight) @if($feature(_DEBUG)) {

$if $feature(_DEBUG):
    self.showAxis();
$endif

    Color g = {0, 255, 0, 100};
    Color r = {255, 0, 0, 100};
    // vertical line
    rl::drawLine((int)self.camera.target.x, -screenHeight*10, (int)self.camera.target.x, screenHeight*10, g);
    rl::drawText("-Y", (int)self.camera.target.x + 10, (int)(self.camera.target.y - (0.95f*(screenHeight/2.0f))), 10, g);
    // horizontal line
    rl::drawLine(-screenWidth*10, (int)self.camera.target.y, screenWidth*10, (int)self.camera.target.y, r);
    rl::drawText("+X", (int)(self.camera.target.x + (0.95f*(screenWidth/2.0f))), (int)self.camera.target.y + 10, 10, r);
    //rl::drawCircleV(self.camera.target, 10.0f, rl::GREEN);
}
