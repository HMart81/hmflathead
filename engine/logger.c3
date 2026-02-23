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

module engine::logging::log;

// region modules
import std::io, std::time, std::math;
import libc;
import game::main;
import thirdparty::raylib5::rl;
import engine::sys::cvar;
// end_region

// region Cvars
CVar g_log @public = { "g_log", CvarType.BOOL, "true", "turns on loggin for debuggin."};

fn void register_cvars() {
	cvar::@register(&g_log);
}
// end_region Cvars

// region constants
const ZString WRITE_NEW        = "w";
const ZString WRITE_NEW_BINARY = "wb";
const ZString APPEND_TO_END    = "a";
// end_region

// region defines
// end_region

enum Where
{
    FILE,
    CONSOLE
}
const Where FILE @export    = Where.FILE;
const Where CONSOLE @export = Where.CONSOLE;

/*
// Trace log level, taken from raylib55
// NOTE: Organized by priority level
ALL     = Display all logs (0)
TRACE   = Trace logging, intended for internal use only
DEBUG   = Debug logging, used for internal debugging, it should be disabled on release builds
INFO    = Info logging, used for program execution info
WARNING = Warning logging, used on recoverable failures
ERROR   = Error logging, used on unrecoverable failures
FATAL   = Fatal logging, used to abort program: exit(EXIT_FAILURE)
NONE    = Disable logging
*/

// region local globals
	int glevel    @local;    // default is ALL; Controls how deep should the logging be done
	int glogcount @local;	// Is this really needed... to know how many log prints we did if to many throw a warning
	ZString gpath @local;	// Full path to the file if needed
    File gfile    @local;    // the file handle itself
// end_region

fn void setLogLevel(RLTraceLogLevel level) @inline 
{
	glevel = level;
}

// NOTE(HM) controls file and Console logging 
// plus sets where the log file is saved as well.
fn void initGlobalLoggingDir() @inline @local
{
    gpath = rl::getWorkingDirectory().str_view().tconcat("\\debug.log").zstr_tcopy();
}

fn void init(RLTraceLogLevel level) @inline
{
	initGlobalLoggingDir();
	setLogLevel(level);
}

fn void closeLogFile() 
{
    if(catch excuse = gfile.close()) {
		warning(CONSOLE, "failed to close log file!!!\n	- %s", excuse);
		unreachable("failed to close log file!!!");
	} else {
		info(CONSOLE, "log file closed successfully!!!");
	}
}

fn String getfilepath() @inline => gpath.str_view();


/*fn void log(Where where, RLTraceLogLevel level, String fmt, args...) @public {
    switch (where) {
        case FILE:
            logTofile(level, fmt, ...args);
        case CONSOLE:
            logToConsole(level, fmt, ...args);
    }
}*/

fn void info(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(RLTraceLogLevel.INFO, fmt, ...args);
        case CONSOLE:
            logToConsole(RLTraceLogLevel.INFO, fmt, ...args);
    }
}

fn void warning(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(RLTraceLogLevel.WARNING, fmt, ...args);
        case CONSOLE:
            logToConsole(RLTraceLogLevel.WARNING, fmt, ...args);
    }
}

fn void error(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(RLTraceLogLevel.ERROR, fmt, ...args);
        case CONSOLE:
            logToConsole(RLTraceLogLevel.ERROR, fmt, ...args);
    }
}

fn void fatal(Where where, String fmt, args...) @public {
	switch (where) {
        case FILE:
            logTofile(RLTraceLogLevel.FATAL, fmt, ...args);
        case CONSOLE:
            logToConsole(RLTraceLogLevel.FATAL, fmt, ...args);
    }
    unreachable();
}

fn void logTofile(RLTraceLogLevel level, String fmt, args...) @local @format(1)
{
	// if logging disabled do nothing
	if(g_log.getBool() == false) return; // turn off logging
	// if nothing to write also do nothing
	if(fmt.len == 0) return;
    
$if $feature(_DEBUG):
	bool should_log = (level >= glevel);
	if(should_log)
	{
		if(glogcount >= 0xFFFF) {
			warning(CONSOLE, "Log messages have reached or surpassed 65K!!!");
		}
		
		DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
		str.appendf(fmt, ...args);
		
		assert(gpath.len() != 0);
		//CFile* file = libc::fopen(gpath, WRITE_NEW);
		if(gfile.file == null) {
			gfile = file::open(gpath.str_view(), WRITE_NEW.str_view())!!;
		}
		defer {
			//libc::fclose(file);
			//gfile.close()!!;
		}
		
		if(glogcount >= 1) {
			// close the old file handle
			//libc::fclose(file);
			if(catch excuse = gfile.reopen(gpath.str_view(), APPEND_TO_END.str_view())) {
				warning(CONSOLE, "Failed to reopen file: %s to append:\n	- %s\n  excuse: %s", gpath, str, excuse);
				return;
			}
			// get a new file handle
			//file = libc::fopen(gpath.str_view(), APPEND_TO_END);
			/*if(!file.file) {
				warning(Where.CONSOLE, "Failed to open file: %s to append:\n	- %s", gpath, str);
				return;
			}*/
		}
		
		assert(gfile.file != null);
		
		String level_str;
		
		switch(level)
		{
			case RLTraceLogLevel.INFO:
				nextcase default;
			case RLTraceLogLevel.WARNING:
				level_str = "[WARNING]";
			case RLTraceLogLevel.ERROR:
				level_str = "[ERROR]";
			case RLTraceLogLevel.FATAL:
				level_str = "[FATAL]";
			default:
				level_str = "[INFO]";
		}
		
		DateTime date = datetime::now();
		String date_str = string::tformat("%s:%s.%d ", date.min, date.sec, (date.usec / 1000));
		gfile.write(string::tformat("%s %s: %s\n",date_str, level_str, str))!!;
		gfile.flush()!!;
		glogcount++;
	}
$endif
}

fn void logToConsole(RLTraceLogLevel level, String fmt, args...) @format(1) @local 
{
	// if logging disabled do nothing
	if(g_log.getBool() == false) return; // turn off logging
	// if nothing to write also do nothing
	if(fmt.len == 0) return;

	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);

	String color;
	String level_str;

	switch(level)
	{
		case RLTraceLogLevel.WARNING:
			color = ANSI_COLOR_BR_YELLOW;
			level_str = "[WARNING]";
		case RLTraceLogLevel.ERROR:
			color = ANSI_COLOR_RED;
			level_str = "[ERROR]";
		case RLTraceLogLevel.FATAL:
			color = ANSI_COLOR_BR_RED;
			level_str = "[FATAL]";
		case RLTraceLogLevel.INFO:
		default:
			color = ANSI_COLOR_YELLOW;
			level_str = "[INFO]";
	}
	String message = string::tformat("%s%s%s", color, str, ANSI_COLOR_RESET);
	//rl::traceLog(level, message.zstr_tcopy());
	io::printfn(level_str.tconcat(" ").tconcat(message));
}


// Note(HM): I later discovered C3, already add support 
// for ANSI color escape sequences in a enum defined inside 
// module std::core::string::ansi;
// so use that instead in the future, if needed.
//
// color escape string for ** console logging only **

const String ANSI_COLOR_RED        @local = "\x1b[31m";
const String ANSI_COLOR_BR_RED     @local = "\x1b[91m";
const String ANSI_COLOR_GREEN      @local = "\x1b[32m";
const String ANSI_COLOR_YELLOW     @local = "\x1b[33m";
const String ANSI_COLOR_BR_YELLOW  @local = "\x1b[93m";
const String ANSI_COLOR_BLUE       @local = "\x1b[34m";
const String ANSI_COLOR_MAGENTA    @local = "\x1b[35m";
const String ANSI_COLOR_BR_MAGENTA @local = "\x1b[95m";
const String ANSI_COLOR_CYAN       @local = "\x1b[36m";
const String ANSI_COLOR_RESET      @local = "\x1b[0m";
const String ANSI_COLOR_WHITE      @local = "\x1b[107m";

/*
const String ANSI_COLOR_RED     = "[31m";
const String ANSI_COLOR_GREEN   = "[32m";
const String ANSI_COLOR_YELLOW  = "[33m";
const String ANSI_COLOR_BLUE    = "[34m";
const String ANSI_COLOR_MAGENTA = "[35m";
const String ANSI_COLOR_CYAN    = "[36m";
const String ANSI_COLOR_RESET   = "[0m";
const String ANSI_COLOR_WHITE   = "[97m";
/*