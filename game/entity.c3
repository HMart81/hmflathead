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
import std::math;
import std::core::mem; // for malloc
import std::collections::map, std::collections::list;
import thirdparty::wren; // wren scripting engine
import thirdparty::tracy;  // profiling
import thirdparty::raylib5::rl;
import thirdparty::scripting::umka; // umka scripting
import engine::misc;
import engine::logging::log;
import engine::physics::box2d;
import engine::serialize::svs; // save system
import engine::sys::cvar;
import engine::sys::ctype;
import engine::sys::render2d::r2d;
import engine::sys::framework::hmdict;
import engine::sys::script_engine::event; // still in testing phase (delete if not finished)
import game;
import game::sys::update;
import game::material::mat; // material system
import game::assets::sprite;
import game::lowlevel::bounds;
// end_region

// region cvars
CVar cvShowInfo = { "ent_showInfo", CvFlag.INT | CvFlag.TOOL, "2", " 1 = show entity name and origin, 2 = show also bounding box" };

// NOTE(HM) this is called by register_modulo_cvars() in game.c3
fn void register_cvars() @inline
{
    cvar::@register(&cvShowInfo);
}
// end_region

constdef EntTh : inline int
{
	NONE = 0,
	THINK,
	UPDATEVISUALS,
	PHYSICS // for the future...
}

const MIN_VISUAL_SIZE_VALUE @if(game::UNITS == Units.PIXEL) @Hardcode = 1;
const MIN_VISUAL_SIZE_VALUE @if(game::UNITS == Units.METER) @Hardcode = 0.10f; // 10 cm

const MIN_PHYSICS_SIZE_VALUE @if($feature(PHYSICS_BOX2D) && game::UNITS == Units.METER) @Hardcode = MIN_VISUAL_SIZE_VALUE;
//const Vec2f MIN_ENTITY_PHYSICS_SIZE @if($feature(PHYSICS_BOX2D)) = {MIN_PHYSICS_SIZE_VALUE, MIN_PHYSICS_SIZE_VALUE};

const Vec2i MIN_ENTITY_VISUAL_SIZE  = {MIN_VISUAL_SIZE_VALUE, MIN_VISUAL_SIZE_VALUE};

const float DEFAULT_SIZE_X @if(game::UNITS == Units.METER) = 0.45f; // 45 cm  (minimum size is 10 cm)
const float DEFAULT_SIZE_Y @if(game::UNITS == Units.METER) = 1.0f;  // 1  m
//
const int DEFAULT_SIZE_X @if(game::UNITS == Units.PIXEL) = 45; // px  (minimum size is 10 px)
const int DEFAULT_SIZE_Y @if(game::UNITS == Units.PIXEL) = 100;  // px

// Target list is a list of other entities that are activated by this entity in certain situations.
alias TargetList = List{HMEntity*}; // list of entities that are targets for this entity

// WORK_IN_PROGRESS!!
const EventDef EV_ENTITY_GET_NAME @if($defined(event::ENABLE_EVENTS)) @local = {"getName", "p", 's'}; 
const EventDef EV_ENTITY_GET_ID @if($defined(event::ENABLE_EVENTS)) @local = {"getID", "p", 'i'};

const EventFunc[*] ENTITY_EVENTS @if($defined(event::ENABLE_EVENTS)) = {
	{&EV_ENTITY_GET_NAME, &ent::event_getName},
	{&EV_ENTITY_GET_ID, &ent::event_getID},
};
/////////////////////////

struct HMEntity (SaveSystemInterface)
{
    //
    inline HMSprite super;
    //
	typeid super_type;
	int id;
	String name;
	HMDict spawnargs;
	String def_name; // entity definition name assigned to this entity
    HMEntity* parent;
	TargetList targets; // list of other entities that are targets for this entity, activated in certain situations
    // physics
    B2BodyId physics @if($feature(PHYSICS_BOX2D));
    //
	Move_Dir move_dir; // mostly used for the player entity
	int health; // should all entities have a health value?
	int max_health;
	//
	int thinkflags;
	//LinkList{HMEntity} activeNode;	// for being linked into activeEntities list
	bool alive; // is the entity alive?
}

fn void HMEntity.save(&self, SaveFile* file) @dynamic {
	self.super.save(file);
// todo
}

fn void HMEntity.reload(&self, SaveFile* file) @dynamic {
	self.super.reload(file);
// todo
}

fn void HMEntity.register(&self) @inline
{
	if(!game::pContext.entityList.contains(self)) {
		game::pContext.entityList.push(self);
	}
}

<*
	Tests if the entity has a slot to be created/spawn to
	if not gets ignored.
	@param [in] name : "name of the entity to test"
	@require name != "" : "entities should all have a name!"
*>
fn bool HMEntity.shouldSkip(&self, String name) @inline 
{
    if(game::pContext.entityList.len() == game::MAX_ENTITY_COUNT) {
		log::warning(FILE, "Skipping entity: '%s' creation, max entity count of '%s' was reached!", 
			name, game::MAX_ENTITY_COUNT);
		return true;
	}

	foreach(ent : game::pContext.entityList)
	{
		if(ent.name == name) {
			log::error(FILE, "Cannot create another entity named: '%s' name is already used by entity id: '%d'!", 
			name, ent.id);
			return true;
		}
	}
    
    return false;
}

<*
	Init basic entity data (overrides Sprite init function...)
	@param [in] aname : "name to give the entity"
	@param origin : "where to put the entity in the world (world coords)"
	@require rl::isWindowReady() == true : "Cannot create a entity before the window is ready!"
*>
fn void HMEntity.init(&self, String aname, Vec2f origin, Vec2f size)
{
	sz entity_count = game::pContext.entityList.len();
	self.id = (int)entity_count + 1;

	String name = "HMEntity";
	if(self.id == 1) // player is always entity id 1
	{
		name = "Player";
	}
	// if we passed a name, overrride any previous set name
	if(aname.len > 0)
	{
		name = aname;
	}
	self.name = string::tformat("%s_%s", name, self.id);

	if(self.shouldSkip(self.name))
	{
		self.name = "";
		self.id = 0;
		return;
	}

	// visuals
    self.initV( origin, 
	{ // entity visual size
		size.x,
		size.y
	});
    //
	
	// NOTE(HM) Saving parent HMSprite typeid info
	// because it will be overriden by HMEntity;
	self.super_type = self.type;
	self.type = HMEntity;
    
$if $feature(_DEBUG):
	log::info(FILE, "Created entity-> %s.", self.name);
$endif
    
	$if $feature(PHYSICS_BOX2D):
	// make sure theres no previous physics body
	assert(self.physics.isValid() == false);
    // define the body
    B2BodyDef bodyDef   = box2d::defaultBodyDef();
    bodyDef.type        = box2d::STATIC; // entities are static by default
    /*
        WARNING(HM) 
        Do not create a body at the world origin and then move it to the final place. 
        If you do that to several bodies (specially on the same entity) performance will suffer.
    */
    bodyDef.position    = origin;
    //bodyDef.rotation    = misc::makeRot(1.0f); // angle is in radians and is zero by default
    // already done by default
    //bodyDef.enableSleep = true;
    
    // create the body using the definition data above
    self.physics        = box2d::createBody(game::pContext.physWorldId, &bodyDef);
    assert(self.physics.isValid() == true);
	//
    // create the physics shape.
	// Warning(HM) if the size is too small or the minimum, this will not return half the size, 
	// but the minimum size of 0.1 meters or 10 centimeters. 
	// And that means that the box bellow will be created with a size of 0.2 meters,
	// because of the half width and height thing.
    B2Polygon dynamicBox = box2d::makeBox(self.rect.x/2, self.rect.y/2);
    B2ShapeDef shapeDef  = box2d::defaultShapeDef();
    // ‍Caution: A dynamic body should have at least one shape with a non-zero density. 
    // Otherwise you will get strange behavior.
    shapeDef.density          = 1.0f;
    shapeDef.friction         = 0.3f;
	box2d::createPolygonShape(self.physics, &shapeDef, &dynamicBox);
	$endif // PHYSICS_BOX2D
    
	self.onSpawn("entityBase");
	self.born(); // set the entity as alive, so it can be used
	self.updateVisuals();
}

fn void HMEntity.setSpawnArgs(&self, String def_name) @inline
{
	self.spawnargs.init();
	@catch(self.spawnargs.parse(DefType.ENTITY, def_name));
}

fn void HMEntity.clearSpawnArgs(&self) @inline
{
	self.spawnargs.clear();
}

fn void HMEntity.setMaterial(&self, String material_name) 
{
	// NOTE(HM) I changed HMEntity to be a inlined HMSprite
	// so this was causing a nasty loop, because I override 
	// the sprite setMaterial function and so by accident 
	// I was calling over and over again the entity own 
	// setMaterial function!!!!!
	//self.setMaterial(material_name);
	
	self.super.setMaterial(material_name);
	self.updateVisuals();
}

fn float HMEntity.getWidth(&self) @inline => self.getSize().x;

fn float HMEntity.getHeight(&self) @inline => self.getSize().y;

<*
    @param [in] other : "the other entity to bind this one too"
    @require other != null
*>
fn void HMEntity.bindTo(&self, HMEntity* other, bool release_from_other = false) {
    if(self.bound() && !release_from_other) {
        log::warning(CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.name, other.name, self.parent.name);
        return;
    }
    
    self.parent = other;
}

fn bool HMEntity.bound(&self) => self.parent != null;

fn void HMEntity.unbind(&self) 
{
    if(self.parent) self.parent = null;
}

fn Vec2f HMEntity.getPosition(&self) @inline
{
	$if $feature(PHYSICS_BOX2D):
	return self.physics.getPosition();
	$else
	return self.super.getPosition();
	$endif
}

fn Vec2f HMEntity.getOrigin(&self) @inline => self.getPosition();

fn void HMEntity.hide(&self) @inline
{
	self.super.hide();
	self.stopThinking();
}

fn void HMEntity.show(&self) @inline
{
	self.super.show();
	self.startThinking();
}

fn void HMEntity.setname(&self, String* aname) @inline
{
	if(aname)
	{
		self.name = aname.tcopy();
	} 
	else
	{
		unreachable("Failed to give name to entity.");
	}
}

fn void HMEntity.setTarget(&self, HMEntity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot set target to null entity.");
		return;
	}
	
	if(self.targets.contains(other)) {
		log::warning(FILE, "HMEntity '%s' already has '%s' as a target.", self.name, other.name);
		return;
	}
	
	self.targets.push(other);
}

fn bool HMEntity.hasTarget(&self, HMEntity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot check target for null entity.");
		return false;
	}
	
	if(self.targets.contains(other)) {
		return true;
	}
	
	log::warning(FILE, "HMEntity '%s' does not have '%s' as a target.", self.name, other.name);
	return false;
}

fn bool HMEntity.hasTargets(self) @inline => self.targets.len() > 0;

fn HMEntity* HMEntity.getTarget(&self, int index) @inline
{
	if(index < 0 || index >= self.targets.len()) {
		log::error(FILE, "Index out of bounds when getting target from entity '%s'.", self.name);
		return null;
	}
	
	return self.targets[index];
}

fn void HMEntity.removeTarget(&self, HMEntity* other) @inline
{
	if(other == null) {
		log::error(FILE, "Cannot remove target from null entity.");
		return;
	}
	
	if(!self.targets.contains(other)) {
		log::warning(FILE, "HMEntity '%s' does not have '%s' as a target.", self.name, other.name);
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
fn HMEntity* HMEntity.find_other_in_radius(self, float radius )
{
	// square the radius, so that we don't have to do a square root
	float r2 = misc::square(radius);
	
	foreach(int index, HMEntity* other : game::pContext.entityList)
	{
		// NOTE(HM) Should this really ignore hidden entities?
		if (other == null || other.isDead() || other.hidden()) {
			continue;
		}
		
		Vec2f other_org = self.getPosition() - other.getPosition();
		
		if (other_org.length_sq() <= r2 ) {
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
fn HMEntity* findradius(HMEntity *startent, Vec2f* org, float rad )
{
	if ( !startent )
	{
		// then startent becomes the player
		startent = (HMEntity*)game::getLocalPlayer();
	}
	
	assert( startent );
	if ( !startent ) {
		return null;
	}
	
	assert(startent.isAlive());
	
	// square the radius so that we don't have to do a square root
	float r2 = misc::square(rad);
	
	foreach(int index, HMEntity* other : game::pContext.entityList) 
	{
		if(other.isDead() || other.hidden()) continue;
		
		Vec2f other_org = (*org) - startent.getPosition();
		
		float distance = other_org.length_sq();
		
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

fn void HMEntity.setAlive(&self, bool live = true, bool shouldRemove = false)
{
	if (live) 
	{
		if (!self.alive) {
			self.alive = true;
			self.register(); // register the entity in the game
		}
		if (!self.isActive()) {
			self.setActive(true); // activate the entity
		}
		if (!(self.thinkflags & EntTh.THINK)) {
			self.startThinking(); // start thinking if it was not thinking
		}
	} 
	else // die
	{
		if (self.alive) {
			self.alive = false;
			if (self.isActive()) {
				self.setActive(false); // deactivate the entity
			}
			if (self.thinkflags & EntTh.THINK) {
				self.stopThinking(); // stop thinking if it was thinking
			}
			if(shouldRemove && !game::pContext.entitiesToRemove.contains(self)) game::pContext.entitiesToRemove.push(self);
		}
	}
}

fn void HMEntity.born(&self)
{ 
	self.setAlive(true);

	if(self.targets.len() > 0) 
	{
		// TODO(HM) activate the targets, if they are not already activated
		foreach(HMEntity* target : self.targets) 
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

fn void HMEntity.kill(&self) 
{
    log::info(CONSOLE, "%s%s'%s'!!!%s", ansi::color_rgb(255, 0, 0), "Killing HMEntity ", self.name, Ansi.RESET);
    self.hide();

	// activate targets on death
	if(self.hasTargets()) 
	{
		// activate our targets, if they are not already activated
		foreach(target : self.targets)
		{
			if(target.isAlive() && target.notOnActiveList())
			{
				target.setActive(true);
			} 
			else
			{ 
				target.born(); // revive the target entity
			}
		}

		// then free the targets list we don't need it anymore
		// clear the targets list, but not free the entities themselves
		// that is done by the game context later
		self.targets.clear();
	}

	self.clearSpawnArgs();
	self.setAlive(false);
}

fn bool HMEntity.isAlive(&self) @inline
{
	return self.alive;
}

fn bool HMEntity.isDead(&self) @inline
{
	return (self.alive) ? false : true;
}

fn bool HMEntity.onThinkingList(&self) @inline {
	return game::pContext.thinkingEntities.contains(self);
}

fn bool HMEntity.notOnThinkingList(&self) @inline {
	return !self.onThinkingList();
}

fn void HMEntity.startThinking(&self) @inline 
{
	if (self.thinkflags & EntTh.THINK) return; // already thinking

	self.thinkflags = 0;
	self.thinkflags |= EntTh.THINK;
	if(self.notOnThinkingList()) game::pContext.thinkingEntities.push(self);
}

fn void HMEntity.stopThinking(&self) @inline 
{
	if (!(self.thinkflags & EntTh.THINK)) return; // not thinking

	if (self.thinkflags) {
		self.thinkflags &= ~ent::EntTh.THINK; // remove the thinking flag

		if(self.onThinkingList()) game::pContext.thinkingEntities.remove_at(game::pContext.thinkingEntities.index_of(self)!!);

		// if all thinking flags are removed, then we can deactivate the entity
		if (!self.thinkflags && self.isActive()) {
			self.setActive(false); // deactivate the entity
		}
	}
}

fn bool HMEntity.onActiveList(&self) @inline {
	return game::pContext.activeEntities.contains(self);
}

fn bool HMEntity.notOnActiveList(&self) @inline {
	return !self.onActiveList();
}

fn void HMEntity.setActive(&self, bool active) @inline {
	if (active) {
		if (!self.isActive()) {
			self.flags.active = true;
			if(self.notOnActiveList()) game::pContext.activeEntities.push(self);
		}
	} else {
		if (self.isActive()) {
			self.flags.active = false;
			if(self.onActiveList()) game::pContext.activeEntities.remove_at(game::pContext.activeEntities.index_of(self)!!);
		}
	}
}

fn bool HMEntity.isActive(&self) @inline {
	return self.flags.active;
}

fn void HMEntity.becomeInactive(&self, int flags) 
{
	if ((flags & EntTh.PHYSICS))
	{
		flags &= ~EntTh.PHYSICS;
		return;
		// may only disable physics on a team master if no team members are running physics or bound to a joints
		/*if (teamMaster == this) {
			for (HMEntity *ent = teamMaster.teamChain; ent; ent = ent.teamChain) {
				if ((ent->thinkflags & EntTh.PHYSICS) || ((ent->bindMaster == this) && (ent->bindJoint != INVALID_JOINT))) {
					flags &= ~EntTh.PHYSICS;
					break;
				}
			}
		}*/
	}

	if (self.thinkflags)
	{
		self.thinkflags &= ~flags;
		if (!self.thinkflags && self.isActive())
		{
			//gameLocal.numEntitiesToDeactivate++;
			self.setActive(false);
		}
	}

	/*if ((flags & EntTh.PHYSICS)) {
		// if this entity has a team master
		if (teamMaster && teamMaster != this) {
			// if the team master is at rest
			if (teamMaster->IsAtRest()) {
				teamMaster->BecomeInactive(EntTh.PHYSICS);
			}
		}
	}*/
}

fn void HMEntity.becomeActive(&self, int flags) 
{
	if ((flags & EntTh.PHYSICS))
	{
		// enable the team master if this entity is part of a physics team
		/*if (teamMaster && teamMaster != this) {
			teamMaster->BecomeActive(EntTh.PHYSICS);
		}
		else if (!(thinkflags & EntTh.PHYSICS)) {
			// if this is a pusher
			if (physics->IsType(idPhysics_Parametric::Type) || physics->IsType(idPhysics_Actor::Type)) {
				gameLocal.sortPushers = true;
			}
		}*/
	}

	int oldFlags = self.thinkflags;
	self.thinkflags |= flags;
	if (self.thinkflags)
	{
		if (!self.isActive())
		{
			self.setActive(true);
		}
		else if (!oldFlags)
		{
			// we became inactive this frame, so we have to decrease the count of entities to deactivate
			//gameLocal.numEntitiesToDeactivate--;
			self.setActive(false);
		}
	}
}

fn void HMEntity.move(&self)
{
	if(self.hidden()) return;
	if(self.isDead()) return;

	$if $feature(PHYSICS_BOX2D):
    // update visuals based on physics movement
    // && box2d::body_GetType(self.physics) == box2d::DYNAMIC
    if(((Vec2f)self.physics.getLinearVelocity()).length() > 0.0f ) {
        Vec2f new_pos = self.physics.getPosition();
        self.setPositionV(new_pos);
		Vec2f translation = 
        self.updateBounds(new_pos);
		self.updateVisuals();
    }
	$else
	// todo movement not based on Box2D physics but inhouse one
	$endif
}

fn void HMEntity.onSpawn(&self, String def_name)
{
	self.setSpawnArgs(def_name);
	// this is diferent from init()
	// this should run when the entity is first spawn in a level
	self.health     = self.spawnargs.getInt("health")!!;
	self.max_health = self.spawnargs.getInt("maxhealth")!!;
}

fn void HMEntity.think(&self, float dt) // update in other engines
{
    if(self.thinkflags & EntTh.THINK)
    {
		$if $feature(TRACY_ENABLE):
			tracy::@zoneN("HMEntity.think", 1)
			{
				self.move();
			};
		$else
			self.move();
		$endif

		bool ent_out_of_view = !game::pContext.view.bounds.intersectsOther(&self.bounds);
		if(ent_out_of_view) {
			self.hide();
		}
    }
}

fn void HMEntity.updateVisuals(&self) 
{
	self.becomeActive(EntTh.UPDATEVISUALS);
}

fn void HMEntity.onDraw(&self) @dynamic 
{
	if(self.hidden()) return;
	if(self.isDead()) 
	{
		self.hide();
		return;
	}

	if(!(self.thinkflags & EntTh.UPDATEVISUALS)) {
		return;
	}
	self.becomeInactive(EntTh.UPDATEVISUALS);

	self.super.onDraw();
}

fn void HMEntity.onPostGUIDraw(&self) @dynamic
{
	if(self.hidden()) return;
	if(self.isDead()) 
	{
		self.hide();
		return;
	}

	if(!(self.thinkflags & EntTh.UPDATEVISUALS)) {
		return;
	}
	self.becomeInactive(EntTh.UPDATEVISUALS);

	if(game::pContext.mode == PLAYING || 
	   game::pContext.mode == EDITOR) {/*go on*/} else { return; }

	// draw entities debug info
	int info_value = cvShowInfo.getInt();
	Vec2f org = self.getOrigin();
    if(info_value)
	{
		if(game::isMouseOver{HMEntity}(self))
		{
			String s = self.name;
			int s_len = rl::measureText(s.zstr_tcopy(), game::SMALL_FONT_SIZE);
			Vec2f n_org = org;
			n_org.x = org.x - (1.5f * s_len);
			r2d::drawRectangleRec(misc::@recFromVecs(n_org,(Vec2f){s_len + 2.0f, (float)game::SMALL_FONT_SIZE + 5.0f}), rl::BLACK);
			r2d::draw_small_string((int)n_org.x, (int)n_org.y, s, rl::WHITE);
			r2d::draw_small_string((int)n_org.x + 1, (int)n_org.y + 1, s, rl::DARKGRAY);
		}
		r2d::drawSquare(org, 5, rl::RED);
		if(info_value == 2)
		{
			self.bounds.debugDraw();
		}
	}
}

/*
fn void HMEntity.becomeActive(&self, int flags) {
	
    if (flags & EntTh.PHYSICS) {
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

fn bool HMEntity.isValid(&self)
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

fn HMEntity* create_entity(String aname, Vec2f pos, int w, int h) @public 
{
	HMEntity* ent = mem::new(HMEntity);
	ent.init(aname, pos, {w,h});
	return ent;
}

<*
 @ensure return != null
*>
fn HMEntity* create_ex(String aname, Vec2f origin, Vec2f size) @public 
{
	HMEntity* ent = mem::new(HMEntity);
	ent.init(aname, origin, size);
	return ent;
}

// TODO
fn void cloneEntity( HMEntity* dest, HMEntity* src )
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
			HMEntity * clone;
			HMEntity * child;
			
			// duplicate the children
			if ( !src.bind_info.children[ i ] )
			{
				continue;
			}
			child = G_GetEntity( src.bind_info.children[ i ] );
			if ( child )
			{
				clone = new HMEntity( ENTITY_CREATE_FLAG_ANIMATE );
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
/// HMEntity script events
///////////////////////////////////
fn void event_getName(UmkaStackSlot *params, UmkaStackSlot *result) @if($feature(UMKA_ENABLE))
{
	//HMEntity *ent = (HMEntity *)umkaGetParam(params, 0);
	//@todo();
	Umka *umk = umka::getInstance(result);
    UmkaAPI *api = umk.getAPI();

    HMEntity *ent = api.umkaGetParam(params, 0).ptrVal;
    api.umkaGetResult(params, result).ptrVal = api.umkaMakeStr(umk, ent.name.zstr_tcopy());
}

fn void event_getID(UmkaStackSlot *params, UmkaStackSlot *result) @if($feature(UMKA_ENABLE))
{
	Umka *umk = umka::getInstance(result);
    UmkaAPI *api = umk.getAPI();

    HMEntity *ent = api.umkaGetParam(params, 0).ptrVal;
    api.umkaGetResult(params, result).intVal = (long)ent.id;
}

///////////////////////////////////
/// HMEntity script callbacks
///////////////////////////////////

fn void getMinc(WrenVM* vm) @if($feature(WREN_ENABLE))
{
	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
	HMEntity* ent = (HMEntity*)vm.getSlotForeign(0);
	WrenHandle handle;
	handle.value = *(Value*)&(*ent).bounds.minc;
	vm.setSlotHandle(0, &handle);
}

fn void getMaxc(WrenVM* vm) @if($feature(WREN_ENABLE))
{
	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
	HMEntity* ent = (HMEntity*)vm.getSlotForeign(0);
	WrenHandle handle;
	handle.value = *(Value*)&(*ent).bounds.maxc;
	vm.setSlotHandle(0, &handle);
}

// fn void script_fn_getBounds(WrenVM* vm) 
// {
// 	vm.ensureSlots(1); // slot 0 is the caller (and return slot), slots after that are the fn arguments slots
//     HMEntity* ent = (HMEntity*)vm.getSlotForeign(0);
// 	WrenHandle handle.value = *(Value*)&(*ent).bounds;
//     vm.setSlotHandle(0, &handle);
// }

/********************************* HMEntity Component System (ECS) *********************************/
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
		case HMSprite.typeid:	
			component.data.ptr = mem::new(HMSprite, {}); // default value for HMSprite
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
