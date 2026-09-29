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
import std::os::win32;
import engine::misc;
//import engine::sys::cmd; still not fully implemented
import engine::logging::log;
import engine::platform::win32;
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

// region cvars
CVar cmd_listCVars @public = { "cmd_listCVars", CvFlag.BOOL | CvFlag.CHEAT | CvFlag.SYSTEM, "0", "print all cvars to the console." };

fn void register_cvars() @public 
{
    @register(&cmd_listCVars);
}

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
	SERVERINFO	= @bit(10),	// sent from servers, available to menu @unused
	NETWORKSYNC	= @bit(11),	// cvar is synced from the server to clients @unused
	CHEAT		= @bit(12),	// variable is considered a cheat
	INIT		= @bit(13),	// can only be set from the command-line
	ROM			= @bit(13),	// display only, cannot be set by user at all
	ARCHIVE		= @bit(14),	// set to cause it to be saved to a config file
	MODIFIED	= @bit(15)	// set when the variable is modified
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

// global cvar list where all cvars are saved
CvarList cvars;

macro @register(#cvar) 
{
    cvars.push(#cvar);
$if $feature(_DEBUG):
    io::printfn("[INFO] Registered CVar %s (%s).", #cvar.name, #cvar.description);
$endif
}

<*
	@param [&inout] cfg : "config memory data to save the cvars into"
*>
fn void archive_cvars(ConfigFile* cfg)
{
	if(cvars.len() > 0)
	{
		foreach(cvar : cvars)
		{
			archive(cvar, cfg);
		}
	}
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
	@ensure return > 0 && return <= 4
*>
fn int CVar.getBasicType(&self) @inline
{
    switch
    {
        case (bool)(self.flags & CvFlag.BOOL):   return 1;
        case (bool)(self.flags & CvFlag.INT):    return 2;	
        case (bool)(self.flags & CvFlag.FLOAT):  return 3;
        case (bool)(self.flags & CvFlag.STRING): return 4;
        default: 
			unreachable("Cvar '%s' has no valid type!", self.name);
    }
}

fn void print_used_flags(uint flags) @inline @local
{
    int count;
    foreach(flag : CvFlag::values)
	{
		if(flags & flag)
		{
			count++;
		}
	}

	if(count) 
	{
		foreach(i, flag : CvFlag::values)
		{
			if(flags & flag)
			{
				io::printf("%s", CvFlag::names[i]);
				if(count)
				{
					io::printf(" %c ", '|');
					count -= 1;
				}
			}
		}
	}
}

fn void printCvars() @inline
{
	if(cvars.len() == 0)
	{
		io::printfn("No cvars registered.");
		return;
	}

	io::printfn("\n============== CONSOLE/FLAGS VARS =====================");
	foreach(cv: cvars)
	{
		io::printf("%s :", cv.name); print_used_flags(cv.flags);
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
    char? value = self.value.to_char();
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

<*
	test if is a cvar the user cannot modify a "ROM" cvar, 
	rom like in memory you can only read from and not write to.
	@param [&in] cvar : "console var being looked at"
*>
fn bool isRomCvar(CVar* cvar, bool warn = false) @local
{
	if((bool)(cvar.flags & CvFlag.ROM) == true)
	{
        if(warn) log::warning(FILE, "Trying to modify CVar %s but is set to ROM (not modifiable).", cvar.name);
		return true;
    }
	return false;
}

fn CVar* CVar.set(&self, String value) @inline 
{
	if(isRomCvar(self)) return self;

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

<*
	@param [&inout] cv : "the cvar to update"
*>
fn void set(CVar* cv, Type1 value) <Type1>
{
	switch(Type1)
	{
		case int:
		case bool:
		case float:
		case String:
    		cv.set(string::tformat("%s", value));
		default:
		{
			String error = string::tformat("cannot set cvar '%s' value because type '%s' is not supported.", cv.name, Type1::name);
			unreachable(error);
		}
	}
}

fn CVar* CVar.setBool(&self, bool value) @inline
{
	if(isRomCvar(self)) return self;

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
	@param [&in] cv : "cvar to archive"
	@param [&inout] cfg : "config file to archive to"
*>
fn void archive(CVar* cv, ConfigFile* cfg) @local
{
	// don't archive console variables that the user shouldn't modify.
	if(isRomCvar(cv)) return;

	// don't archive console variables that are not marked to be so.
	if((bool)(cv.flags & CvFlag.ARCHIVE))
	{
		IniSection* section @noinit;
		ConfigFile* settings = cfg;

		String sec_name;
		switch {
			case (bool)(cv.flags & CvFlag.SYSTEM):   sec_name = "system";
			case (bool)(cv.flags & CvFlag.RENDERER): sec_name = "video";
			case (bool)(cv.flags & CvFlag.SOUND):    sec_name = "sound";
			case (bool)(cv.flags & CvFlag.GUI):      sec_name = "gui";
			case (bool)(cv.flags & CvFlag.GAME):     sec_name = "game";
			case (bool)(cv.flags & CvFlag.TOOL):     sec_name = "tool";
			default: {
				log::warning(FILE, "CVar.archive: Failed to set ini section name, unkown type flag");
				sec_name = "misc";
			}
		}

		section = settings.hasSection(sec_name);
		if(section == null)
		{
			section = settings.createSection(sec_name);
		} 

		if(section == null)
		{
			log::warning(FILE, "CVar.archive: Failed to set ini section '%s'.", sec_name);
			return;
		}

		if(section.hasCmd(cv.name))
		{
			// just update the existing cmd value;
			ini::setSectionValue(section, cv.name, cv.value, settings);
		} 
		else // create a new cmd for the section
		{
			ini::addCmdToSection(section, mem::new(IniCMD, {
				.type = cv.getBasicType(),
				.cmd  = {cv.name, cv.value}
			}), settings);
		}
	}
}

fn void CVar.put_in_registry(&self) @if(env::WIN32)
{
	if(isRomCvar(self)) return;

	// don't archive console variables that are not marked to be so.
	if((bool)(self.flags & CvFlag.ARCHIVE) == true)
	{
		Win32_HKEY? currentUserKey = win32::regOpenCurrentUser(win32::KEY_WRITE | win32::KEY_WOW64_64KEY);
		if(catch excuse = currentUserKey)
		{
			log::warning(FILE, "Unable to open current user key from registry, see if you have required elevated permissions. : excuse > %s", excuse);
		}
		else
		{
			defer win32::regCloseKey(currentUserKey);

			String sub_key = "Software";
			Win32_HKEY? root = win32::regOpenKey(currentUserKey, sub_key, win32::KEY_WRITE);
			if( catch excuse2 = root)
			{
				log::warning(FILE, "Failed to open key \"%s\" inside registry 'HKEY_CURRENT_USER' with: excuse > %s", sub_key, excuse2);
			} 
			else
			{
				defer win32::regCloseKey(root);

				String reg_key   = "HMartSoftware\\unnnamed\\settings\\";
				Win32_DWORD sam  = win32::KEY_WRITE | win32::KEY_WOW64_64KEY;
				Win32_HKEY folder_key;

				bool? rs = win32::regCreateKey(root, reg_key, 0, sam, &folder_key);
				if(catch excuse3 = rs)
				{
					log::warning(FILE, "Failed to create key \"%s\" inside registry 'HKEY_CURRENT_USER/Software' key with: excuse > %s", reg_key, excuse3);
				} 
				else
				{
					defer win32::regCloseKey(folder_key);

					typeid type = Win32_DWORD;
					bool sucess = true;
					switch {
						case (bool)(self.flags & CvFlag.BOOL):
						case (bool)(self.flags & CvFlag.INT):
							int value = self.value.to_int()!!;
							if(win32::regSetValue(folder_key, self.name, any_make(&value, String)) != win32::ERROR_SUCCESS)
							{
								sucess = false;
							}
						case (bool)(self.flags & CvFlag.FLOAT):
							float value = self.value.to_float()!!;
							if(win32::regSetValue(folder_key, self.name, any_make(& value, String)) != win32::ERROR_SUCCESS)
							{
								sucess = false;
							}
						case (bool)(self.flags & CvFlag.STRING):
							if(win32::regSetValue(folder_key, self.name, any_make(&self.value, String)) != win32::ERROR_SUCCESS)
							{
								sucess = false;
							}
						default: unreachable();
					}

					if(sucess == false)
					{
						log::warning(FILE, "failed to write %s to registry.", self.name);
					}
				}
			}
		}
	}
}

fn CVar* findCvar( String name ) @local @inline
{
    foreach( cvar : cvars )
	{
        if ( cvar.name == name ) {
            return cvar;
        }
    }
	return null;
}


fn String get_string( String name ) @inline
{
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getString();
    }
    return "";
}

fn bool get_bool( String name ) @inline
{
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getBool();
    }
    return false;
}

fn int get_int( String name ) @inline
{
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getInt();
    }
    return 0;
}

fn float get_float( String name ) @inline
{
    CVar* internal = findCvar( name );
    if ( internal ) {
        return internal.getfloat();
    }
    return 0.0f;
}


fn bool command( String[] args )
{
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
