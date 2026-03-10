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

/*
Event's are used to link wren script fn to c3 fn.

NOTE(HM) They work like this
EV_name("script func name", "func PARAM types", 'func RETURN type')

example:
    EV_Foo("foo","f",'d'); ==  fn int foo(float value) { return some_int; }
    EV_Foo2("foo2", "",'f'); == fn float foo2() { return some_float; }
    EV_Bar("bar", "ff",'e'); == fn Entity* bar(float value, float value2) { return some_entity_adress; }
*/

module engine::sys::script_engine::event @if($feature(WREN_ENABLE));

import std::collections::linkedlist, std::collections::list;

import thirdparty::wren;
import engine::sys::script_engine::scpt;
import engine::misc;
import engine::logging::log;


////// WARNING(HM) NOTE(HM) For some reason I cannot make, foreign functions work, meaning calling C3 functions.
////// This despite bindForeignMethod being called correctly and both 
////// writeFn and errorFn, working just fine and are also called from c3 code!!!!!!? :( 

<*
 @param [&in] vm : "current wren virtual machine calling this func"
*>
fn void add(WrenVM* vm)
{
    vm.ensureSlots(3);
	// slot 0 is the caller (and return slot), slot 1 and 2 are the fn arguments slots
    double a = vm.getSlotDouble(1);
    double b = vm.getSlotDouble(2);
    vm.setSlotDouble(0, a + b);
}

<*
 @param [in] vm : "current wren virtual machine calling this func"
 @require vm != null
*>
fn void vec2_translate(WrenVM* vm)
{
    vm.ensureSlots(3); // slot 0 is the caller (and return slot), slot 1 and 2 are the fn arguments slots
    Vec2f vec1 = *(Vec2f*)vm.getSlotForeign(0);
    double a = vm.getSlotDouble(1);
    double b = vm.getSlotDouble(2);
    vec1.translateV({(float)a, (float)b});
    Vec2f* vecp = (Vec2f*)vm.setSlotNewForeign(0,0, Vec2f.sizeof);
    mem::copy(vecp, &vec1, Vec2f.sizeof);
    vecp = null; 
}

<*
 @param [&in] vm : "current wren virtual machine calling this func"
*>
fn void logToFile(WrenVM* vm)
{
    int slots = vm.getSlotCount();
    if(slots != 2) vm.ensureSlots(2); // slot 0 is the caller (and return slot), slot 1 is the fn argument slot
    WrenType type = vm.getSlotType(1);
    assert(type == WrenType.STRING, "message must be a string");
    String message = ((ZString)vm.getSlotString(1)).str_view();
    lgr::info(Where.FILE, "%s", message);
    //vm.setSlotDouble(0, a + b);
}

















const ENABLE_EVENTS = true; // enable events system, if false, the event system will not be compiled


const MAX_FN_PARMS = 8;
const MAX_EVENTS = 8192;
const MAX_EVENTSPERFRAME = 8192;

// The only number type in wren, is double precision floating point number or double (64bit). 
const VOID			= ((char)0); // wren uses null as void
const DOUBLE		= 'd';
const INTEGER		= 'i'; // just a double
const FLOAT			= 'f'; // just a double
const VECTOR		= 'v'; // a list of doubles
const STRING		= 's'; // a char array
//
// TODO: wren "pointers" will be defined as a single double value (like they are in reality on 64bits OS's...)
const ENTITY		= 'e'; // entity pointer
const ENTITY_NULL	= 'E'; // null entity
// TODO: ability todo 2d collision traces in script
const TRACE			= 't'; // todo

struct EventDef
{
	String name;
	String argtypes; // ex: "ffd" or "" or "dfde", etc.
	char returnType;
}

<*
	@require $kindof(#ev) == (&EventDef) &&& $kindof(#func) == (&EventFunc)
*>
macro @event(#ev, #func) => {&(#ev), &(#func)};

// double because wren uses double as the only number type, we use it to store the size of the eventDef
fn usz getArgBytesCount(EventDef* ev, typeid type = double.typeid) 
{
	switch(type)
	{
		case double.typeid:
			return (ev.argtypes.len * double.sizeof);
		case float.typeid:
			return (ev.argtypes.len * float.sizeof);
		case int.typeid:
			return (ev.argtypes.len * int.sizeof);
		default:
			unreachable("Can't get argument byte count from an unkown type!");
	}

	return 0;
}

<*
 @ensure return != null
*>
fn EventDef* getEventCommand(EventFunc[] events,  int eventnum ) @nodiscard
{
	return events[eventnum].event;
}

fn EventDef* findEvent(EventFunc[] events, String name ) 
{
	assert( name != "" );

	foreach( evfunc : events) 
	{
		if ( evfunc.event.name == name ) {
			return evfunc.event;
		}
	}

	return null;
}

struct EventFunc {
	EventDef	*event;
	WrenForeignMethodFn	callback;
}

fn String getSignature(EventDef ev) @inline 
{
	String sig = ev.name;
	int args_count = ev.argtypes.len;
	if(args_count > 0) 
	{
		sig = "(".tconcat(sig);
		for(int i = 0; i < args_count; i++)
		{
			if(i != (args_count - 1)) // if not the last argument
			{
				sig = sig.tconcat("_,");
			} 
			else 
			{
				sig = sig.tconcat("_");
				break;
			}
		}
		sig = sig.tconcat(")"); // close the argtypes signature
	}
	else
	{
		sig = "(".tconcat(sig).tconcat(")");
	}

	return sig;
}

//

// alias EventFuncList = List{EventFunc};
// macro @even_linking( #nameofclass; @body) 
// {
//    const EventFunc[*] $stringify(#nameofclass)_EVENTCALLBACKS = {
//         body();
//         { 0, 0 }
//     };
// }

///////////////////////////////////////////////////////////////////////////////
//
//                          UMKA SCRIPT EVENTS
//
//////////////////////////////////////////////////////////////////////////////


/*
Event's are used to link scripts fn to c3 fn.

NOTE(HM) They work like this
EV_name("script func name", "func PARAM types", 'func RETURN type')

example:
    EV_Foo("foo","f",'d'); ==  fn int foo(float value) { return some_int; }
    EV_Foo2("foo2", "",'f'); == fn float foo2() { return some_float; }
    EV_Bar("bar", "ff",'e'); == fn Entity* bar(float value, float value2) { return some_entity_adress; }
*/

module engine::sys::script_engine::event @if($feature(UMKA_ENABLE));

import std::collections::linkedlist, std::collections::list;

import thirdparty::scripting::umka;
import engine::sys::script_engine::scpt;
import engine::misc;
import engine::logging::log;

const ENABLE_EVENTS = true; // enable events system, if false, the event system will not be compiled


const MAX_PARMS = 8;
const MAX_EVENTS = 8192;
const MAX_EVENTSPERFRAME = 8192;

const VOID		= ((char)0);
// The int and uint are the recommended 64-bit integer types. 
// Other integer types are for compatibility with an external environment.
const INT    = 'i'; // a 64bits signed integer (int)
const UINT	 = 'y'; // a 64bits unsigned integer (uint)
//
const REAL32 = 'f'; // a 64bits floating point number (real)
const REAL   = 'F'; // a 64bits floating point number (real)
//
const VECTOR = 'v'; // a list of f64's/REAL's
const STRING = 's'; // a char/u8 array
const PTR    = 'p';
//
// TODO: "pointers" will be defined as a single double value (like they are in reality on 64bits OS's...)
const ENTITY		= 'e'; // entity pointer
const ENTITY_NULL	= '€'; // null entity
// TODO: 2d collision traces in script
const TRACE			= 't'; // todo

alias EventDefList = List{EventDef*}; // list of entities that are targets for this entity

EventDefList eventDefList @local;

fn uint numEventCommands() => (uint)eventDefList.len();

struct EventDef @packed
{
	String name; // script function name
	String argtypes; // fn params as array of strings
	String returnType; // fn return type as a string
}

<*
	Get the number of the event from 1 to MAX_EVENTS
	@param [&in] _ev : "pointer of event to look for"
*>
fn uint getNum(EventDef* _ev) @nodiscard
{
	foreach(i, ev : eventDefList) 
	{
		if ( ev == _ev ) {
			return (uint)(i + 1);
		}
	}

	return 0;
}

<*
	Get the index of the event from 0 to MAX_EVENTS - 1
	@param [&in] _ev : "pointer of event to look for"
*>
fn uint getIndex(EventDef* _ev) @nodiscard
{
	foreach(i, ev : eventDefList) 
	{
		if ( ev.name == _ev.name ) {
			return (uint)i;
		}
	}

	return 0;
}

fn EventDef* find(String name)
{
	assert( name != "" );

	foreach( ev : eventDefList) 
	{
		if ( ev.name == name ) {
			return ev;
		}
	}

	return null;
}

// warning makes no testing to see if events are duplicated
// and now because of the way the event system is done, is very
// easy for two diferent events to have the same internal, name string.
// Todo(HM) find a way to ignore duplicate events
fn void registerEvents(EventFunc[]* events) 
{
	foreach(ev : events) 
	{
		// @performance!!
		if(isDuplicated(ev.event)) {
			unreachable("Trying to register a event again, that is not supported!");
		} else {
			eventDefList.push(ev.event);
		}
	}
}

fn bool isDuplicated(EventDef* _ev) @local
{
	// find duplicates;
	foreach(ev : eventDefList)
	{
		if(ev == _ev) return true;
	}

	return false;
}

struct EventFunc 
{
	EventDef* event;
	// signature = fn void(UmkaStackSlot *params, UmkaStackSlot *result);
	ExternFuncCallback callback;
}

<*
	ex: 
		EventDef* entity_cmd_x = event::getEventCommand(ENTITY_EVENTS, 5); 

	@param [&in] events : "pointer to the array of events"
	@param index : "index of the event in the array"
	@ensure return != null
*>
fn EventDef* getEventCommand(EventFunc[]* events,  int index ) {
	return (*events)[index].event;
}