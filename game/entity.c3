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
import std::collections::map, std::collections::list;
import game::main;
import engine::logging::log;
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
import thirdparty::scripting::umka; // umka scripting
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
const int 	TH_UPDATEVISUALS = 2;
const int   TH_PHYSICS       = 3; // for the future...

const MIN_VISUAL_SIZE_VALUE         @Hardcode = 1;     // pixel
const MIN_PHYSICS_SIZE_VALUE        @Hardcode = 0.10f; // 10 cm;
const Vec2i MIN_ENTITY_VISUAL_SIZE  = {MIN_VISUAL_SIZE_VALUE, MIN_VISUAL_SIZE_VALUE};
const Vec2f MIN_ENTITY_PHYSICS_SIZE = {MIN_PHYSICS_SIZE_VALUE, MIN_PHYSICS_SIZE_VALUE};

const float ENTITY_DEFAULT_SIZE_X_METER   = 0.45f; // 45 cm  (minimum size is 10 cm)
const float ENTITY_DEFAULT_SIZE_Y_METER   = 1.0f;  // 1  m

// Target list is a list of other entities that are activated by this entity in certain situations.
alias TargetList = List{Entity*}; // list of entities that are targets for this entity

// WORK_IN_PROGRESS!!
const EventDef EV_ENTITY_GET_NAME @if($defined(ENABLE_EVENTS)) = {"getName", "p", "s"}; 
const EventDef EV_ENTITY_GET_ID @if($defined(ENABLE_EVENTS)) = {"getID", "p", "i"};

const EventFunc[*] ENTITY_EVENTS @if($defined(ENABLE_EVENTS)) = {
	{&EV_ENTITY_GET_NAME, &ent::event_getName},
	{&EV_ENTITY_GET_ID, &ent::event_getID},
};

struct EntityFlags
{
	bool alive; // is the entity alive?
	bool active; // is the entity active?
}

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
	TargetList targets; // list of other entities that are targets for this entity, activated in certain situations
    // physics
    B2BodyId physics;
    //
	Move_Dir move_dir; // mostly used for the player entity
	//
	int thinkflags;
	//LinkList{Entity} activeNode;	// for being linked into activeEntities list
	EntityFlags flags; // Todo read about C3 bitstruct?
}

fn void Entity.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Entity.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void Entity.register(&self) @inline
{
	main::gpGame.entityList.push(self);
}

<*
	Testes if the entity has a slot to be created/spawn to
	if not gets ignored.
	@param [in] name : "name of the entity to test"
	@require name != "" : "entities should all have a name!"
*>
fn bool Entity.shouldSkip(&self, String name) @inline @local 
{
    if(main::gpGame.entityList.len() == main::MAX_ENTITY_COUNT) {
		log::warning(FILE, "Skipping entity: '%s' creation, max count of '%s' was reached!", 
			name, main::MAX_ENTITY_COUNT);
		return true;
	}
    
    return false;
}

<*
	Init basic entity data
	@param [in] aname : "name to give the entity"
	@param origin : "where to put the entity in the world (world coords)"
	@param color : "base color of the entity"
	@require aname != "" : "entities should all be given a name!"
	@require rl::isWindowReady() == true : "Cannot create entity before the window is ready!"
*>
fn void Entity.init(&self, String aname, Vec2f origin, RLColor color = rl::WHITE)
{
	if(self.shouldSkip(aname)) return;
	
	self.type = Entity.typeid;
	self.move_dir = DIR_NONE;
	
	usz entity_count = main::gpGame.entityList.len();
	/*if( entity_count == 0 ) {
		unreachable("invalid entity count at this time, that should only happen if player1 entity is missing!");
	}*/
	self.id = (int)entity_count + 1;

	/*if(aname == "")
    {
		if(self.id < 10) {
			self.name = string::tformat("entity0%s", self.id);
		} else {
			self.name = string::tformat("entity%s", self.id);
		}
	} else*/ {
		self.name = aname.tcopy();
	}
    
$if $feature(_DEBUG):
	log::info(FILE, "Created entity-> id: %s with name: %s.", self.id, self.name);
$endif
    
	//
	float x_meters = main::gpGame.screen.width_in_meters;
	float y_meters = main::gpGame.screen.height_in_meters;
    self.vs.initV(
    origin, 
	{ // entity visual size
		ENTITY_DEFAULT_SIZE_X_METER,
		ENTITY_DEFAULT_SIZE_Y_METER
	},
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
    bodyDef.type        = box2d::STATIC;
    /*
        WARNING(HM) 
        Do not create a body at the world origin and then move it to the final place. 
        If you do that to several bodies (specially on the same entity) performance will suffer.
    */
    bodyDef.position    = origin;
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
	float hx, hy;
	hx = math::abs((bb.maxc - bb.minc).x);
	hy = math::abs((bb.maxc - bb.minc).y);
	hx = misc::pixelsToMeters((int)hx);
	hy = misc::pixelsToMeters((int)hy);
	// Warning(HM) if the size is too small or the minimum, this will not return half the size, 
	// but the minimum size of 0.1 meters. 
	// And that means that the box bellow will be created with a size of 0.2 meters,
	// because of the half width and height thing.
	/*if(hx > (misc::MINIMUM_SIZE_IN_METERS + 0.05f))
	{
		hx = hx/2.0f; // divide by 2 because makeBox() expects half width and height
	}
	if(hy > (misc::MINIMUM_SIZE_IN_METERS + 0.05f)) 
	{
		hy = hy/2.0f; // divide by 2 because makeBox() expects half width and height
	}*/
    B2Polygon dynamicBox = box2d::makeBox(hx/2, hy/2);
    B2ShapeDef shapeDef  = box2d::defaultShapeDef();
    shapeDef.density          = 1.0f;
    shapeDef.friction         = 0.3f;
	box2d::createPolygonShape(self.physics, &shapeDef, &dynamicBox);
    //
    
	self.born(); // set the entity as alive, so it can be used
	self.updateVisuals();
}

fn void Entity.setTexture(&self, String texture_name_with_ext) @inline {
	unreachable();
	//self.vs.tex = main::asstManager.getAssetExt(texture_name_with_ext, RLTexture2D.typeid);
}

fn void Entity.setMaterial(&self, String material_name) @inline {
	self.vs.setMaterial(material_name);
	self.updateVisuals();
}

<*
	TODO(HM) handle more material/texture stages than diffuse
 @ensure return != null
*>
fn RLTexture2D* Entity.getTexture(&self) @inline {
	return self.vs.mat.getTexture(mat::STAGE_DIFFUSE);
}

fn void Entity.setSize(&self, float w, float h) @inline {
	self.vs.setSize(w, h);
}

fn void Entity.setSizeV(&self, Vec2f scale) @inline {
	self.vs.setSizeV(scale);
}

fn void Entity.addToSize(&self, float w, float h) @inline {
	self.vs.addToSize(w, h);
}

fn void Entity.addToSizeV(&self, Vec2i size) @inline {
	self.vs.addToSizeV(size);
}

fn Vec2f Entity.getSize(&self) @inline => self.vs.getSize();

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
        log::warning(CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.name, other.name, self.parent.name);
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
	return self.physics.getPosition();
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

/*
fn bool Entity.equalcoverage(&self, Coverage coverage) @operator(==)
{
    return self.vs == coverage;
}

fn bool Entity.nequalcoverage(&self, Coverage coverage) @operator(!=)
{
    return self.vs != coverage;
}
*/

<*
	@require self.vs.mat != null
	@ensure return >= 1
*>
fn Coverage Entity.getCoverage(&self) => self.vs.mat.coverage;

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

fn void Entity.setTarget(&self, Entity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot set target to null entity.");
		return;
	}
	
	if(self.targets.contains(other)) {
		log::warning(FILE, "Entity '%s' already has '%s' as a target.", self.name, other.name);
		return;
	}
	
	self.targets.push(other);
}

fn bool Entity.hasTarget(&self, Entity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot check target for null entity.");
		return false;
	}
	
	if(self.targets.contains(other)) {
		return true;
	}
	
	log::warning(FILE, "Entity '%s' does not have '%s' as a target.", self.name, other.name);
	return false;
}

fn Entity* Entity.getTarget(&self, int index) @inline
{
	if(index < 0 || index >= self.targets.len()) {
		log::error(FILE, "Index out of bounds when getting target from entity '%s'.", self.name);
		return null;
	}
	
	return self.targets[index];
}

fn void Entity.removeTarget(&self, Entity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot remove target from null entity.");
		return;
	}
	
	if(!self.targets.contains(other)) {
		log::warning(FILE, "Entity '%s' does not have '%s' as a target.", self.name, other.name);
		return;
	}
	
	self.targets.remove_at(self.targets.index_of(other)!!); // remove the target from the list
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
		if (other == null || other.isDead() || other.hidden()) {
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
	
	assert( startent.isAlive());
	
	// square the radius so that we don't have to do a square root
	float r2 = misc::square(rad);
	
	foreach(int index, Entity* other : main::gpGame.entityList) 
	{
		if(other.isDead() || other.hidden()) continue;
		
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

fn void Entity.setAlive(&self, bool live) @inline {
	if (live) 
	{
		if (!self.flags.alive) {
			self.flags.alive = true;
			self.register(); // register the entity in the game
		}
		if (!self.isActive()) {
			self.setActive(true); // activate the entity
		}
		if (!(self.thinkflags & TH_THINK)) {
			self.startThinking(); // start thinking if it was not thinking
		}
	} 
	else // die
	{
		if (self.flags.alive) {
			self.flags.alive = false;
			if (self.isActive()) {
				self.setActive(false); // deactivate the entity
			}
			if (self.thinkflags & TH_THINK) {
				self.stopThinking(); // stop thinking if it was thinking
			}
			if(!main::gpGame.entitiesToRemove.contains(self)) main::gpGame.entitiesToRemove.push(self);
		}
	}
}

fn void Entity.born(&self) @inline
{ 
	self.setAlive(true);

	if(self.targets.len() > 0) 
	{
		// TODO(HM) activate the targets, if they are not already activated
		foreach(Entity* target : self.targets) 
		{
			if(target.isAlive()) {
				if(target.notOnActiveList()) {
					target.setActive(true);
				}
			} else { 
				target.born(); // revive the target entity
			}
		}
	}
}

fn void Entity.kill(&self) 
{
//self.mGame = null; // make sure we don't accidently kill the game singleton!!
	io::printfn("Killing Entity '%s'!!!", self.name);
    self.hide();

	if(self.targets.len() > 0) 
	{
		// TODO(HM) activate the targets, if they are not already activated
		foreach(Entity* target : self.targets) 
		{
			if(target.isAlive()) {
				if(target.notOnActiveList()) {
					target.setActive(true);
				}
			} else { 
				target.born(); // revive the target entity
			}
		}
	}

	// free the targets list so we don't have dangling pointers
	// clear the targets list, but not free the entities themselves
	if(self.targets.len() > 0) {	
		// foreach(Entity* target : self.targets) {
		// 	mem::free(target);
		// }
		self.targets.clear();
	}

	self.setAlive(false);
}

fn bool Entity.isAlive(&self) @inline
{
	return self.flags.alive;
}

fn bool Entity.isDead(&self) @inline
{
	return (self.flags.alive) ? false : true;
}

fn bool Entity.onThinkingList(&self) @local @inline {
	return main::gpGame.thinkingEntities.contains(self);
}

fn bool Entity.notOnThinkingList(&self) @local @inline {
	return !self.onThinkingList();
}

fn void Entity.startThinking(&self) @inline 
{
	if (self.thinkflags & TH_THINK) return; // already thinking

	self.thinkflags = 0;
	self.thinkflags |= TH_THINK;
	if(self.notOnThinkingList()) main::gpGame.thinkingEntities.push(self);
}

fn void Entity.stopThinking(&self) @inline 
{
	if (!(self.thinkflags & TH_THINK)) return; // not thinking

	if (self.thinkflags) {
		self.thinkflags &= ~ent::TH_THINK; // remove the thinking flag

		if(self.onThinkingList()) main::gpGame.thinkingEntities.remove_at(main::gpGame.thinkingEntities.index_of(self)!!);

		// if all thinking flags are removed, then we can deactivate the entity
		if (!self.thinkflags && self.isActive()) {
			self.setActive(false); // deactivate the entity
		}
	}
}

fn bool Entity.onActiveList(&self) @inline {
	return main::gpGame.activeEntities.contains(self);
}

fn bool Entity.notOnActiveList(&self) @inline {
	return !self.onActiveList();
}

fn void Entity.setActive(&self, bool active) @inline {
	if (active) {
		if (!self.isActive()) {
			self.flags.active = true;
			if(self.notOnActiveList()) main::gpGame.activeEntities.push(self);
		}
	} else {
		if (self.isActive()) {
			self.flags.active = false;
			if(self.onActiveList()) main::gpGame.activeEntities.remove_at(main::gpGame.activeEntities.index_of(self)!!);
		}
	}
}

fn bool Entity.isActive(&self) @inline {
	return self.flags.active;
}

fn void Entity.becomeInactive(&self, int flags) 
{
	if ((flags & TH_PHYSICS)) {
		flags &= ~TH_PHYSICS;
		return;
		// may only disable physics on a team master if no team members are running physics or bound to a joints
		/*if (teamMaster == this) {
			for (Entity *ent = teamMaster.teamChain; ent; ent = ent.teamChain) {
				if ((ent->thinkflags & TH_PHYSICS) || ((ent->bindMaster == this) && (ent->bindJoint != INVALID_JOINT))) {
					flags &= ~TH_PHYSICS;
					break;
				}
			}
		}*/
	}

	if (self.thinkflags) {
		self.thinkflags &= ~flags;
		if (!self.thinkflags && self.isActive()) {
			//gameLocal.numEntitiesToDeactivate++;
			self.setActive(false);
		}
	}

	/*if ((flags & TH_PHYSICS)) {
		// if this entity has a team master
		if (teamMaster && teamMaster != this) {
			// if the team master is at rest
			if (teamMaster->IsAtRest()) {
				teamMaster->BecomeInactive(TH_PHYSICS);
			}
		}
	}*/
}

fn void Entity.becomeActive(&self, int flags) 
{
	if ((flags & TH_PHYSICS)) {
		// enable the team master if this entity is part of a physics team
		/*if (teamMaster && teamMaster != this) {
			teamMaster->BecomeActive(TH_PHYSICS);
		}
		else if (!(thinkflags & TH_PHYSICS)) {
			// if this is a pusher
			if (physics->IsType(idPhysics_Parametric::Type) || physics->IsType(idPhysics_Actor::Type)) {
				gameLocal.sortPushers = true;
			}
		}*/
	}

	int oldFlags = self.thinkflags;
	self.thinkflags |= flags;
	if (self.thinkflags) {
		if (!self.isActive()) {
			self.setActive(true);
		}
		else if (!oldFlags) {
			// we became inactive this frame, so we have to decrease the count of entities to deactivate
			//gameLocal.numEntitiesToDeactivate--;
			self.setActive(false);
		}
	}
}


fn void Entity.move(&self) {
    // update visuals based on physics movement
    // && box2d::body_GetType(self.physics) == box2d::DYNAMIC
    if(((Vec2f)self.physics.getLinearVelocity()).length() > 0.0f ) {
        Vec2f new_pos = self.physics.getPosition();
        self.setPositionV(new_pos);
        self.updateBoundsPos(new_pos);
		self.updateVisuals();
    }
}

fn void Entity.think(&self, float dt) // update in other engines
{
    if(self.thinkflags & TH_THINK)
    {
		$if $feature(TRACY_ENABLE):
			tracy::@zoneN("Entity.think", 1)
			{
				self.move();
				
				if(bounds::db_showBounds.getBool()) {
					self.bounds.debugDraw();
				}
			};
		$else
			self.move();
			
			if(bounds::db_showBounds.getBool()) {
				self.bounds.debugDraw();
			}
		$endif
    }
}

fn void Entity.updateVisuals(&self) 
{
	self.becomeActive(TH_UPDATEVISUALS);
}

fn void Entity.draw(&self) 
{
	if(self.hidden() || self.isDead()) return;

	if(!(self.thinkflags & TH_UPDATEVISUALS)) {
		return;
	}
	self.becomeInactive(TH_UPDATEVISUALS);
	
	RLRectangle rect = self.vs.rect;
	switch (main::CURRENT_UNITS)
	{
		case main::UNITS_METER:
			// position is still in pixels, todo convert to meters 
			//rect.x = misc::metersToPixels(self.rect.x);
			//rect.y = misc::metersToPixels(self.rect.y);
			rect.width  = misc::metersToPixels(self.vs.rect.width);
			rect.height = misc::metersToPixels(self.vs.rect.height);
		case main::UNITS_PIXEL:
			rect;  // do nothing already in pixels
		default:
			log::error(FILE, "Unsupported units set for Entity rendering.");
			unreachable();
	}

	//
	if(self.vs.hasMaterial())
    {
        // TODO(HM) find how to draw a image on a rounded rectangle!?

        RLTexture2D* texture = self.vs.mat.getTexture(mat::STAGE_DIFFUSE);
        Vec2f texture_size = { texture.width, texture.height };
        RLRectangle source = { 0, 0, texture_size.x, texture_size.y };

		// todo selection
        //RLColor color = (selected) ? self.selected_color : self.mat.getStage(mat::STAGE_DIFFUSE).color;
		RLColor color = self.vs.mat.getStage(mat::STAGE_DIFFUSE).color;

        RLBlendMode blending;
		Coverage coverage = self.getCoverage();
        switch //(coverage)
        {
            case (bool)(coverage & mat::COVERAGE_OPAQUE):
				break; // do nothing here
            case (bool)(coverage & mat::COVERAGE_PERFORATED) && !(bool)(coverage & mat::COVERAGE_TRANSLUCENT):
                blending = RLBlendMode.ALPHA;
            case (bool)(coverage & mat::COVERAGE_TRANSLUCENT) && !(bool)(coverage & mat::COVERAGE_PERFORATED):
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
                log::error(FILE, "Entity material %s has a bad material coverage type.", self.vs.mat.name);
                unreachable();
        }

		switch (blending)
        {
            case RLBlendMode.ALPHA:
            case RLBlendMode.ALPHA_PREMUL:
                rl::@blendMode(blending)
                {
                    rl::drawTexturePro(*texture, source, rect, {0, 0}, 0.0f, color);
                };
			case RLBlendMode.CUSTOM:
				rl::setBlendFactors(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_FUNC_ADD);
				rl::setBlendMode(rl::RLBlendMode.CUSTOM);
				rl::@blendMode(blending)
				{
					// NOTE(HM) center of the texture (rotation/scale point), 
					// it's relative to destination rectangle dimentions, not the screen dimentions.
					rl::drawTexturePro(*texture, source, rect, {0, 0}, 0.0f, color);
				};
			case RLBlendMode.CUSTOM_SEPARATE:
				rl::setBlendFactorsSeparate(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD, rl::RL_MAX);
				rl::setBlendMode(rl::RLBlendMode.CUSTOM_SEPARATE);
				rl::@blendMode(blending)
				{
				// NOTE(HM) center of the texture (rotation/scale point),
				// it's relative to destination rectangle dimentions, not the screen dimentions.
					rl::drawTexturePro(*texture, source, rect, {0, 0}, 0.0f, color);
				};
            default: // draw opaque unless the image has invisible pixels...
                // NOTE(HM) center of the texture (rotation/scale point), 
                // it's relative to destination rectangle dimentions, not the screen dimentions.
                rl::drawTexturePro(*texture, source, rect, {0, 0}, 0.0f, color);
        }
    } 
	else // draw simple flat shape
	{
		rl::drawRectangleRec(rect, self.vs.color);
	}

	if(ent_debugBounds.getBool())
	{
		// TODO(HM) need to change Bounds sizes to meters and then here convert back to pixels
		// to draw the bounds in the correct size
		// Right now the bounds are in pixels, so we can draw them directly
		rl::drawCircle((int)self.bounds.maxc.x, (int)self.bounds.maxc.y, 2.0f, rl::SKYBLUE);
		rl::drawCircle((int)self.bounds.minc.x, (int)self.bounds.minc.y, 2.0f, rl::SKYBLUE);
		Vec2f size = self.bounds.minc - self.bounds.maxc;
		RLRectangle r = {rect.x, rect.y, size.x, size.y};
		rl::drawRectangleLinesEx(r, 1.0f, rl::YELLOW);
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

fn bool Entity.isValid(&self)
{
	// TODO(HM) find why this is returning false
	if(
    self.isAlive() && 
	self.id >= 1 && 
	self.getPosition().x >= 0 &&
    self.getPosition().y >= 0 )
	{
		return true;
	}
	
	return false;
}

fn void create(String aname, int x, int y, int w, int h, RLColor color) @public 
{
	Entity* ent = mem::new(Entity);
	ent.init(aname, {x, y}, color);
	ent.scale((float)w, (float)h);
}

<*
 @ensure return != null
*>
fn Entity* create_ex(String aname, Vec2f origin, RLColor color) @public 
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
/// Entity script events
///////////////////////////////////
fn void event_getName(UmkaStackSlot *params, UmkaStackSlot *result) @if($feature(UMKA_ENABLE))
{
	//Entity *ent = (Entity *)umkaGetParam(params, 0);
	//@todo();
	Umka *umk = umka::getInstance(result);
    UmkaAPI *api = umk.getAPI();

    Entity *ent = api.umkaGetParam(params, 0).ptrVal;
    api.umkaGetResult(params, result).ptrVal = api.umkaMakeStr(umk, ent.name.zstr_tcopy());
}

fn void event_getID(UmkaStackSlot *params, UmkaStackSlot *result) @if($feature(UMKA_ENABLE))
{
	Umka *umk = umka::getInstance(result);
    UmkaAPI *api = umk.getAPI();

    Entity *ent = api.umkaGetParam(params, 0).ptrVal;
    api.umkaGetResult(params, result).intVal = (long)ent.id;
}

///////////////////////////////////
/// Entity script callbacks
///////////////////////////////////

fn void getMinc(WrenVM* vm) @if($feature(WREN_ENABLE))
{
	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
	Entity* ent = (Entity*)vm.getSlotForeign(0);
	WrenHandle handle;
	handle.value = *(Value*)&(*ent).bounds.minc;
	vm.setSlotHandle(0, &handle);
}

fn void getMaxc(WrenVM* vm) @if($feature(WREN_ENABLE))
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

/********************************* Entity Component System (ECS) *********************************/
/*
module game::entity_component_system::ecs;


struct ECSEntity
{
	int id;
}

fn void ECSEntity.init(int anid) @inline
{
	if(anid < 0) {
		unreachable("Invalid entity id, must be >= 0");
	}
	self.id = anid;
}

struct ECSComponent
{
	any data; // component data, can be any type
	ECSEntity* entity; // the entity this component belongs to
	String name; // component name, for debugging purposes
	// TODO(HM) add more component data here...
}

fn bool ECSComponent.isType(&self, typeid type) @inline
{
	return self.data.type == type ? true : false;
}

alias ECSSystemCallback = fn void (ECSEntity* entity, ECSComponent* component) @inline;
struct ECSSystem
{
	String name; // system name
	ECSSystemCallback callback; // system callback function
	// TODO(HM) add more system data here...
}

ECSEntityList = List{ECSEntity*}; // list of entities in the ECS system
ECSComponentList = List{ECSComponent*}; // list of components in the ECS system
ECSSystemList = List{ECSSystem*}; // list of systems in the ECS system

struct ECSEntityManager
{
	ECSEntityList entities;
	ECSComponentList components; // list of components in the ECS system
	ECSSystemList systems; // list of systems in the ECS system
	// TODO(HM) add more data here, like systems, etc.
}
	
fn void ECSEntityManager.registerEntity(ECSEntity* entity) @inline
{
	if(entity == null) {
		unreachable("Cannot add a null entity to the ECS entity list.");
	}
	self.entities.push(entity);
}

fn void ECSEntityManager.remove(ECSEntity* entity) @inline
{
	if(entity == null) {
		unreachable("Cannot remove a null entity from the ECS entity list.");
	}
	self.entities.remove(entity);
}

fn ECSEntity* ECSEntityManager.getEntity(int id) @inline
{
	return self.entities.get(id);
}

fn bool ECSEntityManager.hasEntity(ECSEntity* entity) @inline
{
	if(entity == null) {
		unreachable("Cannot check if a null entity exists in the ECS entity list.");
	}
	
	foreach(ECSEntity* e : self.entities)
	{
		if(e == entity) {
			return true; // found
		}
	}
	
	return false; // not found
}

fn void ECSEntityManager.add_component(String name, typeid type, ECSEntity* entity) @inline
{
	if(entity == null) {
		unreachable("Cannot add a component to a null entity.");
	}
	
	ECSComponent* component = mem::new(ECSComponent);
	component.name = name.tcopy();
	component.data.type = type;
	switch (type)
	{
		case float.typeid:
			component.data.ptr = mem::new(float, {0.0f}); // default value for float
		case int.typeid:
			component.data.ptr = mem::new(int, {0}); // default value for int
		case bool.typeid:
			component.data.ptr = mem::new(bool, {false}); // default value for bool
		case String.typeid:
			component.data.ptr = mem::new(String, {""}); // default value for String
		case Vec2f.typeid:
			component.data.ptr = mem::new(Vec2f, {0.0f, 0.0f}); // default value for Vec2f
		case Vec2i.typeid:
			component.data.ptr = mem::new(Vec2i, {0, 0}); // default value for Vec2i
		case Bounds.typeid:
			component.data.ptr = mem::new(Bounds, {Vec2f{0.0f, 0.0f}, Vec2f{0.0f, 0.0f}}); // default value for Bounds
		case B2BodyId.typeid:
			component.data.ptr = mem::new(B2BodyId, {0}); // default value for B2BodyId
		case Sprite.typeid:	
			component.data.ptr = mem::new(Sprite, {}); // default value for Sprite
		default:
			unreachable("Unknown component type: %s", type.name);
	}
	component.entity = entity;
	self.components.push(component);
}

fn ECSComponent* ECSEntityManager.getComponent(ECSEntity* entity, String name) @inline
{
	if(entity == null) {
		unreachable("Cannot get a component from a null entity.");
	}
	
	foreach(ECSComponent* component : self.components)
	{
		if(component.entity == entity && component.name == name) {
			return component;
		}
	}
	
	return null; // not found
}

fn bool ECSEntityManager.hasComponent(ECSEntity* entity, String name) @inline
{
	if(entity == null) {
		unreachable("Cannot check if a component exists in a null entity.");
	}
	
	foreach(ECSComponent* component : self.components)
	{
		if(component.entity == entity && component.name == name) {
			return true; // found
		}
	}
	
	return false; // not found
}

fn bool ECSEntityManager.hasComponentType(ECSEntity* entity, typeid type) @inline
{
	if(entity == null) {
		unreachable("Cannot check if a component exists in a null entity.");
	}
	
	foreach(ECSComponent* component : self.components)
	{
		if(component.entity == entity && component.data.type == type) {
			return true; // found
		}
	}
	
	return false; // not found
}

fn void ECSEntityManager.clear() @inline
{
	if(self.entities.len()) self.entities.clear();
	if(self.components.len()) self.components.clear();
}
