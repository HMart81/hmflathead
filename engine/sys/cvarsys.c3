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

// TODO(HM)
// implement cvar reset see L:\dark_dev\dhewm\neo\framework\CVarSystem.cpp for a good example
// convert L:\dark_dev\dhewm\neo\idlib\CmdArgs.cpp to C3 to use it as a base for our command arguments system
// bring L:\dark_dev\dhewm\neo\framework\CmdSystem.h to C3 to use it as a base for our command system


module engine::sys::cvar;

// #region import modules
import std::io;
import std::collections::list;
import engine::misc;
//import engine::sys::cmd; still not fully implemented
import engine::logging::lgr;
import thirdparty::raylib5::rl;
import game::main;
// #endregion

// #region defines
alias CvarList = List{Cvar*};
// #endregion

// region constantes
//const int PRINT_CVAR_SETTING = 1;
// end_region

enum CvarFlags : (inline int val) // not used yet
{
	CVAR_ALL				= -1,		// all flags
	CVAR_BOOL				= misc::@bit(0),	// variable is a boolean
	CVAR_INTEGER			= misc::@bit(1),	// variable is an integer
	CVAR_FLOAT				= misc::@bit(2),	// variable is a float
	CVAR_SYSTEM				= misc::@bit(3),	// system variable
	CVAR_RENDERER			= misc::@bit(4),	// renderer variable
	CVAR_SOUND				= misc::@bit(5),	// sound variable
	CVAR_GUI				= misc::@bit(6),	// gui variable
	CVAR_GAME				= misc::@bit(7),	// game variable
	CVAR_TOOL				= misc::@bit(8),	// tool variable
	CVAR_USERINFO			= misc::@bit(9),	// sent to servers, available to menu
	CVAR_SERVERINFO			= misc::@bit(10),	// sent from servers, available to menu
	CVAR_NETWORKSYNC		= misc::@bit(11),	// cvar is synced from the server to clients
	CVAR_STATIC				= misc::@bit(12),	// statically declared, not user created
	CVAR_CHEAT				= misc::@bit(13),	// variable is considered a cheat
	CVAR_NOCHEAT			= misc::@bit(14),	// variable is not considered a cheat
	CVAR_INIT				= misc::@bit(15),	// can only be set from the command-line
	CVAR_ROM				= misc::@bit(16),	// display only, cannot be set by user at all
	CVAR_ARCHIVE			= misc::@bit(17),	// set to cause it to be saved to a config file
	CVAR_MODIFIED			= misc::@bit(18)	// set when the variable is modified
}

// todo(HM) replace this with the cvar flags
enum CvarType : char
{
    NONE,
    FLOAT,
    INT,
    BOOLEAN,
    STRING
}

struct Cvar
{
    String   name;
    CvarType type;
    String   value;
    //String   resetvalue; // resetting will change to this value (not used yet)
    String   description;
    //int      flags; // flags for the cvar (not used yet)
    //float valueMin; // min value for the cvar (not used yet)
    //float valueMax; // max value for the cvar (not used yet)

    // this could be done by using function -> fn String[] String.tsplit(s, String delimiter, usz max = 0, bool skip_empty = false) => s.split(tmem, delimiter, max, skip_empty)
    /*
    // not sure if the best example, but is enough for now
    String[*] menuResolutionList = {"800x600", "1024x720"}; // resolution strings to show on the main menu options (not used yet)
    r_res.initWithStrings("r_res", "640x480", CVAR_GUI | CVAR_NOCHEAT | CVAR_ARCHIVE, "resolution to show on the main menu", string::tformat("%s", "800x600;1024x720").split(";"), cmd::SystemPtr.argCompletion_String(&menuResolutionList));
    */
    //String[] valueStrings; // list of strings for the cvar (not used yet)

    // NOTE(HM) 
    // The pointer was a idea I saw on Star Trek Elite Force 1 SDK game code
    // they used a linked list of cvars, to loop through them.
    // But I think it makes the cvar declaration and looping through more involved as well,
    // so for the time being, I decided for a global dynamic list instead.
    // But this is still a cool idea to save for the future if needed....
    //Cvar* next;
}

CvarList cvars;

macro @register(#cvar) {
    cvars.push(#cvar);
$if $feature(_DEBUG):
    io::printfn("[INFO] Registered Cvar %s (%s).", #cvar.name, #cvar.description);
$endif
}

/*
    How to use the macros:
    1. Declare the cvar in your code at the top of the file, like this:
    Cvar someCvar;

    2. Use the macro to initialize the cvar, like this inside a function:
    OnGameStart() {
        someCvar.init("someCvar", "0", CVAR_SYSTEM | CVAR_NOCHEAT, "some cvar description");
    }

*/
/*
// Always use one of the following initializers.
macro Cvar.init(&self, String name, String value, int flags, String description, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.type  = CvarType.NONE;
    self.value = value.copy(mem);
    //self.resetvalue = ""; // not used yet
    self.description = description.copy(mem);
    //self.valueCompletion = valueCompletion; // not used yet
    //self.flags = flags; // not used yet
    //self.valueMin = 0.0f; // not used yet
    //self.valueMax = 0.0f; // not used yet
    //self.valueStrings = null; // not used yet
    //self.next = null; // not used yet

    @register(self);
}
macro Cvar.initMinMax( String name, String value, int flags, const String description, float valueMin, float valueMax, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.type  = CvarType.NONE;
    self.value = value.copy(mem);
    //self.resetvalue = ""; // not used yet
    self.description = description.copy(mem);
    //self.valueCompletion = valueCompletion; // not used yet
    //self.flags = flags; // not used yet
    self.valueMin = valueMin; // not used yet
    self.valueMax = valueMax; // not used yet
    //self.valueStrings = null; // not used yet
    //self.next = null; // not used yet

    @register(self);
}
macro Cvar.initWithStrings( String name, String value, int flags, String description, String[] valueStrings, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.type  = CvarType.NONE;
    self.value = value.copy(mem);
    //self.resetvalue = ""; // not used yet
    self.description = description.copy(mem);
    //self.valueCompletion = valueCompletion; // not used yet
    //self.flags = flags; // not used yet
    //self.valueMin = 0.0f; // not used yet
    //self.valueMax = 0.0f; // not used yet
    self.valueStrings = valueStrings.copy(mem); // not used yet
    //self.next = null; // not used yet

    @register(self);
}
*/

// fn void register_cvars(Cvar*[] cvars) {
    // foreach(cv: cvars) {
        // @register(*cv);
    // }
// }

// // compile time definition of a cvar
// macro void @make_cvar($name, $_type, $value, $disc)
// {
    // Cvar cv = { $name, $_type, $value, $disc };
    // cvars.push(&cv);
// }

fn bool Cvar.getBool(&self) {
    if(self.type != CvarType.BOOLEAN) {
        lgr::warning(Where.FILE, "Cvar: %s is not a bool: %s->%d", self.name, $$FUNC, $$LINE);
        return false;
    }
    
    if(self.value == "true") { 
        return true; 
    } else if(self.value == "false" || self.value == "") { 
        return false;
    }
    
    // from here we expect a valid integer value
    char? value = self.value.to_uchar();
    
    if(catch excuse = value) {
        lgr::error(Where.FILE, "Cvar: %s fault '%s' :: %s->%d", self.name, excuse, $$FUNC, $$LINE);
        return false;
    }
    
    return (value > 0) ? true : false;
}

fn int Cvar.getInt(&self) {
    if(try int result = self.value.to_int()) {
        return result;
    } else {
        lgr::warning(Where.FILE, "unable to get integer value for '%s' :: %s->%d", self.name, $$FUNC, $$LINE);
        return 0;
    }
}

fn float Cvar.getfloat(&self) {
    if(try float result = self.value.to_float()) {
        return result;
    } else {
        lgr::warning(Where.FILE, "unable to get float value for '%s' :: %s->%d", self.name, $$FUNC, $$LINE);
        return 0.0;
    }
}

fn String Cvar.getString(&self) @inline {
    if(self.type != CvarType.STRING) {
        lgr::warning(Where.FILE, "Cvar: %s was not defined as a string: %s->%d", self.name, $$FUNC, $$LINE);
        return "";
    }
    
    return self.value;
}

fn Cvar* Cvar.set(&self, String value) @inline {
    self.value = value.tcopy();
$if $feature(_DEBUG):
    if(self.type == CvarType.BOOLEAN) {
        io::printfn("[INFO] Cvar %s was set to %s.", self.name, (self.value == "1") ? "true" : "false");
    } else {
        io::printfn("[INFO] Cvar %s was set to value %s.", self.name, value);
    }
$endif
    return self;
}

fn Cvar* findCvar( String name ) @local @inline {
    foreach( cvar : cvars ) {
        if ( cvar.name == name ) {
            return cvar;
        }
    }
	return null;
}


fn String getCVarString( String name ) @inline {
    Cvar* internal = findCvar( name );
    if ( internal ) {
        return internal.getString();
    }
    return "";
}

fn bool getCVarBool( String name ) @inline {
    Cvar* internal = findCvar( name );
    if ( internal ) {
        return internal.getBool();
    }
    return false;
}

fn int getCVarInteger( String name ) @inline {
    Cvar* internal = findCvar( name );
    if ( internal ) {
        return internal.getInt();
    }
    return 0;
}

fn float getCVarFloat( String name ) @inline {
    Cvar* internal = findCvar( name );
    if ( internal ) {
        return internal.getfloat();
    }
    return 0.0f;
}


fn bool command( String[] args ) {
	Cvar *internal = findCvar( args[0]);

	if ( internal == null ) {
		return false;
	}

	if ( args.len == 1 ) {
		// print the variable
		//io::printfn( "\"%s\" is:\"%s\" default:\"%s\"\n", internal.name, internal.value, (internal.resetvalue) ? internal.resetvalue : "" );
		io::printfn( "\"%s\" is:\"%s\"", internal.name, internal.value);
		if ( internal.description.len > 0 ) {
			io::printfn("%s", internal.description );
		}
	} else {
		// set the value
        // todo(HM) convert this function
		//internal.set( args.Args(), false, false );
	}
	return true;
}

alias CvarCompletionCallback = fn void( String s );
fn void commandCompletion( CvarCompletionCallback callback ) {
	for( int i = 0; i < cvars.len(); i++ ) {
		callback( cvars[i].name );
	}
}

// unfinished
fn void argCompletion( String cmdString, CvarCompletionCallback callback ) {
	/*CmdArgs args;

	args.tokenizeString( cmdString, false );

	for( int i = 0; i < cvars.len; i++ ) {
		if ( !cvars[i].valueCompletion ) {
			continue;
		}
		if ( args[0] == cvars[i].name) {
			cvars[i].valueCompletion( args, callback );
			break;
		}
	}*/
}


/*fn void Cvar.init(&self, String name, CvarType _type, String value, String description) {
    self.name  = name;
    self.type  = _type;
    self.value = value;
    self.description = description;
    @register(self);
}*/
