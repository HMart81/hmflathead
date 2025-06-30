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

module game::files::ini;

// region C3 imports
import std::io;
import std::ascii;
import std::io::file;
import std::collections::list;
import std::collections::tuple;
// end_region

// region custom imports
import game::main;
import thirdparty::raylib5::rl;
import engine::misc;
import engine::sys::cvar;
import engine::logging::lgr;
// end_region

/*
// File system functions
fn bool fileExists(ZString fileName)
fn bool directoryExists(ZString dirPath)
fn bool isFileExtension(ZString fileName, ZString ext)   // Check file extension (including point: .png, .wav)
fn int getFileLength(ZString fileName)                   // Get file length in bytes (NOTE: GetFileSize() conflicts with windows.h)
fn ZString getFileExtension(ZString fileName)            // Get pointer to extension for a filename string (includes dot: '.png')
fn ZString getFileName(ZString filePath)                 // Get pointer to filename for a path string
fn ZString getFileNameWithoutExt(ZString filePath)       // Get filename string without extension (uses static string)
fn ZString getDirectoryPath(ZString filePath)            // Get full path for a given fileName with path (uses static string)
fn ZString getPrevDirectoryPath(ZString dirPath)         // Get previous directory path for a given path (uses static string)
fn ZString getWorkingDirectory()                         // Get current working directory (uses static string)
fn ZString getApplicationDirectory()                     // Get the directory of the running application (uses static string)
fn bool changeDirectory(ZString dir)                     // Change working directory, return true on success
fn bool isPathFile(ZString path)                         // Check if a given path is a file or a directory
fn FilePathList loadDirectoryFiles(ZString dirPath)      // Load directory filepaths
fn FilePathList loadDirectoryFilesEx(char *basePath, char *filter, bool scanSubdirs) // Load directory filepaths with extension filtering and recursive directory scan
fn void unloadDirectoryFiles(FilePathList files)         // Unload filepaths
fn bool isFileDropped()                                  // Check if a file has been dropped into window
fn FilePathList loadDroppedFiles()                       // Load dropped filepaths
fn void unloadDroppedFiles(FilePathList files)           // Unload dropped filepaths
fn long getFileModTime(char *fileName)                   // Get file modification time (last write time)
*/

typedef INIFile   = inline io::File;

alias SectionListPtr = List{IniSection}*;

<*
 @param [in] key : `The cmd name`
 @param [&in] inifile : `The ini file data`
 @require key != ""
 @deprecated
*>
fn String getIniKey(String key, FileData* inifile) {
    foreach(section : inifile.sections) {
        foreach(inicmd : section.cmds) {
            if(inicmd.cmd.first == key) {
                return inicmd.cmd.second;
            }
        }
    }
    
    return "";
}

faultdef MISSING_FILE_PATH,
         INI_FILE_LOAD_FAILED,
         FAILED_OPEN_FILE,
         FAILED_READ_FILE,
         FAILED_CLOSE,
         FAILED_GET_FILE_SIZE,
         MALFORMED_INI_FILE,
         MISSING_DATA_BUFFER,
         INVALID_TOKEN;


enum ParseLineType : char  {
    NAME,
    COMMAND,
    COMMENT
}

// data types
const int BOOLEAN @private = 1;
const int INT     @private = 2;
const int FLOAT   @private = 3;
const int STRING  @private = 4;

// syntax main characters
const String COMMENT_CHAR       @local = ";";
const String SECTION_NAME_START @local = "[";
const String SECTION_NAME_END   @local = "]";
const String ASSIGNMENT_CHAR    @local = "=";
const String SPACE_CHAR         @local = " ";
const String EMPTY_STR          @local = "";
const String STR_CHAR           @local = "\"";


alias ListIniSectionPrts @local = List{IniSection*};
alias ListIniCMDPrts     @local = List{IniCMD*};
alias IniCmdData         @local = Tuple{String, String};
alias game               @local = main::gpGame;

<*
* DOC Final parsed data used by the engine
*>
struct FileData {
    ListIniSectionPrts sections;
}

<*
  @param [&in] section : "a new section adress to save into the section adresses list"
*>
fn void FileData.register(&self, IniSection* section) @local @inline {
    self.sections.push(section);
}

fn IniSection* FileData.getSection(&self, String name) @local {
    foreach(section : self.sections) {
        if(section.name == name) {
            return section;
        } else if(section.isLinked()) { // first section name didn't match see if it's child is the one
            if(section.next.name == name) {
                return section.next;
            }
        }
    }

    return null;
}

fn bool FileData.hasSection(&self, String name) @local {
    foreach(section : self.sections) {
        if(section.name == name) {
            return true;
        } else if(section.isLinked()) { // first section name didn't match see if it's child is the one
            if(section.next.name == name) {
                return true;
            }
        }
    }
    return false;
}

<*
 @param key : `The cmd name`
 @require key != ""
*>
fn String FileData.getValue(&self, String key) 
{
   ListIniCMDPrts* cmds;

    foreach(section : self.sections) 
    {
        // if the section is linked, we need to use the child section cmds
        if(section.isLinked()) {
            cmds = &section.next.cmds; // use the child section cmds
        } else {
            cmds = &section.cmds; // use the current section cmds
        }

        foreach(inicmd : *cmds) {
            if(inicmd.cmd.first == key) {
                return inicmd.cmd.second.trim("\"");
            }
        }
    }
    
    return "";
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn float? FileData.getFloatValue(&self, String key) {
    ListIniCMDPrts* cmds;

    foreach(section : self.sections) {
        // if the section is linked, we need to use the child section cmds
        if(section.isLinked()) {
            cmds = &section.next.cmds; // use the child section cmds
        } else {
            cmds = &section.cmds; // use the current section cmds
        }

        foreach(inicmd : *cmds) {
            if(inicmd.cmd.first == key) {
                assert(inicmd.type == FLOAT);
                return inicmd.cmd.second.to_float()!;
            }
        }
    }
    
    return 0.0f;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn int? FileData.getIntValue(&self, String key) {
    ListIniCMDPrts* cmds;

    foreach(section : self.sections) {
        // if the section is linked, we need to use the child section cmds
        if(section.isLinked()) {
            cmds = &section.next.cmds; // use the child section cmds
        } else {
            cmds = &section.cmds; // use the current section cmds
        }

        foreach(inicmd : *cmds) {
            if(inicmd.cmd.first == key) {
                assert(inicmd.type == INT);
                return inicmd.cmd.second.to_int()!;
            }
        }
    }
    
    return 0;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn bool? FileData.getBoolValue(&self, String key) {
    ListIniCMDPrts* cmds;

    foreach(section : self.sections) {
        // if the section is linked, we need to use the child section cmds
        if(section.isLinked()) {
            cmds = &section.next.cmds; // use the child section cmds
        } else {
            cmds = &section.cmds; // use the current section cmds
        }

        foreach(inicmd : *cmds) {
            if(inicmd.cmd.first == key) {
                assert(inicmd.type == BOOLEAN);
                String value = inicmd.cmd.second;
                return (value == "true" || value == "1") ? true : false;
            }
        }
    }
    
    return false;
}

struct IniSection { // everything after a [name]
    String name;
    ListIniCMDPrts cmds;
    
    bool linked;
    IniSection* next;
}

<*
  @param [&in] cmd : "a new cmd adress to save into the cmd adresses list"
*>
fn void IniSection.register(&self, IniCMD* cmd) @local @inline {
    self.cmds.push(cmd);
}

<*
  @param [&in] other : "pointer to another section"
*>
fn void IniSection.link(&self, IniSection* other) @local @inline {
    self.next   = other;
    self.linked = true;
}

fn bool IniSection.isLinked(&self) @local @inline {
    return self.linked;
}

fn bool IniSection.hasChild(&self) @local @inline {
    return self.isLinked();
}

fn void IniSection.freeChild(&self) @local @inline {
    if(!self.isLinked()) return;
    
    // first free the child section cmds data if any
    if(self.next.cmds.len()) {
        foreach(cmd : self.next.cmds) {
            mem::free(cmd);
        }
    }
    // then free the child section data itself
    mem::free(self.next);
}

struct IniCMD {
    int type;
    IniCmdData cmd;
}

<*
* DOC where_index is the index in the string where the comment starts
*>
fn bool detect_comment_char_in_line(String str, usz where_index = 0) @local @inline {
    if(string::char_in_set(';', str)) {
        where_index = str.index_of_char(';')!!;
        return true;
    }
    
    return false;
}

<*
* DOC where_index is the index in the string where the next section starts
*>
fn bool detect_child_section_in_name(String str, usz where_index = 0) @local @inline 
{
    if(string::char_in_set('.', str)) {
        where_index = str.index_of_char('.')!!;
        // skip the dot
        where_index += 1;
        return true;
    }
    
    return false;
}

/*
* DOC String is a "slice" and as such is just a struct with a pointer and a len.
* Slices and Array's ARE NOT exactly the same
* String[] is a slice (a pointer and a len) 
* String[*] is a C like array (a pointer to the first data in the array, with no len). 
*/
fn String[]? cutIniFileByLines(String filepath, bool isrelative) @local {
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }
    
    if(isrelative) filepath = game.app_base_folder.tconcat(filepath);
    
    INIFile file_data = (INIFile)file::open(filepath, "r")!;
    defer (void)file_data.close();
    // if(catch excuse = file_data) {
        // lgr::warning(Where.FILE, "Unable to open ini file: %s with excuse: %s", filepath, excuse);
        // return IniFault.FAILED_OPEN_FILE?;
    // }
    
    String? entire_file = misc::readEntireFileX(filepath);
    if(catch excuse = entire_file) {
        lgr::warning(Where.FILE,  "Unable to read data from file: %s with excuse: %s", filepath, excuse);
        return FAILED_READ_FILE?;
    }
    
    // cut the data into individual string slices
    String[] lines = misc::cut_by_newline(entire_file);
    // remove any empty char for the start or end of each line
    foreach( &line : lines) {
        (*line) = line.trim();
    }
    
    if(lines.len) {
        return lines;
    }  else {
        return FAILED_READ_FILE?;
    }
}

fn FileData*? parse_file(String[] lines) @local {
    FileData* file_data = mem::new(FileData);
    
    foreach(line : lines) {
        if(line == "") continue;
        if(line.starts_with(COMMENT_CHAR)) continue; // to next line
        
        //
        bool has_comment = detect_comment_char_in_line(line);
        if(has_comment) {
            // split line by the comment char
            String[] split = line.tsplit(COMMENT_CHAR);
            // now clean the start and end of line ignoring the comment section
            split[0] = split[0].trim();
            line = split[0].tcopy();
        }
        
        if(line.starts_with(SECTION_NAME_START)) {
            parse_section_name(line, file_data);
        } else {
            parse_section_cmd(line, file_data);
        }
        
    }
    
    return file_data;
}

<*
 * DOC Parse a section name from a line of text
 *
  @param [in] line    : "the line of text to parse"
  @param [inout] file : "the file data structure to register the section into"
  @require file != null && line.len > 0
*>
fn void parse_section_name(String line, FileData* file) @local 
{
    String section_name = line.trim("[]");
    if(section_name.contains("."))
    {
        String[] split = section_name.tsplit(".");
        // WARNING(HM) 
        // child sections (section_parent.section_child) ARE NOT registered by the main file 
        // they are only acessible thought their parent section.
        // Also any cmds defined in a dotted/dual ini section, are not registered 
        // to the parent section but the child section (section name after the dot), 
        // the parent section cmds stay empty, it only serves has a link/path to the real section
        // where the cmds will be saved.
        IniSection* section1, section2;

        String parent_section_name = split[0];
        
        if(file.hasSection(parent_section_name)) {
            section1 = file.getSection(parent_section_name);
        } else {
            // create a new main section as well
            section1      = mem::new(IniSection);
            section1.name = parent_section_name;
            file.register(section1);
        }
        
        // create the child section to link to
        section2 = mem::new(IniSection);
        section2.name = split[1];
        section1.link(section2);
    } else {
        // create a single section
        IniSection* section = mem::new(IniSection);
        section.name = section_name;
        file.register(section);
    }
}

struct IniCMD_TempData @local {
    int type;
    String key;
    String value;
}

<*
  @param [inout] file
  @require file != null
 *>
fn void parse_section_cmd(String line, FileData* file) @local
{
    IniCMD_TempData cmdTempData;
    
    //String[] tokens = misc::cut_by_spaces(line);
    String[] tokens = line.tsplit(ASSIGNMENT_CHAR);
    
    foreach(int i, word : tokens)
    {
        if(word == ASSIGNMENT_CHAR || word == SPACE_CHAR || word.len == 0) continue;

        word = word.trim(); // cleans the word
        // NOTE(HM) we don't care about comments here, they are ignored
        
        // key is always the first word
        bool is_key = i == 0;
        if(is_key) {  
            cmdTempData.key = word;
            continue; // to next word
        }
        
        // data is always the next word after the ASSIGNMENT_CHAR '=' ignored above
        // so shouldn't be part of the data at this point
        cmdTempData.value = word;
        
        // this shouldn't happen but just in case... 
        // if we think we are writting C/C++ or C3 code
        // and put a semicolon at the end of the line...
        if(word.ends_with(COMMENT_CHAR)) {
            lgr::warning(Where.CONSOLE, "Ini File: Semicolon found at end of cmd: %s\n\t-> In ini files, \';\' is for single line comments.", cmdTempData.key);
            cmdTempData.value = cmdTempData.value.strip_end(COMMENT_CHAR);
        }
        
        break; // NOTE(HM) this should ignore any data after the cmd_value (like comments...)
    }
    
    // from here we are dealing with the cmd value
    get_cmd_type_from_value(&cmdTempData);
    
    // just in case assert the cmd data is valid
    assert(cmdTempData.type >= 1 && cmdTempData.type <= 4);
    assert(cmdTempData.key != "");
    // cmds are allowed to have empty values
    
    // register the cmd here
    IniCMD* cd    = mem::new(IniCMD);
    cd.type       = cmdTempData.type;
    cd.cmd.first  = cmdTempData.key;
    cd.cmd.second = cmdTempData.value;
    usz len = (*file).sections.len();
    IniSection* last_section_ptr = (*file).sections[len-1];
    if(last_section_ptr.isLinked()) {
        last_section_ptr.next.register(cd);
    } else {
        last_section_ptr.register(cd);
    }
}

<*
 * DOC Get the type of a cmd value from its string representation
 *
  @param [inout] cmd_data : "the cmd data to set the type"
  @require cmd_data != null
  @ensure cmd_data.type != 0
 *>
fn void get_cmd_type_from_value(IniCMD_TempData* cmd_data) @local
{
    String value = (*cmd_data).value;
    
    // default type is integer
    cmd_data.type = INT;
    
    if(value == "" || value == "true" || value == "false") {
        cmd_data.type = BOOLEAN;
        return;
    }
    
    if(value.starts_with(STR_CHAR)) {
        cmd_data.type = STRING;
        // just in case
        testCmdValueStringValidity(value, "");
    }
    else if(value.len >= 2) {
         // see if is a float and ovarride the type if necessary
        if(string::char_in_set('.', value))  cmd_data.type = FLOAT;
    }
}

<*
 * DOC Create a init file data structure for easy parsing
 *
  @param [in] filepath
  @require filepath.len >= 3 "The file path must be at least 3 characters long"
 *>
fn FileData*? load(String filepath, bool isrelative = true) {
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }
    
    String[]? data = cutIniFileByLines(filepath, isrelative);
    if(catch excuse = data) {
        lgr::warning(Where.FILE,  "Unable to load file %s with excuse: %s", filepath, excuse);
        return INI_FILE_LOAD_FAILED?;
    }
    
    //data is valid from here
    return parse_file(data);
}




<*
 * Create a init file data structure for easy parsing
 *
  @param [in] filepath
  @require filepath.len >= 3 "The file path must be at least 3 characters long"
 *>
fn FileData*? _load(String filepath, bool isrelative = true) @deprecated {
    if(filepath == "") {
        return MISSING_FILE_PATH?; // does this even happens when we have a contract in place?
    }
    
    if(isrelative) filepath = main::gpGame.app_base_folder.tconcat(filepath);
    
    // first get the file raw data WARNING(HM) (comes with garbage at the end)
    String entire_data = misc::readEntireFileX(filepath)!;
    if(entire_data.len)
    {
        // cut the data into individual strings
        String[] lines = misc::cut_by_newline(entire_data);
        
        if(lines.len == 0) {
            return MALFORMED_INI_FILE?;
        }
        
        FileData* ini_file = mem::new(FileData);
        
        int section_index = -1; // NOTE: used to indentify sections
        
        foreach(&line : lines) {
        
            // ignore empty lines or comments
            if(line.len == 0 || line.starts_with(COMMENT_CHAR)) continue;
            
            // found a section name/start
            if(line.starts_with(SECTION_NAME_START))
            {
                // create the section
                IniSection* section = mem::new(IniSection);
                section.name = (*line)[1..(*line).index_of_char(SECTION_NAME_END[0])! - 1];//(*line).strip(SECTION_NAME_START).strip_end(SECTION_NAME_END).copy();
                section_index += 1; // sets its "id" using the index
                // register it's adress into the File
                ini_file.register(section);
                
                continue; // to next line
            }
            
            // now handle the section comands
            // we have a previous section to assign values too
            if(ini_file.sections[section_index] != null)
            {
                int        cmd_type;
                String     cmd_id;
                String     cmd_value;
                
                // divide each cmd into small peaces for easy parsing
                String[] tokens = (*line).tsplit(SPACE_CHAR);
                
                assert(tokens.len >= 1);
                
                // Get cmd ID and value
                foreach(int i, String token : tokens)
                {
                    if(token == ASSIGNMENT_CHAR || token == SPACE_CHAR || token.len == 0) continue;
                    
                    // cmd_id is always the first token in the array
                    if(i == 0) { 
                        cmd_id = token;
                        
                        continue; // to next token in the line
                    }
                    
                    // data is always the token after the '='
                    cmd_value = token;
                    
                    // just in case, we think we are writting C/C++ or C3 code
                    // and put a semicolon at the end of the line...
                    if(cmd_value.ends_with(COMMENT_CHAR)) {
                        lgr::warning(Where.CONSOLE, "Ini File: A Semicolon was found at end of cmd: %s\n\t-> In ini files, \';\' is for single line comments.", cmd_id);
                        cmd_value = cmd_value.strip_end(COMMENT_CHAR);
                    }
                    
                    break; // NOTE(HM) this should ignore any data after the cmd_value (like comments...)
                }
                
                if(cmd_id.len != 0 && cmd_value.len == 0) {
                        String type_name;
                        foreach(cv: cvar::cvars) {
                            if(cmd_id == cv.name) {
                                switch(cv.type) {
                                    case FLOAT:
                                        type_name = "float";
                                    case INT:
                                        type_name = "int";
                                    case BOOLEAN:
                                        type_name = "boolean";
                                    case STRING:
                                        type_name = "string";
                                    default:
                                        unreachable("Ini file: Unknown type %s for %s.", cv.type, cmd_id);
                                }
                            }
                        }
                        
                        unreachable("Ini File: cmd: %s has no value!\n\t-> Supported value is \"%s\".", cmd_id, type_name);
                }
                
                // now set what type of cmd value is
                // bool cmd_value_not_empty = cmd_value != "";
                // if(cmd_value_not_empty) 
                {
                    // integer is always default, unless overriden bellow
                    cmd_type = INT;
                    
                    if(cmd_value == "true" || cmd_value == "false") {
                        cmd_type = BOOLEAN;
                    }
                    else if(cmd_value.starts_with(STR_CHAR)) {
                        cmd_type = STRING;
                        testCmdValueStringValidity(cmd_value, cmd_id);
                    }
                    else if(cmd_value.len >= 3) {
                        // see if is a float and ovarride the type if necessary
                        if(string::char_in_set('.', cmd_value)) cmd_type = FLOAT;
                    }
                }
                
                assert(cmd_type != 0 && cmd_id != EMPTY_STR && cmd_value != EMPTY_STR);
                
                IniCMD* cd = mem::new(IniCMD, { .type = cmd_type, .cmd.first = cmd_id, .cmd.second = cmd_value});
                ini_file.sections[section_index].register(cd);
                cmd_id    = "";
                cmd_value = "";
                
                continue; // to next line to handle a new cmd if any
            }
        }
        
        return ini_file;
    }
    
    return null;
}

fn void testCmdValueStringValidity(String value, String id) {
    if(value.ends_with(STR_CHAR)) return; // all is well do nothing
    
    if(value.ends_with("\0")) {
        char* ch = value[:value.len - 2];
        if(*ch != '"') {
            io::printfn("cmdline: Malformed <string> \"%s\" assigned to \"%s\", it should start and end with \'\"\'.",*ch, id);
            // unreachable calls should be put AFTER code that you expect to run!
            // this is because assert(false) is not available anymore and was deprected.
            unreachable();
        }
    } else {
        io::printfn("cmdline: Malformed value <string> assigned to \"%s\", it should start and end with \'\"\'.", id);
        // unreachable calls should be put AFTER code that you expect to run!
        // this is because assert(false) is not available anymore and was deprected.
        unreachable();
    }
}

<*
  @param [&in] inifile : "is not really a file but a adress of a data structure in memory"
*>
fn void unload(FileData* inifile) {
    if(inifile.sections.len()) {
        foreach(section : inifile.sections) {
            if(section.isLinked()) 
            {
                section.freeChild();
                // and lastly free ourself
                // just in case
                assert(section.cmds.len() == 0);
                mem::free(section);
            } else {
                // first free the section cmds data
                if(section.cmds.len()) {
                    foreach(cmd : section.cmds) {
                        mem::free(cmd);
                    }
                }
                // then free the section itself
                mem::free(section);
            }
        }
    }
}


<*
 * Create a init file structure for easy parsing
 *
  @param [in] path
  @require path.len > 0 "The path must be at least 1 character long"
 *>
fn bool? populate(FileData* file_data, String path) @deprecated {
    if(file_data == null) {
        return MISSING_DATA_BUFFER?;
    }

    if(path == "") {
        return MISSING_FILE_PATH?;
    }
    
    // first get the file raw data (comes with garbage at the end)
    //char[] data = file::load_new(path)!;
    String entire_data = (String)file::load_temp(path)!;
    
    if(entire_data.len)
    {
        // now cut the data into individual strings
        String[] lines = misc::cut_by_newline(entire_data);
        
        if(lines.len == 0) {
            return MALFORMED_INI_FILE?;
        }
        
        IniSection* section;
        String old_section_name;
        String* current_editing_section_name;

        foreach(String* &line : lines) {
            //*line = (*line).trim();
            
            if(line.len == 0) continue;
            
            if(line.starts_with(";")) continue; // ignore comments
            
            // found a section name
            if(line.starts_with("["))
            {
                section      = mem::new(IniSection);
                section.name = (*line).strip("[").strip_end("]").tcopy();
                current_editing_section_name = &section.name;
                continue;
            }
            
            // handle comands
            if(section != null) // we have a previous section to assign the values too
            {
                int    cmd_type;
                String cmd_id;
                String cmd_value;
                
                String[] tokens = (*line).tsplit(" ");
                
                // Get cmd ID and value
                foreach(int i, String token : tokens) 
                {
                    token = token.trim(); // cleans the token
                    
                    if(token.len == 0 || token == "=") continue;
                    
                    // cmd_id should be always the first token in the array
                    if(i == 0) { 
                        cmd_id = token;
                        continue;
                    }
                    
                    // data is always the token after the '='
                    cmd_value = token;
                    
                    if(cmd_value == "") {
                        unreachable();
                    }
                    
                    break; 
                }
                
                // Set what value type it is
                bool cmd_value_not_empty = cmd_value != "";
                if(cmd_value_not_empty) 
                {
                    // Data is always a int unless overriden bellow
                    cmd_type = INT;
                    
                    if(cmd_value == "true" || cmd_value == "no") {
                        cmd_type = BOOLEAN;
                    }
                    else if(cmd_value.starts_with("\"")) {
                        cmd_type = STRING;
                        if(cmd_value.ends_with("\"")) {
                            // go on
                        } else {
                            io::printfn("cmdline: Malformed value <string> assigned to \"%s\", it should end with a comma \".", cmd_id);
                            // unreachable calls should be put AFTER code that you expect to run!
                            // this is because assert(false) is not available anymore and was deprected.
                            unreachable();
                        }
                    }
                    else if(cmd_type == INT && cmd_value.len >= 3) {
                        // see if is a float and ovarride the type if necessary
                        foreach(char chr : cmd_value) {
                            // bigger number
                            if(chr == '.') {
                                cmd_type = FLOAT;
                                break;
                            }
                        }
                    }
                }
                
                section.cmds.push(mem::new(IniCMD, { .type = cmd_type, .cmd.first = cmd_id, .cmd.second = cmd_value}));
                /*if ((*file_data).sections.len()) 
                {
                    bool already_pushed = false;
                    foreach (IniSection* &it : (*file_data).sections)
                    {
                        if (it && (*it).name == cmd_id) {
                            already_pushed = true;
                            break;
                        }
                    }

                    if(already_pushed == false) (*file_data).sections.push(*section);
                } else {
                    (*file_data).sections.push(*section);
                }*/
                if ((*file_data).sections.len() == 0 || old_section_name != *current_editing_section_name) {
                    (*file_data).sections.push(section);
                    old_section_name = (*current_editing_section_name).tcopy();
                }
                // done go to next line
                continue;
            }
        }
        
        return true;
    }
    
    return false;
}

fn bool FileData.is_valid(&self) @inline {
    return self.sections.is_empty() == false;
}

fn void FileData.free(&self) {
    unload(self);
}
