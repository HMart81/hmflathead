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

// TODO(HM) to support multiple players make a seperate player array.
module game::projectiles::ammo;

// region c3
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
import engine::misc;
import game::serialize::svs; // save system
import game::main;
//import ent;
import raylib5::rl;
// end_region

const float DEFAULT_PROJECTILE_SPEED    = 1.0f;
const Vec2f DEFAULT_PROJECTILE_MOVE_DIR = misc::VEC_UP;

def ProjectileList    = List(<Projectile>);
def ProjectilePtrList = List(<Projectile*>);

enum Kind : int {
    BULLET,
    ROCKET,
    LASER,
}

struct Projectile
{
    Rectangle rec;
    typeid _typeid;
    Kind kind;
    int lifetime;
    int creationTime;
    //int maxLifeTime;
    float move_speed;
    Vec2f move_dir;
}

fn Projectile* create(Vec2f origin, Vec2f size = {40, 40}, int lifetime = 5000, Kind type = BULLET) {
    Projectile* projectile  = mem::new(Projectile);
    projectile._typeid      = Projectile.typeid;
    projectile.kind         = type;
    projectile.rec          = {origin.x, origin.y, size.x, size.y};
    projectile.move_speed   = DEFAULT_PROJECTILE_SPEED; // @hardcode
    projectile.move_dir     = DEFAULT_PROJECTILE_MOVE_DIR; // @hardcode
    projectile.creationTime = main::gpGame.time_ms;
    projectile.lifetime     = projectile.creationTime + lifetime;
    //projectile.maxLifeTime  = projectile.creationTime + projectile.lifetime;
    return projectile;
}

<*
* @param [in] projectile "pointer to a Projectile"
* @param dt "delta time for projectile movement"
*>
fn void update(Projectile* projectile, float dt) @inline {
    if(!projectile) return;
    
    if(main::gpGame.time_ms > projectile.lifetime) {
        destroy(projectile);
        return;
    }
    
    move(projectile, dt);
}

<*
* @param [in] projectile "pointer to a Projectile"
* @require projectile != null
*>
fn void move(Projectile* projectile, float dt) @inline {
    // TODO(HM) Bullets should move in more directions than just up
    Vec2f velocity = projectile.move_dir + projectile.move_speed * dt;
    projectile.rec.y += velocity.length();
}

<*
* @param [in] projectile "pointer to a Projectile"
* @require projectile != null
*>
fn void draw(Projectile* projectile) @inline {
    if(!projectile) return;
    
    rl::drawRectangleRec(projectile.rec, rl::RED);
}

<*
* @param [in] projectile "pointer to a Projectile"
* @require projectile != null
*>
fn void destroy(Projectile* projectile) @inline {
    mem::free(projectile);
    projectile = null;
}



module game::actors::ent::pl;

// region c3
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
import engine::physics::box2d;
import raylib5::rl;
import game::projectiles::ammo;
import game::serialize::svs; // save system
//import game::actors::ent;
import engine::misc;
import game::main;
// end_region

const float PLAYER_DEFAULT_MOV_SPEED = 5.0f;

enum Move_Dir : int (Vec2i vec, String id)
{
    DIR_NONE  = {{ 0,  0},  "none"},
    DIR_UP    = {{ 0, -1},    "up"},
    DIR_DOWN  = {{ 0,  1},  "down"},
    DIR_LEFT  = {{-1,  0},  "left"},
    DIR_RIGHT = {{ 1,  0}, "right"}
}

// Save here any info the player should take into other levels 
struct PersistentInfo (SaveSystemInterface)  @packed {
    int health;
    int score;
}

fn void PersistentInfo.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void PersistentInfo.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn bool PersistentInfo.clear(&self) @inline {
   // TODO(HM) if some pointers are defined in the struct clean them here.
   return false;
}

struct Player (SaveSystemInterface)
{
    // WARNING(HM) When using subtypes, OVERLAPPING FUNCTION NAMES WILL BE SHADOWED...
    inline Entity super;
    
    Move_Dir move_dir; // todo put this on the main entity seems logical to be there as well...
    ammo::ProjectilePtrList projectiles;
}

fn void Player.save(&self, SaveFile* file) @dynamic {
    self.super.save(file);
// todo
}

fn void Player.reload(&self, SaveFile* file) @dynamic {
    self.super.reload(file);
// todo
}

// Player.init() will shadow (aka override) Entity.init()
fn void Player.init(&self, Vec2f origin = {0, 0}, Color color = rl::BLUE, int id = 1)
{
    self.type = Player.typeid;
    self.id   = id;
    
    char[64] buffer;
    String _name    = (String)io::bprintf(&buffer, "player%d", id)!!;
    self.name       = _name.copy();
    self.move_dir   = DIR_NONE;
    
    // TODO(HM) makes this position editable...
    if(origin == {0, 0}) {
        self.setPosition(
            (float)rl::getScreenWidth() / 2,
            (float)rl::getScreenHeight() / 2
        );
    } else {
        self.setPositionV(origin);
    }
    
    self.setSize(8, 8);
    self.vs.color = color;
    
    // physics
    // define the body
    box2d::BodyDef bodyDef   = box2d::defaultBodyDef();
    bodyDef.type             = box2d::BodyType.KINEMATIC;
    bodyDef.position         = box2d::vec2fToVec2(origin);
    // create the body
    self.physics             = box2d::createBody(main::gpGame.physWorldId, &bodyDef);
    //
    // create the polygon shape
    // TODO(HM) Set the correct size at creation time!!!
    box2d::Polygon playerBox = box2d::makeBox(1.0f, 1.0f); //@hardcode
    box2d::ShapeDef shapeDef  = box2d::defaultShapeDef();
    shapeDef.density          = 1.0f;
    shapeDef.friction         = 0.3f;
	box2d::shapeCreatePolygon(self.physics, &shapeDef, &playerBox);
    //
    
    self.alive = true;
    self.startThinking();
    // NOTE(HM) for now the player as to be manually registered and 
    // be the first Entity in the entity list.
    //
    // TODO(HM) When I create a level system, specially if I ever change 
    // the game to 3D, I need to rethink this entity registering 
    // because in 3D at lest, the player should be the last entity to spawn 
    // not the first like is the case now.
}

fn bool Player.anyKeyPressed(&self) @inline @local {
    // I don't care about what key was pressed
    if(rl::getKeyPressed()) return true;
    
    return false;
}

fn bool Player.handleESC(&self) {
/*
	if (self.inventoryGuiOpen) {
		self.toggleInventory();
		return true;
	}
*/
	return false;
}

fn void Player.updateInteraction(&self, float dt)
{
    float speed = PLAYER_DEFAULT_MOV_SPEED;
    
    self.move_dir = Move_Dir.DIR_NONE;
    
    if(rl::isKeyDown(rl::KEY_RIGHT)) {
        //libc::puts("F1 key was pressed once");
        //self.x += (int)math::floor(1.0f * speed);
        self.move_dir = Move_Dir.DIR_RIGHT;
    }
    if(rl::isKeyDown(rl::KEY_LEFT)) {
        //libc::puts("F1 key was pressed once");
        //self.x -= (int)math::floor(1.0f * speed);
        self.move_dir = Move_Dir.DIR_LEFT;
    }
    if(rl::isKeyDown(rl::KEY_UP)) {
        //libc::puts("F1 key was pressed once");
        //self.y -= (int)math::floor(1.0f * speed);
        self.move_dir = Move_Dir.DIR_UP;
    }
    if(rl::isKeyDown(rl::KEY_DOWN)) {
        //libc::puts("F1 key was pressed once");
        //self.y += (int)math::floor(1.0f * speed);
        self.move_dir = Move_Dir.DIR_DOWN;
    }
    
    // Run
    if(rl::isKeyDown(rl::KEY_LEFT_SHIFT)) 
    {
        speed *= 1.5f;
    }
    
    // shot
    if(rl::isKeyPressed(rl::KEY_SPACE)) {
        self.projectiles.push(ammo::create(self.getPosition()));
    }
    
    Vec2f new_origin = self.getPosition() + misc::dir_mul(self.move_dir, speed);
    self.setPositionV(new_origin);
}

fn void Player.think(&self, float dt /*delta_time*/) 
{
    // NOTE(HM) to run parent entity code that may be necessary by the player
    self.super.think(dt); // parent
    
    if(self.flags & ent::TH_THINK)
    {
        //io::printfn("player is thinking!!!!!!!!!!!!!!!!");
        
        // player Input should be done the next possible to 
        // updating the player think/state possible to diminish input lag.
        self.updateInteraction(dt);
        
        foreach(projectile : self.projectiles) {
            if(projectile) {
                ammo::update(projectile, dt);
                ammo::draw(projectile);
            }
        }
    }
}

fn void Player.startThinking(&self) @inline {
    self.flags = 0;
    self.flags |= ent::TH_THINK;
}

fn void Player.stopThinking(&self) @inline  {
    if (self.flags) {
        self.flags &= ~ent::TH_THINK;
    }
}


fn Player* makePlayer(int id, Color color)  @inline
{
    Player* player = mem::new(Player);
    player.init({0, 0}, color, id);
    return player;
}

module game::actors::palyer::action;

import raylib5::rl;
//import game::actors::palyer;
import std::collections::list;

def InputActionCallback = fn void(void*... args);
def ActionsList         = List(<InputAction*>);
struct InputAction 
{
    String name;
    KeyboardKey key;
    KeyboardKey key_modifier; // alt, ctrl, shift, etc
    MouseButton mBtn;
    InputActionCallback callback;
}

ActionsList actions_list @local;

<*
* @param [in] action "action to register"
* @require action != null
*>
fn void register(InputAction* action) @inline {
    actions_list.push(action);
}

fn void clearActions() @inline {
    foreach(action : actions_list) {
        action.callback = null;
    }
    
    actions_list.free();
}

<*
* @param [in] fn_call "funtion to call has the action"
* @require fn_call != null
*>
fn InputAction* create(String _name, KeyboardKey key, MouseButton mbtn = MouseButton.LEFT, KeyboardKey modifier = rl::KEY_NULL, InputActionCallback fn_call) {
    InputAction* action  = mem::new(InputAction);
    action.name = _name;
    if(key == rl::KEY_NULL) {
        action.mBtn = mbtn;
    } else {
        action.key  = key;
    }
    
    if(modifier != rl::KEY_NULL) action.key_modifier = modifier;
    
    action.callback = fn_call;
    
    register(action);
    
    return action;
}
