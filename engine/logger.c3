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

module engine::logging::lgr;

// region modules
import std::io;
import libc;
import game::main;
import thirdparty::raylib5::rl;
import game::low_level::cvar;
// end_region

// region Cvars
Cvar g_log @public = { "g_log", CvarType.BOOLEAN, "true", "turns on loggin for debuggin."};

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

enum Where {
    FILE,
    CONSOLE
}

/*
// Trace log level      *copy pasta* from raylib55.c3i just for doc reasons
// NOTE: Organized by priority level
enum TraceLogLevel : int
{
    ALL,            // Display all logs (0)
    TRACE,          // Trace logging, intended for internal use only
    DEBUG,          // Debug logging, used for internal debugging, it should be disabled on release builds
    INFO,           // Info logging, used for program execution info
    WARNING,        // Warning logging, used on recoverable failures
    ERROR,          // Error logging, used on unrecoverable failures
    FATAL,          // Fatal logging, used to abort program: exit(EXIT_FAILURE)
    NONE            // Disable logging
}
*/
// region local globals
	rl::TraceLogLevel glevel @local;    // default is ALL; Controls how deep should the logging be done
	int glogcount            @local;	// Is this really needed... to know how many log prints we did if to many throw a warning
	ZString gpath            @local;	// Full path to the file if needed
    File gfile               @local;    // the file handle itself
// end_region

fn void setLogLevel(TraceLogLevel level) @inline 
{
	glevel = level;
}

fn void initGlobalLoggingDir() 
{
    gpath = rl::getWorkingDirectory().str_view().tconcat("\\debug.log").zstr_tcopy();
}

fn void closeLogFile() 
{
    if(catch excuse = gfile.close()) {
		warning(Where.CONSOLE, "failed to close log file!!!\n	- %s", excuse);
		unreachable("failed to close log file!!!");
	} else {
		info(Where.CONSOLE, "log file closed successfully!!!");
	}
}

fn String getfilepath() @inline => gpath.str_view();


fn void log(Where where, TraceLogLevel level, String fmt, args...) @public {
    switch (where) {
        case FILE:
            logTofile(level, fmt, ...args);
        case CONSOLE:
            logToConsole(level, fmt, ...args);
    }
}

fn void info(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(TraceLogLevel.INFO, fmt, ...args);
        case CONSOLE:
            logToConsole(TraceLogLevel.INFO, fmt, ...args);
    }
}

fn void warning(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(TraceLogLevel.WARNING, fmt, ...args);
        case CONSOLE:
            logToConsole(TraceLogLevel.WARNING, fmt, ...args);
    }
}

fn void error(Where where, String fmt, args...) @public
{
	switch (where) {
        case FILE:
            logTofile(TraceLogLevel.ERROR, fmt, ...args);
        case CONSOLE:
            logToConsole(TraceLogLevel.ERROR, fmt, ...args);
    }
}

fn void fatal(Where where, String fmt, args...) @public {
	switch (where) {
        case FILE:
            logTofile(TraceLogLevel.FATAL, fmt, ...args);
        case CONSOLE:
            logToConsole(TraceLogLevel.FATAL, fmt, ...args);
    }
    unreachable();
}

fn void logTofile(TraceLogLevel level, String fmt, args...) @local
{
	bool not_should_log = !g_log.getBool() || fmt.len == 0;
	if(not_should_log) return;
    
$if $feature(_DEBUG):
	bool should_log = level.ordinal >= glevel.ordinal;
	if(should_log == false) return;
	
	if(glogcount >= 0xFFFF) {
		warning(Where.CONSOLE, "Log messages have reached or surpassed 65K!!!");
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
			warning(Where.CONSOLE, "Failed to reopen file: %s to append:\n	- %s\n  excuse: %s", gpath, str, excuse);
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
		case TraceLogLevel.INFO:
			nextcase default;
		case TraceLogLevel.WARNING:
			level_str = "[WARNING]";
		case TraceLogLevel.ERROR:
			level_str = "[ERROR]";
		case TraceLogLevel.FATAL:
			level_str = "[FATAL]";
		default:
			level_str = "[INFO]";
	}
	
	//libc::fprintf(file, "%s: %s\n", level_str.tcopy(), str.zstr_view());
	//libc::fflush(file);
    gfile.write(string::tformat("%s: %s\n", level_str, str))!!;
    gfile.flush()!!;
	glogcount++;
$endif
}

fn void logToConsole(TraceLogLevel level, String fmt, args...) @local {
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	rl::traceLog(level, str.zstr_view());
}

/*

// color escape string for ** console logging only **
const String ANSI_COLOR_RED     = "\x1b[31m";
const String ANSI_COLOR_GREEN   = "\x1b[32m";
const String ANSI_COLOR_YELLOW  = "\x1b[33m";
const String ANSI_COLOR_BLUE    = "\x1b[34m";
const String ANSI_COLOR_MAGENTA = "\x1b[35m";
const String ANSI_COLOR_CYAN    = "\x1b[36m";
const String ANSI_COLOR_RESET   = "\x1b[0m";

//////////////////////// HM ////////////////////////////////////

/**
 * @param [in] fmt `The formatting string`
 **/
macro void hmLog(String fmt, ...) @public @builtin {
$if $defined(DEBUG):
	DString str = dstring::temp_with_capacity(fmt.len + $vacount * 8);
	str.appendf(fmt, $vasplat);
	io::printfn("%sINFO: %s%s", ANSI_COLOR_CYAN, ANSI_COLOR_RESET, str.str_view());
$endif
}

/**
 * @param [in] fmt `The formatting string`
 **/
macro hmLogWarning(String fmt, ...) @public @builtin {
$if $defined(DEBUG):
	DString str = dstring::temp_with_capacity(fmt.len + $vacount * 8);
	str.appendf(fmt, $vasplat);
	io::printfn("%sWARNING: %s%s", ANSI_COLOR_YELLOW, ANSI_COLOR_RESET, str.str_view());
$endif
}
/**
 * @param [in] fmt `The formatting string`
 **/
macro hmLogError(String fmt, ...) @public @builtin {
$if $defined(DEBUG):
	DString str = dstring::temp_with_capacity(fmt.len + $vacount * 8);
	str.appendf(fmt, $vasplat);
	io::printfn("%sERROR: %s%s", ANSI_COLOR_RED, ANSI_COLOR_RESET, str.str_view());
$endif
}
