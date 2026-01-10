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

module engine::filesystem::fs;
// just a wrapper to some raylib functions

// region modules
import std::os;
import game::main;
import std::io, std::io::path;
import std::collections::list;
import thirdparty::raylib5::rl;
import engine::logging::log;
// end_region

faultdef FS_FAILED_SAVE_DATA,
         FS_FAILED_MAKE_DIR,
         FS_FAILED_CHANGE_DIR;

// modes for OpenFileByMode. used as bit mask internally
alias FileMode @local = String;
const FileMode FILE_READ              = "r";
const FileMode FILE_WRITE             = "w";
const FileMode FILE_READ_WRITE        = "r+";
const FileMode FILE_APPEND            = "a";
const FileMode FILE_READ_BINARY       = "rb";
const FileMode FILE_WRITE_BINARY      = "wb";
const FileMode FILE_READ_WRITE_BINARY = "r+b";

alias StringList @local = List{String};

// file list for directory listings
struct FileList (Printable) @private
{
	String basePath;
	StringList	list;
}

fn usz? FileList.to_format(&self, Formatter* f) @dynamic
{
    return f.printf("FileList(basePath: '%s', numFiles: %d)", self.basePath, self.getNumFiles());
}

<*
    Returns the number of files in a file list.
    @ensure return <= self.list.len()
*>
fn uint FileList.getNumFiles(&self) => (uint)self.list.len();

<*
    Returns a file path from the list.
    @param index : "The index into the file list."
    @require index < self.getNumFiles()
*>
fn String FileList.getFile(&self, uint index ) => self.list[index];

<*
    Return a pointer to the file list.
    @ensure return != null
*>
fn StringList*	FileList.getList(&self) => &self.list;

struct ModList 
{
	StringList	mods;
	StringList	descriptions;
}

fn uint ModList.getNumMods(&self) => (uint)self.mods.len();

<*
    Returns the mod folder name from the mod list.
    @param index : "The index into the mod list."
    @require index < self.getNumMods()
*>
fn String ModList.getMod(&self, uint index ) => self.mods[index];

<*
    Returns a mod description from a description list.
    @param index : "The index into the mod description list."
    @require index < self.descriptions.len()
*>
fn String ModList.getDescription(&self, uint index ) => self.descriptions[index];

// region Files management functions
struct EntireFile @local {
    usz contents_size;
    void* contents;
}

<*
    Performance?

    @param [in] filepath : "The path of the file to load."
*>
fn String? readEntireFileX(String filepath) 
{
    EntireFile _file;
    
    File data = openFile(filepath, FILE_READ_BINARY)!;
    defer (void)data.close();
    
    if(data.file != null)
    {
        _file.contents_size = data.seek(0, Seek.END)!;
        data.seek(0, SET)!; // return to the start
        _file.contents = mem::calloc(char.sizeof * _file.contents_size);
        char[] buffer = ((char*)_file.contents)[:_file.contents_size];
        data.read(buffer[:_file.contents_size])!;
        return ((String)buffer).tcopy();
    } else{
        log::error(FILE, "Cannot open file: %s", filepath);
    }
    
    return (String)"";
}

fn String? readEntireFile(String filepath) @inline {
    char[] buffer;
    fault excuse = @catch(file::load_buffer(filepath, buffer));
    
    return string::format(mem, "%s", buffer);
}

<*
    Returns file data as char slice (pointer and len) not a array! (read)
    Needs to be unloaded with fileUnloadEntireBytes() after use.

    @param [in] fileName : "The name of the file to load."
    @ensure return.ptr != null && return.len > 0
*>
fn char[] fileLoadEntireBytes(String fileName) 
{
    int bytesRead;
    return rl::loadFileData(fileName.zstr_tcopy(), &bytesRead)[:bytesRead];
}

// Unload file data allocated by fileLoadEntireBytes()
fn void fileUnloadEntireBytes(ZString data) @inline {
    rl::unloadFileData(data);
}

// Save data to file from byte array (write), returns true on success
fn bool? fileSaveEntireBytes(String fileName, char[] data) {
    if(rl::saveFileData(fileName.zstr_tcopy(), (void*)data.ptr, data.len)) {
        return true;
    } else {
        return FS_FAILED_SAVE_DATA?;
    }
}

// Load text data from file (read), returns string view
fn String fileLoadEntireText(String fileName) {
   return rl::loadFileText(fileName.zstr_tcopy()).str_view();
}

// Save data to file from byte array (write), returns true on success
fn bool? fileSaveEntireText(String fileName, String text) {
    if(rl::saveFileText(fileName.zstr_tcopy(), text.zstr_tcopy())) {
        return true;
    } else {
        return FS_FAILED_SAVE_DATA?;
    }
}


fn File? openFile(String path, String mode = FILE_READ) @inline
{
    return io::file::open(path, mode)!;
}

fn void? saveFile(String path, char[] data) @inline
{
    io::file::save(path, data)!;
}

fn char[]? loadBinaryFile(String path) @inline
{
    return io::file::load_temp(path)!;
}

fn char[]? loadBinaryFileFromPath(Path path) @inline
{
    return io::file::load_path_temp(path)!;
}

// end_region

// region File system functions

/*
    example:
    
    char[100] buffer;
    String res = (String)io::bprintf(&buffer, "%s", "This is where save data will be")!;
    if(@catch(fs::makeFile(local_game.app_save_folder.tconcat("\\").tconcat("READ_ME.txt"), &buffer))) {
        unreachable();
    }
*/
fn void? makeFile(String full_path_including_file_name, char[] data) {
    return file::save(full_path_including_file_name, data);
}

// Check if file exists
fn bool fileExists(String fileName) @inline {
    return rl::fileExists(fileName.zstr_tcopy());
}
// Check if a directory path exists
fn bool directoryExists(String dirPath) @inline {
    return rl::directoryExists(dirPath.zstr_tcopy());
}
// Check file extension (including point: .png, .wav)
fn bool isFileExtension(String fileName, ZString ext) @inline {
    return rl::isFileExtension(fileName.zstr_tcopy(), ext);
}
// Get file size in bytes
fn uint getFileSize(String fileName) @inline {
    CInt result = rl::getFileLength(fileName.zstr_tcopy());
    return (result) ? result : 0u;
}
// Get string view of extension for a filename (includes dot: '.png')
fn String getFileExtension(String fileName) @inline {
    return rl::getFileExtension(fileName.zstr_tcopy()).str_view();
}
// Get string view for a filename for a path string
fn String getFileName(String filePath) {
    return rl::getFileName(filePath.zstr_tcopy()).str_view();
}
// Get zero terminated string (pointer) for a filename for a path string
fn ZString getFileNameZstr(String filePath) @inline {
    return rl::getFileName(filePath.zstr_tcopy());
}
// Get filename string view without extension (uses static string)
fn String getFileNameWithoutExt(String filePath) @inline {
    return rl::getFileNameWithoutExt(filePath.zstr_tcopy()).str_view();
}
// Get full path for a given fileName with path (uses static string)
fn ZString getDirectoryPath(ZString filePath) @inline {
    String result = string::tformat("%s", rl::getDirectoryPath(filePath));
    if(!(result.ends_with("/") || result.ends_with("\\"))) {
        result = result.tconcat("\\");
    }
    return result.zstr_tcopy();
}
// Get previous directory path for a given path (uses static string)
fn ZString getPrevDirectoryPath(ZString dirPath) @inline {
    String result = string::tformat("%s", rl::getPrevDirectoryPath(dirPath));
    if(!(result.ends_with("/") || result.ends_with("\\"))) {
        result = result.tconcat("\\");
    }
   return result.zstr_tcopy();
}
// Get current working directory (uses static string)
// This is the directory where the application is running FROM.
// It is not the same as the application directory, which is where the executable is located.
// This is because the working directory can change during runtime, for example, 
// if the user changes it in the settings or runs the application from a shortcut in a different directory.
fn String getWorkingDirectory() @inline {
    String result = rl::getWorkingDirectory().str_view();
    if(!(result.ends_with("/") || result.ends_with("\\"))) {
        result = result.tconcat("\\");
    }
    return result.tcopy();
}
// Get the directory of the running application (uses static string)
// This is the directory where the executable is really located.
fn ZString getApplicationDirectory() @inline {
    String result = rl::getApplicationDirectory().str_view();
    if(!(result.ends_with("/") || result.ends_with("\\"))) {
        result = result.tconcat("\\");
    }
    return result.zstr_tcopy();
}
// Create directories (including full path requested), returns true on success
fn bool? makeDirectory_IfNotExist(String dirPath) {
    if(rl::directoryExists(dirPath.zstr_tcopy())) {
        return true; // directory already exists
    }

    const SUCESS = 0;
    if(rl::makeDirectory(dirPath.zstr_tcopy()) == SUCESS) {
        return true;
    } else {
        return FS_FAILED_MAKE_DIR?;
    }
}
// Change working directory, return true on success
fn bool? changeDirectory(String dir) {
    if(rl::changeDirectory(dir.zstr_tcopy())) {
        return true;
    } else {
        return FS_FAILED_CHANGE_DIR?;
    }
}
// Check if a given path is a file
fn bool isFile(String path) @inline @public {
    return rl::isPathFile(path.zstr_tcopy());
}
// Check if a given path is a directory
fn bool isDirectory(String path) @inline {
    return !isFile(path);
}
// Check if fileName is valid for the platform/OS
fn bool isFileNameValid(String fileName) @inline {
    return rl::isFileNameValid(fileName.zstr_tcopy());
}
// Load directory filepaths
fn RLFilePathList loadDirectoryFiles(String dirPath) @inline {
    return rl::loadDirectoryFiles(dirPath.zstr_tcopy());
}
// Load directory filepaths with extension filtering and recursive directory scan
fn RLFilePathList loadDirectoryFilesEx(String basePath, String filter, bool scanSubdirs) @inline {
    return rl::loadDirectoryFilesEx(basePath.zstr_tcopy(), filter.zstr_tcopy(), scanSubdirs);
}
// Clear directory files paths buffers (free memory)
fn void unloadDirectoryFiles(RLFilePathList files) @inline {
    rl::unloadDirectoryFiles(files);
}

// Check if a file has been dropped into window
fn bool isFileDropped() => rl::isFileDropped();
// Load dropped filepaths
fn RLFilePathList loadDroppedFiles() => rl::loadDroppedFiles();
// Unload dropped filepaths
fn void unloadDroppedFiles(RLFilePathList files) @inline {
    rl::unloadDroppedFiles(files);
}
// Get file modification time (last write time)
fn CLong getFileModTime(String fileName) => rl::getFileModTime(fileName.zstr_tcopy());


fn void do_move(String from, String dest, String fileExtensions = "") @local
{
    if(fileExtensions.len)
    {
        String[] extensions = fileExtensions.tsplit(",");
        assert(extensions.len > 0, "No file extensions provided for moving files.");
        // remove any leading or trailing whitespace from the extensions
        for(int i = 0; i < extensions.len; i++) {
            extensions[i] = extensions[i].trim();
        }
        // iterate over each file extension
        foreach(fileext : extensions)
        {
            // load all files with the given extension in the main directory
            int i, file_count;
            RLFilePathList files = loadDirectoryFilesEx(from, fileext, scanSubdirs: false);
            file_count = files.count;
            assert(file_count >= 1);
            do { // move the files to the subdirectory
                String file_path = ((ZString)files.paths[i]).str_view();
                char[] file_data = file::load_temp(file_path)!!;
                if(file_data.len)
                {
                    String file_final_path = dest.tconcat(getFileName(file_path));
                    @catch(file::save(file_final_path, file_data));
                    // delete old file
                    @catch(file::delete(file_path));
                }
                file_count--;
                i++;
            } while(file_count >= 1);

            /*for(int i = 0; i < files.count; i++)
            {
                // now move the files to the subdirectory
                String file_path = ((ZString)files.paths[i]).str_view();
                char[] file_data = file::load_temp(file_path)!!;
                if(file_data.len)
                {
                    String file_final_path = dest.tconcat(getFileName(file_path));
                    @catch(file::save(file_final_path, file_data));
                    // delete old file
                    @catch(file::delete(file_path));
                }
            }*/
            unloadDirectoryFiles(files);
        }
    } else {
        // load all files in the original directory
        RLFilePathList files = fs::loadDirectoryFiles(from);
        for(int i = 0; i < files.count; i++) 
        {
            // now move the files to the subdirectory
            String file_path = ((ZString)files.paths[i]).str_view();
            char[] file_data = file::load_temp(file_path)!!;
            if(file_data.len)
            {
                String file_final_path = dest.tconcat(fs::getFileName(file_path));
                @catch(file::save(file_final_path, file_data));
                // delete old file
                @catch(file::delete(file_path));
            }
        }
        fs::unloadDirectoryFiles(files);
    }
}

<*
    Move files from given directory to another directory. 
    (does nothing if the from directory does not exist)
    @param from : "The original directory where the files are located."
    @param to : "The destination directory where the files will be moved."
    @param fileExtensions : "A String of file extensions seperated by a comma, to filter the files to be moved."
    @require from.is_empty() == false && to.is_empty() == false
*>
fn void moveFiles(String from, String to, String fileExtensions = "")
{
    if(directoryExists(from))
    {
        if(from.ends_with("\\") == false) {
            from = from.tconcat("\\");
        }
        if(to.ends_with("\\") == false) {
            to = to.tconcat("\\");
        }
        
        String files_dir = main::gpGame.app_work_dir.tconcat(from);
        String files_to  = main::gpGame.app_work_dir.tconcat(to);

        bool? sucess = fs::makeDirectory_IfNotExist(files_to);
        if(catch excuse = sucess) { // will ignore if the directory already exists
            log::warning(Where.FILE, "Failed to create directory at: %s!\n\t -> excuse: %s", 
                        files_to, excuse);
            $if $feature(_DEBUG):
                unreachable();
            $endif
        }

        do_move(files_dir, files_to, fileExtensions);
    }
}

// end_region

// #region Path
fn Path? newPath(String _path) 
{
    $if $defined(env::WIN32):
        return path::temp(_path, PathEnv.WIN32);
    $else
        $if $defined(env::POSIX):
            return path::temp(_path, PathEnv.POSIX);
        $endif

        return path::temp(_path); // default enviroment whatever it is
    $endif
}
// #endregion







//////////////////////////////////////////////////////////////////////
//--------------------------------------------------------
module engine::filesystem::fs::win32 @if(env::WIN32);

import std::io;
import std::os::env, std::os::win32;
import engine::logging::log;

// region WIN32 (Windows)
const PERSONAL_FOLDER_MY_GAMES = 0;

enum HResult : int (Win32_HRESULT val, String disc) @local {
    S_OK           = {(Win32_HRESULT)0x00000000, "Operation successful"},
    E_ABORT        = {(Win32_HRESULT)0x80004004, "Operation aborted"},
    E_ACCESSDENIED = {(Win32_HRESULT)0x80070005, "General access denied error"},
    E_FAIL         = {(Win32_HRESULT)0x80004005, "Unspecified failure"},
    E_HANDLE       = {(Win32_HRESULT)0x80070006, "Handle that is not valid"},
    E_INVALIDARG   = {(Win32_HRESULT)0x80070057, "One or more arguments are not valid"},
    E_NOINTERFACE  = {(Win32_HRESULT)0x80004002, "No such interface supported"},
    E_NOTIMPL      = {(Win32_HRESULT)0x80004001, "Not implemented"},
    E_OUTOFMEMORY  = {(Win32_HRESULT)0x8007000E, "Failed to allocate necessary memory"},
    E_POINTER      = {(Win32_HRESULT)0x80004003, "Pointer that is not valid"},
    E_UNEXPECTED   = {(Win32_HRESULT)0x8000FFFF, "Unexpected failure"}
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

alias Win32_REFKNOWNFOLDERID = Win32_GUID;
const Win32_REFKNOWNFOLDERID  HOME_FOLDER = {0x4c5c32ff, 0xbb9d, 0x43b0, {0xb5, 0xb4, 0x2d, 0x72, 0xe5, 0x4e, 0xaa, 0xa4}};
alias FOLDERID_SAVEDGAMES = HOME_FOLDER;
// NOTE(HM): I made this before realizing that shGetKnownFolderPath was already defined in std file shell32.c3 win32 module
// i'm letting this be because it works in a tad different way (using our own HResult enum type)
extern fn HResult getKnownFolderPath(Win32_REFKNOWNFOLDERID rfid, Win32_DWORD dwFlags, Win32_HANDLE hToken /*null*/, Win32_PWSTR *ppszPath /*out*/) @cname("SHGetKnownFolderPath") @if(env::WIN32);

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
	statex.dwLength = MemoryStatus.sizeof;
	globalMemoryStatusEx(&statex);
	int physRam = (int)(statex.ullTotalPhys / ( 1024 * 1024 ));
	// HACK: For some reason, ullTotalPhys is sometimes off by a meg or two, so we round up to the nearest 16 megs
	physRam = ( physRam + 8 ) & ~15;
	return physRam;
}

//////////////////////////////////////////////////////////////////////////////////////////////////
// Win32 registry constants and types
// These constants and types are used for Windows registry operations.
const Win32_HKEY HKEY_CURRENT_USER = &&0x80000001;

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
const Win32_DWORD WIN32_KEY_READ  = STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY;  // read access to registry keys
const Win32_DWORD WIN32_KEY_WRITE = STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY;  // write access

const Win32_DWORD REG_CREATED_NEW_KEY     = 0x00000001L;  // registry key was created
const Win32_DWORD REG_OPENED_EXISTING_KEY = 0x00000002L;  // registry key already existed

const Win32_INT64 ERROR_SUCCESS = 0x00000000_00000000;  // success code for registry operations
alias Win32_LSTATUS = Win32_INT64; // alias for registry status codes

alias Reg_SAM = Win32_DWORD; // registry security access mask type

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
         ERROR_REGISTRY_KEY_CLOSING_FAILED;

/*
LSTATUS RegOpenCurrentUser(
  [in]  REGSAM samDesired,
  [out] PHKEY  phkResult
);
*/
extern fn Win32_LSTATUS regOpenCurrentUserEx(Reg_SAM desired, Win32_PHKEY result) @cname("RegOpenCurrentUser");
fn Win32_PHKEY? regOpenCurrentUser(Reg_SAM desired) 
{
    Win32_PHKEY result;
    // Attempt to open the current user registry key with the specified access rights
    Win32_LSTATUS status = regOpenCurrentUserEx(desired, result);
    if (status == ERROR_SUCCESS) {
        return result; // Return the opened registry key handle (call regCloseKey to close it later)
    }
    return ERROR_REGISTRY_KEY_OPEN_FAILED?; // or handle the error as needed
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
extern fn Win32_LSTATUS regOpenKeyExA(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_DWORD options, Reg_SAM desired, Win32_PHKEY result) @cname("RegOpenKeyExA");
fn Win32_PHKEY? regOpenKey(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_DWORD options, Reg_SAM desired) 
{
    Win32_PHKEY result;
    // Attempt to open the specified registry key with the given access rights
    Win32_LSTATUS status = regOpenKeyExA(key, sub_key, options, desired, result);
    if (status == ERROR_SUCCESS) {
        return result; // Return the opened registry key handle (call regCloseKey to close it later)
    }
    return ERROR_REGISTRY_KEY_OPEN_FAILED?; // or handle the error as needed
}

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
                       Win32_PHKEY  result, Win32_LPDWORD disposition) @cname("RegCreateKeyExA");

fn bool? regCreateKey(Win32_HKEY key, Win32_LPCSTR sub_key, Win32_DWORD reserve, Win32_LPSTR class, 
                       Win32_DWORD options, Reg_SAM desired, Win32_LPSECURITY_ATTRIBUTES securityAttributes,
                       Win32_PHKEY  result, Win32_LPDWORD disposition)
{
    Win32_LSTATUS status = regCreateKeyEx(key, sub_key, reserve, class, options, desired, securityAttributes, result, disposition);
    if (status == ERROR_SUCCESS) {
        return true;
    }

    return ERROR_REGISTRY_KEY_CREATION_FAILED?; // or handle the error as needed
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
extern fn Win32_LSTATUS regSetValue(Win32_HKEY key, Win32_LPCSTR valueName, Win32_DWORD reserved, Win32_DWORD type,
                                Win32_BYTE *data, Win32_DWORD data_size) @cname("RegSetValueExA");

extern fn Win32_LSTATUS regCloseKey(Win32_HKEY key) @cname("RegCloseKey");

// creates or opens a new subkey under the current user registry key
// The subkey is created under "Software\\HMartSoftware\\unnnamed\\settings"
fn Win32_PHKEY? createRegistryKey(String keyname) @inline
{
    Win32_PHKEY currentUserKey = regOpenCurrentUser(WIN32_KEY_WRITE)!;
    defer regCloseKey(currentUserKey);

    ZString registry_path = string::tformat("%s","Software\\HMartSoftware\\unnnamed\\settings\\").tconcat(keyname).zstr_tcopy();
    Win32_HKEY result;
    Win32_DWORD dwDisposition;
    // Create or open the registry key with the specified path and access rights
    if(try regCreateKey(currentUserKey, ((Win32_LPCSTR))registry_path, 0, null, REG_OPTION_BACKUP_RESTORE, WIN32_KEY_WRITE, null, &result, &dwDisposition)) {
        return result; // Return the created or opened registry key handle
    }
    return ERROR_REGISTRY_KEY_CREATION_FAILED?;
}

fn void? setRegistryDwordValue(String setting, uint value) @public
{
    Win32_PHKEY folder_key = createRegistryKey("common")!;
    defer regCloseKey(folder_key);

    // Set the value in the registry key
    Win32_DWORD32 dwType, dwSize;
    dwType = REG_DWORD; // type of the value to be set
    dwSize = Win32_DWORD32.sizeof; // size of the Win32_DWORD unsigned 32bits value
    if(regSetValue(folder_key, (Win32_LPCSTR)setting.zstr_tcopy(), 0, dwType, (Win32_BYTE*)&value, dwSize) == ERROR_SUCCESS) return;
    // else return an error
    return ERROR_REGISTRY_KEY_SET_VALUE_FAILED?;
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
fn bool writeRegistryValue(String reg_key, String reg_value, String reg_data) @inline
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

    Win32_DWORD dwDisposition;
    Win32_HKEY folder_key;
    bool? result = regCreateKey(HKEY_CURRENT_USER, (Win32_LPCSTR)reg_key.zstr_tcopy(), 0, null, REG_OPTION_BACKUP_RESTORE, WIN32_KEY_WRITE, null, &folder_key, &dwDisposition);
    if(catch excuse = result)
    {
        log::warning(Where.FILE, "Failed to create or open registry key '%s' with excuse: %s", reg_key, excuse);
        return false; // return false on failure
    }
    defer regCloseKey(folder_key);

    // Set the value in the registry key
    Win32_DWORD32 dwType, dwSize;
    dwType = REG_SZ; // type of the value to be set
    dwSize = reg_data.len; // size of the string data
    if(regSetValue(folder_key, (Win32_LPCSTR)reg_value.zstr_tcopy(), 0, dwType, (Win32_BYTE*)reg_data.zstr_tcopy(), dwSize) == ERROR_SUCCESS) {
        return true; // return true on success
    }
    // It should return true on success and false on failure.
    return false;
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


// NOTE(HM) in windows "Special Path" is the MyDocuments folder in Linux is the HOME folder...
fn String getSystemSpecialPath(int pathType)
{
$if $defined(env::WIN32):
    OSversionInfo osinfo;
    if(win32::getVersion(&osinfo) == 0) {
        if (osinfo.dwMajorVersion >=6)
        {
            Win32_PWSTR path;
            HResult result = getKnownFolderPath(FOLDERID_SAVEDGAMES, KNOWN_FOLDER_FLAG_CREATE, null, &path);
            if (result == S_OK) 
            {
                WString wpath = (WString)path;
                return string::tfrom_wstring(wpath)!!;
            } else {
                return result.disc;
            }
        } else {
            unreachable("unsupported Windows OS detected!");
        }
    } else {
        unreachable("failed to get windows version data");
    }
$else
    switch (pathType)
    {
    case PERSONAL_FOLDER_MY_GAMES:
        // ZString home = libc::getenv("HOME");
        // return home.str_view();
        return env::get_home_dir(tmem)!;
    default:
        return "";
    }
$endif
}
