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
module thirdparty::scripting::lua @if($feature(LUA_ENABLE));


// lua embedding tutorials:
// https://www.youtube.com/watch?v=bg_7iRwfiOg&list=PLLwK93hM93Z3nhfJyRRWGRXHaXgNX0Itk&index=9
// https://www.youtube.com/watch?v=4l5HdmPoynw

// lua manual: https://www.lua.org/manual/5.4/

import std::io;
import game::main;
import std::thread;
import engine::misc; // misc code
import engine::logging::log;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;

import engine::sys::licensee;
alias lic = module engine::sys::licensee;

alias game = main::gpGame;

const TRUE @builtin  = 1;
const FALSE @builtin = 0;

const LUASCRIPTS_FOLDER_NAME = "scripts/";

// UPDATE this value if more globals are needed!!!!
const int MAX_GAME_LUAGLOBALS = 6; // max number of game lua globals to register

struct LUAGlobal 
{
    String name;
    any value;
    bool is_const; // if true the value is always constant and cannot be changed from lua as well
}

LUAGlobal[MAX_GAME_LUAGLOBALS] lua_globals;

fn void registerGameLuaGlobals()
{
    assert(game.lua_state != null, "Fatal Error: Lua state not initialized!!");
    lua_globals = {
        {"g_appName", any_make(&game.app_name, String.typeid), true},
        {"g_appVersion", any_make(&&lic::@game_version(), String.typeid), true},
        {"g_baseFolder", any_make(&game.app_base_folder, String.typeid), true},
        {"g_timeSc", any_make(&game.time_sec, float.typeid), false},
        {"g_timeMs", any_make(&game.time_ms, int.typeid), false},
        {"g_deltaTime", any_make(&game.dt, float.typeid), false}
    };

    foreach(global : lua_globals)
    {
        lua::registerGlobalType(global.name, global.value);
    }
}

fn void updateGameLuaGlobals()
{
    //assert(game.lua_state != null, "Fatal Error: Lua state not initialized!!");

    foreach(global : lua_globals)
    {
        // only update non constant globals
        if(!global.is_const) lua::updateGlobalType(global.name, global.value);
    }
}

fn void preloadscript(String name)
{
    assert(game.app_base_folder != "", "Fatal Error: Application base folder not set!!");
    assert(game.lua_state != null, "Fatal Error: Lua state not initialized!!");

    if(!name.ends_with(".lua")) {
        name = name.tconcat(".lua");
    }
    String path = game.app_base_folder.tconcat(LUASCRIPTS_FOLDER_NAME).tconcat(name);
    int r = game.lua_state.@loadfile(path);
    if(r != OK) {
        // If something went wrong, error message is at the TOP of the stack.
        String error = game.lua_state.tostring(lua::LUASTACK_RETURN).str_view(); // Get error message
        log::warning(CONSOLE, "lua script engine failed to preload %s.lua with error: %s", name, error);
        game.lua_state.pop(1); // Remove error message from the stack
    }
}

<*
 @param name : "name of the lua script file without the .lua extension"
 @require name != "" && game.lua_state != null && game.app_base_folder != ""
*>
fn bool initScript(String name)
{
    if(!name.ends_with(".lua")) {
        name = name.tconcat(".lua");
    }
    String path = game.app_base_folder.tconcat(LUASCRIPTS_FOLDER_NAME).tconcat(name);
    return check(game.lua_state, (int)game.lua_state.dofile(path));
}

<*
 @param [&in] state : "pointer to the lua state"
 @param r : "return code from lua function calls"
*>
fn bool check(LUAState* state, int r) @inline
{
    if ( r != lua::OK) {
        String error = state.tostring(LUASTACK_RETURN).str_view(); // Get error message
        log::warning(CONSOLE, "lua script engine failed with code: %s", error);
        state.pop(1); // Remove error message from the stack
        return false;
    }
    return true;
}

fn void dumpstack(LUAState *state) @inline
{
    io::printf("\n==========================\n");
    int top = state.gettop();
    if(top == 0) {
        io::print("Stack is empty\n");
        io::print("==========================\n\n");
        return;
    }

    io::printfn("Stack elements: %s \n", top);
    for (int i = top; i >= 1; i--)
    {
        //io::printfn("%d\t%s\t", i, state.typename(i));
        int type = state.type(i);
        io::printf("%s > [%s] = ", i, typeTostr(type));
        switch (type)
        {
            case TYPE_NUMBER:
                io::printfn("%s",state.tonumber(i));
            case TYPE_STRING:
                io::printfn("%s",state.tostring(i));
            case TYPE_BOOLEAN:
                io::printfn("%s", (state.toboolean(i) ? "true" : "false"));
            case TYPE_NIL:
                io::printfn("%s", "nil");
            default:
                //io::printf("[%s] >> ", typeTostr(type));
                io::printfn("%d",state.topointer(i));
        }
    }
    io::print("==========================\n\n");
}

<* @require state != null *>
macro clearStack(state) => state.pop(state.gettop());

/*
** Search for 'objidx' in table at index -1 (top). ('objidx' must be an
** absolute index.) Return 1 + string at top if it found a good name.
*/
fn int LUAState.findfield(&self, int objidx, int level) 
{
  if (level == 0 || !self.istable(LUASTACK_TOP)) {
    return 0;  /* not found */
  }

  self.pushnil();  /* start 'next' loop */
  while (self.next(LUASTACK_IDX2)) {  /* for each pair in table */
    if (self.type(LUASTACK_IDX2) == TYPE_STRING) {  /* ignore non-string keys */
      if (self.rawequal(objidx, LUASTACK_TOP)) {  /* found object? */
        self.pop(1);  /* remove value (but keep name) */
        return 1;
      }
      else if (self.findfield(objidx, level - 1)) {  /* try recursively */
        /* stack: lib_name, lib_table, field_name (top) */
        self.pushliteral(".");  /* place '.' between the two names */
        self.replace(LUASTACK_IDX3);  /* (in the slot occupied by table) */
        self.concat(3);  /* lib_name.field_name */
        return 1;
      }
    }
    self.pop(1);  /* remove value */
  }
  return 0;  /* not found */
}

<*
    In lua modules are just tables with functions inside them
    This function will run a function inside a table.

    @param module_name : "name of the table in lua"
    @param menber_func : "name of the function inside the table"
    @param rtrn_count : "number of return values expected from the function, -1 for multiple return values"
    @param args : "arguments to be passed to the function, supported types are: ichar, short, int, char, ushort, uint, float, double, String, ZString"
*> 
fn void runModulefunction(String module_name, String menber_func, int rtrn_count, args...) @format(0)
{
    assert(game.lua_state != null, "Fatal Error: Lua state not initialized!!");

    LUAState* state = game.lua_state;
    //dumpstack(state);

    // make sure the module code is loaded and setup
    // this will also put the module table onto the stack
    if(initScript(module_name) == false) {
        unreachable("lua script engine failed to run module %s, cannot continue!!", module_name);
    }

    // first cheack if stack has space for the args + 2 for the module and menber function itself
    if(args.len)
    {
        if(state.checkstack((int)args.len + 2) == FALSE) {
            unreachable("lua script engine stack overflow!! cannot push %d args for func %s of module %s", args.len, menber_func, module_name);
        }
    } else {
        if(state.checkstack(2) == FALSE) {
            unreachable("lua script engine stack overflow!! cannot push module %s and menber func %s unto stack.", module_name, menber_func);
        }
    }

    //state.getstack(LUASTACK_TOP, game.lua_debug); // get the current stack frame info
    //state.getinfo("nSl", game.lua_debug); // get info about the function at the current stack frame
    //ZString l = state.getlocal(null, LUASTACK_TOP);
    //io::printfn("local name at top of stack: %s", l);   
   // TValue tp = state.getglobal("_ENV"); // get the _ENV table
   
    //TValue tp = state.getglobal(module_name.zstr_tcopy());
    dumpstack(state);
    //assert(state.type(tp) == TYPE_TABLE, "Value pushed unto stack is not a table! it is %s", typeTostr(tp));
    // ^ get and put the module to be called onto the stack 
    // NOTE(HM):
    //  at this point the module name is at the top of the stack)
    // Warning(HM): 
    //  for some reason this will push nil to the top of the stack here!?
    //state.pop(1); // remove the nil value in the stack after the table

    state.pushstring(menber_func.zstr_tcopy());
    // ^ Now push the menber func NAME onto the stack
    // NOTE(HM) 
    //  at this point the menber func NAME (as a STRING) is at the top of the stack)
    //  and the module table is just below it in the stack at index -2

    state.gettable(-2); // misleading name, it does not get a table, it gets the value of the key in the table at index -2
    // ^ Now pop the previous function NAME from the stack
    // and push the FUNCTION pointer from the table onto the stack
    // NOTE(HM): 
    //   at this point the function to be called, should be the one at the top of the stack
    //   and ready to be called.
    assert(state.isfunction(LUASTACK_TOP), "Value pushed unto stack is not a function! it is %s", state.typename(LUASTACK_TOP));

    // After the function, push any existing function arguments onto the stack, one after the other
    foreach(i, arg : args)
    {
        switch(arg.type)
        {
            case ichar.typeid  : (!arg.ptr) ? state.pushnil() : state.pushinteger((Integer)*(ichar*)arg.ptr);
            case short.typeid  : (!arg.ptr) ? state.pushnil() : state.pushinteger((Integer)*(short*)arg.ptr);
            case int.typeid    : (!arg.ptr) ? state.pushnil() : state.pushinteger((Integer)*(int*)arg.ptr);
            case char.typeid   : (!arg.ptr) ? state.pushnil() : state.pushinteger((Unsigned)*(char*)arg.ptr);
            case ushort.typeid : (!arg.ptr) ? state.pushnil() : state.pushinteger((Unsigned)*(ushort*)arg.ptr);
            case uint.typeid   : (!arg.ptr) ? state.pushnil() : state.pushinteger((Unsigned)*(uint*)arg.ptr);
            case float.typeid  : (!arg.ptr) ? state.pushnil() : state.pushnumber((Number)*(float*)arg.ptr);
            case double.typeid : (!arg.ptr) ? state.pushnil() : state.pushnumber(*(Number*)arg.ptr);
            case String.typeid :
                String* str = (String*)arg.ptr;
                (!arg.ptr) ? state.pushstring("") : state.pushlstring(*(ZString*)str, str.len);
            case ZString.typeid: (!arg.ptr) ? state.pushstring("") : state.pushstring(*(ZString*)arg.ptr);
            default: 
                unreachable("lua failed to register unknown arg %d for func %s", i, menber_func);
        }
    }

    //dumpstack(state);

    // If all went well 
    // Try execute the function with the number of arguments and expected return values.
    int r = state.pcall((int)args.len, (rtrn_count >= 0) ? rtrn_count : MULTI_RET, 0);
    if (lua::check(state, r))
    {
        // If the function executed successfully, 
        // the return values are at the top of the lua stack
        // You can retrieve them as needed,
        // for example, if you expect one integer return value:
        if(rtrn_count == 1)
        {
            if(state.isinteger(LUASTACK_TOP))
            {
                // Convert the return value to integer
                int returnValue = state.toS32(LUASTACK_RETURN, true);
                // Use returnValue as needed
                $if $defined(DEBUG):
                    log::warning(CONSOLE, "lua script engine successfully ran function %s with return value: %d", name, returnValue);
                $endif
            } 
            else
            {
                @todo("handle other return types");
            }
        } 
        else if(rtrn_count > 1) 
        {
            // Handle multiple return values if necessary
            // For simplicity, we'll just pop them off the stack here
            state.pop(rtrn_count);
            @todo("Handle multiple return values");
        }

        // Remove the function and all its data from the stack
        state.pop(state.gettop() - 1); // -1 to keep the module table in the stack
        //clearStack(state);
        //dumpstack(state);                                  
    }
}

<*
    This function will run a global free function inside a file.

    @param name : "name of the table in lua"
    @param rtrn_count : "number of return values expected from the function, -1 for multiple return values"
    @param args : "arguments to be passed to the function, supported types are: ichar, short, int, char, ushort, uint, float, double, String, ZString"
*> 
fn void runGlobalfunction(String name, int rtrn_count, args...) @format(0)
{
    assert(game.lua_state != null, "Fatal Error: Lua state not initialized!!");

    LUAState* state = game.lua_state;

    // get and put the function to be called onto the stack
    TValue tp = state.getglobal(name.zstr_tcopy());
    assert(state.type(tp) == TYPE_FUNCTION, "Value pushed unto stack is not a function! it is %s", typeTostr(tp));

    if(args.len) // if there are args to push onto the stack
    { 
        // first cheack if stack has space for the args + 1 for the function itself
        if(state.checkstack((int)args.len + 1) == FALSE) {
            unreachable("lua script engine stack overflow!! cannot push %d args for func %s", args.len, name);
        }

        // Push arguments onto the stack
        foreach(i, arg : args)
        {
            switch(arg.type)
            {
                case ichar.typeid  : state.pushinteger((Integer)*(ichar*)arg.ptr);
                case short.typeid  : state.pushinteger((Integer)*(short*)arg.ptr);
                case int.typeid    : state.pushinteger((Integer)*(int*)arg.ptr);
                case char.typeid   : state.pushinteger((Unsigned)*(char*)arg.ptr);
                case ushort.typeid : state.pushinteger((Unsigned)*(ushort*)arg.ptr);
                case uint.typeid   : state.pushinteger((Unsigned)*(uint*)arg.ptr);
                case float.typeid  : state.pushnumber((Number)*(float*)arg.ptr);
                case double.typeid : state.pushnumber(*(Number*)arg.ptr);
                case String.typeid : state.pushstring((*(String*)arg.ptr).zstr_tcopy());
                case ZString.typeid: state.pushstring(*(ZString*)arg.ptr);
                default: 
                    unreachable("lua failed to register unknown arg %d for func %s", i, name);
            }
        }
    }

     // Execute the function with the number of arguments and expected return values
    int r = state.pcall((int)args.len, (rtrn_count >= 0) ? rtrn_count : MULTI_RET, 0);
    if (lua::check(state, r)) 
    {
        // If the function executed successfully, the return value/s are on the stack
        // You can retrieve them as needed
        // For example, if you expect one integer return value:
        if(rtrn_count == 1 && state.isinteger(LUASTACK_TOP)) 
        {
            // Convert the return value to a C3 int
            int returnValue = state.toS32(LUASTACK_RETURN, true); // true means it will pop the value from the stack
            // Use returnValue as needed
            $if $defined(DEBUG):
                log::info(CONSOLE, "lua script engine successfully ran function %s with return value: %d", name, returnValue);
            $endif
        } else if(rtrn_count > 1) {
            // For simplicity, we'll just pop them off the stack here
            state.pop(rtrn_count);
            @todo("Handle multiple return values");
        }
        // Remove the function from the stack
        state.pop(state.gettop());
    }
}

// register C types to lua
<*
    @param name : "name of the global variable in lua"
    @param obj : "the any object to register"
    @param [&in] state : "pointer to the lua state"
*>
fn void registerGlobalType(String name, any obj, LUAState* state = game.lua_state) @inline
{
    // first cheack if stack has space for the global variable
    if(state.checkstack(1) == FALSE) {
        unreachable("lua script engine stack overflow!! cannot push global %s unto stack.", name);
    }

    void* val = obj.ptr;

    // runs only in debug mode
    assert(val != null, "lua script engine failed to register null type: %s", obj);

    switch(obj.type)
    {
        case ichar.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Integer)*(ichar*)val);
        case short.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Integer)*(short*)val);
        case int.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Integer)*(int*)val);
        case char.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Unsigned)*(char*)val);
        case ushort.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Unsigned)*(ushort*)val);
        case uint.typeid:
           (val == null) ? state.pushnil() : state.pushinteger((Unsigned)*(uint*)val);
        case float.typeid:
           (val == null) ? state.pushnil() : state.pushnumber((Number)*(float*)val);
        case double.typeid:
           (val == null) ? state.pushnil() : state.pushnumber(*(Number*)val);
        case String.typeid:
           (val == null) ? state.pushstring("") : state.pushstring((*(String*)val).zstr_tcopy());
        case ZString.typeid:
           (val == null) ? state.pushstring("") : state.pushstring(*(ZString*)val);
        default:
            $if $feature(RELEASE):
                break; // in release mode just ignore unknown types
            $else
                unreachable("lua script engine failed to register type: %s", obj);
            $endif
    }

   state.setglobal(name.zstr_tcopy()); // set it as a global variable
}

alias updateGlobalType = registerGlobalType;
/*
<*
    @param name : "name of the global variable in lua"
    @param obj : "the any object to update"
    @param [&in] state : "pointer to the lua state"
    @require obj.ptr != null
*>
fn void updateGlobalType(String name, any obj, LUAState* state = game.lua_state) @inline
{
    // just call register again it will overwrite the previous value
    registerGlobalType(name, obj, state);
    /*int r = state.getglobal(name.zstr_tcopy());
    if(r != TYPE_NIL) {
        state.pop(1); // remove the previous value from the stack
    } else {
        unreachable("lua script engine failed to update global type %s, variable not found!!", name);
    }

    switch
    {
        case state.isinteger(LUASTACK_TOP):
            state.pushinteger(state.tointeger(LUASTACK_TOP));
        case state.isnumber(LUASTACK_TOP):
            state.pushnumber(state.tonumber(LUASTACK_TOP));
        case state.isstring(LUASTACK_TOP):
            state.pushstring(state.tostring(LUASTACK_TOP));
            self.pop(1);
        default: 
            unreachable("lua script engine failed to update type: %s", obj);
    }*/
}*/

// Convert lua types to C3 types
fn float LUAState.toF32(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isnumber(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a number!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return 0.0f; // return a default value
        }
    $else
        assert(self.isnumber(stack_idx), "lua stack index %d is not a number!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return (float)self.tonumber(stack_idx);
    $endif
}

fn double LUAState.toF64(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isnumber(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a number!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return 0.0; // return a default value
        }
    $else
        assert(self.isnumber(stack_idx), "lua stack index %d is not a number!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return (double)self.tonumber(stack_idx);
    $endif
}

fn int LUAState.toS32(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isinteger(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a integer!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return 0; // return a default value
        }
    $else
        assert(self.isinteger(stack_idx), "lua stack index %d is not a integer!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return (int)self.isinteger(stack_idx);
    $endif
}

fn uint LUAState.toU32(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isinteger(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a integer!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return 0; // return a default value
        }
    $else
        assert(self.isinteger(stack_idx), "lua stack index %d is not a integer!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return (uint)self.isinteger(stack_idx);
    $endif
}

fn short LUAState.toS16(&self, int stack_idx, bool pop = false) @inline
{
    return (short)self.toS32(stack_idx, pop);
}

fn ushort LUAState.toU16(&self, int stack_idx, bool pop = false) @inline
{
    return (ushort)self.toU32(stack_idx, pop);
}

fn char LUAState.toU8(&self, int stack_idx, bool pop = false) @inline
{
    return (char)self.toU32(stack_idx, pop);
}

fn ichar LUAState.toS8(&self, int stack_idx, bool pop = false) @inline
{
    return (ichar)self.toS32(stack_idx, pop);
}

fn String LUAState.toStr(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isstring(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a string!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return ""; // return a default value
        }
    $else
        assert(self.isstring(stack_idx), "lua stack index %d is not a string!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return self.tostring(stack_idx).str_view().tcopy();
    $endif
}

fn ZString LUAState.toZStr(&self, int stack_idx, bool pop = false) @inline
{
    $if $feature(RELEASE):
        if(self.isstring(stack_idx) == FALSE) {
            game.titleMsgBox = "LUA Error Box";
            game.msgBoxText = string::tformat("Lua stack index: '%s' is not a string!!", stackIDXToSTR(stack_idx));
            if(game.showMessageBox) { // a previous message box is being shown
               // do nothing
            } else { // show a new message box
                game.showMessageBox = true;
            }
            return ""; // return a default value
        }
    $else
        assert(self.isstring(stack_idx), "lua stack index %d is not a string!!", stack_idx);
        defer if(pop) self.pop(1); // pop the value from the stack after returning it
        return self.tostring(stack_idx);
    $endif
}
// end of lua script engine


module engine::sys::script_engine::scpt @if($feature(ANGEL_ENABLE));

import std::io;
import thirdparty::angel; // for the message callback
import engine::logging::log;

// for the angel script engine ONLY
fn void messageCallback(SMessageInfo* msg, void * /*obj*/)
{
	switch
    {
	    case msg.type.ordinal == 0: log::error(CONSOLE, "%s (%d, %d) : %s\n", msg.section, msg.row, msg.col, msg.message);
	    case msg.type.ordinal == 1: log::warning(CONSOLE, "%s (%d, %d) : %s\n", msg.section, msg.row, msg.col, msg.message);
	    case msg.type.ordinal == 2: log::info(CONSOLE, "%s (%d, %d) : %s\n", msg.section, msg.row, msg.col, msg.message);
    }
}

fn void asPrint(String fmt, args...) @format(0)
{
    DString str = dstring::temp_with_capacity(fmt.len + args.len * 8);
	str.appendf(fmt, ...args);
    io::printf("%s", str.zstr_view());
}
// end of message callback

module engine::sys::script_engine::scpt @if($feature(WREN_ENABLE));

import std::io;
import std::collections::list;
import thirdparty::wren;
import engine::filesystem::fs;
import engine::logging::log;
import thirdparty::raylib5::rl;
import engine::misc; // misc code
import game::main;
import engine::sys::script_engine::event; // import the event system
import game::actors::ent;
//

//alias VMListPtr = List{WrenVM*};
alias ScriptList = List{Script*};

const SCRIPT_FOLDER_NAME = "scripts";
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
 @param [&in] _sengine : "pointer to the script engine"
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
    ScriptList scripts;
    int next_check_time; // time to check for file changes
    // wren supports multiple virtual machines but I will just use one and instead
    // rely on the virtual machine fivers to run more scripts concunrrently
    //VMListPtr vmachines;  // list of virtual machines
    ScriptVirtualMachine vmachine;
}

fn void ScriptEngine.init(&self)
{
    WrenConfiguration config;
    config.init();

    self.bindFunctions(&config);
    self.createVirtualMachine(&config);
    io::printfn("ScriptEngine initialized");
}

fn void ScriptEngine.deinit(&self)
{
    if(self.scripts.len()) foreach(script : self.scripts) { script.deinit(); };
    self.closeVirtualMachine();
    io::printfn("ScriptEngine deinitialized");
}

fn void ScriptEngine.bindFunctions(&self, WrenConfiguration* config) @inline @local
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
fn WrenVM* ScriptEngine.makeVM(&self, WrenConfiguration* config) @inline @local
{
    return config.newVM();
}

fn void ScriptEngine.createVirtualMachine(&self, WrenConfiguration* config) @inline @local
{
    if(config == null) unreachable("Script Engine fatal error failed to create virtual machine!!");

    self.vmachine.init();
    self.vmachine.create(self, config);
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
                        lgr::info(Where.FILE, "Reloaded script %s", script.name);
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
fn void ScriptEngine.fileWatcher(&self)
{
    if(main::developer.getBool() == false) return; // only in developer mode
    
    if(main::gpGame.time_ms >= self.next_check_time)
    {
        self.next_check_time = main::gpGame.time_ms + 1000; // check every second
    } else { return; }

    if(self.scripts.len())
    {
        foreach(script : self.scripts)
        { 
            CLong file_mod_time = fs::getFileModTime(script.path);
            bool changed = file_mod_time != script.modtime;
            if(changed) // reload script
            {
                script.data = fs::fileLoadEntireText(script.path).zstr_tcopy();
                script.modtime = file_mod_time;
                lgr::info(Where.FILE, "Reloaded script %s", script.name);
            }
        };
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
        lgr::warning(Where.FILE, "Script Virtual Machine failed to run script, script is null or empty!!");
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
    lgr::error(Where.FILE, "Failed to bind foreign method %s.%s with signature %s", module_name, class_name, fn_signature);
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