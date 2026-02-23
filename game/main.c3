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

// NOTE(HM) This is the main game module, is where the game initializes almost all its systems and where the entry point is
module main @private;

// #region imports
import libc;
import game @public;
import std::io, std::thread;
import std::time;
import engine::telemetry::telem;
import game::intro;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs::win32;
// third party libraries
import thirdparty::raylib5::rl;
import thirdparty::tracy;
import thirdparty::tsoding::flg; // simple flag library
// #endregion


// multithreading 
// *unused*
const int NUM_THREADS = 3;
//Mutex  assetsLoadingMutex;
//Thread assetsLoadingThread;
//
Mutex  introMutex @public;
Thread introThread;
//

const usz GAME_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator gameArena @public;


//usz* memory_pool @local;

fn void pre_InitFunc() @init 
{
    io::printfn("/*******************************************\n");
    io::printfn("This should run %s%s%s main entry function!\n", ansi::color_rgb(171, 218, 217), "BEFORE", Ansi.RESET);
    io::printfn("*******************************************\\\n");
    
    //uint value = misc::megaBytes2Bytes(1024);
    //memory_pool = (usz*)rl::memAlloc( value * uint.sizeof);
    gameArena.init(mem, GAME_ARENA_PAGE_SIZE);
    
    // Controls raylib console logging
    // NOTE(HM) Raylib library/context gets initialized here!!
    // This is because is the first call from raylib we make.
    // NOTE(HM) This means the MINIMUM level not the only level that will log
    // anything bellow this level will not log
    // WARNING(HM) MAY BE OVERRIDEN LATER BY THE INI FILE SETTING!!!
$if $defined(_DEBUG):
    rl::setTraceLogLevel(RLTraceLogLevel.ALL);
$else
    rl::setTraceLogLevel(RLTraceLogLevel.ERROR);
$endif
    
    // ************* My own logging system ****************
    // RLTraceLogLevel means the MINIMUM log level, 
    // not the only level to log, anything bellow this level will not log.
    // WARNING(HM) MAY BE OVERRIDEN LATER BY THE INI FILE SETTING!!!
    log::init(RLTraceLogLevel.INFO);
    // *********************************************************

    game::gpGame.warningBox.init(MessageBoxType.WARN);
    game::gpGame.errorBox.init(MessageBoxType.ERROR);
    game::gpGame.infoBox.init(MessageBoxType.INFO);

    game::showSettingsWindow();

    log::info(FILE, "-------- THE <toname> ENGINE LOG ------------");
    DateTime date = datetime::now();
    log::info(FILE, "\t%s of %s of %s at %sh:%sm", date.day, date.month, date.year, date.hour, date.min);
    log::info(FILE, "---------------------------------------------");
    log::info(FILE, "---------------------------------------------\n"); 

    // print machine info
    misc::printMachineInfo();

    win32::setPhysicalWorkMemory(192 << 20, 1024 << 20); // set min 192mb and max 1gb physical memory usage for this process
}

fn void usage() @local @if($feature(TSODING_FLAG))
{
    log::info(CONSOLE, "Usage: %s [options]", flg::program_name());
    log::info(CONSOLE, "Options:");
    flg::print_options();
}


//********** ENTRY FUNCTION ******************************
fn int main(String[] args) @public @if($feature(_DEBUG))
{ // with console
    return mainEntryFunc(args);
}

fn int main(String[] args) @public @winmain @if($feature(_RELEASE)) 
{ // without console
    return mainEntryFunc(args);
}

fn int mainEntryFunc(String[] args)
{
$if $feature(TRACY_ENABLE):
    tracy::set_thread_name("main_thread");
$endif

$if $feature(TSODING_FLAG):
    ZString* version = flg::flag_bool("version", false, "Print engine version");
    ZString* help    = flg::flag_bool("help", false, "Show this help message");
$endif

    fault excuse = @catch(game::onStart(&args));
    if (excuse) {
        log::error(FILE, "Game initialization failed with excuse: %s", excuse);
        return -1;
    } else {
        //assetsLoadingMutex.init()!!;
        //assetsLoadingThread.create(&loadAssets, null)!!;
        //assetsLoadingThread.detach()!!;
        
        /*Thread[] threads = mem::temp_new_array(Thread, os::num_cpu());
        foreach (&t : threads) {
            t.create(&loadAssets, null)!!;
            // The thread resources will be cleaned up when the thread exits.
            t.detach()!!;
        }*/
        
        // Play the intro in a separate thread
		// mutex used to protect intro state
        if(try introMutex.init()) {
			// create and run intro thread
        	if(try introThread.create(&game::playIntro, null)) {
				excuse = @catch(introThread.detach()); // detach it so it runs independently and cleans up itself on exit
				if (excuse) {
        			log::error(FILE, "Failed to detach thread with excuse: %s", excuse);
    			}
			} else {
				log::error(FILE, "Failed to create and run thread to play intro!!");
			}
		} else {
			log::error(FILE, "Failed to init mutex to play intro!!");
		}
        // NOTE(HM) 
        // using .join hangs the game, I think this is because 
        // intro thread will block the main game thread and 
        // intro needs the main thread to run to display itself and update the window.
        //assert(introThread.join()!! == 0);
        //introMutex.destroy()!!;
        
        // run the game loop
        game::doOneFrame();
        // NOTE(HM) For clean program exit, do not put any code here! 
        // Between this two calls!!!
        // Any per frame code should be put inside gameDoOneFrame 
        // and exit code should be put inside gameOnExit.    
        game::onExit();
    }
    
    // return to Operating System.
    return 0;
}

// NOTE(HM) invoking @finalizer is a best effort attempt by the OS and may not be called during abnormal shutdown.
fn void pos_MainFunc() @finalizer
{
    io::printfn("/*******************************************\n");
    io::printfn("This should run %s%s%s main entry point function returns!\n", ansi::color_rgb(171, 218, 217), "AFTER", Ansi.RESET);
    io::printfn("*******************************************\\\n");
    //libc::system("pause");
}

// #endregion
