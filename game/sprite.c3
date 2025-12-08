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
//import engine::assets_api::asset; // for the asset system
import engine::assets_api::astmng; // asset manager
import game::material::mat;
import game::material::manager::mtrmng;
import engine::logging::log;
import game::serialize::svs; // save system
import game::lowlevel::bounds;
import game::actors::ent;
import thirdparty::raylib5::rl;
import engine::sys::render2d::r2d; // 2D rendering
import thirdparty::tracy;
// end_region

// region defines
alias assetManager @local = astmng::assetManager;
// end_region

// region constants
const MIN_SPRIT_SIZE @local = misc::MINIMUM_SIZE_IN_METERS;
const Vec2f MIN_SIZE @local = {MIN_SPRIT_SIZE, MIN_SPRIT_SIZE};

//
// NOTE(HM) Uncoment this to enable the sprite profilling
//const int SPRITE_PROFILE = 1;
// NOTE(HM) Uncoment this to show debug boxes for the sprites
//const int DEBUG_SPRITES = 1;

// Used for very special sprites only
enum SpriteKind : const int 
{
    GENERIC = 0,
    CURSOR,
}

<*
    @param value : "the inderlying ordinal value from the kind enum"
    @require value >= 0 && value < SpriteKind.values.len
*>
fn SpriteKind kindFrom(int value) @inline @local
{
  return (SpriteKind)value;
}
// end_region defines

struct SpriteFlags
{
     union { // does this really should be a union?
        bool isHidden;
        bool should_hide;
    }
    bool isActive; // if the sprite is active or not
}

struct Sprite (SaveSystemInterface)
{
    typeid type; // class type
    SpriteKind kind; // object kind, used to differentiate between different sprite types

    // flags for the sprite, used to hide it or show it
    // Todo(HM) should we use a bit field for this?
    SpriteFlags flags;

    //
    RLRectangle rect; // position and size of the sprite, screen pixel coordinates and meters scale respectively.
    Bounds bounds; // should be equivalent to the rectangle size
    RLColor color;  // only really used when a material is not defined.

    // Todo(HM) rethink this, should the material be a pointer to a data base loaded in memory
    // or each entity, should copy the material data from the data base
    // and deal with its own copy?
    HMaterial* mat;
}

fn void Sprite.save(&self, SaveFile* file) @dynamic {
    svs::writeTypeid(file, self.type);
    svs::writeInt(file, (int)self.kind);
    svs::writeRect(file, self.rect);
    svs::writeColor(file, self.color);
    // cannot save pointers so just save the material name
    svs::writeString(file, (self.mat != null) ? self.mat.name : "");
}

fn void Sprite.reload(&self, SaveFile* file) @dynamic {
    svs::readTypeid(file, &self.type);
    int kind;
    svs::readInt(file, &kind);
    self.kind = (SpriteKind)kind;//SpriteKind.from_ordinal(kind);
    svs::readRect(file, &self.rect);
    svs::readColor(file, &self.color);
    String mat_name;
    svs::readString(file, &mat_name);
    self.mat = mtrmng::getMaterial(mat_name);
}

fn void Sprite.register(&self) @inline {
    main::gpGame.sprites.push(self);
}

fn void Sprite.init(&self, float x, float y, float width, float height, RLColor color = rl::WHITE, SpriteKind kind = GENERIC, String material_name = "")
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
    self.activate(); // activate the sprite by default
    self.register();
}

fn void Sprite.initRect(&self, RLRectangle rect, RLColor color = rl::WHITE, SpriteKind kind = GENERIC, String material_name = "") @inline {
    self.init(rect.x, rect.y, rect.width, rect.height, color, kind, material_name);
}

fn void Sprite.initV(&self, Vec2f pos, Vec2f size, RLColor color = rl::WHITE, SpriteKind kind = GENERIC, String material_name = "") @inline {
    self.initRect({ pos.x, pos.y, size.x, size.y }, color, kind, material_name);
}

fn void Sprite.resetPosSize(&self) @inline {
    self.setPositionV({0, 0});
    self.setSizeV(MIN_SIZE);
}

fn void Sprite.deinit(&self) @inline {
    if(self.mat) self.mat = null;
}

/*
<*
 @param coverage : "the coverage to compare with"
 @require self.mat != null
*>
fn bool Sprite.equalcoverage(&self, Coverage coverage) //@operator(==)
{
    return (bool)(self.mat.coverage & coverage);
}

<*
 @param coverage : "the coverage to compare with"
 @require self.mat != null
*>
fn bool Sprite.nequalcoverage(&self, Coverage coverage) //@operator(!=)
{
    return (bool)((bool)(self.mat.coverage & coverage) == false);
}
*/

// WARNING(HM) setSize and scale are diferent things!!!
<*
 @param w_scaler : "amout of scaling for width 0 to INF"
 @param h_scaler : "amout of scaling for height 0 to INF"
 @require w_scaler >= 0.0f
 @require h_scaler >= 0.0f
*>
fn void Sprite.scale(&self, float w_scaler, float h_scaler) @inline 
{
    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
}

<*
 @param scaler : "scaling info"
 @require scaler.x >= 0.0f
 @require scaler.y >= 0.0f
*>
fn void Sprite.scaleV(&self, Vec2f scaler) @inline {
    self.scale(scaler.x, scaler.y);
}

// WARNING(HM) setSize and scale are diferent things!!!
// overrides the size of the sprite
fn void Sprite.setSize(&self, float w, float h) @inline 
{
    if(misc::fgetDiff(w, 0.0f) <= 0.05f && misc::fgetDiff(h, 0.0f) <= 0.05f) {
        w = h = MIN_SPRIT_SIZE;
    }
    
    self.rect.width  = w;
    self.rect.height = h;
}

// overrides the size of the sprite
fn void Sprite.setSizeV(&self, Vec2f size) @inline {
    if(misc::fgetDiff(size.x, 0.0f) <= 0.05f && misc::fgetDiff(size.y, 0.0f) <= 0.05f) {
        size.x = size.y = MIN_SPRIT_SIZE;
    }
    
    self.rect.width  = size.x;
    self.rect.height = size.y;
}

// overrides the size of the sprite
fn void Sprite.setSizeX(&self, float w) @inline {
    self.rect.width = w;
}

// overrides the size of the sprite
fn void Sprite.setSizeY(&self, float h) @inline {
    self.rect.height = h;
}

fn void Sprite.addToSize(&self, float w, float h) @inline {
    self.rect.width  += w;
    self.rect.height += h;
}

// overrides the size of the sprite
fn void Sprite.addToSizeV(&self, Vec2f size) @inline {
    self.rect.width  += size.x;
    self.rect.height += size.y;
}

// in meter coordinates
fn Vec2f Sprite.getSize(&self) @inline {
    return self.rect.getSize();
}

// in meter coordinates
fn float Sprite.getSizeX(&self) @inline {
    return self.rect.getSize().x;
}

// in meter coordinates
fn float Sprite.getSizeY(&self) @inline {
    return self.rect.getSize().y;
}

// in screen pixel coordinates
fn Vec2i Sprite.getSizePixels(&self) @inline {
    int w = misc::metersToPixels(self.rect.width);
    int h = misc::metersToPixels(self.rect.height);
    return (Vec2i){ w, h };
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
fn Vec2f Sprite.getPos(&self) @inline => self.rect.getPosition();

fn bool Sprite.isValid(&self) {
    if(self.rect.x >= 0 &&
       self.rect.y >= 0 &&
       self.rect.width  >= MIN_SPRIT_SIZE && 
       self.rect.height >= MIN_SPRIT_SIZE ) return true;
       
    return false;
}

fn void Sprite.setMaterial(&self, String material_name) @inline {

    if(material_name) 
    {
        self.mat = mtrmng::getMaterial(material_name);
        if(self.mat == null || rl::isTextureValid(*self.mat.getTexture(mat::STAGE_DIFFUSE)) == false) {
            log::error(Where.FILE, "Unnable to set Sprite material '%s'.\n", material_name);
            unreachable("Unnable to set Sprite material.");
        }
    } else {
        self.mat = mtrmng::getMaterial("default_material");
    }
}

fn bool Sprite.hasMaterial(&self) @inline {
   return self.mat != null && rl::isTextureValid(*self.mat.getTexture(mat::STAGE_DIFFUSE));
}

fn RLTexture2D* Sprite.getTexture(&self) @inline {
    if(self.hasMaterial()) { return self.mat.getTexture(mat::STAGE_DIFFUSE); }
    
    return null;
}

// in screen pixel coordinates
fn Vec2i Sprite.getTextureSize(&self) @inline 
{
    if(self.hasMaterial() == false) return {0,0};

    int w = (int)self.mat.getTexture(mat::STAGE_DIFFUSE).width;
    int h = (int)self.mat.getTexture(mat::STAGE_DIFFUSE).height;

    return {w,h};
}

fn void Sprite.hide(&self) @inline {
    if(self.flags.isHidden) return;
    self.flags.isHidden = true;
}

fn void Sprite.show(&self) @inline {
    if(!self.flags.isHidden) return;
    self.flags.isHidden = false;
}

fn bool Sprite.hidden(&self) @inline => self.flags.isHidden;

fn Vec2f Sprite.getPosition(&self) @inline {
    return {self.rect.x, self.rect.y};
}

fn void Sprite.activate(&self) @inline 
{
    if(self.flags.isActive) return; // already active

    self.flags.isActive = true;
    if(self.flags.isHidden) {
        self.show(); // if the sprite is hidden, we need to show it
    }
}

fn void Sprite.deactivate(&self, bool should_hide = false) @inline 
{
    if(!self.flags.isActive) return; // already inactive

    self.flags.isActive = false;
    if(should_hide) self.hide();
}

fn bool Sprite.isActive(&self) @inline 
{
    return self.flags.isActive;
}

fn bool Sprite.notActive(&self) @inline 
{
    return !self.flags.isActive;
}

fn void Sprite.update(&self) @inline 
{
    if(self.flags.isHidden) return;
    
    if(self.notActive()) {
        // if the sprite is not active, we don't need to update it
        return;
    }

    // update the in-game cursor
    if(self.kind == SpriteKind.CURSOR) {
        main::update_game_cursor(main::gpGame.screen.w, main::gpGame.screen.h);
    }
}

macro @drawSprite(#s, #b, #t, #ra, #rb, #c) @local 
{
    rl::@blendMode(#b)
    {
        if(#s.mat.shader.isValid())
        {
            rl::@shaderMode(#s.mat.shader) // draw using the sprite shader
            {
                rl::drawTexturePro(#t, #ra, #rb, {0, 0}, 0.0f, #c);
            };
        } else { // draw using the default shader
            rl::drawTexturePro(#t, #ra, #rb, {0, 0}, 0.0f, #c);
        }
    };
}

fn void Sprite.draw(&self)  @inline 
{
    misc::@profile_zone("Sprite Draw")
    {
    tracy::@zoneN("sprite draw", 0)
    {
        if(self.flags.should_hide) return;

        RLRectangle rect = self.rect;
        switch (main::CURRENT_UNITS)
        {
            case main::UNITS_METER:
                //rect.x = misc::metersToPixels(self.rect.x);
                //rect.y = misc::metersToPixels(self.rect.y);
                rect.width  = misc::metersToPixels(self.rect.width);
                rect.height = misc::metersToPixels(self.rect.height);
            case main::UNITS_PIXEL:
                rect;  // do nothing already in pixels
            default:
                log::error(Where.FILE, "Unsupported units set for Sprite rendering.", self.kind);
                unreachable();
        }
        
        $if $defined(DEBUG_SPRITES):
            r2d::drawRectangleLinesEx(rect, 1.0f, rl::RED);
        $endif
        
        if(self.hasMaterial())
        {
            RLTexture2D* texture = self.mat.getTexture(mat::STAGE_DIFFUSE);
            Vec2f texture_size = { texture.width, texture.height };
            RLRectangle source = { 0, 0, texture_size.x, texture_size.y };
            RLRectangle* dist = &rect;

            MaterialStage* diffuse_stage = self.mat.getStage(mat::STAGE_DIFFUSE);
            assert(diffuse_stage != null, "RLMaterial diffuse stage is null for material '%s'.", self.mat.name);
            RLColor color = diffuse_stage.color;

            // Todo(HM) Right now, we only do blending per material but we could do it per stage
            // so for example we could have a material with multiple diffuse stages and each stage 
            // could have its own blending mode. This would allow us to have more complex materials.
            RLBlendMode blending;
            Coverage coverage = self.mat.coverage;
            switch
            {
                case (bool)(coverage & mat::COVERAGE_OPAQUE):
                //case diffuse_stage.drawStateBits & mat::BLEND_NONE:
                    break; // do nothing here
                case (bool)(coverage & mat::COVERAGE_PERFORATED) && !(bool)(coverage & mat::COVERAGE_TRANSLUCENT):
                    blending = RLBlendMode.ALPHA;
                case (bool)(coverage & mat::COVERAGE_TRANSLUCENT) && !(bool)(coverage & mat::COVERAGE_PERFORATED):
                //case diffuse_stage.drawStateBits & mat::BLEND_BLEND:
                    blending = RLBlendMode.ALPHA_PREMUL;
                    if(color.a == 255) // if the color is not transparent
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
                case (bool)(coverage & mat::COVERAGE_TRANSLUCENT) && (bool)(coverage & mat::COVERAGE_PERFORATED):
                    blending = RLBlendMode.CUSTOM_SEPARATE; // use the custom blending mode
                case (bool)(coverage & mat::COVERAGE_BAD):
                    log::error(Where.FILE, "Panel with material %s has a bad material coverage type.", self.mat.name);
                    unreachable();
            }

            switch (blending)
            {
                case RLBlendMode.ALPHA:
                case RLBlendMode.ALPHA_PREMUL:
                    @drawSprite(self, blending, *texture, source, *dist, color);
                    /*rl::@blendMode(blending)
                    {
                        if(self.mat.shader.isValid()) 
                        {
                            rl::@shaderMode(self.mat.shader) // draw using the sprite shader
                            {
                                rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                            };
                        } else { // draw using the default shader
                            rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                        }
                    };*/
                case RLBlendMode.CUSTOM:
                    rl::setBlendFactors(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_FUNC_ADD);
                    rl::setBlendMode(rl::RLBlendMode.CUSTOM);
                    @drawSprite(self, blending, *texture, source, *dist, color);
                    /*rl::@blendMode(blending)
                    {
                        // NOTE(HM) center of the texture (rotation/scale point), 
                        // it's relative to destination rectangle dimentions, not the screen dimentions.
                        rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                    };*/
                case RLBlendMode.CUSTOM_SEPARATE:
                    rl::setBlendFactorsSeparate(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD, rl::RL_MAX);
                    rl::setBlendMode(rl::RLBlendMode.CUSTOM_SEPARATE);
                    @drawSprite(self, blending, *texture, source, *dist, color);
                    /*rl::@blendMode(blending)
                    {
                        // NOTE(HM) center of the texture (rotation/scale point), 
                        // it's relative to destination rectangle dimentions, not the screen dimentions.
                        rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                    };*/
                default: // opaque unless the image has real invisible pixels...
                    // NOTE(HM) center of the texture (rotation/scale point), 
                    // it's relative to destination rectangle dimentions, not the screen dimentions.
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
            }
        } 
        else // draw simple flat shape
        {
            r2d::drawRectangleRec(self.rect, self.color);
        }
    };//tracy::@zoneN
    }; // misc::@profile_zone
}

// draws a immediate sprite (per frame) with the given position, size and color
// NOTE(HM) this is a generic sprite, not a sprite entity, so it does not have a name or any other data
fn void drawImmediate(float posX, float posY, float width, float height, RLColor color = rl::WHITE, String material_name = "") @inline 
{
    @pool() {
        Sprite sptr;
        sptr.type  = Sprite.typeid;
        sptr.kind  = SpriteKind.GENERIC;
        sptr.color = color;
        sptr.setPosition( posX, posY );
        sptr.setSize( width, height );
        // now set the Bounds
        sptr.bounds.fromRect(&sptr.rect);
        if(material_name.len) sptr.setMaterial(material_name);
    };
}

/*
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
import engine::logging::log;
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

fn void Particle.create(&self, Vec2f pos, Vec2f size, RLColor color = rl::WHITE, int lifetime_ms = DEFAULT_PARTICLE_LIFETIME, String tex_name = "") {
    // init the inline sprite data
    self.initV(pos, size, color);
    //self.tex          = assetManager.getAssetExt(tex_name, RLTexture2D.typeid);
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
    RLColor color = misc::INVISIBLE_COLOR;
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
        log::info(Where.CONSOLE, "Entity '%s' has flag %s!!!\n", self.name, self.flags);
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


