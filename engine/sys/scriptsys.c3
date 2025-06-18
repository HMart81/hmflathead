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
    uint data_size;
    WrenVM* vm;
    ScriptList imports;
}

fn void Script.deinit(&self)
{
    mem::free(self);
}

fn void Script.run(&self, ScriptEngine* sengine) 
{
    assert(sengine != null);
    if(!self.vm) self.vm = sengine.makeVM();
    if(self.vm)
    {
        WrenInterpretResult result = self.vm.interpret(self.name.zstr_tcopy(), self.data);

        switch (result)
        {
            case wren::RESULT_COMPILE_ERROR: io::printfn("Compile Error!\n");
            case wren::RESULT_RUNTIME_ERROR: io::printfn("Runtime Error!\n");
            case wren::RESULT_SUCCESS: io::printfn("Success!\n");
            default:
                unreachable("Script Engine fatal error was Unkown.");
        }
    } else {
        lgr::warning(Where.FILE,"Failed to run script %s because it has no virtual machine", self.name);
    }
}

fn void Script.stop(&self) {
    if(self.vm) 
    {
        self.vm.collectGarbage(); // should I do this?
        self.vm.free();
        self.vm = null;
    }
}

struct ScriptEngine
{
    WrenConfiguration config;
    //VMListPtr vmachines;  // list of virtual machines
    ScriptList scripts;
}

fn void ScriptEngine.init(&self)
{
    self.config.init();
    self.config.writeFn = &writeFn;
    self.config.errorFn = &errorFn;
    self.config.loadModuleFn = &loadModule;
    io::printfn("ScriptEngine initialized");
}

fn void ScriptEngine.deinit(&self)
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };
    io::printfn("ScriptEngine deinitialized");
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

            if(path::is_file(script_path)) {
                String script_name = fs::getFileNameWithoutExt(script_path.path_string);
                Script* script = self.getScript(script_name);
                if(script) {
                    usz file_size = fs::getFileSize(script_path.path_string);
                    bool size_mismatch = (int)file_size != script.data_size;
                    if(size_mismatch) {
                        script.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
                        script.data_size = (int)file_size;
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

fn WrenVM* ScriptEngine.makeVM(&self) 
{
    return self.config.newVM();
}

fn void ScriptEngine.createScript(&self, Path script_path)
{
    // else
    Script* new_module = mem::new(Script);
    new_module.path = script_path.path_string.tcopy();
    new_module.name = fs::getFileNameWithoutExt(script_path.path_string);
    new_module.data = fs::fileLoadEntireText(script_path.path_string).zstr_tcopy();
    new_module.data_size = script_path.path_string.len;
    self.scripts.push(new_module);
}

<*
* @ensure return != null
*>
fn Script* ScriptEngine.getScript(&self, String name) 
{
    foreach(script : self.scripts) 
    { 
        if(script.name == name) return script;
    };

    return null;
}


// wren config callbacks

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
                    String _module_import = fs::fileLoadEntireText(script_path.path_string);
                    result.source = _module_import.zstr_tcopy();
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
