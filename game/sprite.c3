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
import game::main;
import engine::misc;
import game::camview;
import engine::assets::astmng; //@deprecated;  // asset manager 
import engine::assets_api::asapi; //@deprecated; // for the asset
import game::material::mtr;
import game::material::manager::mtrmng;
import engine::logging::lgr;
import game::serialize::svs; // save system
import game::lowlevel::bounds;
import game::actors::ent;
import thirdparty::raylib5::rl;
import thirdparty::tracy;
// end_region

// region defines
alias assetManager @local = astmng::assetManager;
// end_region

// region constants
const int MIN_SPRIT_SIZE @local = 1; // pixels
const Vec2i MIN_SIZE @local = {MIN_SPRIT_SIZE, MIN_SPRIT_SIZE};
//
// NOTE(HM) Uncoment this to enable the sprite profilling
//const int SPRITE_PROFILE = 1;
// NOTE(HM) Uncoment this to show debug boxes for the sprites
//const int DEBUG_SPRITES = 1;

// Used for very special sprites only
enum SpriteKind : int {
    GENERIC,
    CURSOR,
}

<*
    @param value "the inderlying ordinal value from the kind enum"
    @require value >= 0 && value < SpriteKind.elements
*>
fn SpriteKind kindFrom(int value) @inline {
  return SpriteKind.from_ordinal(value);
}
// end_region defines

struct Sprite (SaveSystemInterface)
{
    typeid type; // class type
    SpriteKind kind; // object type
    //
    Rectangle rect;
    RColor color;  // only used for when a material is not defined.
    Asset* tex @deprecated;
    HMaterial* mat;
    Bounds bounds; // will be equal to the rectangle
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
        //ZString text = string::tformat("%s", source).tcopy();
        //rl::drawText(text, 500, 25, 15, rl::RAYWHITE);
        main::update_game_cursor(main::gpGame.screen.w, main::gpGame.screen.h);
    }
}

fn void Sprite.init(&self, float x, float y, int width, int height, RColor color, SpriteKind kind = GENERIC, String material_name = "")
{
    self.type  = Sprite.typeid;
    //
    self.kind  = kind;
    self.color = color;
    self.setPosition( x, y );
    self.setSize( width, height );
    // now set the Bounds
    self.bounds.fromRect(&self.rect);
    self.setMaterial(material_name);
    self.register();
}

fn void Sprite.initRec(&self, Rectangle rect, RColor color = rl::COLOR_WHITE, SpriteKind kind = GENERIC, String material_name = "") @inline {
    self.init(rect.x, rect.y, (int)rect.width, (int)rect.height, color, kind, material_name);
}

fn void Sprite.initV(&self, Vec2f pos, Vec2f size, RColor color, SpriteKind kind = GENERIC, String material_name = "") @inline {
    self.initRec({ pos.x, pos.y, size.x, size.y }, color, kind, material_name);
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

fn bool Sprite.equal(&self, Sprite* other) //@operator(==) 
{
    return (self.kind  == other.kind  &&
            self.rect  == other.rect  &&
            self.color == other.color);
}


// WARNING(HM) setSize and scale are diferent things!!!
<*
* @param w_scaler "amout of scaling for width 0 to INF"
* @param h_scaler "amout of scaling for height 0 to INF"
* @require w_scaler >= 0.0f
* @require h_scaler >= 0.0f
*>
fn void Sprite.scale(&self, float w_scaler, float h_scaler) @inline 
{
    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
}

<*
* @param scaler "scaling info"
* @require scaler.x >= 0.0f
* @require scaler.y >= 0.0f
*>
fn void Sprite.scaleV(&self, Vec2f scaler) @inline {
    self.scale(scaler.x, scaler.y);
}

// overrides the size of the sprite
fn void Sprite.setSize(&self, uint w, uint h) @inline {
    if(w == 0 && h == 0) {
        w = h = MIN_SPRIT_SIZE;
    }
    
    self.rect.width  = (float)w;
    self.rect.height = (float)h;
}

// overrides the size of the sprite
fn void Sprite.setSizeV(&self, Vec2f size) @inline {
    if(size.x && math::is_approx(size.x, 0.0f, 0.05f) && 
       size.y && math::is_approx(size.x, 0.0f, 0.05f))
    {
        size.x = size.y = MIN_SPRIT_SIZE;
    }
    
    self.rect.width  = size.x;
    self.rect.height = size.y;
}

// overrides the size of the sprite
fn void Sprite.setSizeX(&self, uint v) @inline {
    self.rect.width  = (float)v;
}

// overrides the size of the sprite
fn void Sprite.setSizeY(&self, uint v) @inline {
    self.rect.height = (float)v;
}

fn void Sprite.addToSize(&self, uint w, uint h) @inline {
    self.rect.width  += (float)w;
    self.rect.height += (float)h;
}

// overrides the size of the sprite
fn void Sprite.addToSizeV(&self, Vec2f size) @inline {
    self.rect.width  += size.x;
    self.rect.height += size.y;
}

// in screen pixel coordinates
fn Vec2f Sprite.getSize(&self) @inline {
    return self.rect.getSize().toVec2f();
}

// in screen pixel coordinates
fn float Sprite.getSizeX(&self) @inline {
    return self.rect.getSize().toVec2f().x;
}

// in screen pixel coordinates
fn float Sprite.getSizeY(&self) @inline {
    return self.rect.getSize().toVec2f().y;
}

// in screen pixel coordinates
fn Vec2i Sprite.getSizei(&self) @inline {
    return (Vec2i)self.rect.getSize().toVec2f();
}

fn void Sprite.setKind(&self, int kind) @inline => self.kind = kindFrom(kind);

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
fn Vec2f Sprite.getPos(&self) @inline => self.rect.getPosition().toVec2f();

fn bool Sprite.isValid(&self) {
    if(self.rect.x >= 0 &&
       self.rect.y >= 0 &&
       self.rect.width  >= MIN_SPRIT_SIZE && 
       self.rect.height >= MIN_SPRIT_SIZE ) return true;
       
    return false;
}

fn void Sprite.setTexture(&self, String texture_name_with_ext) @inline {

    if(texture_name_with_ext == "") return;
    
    self.tex = main::asstManager.getAssetExt(texture_name_with_ext, Texture2D.typeid);
    assert(rl::isTextureValid(*(Texture2D*)self.tex.data.ptr));
}

fn void Sprite.setMaterial(&self, String material_name) @inline {

    if(material_name) 
    {
        self.mat = mtrmng::getMaterial(material_name);
        if(self.mat == null || rl::isTextureValid(self.mat.diffuse.tex) == false) {
            lgr::error(Where.FILE, "Unnable to set Sprite material '%s'.\n", material_name);
            unreachable("Unnable to set Sprite material.");
        }
    } else {
        self.mat = mtrmng::getMaterial("default_material");
    }
}

fn bool Sprite.hasMaterial(&self) @inline {
   return self.mat != null && rl::isTextureValid(self.mat.diffuse.tex);
}

<*
* @param out texture "pointer to sprite image texture"
* @ensure return != null
*>
fn Texture2D* Sprite.getTexture(&self) @inline {
    if(self.asTexture()) {
        if(self.tex) {
            return (Texture2D*)self.tex.data.ptr;
        } else if(self.mat) {
            return &self.mat.diffuse.tex;
        }
    }
    
    return null;
}

fn bool Sprite.asTexture(&self) @inline {
   return self.tex != null;
}

// in screen pixel coordinates
fn Vec2i Sprite.getTextureSize(&self) @inline {
    if(self.asTexture() == false) return {0,0};

    int w,h;
    if(self.tex) {
        w = (int)((Texture2D*)self.tex.data.ptr).width;
        h = (int)((Texture2D*)self.tex.data.ptr).height;
    } else if(self.mat) {
        w = (int)self.mat.diffuse.tex.width;
        h = (int)self.mat.diffuse.tex.height;
    }
    
    return {w,h};
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

fn void Sprite.draw(&self)  @inline 
{
    misc::@profile_zone("Sprite Draw")
    {
    tracy::@zoneN("sprite draw", 0)
    {
        if(self.should_hide) return;
        
        $if $defined(DEBUG_SPRITES):
            rl::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
        $endif
        
        if(self.hasMaterial())
        {
            Texture2D* texture = &self.mat.diffuse.tex;
            Vec2f texture_size = { texture.width, texture.height };
            Rectangle source = { 0, 0, texture_size.x, texture_size.y };
            Rectangle* dist = &self.rect;

            Color color = self.mat.diffuse.color;

            BlendMode blending;
            switch (self.mat.coverage)
            {
                case MatMC.OPAQUE: break; // do nothing here
                case MatMC.PERFORATED:
                    blending = BlendMode.ALPHA;
                case MatMC.TRANSLUCENT:
                    blending = BlendMode.ALPHA_PREMUL;
                    if(color.a >= 1.0f)
                    {
                        color.a = 128; // half transparent
                        float r = misc::@mapValueRangeToOther(color.r, 0, 255, 0.0f, 1.0f);
                        float g = misc::@mapValueRangeToOther(color.g, 0, 255, 0.0f, 1.0f);
                        float b = misc::@mapValueRangeToOther(color.b, 0, 255, 0.0f, 1.0f);
                        float a = misc::@mapValueRangeToOther(color.a, 0, 255, 0.0f, 1.0f);

                        color.r = (char)math::floor((r * a) * 255);
                        color.g = (char)math::floor((g * a) * 255);
                        color.b = (char)math::floor((b * a) * 255);
                    }
                case MatMC.BAD:
                    lgr::error(Where.FILE, "Panel with material %s has a bad material coverage type.", self.mat.name);
                    unreachable();
                break;
            }

            switch (blending)
            {
                case BlendMode.ALPHA:
                case BlendMode.ALPHA_PREMUL:
                    rl::@blendMode(blending)
                    {
                        rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                    };
                default: // opaque unless the image has invisible pixels...
                    // NOTE(HM) center of the texture (rotation/scale point), 
                    // it's relative to destination rectangle dimentions, not the screen dimentions.
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
            }
        } else {
            if(self.asTexture())
            {
                // Source rectangle (part of the texture to use for drawing)
                Vec2i texture_size = self.getTextureSize();
                Rectangle source = {0.0f, 0.0f, (float)texture_size.x, (float)texture_size.y};
                // Destination rectangle (screen rectangle where to draw part of texture)
                Rectangle* dist  = &self.rect;
                // Origin of the texture (rotation/scale point), 
                // is relative to destination rectangle size/area NOT the screen!!!
                Vector2 image_center       = {0, 0};
                const float IMAGE_ROTATION = 0.0f;
                if(self.tex) {
                    rl::drawTexturePro(*(Texture2D*)self.tex.data.ptr, source, *dist, image_center, IMAGE_ROTATION, self.color);
                } else if(self.mat) {
                    rl::drawTexturePro(self.mat.diffuse.tex, source, *dist, image_center, IMAGE_ROTATION, self.mat.diffuse.color);
                } else {
                    //lgr::error(Where.CONSOLE, "Sprite '%s' set to have a texture but has none.\n", self.name);
                    unreachable("Sprite set to have a texture but has none.");
                }
            } else {
                rl::drawRectangleRec(self.rect, self.color);
            }
        }
    };//tracy::@zoneN
    }; // misc::@profile_zone
}

///////////////////////////////////// PARTICLE ///////////////
module game::assets::part;
// UNFINISHED...

// region user module
import thirdparty::raylib5::rl;
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
alias assetManager @local = astmng::assetManager;
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
struct ParticleSpawner
{
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
    //self.super.stopThinking();
    //self.stopThinking();
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


