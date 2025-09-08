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

// WARNING: This file is a work in progress and may not be fully functional yet.

/***************************************************************
* This is C3 implementation code for the micro java script language (mujs). 
****************************************************************/

module thirdparty::mujs @if($feature(MUJS_ENABLE));

import std::io;
import engine::logging::log;
import game::main;

fn int State.initStdLib(&self)
{
  self.bindFunction(&bindPrint, "print", 1);
  self.bindFunction(&bindPrintToFile, "printTofile", 1);
  self.atpanic(&State.panic);
  self.setreport(&State.report);

  int result = self.dostring(MUJS_STDLIB);
  assert(result == 0, "Failed to initialize mujs stdlib");
  return result;
}

<*
  @param [&in] state : "The mujs state"
*>
fn void bindPrint(State* state) @local
{
  int top = state.gettop();
  for(int i = 1; i < top; i++)
  {
    ZString s = state.tostring(i);
    if(i > 1) io::printf(" "); // separate multiple args with spaces
    io::printfn("%s", s);
  }
  state.pushundefined();
}

<*
  @param [&in] state : "The mujs state"
*>
fn void bindPrintToFile(State* state) @local
{
  int top = state.gettop();
  for(int i = 1; i < top; i++)
  {
    ZString s = state.tostring(i);
    if(i > 1) io::printf(" "); // separate multiple args with spaces
    //io::printfn("%s", s);
    log::info(Where.FILE, "%s", s);
  }
  state.pushundefined();
}

fn void State.panic(&self) @local
{
  ZString msg = self.tostring(-1);
  unreachable("mujs panic: %s", msg);
  //log::error(Where.FILE, "mujs panic: %s", msg);
  // Handle panic appropriately, e.g., log the error, clean up resources, etc.
  // For this example, we'll just exit the program.
 // exit(1);
}

fn void State.report(&self, ZString message) @local
{
  log::warning(Where.FILE, "mujs report: %s", message);
}
//

<*
  Calls a function in the mujs state by name, with optional arguments.
  @param [in] func_name : "The name of the function to call"
  @param fl : "Flags to indicate if the function is global or in a specific object (ISGLOBAL or ISNOTGLOBAL)"
  @param [in] args : "Optional arguments to pass to the function"
  @require fl == ISGLOBAL || fl == ISLOCAL || fl == ISMENBER
*>
fn void State.runFunction(&self, String func_name, int fl, args...) 
{
  if(fl == ISGLOBAL) {
    self.getglobal(func_name.zstr_tcopy()); // get named global function
  }
  // if not global, get it from the subtop object
  else { self.getproperty(STACK_IDX_SUBTOP, func_name.zstr_tcopy()); }
  //
  int stack_top_val = self.gettop();
  if(stack_top_val < STACK_IDX_ARG1 || self.toboolean(STACK_IDX_TOP) == 0 || self.type(STACK_IDX_TOP) != ISFUNCTION) {
    unreachable("Function %s not found in mujs state", func_name);
  }

  self.pushnull(); // push the 'this' object to use

  int arg_count;
  if(args) arg_count = args.len;

  // push function arguments unto the stack if any
  if(arg_count) 
  {
    double val;
    int i = 1;
    foreach(any arg: args) 
    {
      switch(arg.type) 
      {
        case void.typeid: 
          self.pushnull();
        case int.typeid:
          val = (double)*(int*)arg.ptr;
          self.pushnumber(val);
        case uint.typeid:
          val = (double)*(uint*)arg.ptr;
          self.pushnumber(val);
        case float.typeid:
          val = (double)*(float*)arg.ptr;
          self.pushnumber(val);
        case double.typeid:
          val = *(double*)arg.ptr;
          self.pushnumber(val);
        case bool.typeid: 
          (*(bool*)arg.ptr) ? self.pushboolean(1) : self.pushboolean(0);
        case String.typeid: 
          self.pushstring((*(String*)arg.ptr).zstr_tcopy());
        case ZString.typeid: 
          self.pushstring(*(ZString*)arg.ptr);
        default: unreachable("Function %s argument has unsupported type", func_name);
      }
      i++;
    }
  }
  //
  String result; 
  if(self.pcall(arg_count) != 0) 
  {
    result = self.tostring(STACK_IDX_RETURN).str_view();
    self.pop(1); // pop only function
    unreachable("Failed to execute script function '%s' with excuse: %s", func_name, result);
  } 
  else if(main::developer.getBool()) 
  {
    result = self.tostring(STACK_IDX_RETURN).str_view();
    io::printfn("Script function '%s' executed successfully with return value: %s", func_name, result);
  }
  self.pop(1); // pop function + args
}