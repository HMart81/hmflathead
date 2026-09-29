module engine::sys::framework::platform::platf;

import std::io, std::os;

/*
===============================================================================

	Non-portable system services.

===============================================================================
*/

const PATHSEPERATOR_STR	 @if(env::WIN32) = "\\";
const PATHSEPERATOR_CHAR @if(env::WIN32) = '\\';
const PATHSEPERATOR_STR	 @if(env::POSIX) = "/";
const PATHSEPERATOR_CHAR @if(env::POSIX) = '/';

const NULL @if(!$defined(NULL)) = ((void *)0);
macro int @bit($num) @if(!$defined(@bit)) => ( 1 << $num );

const MAX_STRING_CHARS = 1024; // max length of a string
const MAX_PATH_CHARS @if(env::WIN32) = 260;	   // max length of a path including drive letter
const MAX_PATH_CHARS @if(env::POSIX) = 4096;   // max length of a path

// maximum world size
const MAX_WORLD_COORD = ( 128 * 1024 );
const MIN_WORLD_COORD = ( -128 * 1024 );
const MAX_WORLD_SIZE  = ( MAX_WORLD_COORD - MIN_WORLD_COORD );




//////////////////////////////////////////////////////////////////////
//--------------------------------------------------------
module engine::platform::win32 @if(env::WIN32);

import std::io;
import std::os::env, std::os::win32;
import engine::logging::log;
import engine::misc;
import engine::sys::framework::platform::platf;

enum HResult : int (Win32_HRESULT val, String disc) @local {
    S_OK           {(Win32_HRESULT)0x00000000, "Operation successful"},
    E_ABORT        {(Win32_HRESULT)0x80004004, "Operation aborted"},
    E_ACCESSDENIED {(Win32_HRESULT)0x80070005, "General access denied error"},
    E_FAIL         {(Win32_HRESULT)0x80004005, "Unspecified failure"},
    E_HANDLE       {(Win32_HRESULT)0x80070006, "Handle that is not valid"},
    E_INVALIDARG   {(Win32_HRESULT)0x80070057, "One or more arguments are not valid"},
    E_NOINTERFACE  {(Win32_HRESULT)0x80004002, "No such interface supported"},
    E_NOTIMPL      {(Win32_HRESULT)0x80004001, "Not implemented"},
    E_OUTOFMEMORY  {(Win32_HRESULT)0x8007000E, "Failed to allocate necessary memory"},
    E_POINTER      {(Win32_HRESULT)0x80004003, "Pointer that is not valid"},
    E_UNEXPECTED   {(Win32_HRESULT)0x8000FFFF, "Unexpected failure"}
}

const Win32_DWORD KNOWN_FOLDER_FLAG_DEFAULT                          @local = 0x00000000;
const Win32_DWORD KNOWN_FOLDER_FLAG_FORCE_APP_DATA_REDIRECTION       @local = 0x00080000;
const Win32_DWORD KNOWN_FOLDER_FLAG_RETURN_FILTER_REDIRECTION_TARGET @local = 0x00040000;
const Win32_DWORD KNOWN_FOLDER_FLAG_FORCE_PACKAGE_REDIRECTION        @local = 0x00020000;
const Win32_DWORD KNOWN_FOLDER_FLAG_NO_PACKAGE_REDIRECTION           @local = 0x00010000;
const Win32_DWORD KNOWN_FOLDER_FLAG_FORCE_APPCONTAINER_REDIRECTION   @local = 0x00020000;
const Win32_DWORD KNOWN_FOLDER_FLAG_NO_APPCONTAINER_REDIRECTION      @local = 0x00010000;
const Win32_DWORD KNOWN_FOLDER_FLAG_CREATE                           @local = 0x00008000;
const Win32_DWORD KNOWN_FOLDER_FLAG_DONT_VERIFY                      @local = 0x00004000;
const Win32_DWORD KNOWN_FOLDER_FLAG_DONT_UNEXPAND                    @local = 0x00002000;
const Win32_DWORD KNOWN_FOLDER_FLAG_NO_ALIAS                         @local = 0x00001000;
const Win32_DWORD KNOWN_FOLDER_FLAG_INIT                             @local = 0x00000800;
const Win32_DWORD KNOWN_FOLDER_FLAG_DEFAULT_PATH                     @local = 0x00000400;
const Win32_DWORD KNOWN_FOLDER_FLAG_NOT_PARENT_RELATIVE              @local = 0x00000200;
const Win32_DWORD KNOWN_FOLDER_FLAG_SIMPLE_IDLIST                    @local = 0x00000100;
const Win32_DWORD KNOWN_FOLDER_FLAG_ALIAS_ONLY                       @local = 0x80000000;


struct OSversionInfo (Printable) 
{
  Win32_ULONG dwOSVersionInfoSize;
  Win32_ULONG dwMajorVersion;
  Win32_ULONG dwMinorVersion;
  Win32_ULONG dwBuildNumber;
  Win32_ULONG dwPlatformId;
  Win32_WCHAR[128] szCSDVersion;
}
alias OSversionInfoPrt = OSversionInfo*;

fn String OSversionInfo.to_constant_string(&self) @dynamic
{
    return string::format(tmem, "%s", *self);
}

//--------------------------------------------------------

//const Win32_KNOWNFOLDERID  HOME_FOLDER = {0x4c5c32ff, 0xbb9d, 0x43b0, {0xb5, 0xb4, 0x2d, 0x72, 0xe5, 0x4e, 0xaa, 0xa4}};
// NOTE(HM): I made this before realizing that shGetKnownFolderPath was already defined in std file shell32.c3 win32 module
// i'm letting this stay because it works in a tad different way (using our own HResult enum type)
extern fn HResult getKnownFolderPath(Win32_KNOWNFOLDERID rfid, Win32_DWORD dwFlags, Win32_HANDLE hToken /*null*/, Win32_PWSTR *ppszPath /*out*/) @cname("SHGetKnownFolderPath") @if(env::WIN32);

//extern fn bool isWindowsVistaOrGreater() @cname("IsWindowsVistaOrGreater");
extern fn int getVersion(OSversionInfoPrt lpVersionInformation) @cname("RtlGetVersion");
extern fn int copyFileA( Win32_LPCSTR lpExistingFileName, Win32_LPCSTR lpNewFileName, Win32_BOOL bFailIfExists ) @cname("CopyFileA");
// end_region WIN32 (Windows)

extern fn Win32_DWORD_PTR setThreadAffinityMask( Win32_HANDLE hThread, Win32_DWORD_PTR dwThreadAffinityMask) @cname("SetThreadAffinityMask");

extern fn Win32_BOOL setProcessWorkingSetSize( Win32_HANDLE hProcess, Win32_SSIZE_T dwMinimumWorkingSetSize, Win32_SSIZE_T dwMaximumWorkingSetSize ) @cname("SetProcessWorkingSetSize");
macro setPhysicalWorkMemory( int minBytes, int maxBytes ) => setProcessWorkingSetSize( win32::getCurrentProcess(), minBytes, maxBytes );

// does not work for some reason
//extern fn Win32_BOOL getSystemRAM( Win32_PULONGLONG totalMemoryInKilobytes ) @cname("GetPhysicallyInstalledSystemMemory");

extern fn Win32_BOOL globalMemoryStatusEx( MemoryStatus* memstatus ) @cname("GlobalMemoryStatusEx");

struct MemoryStatus @local
{
  Win32_DWORD     dwLength;
  Win32_DWORD     dwMemoryLoad;
  Win32_DWORDLONG ullTotalPhys;
  Win32_DWORDLONG ullAvailPhys;
  Win32_DWORDLONG ullTotalPageFile;
  Win32_DWORDLONG ullAvailPageFile;
  Win32_DWORDLONG ullTotalVirtual;
  Win32_DWORDLONG ullAvailVirtual;
  Win32_DWORDLONG ullAvailExtendedVirtual;
}

/*
================
getSystemRAM - returns amount of physical memory in MB
================
*/
fn int getSystemRAM() 
{
	MemoryStatus statex;
	statex.dwLength = MemoryStatus::size;
	globalMemoryStatusEx(&statex);
	int physRam = (int)(statex.ullTotalPhys / ( 1024 * 1024 ));
	// HACK: For some reason, ullTotalPhys is sometimes off by a meg or two, so we round up to the nearest 16 megs
	physRam = ( physRam + 8 ) & ~15;
	return physRam;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Win32 registry constants and types
// These constants and types are used for Windows registry operations.
const HKEY_CURRENT_USER  = (( Win32_HKEY ) (ulong)((long)0x80000001));
const HKEY_LOCAL_MACHINE = (( Win32_HKEY ) (ulong)((long)0x80000002));

const Win32_DWORD REG_OPTION_NON_VOLATILE   = 0x00000000L;  // default option for registry keys
const Win32_DWORD REG_OPTION_VOLATILE       = 0x00000001L;  // option for volatile registry keys
const Win32_DWORD REG_OPTION_CREATE_LINK    = 0x00000002L;  // option for creating symbolic links in registry (Registry symbolic links should only be used for application compatibility when absolutely necessary.)
const Win32_DWORD REG_OPTION_BACKUP_RESTORE = 0x00000004L;

const Win32_DWORD STANDARD_RIGHTS_WRITE   = 0x00020000;
const Win32_DWORD STANDARD_RIGHTS_READ    = STANDARD_RIGHTS_WRITE;
const Win32_UINT16 KEY_SET_VALUE          = 0x0002;
const Win32_UINT16 KEY_QUERY_VALUE        = 0x0001;      // allows querying of values in the key
const Win32_UINT16 KEY_CREATE_SUB_KEY     = 0x0004;
const Win32_UINT16 KEY_ENUMERATE_SUB_KEYS = 0x0008;      // allows enumeration of subkeys
const Win32_UINT16 KEY_NOTIFY             = 0x0010;      // allows notification of changes to the key
const Win32_DWORD KEY_READ  = STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY;  // read access to registry keys
const Win32_DWORD KEY_WRITE = STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY;  // write access

const Win32_LPDWORD REG_CREATED_NEW_KEY     = &&0x00000001L;  // registry key was created
const Win32_LPDWORD REG_OPENED_EXISTING_KEY = &&0x00000002L;  // registry key already existed

// stupid Microsoft Monkeys, 
// who the hell put the error word in a sucess code!
const Win32_INT64 ERROR_SUCCESS = 0x00000000_00000000;  // success code for registry operations
//
alias Win32_LSTATUS = Win32_INT64; // alias for registry status codes

alias Reg_SAM = Win32_DWORD; // registry security access mask type
const Reg_SAM KEY_WOW64_32KEY = 0x0200;
const Reg_SAM KEY_WOW64_64KEY = 0x0100;

const Win32_DWORD32 REG_NONE          = 0x00000000;  // registry value type for no data
const Win32_DWORD32 REG_SZ            = 0x00000001;  // registry value type for null-terminated string
const Win32_DWORD32 REG_EXPAND_SZ     = 0x00000002;  // registry value type for expandable string
const Win32_DWORD32 REG_BINARY        = 0x00000003;  // registry value type for binary data
const Win32_DWORD32 REG_DWORD         = 0x00000004;  // registry value type for DWORD (32-bit unsigned integer)
const Win32_DWORD32 REG_MULTI_SZ      = 0x00000007;  // registry value type for multiple null-terminated strings
const Win32_DWORD32 REG_RESOURCE_LIST = 0x00000008;  // registry value type for resource list   
const Win32_DWORD64 REG_QWORD         = 0x0000000b;  // registry value type for QWORD (64-bit unsigned integer)

faultdef ERROR_REGISTRY_KEY_CREATION_FAILED,
         ERROR_REGISTRY_KEY_OPEN_FAILED,
         ERROR_REGISTRY_KEY_SET_VALUE_FAILED,
         ERROR_REGISTRY_KEY_CLOSING_FAILED,
         ERROR_SPECIAL_PATH_QUERY_FAILED,
         ERROR_UNSUPPORTED_WINDOWS_OS;


/*
LSTATUS RegOpenCurrentUser(
  [in]  REGSAM samDesired,
  [out] PHKEY  phkResult
);
*/
extern fn Win32_LSTATUS regOpenCurrentUserEx(Reg_SAM desired, Win32_PHKEY result) @cname("RegOpenCurrentUser");
fn Win32_HKEY? regOpenCurrentUser(Reg_SAM desired) 
{
    Win32_HKEY result;
    // Attempt to open the current user registry key with the specified access rights
    Win32_LSTATUS status = regOpenCurrentUserEx(desired, &result);
    if (status == ERROR_SUCCESS) {
        return result; // Return the opened registry key handle (call regCloseKey to close it later)
    }
    return ERROR_REGISTRY_KEY_OPEN_FAILED~; // or handle the error as needed
}

/*
LSTATUS RegOpenKeyExA(
  [in]           HKEY   hKey,
  [in, optional] LPCSTR lpSubKey,
  [in]           DWORD  ulOptions,
  [in]           REGSAM samDesired,
  [out]          PHKEY  phkResult
);
*/
extern fn Win32_LSTATUS regOpenKeyExA(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_DWORD options, Reg_SAM desired, Win32_PHKEY result) @local @cname("RegOpenKeyExA");
<*
    Opens a windows register key using the sub_key
    @param [&in] keyroot : "a pointer to the root key. ex: HKEY_CURRENT_USER, get it with regOpenCurrentUser()"
    @param [in] sub_key : "the path key to open, Key names are not case sensitive"
    @param desired : "flags to say what to do with the key and what type it is, like if 32 or 64 bits"
*>
fn Win32_HKEY? regOpenKey(Win32_HKEY keyroot, String sub_key, Reg_SAM desired) 
{
    Win32_HKEY outkey;
    // Attempt to open the specified registry key with the given access rights
    Win32_LSTATUS status = regOpenKeyExA(keyroot, (Win32_LPCSTR)sub_key.zstr_tcopy(), 0, desired | KEY_WOW64_64KEY, &outkey);
    if (status == ERROR_SUCCESS) {
        return outkey; // Return the opened registry key handle (call regCloseKey to close it later)
    }
    return ERROR_REGISTRY_KEY_OPEN_FAILED~; // or handle the error as needed
}

/*
LSTATUS RegRenameKey(
  HKEY    hKey,
  LPCWSTR lpSubKeyName,
  LPCWSTR lpNewKeyName
);
*/
extern fn Win32_LSTATUS regRenameKey(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_LPCSTR new_name) @cname("RegRenameKey");

/*
LSTATUS RegCreateKeyExA(
  [in]            HKEY                        hKey,
  [in]            LPCSTR                      lpSubKey,
                  DWORD                       Reserved,
  [in, optional]  LPSTR                       lpClass,
  [in]            DWORD                       dwOptions,
  [in]            REGSAM                      samDesired,
  [in, optional]  const LPSECURITY_ATTRIBUTES lpSecurityAttributes,
  [out]           PHKEY                       phkResult,
  [out, optional] LPDWORD                     lpdwDisposition
);
*/
extern fn Win32_LSTATUS regCreateKeyEx(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_DWORD reserve, Win32_LPSTR class, 
                       Win32_DWORD options, Reg_SAM desired, Win32_LPSECURITY_ATTRIBUTES securityAttributes,
                       Win32_PHKEY result, Win32_LPDWORD disposition) @local @cname("RegCreateKeyExA");

fn bool? regCreateKey(Win32_HKEY key, String sub_key, Win32_DWORD options, 
					  Reg_SAM desired, Win32_PHKEY result, Win32_LPDWORD disposition = null, 
					  Win32_LPSECURITY_ATTRIBUTES securityAttributes = null)
{
    // remove start and end trailing slashs for paths 
    // aparently those are not supported!
    if(sub_key.starts_with(platf::PATHSEPERATOR_STR)) sub_key = sub_key.strip_start(platf::PATHSEPERATOR_STR);
    if(sub_key.ends_with(platf::PATHSEPERATOR_STR)) sub_key = sub_key.strip_end(platf::PATHSEPERATOR_STR);
    Win32_LSTATUS status = regCreateKeyEx(key, (Win32_LPCSTR)sub_key.zstr_tcopy(), 0, null, options, desired, securityAttributes, result, disposition);
    if (status == ERROR_SUCCESS) {
        return true;
    }

    return ERROR_REGISTRY_KEY_CREATION_FAILED~; // or handle the error as needed
}

/*LSTATUS RegSetValueExA(
  [in]           HKEY       hKey,        // a handle to an open registry key. The key must have been opened with the KEY_SET_VALUE access right.
  [in, optional] LPCSTR     lpValueName,   // if is NULL or an empty string, "", the function sets the type and data for the key's unnamed or default
                 DWORD      Reserved, // a reserved parameter, must be zero
  [in]           DWORD      dwType,   // the type of data to be stored in the registry value. This parameter can be one of the following values:
                                     // REG_NONE, REG_SZ, REG_EXPAND_SZ, REG_BINARY, REG_DWORD, REG_QWORD, REG_MULTI_SZ, REG_RESOURCE_LIST, REG_FULL_RESOURCE_DESCRIPTOR, REG_RESOURCE_REQUIREMENTS_LIST
                                     // Note: The function does not check the type of data being set. It is the caller's responsibility to ensure that the data matches the specified type.
  [in]           const BYTE *lpData, // For string-based types, such as REG_SZ, the string must be null-terminated. With the REG_MULTI_SZ data type, the string must be terminated with two null characters.
                                     // Note  lpData indicating a null value is valid, however, if this is the case, cbData must be set to '0'.
  [in]           DWORD      cbData
);*/
extern fn Win32_LSTATUS regSetValueExA(Win32_HKEY key, Win32_LPCSTR valueName, Win32_DWORD reserved, Win32_DWORD type,
                                Win32_BYTE *data, Win32_DWORD data_size) @cname("RegSetValueExA");
fn Win32_LSTATUS regSetValue(Win32_HKEY key, String valueName, any value)
{
    var value_name @safeinfer = (Win32_LPCSTR)valueName.zstr_tcopy();
    switch(value.type)
    {
        case Win32_DWORD:
            return regSetValueExA(key, value_name, 0, REG_DWORD, (Win32_BYTE*)value.ptr, Win32_DWORD::size);
        case Win32_QWORD:
            return regSetValueExA(key, value_name, 0, REG_QWORD, (Win32_BYTE*)value.ptr, Win32_QWORD::size);
        case String:
            var str @safeinfer = (String*)value.ptr;
            return regSetValueExA(key, value_name, 0, REG_SZ, (Win32_BYTE*)(*str), (Win32_DWORD)str.len);
        default:
        {
            win32::regCloseKey(key);
            unreachable();
        }
    }
}

/*
    examples
    /*if(!win32::regSetValue(k, "language", any_make(&local_game.langdict.type, String.typeid))) {
        log::warning(FILE, "failed to write language type to registry.");
    } else {win32::regCloseKey(k);}*/

    // function itself
	String reg_SZ = "TestSZ";
    String reg_DWord = "testdword";
    int dw = 420;
    String reg_data = "hello world";
    Win32_LSTATUS sucess = win32::regSetValue(folder_key, reg_DWord, any_make(&dw, Win32_DWORD.typeid));
    if( sucess  != win32::ERROR_SUCCESS ) {
        unreachable();
    }
    Win32_LSTATUS sucess = win32::regSetValue(folder_key, "baseDir", any_make(&local_game.app_base_folder, String.typeid));
    if( sucess != win32::ERROR_SUCCESS ) {
        unreachable();
    }
    // macro version
    @catch(key.setValue("baseDir", &local_game.app_base_folder, String.typeid));
    Don't forget to close the key after using it!
*/
fn bool? Win32_HKEY.setValue(self, String valueName, void* data, typeid type, bool close_key = false)
{
    if(win32::regSetValue(self, valueName, any_make(data, type)) == win32::ERROR_SUCCESS ) {
        if(close_key) regCloseKey(self);
        return true;
    }
    return ERROR_REGISTRY_KEY_SET_VALUE_FAILED~;
}

macro Win32_HKEY? getGameRegSettingsPath(Reg_SAM choice = KEY_WRITE)
{
    Win32_HKEY currentUserKey = win32::regOpenCurrentUser(choice | KEY_WOW64_64KEY)!;
    defer win32::regCloseKey(currentUserKey);
    String sub_key = "Software\\HMartSoftware\\unnnamed\\settings";
	return win32::regOpenKey(currentUserKey, sub_key, choice);
}

/*
LSTATUS RegGetValueA(
  [in]                HKEY    hkey,
  [in, optional]      LPCSTR  lpSubKey,
  [in, optional]      LPCSTR  lpValue,
  [in, optional]      DWORD   dwFlags,
  [out, optional]     LPDWORD pdwType,
  [out, optional]     PVOID   pvData,
  [in, out, optional] LPDWORD pcbData
);
*/
extern fn Win32_LSTATUS regGetValueA(Win32_HKEY key, Win32_LPCSTR lpSubKey, Win32_LPCSTR lpValue, Win32_DWORD flags,
                                Win32_LPDWORD *pdwType, Win32_PVOID pvData, Win32_LPDWORD pcbData) @cname("RegGetValueA");

extern fn Win32_LSTATUS regCloseKey(Win32_HKEY key) @cname("RegCloseKey");

fn void? setRegistryDwordValue(Win32_HKEY key, String setting, uint value) @public
{
    // Set the value in the registry key
    /*Win32_DWORD32 dwType, dwSize;
    dwType = REG_DWORD; // type of the value to be set
    dwSize = Win32_DWORD32::size; // size of the Win32_DWORD unsigned 32bits value
    if(regSetValue(key, (Win32_LPCSTR)setting.zstr_tcopy(), 0, dwType, (Win32_BYTE*)&value, dwSize) == ERROR_SUCCESS) return;
    // else return an error
    return ERROR_REGISTRY_KEY_SET_VALUE_FAILED~;*/
}

// unfinished does not work yet because of user permissions, don't know if I will bother with this
// as this functions try to write the Windows registry under the current user and that may be problematic
// for now will just save to the public user home directory.
//
// If you want to use this function, you need to run the application with administrator privileges
// and the user must have the necessary permissions to write to the registry.
// see https://community.osr.com/t/ot-regopenkeysave-fails-with-87/43818
// https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants
// https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-lookupprivilegevaluea
fn bool writeRegistryValue(Win32_HKEY key_root, String reg_key, String reg_value, String reg_data) @inline
{
    /*Win32_PHKEY? currentUserKey = regOpenCurrentUser(WIN32_KEY_WRITE);
    if(catch excuse = currentUserKey) 
    {
        log::warning(Where.FILE,"Failed to open current user register key with excuse: %s", excuse);
        return false;
    }
    defer regCloseKey(currentUserKey);*/

    /*Win32_HKEY? folder_key = regOpenKey(HKEY_CURRENT_USER, (Win32_LPCSTR)reg_key.zstr_tcopy(), 0, WIN32_KEY_WRITE);
    if(catch excuse = folder_key) 
    {
        log::warning(Where.FILE,"Failed to open key '%s' with excuse: %s", reg_key, excuse);
        return false;
    }
    defer regCloseKey(folder_key);*/

    Win32_LPDWORD dwDisposition;
    Win32_HKEY folder_key;
    defer regCloseKey(folder_key);

	Win32_DWORD sam = KEY_WRITE | KEY_WOW64_64KEY;

    bool? result = regCreateKey(key_root, reg_key, /*REG_OPTION_BACKUP_RESTORE*/REG_OPTION_NON_VOLATILE, sam, &folder_key, dwDisposition);
    if(catch excuse = result)
    {
        log::warning(FILE, "Failed to create or open registry key '%s' with excuse: %s", reg_key, excuse);
        return false; // return false on failure
    }

	if(dwDisposition == REG_CREATED_NEW_KEY) {
		log::info(FILE, "Registry key '%s' was created", reg_key);
	} 
	else if(dwDisposition == REG_OPENED_EXISTING_KEY) {
		log::warning(FILE, "registry key '%s' already existed", reg_key);
	}


    // Set the value in the registry key
    Win32_DWORD32 dwType, dwSize;
    dwType = REG_SZ; // type of the value to be set
    dwSize = reg_data.len; // size of the string data
    /*if(regSetValue(folder_key, reg_value, dwType, (Win32_BYTE*)reg_data.zstr_tcopy(), dwSize) == ERROR_SUCCESS) {
        return true; // return true on success
    }*/
    // It should return true on success and false on failure.
    return false;
}

/*
LSTATUS RegQueryValueExA(
  [in]                HKEY    hKey,
  [in, optional]      LPCSTR  lpValueName,
                      LPDWORD lpReserved,
  [out, optional]     LPDWORD lpType,
  [out, optional]     LPBYTE  lpData,
  [in, out, optional] LPDWORD lpcbData
);
*/
extern fn Win32_LSTATUS regQueryValueExA(Win32_HKEY key, Win32_LPCSTR  lpValueName,
  Win32_LPDWORD lpReserved,
  Win32_LPDWORD lpType,
  Win32_LPBYTE  lpData,
  Win32_LPDWORD lpcbData) @cname("RegQueryValueExA");

const MAX_OSPATH @local = 260;
<*
	Gets a path from the register inside HKEY_LOCAL_MACHINE
*>
fn bool getRegistryPath(Win32_HKEY root, String subkey, String name, String* dst) 
{
	if(root != HKEY_CURRENT_USER && root != HKEY_LOCAL_MACHINE) return false;

	Win32_CHAR[MAX_OSPATH] w;
	Win32_DWORD len = w.len;
	Win32_HKEY res;
	Win32_DWORD sam = KEY_QUERY_VALUE | KEY_WOW64_64KEY;
	Win32_DWORD type;

	if (regOpenKeyExA(root, (Win32_LPCSTR)subkey.zstr_tcopy(), 0, sam, &res) != ERROR_SUCCESS) {
		return false;
	}

	if (regQueryValueExA(res, (Win32_LPCSTR)name.zstr_tcopy(), null, &type, (Win32_LPBYTE)&w[0], &len) != ERROR_SUCCESS) {
		regCloseKey(res);
		return false;
	}

	regCloseKey(res);

	if (type != REG_SZ) {
		return false;
	}

	(*dst) = string::tformat("%s", (String)w[0:MAX_OSPATH]);

	return true;
}

/*
// Find the location of the DXC or FXC compiler
HKEY key;
if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, "SOFTWARE\\WOW6432Node\\Microsoft\\Microsoft SDKs\\Windows\\v10.0", 0, KEY_READ, &key) == ERROR_SUCCESS)
{
    DWORD sdk_path_len = sizeof(sdk_path);
    if (RegGetValueA(key, nullptr, "InstallationFolder", RRF_RT_REG_SZ, nullptr, sdk_path, &sdk_path_len) == ERROR_SUCCESS)
    {
        strcpy(sdk_path + sdk_path_len - 1, "bin\\");

        DWORD sdk_path_len2 = sizeof(sdk_path) - sdk_path_len - 4;
        if (RegGetValueA(key, nullptr, "ProductVersion", RRF_RT_REG_SZ, nullptr, sdk_path + sdk_path_len + 3, &sdk_path_len2) == ERROR_SUCCESS)
        {
            sprintf(sdk_path + sdk_path_len + 2 + sdk_path_len2, ".0\\x64\\%s.exe", dxc? "dxc" : "fxc");

            compiler = sdk_path;
        }
    }
    RegCloseKey(key);
}
*/
////


fn String? getSystemSpecialPath(Win32_KNOWNFOLDERID pathType = win32::FOLDERID_SAVED_GAMES)
{
    OSversionInfo osinfo;
    if(win32::getVersion(&osinfo) == 0) {
        if (osinfo.dwMajorVersion >=6)
        {
            Win32_PWSTR path;
            HResult result = getKnownFolderPath(pathType, KNOWN_FOLDER_FLAG_CREATE, null, &path);
            if (result == S_OK) 
            {
                WString wpath = (WString)path;
                return string::tfrom_wstring(wpath)!!;
            } else {
                return result.disc;
            }
        } else {
            return ERROR_UNSUPPORTED_WINDOWS_OS~;
        }
    } else {
        return ERROR_SPECIAL_PATH_QUERY_FAILED~;
    }
}

enum Sw : (String desc) @public
{
	HIDE {"Hides the window and activates another window"},
	SHOWNORMAL {"Activates and displays a window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time."},
	SHOWMINIMIZED {"Activates the window and displays it as a minimized window"},
	SHOWMAXIMIZED {"Activates the window and displays it as a maximized window"},
	SHOWNOACTIVATE {"Displays a window in its most recent size and position. This value is similar to SW_SHOWNORMAL, except that the window is not activated"},
	SHOW {"Activates the window and displays it in its current size and position"},
	MINIMIZE {"Minimizes the specified window and activates the next top-level window in the Z order"},
	SHOWMINNOACTIVE {"Displays the window as a minimized window. This value is similar to SW_SHOWMINIMIZED, except the window is not activated"},
	SHOWNA {"Displays the window in its current size and position. This value is similar to SW_SHOW, except that the window is not activated"},
	RESTORE {"Activates and displays the window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when restoring a minimized window"},
	SHOWDEFAULT {"Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application"},
	FORCEMINIMIZE {"force window to be minimized"}
}
const SW_NORMAL = Sw.SHOWNORMAL;
const SW_MAXIMIZE = Sw.SHOWMAXIMIZED;
<*
  @param [in] hwnd : "optional"
  @param [in] lpOperation : "optional"
  @param [in] lpFile : "mandatory"
  @param [in]  lpParameters : "optional"
  @param [in]  lpDirectory : "optional"
  @param nShowCmd : "in, mandatory"
*>
extern fn Win32_HINSTANCE shellExecuteA(
  Win32_HWND   hwnd,
  Win32_LPCSTR lpOperation,
  Win32_LPCSTR lpFile,
  Win32_LPCSTR lpParameters,
  Win32_LPCSTR lpDirectory,
  Win32_INT    nShowCmd
) @cname("ShellExecuteA");

<*
  @param [in] lpFileName : "mandatory, The name of the file or directory"
  @require lpFileName != (Win32_LPCSTR)""
*>
extern fn Win32_DWORD getFileAttributesA(Win32_LPCSTR lpFileName) @cname("GetFileAttributesA");

const FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400;
const INVALID_FILE_ATTRIBUTES = 0xFFFF_FFFF_FFFF_FFFF;
fn bool is_symblink(String path_or_file) @inline
{
    Win32_DWORD result = getFileAttributesA((ichar*)&path_or_file.zstr_tcopy()[0]);
    if (result != INVALID_FILE_ATTRIBUTES) {
        return (result & FILE_ATTRIBUTE_REPARSE_POINT) ? true : false;
    } else {
        log::warning(FILE, "failed to get file attributes to query for symbolic link status.");
        return false;
    }
}

alias Win32_PULARGE_INTEGER @local = ulong*;
<*
	Retrieves information about the amount of space that is available on a disk volume, 
	which is the total amount of space, 
	the total amount of free space, 
	and the total amount of free space available to the user that is associated with the calling thread.
	
	Remarks:
	If the function succeeds, the return value is nonzero.
	If the function fails, the return value is zero (0). 
	To get extended error information, call wind32::getLastError()
	The values obtained by this function are of the type ULARGE_INTEGER. 
	Do not truncate these values to 32 bits!!!
	
	@param [in] lpDirectoryName : `A directory on the disk.
								   If this parameter is NULL, the function uses the root of the current disk.
								   If this parameter is a UNC name, it must include a trailing backslash, for example, "\\MyServer\MyShare\".
								   This parameter does not have to specify the root directory on a disk. The function accepts any directory on a disk.
								   The calling application must have FILE_LIST_DIRECTORY access rights for this
								   directory.`
	@param [out] lpFreeBytesAvailableToCaller : `A pointer to a variable that receives the total number of free bytes on a disk that are available to the user who is associated with the calling thread.
											   This parameter can be NULL.
											   If per-user quotas are being used, this value may be less than the total number of free bytes on a disk.`
	@param [out]  lpTotalNumberOfBytes : `A pointer to a variable that receives the total number of bytes on a disk that are available to the user who is associated with the calling thread.
									    This parameter can be NULL.
									    If per-user quotas are being used, this value may be less than the total number of bytes on a disk.
									    To determine the total number of bytes on a disk or volume, use IOCTL_DISK_GET_LENGTH_INFO.`
	@param [out]  lpTotalNumberOfFreeBytes : `A pointer to a variable that receives the total number of free bytes on a disk.
											This parameter can be NULL.`
*>
extern fn Win32_BOOL getDiskFreeSpaceExA(
  Win32_LPCSTR          lpDirectoryName = null,
  Win32_PULARGE_INTEGER lpFreeBytesAvailableToCaller = null,
  Win32_PULARGE_INTEGER lpTotalNumberOfBytes = null,
  Win32_PULARGE_INTEGER lpTotalNumberOfFreeBytes = null
) @cname("GetDiskFreeSpaceExA");

