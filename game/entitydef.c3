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
/* UNFINISHED
// region module
module game::entitydef::entdef @private;

// region imports
import engine::misc;
import std::io, std::math;
import game::entitydef::mtr;
import game::entitydef::manager::mtrmng;
import engine::logging::log;
import engine::filesystem::fs;
import engine::assets_api::astmng; // asset manager
import engine::sys::render2d::r2d;
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
import std::collections::list, std::collections::tuple;
// end_region

/*
****************************************************************************
*
*                   Bellow is still very WIP
*
*****************************************************************************
*/

alias EntSpawnArg = StringPair; // alias for a entity spawn argument, which is a tuple of two strings (name, value)
alias SpawnArgList = List{EntSpawnArg*};

faultdef ENTDEF_INVALID_PATH,
         ENTDEF_UNKNOWN_ENTITYDEF,
	     ENTDEF_UNKNOWN_FOLDER,
         ENTDEF_LOAD_ERROR,
         ENTDEF_PARSING_ERROR,
	     ENTDEF_SMALL_PATH_ERROR;

bitstruct Flags : char
{
	bool noShadows;
	bool forceShadows;
	bool editor_visible; // visible in the editor
}

// RLMaterial stage represents each texture type in a entitydef
struct EntityDef (SaveSystemInterface) @public
{
	String name;
	String comment;
	Flags flags;
    SpawnArgList spawnargs; // dynamic array of spawn arguments for this entity definition, used to store any custom data for the entity that is not covered by the other fields
	DEFile *file; // pointer to the .def file where this entity is defined
}

fn void EntityDef.save(&self, SaveFile* file) @dynamic {
    @todo();
}

fn void EntityDef.reload(&self, SaveFile* file) @dynamic {
    @todo();
}

<*
    @param [&inout] def : "entity definition we are handling"
    @param [&in] node : "xml node we are parsing"
*>
fn void register_spawnargs(EntityDef* def, XmlNode* node)
{
    if(node.hasAttributes() == false) return;

    foreach (arg : node.attributes)
    {
       if(arg == null) unreachable("null atrribute found for xml node '%s'", node.name);
       // else
       def.spawnargs.push(mem::new(EntSpawnArg, {
                                                  .first  = arg.name.tcopy(), 
                                                  .second = arg.value.tcopy()
                                                }
        ));
    }
}

fn void EntityDef.clear(&self)
{
    if(self.file) self.file = null;
    if(self.spawnargs.len() > 0)
    {
        // NOTE(HM) free all the arguments in the list
        foreach (arg : self.spawnargs)
        {
            if(arg != null) mem::free(arg);
        }
        self.spawnargs.clear();
    }
}

fn void EntityDef.init(&self)
{
    self.comment  = "<no comment>";
	self.flags.editor_visible = true;
}

// TODO(HM) make this print a more detailed info
fn void EntityDef.print(self)
{
    io::printfn("[Entity : '%s']", self.name);
    if(self.comment.len && self.comment != "<no comment>") {
        io::printfn(" comment = \"%s\"", self.comment);
    }
    io::printfn(" <spawnargs>");
    foreach(i, arg : self.spawnargs) {
        io::printfn("\t\"%s = %s\"", i, arg.first, arg.second);
    }
	io::printfn(" </spawnargs>");
}

// @untested
<*
    Deep copy of a entity def data
    @param [&in] other : "the other def to copy data from"
*>
fn void EntityDef.copy(&self, EntityDef* other)
{
    @todo();
    /*if(other == null) {
        log::error(FILE, "Cannot copy entitydef from null pointer!");
        return;
    }*/
    
    // NOTE(HM) Perhaps this should be a string with the mtr path in it, 
    // not a pointer to some data in memory, that could be freed anytime...
    // DEFile* mtrfile;  // pointer to mtr data in memory where this entitydef is defined
    self.name = other.name.tcopy();
    self.comment = other.comment.tcopy();
    self.flags = other.flags;
	// first free our old spawnargs
	if(self.spawnargs.len)
	{
		foreach (arg : self.spawnargs)
		{
			if(arg != null) arg.free();
		}
		self.spawnargs.clear();
	}
	
    // now copy the new spawnargs
	if(other.spawnargs.len)
	{
		foreach (arg : other.spawnargs)
        {
            if(arg != null) self.spawnargs.push(mem::new(EntSpawnArg, {arg.first.tcopy(), arg.second.tcopy()}));
        }
	}
}

fn bool EntityDef.hasSpawnarg(String arg_name, String *arg_value) @nodiscard
{
	foreach (usz i, &arg : self.spawnargs)
	{
		if((*arg).name == arg_name) {
            if(arg_value) (*arg_value) = self.spawnargs[i].second.tcopy();
            return true;
        }
	}

	return false;
}


fn String EntityDef.defaultDefinition(self) @inline
{
    String def = `
     <EntityDef name="default">
        <comment>This is the default entity definition</comment>
        <spawnargs
        spawnType="Entity"
        />
    </EntityDef>
    `;
    
	return string::tformat("%s", def);
}

<*
    @param [&in] node : "node we are currently parsing"
*>
fn void parse_spawnargs(EntityDef* def, XmlNode* node)
{
    assert(node.hasAttributes() == true);
    assert(isXmlNode(node, Node.TEXT) == false);

    foreach(atrb: node.attributes)
    {
        switch(atrb.name)
        {
            case Spawnarg.SPAWNTYPE.str:
            case Spawnarg.INHERIT.str:
			case Spawnarg.MODEL.str:
			case Spawnarg.PHYSMODEL.str:
			case Spawnarg.BROKEN.str:
			case Spawnarg.DENSITY.str:
			case Spawnarg.MASS.str:
			case Spawnarg.FRICTION.str:
			case Spawnarg.BOUNCYNESS.str:
			case Spawnarg.HEALTH.str:
			case Spawnarg.SND_BOUNCE.str:
			case Spawnarg.NONSOLID.str:
            	@todo();
            default:
               unreachable("invalid spawnarg '%s' for '%s' found!!", atrb.name, def.name);
        }
    }
}

<*
    @param [&inout] def : "def to set data to"
    @param [&in] node : "node to get data from"
*>
fn void parse_comment(EntityDef* def, XmlNode* node) @inline
{
	def.comment = node.getText().tcopy();
}

fn Vec2f getVector2FromString(String str) @inline @local
{
    String[] slice = str.tsplit(", ");
    if(slice.len == 0) {
        return {};
    }

    if(slice.len == 1) {
        float x = slice[0].to_float()!!;
        return {x, x}; // use the same value for both x and y
    } else if(slice.len == 2) {
        return {slice[0].to_float()!!, slice[1].to_float()!!};
    }

    return {};
}

fn Vec3f getVector3FromString(String str) @inline @local
{
    String[] slice = str.tsplit(", ");
    if(slice.len == 0) {
        return {};
    }

    if(slice.len == 1) {
        float x = slice[0].to_float()!!;
        return {x, x, x}; // use the same value for x, y and z
    } else if(slice.len == 2) {
        return {slice[0].to_float()!!, slice[1].to_float()!!, 0.0f}; // z is 0.0f
    } else if(slice.len == 3) {
        return {slice[0].to_float()!!, slice[1].to_float()!!, slice[2].to_float()!!};
    }

    return {};
}

fn Vec4f getVector4FromString(String str) @inline @local
{
    String[] slice = str.tsplit(", ");
    if(slice.len == 0) {
        return {};
    }

    if(slice.len == 1) {
        float x = slice[0].to_float()!!;
        return {x, x, x, 1.0f}; // use the same value for x, y and z, w is 1.0f
    } else if(slice.len == 2) {
        return {slice[0].to_float()!!, slice[1].to_float()!!, 0.0f, 1.0f}; // z is 0.0f, w is 1.0f
    } else if(slice.len == 3) {
        return {slice[0].to_float()!!, slice[1].to_float()!!, slice[2].to_float()!!, 1.0f}; // w is 1.0f
    } else if(slice.len == 4) {
        return {slice[0].to_float()!!, slice[1].to_float()!!, slice[2].to_float()!!, slice[3].to_float()!!};
    }

    return {};
}

////////////////////////////////////////////////////////////////////////////////
//
//              DEFile - Entity definitions file data structure
//
///////////////////////////////////////////////////////////////////////////////

module game::entitydefile::def @private;

// region imports
import game::entitydef::mat;
import std::io, std::math;
import game::main; // for file logging or console logging
import engine::misc;
import game::serialize::svs;
import game::entitydef::manager::mtrmng;
import engine::logging::log;
import engine::filesystem::fs;
import engine::assets_api::astmng; // asset manager
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
import std::collections::list, std::collections::tuple;
// end_region

const DEF_VERSION_STRING = "1.0.0"; // the version of the file format
const DEF_FILE_EXT = ".def"; // the extension of the file
const MAX_DEFS_PER_FILE = 100; // the maximum number of definitions per def file
const MAX_DEFS_OVERALL  = 10000; // the maximum number of definitions in the game

alias EntityDefsList = List{EntityDef*};

faultdef DEF_INVALID_PATH,
	     DEF_MALFORMED_FILE,
	     DEF_UNKNOWN_FOLDER,
	     DEF_FOLDER_SCAN_ERROR,
	     DEF_LOAD_ERROR,
         DEF_VERSION_MISMATCH,
         DEF_PARSING_ERROR,
	     DEF_SMALL_PATH_ERROR,
	     DEF_RETRIVAL_ERROR,
	     DEF_MISSING;

// NOTE(HM) This represents every usefull node in the def xml file 
constdef Node : String @public
{
    ROOT      = "DEFS",
    TEXT      = "#text",
    ENTITYDEF = "EntityDef",
    COMMENT   = "comment",
    SPAWNARGS = "spawnargs"
}

<*
    @param [&in] node : "node to compare the name"
*>
fn bool isXmlNode(XmlNode* node, Node kind) @inline @public => (node.name == kind.str) ? true : false;

enum Spawnarg : int (String str) @public
{
	SPAWNTYPE {"spawnType"},
	INHERIT {"inherit"},
	MODEL {"model"},
	PHYSMODEL {"physmodel"},
	BROKEN {"broken"},
	DENSITY {"density"},
	MASS {"mass"},
	FRICTION {"friction"},
	BOUNCYNESS {"bouncyness"},
	HEALTH {"health"},
	SND_BOUNCE {"snd_bounce"},
	NONSOLID {"nonsolid"}
}

// NOTE(HM) This is the data structure represents a entire def file, it contains a list of entitydef's data
struct DEFile @public
{
    String path;    // path to the def file on disk.
    String version; // version of the def file format, should be DEF_VERSION_STRING.
    EntityDefsList entdefs;  // list of defs in this file.
}

fn void  DEFile.init(&self, String path) @inline
{
    self.path = path.tcopy();
    self.version = DEF_VERSION_STRING;
    self.entdefs.reserve(MAX_DEFS_PER_FILE);
}

fn void  DEFile.unload(&self) @inline
{
    if(self.entdefs.len() == 0) return; // nothing to unload

	foreach(def: self.entdefs) def.free();
    self.entdefs.free();
}

<*
    @param [&in] def : "definition to register"
*>
fn void  DEFile.register(&self, EntityDef* def) @inline
{
    if(self.entdefs.len() >= MAX_DEFS_PER_FILE) {
        log::error(FILE, "Maximum number of definitions per def file reached (%d), cannot register '%s' in file '%s'.", MAX_DEFS_PER_FILE, def.name, self.path);
        return;
    }
    self.entdefs.push(def);
}

// @Performance This will probably be very slow with many entities...
// TODO(HM) make this faster by using a hash table
fn EntityDef* DEFile.getEntityDefinition(&self, String name) @inline
{
	foreach(def: self.entdefs) {
		if(def.name == name) return def;
	}
    
	return null;
}

fn bool?  DEFile.load(&self, File file) @inline
{
    XmlDoc*? doc = xml::read_file(file);
    defer doc.free()!!;
    
    if(catch excuse = doc)
    {
       log::warning(FILE, " Failed to load/open .def xml file [%s] with excuse: %s", self.path, excuse);
       return DEF_LOAD_ERROR~;
    }
    
    return self.parse(doc);
}

<*
    @param [&in] doc : "mtr (xml) file to parse"
*>
fn bool? DEFile.parse(&self, XmlDoc* doc)
{
    bool invalid_file = doc.rootNode.name != Node.ROOT.str;
    if(invalid_file)
    {
       log::error(FILE, " Malformed def file '%s', root node expected to be '%s' but is '%s' instead.", self.path, Node.ROOT.str, doc.rootNode.name);
       return DEF_MALFORMED_FILE~;
    }

    String? version = (String)doc.rootNode.getAttribute(NodeAttrib.VERSION).value;
    if (catch excuse = version)
    {
        log::error(FILE, "Failed to get def version node in %s with excuse: %s\n", self.path, excuse);
        return false;
    }
    // else got version, so check if it matches the current version
    // TODO(HM) handle version changes.
    if(version != DEF_VERSION_STRING)
    {
        log::error(FILE, " Invalid def file '%s', version expected to be '%s' but is '%s' instead.", self.path, DEF_VERSION_STRING, version);
        return DEF_VERSION_MISMATCH~;
    }

    // else everything should be fine from here, so keep parsing this def data
    self.version = version.tcopy();
    
    // now parse each def xml node
    foreach (node : doc.rootNode.children)
    {
        $if $feature(_DEBUG):
            if(node == null) 
            {
                log::error(FILE, "Null node found in def file '%s', skipping it.", self.path);
                return DEF_MATERIAL_PARSING_ERROR~;
            }
        $endif

        switch
        {
            // Skip any text nodes assigned to the root node (shouldn't happen now though).
            // Text nodes are handled further by the parser, so we don't need to handle them here.
            case isXmlNode(node, Node.TEXT):
                log::error(FILE, "Unexpected 'TEXT' node found in body of def '%s'! Text = '%s' ", fs::getFileNameWithoutExt(self.path), node.value);
                // This was caused by a bug in the xml reader code (not very easy to solve but I worked around it). 
                // The xml reader, treats any end char '>', as always being followed by a Text "node", 
                //  (free text between a '>' and a '<'), so in some situations, it created empty text nodes, 
                //  like when after a '>' char, came the start char '<' of another node, 
                //  but you add in between them, empty characters (space, new line), but even so 
                //  the xml reader, still considered those as valid "text". 
                // Because the xml reader, reads character by character, is not easy to solve this, 
                //  so it will create a text node, regardless if is empty or not.  
                // The workaround, test for empty text nodes and just don't register them, in the xml doc file.
                return DEF_PARSING_ERROR~;
                //
            case isXmlNode(node, Node.ENTITYDEF):
                EntityDef* def = parse_definition(node, self);
                if(def) {
                    self.register(def);
                } else {
                    log::error(FILE, "Failed to parse node '%s' in def file '%s'", node.name, self.path);
                    return DEF_PARSING_ERROR~;
                }
            default:
                log::warning(FILE, " Unexpected node in file '%s', expected <%s> found <%s>", self.path, Node.ENTITYDEF.str, node.name);
                $if $feature(_DEBUG):
                    return DEF_PARSING_ERROR~;
                $else
                    continue;
                $endif
        }
    } // end foreach node
    
    return true;
}

// @Performance This will probably be very slow with many def files
// TODO(HM) make this faster by using a hash table
fn bool check_definition_existance(String name,  DEFile* file = null) @inline @public
{
    // first check if the entitydef name already exists in the current passed def file
    if(file != null) if(file.getEntityDefinition(name) != null) return true;

    // else check for it in the global defs database
    // NOTE(HM) this is a slow operation, so use it with caution
    DefsDataBase* db = &game::gpGame.defsDB;
    foreach(def: db.data) {
        if(def.getEntityDefinition(name) != null) return true;
    }
    
    return false;
}

<*
    @param [&in] in_node : "entitydef node we are currently parsing"
*>
fn EntityDef* parse_definition(XmlNode* in_node, DEFile* def)
{
    // create the definition structure to save the parsed data into
    EntityDef* ent = mem::new(EntityDef);
    ent.init();
    
    // first get entity name
    String? ent_name = (String)in_node.getAttribute(NodeAttrib.NAME).value;
    if (catch excuse = ent_name)
    {
        log::error(FILE, "Failed to get attribute name %s for %s with excuse: %s\n", (*in_node).name, self.path, excuse);
        ent.free();
        mem::free(ent);
        return null;
    }
    
    if (ent_name.is_empty())
    {
        log::error(FILE, "entitydef with empty or no name in %s\n", self.path);
        ent.free();
        mem::free(ent);
        return null;
    }

    // check if the entitydef name already exists in the database
    if(check_definition_existance(ent_name, self) == true)
    {
        log::warning(FILE, "entitydef with name '%s' already exists in %s\n", ent_name, self.path);
        ent.free();
        mem::free(ent);
        return null;
    }
    
    // else everything should be fine from here, so keep parsing this entitydef data
    ent.name = ent_name.tcopy();
    ent.file = self; // set the entitydef file pointer to this def file
    
    // parse extra attributes if any
    ent.parse_node_atributes(in_node);

    /////////////////////////////////////////////
    // NOTE(HM) this is the main part of the entitydef parsing, where we parse all the child nodes
    // and set the data accordingly
    foreach (node : in_node.children)
    {
       // just in case...
       if(node == null) {
            log::warning(FILE, "Null child node found for '%s', skipping it.", ent.name);
            continue;
       }

       switch(node.name)
       {
            case Node.TEXT.str:
                // NOTE(HM) free text nodes are not supported here, so we just skip them
                log::warning(FILE, "Unexpected text node found in '%s'! Text = '%s' ", ent.name, node.value);
                continue;
            case Node.COMMENT.str: 
                ent.parse_comment(node);
            case Node.SPAWNARGS.str: 
                ent.parse_spawnargs(node);
			default:
				unreachable();
       }
    }
    
    return ent;
}



//////////////////
// #region private
//////////////////

fn RLColor xmlStrColorToColor(String _value) @public
{
    String[] chars = _value.tsplit(" ");
    assert(chars.len == 4);
    
    RLColor result;
    
    char? value;

    value = chars[0].to_uchar();
    if(catch excuse = value) {
        result.r = 255;
    } else {
        result.r = (value <= 255) ? value : 255;
    }
    value = chars[1].to_uchar();
    if(catch excuse = value) {
        result.g = 255;
    } else {
        result.g = (value <= 255) ? value : 255;
    }
    value = chars[2].to_uchar();
    if(catch excuse = value) {
        result.b = 255;
    } else {
        result.b = (value <= 255) ? value : 255;
    }
    value = chars[3].to_uchar();
    if(catch excuse = value) {
        result.a = 255;
    } else {
        result.a = (value <= 255) ? value : 255;
    }
    
    return result;
}

// #endregion private

//////////////////////////
// Def's Manager
//////////////////////////

module game::definitions::manager::defsmng @private;

// region imports
import std::io;
import game::main; // for file logging or console logging
import engine::misc;
import game::entitydef::mtr, game::entitydef::mat;
import engine::logging::log;
import std::collections::list, std::collections::tuple;
import engine::assets_api::astmng; // asset manager
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
// end_region

alias DEFS_FileList = List{ DEFile*};

struct DefsDataBase @public
{
    DEFS_FileList data;
}

faultdef INVALID_PATH_STRING,
	     MALFORMED_DEF_FILE,
	     UNKNOWN_FOLDER,
	     FOLDER_SCAN_ERROR,
	     DEF_LOAD_ERROR,
	     SMALL_PATH_ERROR,
	     DEF_RETRIVAL_ERROR,
	     MISSING_DEF;


<*
    @param search_path : "where to look for the def files"
    @param [inout] database : "the database where to register the def files"
    @require database != null && search_path.len >= 2
*>
fn void? load_def_files(String search_path, DefsDataBase* database) @local
{
	PathList? paths = path::ls(tmem, path::temp(search_path));
	if(catch excuse = paths) {
		log::warning(FILE,  "Unable get def files paths from folder: %s with excuse: %s", search_path, excuse);
		return FOLDER_SCAN_ERROR~;
	}
	
	foreach(path: paths)
	{
		String asset_path = search_path.tconcat(path.str_view());
        
        if(!fs::isFile(asset_path)) continue;
        
		{ // else try to load def files
			String file_name = fs::getFileNameWithoutExt(asset_path);
			// NOTE(HM) ignore .default files those are handled elsewhere
            // plus there's no default def...
			if (file_name == "default") 
            {
                log::warning(FILE, " unexpected '%s' file name found inside defs folder.", file_name);
				continue; // to next file
			}
			
			if(fs::getFileExtension(asset_path) != ".def") 
            {
                log::warning(FILE, " unexpected file type '%s' found inside defs folder.", file_name);
				continue; // to next file
			}
			
            //****
			// from here should be a valid file
            //****

            if(file::get_size(asset_path)! < 10) // TODO(HM) make this a constant
            {
                log::warning(FILE, " def file [%s] is too small to be valid, skipping it.", asset_path);
                continue; // to next file
            }
            
            // we have a valid size, so now try to open it

            File? file = fs::openFile(asset_path, "r");
            defer file.close()!!;
            
            if(catch excuse = file) 
            {
               log::warning(FILE, " Failed to open def file [%s] with excuse: %s", asset_path, excuse);
               // DOC(HM) I need to always return from a catch or the excuse will not unwrap,
               // causing variable shadow error, preventing me from using excuse again bellow.
               continue; // to next file
            }

            // we could open it, so now try to load and save it's data
            DEFile* def_file = mem::new(DEFile);
            def_file.path = asset_path;
            
            if(catch excuse = def_file.load(file))
            {
                log::warning(FILE, " Failed to load [%s]", asset_path);
                mem::free(def_file);
                continue; // to next file
            }
			
            // every thing was fine, so save the def file, in def files database
            _register(database, def_file);
		}
        
		//continue to next file
	}
}

<*
    @param [&inout] db : "entitydef file data base"
    @require game::gpGame.app_base_folder.len > 0
*>
fn void? loadDefsFilesTo(DefsDataBase* db) @inline @public
{
    String folder = game::gpGame.app_base_folder.tconcat("defs").tconcat("\\");
	load_def_files(folder, db)!!;

    // see if we have a default entitydef inside the file, if not create one
    if(defsmng::getDefinition("default") == null)
    {
        // TODO(HM) Makes this use the default definition
        // from the .defaultDefinition() function
        log::fatal(FILE, "Default entitydef not found in def database!");
        /*EntityDef* default_ = mem::new(EntityDef);
        default_.init();
        default_.name = "default";
        db.data[0].register(default_material);*/
    }
}

<*
    Performance: This will probably be very slow with many entities...

    @param [in] def_name : "name of the entitydef to search for"
    @require def_name.len > 0
    @require game::gpGame.defsDB.data.len() > 0
*>
fn EntityDef* getDefinition(String def_name) @public
{
    EntityDef* ent;
    uint index;

    uint count = (uint)game::gpGame.defsDB.data.len();
    if(count == 0) {
        log::error(FILE, "No def files loaded in the game, cannot get entitydef '%s'", def_name);
		// todo return a required default entitydef
        return null;
    }

    do { // @Performance This is a linear search, so it will be slow with many entities.
        // NOTE(HM): This is done this way because findDefinition() from  DEFile returns null 
        // if the entitydef is not found in the def data, so while we have defs in the data base
        // we need to keep looking through all of them.
        ent = game::gpGame.defsDB.data[index++].findDefinition(def_name);
    } while(ent == null && index < count);
    
	return ent;
}

<*
	@param [&inout] db : "the def database to register the def file in"
	@param [&inout] _def : "the def file to register"
*>
fn void _register(DefsDataBase* db,  DEFile* _def) @local @inline {
	db.data.push(_def);
}

fn void DefsDataBase.listDEFs(&self)
{
    $if $feature(_DEBUG):
        if(self.data.len())
        {
            log::info(CONSOLE, "[Definition FILES]");
            foreach(_def: self.data) {
                String trimmed_path = "...\\".tconcat(_def.path.strip(game::gpGame.app_base_folder));
                io::printfn("%s\t-> \"%s\"%s", ansi::color_rgb(171, 218, 217), trimmed_path, Ansi.RESET);
            }
        }
    $endif
}

// WARNING(HM) 06/11/2024
// To be used only at game exit, 
// for now ALL def files, are loaded at game start and stay in RAM, 
// during the entire game run. They only get freed at game end.
// This is done this way for now, because I don't have many def files,
// if that ever changes, I will have to refactor all of this.
// For now getting them hot from RAM, is faster then reading the data from the HD/SSD/MD2 drive.
fn void DefsDataBase.clear(&self) @inline
{
	if(self.data.len()) 
    {
		foreach(_def: self.data) _def.unload();
		self.data.free();
	}
}
