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
import libc;
import std::io, std::io::path;
import std::collections::list;
import std::os, std::core::mem;
import game::main;
import engine::misc;
import engine::sys::cvar;
import engine::logging::log;
import engine::platform::win32;
import engine::sys::framework::platform::platf;
import thirdparty::raylib5::rl;
// end_region

faultdef FS_FAILED_SAVE_DATA,
         FS_FAILED_MAKE_DIR,
         FS_FAILED_GET_DIR,
         FS_FAILED_GET_FILE_ATTRIB,
         FS_FAILED_ADD_DIR,
         FS_FAILED_CHANGE_DIR;

const Time_t FILE_NOT_FOUND_TIMESTAMP = 0xFFFFFFFF;
const int MAX_PURE_PAKS = 128;
// HM: https://www.gnu.org/software/libc/manual/html_node/Limits-for-Files.html says
//     that FILENAME_MAX can be *really* big on some systems and thus is not suitable
//     for buffer lengths. So limit it to prevent stack overflow/out of memory issues
const int MAX_OSPATH = (libc::FILENAME_MAX < 32000) ? libc::FILENAME_MAX : 32000;

CVar cv_base      = { "fs_base", CvFlag.STRING | CvFlag.ARCHIVE | CvFlag.SYSTEM, "data",  "default game base folder"};
CVar cv_mod_name  = { "fs_mod_name", CvFlag.STRING | CvFlag.ARCHIVE | CvFlag.SYSTEM, "",      "folder name of mod to run"};
CVar cv_mod_base  = { "fs_mod_base", CvFlag.STRING | CvFlag.ARCHIVE | CvFlag.SYSTEM, "",      "folder name for custom database of running mod"};
CVar cv_save_path = { "fs_savepath", CvFlag.STRING | CvFlag.ARCHIVE | CvFlag.SYSTEM, "HMGames\\saves\\", "relative folder path to the game/s save data"};
CVar cv_dev_path  = { "fs_devpath", CvFlag.STRING | CvFlag.ARCHIVE | CvFlag.SYSTEM, "", "special developer folder where source assets are put"};

fn void register_cvars() 
{
    cvar::@register(&cv_base);
    cvar::@register(&cv_mod_name);
    cvar::@register(&cv_mod_base);
    cvar::@register(&cv_save_path);
    cvar::@register(&cv_dev_path);
}



// modes for OpenFileByMode. used as bit mask internally
alias FileMode @local = String;
const FileMode FILE_READ              = "r";
const FileMode FILE_WRITE             = "w";
const FileMode FILE_READ_WRITE        = "r+";
const FileMode FILE_APPEND            = "a";
const FileMode FILE_READ_BINARY       = "rb";
const FileMode FILE_WRITE_BINARY      = "wb";
const FileMode FILE_READ_WRITE_BINARY = "r+b";


const MAX_SEARCH_DEPTH = 6; // how deep to search for directories

module engine::filesystem::fs @if($defined(NEW_DIRECTORY_SYSTEM));

// region modules
import std::os;
import libc;
import game::main;
import engine::misc;
import std::io, std::io::path;
import std::collections::list;
import thirdparty::raylib5::rl;
import engine::logging::log;
import engine::sys::cvar;
import engine::sys::framework::platform::platf;
// end_region

constdef AppDir : inline int
{
    EXE = 0,
	WORK,
	BASE,
	SAVE,
	MODS,
	SCREENSHOTS
}
const DIR_COUNT = AppDir::values.len;

alias ListFiles @local = List { HMFile* };

struct HMFile
{
	Path path;
	String name;
}

alias DirList @local = List { HMDirectory* };

struct HMDirectory
{
    int id;
    Path path;
    String name;
}

fn void HMDirectory.clear(&self) @inline
{
    self.path.free(tmem);
    self.name = "";
}

fn bool HMDirectory.exists(self) => directoryExists(self.path);

fn bool? HMDirectory.contains(self, Path _path)
{
	PathList paths = listDirectoryPaths(self.path)!;
	foreach(pth : paths) 
    {
		if(pth == _path) return true;
	}
	return false;
}


/*
TraverseCallback fnwalk = fn bool?(Path p, bool is_dir, any d) {
    assert(d.type == HMDirectory);
    HMDirectory* dr = d.ptr;
    $if env::WIN32:
        Win32_FILE_ATTRIBUTE_DATA fileInfo;
        Win32_BOOL sucess = win32::getFileAttributesExW(p.to_temp_wstring(), Win32_GET_FILEEX_INFO_LEVELS.STANDARD, &fileInfo)!;
        if(sucess == 0) {
            log::warning(FILE, "failed to get attributs for file '%s", p);
            return true; // abort traverse
        }
        bool is_hidden_file_or_folder = (fileInfo.dwFileAttributes & win32::FILE_ATTRIBUTE_HIDDEN) == win32::FILE_ATTRIBUTE_HIDDEN;
        if(is_dir) {
            if(is_hidden_file_or_folder || p.basename().starts_with(".")) {
                // ignore this directory
            } else {
                dr.directories.push(p);
            }
            return false; // continue traverse
        } else if(path::is_file(p)) {
            if(is_hidden_file_or_folder) {
                // ignore hidden files
            } else { 
                dr.files.push(p); 
            }
            return false; // continue traverse
        }
    $else
        if(is_dir) {
            dr.directories.push(p);
            return false;
        } else if(path::is_file(p)) {
            dr.files.push(p);
            return false;
        }
    $endif
    return true; // abort traverse
};
*/

fn bool? traverse(Path pth) @local
{
    PathList paths = listDirectoryPaths(pth)!;
    foreach(_path : paths)
    {
        bool is_hidden_file_or_folder;
        $if env::WIN32:
            Win32_FILE_ATTRIBUTE_DATA fileInfo;
            Win32_BOOL sucess = win32::getFileAttributesExW(_path.to_temp_wstring(), Win32_GET_FILEEX_INFO_LEVELS.STANDARD, &fileInfo)!;
            if(sucess == 0) {
                log::warning(FILE, "failed to get attributs for file '%s", _path);
                return FS_FAILED_ADD_DIR~;
            }
            is_hidden_file_or_folder = (fileInfo.dwFileAttributes & win32::FILE_ATTRIBUTE_HIDDEN) == win32::FILE_ATTRIBUTE_HIDDEN;
        $endif
        if(path::is_dir(_path))
        {
            if(is_hidden_file_or_folder || _path.basename().starts_with(".")) {
                continue; // ignore
            } else {
				// do something with the folder info
				// ...

				// go on traversing the directory tree
                if(traverse(_path)!) break;
            }
        } else { // is a file
			if(is_hidden_file_or_folder) {
                continue; // ignore file
            }

			// do something with the file
			// ...
        }
    }
    return true; // abort traverse
}

fn bool? is_hidden_file_or_folder(Path path) @local
{
	bool is_dot_folder = path.basename().starts_with(".");
	if(is_dot_folder) return true;

    $if env::WIN32:
        Win32_FILE_ATTRIBUTE_DATA fileInfo;
        Win32_BOOL sucess = win32::getFileAttributesExW(path.to_temp_wstring(), Win32_GET_FILEEX_INFO_LEVELS.STANDARD, &fileInfo)!;
        if(sucess == 0) {
            log::warning(FILE, "failed to get attributs for file '%s", path);
            return FS_FAILED_GET_FILE_ATTRIB~;
        }
        return (fileInfo.dwFileAttributes & win32::FILE_ATTRIBUTE_HIDDEN) == win32::FILE_ATTRIBUTE_HIDDEN;
    $else // handle linux
        @todo();
    $endif
}

fn HMDirectory* create_HMDirectory(Path path) @local
{
	HMDirectory* dir = mem::new(HMDirectory);
    dir.path = path::normalize((String)path).to_tpath()!!;
    dir.name = path.basename().tcopy();
    dir.id   = (int)local_directories.len();
	if(dir.id == 0) dir.id += 1;
	return dir;
}

fn void registerDirectory(Path folder_path, int idx) @inline
{
	local_directories[idx].path = folder_path.tcopy();
	local_directories[idx].name = folder_path.basename().tcopy();
}

<* 
	@param idx : "index of directory"
	@require idx >= 0 && idx < local_directories.len()
	@ensure return != null
*>
fn HMDirectory* getDirectory(int idx)
{
    return local_directories[idx];
}

fn Path getWorkDirectory(int idx) => getDirectory(AppDir.WORK).path;
fn Path getBaseDirectory(int idx) => getDirectory(AppDir.BASE).path;
fn Path getSaveDirectory(int idx) => getDirectory(AppDir.SAVE).path;
fn Path getModsDirectory(int idx) => getDirectory(AppDir.MODS).path;
fn Path getShotsDirectory(int idx) => getDirectory(AppDir.SCREENSHOTS).path;

<*
	Use getDirectoryByid in performance sensitive code... 
	@param id : "name of directory"
	@require id >= 1 && id <= local_directories.len()
*>
fn HMDirectory*? getDirectoryByid(int id)
{
    foreach(dir : local_directories) {
        if(dir.id == id) return dir;
    }
    return FS_FAILED_GET_DIR~;
}

<* 
	@param [in] name : "name of directory"
	@require name.len > 0
*>
fn HMDirectory*? getDirectoryByName(String name)
{
    foreach(dir : local_directories) {
        if(dir.name == name) return dir;
    }
    return FS_FAILED_GET_DIR~;
}

//@performance!!!! May be slow for large paths...
fn HMDirectory*? getDirectoryByPath(Path path)
{
    foreach(dir : local_directories) {
        if(dir.path == path) return dir;
    }
    return FS_FAILED_GET_DIR~;
}

fn void init_game_directories_defaults() @inline
{
    // will reserve 16 slots as minimum
    // no matter if the dir count is less...
	local_directories.reserve(DIR_COUNT);
}

fn void clearGameDirectories() 
{
    foreach(dir : local_directories) {
        if(dir.name.len) dir.clear();
    }
    local_directories.free();
    pGameDirs = null;
}

DirList local_directories @local;
DirList* pGameDirs = &local_directories;

module engine::filesystem::fs;

// region modules
import std::os;
import libc;
import game::main;
import engine::misc;
import std::io, std::io::path;
import std::collections::list;
import thirdparty::raylib5::rl;
import engine::sys::cvar;
import engine::logging::log;
import engine::platform::win32;
import engine::sys::framework::platform::platf;
// end_region

alias StringList @local = List{String};

// file list for directory listings
struct FileList (Printable) @private
{
	String basePath;
	StringList	list;
}

fn sz? FileList.to_format(&self, Formatter* f) @dynamic
{
    return f.printf("FileList(basePath: '%s', numFiles: %d)", self.basePath, self.getNumFiles());
}


fn sz FileList.getNumFiles(&self) @inline => self.list.len();

<*
    Returns a file path from the list.
    @param index : "The index into the file list."
    @require index < self.getNumFiles()
*>
fn Path? FileList.getFile(&self, uint index ) @inline => path::tnew(self.list[index]);

<*
    Return a pointer to the file list.
    @ensure return != null
*>
fn StringList*	FileList.getList(&self) => &self.list;

fn FileList*? listDirectoryFiles(String dirPath) @inline {
    FileList* dirList = mem::new(FileList, {.basePath = dirPath});
	PathList ls = path::ls(tmem, path::tnew(dirPath)!)!;
	foreach(pt : ls) {
		if(path::is_dir(pt)) dirList.list.push(pt.tcopy());
	}
	return dirList;
}

fn PathList? listDirectoryPaths(Path dirPath) => path::ls(mem, dirPath)!;

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
fn Path? ModList.getMod(&self, uint index ) => path::tnew(self.mods[index]);

<*
    Returns a mod description from a description list.
    @param index : "The index into the mod description list."
    @require index < self.descriptions.len()
*>
fn String ModList.getDescription(&self, uint index ) => self.descriptions[index];

const MODS_MAX_DESCRIPTION = 256;
<*
    Returns a list of mods found along with descriptions
    'mods' contains the directory names to be passed to fs_game
    'descriptions' contains a string to be used in the UI
*>
fn ModList* listMods() 
{
    /*
	char[ MODS_MAX_DESCRIPTION ] desc;

	StringList	dirs;
	StringList	pks;

	ModList	*list = mem::new(ModList);

	String[4] search;

	search[0] = cv_save_path.getString();
	search[1] = cv_dev_path.getString();
	search[2] = cv_base.getString();
	search[3] = cv_dev_path.getString();

	for ( int isearch = 0; isearch < 4; isearch++ ) {
		// skip empty cdpath or such, so we don't search C:\ or / -_-
		if ( search[ isearch ] == "" ) {
			continue;
		}

		dirs.clear();
		pk4s.clear();

		// scan for directories
		ListOSFiles( search[ isearch ], "/", dirs );

		dirs.Remove( "." );
		dirs.Remove( ".." );
		dirs.Remove( "base" );
		dirs.Remove( "pb" );

		// see if there are any pk files in each directory
		for( i = 0; i < dirs.Num(); i++ ) {
			idStr gamepath = BuildOSPath( search[ isearch ], dirs[ i ], "" );
			ListOSFiles( gamepath, ".pk4", pk4s );
			if ( pk4s.Num() ) {
				if ( !list->mods.Find( dirs[ i ] ) ) {
					// DG: ignore d3xp, it's added explicitly later, if available
					if ( dirs[ i ].Icmp( "d3xp" ) ) {
						list->mods.Append( dirs[ i ] );
					}
				}
			}
		}
	}

	list->mods.Sort();

	// read the descriptions for each mod - search all paths
	for ( i = 0; i < list->mods.Num(); i++ ) {

		for ( isearch = 0; isearch < 4; isearch++ ) {

			idStr descfile = BuildOSPath( search[ isearch ], list->mods[ i ], "description.txt" );
			FILE *f = OpenOSFile( descfile, "r" );
			if ( f ) {
				if ( fgets( desc, MAX_DESCRIPTION, f ) ) {
					list->descriptions.Append( desc );
					fclose( f );
					break;
				} else {
					common->DWarning( "Error reading %s", descfile.c_str() );
					fclose( f );
					continue;
				}
			}
		}

		if ( isearch == 4 ) {
			list->descriptions.Append( list->mods[ i ] );
		}
	}

	list->mods.Insert( "" );
	list->descriptions.Insert( "Doom 3 (base game)" );

	// DG: if installed, add d3xp with useful description, right below the base game
	if ( HasD3XP() ) {
		list->mods.Insert( "d3xp", 1 );
		list->descriptions.Insert( "Resurrection Of Evil (d3xp)", 1 );
	}

	assert( list->mods.Num() == list->descriptions.Num() );

	return list;
    */
	return null;
}
//////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////


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
        _file.contents_size = (usz)data.size()!;
        data.seek(0, FROM_START)!; // return to the start
        _file.contents = mem::calloc(char::size * (sz)_file.contents_size);
        char[] buffer = ((char*)_file.contents)[:_file.contents_size];
        data.read(buffer[:_file.contents_size])!;
        return ((String)buffer).tcopy();
    } else{
        log::error(FILE, "Cannot open file: %s", filepath);
    }
    
    return (String)"";
}

fn String? readEntireFile(String filepath) @inline
{
    char[] buffer;
    fault excuse = @catch(file::load_buffer(filepath, buffer));
    
    return string::format(mem, "%s", buffer);
}

fn String? readEntireFile2(File file) @inline 
{
    usz contents_size = (usz)file.size()!;
    file.seek(0, FROM_START)!; // return to the start
    char[] buffer = mem::temp_array(char, char::size * (sz)contents_size);
    file.read(buffer[:contents_size])!;
    return ((String)buffer).tcopy();
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
        return FS_FAILED_SAVE_DATA~;
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
        return FS_FAILED_SAVE_DATA~;
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
    if(@catch(fs::makeFile(local_game.app_save_folder.tconcat(platf::PATHSEPERATOR_STR).tconcat("READ_ME.txt"), &buffer))) {
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

// Get file size in bytes
fn uint getFileSize(String fileName) @inline {
    CInt result = rl::getFileLength(fileName.zstr_tcopy());
    return (result) ? (uint)result : 0u;
}

// Get string view of extension for a filename (includes dot: '.png')
fn String getFileExtension(String fileName) @inline {
    return rl::getFileExtension(fileName.zstr_tcopy()).str_view();
}

// Check file extension (including point: .png, .wav)
fn bool isFileExtension(String fileName, ZString ext) @inline {
    return rl::isFileExtension(fileName.zstr_tcopy(), ext);
}

<*
	@param [in] str : "string to remove extension"
*>
fn String remove_extension(String str) @inline {
	if(!str.contains(".")) {
		log::warning(FILE, "Trying to remove extension from '%s' but it has none", str);
		return str;
	}
	return str.strip_end(getFileExtension(str));
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
fn String getDirectoryPath(String filePath) @inline {
    String result = string::tformat("%s", rl::getDirectoryPath(filePath.zstr_tcopy()));
    if(!result.ends_with(platf::PATHSEPERATOR_STR)) {
        result = result.tconcat(platf::PATHSEPERATOR_STR);
    }
    return result;
}

<*
	Get previous directory path for a given path (uses static string)
	@param dirPath : "path string to the current directory"
	@ensure result.ends_with(platf::PATHSEPERATOR_STR) 
*>
fn String getPrevDirectoryPath(String dirPath) @inline {
    String result = string::tformat("%s", rl::getPrevDirectoryPath(dirPath.zstr_tcopy()));
    if(!result.ends_with(platf::PATHSEPERATOR_STR)) {
        result = result.tconcat(platf::PATHSEPERATOR_STR);
    }
   return result;
}

<*
	Get current working directory (uses static string)
	This is the directory where the application is running FROM.
	It is not the same as the application directory, which is where the executable is located.
	This is because the working directory can change during runtime, for example, 
	if the user changes it in the settings or runs the application from a shortcut in a different directory.
	@ensure result.ends_with(platf::PATHSEPERATOR_STR) 
*>
fn String getWorkingDirectory() @inline {
    String result = rl::getWorkingDirectory().str_view();
    if(!result.ends_with(platf::PATHSEPERATOR_STR)) {
        result = result.tconcat(platf::PATHSEPERATOR_STR);
    }
    return result.tcopy();
}

<*
	Get the directory of the running application (uses static string)
	This is the directory where the executable is really located.
	@ensure result.ends_with(platf::PATHSEPERATOR_STR)
*>
fn String getApplicationDirectory() @inline {
    String result = rl::getApplicationDirectory().str_view();
    if(!result.ends_with(platf::PATHSEPERATOR_STR)) {
        result = result.tconcat(platf::PATHSEPERATOR_STR);
    }
    return result.tcopy();
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
        return FS_FAILED_MAKE_DIR~;
    }
}

// Change working directory, return true on success
fn bool? changeDirectory(String dir) 
{
    if(rl::changeDirectory(dir.zstr_tcopy())) {
        return true;
    } else {
        return FS_FAILED_CHANGE_DIR~;
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
            file_count = (int)files.count;
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
        for(int i = 0; i < (int)files.count; i++) 
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
        if(from.ends_with(platf::PATHSEPERATOR_STR) == false) {
            from = from.tconcat(platf::PATHSEPERATOR_STR);
        }
        if(to.ends_with(platf::PATHSEPERATOR_STR) == false) {
            to = to.tconcat(platf::PATHSEPERATOR_STR);
        }
        
        String files_dir = game::pContext.app_root_dir.tconcat(from);
        String files_to  = game::pContext.app_root_dir.tconcat(to);

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
fn Path? newPath(String _path) => path::new(mem, _path);
// #endregion

fn bool isFileLink(String asPath)
{
	$if env::POSIX:
		return (posix::chdir(asPath.zstr_tcopy()) & posix::DT_LNK) ? true : false;
	$else
		return win32::is_symblink(asPath);
	$endif
}


macro openBrowserWindow ( String asURL )
{
	$switch:
		$case env::WIN32:
			win32::shellExecuteA(null, "open", (ichar*)&asURL.zstr_tcopy()[0], null, null, Sw.SHOWNORMAL.ordinal );
		$case env::LINUX:
			String asTemp = "./openurl.sh ".tconcat(asURL);
			system(asTemp.zstr_tcopy());
		$case env::MACOS:
			String asTemp = "open ".tconcat(asURL);
			system(asTemp.zstr_tcopy());
	$endswitch
}

// NOTE(HM) 
// in windows "Special Path" is the MyDocuments folder, 
// in Linux is the HOME folder...
fn String? getSystemSpecialPath()
{
$if env::WIN32:
    return win32::getSystemSpecialPath()!;
$else
    return env::get_home_dir(tmem)!;
$endif
}
