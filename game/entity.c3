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

module game::actors::ent;

// region modules
import std::io;
import std::core::mem; // for malloc
import std::math;
import std::collections::map;
import game::main;
import engine::logging::lgr;
import thirdparty::raylib5::rl;
import thirdparty::tracy;  // profiling
import engine::misc;
import game::assets::sprt;
import game::material::mat; // material system
import game::serialize::svs; // save system
import engine::sys::cvar;
import game::lowlevel::bounds;
import engine::physics::box2d;
import engine::sys::script_engine::event; // still in testing phase (delete if not finished)
import thirdparty::wren; // wren scripting engine
// end_region

// region cvars
Cvar ent_debugBounds  = { "ent_debugBounds", CvarType.BOOLEAN, "0", "show debug visualization for entity bounding box" };

// NOTE(HM) this is called in main.c3
fn void register_cvars() @inline 
{
    cvar::@register(&ent_debugBounds);
}
// end_region

const int   TH_NONE          = 0;
const int   TH_THINK         = 1;
const int   TH_PHYSICS       = 2; // for the future...

const MIN_VISUAL_SIZE_VALUE         @Hardcode = 1;     // pixel
const MIN_PHYSICS_SIZE_VALUE        @Hardcode = 0.10f; // 10 cm;
const Vec2i MIN_ENTITY_VISUAL_SIZE  = {MIN_VISUAL_SIZE_VALUE, MIN_VISUAL_SIZE_VALUE};
const Vec2f MIN_ENTITY_PHYSICS_SIZE = {MIN_PHYSICS_SIZE_VALUE, MIN_PHYSICS_SIZE_VALUE};

const int   ENTITY_DEFAULT_SIZE_X_PIXELS  = 3;
const int   ENTITY_DEFAULT_SIZE_Y_PIXELS  = 11;
const float ENTITY_DEFAULT_SIZE_X_METER   = 0.27f; // 27 cm  (minimum size is 10 cm)
const float ENTITY_DEFAULT_SIZE_Y_METER   = 1.0f;  // 1  m

// WORK_IN_PROGRESS!!
const EventDef EV_ENTITY_GET_MINC @if($defined(ENABLE_EVENTS)) = {"getMinc", "", event::VECTOR}; 
const EventDef EV_ENTITY_GET_MAXC @if($defined(ENABLE_EVENTS)) = {"getMaxc", "", event::VECTOR};

const EventFunc[*] ENTITY_EVENTS_CALLBACKS @if($defined(ENABLE_EVENTS)) = {
	{&EV_ENTITY_GET_MINC, &ent::getMinc},
	{&EV_ENTITY_GET_MAXC, &ent::getMaxc},
};

struct Entity (SaveSystemInterface)
{
	int id;
	typeid type;
	String name;
    //
    Bounds bounds;
    Sprite vs;
    //
    Entity* parent;
    // physics
    B2BodyId physics;
    //
	int flags;
	//LinkList{Entity} activeNode;	// for being linked into activeEntities list
	bool alive; // Todo read about C3 bitstruct?
}

fn void Entity.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Entity.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn bool Entity.shouldSkip(&self, String name) @inline @local {
    if(main::gpGame.entityList.len() > main::MAX_ENTITY_COUNT) {
		if(name != "") {
			lgr::warning(Where.FILE, "Skipping entity: '%s' creation, max count of '%s' reached!", 
				name, main::MAX_ENTITY_COUNT);
		} else {
            Vec2f origin = self.getPosition();
			lgr::warning(Where.FILE, "Skipping entity to create at {%s, %s}, because max count '%s' was reached!", 
				origin.x, origin.y, main::MAX_ENTITY_COUNT);
		}
		return true;
	}
    
    return false;
}

fn void Entity.init(&self, String aname, Vec2f origin, Color color = rl::WHITE)
{
	if(self.shouldSkip(aname)) return;
	
	self.type = Entity.typeid;
	
	int entity_count = (int)main::gpGame.entityList.len();
	if( entity_count <= 0 ) {
		unreachable("invalid entity count, missing player1 entity?");
	}
	self.id = entity_count + 1;
    
	if(aname == "")
    {
		if(self.id < 10) {
			self.name = string::tformat("entity0%s", self.id);
		} else {
			self.name = string::tformat("entity%s", self.id);
		}
	} else {
		self.name = aname.tcopy();
	}
    
$if $feature(_DEBUG):
	lgr::info(Where.FILE, "Created entity-> id: %s with name: %s.", self.id, self.name);
$endif
    
	//
    self.vs.initV(
    origin, 
    {ENTITY_DEFAULT_SIZE_X_PIXELS, ENTITY_DEFAULT_SIZE_Y_PIXELS}, 
    color
    );
    //
    
    // set entity Bounds
    Bounds bb;
    bb.maxc = origin;
    bb.minc = bb.maxc + misc::VEC_RIGHT * self.vs.rect.width + misc::VEC_DOWN * self.vs.rect.height;
    self.setBounds(bb);
    
    // physics
    // define the body
    B2BodyDef bodyDef   = box2d::defaultBodyDef();
    bodyDef.type        = box2d::KINEMATIC;
    /*
        WARNING(HM) 
        Do not create a body at the world origin and then move it to the final place. 
        If you do that to several bodies (specially on the same entity) performance will suffer.
    */
    bodyDef.position    = origin; //box2d::vec2fToVec2(origin);
    //bodyDef.rotation    = misc::makeRot(1.0f); // angle is in radians and is zero by default
    // already done by default
    //bodyDef.enableSleep = true;
    
    // create the body from the definition data above
    self.physics        = box2d::createBody(main::gpGame.physWorldId, &bodyDef);
    //
    // create the physics shape
    // ‍Caution: A dynamic body should have at least one shape with a non-zero density. 
    // Otherwise you will get strange behavior.
    // TODO(HM) Set the correct size at creation time!!!
    B2Polygon dynamicBox = box2d::makeBox(
        misc::pixelsToMeters(ENTITY_DEFAULT_SIZE_X_PIXELS),
        misc::pixelsToMeters(ENTITY_DEFAULT_SIZE_Y_PIXELS)
        );
    B2ShapeDef shapeDef  = box2d::defaultShapeDef();
    shapeDef.density          = 1.0f;
    shapeDef.friction         = 0.3f;
	box2d::createPolygonShape(self.physics, &shapeDef, &dynamicBox);
    //
    
	self.alive = true;
	self.startThinking();
	self.register();
}

fn void Entity.setTexture(&self, String texture_name_with_ext) @inline {
	unreachable();
	//self.vs.tex = main::asstManager.getAssetExt(texture_name_with_ext, Texture2D.typeid);
}

fn void Entity.setMaterial(&self, String material_name) @inline {
	self.vs.setMaterial(material_name);
}

<*
	TODO(HM) handle more material/texture stages than diffuse
 @ensure return != null
*>
fn Texture2D* Entity.getTexture(&self) @inline {
	return self.vs.mat.getTexture(mat::STAGE_DIFFUSE);
}

fn void Entity.setSize(&self, int w, int h) @inline {
	self.vs.setSize(w, h);
}

fn void Entity.setSizeV(&self, Vec2i scale) @inline {
	self.vs.setSizeV(scale);
}

fn void Entity.addToSize(&self, int w, int h) @inline {
	self.vs.addToSize(w, h);
}

fn void Entity.addToSizeV(&self, Vec2i size) @inline {
	self.vs.addToSizeV(size);
}

fn Vec2f Entity.getSize(&self) @inline => self.vs.getSize();
fn Vec2i Entity.getSizei(&self) @inline => self.vs.getSizei();

fn void Entity.scale(&self, float w, float h) @inline {
	self.vs.scale(w, h);
}

fn void Entity.scaleV(&self, Vec2f scaler) @inline {
	self.vs.scaleV(scaler);
}

<*
    @param [in] other : "the other entity to bind this one too"
    @require other != null
*>
fn void Entity.bindTo(&self, Entity* other, bool release_from_other = false) {
    if(self.bound() && !release_from_other) {
        lgr::warning(Where.CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.name, other.name, self.parent.name);
        return;
    }
    
    self.parent = other;
}

fn bool Entity.bound(&self) => self.parent != null;

fn void Entity.unbind(&self) 
{
    if(self.parent) self.parent = null;
}

fn void Entity.setPosition(&self, float x, float y) @inline
{
	self.vs.setPosition(x, y);
}

fn void Entity.setPositionV(&self, Vec2f newpos) @inline
{
	self.setPosition(newpos.x, newpos.y);
}

fn Vec2f Entity.getPosition(&self) @inline
{
	return self.vs.getPos();
}

fn void Entity.setBounds(&self, Bounds bb) @inline {
    self.bounds = {
        .minc = bb.minc,
        .maxc = bb.maxc
    };
}

fn Vec2f Entity.getMinc(&self, Bounds bb) => self.bounds.minc;

fn Vec2f Entity.getMaxc(&self, Bounds bb) => self.bounds.maxc;

fn void Entity.updateBoundsPos(&self, Vec2f pos) @inline
{
    self.bounds.translate(pos);
    // Bounds bb;
    // bb.maxc = origin;
    // bb.minc = bb.maxc + misc::VEC_RIGHT * self.vs.rect.width + misc::VEC_DOWN * self.vs.rect.height;
    // self.setBounds(bb);
}

// fn void Entity.rotate2D(&self, float angle) @inline
// {
	// //float rad = (float)math::deg_to_rad(angle);
	// float ct, st; // t = theta
	// ct = math::cos(angle);
	// st = math::sin(angle);
	// self.axis.m10 = ct;
	// self.axis.m01 = st;
// }

fn bool Entity.equalcoverage(&self, Coverage coverage) @operator(==)
{
    return self.vs == coverage;
}

fn bool Entity.nequalcoverage(&self, Coverage coverage) @operator(!=)
{
    return self.vs != coverage;
}

fn bool Entity.isdead(&self) @inline
{
	return (self.alive) ? false : true;
}

fn void Entity.hide(&self) @inline => self.vs.hide();

fn void Entity.show(&self) @inline => self.vs.show();

fn bool Entity.hidden(&self) @inline => self.vs.hidden();

fn void Entity.setname(&self, String* aname) @inline
{
	if(aname)
	{
		self.name = aname.tcopy();
	} else {
		unreachable("Failed to give name to entity.");
	}
}

/*
=================
find_other_in_radius

Returns other entities that have origins 
within a spherical area around us
=================
*/
// UNTESTED
fn Entity* Entity.find_other_in_radius(self, float radius )
{
	// square the radius, so that we don't have to do a square root
	float r2 = misc::square(radius);
	
	foreach(int index, Entity* other : main::gpGame.entityList)
	{
		// NOTE(HM) Should this really ignore hidden entities?
		if (other == null || other.isdead() || other.hidden()) {
			continue;
		}
		
		Vec2f other_org = self.getPosition() - other.getPosition();
		
		if (other_org.sq_magnitude() <= r2 ) {
			return other;
		}
	}
	
	return null;
}

/*
=================
findradius

Returns entities that have origins within a spherical area
=================
*/
// UNTESTED
fn Entity* findradius(Entity *startent, Vec2f* org, float rad )
{
	if ( !startent )
	{
		// startent becomes the player
		startent = (Entity*)main::gpGame.getLocalPlayer(); //entityList[0];
	}
	
	assert( startent );
	if ( !startent ) {
		return null;
	}
	
	assert( startent.alive == true);
	
	// square the radius so that we don't have to do a square root
	float r2 = misc::square(rad);
	
	foreach(int index, Entity* other : main::gpGame.entityList) 
	{
		if(other.isdead() || other.hidden()) continue;
		
		Vec2f other_org = (*org) - startent.getPosition();
		
		float distance = other_org.sq_magnitude();
		
		if ( distance <= r2 )
		{
			return startent;
		}
		else
		{
			// subtract the object's own radius from this distance
			distance -= (startent.getSize().x * startent.getSize().y);
			if ( distance <= r2 )
			{
				return startent;
			}
		}
	}
	
	return null;
}

fn void Entity.born(&self) @inline @local { if(self.alive) return; self.alive = true; }

fn void Entity.register(&self) @inline
{
	// NOTE(HM) shouldn't never happen, but who knows...
	//assert(self.isValid(), "error cannot register entity because is not valid!");
    self.born();
	main::gpGame.entityList.push(self);
}

fn void Entity.draw(&self) 
{
	if(self.hidden() || self.isdead()) return;
	
	//
	if(self.vs.hasMaterial())
    {
        // TODO(HM) find how to draw a image on a rounded rectangle!?

        Texture2D* texture = self.vs.mat.getTexture(mat::STAGE_DIFFUSE);
        Vec2f texture_size = { texture.width, texture.height };
        Rectangle source = { 0, 0, texture_size.x, texture_size.y };
        Rectangle* dist = &self.vs.rect;

		// todo selection
        //Color color = (selected) ? self.selected_color : self.mat.getStage(mat::STAGE_DIFFUSE).color;
		Color color = self.vs.mat.getStage(mat::STAGE_DIFFUSE).color;

        BlendMode blending;
        switch //(self.vs.mat.coverage)
        {
            case *self == mat::COVERAGE_OPAQUE:
				break; // do nothing here
            case *self == mat::COVERAGE_PERFORATED && *self != mat::COVERAGE_TRANSLUCENT:
                blending = BlendMode.ALPHA;
            case *self == mat::COVERAGE_TRANSLUCENT && *self != mat::COVERAGE_PERFORATED:
                blending = BlendMode.ALPHA_PREMUL;
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
			case *self == mat::COVERAGE_TRANSLUCENT && *self == mat::COVERAGE_PERFORATED:
				blending = BlendMode.CUSTOM_SEPARATE; // use the custom blending mode					
            case *self == mat::COVERAGE_BAD:
                lgr::error(Where.FILE, "Entity material %s has a bad material coverage type.", self.vs.mat.name);
                unreachable();
        }

		switch (blending)
        {
            case BlendMode.ALPHA:
            case BlendMode.ALPHA_PREMUL:
                rl::@blendMode(blending)
                {
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                };
			case BlendMode.CUSTOM:
				rl::setBlendFactors(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_FUNC_ADD);
				rl::setBlendMode(rl::BlendMode.CUSTOM);
				rl::@blendMode(blending)
				{
					// NOTE(HM) center of the texture (rotation/scale point), 
					// it's relative to destination rectangle dimentions, not the screen dimentions.
					rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
				};
			case BlendMode.CUSTOM_SEPARATE:
				rl::setBlendFactorsSeparate(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD, rl::RL_MAX);
				rl::setBlendMode(rl::BlendMode.CUSTOM_SEPARATE);
				rl::@blendMode(blending)
				{
				// NOTE(HM) center of the texture (rotation/scale point),
				// it's relative to destination rectangle dimentions, not the screen dimentions.
					rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
				};
            default: // draw opaque unless the image has invisible pixels...
                // NOTE(HM) center of the texture (rotation/scale point), 
                // it's relative to destination rectangle dimentions, not the screen dimentions.
                rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
        }
    } 
	else // draw simple flat shape
	{
		rl::drawRectangleRec(self.vs.rect, self.vs.color);
	}

	if(ent_debugBounds.getBool())
	{
		rl::drawCircle((int)self.bounds.maxc.x, (int)self.bounds.maxc.y, 2.0f, rl::SKYBLUE);
		rl::drawCircle((int)self.bounds.minc.x, (int)self.bounds.minc.y, 2.0f, rl::SKYBLUE);
		Vec2f size = self.bounds.minc - self.bounds.maxc;
		Rectangle rect = {self.vs.rect.x, self.vs.rect.y, size.x, size.y};
		rl::drawRectangleLinesEx(rect, 1.0f, rl::YELLOW);
	}
}

fn void Entity.startThinking(&self) @inline {
	self.flags = 0;
	self.flags |= ent::TH_THINK;
}

fn void Entity.stopThinking(&self) @inline {
	if (self.flags) {
		self.flags &= ~ent::TH_THINK;
		// if (!self.flags && IsActive()) {
			// gameLocal.numEntitiesToDeactivate++;
		// }
	}
}


fn bool Entity.isActive(&self) @inline {
	return (self.flags & ent::TH_THINK) ? true : false;
}

fn void Entity.move(&self) {
    // update visuals based on physics movement
    // && box2d::body_GetType(self.physics) == box2d::DYNAMIC
    if(((Vec2f)box2d::body_GetLinearVelocity(self.physics)).length() > 0.0f ) {
        Vec2f new_pos = box2d::body_GetPosition(self.physics);
        self.setPositionV(new_pos);
        self.updateBoundsPos(new_pos);
    }
}

fn void Entity.think(&self, float dt) // update in other engines
{
    if(self.flags & TH_THINK)
    {
        tracy::@zoneN("Entity.think", 1)
        {
            self.move();
            
            if(bounds::db_showBounds.getBool()) {
                self.bounds.debugDraw();
            }
        };
    }
}

/*
fn void Entity.becomeActive(&self, int flags) {
	
    if (flags & TH_PHYSICS) {
        //enable physics
	}
    
	int oldFlags = self.flags;
	self.flags |= flags;
	if (self.flags) {
		if (!isActive()) {
			activeNode.AddToEnd(gameLocal.activeEntities);
		}
		else if (!oldFlags) {
			// we became inactive this frame, so we have to decrease the count of entities to deactivate
			gameLocal.numEntitiesToDeactivate--;
		}
	}
}
*/

fn void Entity.kill(&self) {
//self.mGame = null; // make sure we don't accidently kill the game singleton!!
	io::printfn("Killing Entity '%s'!!!", self.name);
    self.hide();
	self.stopThinking();
	self.alive = false;
}

fn bool Entity.isValid(&self)
{
	// TODO(HM) find why this is returning false
	if(
    self.alive && 
	self.id >= 1 && 
	self.getPosition().x >= 0 &&
    self.getPosition().y >= 0 && 
    self.getSizei().x >= MIN_VISUAL_SIZE_VALUE &&
    self.getSizei().y >= MIN_VISUAL_SIZE_VALUE)
	{
		return true;
	}
	
	return false;
}

fn void create(String aname, int x, int y, int w, int h, Color color) @public 
{
	Entity* ent = mem::new(Entity);
	ent.init(aname, {x, y}, color);
	ent.scale((float)w, (float)h);
}

<*
 @ensure return != null
*>
fn Entity* create_ex(String aname, Vec2f origin, Color color) @public 
{
	Entity* ent = mem::new(Entity);
	ent.init(aname, origin, color);
	return ent;
}

// TODO
fn void cloneEntity( Entity* dest, Entity* src )
{
/*
	int     i, num;
	
	dest.setModel( src.model );
	// don't process our init commands
	//dest.CancelEventsOfType( EV_ProcessInitCommands );
	dest.setOrigin( src.origin );
	dest.setAngles( src.angles );
	dest.setScale( src.edict.s.scale );
	dest.setAlpha( src.edict.s.alpha );
	dest.health = src.health;
	// copy the surfaces
	memcpy( dest.edict.s.surfaces, src.edict.s.surfaces, sizeof( src.edict.s.surfaces ) );
	dest.edict.s.constantLight = src.edict.s.constantLight;
	//dest.edict.s.eFlags = src.edict.s.eFlags;
	dest.edict.s.renderfx = src.edict.s.renderfx;
	dest.edict.s.anim = src.edict.s.anim;
	dest.edict.s.frame = src.edict.s.frame;
	
	if ( src.bind_info )
	{
		num = src.bind_info.numchildren;
		for( i = 0; ( i < MAX_MODEL_CHILDREN ) && num; i++ )
		{
			Entity * clone;
			Entity * child;
			
			// duplicate the children
			if ( !src.bind_info.children[ i ] )
			{
				continue;
			}
			child = G_GetEntity( src.bind_info.children[ i ] );
			if ( child )
			{
				clone = new Entity( ENTITY_CREATE_FLAG_ANIMATE );
				CloneEntity( clone, child );
				clone.attach( dest.entnum, child.edict.s.tag_num );
			}
			num--;
		}
	}
	dest.ProcessPendingEvents();
	*/
}


///////////////////////////////////
/// Entity script callbacks
///////////////////////////////////

fn void getMinc(WrenVM* vm)
{
	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
	Entity* ent = (Entity*)vm.getSlotForeign(0);
	WrenHandle handle;
	handle.value = *(Value*)&(*ent).bounds.minc;
	vm.setSlotHandle(0, &handle);
}

fn void getMaxc(WrenVM* vm) 
{
	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
	Entity* ent = (Entity*)vm.getSlotForeign(0);
	WrenHandle handle;
	handle.value = *(Value*)&(*ent).bounds.maxc;
	vm.setSlotHandle(0, &handle);
}

// fn void script_fn_getBounds(WrenVM* vm) 
// {
// 	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
//     Entity* ent = (Entity*)vm.getSlotForeign(0);
// 	WrenHandle handle.value = *(Value*)&(*ent).bounds;
//     vm.setSlotHandle(0, &handle);
// }