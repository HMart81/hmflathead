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
* This are C3 bindings for the umka script language (1.5.4). 
* To know more about it, see: https://github.com/vtereshkov/umka-lang/blob/master/examples/3dcam/3dcam.c#L57
*
* NOTE(HM): 
*   structs in this file, passed by pointer, can be just alias to a void* (opaque pointer) and be done with it! 
*   The reality is, you don't need to know the full data-layout for most of them to use this... 
*   (but don't try storing the structs by value after that...)
****************************************************************/
module umkadyarr @private @if($feature(UMKA_ENABLE));

struct DynArray <Type> @if($feature(UMKA_ENABLE))                                                      
{
  void* internal;
  long itemSize;
  Type* data;
}

module thirdparty::scripting::umka @if($feature(UMKA_ENABLE));

import std::io;
import engine::logging::log;
import libc;
import umkadyarr @public;

//import buffer @public;

const VERSION_MAJOR   = "1";
const VERSION_MINOR   = "5";
const VERSION_RELEASE = "4";

const VERSION_NUM = 154;
macro version() => VERSION_NUM;

// A human-friendly string representation of the version.
const VERSION_STR =	"umka " +++ VERSION_MAJOR +++ "." +++ VERSION_MINOR;
const RELEASE =	VERSION_STR +++ "." +++ VERSION_RELEASE;
const COPYRIGHT =	RELEASE +++ "  Copyright (c) 2020-2025, Vasiliy Tereshkov";
const AUTHORS =	"Vasiliy Tereshkov";

// types
alias UmkaInt     = long;
alias UmkaUint    = ulong;
alias UmkaReal32  = float;
alias UmkaReal    = double;
alias UmkaVoid    = void;

// opaque pointer
alias Umka = UmkaVoid*;

union UmkaStackSlot
{
  UmkaInt    intVal;
  UmkaUint   uintVal;
  UmkaVoid*  ptrVal;
  UmkaReal   realVal;
  UmkaReal32 real32Val;
}

struct UmkaFuncContext
{
  UmkaInt entryOffset;
  UmkaStackSlot *params;
  UmkaStackSlot *result;
}

alias ExternFuncCallback = fn void(UmkaStackSlot *params, UmkaStackSlot *result);

enum UmkaHookEvent : const int
{
  UMKA_HOOK_CALL,
  UMKA_HOOK_RETURN,
}

alias HookFuncCallback = fn void(ZString fileName, ZString funcName, int line);

struct UmkaMap
{
  void *internal1;
  void *internal2;
}

struct UmkaAny
{
  void *data;
  void *type;
}

struct UmkaClosure
{
  UmkaInt entryOffset;
  UmkaAny upvalue;
}

struct UmkaError
{
  ZString fileName;
  ZString fnName;
  int line, pos, code;
  ZString msg;
}

alias WarningCallback = fn void(UmkaError *warning);

fn void umkaWarning(UmkaError *warning) @local {
  io::printfn("UMKA: Warning from script: %s \n\t-> %s:%d::%d -> %s", warning.fileName, warning.fnName, warning.line, warning.pos, warning.msg);
}

struct UmkaAPI
{
  AllocCallback           umkaAlloc;
  InitCallback            umkaInit;
  CompileCallback         umkaCompile;
  RunCallback             umkaRun;
  CallCallback            umkaCall;
  FreeCallback            umkaFree;
  GetErrorCallback        umkaGetError;
  AliveCallback           umkaAlive;
  AsmCallback             umkaAsm;
  AddModuleCallback       umkaAddModule;
  AddFuncCallback         umkaAddFunc;
  GetFuncCallback         umkaGetFunc;
  GetCallStackCallback    umkaGetCallStack;
  SetHookCallback         umkaSetHook;
  AllocDataCallback       umkaAllocData;
  IncRefCallback          umkaIncRef;
  DecRefCallback          umkaDecRef;
  GetMapItemCallback      umkaGetMapItem;
  MakeStrCallback         umkaMakeStr;
  GetStrLenCallback       umkaGetStrLen;
  MakeDynArrayCallback    umkaMakeDynArray;
  GetDynArrayLenCallback  umkaGetDynArrayLen;
  GetVersionCallback      umkaGetVersion;
  GetMemUsageCallback     umkaGetMemUsage;
  MakeFuncContextCallback umkaMakeFuncContext;
  GetParamCallback        umkaGetParam;
  GetUpvalueCallback      umkaGetUpvalue;
  GetResultCallback       umkaGetResult;
  GetMetadataCallback     umkaGetMetadata;
  SetMetadataCallback     umkaSetMetadata;
}

alias AllocCallback           = fn void*();
alias InitCallback            = fn bool(void *umka, ZString fileName, ZString sourceString, int stackSize, void *reserved, int argc, ZString*argv, bool fileSystemEnabled, bool implLibsEnabled, WarningCallback warningCallback);
alias CompileCallback         = fn bool(void *umka);
alias RunCallback             = fn int(void *umka);
alias CallCallback            = fn int(void *umka, UmkaFuncContext *func);
alias FreeCallback            = fn void(void *umka);
alias GetErrorCallback        = fn UmkaError*(void *umka);
alias AliveCallback           = fn bool(void *umka);
alias AsmCallback             = fn ZString (void *umka);
alias AddModuleCallback       = fn bool(void *umka, ZString fileName, ZString sourceString);
alias AddFuncCallback         = fn bool(void *umka, ZString name, ExternFuncCallback func);
alias GetFuncCallback         = fn bool(void *umka, ZString moduleName, ZString fnName, UmkaFuncContext *func);
alias GetCallStackCallback    = fn bool(void *umka, int depth, int nameSize, int *offset, ZString fileName, ZString fnName, int *line);
alias SetHookCallback         = fn void(void *umka, UmkaHookEvent event, HookFuncCallback hook);
alias AllocDataCallback       = fn void*(void *umka, int size, ExternFuncCallback onFree);
alias IncRefCallback          = fn void(void *umka, void *ptr);
alias DecRefCallback          = fn void(void *umka, void *ptr);
alias GetMapItemCallback      = fn void *(void *umka, UmkaMap *map, UmkaStackSlot key);
alias MakeStrCallback         = fn ZString(void *umka, ZString str);
alias GetStrLenCallback       = fn int(ZString str);
alias MakeDynArrayCallback    = fn void(void *umka, void *array, void *type, int len);
alias GetDynArrayLenCallback  = fn int(void *array);
alias GetVersionCallback      = fn ZString();
alias GetMemUsageCallback     = fn long(void *umka);
alias MakeFuncContextCallback = fn void(void *umka, void *closureType, int entryOffset, UmkaFuncContext *func);
alias GetParamCallback        = fn UmkaStackSlot *(UmkaStackSlot *params, int index);
alias GetUpvalueCallback      = fn UmkaAny *(UmkaStackSlot *params);
alias GetResultCallback       = fn UmkaStackSlot *(UmkaStackSlot *params, UmkaStackSlot *result);
alias GetMetadataCallback     = fn void*(void *umka);
alias SetMetadataCallback     = fn void(void *umka, void *metadata);

faultdef INIT_FAILED, 
         COMPILE_FAILED;

extern fn Umka alloc() @cname("umkaAlloc");
extern fn bool Umka._init(&self, ZString fileName, ZString sourceString, int stackSize, void *reserved, int argc, ZString *argv, bool fileSystemEnabled, bool implLibsEnabled, WarningCallback warningCallback = &umkaWarning) @cname("umkaInit");

struct UmkaScriptInitData 
{
    ZString fileName; 
    ZString sourceString; 
    int stackSize; 
    void *reserved; // always null?
    int argc; 
    ZString *argv; 
    bool fileSystemEnabled; 
    bool implLibsEnabled;
}

fn bool? Umka.init(&self, UmkaScriptInitData* inidata) 
{
  bool ok = self._init(inidata.fileName, 
                       inidata.sourceString, 
                       inidata.stackSize, 
                       inidata.reserved, 
                       inidata.argc, inidata.argv, 
                       inidata.fileSystemEnabled, 
                       inidata.implLibsEnabled);
  if(ok) return ok; 

  return INIT_FAILED~;
}

extern fn bool Umka._compile(&self) @local @cname("umkaCompile");
macro bool? Umka.compile(&self) {
  if(self._compile()) return true;
  return COMPILE_FAILED~;
}
extern fn int  Umka.run(&self) @cname("umkaRun");
extern fn int  Umka.call(&self, UmkaFuncContext *func) @cname("umkaCall");
extern fn void Umka.free(&self) @cname("umkaFree");
extern fn UmkaError* Umka.getError(&self) @cname("umkaGetError");
extern fn bool Umka.alive(&self) @cname("umkaAlive");
extern fn ZString Umka.assembly(&self) @cname("umkaAsm");
extern fn bool Umka.addModule(&self, ZString fileName, ZString sourceString) @cname("umkaAddModule");
extern fn bool Umka.addFunc(&self, ZString name, ExternFuncCallback func) @cname("umkaAddFunc");
extern fn bool Umka.getFunc(&self, ZString moduleName, ZString fnName, UmkaFuncContext *func) @cname("umkaGetFunc");
extern fn bool Umka.getCallStack(&self, int depth, int nameSize, int *offset, ZString fileName, ZString fnName, int *line) @cname("umkaGetCallStack");
extern fn void Umka.setHook(&self, UmkaHookEvent event, HookFuncCallback hook) @cname("umkaSetHook");
extern fn void* Umka.allocData(&self, int size, ExternFuncCallback onFree) @cname("umkaAllocData");
extern fn void Umka.incRef(&self, void *ptr) @cname("umkaIncRef");
extern fn void Umka.decRef(&self, void *ptr) @cname("umkaDecRef");
extern fn void* Umka.getMapItem(&self, UmkaMap *map, UmkaStackSlot key) @cname("umkaGetMapItem");
extern fn ZString Umka.makeStr(&self, ZString str) @cname("umkaMakeStr");
extern fn int getStrLen(ZString str) @cname("umkaGetStrLen");
extern fn void Umka.makeDynArray(&self, void *array, void *type, int len) @cname("umkaMakeDynArray");
extern fn int getDynArrayLen(void *array) @cname("umkaGetDynArrayLen");
extern fn ZString getVersion() @cname("umkaGetVersion");
extern fn long Umka.getMemUsage(&self) @cname("umkaGetMemUsage");
extern fn void Umka.makeFuncContext(&self, void *closureType, int entryOffset, UmkaFuncContext *func) @cname("umkaMakeFuncContext");
extern fn UmkaStackSlot* getParam(UmkaStackSlot *params, int index) @cname("umkaGetParam");
extern fn UmkaAny* getUpvalue(UmkaStackSlot *params) @cname("umkaGetUpvalue");
extern fn UmkaStackSlot* getResult(UmkaStackSlot *params, UmkaStackSlot *result) @cname("umkaGetResult");
extern fn void* Umka.getMetadata(&self) @cname("umkaGetMetadata");
extern fn void Umka.setMetadata(&self, void *metadata) @cname("umkaSetMetadata");

fn UmkaAPI* Umka.getAPI(&self) @inline => (UmkaAPI*)self;

/*fn UmkaAPI* Umka.getAPI(&self) @inline {
  UmkaAPI* result = mem::new(UmkaAPI);

  result.umkaAlloc = umka::alloc;
  result.umkaInit = self.init;
  result.umkaCompile = self.compile;
  result.umkaRun = self.run;
  result.umkaCall = self.call;
  result.umkaFree = self.free;
  result.umkaGetError = self.getError;
  result.umkaAlive = self.alive;
  result.umkaAsm = self.asm;
  result.umkaAddModule = self.addModule;
  result.umkaAddFunc = self.addFunc;
  result.umkaGetFunc = self.getFunc;
  result.umkaGetCallStack = self.getCallStack;
  result.umkaSetHook = self.setHook;
  result.umkaAllocData = self.allocData;
  result.umkaIncRef = self.incRef;
  result.umkaDecRef = self.decRef;
  result.umkaGetMapItem = self.getMapItem;
  result.umkaMakeStr = self.makeStr;
  result.umkaGetStrLen = self.getStrLen;
  result.umkaMakeDynArray = self.makeDynArray;
  result.umkaGetDynArrayLen = self.getDynArrayLen;
  result.umkaGetVersion = self.getVersion;
  result.umkaGetMemUsage = self.getMemUsage;
  result.umkaMakeFuncContext = self.makeFuncContext;
  result.umkaGetParam = self.getParam;
  result.umkaGetUpvalue = self.getupvalue;
  result.umkaGetResult = self.getResult;
  result.umkaGetMetadata = self.getMetadata;
  result.umkaSetMetadata = self.setMetadata;

  return result;
}*/

fn void* getInstance(UmkaStackSlot *result) @inline {
  return result.ptrVal;
}
