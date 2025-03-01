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

module game::assets::sprt;

// region C3 modules
import std::io;
import std::core::mem; // for malloc
import std::math;
import std::collections::map;
// end_region

// region other modules
import game::main;
import engine::misc;
import engine::assets::astmng; // asset manager
import engine::assets_api::asapi; // for the asset
import engine::logging::lgr;
import game::serialize::svs; // save system
import game::actors::ent;
import raylib5::rl;
// end_region

// region defines
def assetManager = astmng::assetManager @local;
// end_region

// region constants
const int MIN_SPRIT_SIZE @local = 4; // pixels
const Vec2i MIN_SIZE @local = {MIN_SPRIT_SIZE, MIN_SPRIT_SIZE};
//
// NOTE(HM) Uncoment this to enable the sprite profilling
//const int SPRITE_PROFILE = 1;
// NOTE(HM) Uncoment this to show debug boxes for the sprites
const int DEBUG_SPRITES = 1;

// Used for very special sprites only
enum SpriteKind : int {
    GENERIC,
    CURSOR,
}

fn SpriteKind SpriteKind.of(int value) @operator(construct)
{
  return SpriteKind.from_ordinal(value);
}
// end_region defines

struct Sprite (SaveSystemInterface)
{
    typeid type; // class type
    SpriteKind kind; // object type
    //
    Rectangle rect;
    RColor color;
    Asset* tex;
    //
    union {
        bool isHidden;
        bool should_hide;
    }
}

fn void Sprite.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Sprite.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void Sprite.register(&self) @inline {
    main::gpGame.sprites.push(self);
}

fn void Sprite.update(&self) @inline {
    if(self.isHidden) return;
    
    if(self.kind == SpriteKind.CURSOR) {
        //ZString text = string::tformat("%s", source).zstr_copy();
        //rl::drawText(text, 500, 25, 15, rl::RAYWHITE);
        main::update_game_cursor(main::gpGame.screen.w, main::gpGame.screen.h);
    }
}

fn void Sprite.init(&self, float x, float y, float width, float height, RColor color, SpriteKind kind = GENERIC, String asset_name = "") @inline {
    self.type  = Sprite.typeid;
    //
    self.kind  = kind;
    self.color = color;
    self.setPosition( x, y );
    self.setSize( (int)width, (int)height );
    self.setTexture(asset_name);
$if $feature(_DEBUG):   
    assert(self.isValid() == true);
$endif
    self.register();
}

fn void Sprite.initRec(&self, Rectangle rect, RColor color = rl::COLOR_WHITE, SpriteKind kind = GENERIC, String asset_texture_name = "") @inline {
    self.init(rect.x, rect.y, rect.width, rect.height, color, kind, asset_texture_name);
}

fn void Sprite.initV(&self, Vec2f pos, Vec2f size, RColor color, SpriteKind kind = GENERIC, String asset_texture_name = "") @inline {
    self.initRec({ pos.x, pos.y, size.x, size.y }, color, kind, asset_texture_name);
}

fn void Sprite.resetPosSize(&self) @inline {
    self.setPositionV({0, 0});
    self.setSizeV(MIN_SIZE);
}

fn void Sprite.deinit(&self) @inline {
    //self.rect  = {};
    //self.color = {0xFF, 0xFF, 0xFF, 0x00}; // INVISIBLE_COLOR
    //self.isHidden         = true;
    if(self.asTexture()) self.tex = null;
}


// WARNING(HM) setSize and scale are diferent things!!!
<*
* @param w_scaler "amout of scaling for width"
* @param h_scaler "amout of scaling for height"
* @require w_scaler <= 0 && w_scaler >= -1.0f || w_scaler >= 0 && w_scaler <= 1.0f
* @require h_scaler <= 0 && h_scaler >= -1.0f || h_scaler >= 0 && h_scaler <= 1.0f
*>
// adds to the current size
fn void Sprite.scale(&self, float w_scaler, float h_scaler) @inline {
    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
}

<*
* @param scaler "scaling info"
* @require scaler.x <= 0.0f && scaler.x >= -1.0f || scaler.x >= 0.0f && scaler.x <= 1.0f
* @require scaler.y <= 0.0f && scaler.y >= -1.0f || scaler.y >= 0.0f && scaler.y <= 1.0f
*>
// adds to the current size
fn void Sprite.scaleV(&self, Vec2f scaler) @inline {
    self.scale(scaler.x, scaler.y);
}

// overrides the size of the sprite
fn void Sprite.setSize(&self, int w, int h) @inline {
    self.rect.width  = (float)w;
    self.rect.height = (float)h;
}

// overrides the size of the sprite
fn void Sprite.setSizeV(&self, Vec2i size) @inline {
    self.rect.width  = (float)size.x;
    self.rect.height = (float)size.y;
}

fn void Sprite.addToSize(&self, int w, int h) @inline {
    self.rect.width  += (float)w;
    self.rect.height += (float)h;
}

// overrides the size of the sprite
fn void Sprite.addToSizeV(&self, Vec2i size) @inline {
    self.rect.width  += (float)size.x;
    self.rect.height += (float)size.y;
}

// in screen pixel coordinates
fn Vec2f Sprite.getSize(&self) @inline {
    return self.rect.getSize().toVec2f();
}

// in screen pixel coordinates
fn Vec2i Sprite.getSizei(&self) @inline {
    return (Vec2i)self.rect.getSize().toVec2f();
}

fn void Sprite.setKind(&self, int kind) @inline => self.kind = SpriteKind.of(kind);

// this is a world position
// overrides the original position of the sprite
fn void Sprite.setPosition(&self, float x, float y) @inline {
    self.rect.x = x;
    self.rect.y = y;
/*
$if $feature(_DEBUG):   
    if(main::gpGame.isPointInsideScreenView({x,y}) == false) {
        unreachable("Sprite origin is outside the view.");
    }
$endif
*/
}

// this is a world position
// overrides the original position of the sprite
fn void Sprite.setPositionV(&self, Vec2f pos) @inline {
    self.setPosition(pos.x, pos.y);
}

// this is a world position
fn void Sprite.addToPosition(&self, float x, float y) @inline {
    self.rect.x += x;
    self.rect.y += y;
    
// $if $feature(_DEBUG):   
    // if(main::gpGame.isPointInsideScreenView({self.rect.x, self.rect.y}) == false) {
        // unreachable("Sprite origin is outside the view.");
    // }
// $endif
}

// this is a world position
fn void Sprite.addToPositionV(&self, Vec2f pos) @inline {
    self.addToPosition(pos.x, pos.y);
}

// this is a world position
fn Vec2f Sprite.getPos(&self) @inline => self.rect.getPos().toVec2f();

fn bool Sprite.isValid(&self) @inline {
    if(self.rect.x >= 0 &&
       self.rect.y >= 0 &&
       self.rect.width  >= MIN_SPRIT_SIZE && 
       self.rect.height >= MIN_SPRIT_SIZE ) return true;
       
    return false;
}

fn void Sprite.setTexture(&self, String texture_name_with_ext) @inline {
    if(texture_name_with_ext == "") return;
    
    self.tex = main::asstManager.getAssetExt(texture_name_with_ext, Texture2D.typeid);;
    assert(rl::isTextureValid(*(Texture2D*)self.tex.data.ptr));
}

<*
* @param out texture "pointer to sprite image texture"
* @ensure return != null
*>
fn Texture2D* Sprite.getTexture(&self) @inline {
    if(self.asTexture()) return (Texture2D*)self.tex.data.ptr;
    
    return null;
}

fn bool Sprite.asTexture(&self) @inline {
   return self.tex != null;
}

// in screen pixel coordinates
fn Vec2i Sprite.getTextureSize(&self) @inline {
    int w,h;
    w = (int)((Texture2D*)self.tex.data.ptr).width;
    h = (int)((Texture2D*)self.tex.data.ptr).height;
    if(self.asTexture()) return {w,h};
    
    return {0,0};
}

fn void Sprite.hide(&self) @inline {
    if(self.isHidden) return;
    self.isHidden = true;
}

fn void Sprite.show(&self) @inline {
    if(!self.isHidden) return;
    self.isHidden = false;
}

fn bool Sprite.hidden(&self) @inline => self.isHidden;

fn Vec2f Sprite.getPosition(&self) @inline {
    return {self.rect.x, self.rect.y};
}

fn void Sprite.draw(&self)  @inline {
$if $defined(SPRITE_PROFILE):
    float sprite_profile_start = @start_profile_zone();
    defer @end_profile_zone(sprite_profile_start);
$endif

    if(self.should_hide) return;
    
$if $defined(DEBUG_SPRITES):
        rl::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
$endif
    
    if(self.asTexture())
    {
        //rl::drawTexture(*self.tex, (int)self.rect.x, (int)self.rect.y, self.color);
        //rl::drawTextureV(*self.tex, self.rect.getPos(), self.color);
        //rl::drawTextureEx(*self.tex, {self.rect.x, self.rect.y}, 0.0f, self.rect.width, self.color);
        
        // Source rectangle (part of the texture to use for drawing)
        Vec2i texture_size = self.getTextureSize();
        Rectangle source = {0, 0, texture_size.x, texture_size.y};
        // Destination rectangle (screen rectangle where to draw part of texture)
        Rectangle* dist  = &self.rect;
        // Origin of the texture (rotation/scale point), 
        // is relative to destination rectangle size/area NOT the screen!!!
        rl::Vec2 image_center       = {0, 0};
        const float IMAGE_ROTATION  = 0.0f;
        rl::drawTexturePro(*(Texture2D*)self.tex.data.ptr, source, *dist, image_center, IMAGE_ROTATION, self.color);
    } else {
        rl::drawRectangleRec(self.rect, self.color);
    }
}

///////////////////////////////////// PARTICLE ///////////////
module game::assets::part;
// UNFINISHED...

// region user module
import raylib5::rl;
import game::main;
import game::assets::sprt;
import std::math::vector;
import game::actors::ent;
import engine::assets::astmng;
import engine::logging::lgr;
import engine::misc;
// end_region

const int DEFAULT_PARTICLE_LIFETIME   = 1000; // ms

// region defines
def assetManager = astmng::assetManager @local;
// end_region

struct Particle
{
    inline Sprite super;
    Vec2f velocity;
    Vec2f dir;
    int lifetime;
    float acceleration;
}

fn void Particle.create(&self, Vec2f pos, Vec2f size, RColor color = rl::WHITE, int lifetime_ms = DEFAULT_PARTICLE_LIFETIME, String tex_name = "") {
    // init the inline sprite data
    self.initV(pos, size, color);
    self.tex          = assetManager.getAssetExt(tex_name, Texture2D.typeid);
    self.lifetime     = main::gpGame.time_ms + lifetime_ms;
    self.dir          = misc::VEC_UP;
    self.velocity     = self.dir;
    self.acceleration = 1.0f;
}

fn void Particle.animate(&self) @inline {
    if(self.lifetime == 0) return;
    
    self.velocity  *= self.acceleration * main::gpGame.dt;
    self.addToPositionV(self.dir * self.velocity);
    if(main::gpGame.time_ms > self.lifetime) self.remove();
}

fn void Particle.stop(&self) @inline {
    self.lifetime = 0;
    self.hide();
}

fn void Particle.remove(&self) @inline {
    self.stop();
    self.deinit();
    //mem::free(self);
}

///////////

const int DEFAULT_PARTICLES_AMOUNT             = 50;
const int DEFAULT_PARTICLES_SIZE               = 10;
const int DEFAULT_PARTICLES_SPAWNER_LIFETIME   = 5000; // ms

// UNFINISHED...
struct ParticleSpawner {
    inline Entity super;
    
    int max_amount;
    int current_amount;
    int part_size;
    int lifetime; // our lifetime not particles lifetime...
    int delay_ms;  // so it doesn't spawn entities imidiatly at activation time
}

fn void ParticleSpawner.init(&self, Vec2f pos, int delay = 0) {
    String name = string::tformat("%s%s", "ParticleSpawner_", main::gpGame.time_ms);
    RColor color = misc::INVISIBLE_COLOR;
$if $feature(_DEBUG):
    color = rl::RED;
$endif
    // init the inlined entity data
    self.super.init(name, pos, color);
    self.max_amount = DEFAULT_PARTICLES_AMOUNT;
    self.part_size  = DEFAULT_PARTICLES_SIZE;
    self.lifetime   = DEFAULT_PARTICLES_SPAWNER_LIFETIME;
    self.delay_ms   = delay;
    self.activate();
}

fn void ParticleSpawner.reset(&self) {
    self.current_amount = DEFAULT_PARTICLES_AMOUNT;
    self.lifetime       = DEFAULT_PARTICLES_SPAWNER_LIFETIME;
}

fn void ParticleSpawner.setMaxAmount(&self, int new_max) @inline {
    self.max_amount = new_max;
}

fn void ParticleSpawner.setParticleSize(&self, int size) @inline {
    self.part_size = size;
}

fn void ParticleSpawner.activate(&self) @inline {
    if(self.delay_ms) {
        self.delay_ms = main::gpGame.time_ms + self.delay_ms;
        self.lifetime = self.delay_ms + self.lifetime;
    } else {
        self.lifetime = main::gpGame.time_ms + self.lifetime;
    }
    self.super.startThinking();
    self.startThinking();
}

fn void ParticleSpawner.deactivate(&self) @inline {
    unreachable();
    self.super.stopThinking();
    self.stopThinking();
}

fn void ParticleSpawner.spawnParticle(&self) {
    Particle* part = allocator::new(&main::gameArena, Particle);
    part.create(self.getPosition(), {self.part_size, self.part_size}, self.vs.color);
    part.animate();
}

// TODO(HM) Create a CPU thread for this?
fn void ParticleSpawner.think(&self) {
   self.super.think(main::gpGame.dt);
    
    if(self.flags & ent::TH_THINK)
    {
        int current_time = main::gpGame.time_ms;
        lgr::info(Where.CONSOLE, "Entity '%s' has flag %s!!!\n", self.name, self.flags);
        if(current_time < self.delay_ms) {
           // do nothing
        }
        else if(current_time <= self.lifetime) {
            if(self.current_amount <= self.max_amount) {
                self.spawnParticle();
                self.current_amount++;
            } else {
                self.deactivate();
            }
        }
    }
}


