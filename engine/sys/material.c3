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

// region module
module game::material::mtr;

// region imports
import std::io;
import game::main; // for file logging or console logging
import engine::misc;
import engine::logging::lgr;
import std::collections::list, std::collections::tuple;
import engine::assets::astmng;
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
// end_region

/*****************************************************************************
*
*                   Bellow is still very WIP
*
******************************************************************************/


alias MaterialList   = List{HMaterial*};
alias MTRFile        = File;
alias MTR_MatMapArgs = List{StringTuple*};

faultdef INVALID_PATH_STRING,
	     MALFORMED_MTR_FILE,
	     UNKNOWN_FOLDER,
         MATERIAL_PARSING_ERROR,
	     FOLDER_SCAN_ERROR,
	     MTR_LOAD_ERROR,
	     SMALL_PATH_ERROR,
	     MTR_RETRIVAL_ERROR,
	     MISSING_MTR;

enum MTR_Node : int (inline String name)
{
    ROOT      = "MTR",
    MATERIAL  = "MATERIAL",
    COMMENT   = "comments",
    MAPS      = "maps",
    MAP       = "map",
    VIDEO_MAP = "video_map",
    ARGS      = "args",
    COLOR     = "color",
    ALBEDO    = "albedo",
    NORMAL    = "normal",
    SPECULAR  = "specular",
    SOUND     = "sound",
    SHADER    = "shader"
}

enum MTR_NodeAttrib : int (inline String name)
{
    NAME     = "name",
    PATH     = "path",
    KIND     = "kind",
}

enum MTR_MapArgs : int (inline String name)
{
    TILE_H   = "tileH",
    TILE_V   = "tileV",
    CLAMP    = "clamp",
    NAME     = "name",
    KIND     = "kind",
}

const String INVALID_NODE_NAME = "[35, 116, 101, 120, 116]";
const String MATERIAL_NODE     = "MATERIAL";

struct MTR_MatMap
{
    Texture2D* tex;
    Color color;
    MTR_MatMapArgs args;
}

fn void MTR_MatMap.clear(&self) 
{
    if(self.tex) self.tex = null;
    foreach (arg : self.args)
    {
       if(arg != null) mem::free(arg);
    }
}

struct HMaterial
{
    String name, comment;
    
    MTR_MatMap diffuse;
    //MTR_MatMap normal;
    //MTR_MatMap spec;
    //Texture2D* bump;
    //Texture2D* rough;
    //Texture2D* metal;
    //Texture2D* ao;
    //Texture2D* cube;
    
    //shdshd::Sound* sound;
}

struct HM_mtr_Data
{
    String path;
    MaterialList mats;
}

fn void HM_mtr_Data.unload(&self) @inline 
{
	foreach(mat: self.mats) mat.free();
    self.mats.free();
}

// This will probably be very slow...
fn HMaterial* HM_mtr_Data.getMaterial(&self, String name) @inline 
{
	foreach(mat: self.mats) {
		if(mat.name == name) return mat;
	}
    
	return null;
}

fn void print_material_map_data(HMaterial* mat) @local @inline
{
    if(mat)
    {
        io::printfn("   [map : 'Diffuse']");
        io::printfn("       tex: \"%s\"", mat.diffuse.tex);
        io::printfn("       color: \"%s\"", mat.diffuse.color);
        foreach(i, arg : mat.diffuse.args) io::printfn("       arg%d: \"%s = %s\"", i, arg.first, arg.second);
    }
}

fn void HM_mtr_Data.printMaterials(&self) @inline 
{
    if(self.mats.len()) 
    {
        foreach(mat: self.mats) 
        {
             io::printfn("[material : '%s']", mat.name);
             if(mat.comment.len) {
                io::printfn("   comment = \"%s\"", mat.comment);
             }
             print_material_map_data(mat);
        }
    }
}

fn bool? HM_mtr_Data.load(&self, String file_path) @inline
{
    if(self.parse(file_path) == false) {
        return MATERIAL_PARSING_ERROR?;
    }
    
    return true;
}

fn bool HM_mtr_Data.parse(&self, String file_path)
{
    // load mtr file
    MTRFile? file = fs::openFile(file_path, "r");
    defer file.close()!!;
    
    if(catch excuse = file) 
    {
       lgr::warning(Where.FILE, " Failed to open mtr file at [%s] with excuse: %s", file_path, excuse);
       // DOC(HM) I need to return from a catch or the excuse will not unwrap,
       // and causes variable shadow error, preventing me from using excuse again bellow.
       return false; 
    }
    
    self.path = file_path;
    
    XmlDoc*? doc = xml::read_file(file);
    defer doc.free()!!;
    
    if(catch excuse = doc) 
    {
       lgr::warning(Where.FILE, " Failed to open xml file [%s] with excuse: %s", file_path, excuse);
       // DOC(HM) I need to return from a catch or the excuse will not unwrap,
       // and causes variable shadow error, preventing me from using excuse again.
       return false; 
    }
    
    bool invalid_mtr = doc.rootNode.name != MTR_Node.ROOT.name;
    if(invalid_mtr) 
    {
       lgr::error(Where.FILE, " Invalid root node found in mtr file [%s], expected 'MTR' found '%s'", file_path, doc.rootNode.name);
       return false;
    }
    
    foreach (node : doc.rootNode.children)
    {
       if(node == null) continue;
       if(node.name == INVALID_NODE_NAME) continue;
       if(node.name != MATERIAL_NODE) 
       {
            lgr::warning(Where.FILE, " Non material node [%s] found in mtr '%s'", node.name, file_path);
            continue;
       }
       
       self.mats.push(parse_material_node(node, self));
    }
    
    return true;
}

<*
    @param [in] node : "node to compare the name"
    @require node != null
*>
fn bool XmlNode.isNode(XmlNode* node, MTR_Node kind) @inline @local => (node.name == kind.name) ? true : false;

<*
    @param [in] mat_node : "material node we are currently parsing"
    @param [in] mtr_file : "parsed mtr file data"
    @require mat_node != null && mtr_file != null
*>
fn HMaterial* parse_material_node(XmlNode* mat_node, HM_mtr_Data* mtr_file)
{
    //XmlNodeList materialNodes;
    //defer materialNodes.free();
   
    //doc.find_nodes_by_tag_name("MATERIAL", &materialNodes);
    //assert(materialNodes.len() > 0);
    //XmlNode* main_node = doc.rootNode; //doc.get_node("MATERIAL");
    //assert(main_node != null);
    
    // create the material structure to save the parsed data into
    HMaterial* mat = mem::new(HMaterial);
    
    // get material name
    String? mat_name = (String)mat_node.get_attrib_value(MTR_NodeAttrib.NAME);
    if (catch excuse = mat_name)
    {
        lgr::error(Where.FILE, "Failed to get a material name attribute in %s with excuse: %s\n", mtr_file.path, excuse);
        mem::free(mat);
        return null;
    }
    
    mat.name = mat_name;
    if (mat_name == "")
    {
        lgr::error(Where.FILE, "material with empty name attribute in %s\n", mtr_file.path);
        mem::free(mat);
        return null;
    }
    
    // parse extra material atribbutes if any
    if(mat_node.attributes.len() > 1) 
    {
        parse_material_atributes(mat_node, mat, mtr_file);
    }

    // start parsing the material internal nodes
    foreach (node : mat_node.children)
    {
       // in case...
       if(node == null) continue;
       if(node.name == INVALID_NODE_NAME) continue;
       //
       if(node.isNode(MTR_Node.COMMENT)) parse_material_comment(*node, mat, *mtr_file);
       
       if(node.isNode(MTR_Node.MAPS))
       {
            parse_material_maps(node, mat, mtr_file);
       }
       
       if(node.isNode(MTR_Node.SOUND))
       {
            parse_material_sound(*node, mat, *mtr_file);
       }
    }
    
    return mat;
}

fn String getNodeText(XmlNode* node) @local
{
    usz child_count = node.children.len();
    if(child_count >= 1) {
        String result = node.children[0].value;
        if(child_count > 1) {
            for(int i = 1; i < child_count; i++) {
                result = result.tconcat(node.children[i].value);
            }
        }
        return result;
    }
    
    return "";
}
<*
    @param [inout] mat : "material to save parsed data into"
    @require mat != null
*>
fn void parse_material_comment(XmlNode node, HMaterial* mat, HM_mtr_Data mtr_file) @inline @local
{
    mat.comment = getNodeText(&node);
}

<*
    @param [inout] mat : "material to save parsed data into"
    @param node : "node we are currently parsing"
    @require mat != null && node.asAttributes() == true
*>
fn void parse_material_sound(XmlNode node, HMaterial* mat, HM_mtr_Data mtr_file) @inline @local
{
   parse_node_atributes(&node, mat, &mtr_file);
            
   // TODO make sound shaders
   //self.sound = astmng::assetManager.getSound(sound_shader_name);
}

fn void parse_material_maps(XmlNode* maps_node, HMaterial* mat, HM_mtr_Data* mtr_file) 
{
    foreach(node: maps_node.children)
    {
        if(node.name == INVALID_NODE_NAME) continue;
        switch(node.name)
        {
            case MTR_Node.ALBEDO:
                foreach(child: node.children)
                {
                    if(child == null) continue;
                    if(child.isNode(MTR_Node.MAP))
                    {
                        String texture_name = getNodeText(child).extractFileBaseByCopy();
                        if(texture_name == "default.png") {
                            mat.diffuse.tex = &main::gpGame.default_texture;
                        } else {
                            mat.diffuse.tex = (Texture2D*)main::asstManager.getAssetExt(texture_name, Texture2D.typeid).data.ptr;
                        }
                    }
                    if(child.isNode(MTR_Node.COLOR))
                    {
                        mat.diffuse.color = xmlStrColorToColor(getNodeText(child));
                    }
                    if(child.isNode(MTR_Node.ARGS) || child.asAttributes()) {
                        parse_material_map_args(&mat.diffuse, child);
                        handle_material_map_args(&mat.diffuse, child, mat, mtr_file);
                    }
                }
            case MTR_Node.VIDEO_MAP: break;
                if(node.asAttributes())
                {
                   parse_node_atributes(node, mat, mtr_file);
                }
            case MTR_Node.NORMAL: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(MTR_Node.MAP))
                    // {
                        // mat.normal.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(MTR_Node.ARGS) || child.asAttributes()) {
                        // get_material_map_atributes_data(&mat.normal, child);
                        // parse_material_map_args(&mat.normal, child, mat, mtr_data);
                    // }
                // }
            case MTR_Node.SPECULAR: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(MTR_Node.MAP))
                    // {
                        // mat.spec.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(MTR_Node.ARGS) || child.asAttributes()) {
                        // get_material_map_atributes_data(&mat.spec, child);
                        // parse_material_map_args(&mat.spec, child, mat, mtr_data);
                    // }
                // }
            default:
               unreachable("invalid material maps node found!!");
        }
    }
}

fn Color xmlStrColorToColor(String value) @local
{
    String[] chars = value.tsplit(" ");
    assert(chars.len == 4);
    
    Color result;
    
    result.r = chars[0].to_uchar()!!;
    result.g = chars[1].to_uchar()!!;
    result.b = chars[2].to_uchar()!!;
    result.a = chars[3].to_uchar()!!;
    
    return result;
}

<*
    @param [in] node : "node we are parsing"
    @param [inout] mat : "material to save parsed data into"
    @param [in] mtr_file : "the parsed file data, mostly used to get the file path for logging"
    @require node != null && mat != null && mtr_file != null && node.asAttributes() == true
*>
fn void parse_material_atributes(XmlNode* node, HMaterial* mat, HM_mtr_Data* mtr_file)
{
    //io::printfn("START parsing Material '%s' attributes:", node.name);
    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       
       switch(atrb.name)
       {
        case MTR_NodeAttrib.NAME:
            continue; // name atrribute is handled seperatly
        default:
           io::printfn("Unnused atribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, mat.name, mtr_file.path);
       }
    }
    //io::printfn("END parsing Material '%s' attributes:", node.name);
}

<*
    @param [in] node : "current node we are parsing"
    @param [inout] mat : "the material we are saving data into"
    @param [in] mtr_file : "the parsed file data, mostly used to get the file path for logging"
    @require node != null && mat != null && mtr_file != null && node.asAttributes() == true
*>
fn void parse_node_atributes(XmlNode* node, HMaterial* mat, HM_mtr_Data* mtr_file)
{
    //io::printfn("START parsing node '%s' attributes:", node.name);
    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       
       switch(atrb.name)
       {
        case MTR_NodeAttrib.NAME: continue;
        case MTR_NodeAttrib.PATH:
        case MTR_NodeAttrib.KIND:
           io::printfn("  %s = %s,", atrb.name, atrb.value);
        default:
           io::printfn("Unnused node attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, mat.name, mtr_file.path);
       }
    }
    //io::printfn("END parsing node '%s' attributes:", node.name);
}

<*
    @param [in] node : "node we are parsing"
    @param [inout] map : "the texture map we are saving parsed data into"
    @require node != null && map != null && node.asAttributes() == true
*>
fn void parse_material_map_args(MTR_MatMap* map, XmlNode* node)
{
    foreach (arg : node.attributes)
    {
       if(arg == null) continue;
       // else
       map.args.push(mem::new(StringTuple, {arg.name, arg.value}));
    }
}

<*
    @param [inout] map : "the texture map we are getting parsed data from"
    @param [in] node : "current node we are parsing"
    @param [inout] mat : "the material we are saving data into"
    @param [in] mtr_file : "the parsed file data, mostly used to get the file path for logging"
    @require map != null && node != null && mat != null && mtr_file != null
*>
fn void handle_material_map_args(MTR_MatMap* map, XmlNode* node, HMaterial* mat, HM_mtr_Data* mtr_file)
{
    //io::printfn("START parsing map '%s' arguments:", node.name);
    foreach (arg : map.args)
    {
       if(arg == null) continue;
       
       switch(arg.first)
       {
        case MTR_MapArgs.TILE_H:
        case MTR_MapArgs.TILE_V:
        case MTR_MapArgs.CLAMP:
        case MTR_MapArgs.KIND:
           io::printfn("  %s = %s,", arg.first, arg.second);
        default:
           io::printfn("Unnused map argument '%s' found in node '%s' of material '%s' in file '%s'!", arg.first, node.name, mat.name, mtr_file.path);
       }
    }
    //io::printfn("END parsing map '%s' arguments:", node.name);
}

fn void HMaterial.free(&self)
{
	self.diffuse.clear();
}

fn void HMaterial.copy(&self, HMaterial* other)
{
	self.diffuse.tex = other.diffuse.tex;
    self.diffuse.args.add_all(&other.diffuse.args);
}

fn Texture2D* HMaterial.getTexture(&self, rl::MaterialMapIndex index = ALBEDO, bool isPBR = false)
{
    /*
    ALBEDO,            // Albedo material (same as: MATERIAL_MAP_DIFFUSE)
    METALNESS,         // Metalness material (same as: MATERIAL_MAP_SPECULAR)
    NORMAL,            // Normal material
    ROUGHNESS,         // Roughness material
    OCCLUSION,         // Ambient occlusion material
    EMISSION,          // Emission material
    HEIGHT,            // Heightmap material
    CUBEMAP,           // Cubemap material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
    IRRADIANCE,        // Irradiance material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
    PREFILTER,         // Prefilter material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
    BRDF,              // Brdf material
    DEPTH0,            // New depth map index shadow for light1
    DEPTH1,            // New depth map index shadow for light2
    DEPTH2,            // New depth map index shadow for light3
    DEPTH3             // New 
    */
    switch(index)
    {
        /*case NORMAL:
            return self.normal.tex;
        case METALNESS: // this is both specular and metalness for pbr
            return (isPBR == true) ? self.metal.tex : self.spec.tex;
        case HEIGHT:
            return self.bump.tex;
        case ROUGHNESS:
            return self.rough.tex;
        case OCCLUSION:
            return self.ao.tex;
        case CUBEMAP:
            return self.cube.tex;*/
        case ALBEDO:
        default:
            return self.diffuse.tex;
    }
}


module game::material::database::mtrdb;

// region imports
import std::io;
import game::main; // for file logging or console logging
import engine::misc;
import game::material::mtr;
import engine::logging::lgr;
import std::collections::list, std::collections::tuple;
import engine::assets::astmng;
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
// end_region

alias MTR_FileList = List{HM_mtr_Data*};

struct MTR_DataBase 
{
    MTR_FileList data;
}

faultdef INVALID_PATH_STRING,
	     MALFORMED_MTR_FILE,
	     UNKNOWN_FOLDER,
	     FOLDER_SCAN_ERROR,
	     MTR_LOAD_ERROR,
	     SMALL_PATH_ERROR,
	     MTR_RETRIVAL_ERROR,
	     MISSING_MTR;


<*
    @param search_path : "where to look for the mtr files"
    @param [inout] database : "the database where to register the mtr files"
    @require database != null && search_path.len >= 2
*>
fn void? load_mtr_files(String search_path, MTR_DataBase* database) @local 
{
	PathList? paths = path::ls(tmem, path::temp(search_path));
	if(catch excuse = paths) {
		lgr::warning(Where.FILE,  "Unable get mtr files paths from folder: %s with excuse: %s", search_path, excuse);
		return FOLDER_SCAN_ERROR?;
	}
	
	foreach(path: paths)
	{
		String asset_path = search_path.tconcat(path.str_view());
        
        if(!fs::isFile(asset_path)) continue;
        
		{ // else try to load mtr files
			String file_name = fs::getFileNameWithoutExt(asset_path);
			// NOTE(HM) ignore default assets those are handled elsewhere
            // plus there's no default mtr...
			if (file_name == "default") 
            {
                lgr::warning(Where.FILE, " unexpected '%s' file name found inside material folder.", file_name);
				continue; // to next file
			}
			
			if(fs::getFileExtension(asset_path) != ".mtr") 
            {
                lgr::warning(Where.FILE, " unexpected non mtr file '%s' found inside material folder.", file_name);
				continue; // to next file
			}
			
			// from here should be a valid mtr file
			
            HM_mtr_Data* mtr_file = mem::new(HM_mtr_Data);
            if(catch excuse = mtr_file.load(asset_path))
            {
                lgr::warning(Where.FILE, " Failed to parse [%s]", asset_path);
                mem::free(mtr_file);
                continue; // to next file
            }
			
            // every thing is fine save the mtr file in database
            database.register(mtr_file);
		}
        
		//continue to next file
	}
}

<*
    @param [inout] db : "material file data base"
    @require main::gpGame.app_base_folder.len > 0
*>
fn void? loadMaterialFiles(MTR_DataBase* db) @inline
{
    String material_folder = main::gpGame.app_base_folder.tconcat("materials").tconcat("\\");
	load_mtr_files(material_folder, db)!!;
}


// This will probably be very slow...
fn HMaterial* MTR_DataBase.findMaterial(&self, String name) @inline 
{
	foreach(mtr: self.data)
    {
        HMaterial* mat = mtr.getMaterial(name);
		if(mat != null) return mat;
	}
    
	return null;
}

<*
* @param [inout] mtr : "the mtr file to register"
* @require mtr != null
*>
fn void MTR_DataBase.register(&self, HM_mtr_Data* mtr) @local @inline {
	self.data.push(mtr);
}

fn void MTR_DataBase.listMTRs(&self) @if($feature(_DEBUG)) 
{
	if(self.data.len())
	{
		lgr::info(Where.CONSOLE, "[MATERIAL FILES]");
		foreach(mtr: self.data) {
			io::printfn("\t-> \"%s\"", mtr.path);
		}
	}
}

// WARNING(HM) 06/11/2024
// To be used only at game exit, for now mtr files are loaded at game start and stay in RAM, 
// during the entire game run, they only get freed at game end.
// This is done this way for now, because I don't have many mtr files in this game for now,
// if that changes someday I will refactor this,
// for now getting them hot from RAM, is very fast, compared
// 	to reading the data from the HD/SSD/MD2 drive.
fn void MTR_DataBase.clear(&self) @inline
{
	if(self.data.len()) 
    {
		foreach(mtr: self.data) mtr.unload();
		self.data.free();
	}
}
