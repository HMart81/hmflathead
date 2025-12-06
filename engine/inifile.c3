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
import std::collections::list, std::collections::pair;
// end_region

// region custom imports
import game::main;
import thirdparty::raylib5::rl;
import engine::misc;
import engine::filesystem::fs;
import engine::sys::cvar;
import engine::logging::log;
// end_region

const String SETTINGS_FILE_NAME  @Hardcode = "user.ini";

// default safe settings
const String SAFE_SETTINGS @Hardcode = `
[video]
maxFPS          = 120
; vsync is just a hint and may not apply, depends on window mode you'r in.
; window mode, borderless fullscreen and native fullscreen, equal 0, 1 and 2 values respectively.
; do not support vsync.
vsync           = true
; r_mode is the index into the screen resolution array, r_mode = -1 means use custum values. 
r_mode          = 4
r_custom_width  = 800
r_custom_heigth = 600
r_fullscreen    = 0
; only works in window mode
;r_window_resizable = true (doesn't work anymore...)
; msaa only supports 0 or 4 as values
; msaa also depends on window mode you'r in
; window and borderless fullscreen (r_fullscreen = 0 and r_fullscreen = 1)
; do not support msaa.
msaa            = 4
gamma           = 1.0
brightness      = 1.0


; action = key name
[keys]
move_up    = "KEY_W"
move_down  = "KEY_S"
move_left  = "KEY_A"
move_right = "KEY_D"
quit       = "KEY_F10"
editor     = "KEY_F1"
quicksave  = "KEY_F5"
quickload  = "KEY_F9"
`;

alias INIFile = io::File;

alias SectionListPtr = List{IniSection}*;

<*
 @param [in] key : `The cmd name`
 @param [&in] inifile : `The ini file data`
 @require key != ""
 @deprecated
*>
fn String getIniKey(String key, ConfigFile* inifile) {
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
alias IniCmdData         @local = Pair{String, String};
alias game               @local = main::gpGame;


struct Config_Flags @local  // flags used to store config file state
{
    bool is_modified; // if the config file has been modified since it was loaded
}

<*
* DOC Final parsed config data used by the engine
*>
struct ConfigFile {
    String path; // the path to the config file
    ListIniSectionPrts sections;
    Config_Flags flags; // if the config file has been modified since it was loaded
}

<*
  @param [&in] section : "a new section adress to save into the section adresses list"
*>
fn void ConfigFile.register(&self, IniSection* section) @local @inline {
    self.sections.push(section);
}

<*
  @param [in] name : " name of the new section to create"
  @ensure return != null
*>
fn IniSection* ConfigFile.createSection(&self, String name) @local @nodiscard
{
    if(self.hasSection(name)) {
        log::warning(FILE, "Section %s already exists in config file %s.", name, self.path);
        return self.getSection(name);
    }

    // create a new section and register it
    IniSection* section = mem::new(IniSection, { .name = name });
    self.register(section);
    return section;
}

<*
    @UNTESTED
    @param [&in] section : "the new section to save into the file"
*>
fn void ConfigFile.addSection(&self, IniSection* section) @local @inline 
{
    if(self.hasSection(section.name)) {
        log::warning(FILE, "Cant add section %s already exists in config file %s.", section.name, self.path);
        return;
    }

    INIFile? cfg = fs::openFile(self.path, fs::FILE_READ_WRITE);
    defer (void)cfg.close();
    if(catch excuse = cfg) {
        log::warning(FILE, "failed to open config file %s to add section %s.", self.path, section.name);
        return;
    }

    usz len = (usz)fs::getFileSize(self.path);
    if(len) 
    {
        char* buffer = (char*)mem::malloc( len * char.sizeof);
        defer mem::free(buffer);
        
        file::load_buffer(self.path, buffer[:len])!!;
        String result = string::tformat("%s", buffer);
        // if the section is linked, we need to use the write the child name
        if(section.isLinked()) {
            result = result.tconcat(string::tformat("\n[%s.%s]", section.name, section.next.name));
        } else {
            result = result.tconcat(string::tformat("\n[%s]", section.name));
        }
        cfg.write(result[:result.len])!!;
    } else {
        $if $defined(_DEBUG):
        unreachable("zero file size found!");
        $endif
    }
}

<*
  @param [in] name : " name of the new section to get"
*>
fn IniSection* ConfigFile.getSection(&self, String name) @local {
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

<*
  @param [in] name : " name of the new section to look for"
*>
fn bool ConfigFile.hasSection(&self, String name) @local {
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
    @param [in] name : `The section name to add the cmd to`
    @param [&in] cmd : `The cmd to add to the section`
    @require name != ""
*>
fn void ConfigFile.addToSection(&self, String name, IniCMD* cmd)
{
    if(self.hasSection(name))
    {
        IniSection* section = self.getSection(name);
        if(section.isLinked()) {
            section.next.register(cmd); // register the cmd to the child section cmds
        } else {
            section.register(cmd); // register the cmd to the current section cmds
        }
        self.markModified(); // mark the config as modified
        return;
    }
}

fn void ConfigFile.freeChildSections(&self) @local
{
    foreach(section : self.sections) {
        if(section.isLinked()) {
            section.freeChild(); // free the child section cmds and data
        }
    }
}

fn void ConfigFile.markModified(&self) @local => self.flags.is_modified = true;
fn bool ConfigFile.isModified(&self) => self.flags.is_modified;

<*
 @param [in] key : `The cmd name`
 @param [in] default_value : `The fallback value`
 @require key != ""
*>
fn String ConfigFile.getValue(&self, String key, String default_value = "") @local
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
    
    return default_value;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn float? ConfigFile.getFloat(&self, String key, float default_value = 0.0f) {
    ListIniCMDPrts* child_cmds;

    foreach(section : self.sections) 
    {
        // if the section is linked, we need to loop the child section cmds instead
        if(section.isLinked())
        {
            child_cmds = &section.next.cmds; // use the child section cmds
            if(child_cmds.len() == 0) continue; // no cmds in this section
            foreach(inicmd : *child_cmds)
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == FLOAT);
                    return inicmd.cmd.second.to_float()!;
                }
            }
        } 
        else
        {
            // use the current section cmds
            if(section.cmds.len() == 0) continue; // no cmds in this section
            // else loop the current section cmds
            foreach(inicmd : section.cmds) 
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == FLOAT);
                    return inicmd.cmd.second.to_float()!;
                }
            }
        }
    }
    
    return default_value;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn int? ConfigFile.getInt(&self, String key, int default_value = -1) {
    ListIniCMDPrts* child_cmds;

    foreach(section : self.sections) 
    {
        // if the section is linked, we need to loop the child section cmds instead
        if(section.isLinked())
        {
            child_cmds = &section.next.cmds; // use the child section cmds
            if(child_cmds.len() == 0) continue; // no cmds in this section
            foreach(inicmd : *child_cmds)
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == INT);
                    return inicmd.cmd.second.to_int()!;
                }
            }
        } 
        else
        {
            // use the current section cmds
            if(section.cmds.len() == 0) continue; // no cmds in this section
            // else loop the current section cmds
            foreach(inicmd : section.cmds) 
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == INT);
                    return inicmd.cmd.second.to_int()!;
                }
            }
        }
    }
    
    return default_value;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn bool? ConfigFile.getBool(&self, String key, bool default_value = false) 
{
    ListIniCMDPrts* child_cmds;

    foreach(section : self.sections) 
    {
        // if the section is linked, we need to loop the child section cmds instead
        if(section.isLinked())
        {
            child_cmds = &section.next.cmds; // use the child section cmds
            if(child_cmds.len() == 0) continue; // no cmds in this section
            foreach(inicmd : *child_cmds)
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == BOOLEAN);
                    String value = inicmd.cmd.second;
                    return (value == "true" || value == "1") ? true : false;
                }
            }
        } 
        else
        {
            // use the current section cmds
            if(section.cmds.len() == 0) continue; // no cmds in this section
            // else loop the current section cmds
            foreach(inicmd : section.cmds) 
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == BOOLEAN);
                    String value = inicmd.cmd.second;
                    return (value == "true" || value == "1") ? true : false;
                }
            }
        }
    }
    
    return default_value;
}

<*
 @param [in] key : `The cmd name`
 @require key != ""
*>
fn String ConfigFile.getString(&self, String key, String default_value = "")
{
    ListIniCMDPrts* child_cmds;

    foreach(section : self.sections) 
    {
        // if the section is linked, we need to loop the child section cmds instead
        if(section.isLinked())
        {
            child_cmds = &section.next.cmds; // use the child section cmds
            if(child_cmds.len() == 0) continue; // no cmds in this section
            foreach(inicmd : *child_cmds)
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == STRING);
                    return inicmd.cmd.second.trim("\"");
                }
            }
        } 
        else
        {
            // use the current section cmds
            if(section.cmds.len() == 0) continue; // no cmds in this section
            // else loop the current section cmds
            foreach(inicmd : section.cmds) 
            {
                if(inicmd.cmd.first == key) {
                    assert(inicmd.type == STRING);
                    return inicmd.cmd.second.trim("\"");
                }
            }
        }
    }
    
    return default_value;
}

fn bool ConfigFile.hasValue(&self, String key)
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

        foreach(inicmd : *cmds) 
        {
            if(inicmd.cmd.first == key) 
            {
                return true;
            }
        }
    }
    
    return false;
}

fn bool ConfigFile.sectionHasValue(&self, String section_name, String key)
{
    IniSection* section = self.getSection(section_name);
    if(section == null) return false; // section not found

    ListIniCMDPrts* cmds;
    if(section.isLinked()) {
        cmds = &section.next.cmds; // use the child section cmds
    } else {
        cmds = &section.cmds; // use the current section cmds
    }

    foreach(inicmd : *cmds) 
    {
        if(inicmd.cmd.first == key) 
        {
            return true;
        }
    }
    
    return false;
}
///////////

<*
 @param key : `The cmd name`
 @require key != ""
*>
fn void ConfigFile.setValue(&self, String key, String value) @local
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

        foreach(inicmd : *cmds) 
        {
            if(inicmd.cmd.first == key) 
            {
                inicmd.cmd.second = value.tcopy(); // update the value
                self.markModified(); // mark the config as modified
            }
        }
    }
}

fn void ConfigFile.setBool(&self, String key, bool value)
{
	self.setValue(key, (value) ? "1" : "0");
}

fn void ConfigFile.setInteger(&self, String key, int value)
{
	String val = string::tformat("%s", value);
	self.setValue(key, val);
}

fn void ConfigFile.setFloat(&self, String key, float value)
{
	String val = string::tformat("%s", value);
    self.setValue(key, val);
}

fn void ConfigFile.setString(&self, String key, String value)
{
    if(value == "") {
        self.setValue(key, EMPTY_STR);
        return;
    }
    
    // make sure the value is a valid string
    if(!value.starts_with(STR_CHAR) || !value.ends_with(STR_CHAR)) {
        value = STR_CHAR.tconcat(value).tconcat(STR_CHAR);
    }
    self.setValue(key, value);
}

// DOC IniSection is a section in the ini file, 
// [section_name.child_section_name] it can have child sections and
// it can have commands (cmds) registered to it.
// When a section has a child section, the cmds are not registered to the parent section,
// but to the child section, the parent section only serves as a link/path to the real section
// where the cmds will be saved.
struct IniSection { 
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
    DOC where_index is the index in the string where the comment starts
    @param [in] str : "line to detect the comment symbol"
    @param [inout] where_index : "the index in the line where the comment char is"
*>
fn bool detect_comment_char_in_line(String str, usz* where_index = null) @local @inline {
    if(string::char_in_set(';', str)) {
        if(where_index != null) (*where_index) = str.index_of_char(';')!!;
        return true;
    }
    
    return false;
}

<*
    DOC String is a "slice" and as such is just a struct with a pointer and a len.
    Slices and Array's ARE NOT exactly the same
    String[] is a slice (a pointer and a len) 
    String[*] is a C like array (a pointer to the first data in the array, with no len).
    @param [in] filepath : "path to the config file"
    @param isrelative : "marks if the path is a full one or one relative to the game base folder"
*>
fn String[]? openConfigfileAndCutDataByLines(String filepath, bool isrelative) @local {
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }
    
    if(isrelative) filepath = game.app_base_folder.tconcat(filepath);
    
    INIFile file_data = (INIFile)file::open(filepath, "r")!;
    defer (void)file_data.close();
    // if(catch excuse = file_data) {
        // log::warning(Where.FILE, "Unable to open ini file: %s with excuse: %s", filepath, excuse);
        // return IniFault.FAILED_OPEN_FILE?;
    // }
    
    String? entire_file = fs::readEntireFileX(filepath);
    if(catch excuse = entire_file) {
        log::warning(FILE,  "Unable to read data from file: %s with excuse: %s", filepath, excuse);
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

fn ConfigFile*? parse_file(String[] lines) @local 
{
    ConfigFile* file_data = mem::new(ConfigFile);
    
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
fn void parse_section_name(String line, ConfigFile* file) @local 
{
    String section_name = line.trim("[]");
    if(section_name.contains("."))
    {
        String[] split = section_name.tsplit(".");
        // WARNING(HM) 
        // child sections (section_parent.section_child) unlike 
        //  the parent section ARE NOT registered in the main file sections list, 
        //  they are registered in the parent section itself and only acessible thought it.
        // Also any child cmds, are not registered to the parent section cmds, those stay empty, 
        //  child cmds, get registered to the child cmds list, the parent section then 
        //  only serves as a link/path to the real section where the cmds are saved.
        IniSection* parent, child;

        String parent_section_name = split[0];
        
        // see if the parent section already exists
        // if it does, we just link the child section to it
        if(file.hasSection(parent_section_name)) {
            parent = file.getSection(parent_section_name);
        } else {
            // create a parent section as well
            parent      = mem::new(IniSection);
            parent.name = parent_section_name;
            file.register(parent);
        }
        
        // create the child section to link to
        child = mem::new(IniSection);
        child.name = split[1];
        parent.link(child);
    } 
    else // if the section name is a single section (no child sections)
    {
        // create a single section
        IniSection* section = mem::new(IniSection);
        section.name = section_name;
        file.register(section);
    }
}

<*
  @param [in] line : "the line to parse"
  @param [&inout] file : "pointer to the config file data"
*>
fn void parse_section_cmd(String line, ConfigFile* file) @local
{
    String[] tokens = line.tsplit(ASSIGNMENT_CHAR);

    IniCmdData cmd_data = { .first = tokens[0].trim(), .second = tokens[1].trim() };
    assert(cmd_data.first != "");

    // this shouldn't happen but just in case... 
    // if we think we are writting C/C++ or C3 code
    // and put a semicolon at the end of the line...
    if(cmd_data.second.ends_with(COMMENT_CHAR)) {
        cmd_data.second = cmd_data.second.strip_end(COMMENT_CHAR);
    }

    if(cmd_data.second.contains(".") && cmd_data.second.len > 1) 
    {
        // see if is a float of form '1.'
        usz dot_index = cmd_data.second.index_of_char('.')!!;
        // if the dot is the last char in the string, we need to add a zero at the end
        if((dot_index + 1) == cmd_data.second.len) 
        {
            // NOTE(HM) this is a bit of a hack, but it works for now
            // if the value is like "1." we need to add a zero at the end
            // to make it a valid float value
            // this is because later the value parser will not accept a float without a number after the dot
            String value = cmd_data.second;
            value = value.strip_end(" \n\t");
            cmd_data.second = value.tconcat("0");
        }
    }
    
    int type = get_cmd_type_from_value(cmd_data.second);
    // just in case assert the cmd type is valid
    assert(type >= 1 && type <= 4);
    
    // register the new cmd
    // cmds are allowed to have empty values
    IniCMD* cd  = mem::new(IniCMD);
    cd.type     = type;
    cd.cmd      = cmd_data;
    //cd.cmd.first  = cmdTempData.key;
    //cd.cmd.second = cmd_data.second;
    // now register the cmd to the last section in the file
    IniSection* last_section_ptr = (*file).sections.last()!!;
    if(last_section_ptr.isLinked()) {
        last_section_ptr.next.register(cd); // register the cmd to the child section cmds
    } else {
        last_section_ptr.register(cd);
    }
}

<*
 * DOC Get the type of a cmd value from its string representation
 *
  @param [in] value : "the cmd data to set the type"
  @require value != ""
 *>
fn int get_cmd_type_from_value(String value) @inline @local
{
    if(value == "" || value == "true" || value == "false") {
       return BOOLEAN;
    }
    
    if(value.starts_with(STR_CHAR)) 
    {
        // just in case
        testCmdValueStringValidity(value, "");
       return STRING;
    }
    
    if(value.contains(".")) return FLOAT;

     // default type is integer
    return INT;
}

<*
 * DOC Create a init file data structure for easy parsing
 *
  @param [in] filepath : "path to the config file (.ini file)"
  @require filepath.len >= 3 : "The file path must be at least 3 characters long"
 *>
fn ConfigFile*? load(String filepath, bool isrelative = true) 
{
    if(filepath == "") {
        return MISSING_FILE_PATH?;
    }
    
    String[]? data = openConfigfileAndCutDataByLines(filepath, isrelative);
    if(catch excuse = data) {
        log::warning(FILE,  "Unable to open file %s to cut with excuse: %s", filepath, excuse);
        return INI_FILE_LOAD_FAILED?;
    }
    
    //data is valid from here
    ConfigFile*? file_data = parse_file(data);
    if(catch excuse = file_data) {
        log::warning(FILE, "Failed to parse config file: %s with excuse: %s", filepath, excuse);
        return MALFORMED_INI_FILE?;
    }
    file_data.path = filepath.tcopy();

    return file_data; //parse_file(data);
}

<*
 * DOC Create a init file data structure for easy parsing
 *
  @param [in] filepath
  @require filepath.len >= 3 : "The file path must be at least 3 characters long"
 *>
fn bool? ConfigFile.load(&self, String filepath, bool isrelative = true) 
{
    String[]? lines = openConfigfileAndCutDataByLines(filepath, isrelative);
    if(catch excuse = lines) {
        log::warning(Where.FILE,  "Unable to open file %s to cut with excuse: %s", filepath, excuse);
        return INI_FILE_LOAD_FAILED?;
    }

    self.path = filepath.tcopy();
    
    foreach(line : lines)
    {
        if(line.is_empty()) continue;
        if(line.starts_with(COMMENT_CHAR)) continue; // to next line
        
        //
        bool has_comment_at_the_end = detect_comment_char_in_line(line);
        if(has_comment_at_the_end) {
            // split line by the comment char
            String[] split = line.tsplit(COMMENT_CHAR);
            // now clean the start and end of line ignoring the comment section
            split[0] = split[0].trim();
            line = split[0].tcopy();
        }
        
        // now handle the line data
        if(line.starts_with(SECTION_NAME_START)) 
        {
            parse_section_name(line, self);
        } else {
            parse_section_cmd(line, self);
        }
    }

    return true; 
}

fn bool ConfigFile.save(&self, String filename = SETTINGS_FILE_NAME)
{
    if(self.isModified() == false) return true; // nothing to save, the file is not modified

    //String filepath = game.app_base_folder.tconcat(filename);
    assert(self.path.len > 0, "The config file path must be set before saving the config file.");
    String filepath = self.path;

    INIFile? file_data = (INIFile)file::open(self.path, "wt");
    if(catch excuse = file_data) {
        log::warning(Where.FILE, "Failed to open config file: %s to write with excuse: %s", filepath, excuse);
        return false;
    }
    defer (void)file_data.close();

	uint section_count = (uint)self.sections.len();
	for (uint s = 0; s < section_count; s++)
	{
		IniSection *section = self.sections[s];
		if (section.name.is_empty()) continue; // skip empty sections
        //
        @catch(file_data.write("["));
        @catch(file_data.write(section.name));
        if(section.isLinked()) {
            @catch(file_data.write("."));
            @catch(file_data.write(section.next.name));
        }
        @catch(file_data.write("]\n"));

        if(section.isLinked()) {
            foreach(cmd : section.next.cmds) 
            {
                if(cmd.cmd.first.is_empty()) continue; // skip empty cmds
                if(cmd.type == STRING) {
                    testCmdValueStringValidity(cmd.cmd.second, cmd.cmd.first);
                }
                @catch(file_data.write(cmd.cmd.first));
                @catch(file_data.write(" = "));
                @catch(file_data.write(cmd.cmd.second));
                @catch(file_data.write("\n"));
            }
        } else {
            foreach(cmd : section.cmds) 
            {
                if(cmd.cmd.first.is_empty()) continue; // skip empty cmds
                if(cmd.type == STRING) {
                    testCmdValueStringValidity(cmd.cmd.second, cmd.cmd.first);
                }
                @catch(file_data.write(cmd.cmd.first));
                @catch(file_data.write(" = "));
                @catch(file_data.write(cmd.cmd.second));
                @catch(file_data.write("\n"));
            }
        }
	}

	return true;
}

fn void ConfigFile.reload(&self)
{
    // reload the config file
    ConfigFile*? new_data = load(SETTINGS_FILE_NAME, true);
    if(catch excuse = new_data) {
        log::warning(Where.FILE, "Failed to reload config file with excuse: %s", excuse);
        return;
    }
    
    // free the old data
    unload(self);
    
    // assign the new data to the current config
    mem::copy(self, new_data, ConfigFile.sizeof);
    //*self = *new_data;
    
    // free the new data
    mem::free(new_data);
}

fn void testCmdValueStringValidity(String value, String id) 
{
    if(value.ends_with(STR_CHAR)) return; // all is well do nothing
    
    if(value.ends_with("\0"))
    {
        char* ch = value[:value.len - 2];
        if(*ch != '"') {
            io::printfn("cmdline: Malformed <string> \"%s\" assigned to \"%s\", it should start and end with \'\"\'.",*ch, id);
            // unreachable calls should be put AFTER code that you expect to run!
            unreachable();
        }
    } else {
        io::printfn("cmdline: Malformed value <string> assigned to \"%s\", it should start and end with \'\"\'.", id);
        unreachable();
    }
}

<*
  @param [&inout] inifile : "is not really a file but a adress of a data structure in memory"
*>
fn void unload(ConfigFile* inifile) 
{
    if(inifile == null) {
        return; // nothing to unload
    }

    if(inifile.path.len) {
        inifile.path = ""; // clear the path
    }

    if(inifile.sections.len()) 
    {
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
    Creates a init file with default data 
    @param [in] filepath : "path to save the file in"
    @require filepath.len >= 2 : "The path must be at least 2 characters long"
 *>
fn void create_default_settings_file(String filepath) @inline
{
    if(fs::fileExists(filepath)) return;

    File? data = file::open(filepath, "w");
    if(catch excuse = data) {
        log::warning(Where.FILE, "Failed to open config file: %s to write with excuse: %s", filepath, excuse);
        return;
    }
    @catch(data.write(SAFE_SETTINGS));
    data.close()!!;
    log::warning(Where.FILE, "Settings file missing, creating one with default settings at: %s", filepath);
}


<*
 * Create a init file structure for easy parsing
 *
  @param [in] path
  @require path.len > 0 : "The path must be at least 1 character long"
 *>
fn bool? populate(ConfigFile* file_data, String path) @deprecated {
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

fn bool ConfigFile.is_valid(&self) @inline {
    return self.sections.is_empty() == false;
}

fn void ConfigFile.free(&self) {
    unload(self);
}
