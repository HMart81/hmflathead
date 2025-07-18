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

// Add fields and methods for 2D rendering
// For example, you might have a method to draw a rectangle or a sprite

module engine::sys::script_engine::scpt @if($feature(WREN_ENABLE));

import std::io;
import std::collections::list;
import thirdparty::wren;
import engine::filesystem::fs;
import engine::logging::lgr;
import thirdparty::raylib5::rl;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
import game::actors::ent;

//alias VMListPtr = List{WrenVM*};
alias ScriptList = List{Script*};

const SCRIPT_FOLDER_NAME = "scripts";
const SCRIPT_FILE_EXTENSION = ".scpt";

// NOTE(HM) in wren a Module is a file with wren code inside 
// we call them scripts instead;
struct Script 
{
    String path;
    String name;
    ZString data;
    CLong modtime; // to see if the file was modified
    //WrenVM* vm;
    ScriptEngine* sengine;
}

fn void Script.deinit(&self)
{
    if(self.sengine) self.sengine = null;
    mem::free(self);
}

fn void Script.run(&this) @inline
{
    assert(this.sengine != null);
    this.sengine.vmachine.compile_run(this); 
}

<*
 @param [in] _sengine : "pointer to the script engine"
 @require _sengine != null
*>
fn void Script.linkTo(&self, ScriptEngine* _sengine) @inline
{
    self.sengine = _sengine;
}

fn void Script.stop(&self) 
{
    if(self.sengine != null)
    {
        self.sengine.vmachine.vm.abortFiber((int)wren::RESULT_SUCCESS);
    }
}

struct ScriptEngine
{
    WrenConfiguration config;
    ScriptList scripts;
    // wren supports multiple virtual machines but I will just use one and instead
    // rely on the virtual machine fivers to run more scripts concunrrently
    //VMListPtr vmachines;  // list of virtual machines
    ScriptVirtualMachine vmachine;
}

fn void ScriptEngine.init(&self)
{
    self.config.init();
    self.bindFunctions();
    self.createVirtualMachine();
    io::printfn("ScriptEngine initialized");
}

fn void ScriptEngine.deinit(&self)
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };
    self.closeVirtualMachine();
    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.bindFunctions(&self) @inline @local
{
    self.config.writeFn = &writeFn;
    self.config.errorFn = &errorFn;
    self.config.loadModuleFn = &loadModule;
    self.config.bindForeignMethodFn = &bindForeignMethod;
}

fn WrenVM* ScriptEngine.makeVM(&self) @inline @local
{
    return self.config.newVM();
}

fn void ScriptEngine.createVirtualMachine(&self) @inline @local
{
    self.vmachine.init();
    self.vmachine.create(self);
}

fn void ScriptEngine.closeVirtualMachine(&self) @inline @local
{
    self.vmachine.deinit();
}

fn void ScriptEngine.registerScripts(&self, String script_folder)
{
    FilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                lgr::warning(Where.FILE,"Failed to load script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_NAME, excuse)!!;
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

fn void ScriptEngine.reloadScripts(&self, String script_folder)
{
    FilePathList scriptlist = fs::loadDirectoryFiles(script_folder);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                lgr::warning(Where.FILE,"Failed to reload script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_NAME, excuse)!!;
                continue;
            }

            if(path::is_file(script_path)) 
            {
                //();
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
                    }
                }
            } else {
                self.reloadScripts(script_path.path_string); // Warning(HM) recursion
            }
        }
    } else {
        unreachable("Script Engine fatal error failed to reload scripts!!");
    }
}

fn void ScriptEngine.createScript(&this, Path script_path)
{
    Script* new_module = mem::new(Script);
    new_module.path = script_path.path_string.tcopy();
    new_module.name = fs::getFileNameWithoutExt(script_path.path_string).tcopy();
    new_module.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
    new_module.modtime = fs::getFileModTime(script_path.path_string);
    new_module.linkTo(this);
    this.scripts.push(new_module);
}

fn Script* ScriptEngine.getScript(&self, String name) 
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}

/////////////////////////////////////////// Virtual Machine ///////////////////////////////////
struct ScriptVirtualMachine
{
    uint id;
    WrenVM* vm;
}

fn void ScriptVirtualMachine.init(&self)
{
    
}

<*
 @param [in] scptengine : "pointer to the current script engine"
 @require scptengine != null
 @ensure self.vm != null
*>
fn void ScriptVirtualMachine.create(&self, ScriptEngine* scptengine)
{
    // for now we only support one virtual machine per game run
    assert(self.vm == null);
    // create the new machine
    if(self.id) self.id++;
    self.vm = scptengine.makeVM();
}

fn void ScriptVirtualMachine.deinit(&self) @inline
{
    if(self.vm) {
        //self.vm.collectGarbage(); // should I do this?
        self.vm.free();
        self.vm = null;
    }
}

fn void ScriptVirtualMachine.compile_run(&self, Script* script) @inline
{
    WrenInterpretResult result = self.vm.interpret(script.name.zstr_tcopy(), script.data);

    switch (result)
    {
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
    String path = main::gpGame.app_base_folder.tconcat(SCRIPT_FOLDER_NAME);
    return myLoadModule(name.str_view(), path);
}

fn WrenLoadModuleResult myLoadModule(String name, String path) @local
{
    WrenLoadModuleResult result;
    FilePathList scriptlist = fs::loadDirectoryFiles(path);
    defer if(scriptlist.count) fs::unloadDirectoryFiles(scriptlist);

    if(scriptlist.count >= 1) 
    {
        for(int i = 0; i < scriptlist.count; i++) 
        {
            Path? script_path = fs::newPath(scriptlist.paths[i].str_view());
            if(catch excuse = script_path) 
            {
                lgr::warning(Where.FILE,"Failed to get path for script %s inside %s with excuse: %s", 
                                fs::getFileNameWithoutExt(script_path.path_string), SCRIPT_FOLDER_NAME, excuse)!!;
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

 @param [in] vm : "current wren virtual machine calling this func"
 @require vm != null
*>
fn WrenForeignMethodFn bindForeignMethod(WrenVM* vm, ZString script_name, ZString className, bool isStatic, ZString signature)
{
    String module_name, class_name, fn_signature;
    module_name = script_name.str_view();
    class_name = className.str_view();
    fn_signature = signature.str_view();

    WrenForeignMethodFn result;

    switch MODULES : (module_name)
    {
        case "global":
            switch (class_name)
            {
                case "Log":
                    if (isStatic)
                    {
                        if (fn_signature == "tofile(_)") {
                            result = &event::logToFile;
                            break MODULES;
                        }
                    }
            }
        case "main":
            switch (class_name)
            {
                case "Test":
                    if (isStatic)
                    {
                        if (fn_signature == "add(_,_)") {
                            result = &event::add;
                            break MODULES;
                        }
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
                                result = evfunc.callback;
                                break MODULES;
                            }

                        }
                        if (result == null) {
                            lgr::warning(Where.FILE, "Failed to bind foreign method %s.%s with signature %s", module_name, class_name, fn_signature);
                        }
                    }
            }
        case "math":
            switch (class_name)
            {
                case "Vec2":
                    if (isStatic)
                    {
                        if (fn_signature == "translate(_,_)") {
                            result = &event::vec2_translate;
                            break MODULES;
                        }
                    }
            }
    }

  ///  
  return result;
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