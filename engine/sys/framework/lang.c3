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

//////////////////// Language stuff /////////////////

module engine::sys::framework::language::lang;

import std::io;
import game::main;
import thirdparty::raylib5::rl;
import engine::filesystem::fs;
import std::collections;
import thirdparty::library::xml;
import engine::logging::log;

faultdef MALFORMED_LANG_FILE,
         LANG_PARSING_ERROR,
	     LANG_LOAD_ERROR,
	     LANG_READ_ERROR,
         LANG_VALUE_ERROR,
	     LANG_FILE_MISSING;

typedef LANGFile = inline XmlDoc;
//typedef LANGNode = inline XmlNode;
//typedef LANGAttribute = inline XmlAttribute;

alias StringsList = List{StringPair*};
alias LanguageList = List{Language*};

struct Language 
{
    String type;
    StringsList strings;
}

struct LANGData
{
    String path;  // full path to the lang file
    String type;  // current set language
    LanguageList languages;
}

fn String LANGData.getString(&self, String id) 
{
    foreach(lang : self.languages) 
    {
        if(lang.type != self.type) continue;

        foreach(str : lang.strings) 
        {
            if(str.first == id) return str.second;
        }
    }

    return "<failed>";
}

fn void LANGData.destroy(&self) 
{
    if(self.languages.len())
    {
        foreach(lang : self.languages) 
        {
            foreach(str : lang.strings) {
                mem::free(str);
            }
            lang.strings.clear();
            mem::free(lang);
        }
        self.languages.clear();
    }
}

<*
    @param [in] _path : "path to the language file"
*>
fn bool? LANGData.load(&self, String _path)
{
    self.path = _path.tcopy();

    // check if the file exists
    if(fs::fileExists(self.path)) 
    {
        File file = fs::openFile(self.path)!;
        defer file.close()!!;
        if(file.file == null) {
            log::error(FILE, "Failed to open language file '%s'", self.path);
            return LANG_LOAD_ERROR?;
        }

        LANGFile* lang_file = (LANGFile*)xml::read_file(file)!;
        defer lang_file.free();
        if(lang_file == null) {
            log::error(FILE, "Failed to read language file '%s'", self.path);
            return LANG_READ_ERROR?;
        }

        if(self.parse(lang_file)) {
            return true;
        } else {
            return LANG_PARSING_ERROR?;
        }
    } else {
        return LANG_FILE_MISSING?;
    }
}


<*
    @param [&in] doc : "the language file/document to parse"
*>
fn bool LANGData.parse(&self, LANGFile* doc) @local
{
    if(doc.rootNode.name != "LANG")
    {
       log::error(FILE, " Invalid language file '%s', root element should be 'LANG' but is '%s' instead.", self.path, doc.rootNode.name);
       return false;
    }

    if(doc.rootNode.children.len() == 0) {
        log::error(FILE, " Required strings in language file '%s' not found!", self.path);
        return false;
    }

    foreach (node : doc.rootNode.children)
    {
        if(node.name == "language")
        {
            assert(node.children.len() > 0);
            assert(node.hasAttributes());
            Language* new_lang = mem::new(Language);
            new_lang.type = node.attributes[0].value.tcopy();
            foreach(str_node : node.children) 
            {
                if(str_node.name != "string" && !str_node.hasAttributes()) {
                    unreachable("invalid string node found in language file");
                }
                new_lang.strings.push(
                    mem::new(StringPair, {
                        .first  = str_node.attributes[0].value.tcopy(), 
                        .second = str_node.attributes[1].value.tcopy()
                    })
                );
            }
            self.languages.push(new_lang);
        } else {
            log::error(FILE, " Invalid language file '%s', expected 'language' node found '%s' instead.", self.path, node.name);
            return false;
        }
    }

    return true;
}