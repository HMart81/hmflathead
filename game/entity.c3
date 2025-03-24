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
import raylib5::rl;
import engine::misc;
import game::assets::sprt;
import game::serialize::svs; // save system
import engine::physics::box2d;
// end_region

const int TH_NONE         = 0;
const int TH_THINK        = 1;
const int TH_PHYSICS      = 2; // for the future...
const int MIN_SIZE_VALUE    = 8;
const Vec2i MIN_ENTITY_SIZE = {MIN_SIZE_VALUE, MIN_SIZE_VALUE};

/*
interface EntityInterface {
	fn void init(String aname, Vec2f origin, Color color, typeid _type = Entity.typeid);
	fn void deinit();
	fn void spawn(); // what the diference with init right now?
	fn void think();
	
	//
	fn void setAxis(Matrix2f axis);
	fn void setTexture(Texture2D* tex = null); @optional
	fn Vec2f getWorldForward(); @optional
	fn Vec2f getForward(); @optional
	fn void scale(float w, float h); @optional
	fn void scale_ex(Matrix2f axis); @optional
	fn void scaleV(Vec2f scale); @optional
	fn void scaleEqualy(float scaler); @optional
	fn void setOrigin(float x, float y); @optional
	fn void setOriginV(Vec2f newpos); @optional
	fn void rotate2D(float angle); @optional
	fn bool isdead(); @optional
    fn void hide(); @optional
    fn void show(); @optional
    fn bool isHidden(); @optional
}
*/

struct Entity (SaveSystemInterface)
{
	int id;
	typeid type;
	String name;
    //
    Sprite vs;
    //
    // physics
    box2d::BodyId physics;
    //
	int flags;
	//LinkList(<Entity>) activeNode;	// for being linked into activeEntities list
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

fn void Entity.init(&self, String aname, Vec2f origin = {0,0}, Color color = rl::WHITE) @public 
{
	if(self.shouldSkip(aname)) return;
	
	self.type = Entity.typeid;
	
	int entity_count = (int)main::gpGame.entityList.len();
	if( entity_count <= 0 ) {
		unreachable("invalid entity count, missing player1 entity?");
	}
	self.id = entity_count + 1;
    
	if(aname == "") {
		if(self.id < 10) {
			self.name = string::tformat("entity0%s", self.id);
		} else {
			self.name = string::tformat("entity%s", self.id);
		}
	} else {
		self.name = aname.copy();
	}
    
$if $feature(_DEBUG):
	lgr::info(Where.FILE, "Created entity-> id: %s with name: %s.", self.id, self.name);
$endif
    
	//
    self.vs.initV(origin, MIN_ENTITY_SIZE, color);
    //
    
    // physics
    // define the body
    box2d::BodyDef bodyDef   = box2d::defaultBodyDef();
    bodyDef.type             = box2d::BodyType.DYNAMIC;
    bodyDef.position         = box2d::vec2fToVec2(origin);
    // create the body
    self.physics             = box2d::createBody(main::gpGame.physWorldId, &bodyDef);
    //
    // create the polygon shape
    // ‍Caution: A dynamic body should have at least one shape with a non-zero density. 
    // Otherwise you will get strange behavior.
    // TODO(HM) Set the correct size at creation time!!!
    box2d::Polygon dynamicBox = box2d::makeBox(1.0f, 1.0f); //@hardcode
    box2d::ShapeDef shapeDef  = box2d::defaultShapeDef();
    shapeDef.density          = 1.0f;
    shapeDef.friction         = 0.3f;
	box2d::shapeCreatePolygon(self.physics, &shapeDef, &dynamicBox);
    //
    
	self.alive = true;
	self.startThinking();
	self.register();
}

fn void Entity.setTexture(&self, String texture_name_with_ext) @inline {
	self.vs.tex = main::asstManager.getAssetExt(texture_name_with_ext, Texture2D.typeid);
}

<*
* @ensure return != null
*>
fn Texture2D* Entity.getTexture(&self) @inline {
	return (Texture2D*)self.vs.tex.data.ptr;
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

fn void Entity.setPosition(&self, float x, float y) @inline
{
	self.vs.setPosition(x, y);
}

fn void Entity.setPositionV(&self, Vec2f newpos) @inline
{
	self.vs.setPositionV(newpos);
}

fn Vec2f Entity.getPosition(&self) @inline
{
	return self.vs.getPos();
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

fn bool Entity.isdead(&self) @inline
{
	return (self.alive) ? false : true;
}

fn void Entity.hide(&self) @inline => self.vs.hide();

fn void Entity.show(&self) @inline => self.vs.show();

fn bool Entity.isHidden(&self) @inline => self.vs.hidden();

fn void Entity.setname(&self, String* aname) @inline
{
	if(aname)
	{
		self.name = aname.copy();
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
		if (other == null || other.isdead() || other.isHidden()) {
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
		if(other.isdead() || other.isHidden()) continue;
		
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

fn void Entity.born(&self) @inline @local { if(self.alive) return; self.alive = true; }

fn void Entity.register(&self) @inline
{
	// NOTE(HM) shouldn't never happen, but who knows...
	assert(self.isValid(), "error cannot register entity because is not valid!");
    self.born();
	main::gpGame.entityList.push(self);
}

fn void Entity.draw(&self) 
{
	if(self.isHidden() || self.isdead()) return;
	
	//
	if(self.vs.asTexture()) {
        Vec2f tex_size = self.vs.getTextureSize();
		//rl::drawTextureRec(*self.tex, self.rect, self.origin, self.color);
		//rl::drawTextureV(*self.tex, self.origin, self.color);
		Rectangle source = {0, 0, tex_size.x, tex_size.y};
		// center of the texture (rotation/scale point), it's relative to destination rectangle dimentions, not the screen
		rl::drawTexturePro(*self.vs.getTexture(), source, self.vs.rect, {0, 0}, 0.0f, self.vs.color);
		//rl::drawTextureEx(*self.tex, self.origin, 0, 1.0f, self.color);
	//$if $feature(_DEBUG):
	//	rl::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
//	$endif
	} else {
		rl::drawRectangleRec(self.vs.rect, self.vs.color);
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

fn void Entity.think(&self, float dt) // update in other engines
{
	float think_st = @start_profile_zone();
	defer @end_profile_zone(think_st);
	
	if(self.flags & TH_THINK)
	{
        // TODO find why this crash's
        self.setPositionV(box2d::vec2ToVec2f(box2d::bodyGetPosition(self.physics)));
        
		//io::printf("Entity '%s' has flag %s!!!\n", self.name, self.flags);
		//self.rotateX(1);
	}
}

// fn void Entity.becomeActive(&self, int flags) {
	
	// int oldFlags = self.flags;
	// self.flags |= flags;
	// if (self.flags) {
		// if (!isActive()) {
			// activeNode.AddToEnd(gameLocal.activeEntities);
		// }
		// else if (!oldFlags) {
			// // we became inactive this frame, so we have to decrease the count of entities to deactivate
			// gameLocal.numEntitiesToDeactivate--;
		// }
	// }
// }

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
    self.getSizei().x >= MIN_SIZE_VALUE &&
    self.getSizei().y >= MIN_SIZE_VALUE)
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
* @ensure return != null
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
