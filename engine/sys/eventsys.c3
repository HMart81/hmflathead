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

module engine::sys::event @if($feature(WREN_ENABLE));

import std::collections::linkedlist, std::collections::list;

import thirdparty::wren;

const MAX_FN_PARMS = 8;
const MAX_EVENTS = 8192;
const MAX_EVENTSPERFRAME = 8192;

// The only number type in wren, is double precision floating point number or double (64bit). 
const VOID			= ((char)0); // wren uses null as void
const INTEGER		= 'i'; // just a double
const FLOAT			= 'f'; // just a double
const DOUBLE		= 'd'; // ...
const VECTOR		= 'v'; // a list of doubles
const STRING		= 's'; // a char array
//
const ENTITY		= 'e'; // todo entity pointer
const ENTITY_NULL	= 'E'; // todo, wren "pointers" will be defined as a single double value (like they are in reality on 64bits OS's...)
const TRACE			= 't'; // todo

// tells if the event system was initialized
bool initialized @local;

//alias EventLinkedList = Linkedlist{Event};
alias EventDefList = List{EventDef*};

EventDefList eventDefList;

struct EventDef 
{
	String name;
	String params; // ex: "ffd" or "" or "dfde"
	char returnType;
}

fn int EventDef.getNumArgs(&self) {
	return self.params.len;
}

fn usz EventDef.getArgBytesCount(&self) {
	return (self.getNumArgs() * double.sizeof);
}

fn void EventDef.register(&self) {
	eventDefList.push(self);
}

<*
* @ensure return != null
*>
fn EventDef* getEventCommand(int eventnum ) {
	return eventDefList[ eventnum ];
}

fn EventDef* findEvent(String name ) {
	assert( name != "" );

	foreach( ev : eventDefList) {
		if ( ev.name == name ) {
			return ev;
		}
	}

	return null;
}

struct EventFunc {
	EventDef	*event;
	WrenForeignMethodFn	function;
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