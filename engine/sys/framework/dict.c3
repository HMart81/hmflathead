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
module engine::sys::framework::hmdict;

import std::io;
import std::collections::list;
import engine::misc;
import engine::logging::log;
import game;

/*
===============================================================================

Key/value dictionary

This is a dictionary class that tracks an arbitrary number of key / value
pair combinations. It is used for map entity spawning, GUI state management,
and other things.

Keys are compared case-insensitive.

Does not allocate memory until the first key/value pair is added.

===============================================================================
*/

faultdef FAULT_EMPTY_KEY, FAULT_MISSING_KEY, FAULT_PARSING_ERROR;

struct HMKeyValue (Printable)
{
	String	key;
	String	value;
}

fn sz? HMKeyValue.to_format(&self, Formatter* f) @dynamic
{
	return f.printf("%s = %s;", self.key, self.value);
}

fn bool HMKeyValue.equal(&self, HMKeyValue kv ) @operator(==) { 
	return self.key == kv.key && self.value == kv.value; 
}

const DEF_DATA_FILE_PATH = "defs.data";

constdef DefType : inline String
{
	ENTITY = "entityDef"
}

alias SpawnArgsList = List{HMKeyValue*};
struct HMDict
{
	SpawnArgsList args;
}


fn void HMDict.init(&self) 
{
	self.args.tinit();
	self.args.reserve(128);
}

fn void HMDict.register(&self, HMKeyValue* kv ) {
	self.args.push(kv);
}

fn void HMDict.copy(&self, HMDict* other ) {
	*self = *other;
}

fn void HMDict.clear(&self, bool free_list = true) {
	if(self.args.len()) 
	{
		if(free_list) {
			self.args.free();
		} else {
			self.args.clear();
		}
	}
}

fn void HMDict.delete(&self, String key ) {
	self.args.remove_at((sz)self.findKeyIndex(key));
}

fn void HMDict.reserve(&self, int count ) {
	self.args.reserve( count );
}

fn void HMDict.setFloat(&self, String key, float val ) {
	self.set( key, string::tformat( "%s", val ) );
}

fn void HMDict.setInt(&self, String key, int val ) {
	self.set( key, string::tformat( "%s", val ) );
}

fn void HMDict.setBool(&self, String key, bool val ) {
	self.set( key, string::tformat( "%s", val ) );
}

fn void HMDict.setVec3(&self, String key, Vec3f* val ) {
	self.set( key, val.toString() );
}

fn void HMDict.setVec4(&self, String key, Vec4f* val ) {
	self.set( key, val.toString() );
}

fn void HMDict.setVec2(&self, String key, Vec2f* val ) {
	self.set( key, val.toString() );
}

/*fn void HMDict.SetAngles( String key, const idAngles &val ) {
	Set( key, val.ToString() );
}*/

/*fn void HMDict.SetMatrix( String key, const idMat3 &val ) {
	Set( key, val.ToString() );
}*/

fn bool HMDict.getStringOut(&self, String key, String defaultString, String *out ) {
	HMKeyValue*? kv = self.findKey( key );
	if ( catch excuse = kv ) {
		*out = defaultString;
		return false;
	}
	*out = kv.value.tcopy();
	return true;
}

fn String HMDict.getString(&self, String key, String defaultString ) {
 	HMKeyValue*? kv = self.findKey( key );
	if ( catch excuse = kv ) {
		return defaultString;
	}
	return kv.value.tcopy();
}

fn float? HMDict.getFloat(&self, String key, String defaultString = "0.0" )  {
	return self.getString( key, defaultString ).to_float()!;
}

fn int? HMDict.getInt(&self, String key, String defaultString = "0" ) {
	return self.getString(key, defaultString).to_int()!;
}

fn bool? HMDict.getBool(&self, String key, String defaultString = "false" ) {
	String value = self.getString(key, defaultString);
	switch(value)
	{
		case "false": return false;
		case "true":  return true;
	}

	int d = value.to_int()!;
	if(d < 0 || d > 0) // just like c anything but zero is true
	{ 
		return true; 
	} else {
		return false;
	}
}

fn bool? HMDict.getVec3Out(&self, String key, String defaultString, Vec3f* out ) {
	bool found;
	String s;

	if ( !defaultString ) {
		defaultString = "0 0 0";
	}

	found = self.getStringOut( key, defaultString, &s );
	//libc::sscanf( s, "%f %f %f", &out.x, &out.y, &out.z );
	Splitter peaces = s.tokenize(" ");
	for(int i = 0; i < 3; i++) {
		(*out)[i] = peaces.next().to_float()!;
	}
	return found;
}

fn bool? HMDict.getVec2Out(&self, String key, String defaultString, Vec2f* out ) {
	bool found;
	String s;

	if ( !defaultString ) {
		defaultString = "0 0";
	}

	found = self.getStringOut( key, defaultString, &s );
	//libc::sscanf( s, "%f %f", &out.x, &out.y);
	Splitter peaces = s.tokenize(" ");
	for(int i = 0; i < 2; i++) {
		(*out)[i] = peaces.next().to_float()!;
	}
	return found;
}

fn bool? HMDict.getVec4Out(&self, String key, String defaultString, Vec4f* out ) {
	bool found;
	String s;

	if ( !defaultString ) {
		defaultString = "0 0 0 0";
	}

	found = self.getStringOut( key, defaultString, &s );
	//libc::sscanf( s, "%s %s %s %s", &out.x, &out.y, &out.z, &out.w );
	Splitter peaces = s.tokenize(" ");
	for(int i = 0; i < 4; i++) {
		(*out)[i] = peaces.next().to_float()!;
	}
	return found;
}

fn Vec3f? HMDict.getVec3(&self, String key, String defaultString = "0 0 0") {
	Vec3f out;
	self.getVec3Out( key, defaultString, &out )!;
	return out;
}

fn Vec2f? HMDict.getVec2(&self, String key, String defaultString = "0 0")  {
	Vec2f out;
	self.getVec2Out( key, defaultString, &out )!;
	return out;
}

fn Vec4f? HMDict.getVec4(&self, String key, String defaultString = "0 0 0 0")  {
	Vec4f out;
	self.getVec4Out( key, defaultString, &out )!;
	return out;
}

fn HMKeyValue* HMDict.getKeyVal(&self, int index )
{
	if ( index >= 0 && index < self.args.len() ) {
		return self.args[ index ];
	}
	return null;
}

fn HMKeyValue*? HMDict.findKey(&self, String key ) 
{
	if ( key == "" || key[0] == '\0' ) {
		log::warning(FILE, "HMDict.findKey: empty key" );
		return FAULT_EMPTY_KEY~;
	}

	foreach (arg : self.args) {
		if ( arg.key == key ) {
			return arg;
		}
	}

	return FAULT_MISSING_KEY~;
}

<*
	get a spawnarg key index 
	@param [in] key : " the key"
	@require key.len > 0
*>
fn int HMDict.findKeyIndex(&self, String key )  {

	if ( key == "" || key[0] == '\0' ) {
		log::warning(FILE, "HMDict.findKeyIndex: empty key" );
		return 0;
	}

	foreach (i, arg : self.args) {
		if ( arg.key == key ) {
			return (int)i;
		}
	}

	return -1;
}

<*
	Set a spawnarg key value 
	@param [in] key : " the key"
	@param [in] value : " the value"
	@require key.len > 0
*>
fn void HMDict.set(&self, String key, String value ) {
	if (key.len == 0) {
		return;
	}

	int i = self.findKeyIndex( key );
	if ( i != -1 ) {
		(*self.args[i]).value = value.tcopy();
	} else {
		self.register(mem::new(HMKeyValue, {
			.key   = key.tcopy(),
			.value = value.tcopy()
		}));
	}
}

fn void HMDict.list_spawnargs(&self) {
	log::info(CONSOLE, "Spawnargs = {");
	foreach (arg : self.args) {
		log::info(CONSOLE, "%s", arg);
	}
	log::info(CONSOLE, "}");
}

fn void? HMDict.parse(&self, DefType def_type, String def_name )
{
	String path = game::pContext.app_base_folder.tconcat(DEF_DATA_FILE_PATH);
	JSCObject* parser = game::load_jsonc_obj(path)!;
	defer game::free_jsonc( obj: parser );

	if(parser.has_key(def_type)) 
	{
		JSCObject* ent_def_root = parser.get(def_type)!;
		if(ent_def_root && ent_def_root.has_key(def_name)) {
			JSCObject* def = ent_def_root.get(def_name)!;
			def.map.@each(; String key, value)
			{
				if(key != "")
				{
					assert(value.is_string() && !value.is_empty());
					self.register(mem::new(HMKeyValue, {
						.key   = key, 
						.value = value.to_value(String)!
					}));
				} else {
					log::warning(FILE, "HMDict.parse: empty key found for dictionary object \"%s\" inside defs.data file!", def_name);
				}
			};
		}
    }
	return FAULT_PARSING_ERROR~;
}

