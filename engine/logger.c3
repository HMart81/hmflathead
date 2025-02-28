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

/**
	A bunch of code for Console and file logging.
**/
module game::logger::lgr @private;

// region C3 modules
import std::io;
import libc;
// end_region C3 modules

// region Custom modules
import game::main;
import raylib5::rl;
import game::low_level::cvar;
// end

// region Cvars
Cvar g_log @public = { "g_log", CvarType.INT, "0", "loggin for debuggin, int value from 0 to 4, 0 = off, larger values prints more stuff."};

fn void register_modulo_cvars() @local {
	cvar::@register(&g_log);
}
// end_region Cvars

//
const ZString WRITE_NEW     = "w";
const ZString APPEND_TO_END = "a";

struct FileLogger {
	libc::CFile* file;         // File to log to
	rl::TraceLogLevel level;    // Controls how deep should the logging be done
	int logcount;	           // Is this really needed... to know how many log prints he did if to many throw a warning
	ZString path;	           // Full path to the file if needed 
}

// NOTE(HM) 
// Made this into a singleton 
// (a global unique object that stays alive while the game is running) 
// did this because I need to log to a file before the game stuff is initialized.
FileLogger local_logger @local; // local engine logger
FileLogger* gpfLog @public = &local_logger;

fn void FileLogger.setLogLevel(&self, TraceLogLevel level) @inline {
	self.level = level;
}

fn void FileLogger.init(&self) {
	self.path = rl::getWorkingDirectory().str_view().concat("\\debug.log").zstr_tcopy();
	if(self.path.len()) {
		self.file = libc::fopen(self.path, WRITE_NEW);
		if(!self.file) {
			raylibWarning("Unable to open file: %s to write to.", self.path);
		}
	} else {
		raylibWarning("File path giving to log system is invalid.\n  Failed to initialize file logging!");
	}
	
	register_modulo_cvars();
}

fn void FileLogger.deinit(&self) {
	self.path = "";
	if(self.file) libc::fclose(self.file);
}

fn bool FileLogger.fileExist(&self) => self.file != null;


<*
* @param [in] fmt `The formatting string`
* @require self.path != "" && self.file != null
*>
fn void FileLogger.log(&self, TraceLogLevel level, String fmt, args...) 
{
	int log_value_from_cvar = g_log.getInt();
	if(log_value_from_cvar == 0) return;
	if(self.fileExist() == false) return;
	
$if $feature(_DEBUG):
	if(fmt.len == 0) return;
	
	bool should_log = level.ordinal >= self.level.ordinal;
	if( should_log == false || self.level.ordinal < log_value_from_cvar) return;
	
	if(self.logcount >= 0xFFFF) {
		self.log(TraceLogLevel.WARNING, "Log messages have reached or surpassed 65K!!!");
	}
	
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	
	if(self.logcount >= 1) {
		// close the old file handle
		libc::fclose(self.file);
		// get a new file handle
		self.file = libc::fopen(self.path, APPEND_TO_END);
		if(!self.file) {
			raylibWarning("Failed to open file: %s to write to it.\nlogging following warning to console instead:\n	- %s", self.path, str);
			return;
		}
	}
	
	assert(self.file != null);
	
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
	
	libc::fprintf(self.file, "%s: %s\n", level_str.zstr_copy(), str.zstr_view());
	libc::fflush(self.file);
	self.logcount++;
$endif
}

fn void FileLogger.info(&self, String fmt, args...) @inline
{
	self.log(TraceLogLevel.INFO, fmt, ...args);
}

fn void FileLogger.warning(&self, String fmt, args...) @inline
{
	self.log(TraceLogLevel.WARNING, fmt, ...args);
}

fn void FileLogger.error(&self, String fmt, args...) @inline
{
	self.log(TraceLogLevel.ERROR, fmt, ...args);
}

/////////////////////////// RAYLIB based Console logging ////////////////////////////////

fn void raylibLog(String fmt, args...) @inline @public {
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	rl::traceLog(TraceLogLevel.INFO, str.zstr_view());
}

fn void raylibWarning(String fmt, args...) @inline @public {
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	rl::traceLog(TraceLogLevel.WARNING, str.zstr_view());
}

fn void raylibError(String fmt, args...) @inline @public {
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	rl::traceLog(TraceLogLevel.ERROR, str.zstr_view());
}

fn void raylibFatal(String fmt, args...) @inline @public {
	DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
	rl::traceLog(TraceLogLevel.FATAL, str.zstr_view());
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
