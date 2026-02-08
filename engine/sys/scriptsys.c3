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

module engine::sys::script_engine::scpt @if($feature(WREN_ENABLE));

import std::io;
import std::collections::list;
import engine::filesystem::fs;
import thirdparty::wren;
import engine::logging::log;
import thirdparty::raylib5::rl;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
import game::actors::ent;
//

alias ScriptList = List{Script*};

const SCRIPT_FOLDER_PATH = "scripts/wren/";
const SCRIPT_MAIN_MODULE_NAME = "main";
//
const SCRIPT_LANGUAGE = "WREN";
//
const SCRIPT_LANG_VERSION = wren::VERSION_STRING;
//
const SCRIPT_FILE_EXTENSION = ".scpt";
const MAX_VIRTUAL_MACHINES  = 1; // for now only one virtual machine is supported

// NOTE(HM) in wren a Module is a file with wren code inside 
// we call them scripts instead;
struct Script 
{
    String path;
    String name;
    ZString data;
    CLong modtime; // to see if the file was modified

    ScriptEngine* sengine;
}

fn void Script.init(&self, String path)
{
    self.path = path.tcopy();
    self.name = fs::getFileNameWithoutExt(self.path).tcopy();
    self.data = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = fs::getFileModTime(self.path);
}

fn bool Script.isValid() 
{
    return  self.path.len >= 4 &&
            self.name.len >= 3 &&
            self.modtime >= (CLong)1; // to see if the file was modified
}

fn void Script.deinit(&self)
{
    if(self.sengine) self.sengine = null;
    if(self.isRunning()) self.stop();
    mem::free(self);
}

<*
    Run this script
    @param [in] this : "the script being run"
    @require this.sengine != null
*>
fn void Script.run(&this) @inline
{
    //assert(this.sengine != null);
    if(this.isValid() == false) {
        log::warning(FILE, "Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $if $feature(_DEBUG):
            @unreachable("Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $else
            return;
        $endif
    }

    this.sengine.vmachine.compile_run(this);
}

fn void Script.reloadData(CLong new_mod_time)
{
    self.data    = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = new_mod_time;
    log::info(Where.FILE, "Reloaded script %s", self.name);
}

<*
 @param [&in] _sengine : "pointer to the script engine"
*>
fn void Script.linkTo(&self, ScriptEngine* _sengine) @inline
{
    self.sengine = _sengine;
}

fn void Script.stop(&self)
{
   if(self.sengine != null) self.sengine.vmachine.vm.abortFiber((int)wren::RESULT_SUCCESS);
}

interface IScriptEngine
{
    fn void	init();
    fn void	deinit();
    fn void update();
    fn void bindFunctions(WrenConfiguration* config);
    fn WrenVM* makeVM(WrenConfiguration* config);
    fn void createVirtualMachine(WrenConfiguration* config);
    fn void closeVirtualMachine();
    fn void createScript(Path script_path);
    fn Script* getScript(String name);
    fn void registerScripts(String path);
    fn void reloadScripts(String script_folder);
    fn void fileWatcher();
    fn void callMainScript() @optional;
}

struct ScriptEngine (IScriptEngine)
{
    ScriptList scripts;
    int next_check_time; // time to check for file changes
    
    //////////////////////////////////////////
    // WREN supports multiple virtual machines but I will just use one and instead
    // rely on the virtual machine fivers to run more scripts concunrrently
    //VMListPtr vmachines;  // list of virtual machines
    ScriptVirtualMachine vmachine;
}

fn void ScriptEngine.init(&self) @dynamic
{
    log::info(FILE, "- Language(%s) - Version(%s)", SCRIPT_LANGUAGE, SCRIPT_LANG_VERSION);
    WrenConfiguration config;
    config.init();
    self.bindFunctions(&config);
    self.createVirtualMachine(&config);
    log::info(FILE, "Script Engine initialized!");
    log::info(FILE, "---------------------------------------------\n");

    log::info(FILE, "-----------Registering Scripts -----------------\n");
    self.registerScripts(game::gpGame.app_base_folder.tconcat(SCRIPT_FOLDER_PATH));
    log::info(FILE, "%d scripts registered.", self.scripts.len());
    log::info(FILE, "---------------------------------------------\n");
}

fn void ScriptEngine.deinit(&self) @dynamic
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };
    self.closeVirtualMachine();
    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.update(&self) @dynamic
{
    self.fileWatcher();
}

fn void ScriptEngine.bindFunctions(&self, WrenConfiguration* config) @dynamic
{
    if(config == null) unreachable("Script Engine fatal error failed to bind functions!!");

    config.writeFn = &writeFn;
    config.errorFn = &errorFn;
    config.loadModuleFn = &loadModule;
    config.bindForeignMethodFn = &bindForeignMethod;
}

<*
    @param [&in] config : "pointer to wren virtual machine configuration"
    @ensure return != null
*>
fn WrenVM* ScriptEngine.makeVM(&self, WrenConfiguration* config) @dynamic
{
    return config.newVM();
}

fn void ScriptEngine.createVirtualMachine(&self, WrenConfiguration* config) @dynamic
{
    if(config == null) unreachable("Script Engine fatal error failed to create virtual machine!!");

    self.vmachine.init();
    self.vmachine.create(self, config);
}

fn void ScriptEngine.closeVirtualMachine(&self) @dynamic
{
    self.vmachine.deinit();
}

fn void ScriptEngine.registerScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to load script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) {
                self.createScript(script_path);
            } else {
                self.registerScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to register scripts!!");
    }
}

fn void ScriptEngine.reloadScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to reload script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) 
            {
                String file_path = script_path.path_string;
                Script* script = self.getScript(fs::getFileNameWithoutExt(file_path));
                if(script) 
                {
                    CLong file_mod_time = fs::getFileModTime(file_path); //fs::getFileSize(script_path.path_string);
                    bool mismatch = file_mod_time != script.modtime;
                    if(mismatch) // reload script
                    {
                        script.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
                        script.modtime = file_mod_time;
                        log::info(Where.FILE, "Reloaded script %s", script.name);
                    }
                    continue;
                }
                continue;
            } else {
                self.reloadScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to reload scripts!!");
    }
}

// note this function will run constantly, to see if any script file was modified
// if so it will reload the script.
fn void ScriptEngine.fileWatcher(&self) @dynamic
{
    if(game::developer.getBool() == false) return; // only in developer mode
    
    if(game::gpGame.time_ms >= self.next_check_time)
    {
        self.next_check_time = game::gpGame.time_ms + 1000; // check every second
    } 
    else { return; }

    if(self.scripts.len())
    {
        foreach(script : self.scripts)
        { 
            CLong file_mod_time = fs::getFileModTime(script.path);
            bool changed = file_mod_time != script.modtime;
            if(changed) // reload script
            {
                script.reloadData(file_mod_time); 
            }
        };
    }
}

fn void ScriptEngine.createScript(&this, Path script_path) @dynamic
{   
    Script* new_script = mem::new(Script);
    new_script.init(script_path.path_string);
    new_script.linkTo(this);
    this.scripts.push(new_script);
}

fn Script* ScriptEngine.getScript(&self, String name) @dynamic
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}

/////////////////////////////////////////// Virtual Machine ///////////////////////////////////
module engine::sys::script_engine::scpt @if($feature(WREN_ENABLE));

struct ScriptVirtualMachine
{
    uint id;
    // WREN
    WrenVM* vm @if($feature(WREN_ENABLE));
    // LUA
    LUAState* state @if($feature(LUA_ENABLE));
    LUADebug* debug @if($feature(LUA_ENABLE)); // lua debug context
}

fn void ScriptVirtualMachine.init(&self)
{
   // future init code 
}

<*
    @param [&in] scptengine : "pointer to the current script engine"
    @param [&in] config : "pointer to wren virtual machine configuration"
    @ensure self.vm != null
*>
fn void ScriptVirtualMachine.create(&self, ScriptEngine* scptengine, WrenConfiguration* config) @inline
{
    assert(self.vm == null);
    // create the new machine
    self.id++;
    // for now we only support one virtual machine per game run
    assert(self.id && self.id == MAX_VIRTUAL_MACHINES, "For now only one virtual machine is supported");
    self.vm = scptengine.makeVM(config);
}

fn void ScriptVirtualMachine.runGarbageCollector(&self) @inline
{
    if(self.vm) self.vm.collectGarbage();
}

fn void ScriptVirtualMachine.deinit(&self) @inline
{
    if(self.vm) {
        //self.vm.collectGarbage(); // should I do this here?
        self.vm.free();
        self.vm = null;
    }
}

fn void ScriptVirtualMachine.compile_run(&self, Script* script) @inline
{
    if(self.vm == null) {
        unreachable("Script Virtual Machine not created!!");
    }

    if(script == null || script.data.len() == 0) {
        log::warning(Where.FILE, "Script Virtual Machine failed to run script, script is null or empty!!");
        return;
    }

    WrenInterpretResult result = self.vm.interpret(script.name.zstr_tcopy(), script.data);

    switch (result)
    {
        // TODO(HM) handle this errors in the ingame console too if possible
        case wren::RESULT_COMPILE_ERROR: io::printfn("Compile Error!\n");
        case wren::RESULT_RUNTIME_ERROR: io::printfn("Runtime Error!\n");
        case wren::RESULT_SUCCESS: io::printfn("Success!\n");
        default:
            unreachable("Script Virtual Machine got a unkown fatal error!?");
    }
}

// wren required config callbacks

//#region import support
fn WrenLoadModuleResult loadModule(WrenVM* vm, ZString name) @local
{
    String path = game.app_base_folder.tconcat(SCRIPT_FOLDER_PATH);
    return myLoadModule(name.str_view(), path);
}

fn WrenLoadModuleResult myLoadModule(String name, String path) @local
{
    WrenLoadModuleResult result;
    RLFilePathList scriptlist = fs::loadDirectoryFiles(path);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to get path for script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path))
            {
                String found_name = fs::getFileNameWithoutExt(script_path.path_string);
                if(found_name.len && found_name == name)
                {
                    String _module_import_data = fs::fileLoadEntireText(script_path.path_string);
                    if(result.source != null) {
                        //for example, if we used malloc to allocate
                        //our source string, we use free to release it.
                        mem::free(result.source);
                    }
                    result.source = _module_import_data.zstr_tcopy();
                    break;
                }
            } else {
                String new_folder = script_path.path_string;
                result = myLoadModule(name, new_folder); // Warning(HM) recursion
                if(result.source.len()) break;
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to import module script!!");
    }

    return result;
}
//#endregion 

//#region basic logging and script error handling
fn void writeFn(WrenVM* vm, ZString text) @local
{
    // do not put a new line here, wren already does that 
    io::printf("%s", text);
}

fn void errorFn(WrenVM* vm, WrenErrorType errorType, ZString _module, int line, ZString msg) @local
{
  switch (errorType)
  {
    case wren::ERROR_COMPILE: io::printfn("[%s line %d] [Error] %s\n", _module, line, msg);
    case wren::ERROR_STACK_TRACE: io::printfn("[%s line %d] in %s\n", _module, line, msg);
    case wren::ERROR_RUNTIME: io::printfn("[Runtime Error] %s\n", msg);
    default:
        unreachable("Script Engine fatal error was Unkown.");
  }
}
//#endregion


//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// Bind Foreign Methods ///////////////////////////////////////////////

<*
    Binds C3 functions to methods defined in script classes

 @param [&in] vm : "current wren virtual machine calling this func"
*>
fn WrenForeignMethodFn bindForeignMethod(WrenVM* vm, ZString script_name, ZString className, bool isStatic, ZString signature)
{
    String module_name, class_name, fn_signature;
    module_name  = script_name.str_view();
    class_name   = className.str_view();
    fn_signature = signature.str_view();

    //WrenForeignMethodFn result;

    switch MODULES : (module_name)
    {
        case "global":
            switch (class_name)
            {
                case "Log":
                    if (isStatic)
                    {
                        if (fn_signature == "tofile(_)") {
                            //result = &event::logToFile;
                            return &event::logToFile;
                            //break MODULES;
                        }
                    } 
                    else 
                    {
                        unreachable("For now only static methods are supported");
                    }
            }
        case "main":
            switch (class_name)
            {
                case "Test":
                    if (isStatic)
                    {
                        if (fn_signature == "add(_,_)") {
                            //result = &event::add;
                            return &event::add;
                            //break MODULES;
                        }
                    }
                    else 
                    {
                        unreachable("For now only static methods are supported");
                    }
            }
        case "entity":
            switch (class_name)
            {
                case "Entity":
                    if (isStatic)
                    {
                        foreach(evfunc : ent::ENTITY_EVENTS_CALLBACKS)
                        {
                            if (fn_signature == event::getSignature(*evfunc.event)) {
                                //result = evfunc.callback;
                                return evfunc.callback;
                                //break MODULES;
                            }

                        }
                    }
                    else 
                    {
                        unreachable("For now only static methods are supported");
                    }
            }
        case "math":
            switch (class_name)
            {
                case "Vec2":
                    if (isStatic)
                    {
                        if (fn_signature == "translate(_,_)") {
                            //result = &event::vec2_translate;
                            return &event::vec2_translate;
                            //break MODULES;
                        }
                    }
                    else 
                    {
                        unreachable("For now only static methods are supported");
                    }
            }
    }

  ///  
    log::error(Where.FILE, "Failed to bind foreign method %s.%s with signature %s", module_name, class_name, fn_signature);
    return null;
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////// Bind Foreign Classes ///////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


<*
 @param [in] vm : "current wren virtual machine calling this func"
 @require vm != null
*>
fn void wren_class_vec2(WrenVM* vm)
{
    Vec2f* vec = (Vec2f*)vm.setSlotNewForeign(0, 0, Vec2f.sizeof);
    vm.ensureSlots(3); // slot 0 is the caller (and return slot), slot 1 and 2 are the fn arguments slots
    double a = vm.getSlotDouble(1);
    double b = vm.getSlotDouble(2);
    vec.x = (float)a;
    vec.y = (float)b;
    // note(HM) Wren will manage the memory allocated itself using the garbage collector
}

<*
    Binds C3 "classes" to wren classes defined in script 

 @param [in] vm : "current wren virtual machine calling this func"
 @require vm != null
*>
fn WrenForeignClassMethods bindForeignClass(WrenVM* vm, ZString script_name, ZString className)
{
    String module_name, class_name;
    module_name = script_name.str_view();
    class_name = className.str_view();

    WrenForeignClassMethods methods;

    switch MODULES : (module_name)
    {
        case "global":
            switch (class_name)
            {
                case "Log":
            }
        case "main":
            switch (class_name)
            {
                case "Test":
            }
        case "math":
            switch (class_name)
            {
                case "Vec2":
                    methods.allocate = &wren_class_vec2;
                    methods.finalize = null;
            }
        default:
            // Unknown class.
            methods.allocate = null;
            methods.finalize = null;
    }

  ///  
  return methods;
}

///////////////////////////////////////////////////////////////////////////////
//
//                          MUJS SCRIPT
//
//////////////////////////////////////////////////////////////////////////////
module engine::sys::script_engine::scpt @if($feature(MUJS_ENABLE));
import thirdparty::mujs;

import std::io;
import std::collections::list;
import engine::filesystem::fs;
import thirdparty::wren;
import engine::logging::log;
import thirdparty::raylib5::rl;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
import game::actors::ent;
//

alias ScriptList = List{Script*};

const SCRIPT_FOLDER_PATH = "scripts/mujs/";
const SCRIPT_MAIN_MODULE_NAME = "main";
//
const SCRIPT_LANGUAGE = "MUJS";
//
const SCRIPT_LANG_VERSION = mujs::VERSION_STRING;
//
const SCRIPT_FILE_EXTENSION = ".scpt";

struct Script 
{
    String path;
    String name;
    ZString data;
    CLong modtime; // to see if the file was modified
    State* context; // mujs state (current script being handled)
    ScriptEngine* sengine;
}

fn void Script.init(&self, String path)
{
    self.path = path.tcopy();
    self.name = fs::getFileNameWithoutExt(self.path).tcopy();
    self.data = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = fs::getFileModTime(self.path);

    self.context = mujs::new_state();
    if(self.context)
    {
        int ret = self.context.initStdLib();
        if(ret != 0) {
            log::warning(FILE, "mujs script failed to init stdlib with code: %d", ret);
        }
    }
}

fn bool Script.isValid() 
{
    return  self.isInitialized() && 
            self.path.len >= 4 &&
            self.name.len >= 3 &&
            self.modtime >= (CLong)1; // to see if the file was modified
}

fn void Script.deinit(&self)
{
    if(self.sengine) self.sengine = null;
    if(self.isRunning()) self.stop();
    mem::free(self);
}

<*
    Run this script
    @param [in] this : "the script being run"
    @require this.sengine != null
*>
fn void Script.run(&this) @inline
{
    //assert(this.sengine != null);
    if(this.isValid() == false) {
        log::warning(FILE, "Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $if $feature(_DEBUG):
            @unreachable("Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $else
            return;
        $endif
    }

    mujs::@try(self.context)
    {
        ret = self.context.runScript(self.path);
        self.context.runFunction("hello", mujs::ISGLOBAL);
        //any[*] _args = { any_make(&&5, int.typeid), any_make(&&5, int.typeid) };
        self.context.runFunction("testwithargs", mujs::ISGLOBAL, 5, 5);
    };
    log::info(FILE, "mujs script &s run returned: %d", self.name, ret);
}

fn bool Script.isInitialized() @inline
{
    return (self.context) ? true : false;
}

fn bool Script.isRunning() @inline 
{
    if(self.isInitialized() == false) return false;

    @todo();

    return false;
}

fn void Script.reloadData(CLong new_mod_time) 
{
    self.data    = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = new_mod_time;
    log::info(Where.FILE, "Reloaded script %s", self.name);
}

<*
 @param [&in] _sengine : "pointer to the script engine"
*>
fn void Script.linkTo(&self, ScriptEngine* _sengine) @inline
{
    self.sengine = _sengine;
}

fn void Script.stop(&self) 
{
    if(!self.isRunning()) return;
    if(self.isInitialized()) self.context.free();
}

interface IScriptEngine
{
    fn void	init();
    fn void	deinit();
    fn void update();
    fn void createScript(Path script_path);
    fn Script* getScript(String name);
    fn void registerScripts(String path);
    fn void reloadScripts(String script_folder);
    fn void fileWatcher();
    fn void callMainScript() @optional;
}

struct ScriptEngine (IScriptEngine)
{
    ScriptList scripts;
    int next_check_time; // time to check for file changes
}

fn void ScriptEngine.init(&self) @dynamic
{
    @todo();

    log::info(FILE, "- Language(%s) - Version(%s)", SCRIPT_LANGUAGE, SCRIPT_LANG_VERSION);
    // todo put self.context in the script now
    self.context = mujs::new_state();
    if(self.context) 
    {
        int ret = self.context.initStdLib();
        if(ret != 0) {
            log::warning(FILE, "mujs script failed to init stdlib with code: %d", ret);
        }
    }
    log::info(FILE, "Script Engine initialized!");
    log::info(FILE, "---------------------------------------------\n");

    log::info(FILE, "-----------Registering Scripts -----------------\n");
    self.registerScripts(game::gpGame.app_base_folder.tconcat(SCRIPT_FOLDER_PATH));
    log::info(FILE, "%d scripts registered.", self.scripts.len());
    log::info(FILE, "---------------------------------------------\n");
}

fn void ScriptEngine.deinit(&self) @dynamic
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };

    @todo();

    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.update(&self) @dynamic
{
    self.fileWatcher();
}

fn void ScriptEngine.registerScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to load script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) {
                self.createScript(script_path);
            } else {
                self.registerScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to register scripts!!");
    }
}

fn void ScriptEngine.reloadScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to reload script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) 
            {
                String file_path = script_path.path_string;
                Script* script = self.getScript(fs::getFileNameWithoutExt(file_path));
                if(script) 
                {
                    CLong file_mod_time = fs::getFileModTime(file_path); //fs::getFileSize(script_path.path_string);
                    bool mismatch = file_mod_time != script.modtime;
                    if(mismatch) // reload script
                    {
                        script.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
                        script.modtime = file_mod_time;
                        log::info(Where.FILE, "Reloaded script %s", script.name);
                    }
                    continue;
                }
                continue;
            } else {
                self.reloadScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to reload scripts!!");
    }
}

// note this function will run constantly, to see if any script file was modified
// if so it will reload the script.
fn void ScriptEngine.fileWatcher(&self) @dynamic
{
    if(game::developer.getBool() == false) return; // only in developer mode
    
    if(game::gpGame.time_ms >= self.next_check_time)
    {
        self.next_check_time = game::gpGame.time_ms + 1000; // check every second
    } 
    else { return; }

    if(self.scripts.len())
    {
        foreach(script : self.scripts)
        { 
            CLong file_mod_time = fs::getFileModTime(script.path);
            bool changed = file_mod_time != script.modtime;
            if(changed) // reload script
            {
                script.reloadData(file_mod_time); 
            }
        };
    }
}

fn void ScriptEngine.createScript(&this, Path script_path) @dynamic
{   
    Script* new_script = mem::new(Script);
    new_script.init(script_path.path_string);
    new_script.linkTo(this);
    this.scripts.push(new_script);
}

fn Script* ScriptEngine.getScript(&self, String name) @dynamic
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}


///////////////////////////////////////////////////////////////////////////////
//
//                          LUA SCRIPT
//
//////////////////////////////////////////////////////////////////////////////
module engine::sys::script_engine::scpt @if($feature(LUA_ENABLE));
import thirdparty::scripting::lua;

import std::io;
import std::collections::list;
import engine::filesystem::fs;
import thirdparty::wren;
import engine::logging::log;
import thirdparty::raylib5::rl;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
import game::actors::ent;
//

alias ScriptList = List{Script*};

const SCRIPT_FOLDER_PATH = "scripts/lua/";
const SCRIPT_MAIN_MODULE_NAME = "main";
//
const SCRIPT_LANGUAGE = "LUA";
//
const SCRIPT_LANG_VERSION = lua::RELEASE;
//
const SCRIPT_FILE_EXTENSION = ".scpt";
const MAX_VIRTUAL_MACHINES = 1; // for now only one virtual machine is supported

// NOTE(HM) in wren a Module is a file with wren code inside 
// we call them scripts instead;
struct Script 
{
    String path;
    String name;
    ZString data;
    CLong modtime; // to see if the file was modified
    LUAState* context; // lua context
    ScriptEngine* sengine;
}

fn void Script.init(&self, String path)
{
    self.path = path.tcopy();
    self.name = fs::getFileNameWithoutExt(self.path).tcopy();
    self.data = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = fs::getFileModTime(self.path);

    self.context = lua::newstate();
    if(self.context) {
        // init the lua libraries (math, string, table, etc) for this context
        self.context.openlibs();
    }
}

fn bool Script.isValid() 
{
    return  self.isInitialized() && 
            self.path.len >= 4 &&
            self.name.len >= 3 &&
            self.modtime >= (CLong)1; // to see if the file was modified
}

fn void Script.deinit(&self)
{
    if(self.sengine) self.sengine = null;
    if(self.isRunning()) self.stop();
    mem::free(self);
}

<*
    Run this script
    @param [in] this : "the script being run"
    @require this.sengine != null
*>
fn void Script.run(&this) @inline
{
    //assert(this.sengine != null);
    if(this.isValid() == false) {
        log::warning(FILE, "Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $if $feature(_DEBUG):
            @unreachable("Cannot run invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $else
            return;
        $endif
    }

    @todo();
}

fn bool Script.isInitialized() @inline
{
    @todo();

    return false;
}

fn bool Script.isRunning() @inline 
{
    if(self.isInitialized() == false) return false;

    @todo();

    return false;
}

fn void Script.reloadData(CLong new_mod_time) 
{
    self.data    = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = new_mod_time;
    log::info(Where.FILE, "Reloaded script %s", self.name);
}

<*
 @param [&in] _sengine : "pointer to the script engine"
*>
fn void Script.linkTo(&self, ScriptEngine* _sengine) @inline
{
    self.sengine = _sengine;
}

fn void Script.stop(&self) 
{
    if(!self.isRunning()) return;
    @todo();
}

interface IScriptEngine
{
    fn void	init();
    fn void	deinit();
    fn void update();
    fn void createScript(Path script_path);
    fn Script* getScript(String name);
    fn void registerScripts(String path);
    fn void reloadScripts(String script_folder);
    fn void fileWatcher();
    fn void callMainScript() @optional;
}

struct ScriptEngine (IScriptEngine)
{
    ScriptList scripts;
    int next_check_time; // time to check for file changes
    LUADebug* debug; // lua debug context
}

fn void ScriptEngine.init(&self) @dynamic
{
    log::info(FILE, "- Language(%s) - Version(%s)", SCRIPT_LANGUAGE, SCRIPT_LANG_VERSION);
    log::info(FILE, "-----------Registering LUA globals -----------------\n");
    lua::registerGameLuaGlobals();
    log::info(FILE, "------------------ done ---------------------\n");

    log::info(FILE, "-----------Registering Scripts -----------------\n");
    self.registerScripts(game::gpGame.app_base_folder.tconcat(SCRIPT_FOLDER_PATH));
    log::info(FILE, "%d scripts registered.", self.scripts.len());
    log::info(FILE, "------------------ done ---------------------\n");
    self.debug = mem::new(LUADebug);
    log::info(FILE, "Script Engine initialized!");
    log::info(FILE, "---------------------------------------------\n");
}

fn void ScriptEngine.deinit(&self) @dynamic
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };

    if(self.debug != null) {
        mem::free(self.debug);
        self.debug = null;
    }
    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.update(&self) @dynamic
{
    /*lua::updateGlobalType("g_timeSc", any_make(&local_game.time_sec, float.typeid));
    lua::updateGlobalType("g_timeMs", any_make(&gpGame.time_ms, int.typeid));
    lua::updateGlobalType("g_deltaTime", any_make(&gpGame.dt, float.typeid));*/
    lua::updateGameLuaGlobals();
    self.fileWatcher();
}

fn void ScriptEngine.registerScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to load script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) {
                self.createScript(script_path);
            } else {
                self.registerScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to register scripts!!");
    }
}

fn void ScriptEngine.reloadScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to reload script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) 
            {
                String file_path = script_path.path_string;
                Script* script = self.getScript(fs::getFileNameWithoutExt(file_path));
                if(script) 
                {
                    CLong file_mod_time = fs::getFileModTime(file_path); //fs::getFileSize(script_path.path_string);
                    bool mismatch = file_mod_time != script.modtime;
                    if(mismatch) // reload script
                    {
                        script.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
                        script.modtime = file_mod_time;
                        log::info(Where.FILE, "Reloaded script %s", script.name);
                    }
                    continue;
                }
                continue;
            } else {
                self.reloadScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to reload scripts!!");
    }
}

// note this function will run constantly, to see if any script file was modified
// if so it will reload the script.
fn void ScriptEngine.fileWatcher(&self) @dynamic
{
    if(game::developer.getBool() == false) return; // only in developer mode
    
    if(game::gpGame.time_ms >= self.next_check_time)
    {
        self.next_check_time = game::gpGame.time_ms + 1000; // check every second
    } 
    else { return; }

    if(self.scripts.len())
    {
        foreach(script : self.scripts)
        { 
            CLong file_mod_time = fs::getFileModTime(script.path);
            bool changed = file_mod_time != script.modtime;
            if(changed) // reload script
            {
                script.reloadData(file_mod_time); 
            }
        };
    }
}

fn void ScriptEngine.createScript(&this, Path script_path) @dynamic
{   
    Script* new_script = mem::new(Script);
    new_script.init(script_path.path_string);
    new_script.linkTo(this);
    this.scripts.push(new_script);
}

fn Script* ScriptEngine.getScript(&self, String name) @dynamic
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}


///////////////////////////////////////////////////////////////////////////////
//
//                          UMKA SCRIPT
//
//////////////////////////////////////////////////////////////////////////////

module engine::sys::script_engine::scpt @if($feature(UMKA_ENABLE));

import std::io;
import std::collections::list;
import engine::filesystem::fs;
import engine::logging::log;
import thirdparty::raylib5::rl; // for RLFilePathList
import thirdparty::scripting::umka;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
//import game::actors::ent;
//

alias ScriptList = List{Script*};

const SCRIPT_FOLDER_PATH      = "scripts/umka/";
const SCRIPT_MAIN_MODULE_NAME = "main";
const SCRIPT_LANGUAGE         = "UMKA";
const SCRIPT_LANG_VERSION     = umka::RELEASE;
const SCRIPT_FILE_EXTENSION   = ".scpt";

struct ScriptFlags @local
{
    bool inited; // initialized
    bool compiled;
}

// each script is container for a language context/environment
struct Script 
{
    String path;    // the path to the script module/file
    String name;    // the name of the script file
    ZString data;   // the full text data of the module/file 
    CLong modtime;  // file modification time, to see if the file was modified
    Umka* context;  // current script being handled
    ScriptFlags fl; // flags
    ScriptEngine* sengine; // pointer to the main Script System if necessary
}


fn void Script.init(&self, String path, int argc = 0, ZString* argv = null)
{
    self.path = path.tcopy();
    self.name = fs::getFileNameWithoutExt(self.path).tcopy();
    self.data = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = fs::getFileModTime(self.path);

    // create umka context
    self.context = umka::alloc();
    // init/setup the script data (is not compiled or run at this time)
    UmkaScriptInitData inidata =
    {
        .fileName = self.name.zstr_tcopy(),
        .sourceString = self.data, 
        .stackSize = 1024*1024, // 2MB (amount of stack memory for the context)
        .reserved = null, // unused 
        .argc = argc, // script flags count passed during game initialization if any...
        .argv = argv, // script flags cmds passed during game initialization if any...
        .fileSystemEnabled = false, // todo find whats this...
        .implLibsEnabled = false // todo find whats this...
    };
    if(catch excuse = self.context.init(&inidata)) {
        log::info(FILE, "failed to initialize umka script: %s with excuse: %s!!", self.name, excuse);
    } else {
        self.fl.inited = true;
    }
}

fn bool Script.isValid(&self) @inline
{
    return  self.hasContext() && self.fl.inited && 
            self.path.len >= 4 &&
            self.name.len >= 3 &&
            self.modtime >= (CLong)1; // to see if the file was modified
}

macro Script.hasContext(&self) => self.context != null;
macro Script.freeContext(&self) => self.context.free();

fn void Script.deinit(&self)
{
    if(self.sengine) self.sengine = null;
    // do Umka de-initialization
    if(self.hasContext()) self.freeContext();
    // free the script container itself
    //mem::free(self); this is done by the script engine now!!
}

fn void Script.compile(&this) @inline
{
    if(this.isValid() == false) 
    {
        log::warning(FILE, "Cannot compile invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $if $feature(_DEBUG):
            unreachable("Cannot compile invalid script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $else
            return;
        $endif
    }

    /*if (this.context.compile() == false) {
        UmkaError *error = this.context.getError();
        log::warning(FILE, "Failed to compile script: %s (l:%d, p:%d): %s\n", error.fileName, error.line, error.pos, error.msg);
    } else {
        this.fl.compiled = true;
    }*/
    if (try this.context.compile()) {
        this.fl.compiled = true;
    } else {
        UmkaError *error = this.context.getError();
        log::warning(FILE, "Failed to compile script: %s (l:%d, p:%d):> '%s'\n", error.fileName, error.line, error.pos, error.msg);
    }
}

fn void Script.run(&this) @inline
{
    if(this.fl.compiled == false) {
        log::warning(FILE, "Trying to run a non compiled script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $if $feature(_DEBUG):
            unreachable("Trying to run a non compiled script! '%s' ", (this.name.len) ? this.name : "<unnamed>");
        $else
            return;
        $endif
    }

    assert(this.hasContext());
    int result = this.context.run();
    if (result == -1) {
        UmkaError *error = this.context.getError();
        log::warning(FILE, "script failed to run: %s (%d, %d): %s\n", error.fileName, error.line, error.pos, error.msg);
    }
}

fn void Script.compile_run(&this) @inline
{
    this.compile();
    this.run();
}

macro Script.isRunning(&self) => (self.hasContext()) ? self.context.alive() : false;

fn void Script.reloadData(&self, CLong new_mod_time) 
{
    self.data    = fs::fileLoadEntireText(self.path).zstr_tcopy();
    self.modtime = new_mod_time;
    log::info(Where.FILE, "Reloaded script %s", self.name);
}

<*
 @param [&in] _sengine : "pointer to the script engine"
*>
fn void Script.linkTo(&self, ScriptEngine* _sengine) @inline
{
    self.sengine = _sengine;
}

interface IScriptEngine
{
    fn void	init();
    fn void	deinit();
    fn void update();
    fn void createScript(Path script_path);
    fn void removeScript(String name) @optional;
    fn Script* getScript(String name);
    fn void registerScripts(String path);
    fn void reloadScripts(String script_folder);
    fn void fileWatcher();
    fn void callMainScript() @optional;
}

struct ScriptEngine (IScriptEngine)
{
    ScriptList scripts;
    int next_check_time; // time to check for file changes
}

fn void ScriptEngine.init(&self) @dynamic
{
    log::info(FILE, "- Language(%s) - Version(%s)", SCRIPT_LANGUAGE, SCRIPT_LANG_VERSION);
    log::info(FILE, "-----------Registering Scripts -----------------\n");
        self.registerScripts(game::gpGame.app_base_folder.tconcat(SCRIPT_FOLDER_PATH));
        usz scpt_count = self.scripts.len();
        log::info(FILE, "\t- '%d' %s registered.", scpt_count, (scpt_count > 1) ? "scripts" : "script");
    log::info(FILE, "Script Engine initialized!");
    log::info(FILE, "---------------------------------------------\n");
}

fn void ScriptEngine.deinit(&self) @dynamic
{
    if(self.scripts.len()) foreach(script : self.scripts) { 
        script.deinit();
        mem::free(script);
        script = null;
    };
    self.scripts.clear();
    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.update(&self) @dynamic
{
    self.fileWatcher();
}

fn void ScriptEngine.registerScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to load script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) {
                self.createScript(script_path);
            } else {
                self.registerScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to register scripts!!");
    }
}

fn void ScriptEngine.reloadScripts(&self, String script_folder) @dynamic
{
    RLFilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                log::warning(Where.FILE,"Failed to reload script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_PATH, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) 
            {
                String file_path = script_path.path_string;
                Script* script = self.getScript(fs::getFileNameWithoutExt(file_path));
                if(script) 
                {
                    CLong file_mod_time = fs::getFileModTime(file_path); //fs::getFileSize(script_path.path_string);
                    bool mismatch = file_mod_time != script.modtime;
                    if(mismatch) // reload script
                    {
                        script.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
                        script.modtime = file_mod_time;
                        log::info(Where.FILE, "Reloaded script %s", script.name);
                    }
                    continue;
                }
                continue;
            } else {
                self.reloadScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to reload scripts!!");
    }
}

fn void ScriptEngine.removeScript(&self, String name) @dynamic 
{
    foreach(script : self.scripts)
    { 
        if(script.name == name)
        {
            script.deinit();
            mem::free(script);
            self.scripts.remove_item(script);
            return;
        }
    };
}

// note this function will run constantly, to see if any script file was modified
// if so it will reload the script.
fn void ScriptEngine.fileWatcher(&self) @dynamic
{
    if(game::developer.getBool() == false) return; // only in developer mode
    
    if(game::gpGame.time_ms >= self.next_check_time)
    {
        self.next_check_time = game::gpGame.time_ms + 1000; // check every second
    } 
    else { return; }

    if(self.scripts.len())
    {
        foreach(script : self.scripts)
        { 
            CLong file_mod_time = fs::getFileModTime(script.path);
            bool changed = file_mod_time != script.modtime;
            if(changed) // reload script
            {
                script.reloadData(file_mod_time); 
            }
        };
    }
}

fn void ScriptEngine.createScript(&this, Path script_path) @dynamic
{   
    Script* new_script = mem::new(Script);
    new_script.init(script_path.path_string);
    new_script.linkTo(this);
    this.scripts.push(new_script);
}

fn Script* ScriptEngine.getScript(&self, String name) @dynamic
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}
