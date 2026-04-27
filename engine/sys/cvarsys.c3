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
// Rework the cvar system to be more like the one on idTech 4, with a global list of cvars and a macro to register them, and functions to get/set them by name, and also support for different flags (system, renderer, sound, cheat, etc).
// Also add support for cvar completion in the console, and for archiving cvars to a config file.
// Also add support for cvar reset to default value, and for cvar min/max values.
// Also add support for cvar change callbacks, so that when a cvar is changed, a callback function can be called to handle the change (e.g. for changing the renderer settings when a renderer cvar is changed).
// Also add support for cvar value strings, so that a cvar can have a list of valid string values (e.g. for a cvar that sets the resolution, it can have a list of valid resolution strings to choose from).
// implement cvar reset see L:\dark_dev\dhewm\neo\framework\CVarSystem.cpp for a good example
// convert L:\dark_dev\dhewm\neo\idlib\CmdArgs.cpp to C3 to use it as a base for our command arguments system
// bring L:\dark_dev\dhewm\neo\framework\CmdSystem.h to C3 to use it as a base for our command system


module engine::sys::cvar;

// #region import modules
import std::io;
import std::collections::list;
import engine::misc;
//import engine::sys::cmd; still not fully implemented
import engine::logging::log;
import thirdparty::raylib5::rl;
import game::main;
import game::files::ini;
// #endregion

// #region defines
alias CvarList = List{CVar*};
// #endregion

// region constantes
//const int PRINT_CVAR_SETTING = 1;
// end_region

// cvar flags (some are unnused...)
constdef CvFlag : inline uint
{
	BOOL		= @bit(0),	// variable is a boolean
	INT			= @bit(1),	// variable is an integer
	FLOAT		= @bit(2),	// variable is a float
	STRING		= @bit(3),	// system variable
	RENDERER	= @bit(4),	// renderer variable
	SOUND		= @bit(5),	// sound variable
	GUI			= @bit(6),	// gui variable
	GAME		= @bit(7),	// game variable
	TOOL		= @bit(8),	// tool variable
	SYSTEM		= @bit(9),	// system variable
	SERVERINFO	= @bit(10),	// sent from servers, available to menu
	NETWORKSYNC	= @bit(11),	// cvar is synced from the server to clients
	STATIC		= @bit(12),	// statically declared, not user created
	CHEAT		= @bit(13),	// variable is considered a cheat
	NOCHEAT		= @bit(14),	// variable is not considered a cheat
	INIT		= @bit(15),	// can only be set from the command-line
	ROM			= @bit(16),	// display only, cannot be set by user at all
	ARCHIVE		= @bit(17),	// set to cause it to be saved to a config file
	MODIFIED	= @bit(18)	// set when the variable is modified
}

struct CVar
{
    String  name;
    uint    flags;
    String  value;
    //String   resetvalue; // resetting will change to this value (not used yet)
    String  description;
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
    // This pointer was a idea I saw on Star Trek Elite Force 1 SDK game code
    // they used a linked list of cvars, to loop through them.
    // But I think it makes the cvar declaration and looping through more involved as well,
    // so for the time being, I decided for a global dynamic array instead.
    // But this is still a cool idea to save for the future if needed....
    //CVar* next;
}

CvarList cvars;

macro @register(#cvar) 
{
    cvars.push(#cvar);
$if $feature(_DEBUG):
    io::printfn("[INFO] Registered CVar %s (%s).", #cvar.name, #cvar.description);
$endif
}

/*
<*
	@param [&inout] cfg : "config file data to save the cvars in"
	@require cfg.path.len > 0
*>
fn bool? saveCvarsToIniFile(ConfigFile* cfg) 
{
	String filepath = cfg.path;

	File? file_data = (File)file::open(filepath, "r+");
	if(catch excuse = file_data) {
		log::warning(FILE, "Failed to open file: %s to save cvars data with excuse: %s", filepath, excuse);
		return excuse~;
	}
	defer file_data.close()!!;

	foreach(it : cvars) 
	{
		String section_type;
		switch
		{
			case it.flags & CvFlag.RENDERER:   section_type = "Renderer";
			case it.flags & CvFlag.SYSTEM:     section_type = "System";
			case it.flags & CvFlag.SOUND:      section_type = "Sound";
			case it.flags & CvFlag.TOOL:       section_type = "Tool";
			case it.flags & CvFlag.GAME:       section_type = "Game";
			case it.flags & CvFlag.GUI:        section_type = "Gui";
			case it.flags & CvFlag.SERVERINFO: section_type = "Server";
			default: section_type = "Undefined";
		}
		if(cfg.hasSection(section_type)) {
			cfg.addToSection(cfg.getSection(section_type), mem::tnew(IniCMD, {
				switch
				{
					case it.flags & CvFlag.BOOL:   .type = CvFlag.BOOL,
					case it.flags & CvFlag.INT:    .type = CvFlag.INT,
					case it.flags & CvFlag.FLOAT:  .type = CvFlag.FLOAT,
					case it.flags & CvFlag.STRING: .type = CvFlag.STRING,
					default: unreachable(),
				}
				.first  = it.name,
				.second = it.value
			}));
		}
		// write cvar 
		file.write(Token.NEWLINE)!;
		file.write(Token.SECTION_START)!;
			file.write(section.name)!;
			if(section.isLinked()) {
				file.write(Token.DOT)!;
				file.write(section.next.name)!;
			}
		file.write(Token.SECTION_END+++Token.NEWLINE)!;
	}
}*/

<*
	@ensure return != 0
*>
fn int CVar.getBasicType(&self) @MyInline
{
    switch
    {
        case (bool)(self.flags & CvFlag.BOOL):   return 1;
        case (bool)(self.flags & CvFlag.INT):    return 2;	
        case (bool)(self.flags & CvFlag.FLOAT):  return 3;
        case (bool)(self.flags & CvFlag.STRING): return 4;
        default: return 0;
    }
}

fn void printflags(int flags) @inline @local
{
    int count;
    foreach(flag : CvFlag.values) {
		if(flags & flag) {
			count++;
		}
	}

	foreach(i, flag : CvFlag.values) {
		if(flags & flag) {
			io::printf("%s", CvFlag.names[i]);
			if(count) {
				io::printf(" %c ", '|');
                count -= 1;
			}
		}
	}
}

fn void printCvars() @inline
{
    if(cvars.len() == 0) {
        io::printfn("No cvars registered.");
        return;
    }

    io::printfn("\n============== CONSOLE/FLAGS VARS =====================");
    foreach(cv: cvars) {
        io::printf("%s :", cv.name); printflags(cv.flags);
        io::printfn("\t - desc: %s", cv.description);
        io::printfn("\t - default: %s", (!(cv.flags & CvFlag.BOOL)) ? cv.value : misc::bool2str(cv.value == "1"));
        //io::printfn("--------------------------------------------------------");
    }
    io::printfn("Total cvars: %d", cvars.len());
    io::printfn("============== CONSOLE/FLAGS VARS END =====================\n");
}

/*
    How to use the macros:
    1. Declare the cvar in your code at the top of the file, like this:
    CVar someCvar;

    2. Use the macro to initialize the cvar, like this inside a function:
    OnGameStart() {
        someCvar.init("someCvar", "0", CVAR_SYSTEM | CVAR_NOCHEAT, "some cvar description");
    }

*/
/*
// Always use one of the following initializers.
macro CVar.init(&self, String name, String value, int flags, String description, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.flags  = CvFlag.NONE;
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
macro CVar.initMinMax( String name, String value, int flags, const String description, float valueMin, float valueMax, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.flags  = CvFlag.NONE;
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
macro CVar.initWithStrings( String name, String value, int flags, String description, String[] valueStrings, ArgCompletionCallback valueCompletion = null ) {
    self.name  = name;
    self.flags  = CvFlag.NONE;
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

// fn void register_cvars(CVar*[] cvars) {
    // foreach(cv: cvars) {
        // @register(*cv);
    // }
// }

// // compile time definition of a cvar
// macro void @make_cvar($name, $_type, $value, $disc)
// {
    // CVar cv = { $name, $_type, $value, $disc };
    // cvars.push(&cv);
// }

fn bool CVar.getBool(&self, bool default_value = false) @inline @nodiscard
{
    if(!(self.flags & CvFlag.BOOL)) {
        log::warning(FILE, "Trying to get boolean value from CVar: %s but it is not a bool: %s->%d", self.name, $$FUNC, $$LINE);
        return default_value;
    }
    
    if(self.value == "true" || self.value == "1") { 
        return true; 
    } else if(self.value == "false" || self.value == "0") { 
        return false;
    }
    
    // from here we expect a valid char value
    char? value = self.value.to_uchar();
    if(catch excuse = value) {
        log::error(FILE, "CVar: %s fault '%s' :: %s->%d", self.name, excuse, $$FUNC, $$LINE);
        return default_value;
    }
    
    return (value > 0) ? true : false;
}

fn int CVar.getInt(&self, int default_value = 0) @inline @nodiscard
{
    if(try int result = self.value.to_int()) {
        return result;
    } else {
        log::warning(FILE, "unable to get integer value for '%s' :: %s->%d", self.name, $$FUNC, $$LINE);
        return default_value;
    }
}

fn float CVar.getfloat(&self, float default_value = 0.0f) @inline @nodiscard
{
    if(try float result = self.value.to_float()) {
        return result;
    } else {
        log::warning(FILE, "unable to get float value for '%s' :: %s->%d", self.name, $$FUNC, $$LINE);
        return default_value;
    }
}

fn String CVar.getString(&self, String default_value = "") @inline @nodiscard 
{
    if(!(self.flags & CvFlag.STRING)) {
        log::warning(FILE, "CVar: %s was not defined as a string: %s->%d", self.name, $$FUNC, $$LINE);
        return default_value;
    }
    
    // doesn't care about empty strings
    return self.value;
}

fn CVar* CVar.set(&self, String value) @inline 
{
    self.value = value.tcopy();
$if $feature(_DEBUG):
    if(self.flags & CvFlag.BOOL) {
        log::info(CONSOLE, "CVar %s was set to %s.", self.name, (self.value == "1" || self.value == "true") ? "true" : "false");
    } else {
        log::info(CONSOLE, "CVar %s was set to value %s.", self.name, value);
    }
$endif
    return self;
}

fn CVar* CVar.setBool(&self, bool value) @inline
{
$if $feature(_DEBUG):
    if(!(self.flags & CvFlag.BOOL)) {
        log::fatal(FILE, "Trying to set non bool CVar %s to bool value %s.", self.name, (self.value) ? "true" : "false");
    }
$endif
    (value == true) ? self.set("true") : self.set("false");
    return self;
}

<*
    Archive console variables into the config file
    @require game::gpGame.settings_data.isValid()
*>
fn void CVar.archive(&self)
{
	// don't archive console variables that are not marked to be so.
	if(!(self.flags & CvFlag.ARCHIVE)) return;

	IniSection* section;
	ConfigFile* settings_data = &game::gpGame.settings_data;

    String sec_name = "Cvars";
    switch {
        case (bool)(self.flags & CvFlag.SYSTEM):   sec_name = "System";
        case (bool)(self.flags & CvFlag.RENDERER): sec_name = "Renderer";
        case (bool)(self.flags & CvFlag.SOUND):    sec_name = "Sound";
        case (bool)(self.flags & CvFlag.GUI):      sec_name = "Gui";
        case (bool)(self.flags & CvFlag.GAME):     sec_name = "Game";
        case (bool)(self.flags & CvFlag.TOOL):     sec_name = "Tool";
        default: break;
    }
	if(settings_data.hasSection(sec_name)) {
		section = settings_data.getSection(sec_name);
	} else {
		section = settings_data.createSection(sec_name);
	}
	assert(section != null);

    if(section.hasCmd(self.name)) {
        // just update cmd value;
        settings_data.setValue(self.name, self.value);
    } else {
        settings_data.addToSection(section, mem::new(IniCMD, {
            .type = self.getBasicType(),
            .cmd  = {self.name, self.value}
        }));
    }
}

fn CVar* findCvar( String name ) @local @inline 
{
    foreach( cvar : cvars ) {
        if ( cvar.name == name ) {
            return cvar;
        }
    }
	return null;
}


fn String getCVarString( String name ) @inline {
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getString();
    }
    return "";
}

fn bool getCVarBool( String name ) @inline {
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getBool();
    }
    return false;
}

fn int getCVarInteger( String name ) @inline {
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getInt();
    }
    return 0;
}

fn float getCVarFloat( String name ) @inline {
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getfloat();
    }
    return 0.0f;
}


fn bool command( String[] args ) {
	CVar *internal = findCvar( args[0]);

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


/*fn void CVar.init(&self, String name, CvarType _type, String value, String description) {
    self.name  = name;
    self.flags  = _type;
    self.value = value;
    self.description = description;
    @register(self);
}*/
