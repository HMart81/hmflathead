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
import std::io, std::io::path;
import std::os;
import thirdparty::raylib5::rl;
// end_region

faultdef FS_FAILED_SAVE_DATA,
         FS_FAILED_MAKE_DIR,
         FS_FAILED_CHANGE_DIR;

// region Files management functions
// Load file data as byte array (read)
fn char[] fileLoadEntireBytes(String fileName) {
    int bytesRead;
    char[] result;
    char* data = rl::loadFileData(fileName.zstr_tcopy(), &bytesRead);
    result = data[:bytesRead];
    fileUnloadEntireBytes((ZString)data);
    return result;
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


fn File? openFile(String path, String mode = "r") @inline
{
    return io::file::open(path, mode)!;
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
fn usz getFileSize(String fileName) @inline {
    return (usz)rl::getFileLength(fileName.zstr_tcopy());
}
// Get pointer to extension for a filename string (includes dot: '.png')
fn String getFileExtension(String fileName) @inline {
    return rl::getFileExtension(fileName.zstr_tcopy()).str_view();
}
// Get string view for a filename for a path string
fn String getFileName(String filePath) {
    return rl::getFileName(filePath.zstr_tcopy()).str_view();
}
// Get pointer for a filename for a path string
fn ZString getFileNamePtr(String filePath) @inline {
    return rl::getFileName(filePath.zstr_tcopy());
}
// Get filename string without extension (uses static string)
fn String getFileNameWithoutExt(String filePath) @inline {
    return rl::getFileNameWithoutExt(filePath.zstr_tcopy()).str_view();
}
// Get full path for a given fileName with path (uses static string)
fn ZString getDirectoryPath(ZString filePath) @inline {
    return rl::getDirectoryPath(filePath);
}
// Get previous directory path for a given path (uses static string)
fn ZString getPrevDirectoryPath(ZString dirPath) @inline {
    return rl::getPrevDirectoryPath(dirPath);
}
// Get current working directory (uses static string)
fn String getWorkingDirectory() @inline {
    return rl::getWorkingDirectory().str_view();
}
// Get the directory of the running application (uses static string)
fn ZString getApplicationDirectory() @inline {
    return rl::getApplicationDirectory();
}
// Create directories (including full path requested), returns true on success
fn bool? makeDirectory(String dirPath) {
    if(rl::makeDirectory(dirPath.zstr_tcopy()) == 0) {
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
fn FilePathList loadDirectoryFiles(String dirPath) @inline {
    return rl::loadDirectoryFiles(dirPath.zstr_tcopy());
}
// Load directory filepaths with extension filtering and recursive directory scan
fn FilePathList loadDirectoryFilesEx(String basePath, String filter, bool scanSubdirs) @inline {
    return rl::loadDirectoryFilesEx(basePath.zstr_tcopy(), filter.zstr_tcopy(), scanSubdirs);
}
// Clear directory files paths buffers (free memory)
fn void unloadDirectoryFiles(FilePathList files) @inline {
    rl::unloadDirectoryFiles(files);
}
// Check if a file has been dropped into window
fn bool isFileDropped() => rl::isFileDropped();
// Load dropped filepaths
fn FilePathList loadDroppedFiles() => rl::loadDroppedFiles();
// Unload dropped filepaths
fn void unloadDroppedFiles(FilePathList files) @inline {
    rl::unloadDroppedFiles(files);
}
// Get file modification time (last write time)
fn CLong getFileModTime(String fileName) => rl::getFileModTime(fileName.zstr_tcopy());
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

//--------------------------------------------------------

// region WIN32 (Windows)
enum SystemPath : int @if(env::WIN32)
{
    PERSONAL
}

enum HResult : int (Win32_HRESULT val, String disc) @if(env::WIN32) @local {
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

enum KnownFolderFlag : int (Win32_DWORD val) @if(env::WIN32) @local {
  DEFAULT                          = 0x00000000,
  FORCE_APP_DATA_REDIRECTION       = 0x00080000,
  RETURN_FILTER_REDIRECTION_TARGET = 0x00040000,
  FORCE_PACKAGE_REDIRECTION        = 0x00020000,
  NO_PACKAGE_REDIRECTION           = 0x00010000,
  FORCE_APPCONTAINER_REDIRECTION   = 0x00020000,
  NO_APPCONTAINER_REDIRECTION      = 0x00010000,
  CREATE                           = 0x00008000,
  DONT_VERIFY                      = 0x00004000,
  DONT_UNEXPAND                    = 0x00002000,
  NO_ALIAS                         = 0x00001000,
  INIT                             = 0x00000800,
  DEFAULT_PATH                     = 0x00000400,
  NOT_PARENT_RELATIVE              = 0x00000200,
  SIMPLE_IDLIST                    = 0x00000100,
  ALIAS_ONLY                       = 0x80000000
}

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

alias Win32_REFKNOWNFOLDERID @if(env::WIN32) = Win32_GUID;
const Win32_REFKNOWNFOLDERID  HOME_FOLDER @if(env::WIN32) = {0x4c5c32ff, 0xbb9d, 0x43b0, {0xb5, 0xb4, 0x2d, 0x72, 0xe5, 0x4e, 0xaa, 0xa4}};
alias FOLDERID_SAVEDGAMES = HOME_FOLDER;

extern fn HResult win32GetKnownFolderPath(Win32_REFKNOWNFOLDERID rfid, Win32_DWORD dwFlags, Win32_HANDLE hToken /*null*/, Win32_PWSTR *ppszPath /*out*/) @extern("SHGetKnownFolderPath") @if(env::WIN32);
//extern fn bool isWindowsVistaOrGreater() @extern("IsWindowsVistaOrGreater") @if(env::WIN32);
extern fn int win32GetVersion(OSversionInfoPrt lpVersionInformation) @extern("RtlGetVersion") @if(env::WIN32);
extern fn int copyFileA( Win32_LPCSTR lpExistingFileName, Win32_LPCSTR lpNewFileName, Win32_BOOL bFailIfExists ) @extern("CopyFileA");
// end_region WIN32 (Windows)

// NOTE(HM) in windows is the MyDocuments folder in Linux is the HOME folder...
fn String getSystemSpecialPath(SystemPath pathType)
{
$if $defined(env::WIN32):
    OSversionInfo osinfo;
    if(win32GetVersion(&osinfo) == 0) {
        if (osinfo.dwMajorVersion >=6)
        {
            Win32_PWSTR path;
            HResult result = win32GetKnownFolderPath(FOLDERID_SAVEDGAMES, KnownFolderFlag.CREATE.val, null, &path);
            if (result == S_OK) {
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
    case SystemPath.PERSONAL:
        // ZString home = libc::getenv("HOME");
        // return home.str_view();
        return env::get_home_dir(tmem)!;
    default:
        return "";
    }
$endif
}
