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

enum MTR_Node : int (inline String name)
{
    ROOT     = "MTR",
    MATERIAL = "MATERIAL",
    COMMENT  = "comments",
    MAPS     = "maps",
    MAP      = "map",
    ARGS     = "args",
    COLOR    = "color",
    ALBEDO   = "albedo",
    NORMAL   = "normal",
    SPECULAR = "specular",
    SOUND    = "sound",
    SHADER   = "shader"
}

enum MTR_Attrib : int (inline String name)
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

fn void HM_mtr_Data.load(&self, String file_path) @inline
{
    if(self.parse(file_path) == false) {
        lgr::warning(Where.FILE, " Failed to parse [%s]", file_path);
    }
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

fn HMaterial* parse_material_node(XmlNode* mat_node, HM_mtr_Data* mtr_data)
{
    //XmlNodeList materialNodes;
    //defer materialNodes.free();
   
    //doc.find_nodes_by_tag_name("MATERIAL", &materialNodes);
    //assert(materialNodes.len() > 0);
    //XmlNode* main_node = doc.rootNode; //doc.get_node("MATERIAL");
    //assert(main_node != null);
    
    HMaterial* mat = mem::new(HMaterial);
    
    String? mat_name = (String)mat_node.get_attrib_value(MTR_Attrib.NAME);
    if (catch excuse = mat_name) {
        lgr::error(Where.FILE, "Failed getting Material name from %s with excuse: %s\n", mtr_data.path, excuse);
        return null;
    }
    mat.name = mat_name;

    foreach (node : mat_node.children)
    {
       if(node == null) continue;
       //if(node.name == INVALID_NODE_NAME) continue;
       if(node.isNode(MTR_Node.COMMENT)) mat.comment = node.value;
       
       if(node.isNode(MTR_Node.MAPS))
       {
            parse_material_maps(node, mat, mtr_data);
       }
       
       if(node.isNode(MTR_Node.SOUND)) 
       {
            if(node.asAttributes()) {
                parse_material_node_atributes(node, mat, mtr_data);
            }
            
            // TODO make sound shaders
            //self.sound = astmng::assetManager.getSound(sound_shader_name);
       }
    }
    
    return mat;
}

fn void parse_material_maps(XmlNode* maps_node, HMaterial* mat, HM_mtr_Data* mtr_data) 
{
    foreach(node: maps_node.children)
    {
        //if(map.name == INVALID_NODE_NAME) continue;
        switch(node.name)
        {
            case MTR_Node.ALBEDO:
                foreach(child: node.children)
                {
                    if(child == null) continue;
                    if(child.isNode(MTR_Node.MAP))
                    {
                        mat.diffuse.tex = astmng::assetManager.getTexture(child.value);
                    }
                    if(child.isNode(MTR_Node.COLOR))
                    {
                        mat.diffuse.color = xmlStrColorToColor(child.value);
                    }
                    if(child.isNode(MTR_Node.ARGS) || child.asAttributes()) {
                        get_material_map_atributes_data(&mat.diffuse, child);
                        parse_material_map_args(&mat.diffuse, child, mat, mtr_data);
                    }
                }
            // case MTR_Node.NORMAL:
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
            // case MTR_Node.SPECULAR:
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

fn Color xmlStrColorToColor(String value) @local @inline
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


fn void parse_material_node_atributes(XmlNode* node, HMaterial* mat, HM_mtr_Data* mtr_data)
{
    io::printfn("START parsing Material '%s' attributes:", node.name);
    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       
       switch(atrb.name)
       {
        case MTR_Attrib.NAME:
            mat.name = atrb.value;
        default:
           io::printfn("Unnused atribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, mat.name, mtr_data.path);
       }
    }
    io::printfn("END parsing Material '%s' attributes:", node.name);
}


fn void get_material_map_atributes_data(MTR_MatMap* map, XmlNode* node)
{
    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       map.args.push(mem::new(StringTuple, {atrb.name, atrb.value}));
    }
}

fn void parse_material_map_args(MTR_MatMap* map, XmlNode* node, HMaterial* mat, HM_mtr_Data* mtr_data)
{
    io::printfn("START parsing map '%s' attributes:", node.name);
    foreach (arg : map.args)
    {
       if(arg == null) continue;
       
       io::printfn("  %s = %s,", arg.first, arg.second);
       
       switch(arg.first)
       {
        case MTR_Attrib.TILE_H:
        case MTR_Attrib.TILE_V:
        case MTR_Attrib.CLAMP:
        case MTR_Attrib.KIND:
        default:
           io::printfn("Unnused map atribute '%s' found in node '%s' of material '%s' in file '%s'!", arg.first, node.name, mat.name, mtr_data.path);
       }
    }
    io::printfn("END parsing map '%s' attributes:", node.name);
}

fn void HMaterial.free(&self)
{
	self.diffuse.clear();
    // if(self.maps.normal)  self.maps.normal  = null;
    // if(self.maps.bump)    self.maps.bump    = null;
    // if(self.maps.spec)    self.maps.spec    = null;
    // if(self.maps.rough)   self.maps.rough   = null;
    // if(self.maps.metal)   self.maps.metal   = null;
    // if(self.maps.ao)      self.maps.ao      = null;
    // if(self.maps.cube)    self.maps.cube    = null;
    //if(self.sound)        self.sound        = null;
}

/*
fn void HMaterial.copy(&self, Material* other)
{
	self.maps.diffuse = other.maps.diffuse;
    self.maps.normal  = other.maps.normal;
    self.maps.bump    = other.maps.bump;
    self.maps.spec    = other.maps.spec;
    self.maps.rough   = other.maps.rough;
    self.maps.metal   = other.maps.metal;
    self.maps.ao      = other.maps.ao;
    self.maps.cube    = other.maps.cube;
    //self.sound        = other.sound;
}

fn Texture2D* Material.getTexture(&self, rl::MaterialMapIndex index, bool isPBR = false) @dynamic
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
        case NORMAL:
            return self.maps.normal;
        case METALNESS: // this is both specular and metalness for pbr
            return (isPBR == true) ? self.maps.metal : self.maps.spec;
        case HEIGHT:
            return self.maps.bump;
        case ROUGHNESS:
            return self.maps.rough;
        case OCCLUSION:
            return self.maps.ao;
        case CUBEMAP:
            return self.maps.cube;
        case ALBEDO:
        default:
            return self.maps.diffuse;
    }
}

fn void Material.load(&self, String file_path) @dynamic @inline
{
    self.parse(file_path);
}

/*
        EXAMPLE USAGE
        
    import std::io;
    import std::core;
    import xml;

    File xmlFile = io::file::open("test/test.xml", "r")!!;
    defer xmlFile.close()!!;

    XmlDoc* doc = xml::read_file(xmlFile)!!;
    defer doc.free();

    XmlNodeList bookNodes;
    defer bookNodes.free();
    
    doc.find_nodes_by_tag_name("book", &bookNodes);
    io::printf("book nodes %d\n", bookNodes.size);

    foreach (node : bookNodes) {
        char[]? id = node.get_attrib_value("id");
        if (catch err = id) {
            io::printf("attribute not found\n");
            continue;
        }
        io::printf("Id %s\n", id);
    }
*/

fn void Material.parse(&self, String file_path) @dynamic
{
/*
    // load test xml file
    String xml_path = local_game.app_base_folder.tconcat("images\\default.xml");
    File? xmlfile = io::file::open(xml_path, "r");
    defer xmlfile.close()!!;
    
    if(catch excuse = xmlfile) {
       lgr::raylibWarning("Failed to open test xml doc with excuse: %s", excuse);
    } else {
    
        XmlDoc* doc = xml::read_file(xmlfile)!!;
        defer doc.free();
        
        XmlNode material_node = doc.get_node("Material");
        
        io::printfn("%s", material_node.name);
        io::printfn("{");
        foreach(atribute : material_node.attributes) {
            io::printfn("%s = %s", atribute.name, atribute.value);
        }
        io::printfn("}");
    }
*/
    // load xml file
    File? file = io::file::open(file_path, "r");
    defer file.close()!!;
    
    if(catch excuse = file) {
       lgr::warning(Where.FILE, " Failed to open material xml at [%s] with excuse: %s", file_path, excuse);
       // DOC(HM) I need to return from a catch or the excuse will not unwrap,
       // and causes variable shadow error, preventing me from using excuse again bellow.
       return; 
    }
    
    XmlDoc* doc = xml::read_file(file)!!;
    defer doc.free();
    
    assert(doc.rootNode.name == "MATERIAL");
       
    XmlNodeList materialNodes;
    defer materialNodes.free();
   
    //doc.find_nodes_by_tag_name("MATERIAL", &materialNodes);
    //assert(materialNodes.len() > 0);
    XmlNode* main_node = doc.rootNode; //doc.get_node("MATERIAL");
    assert(main_node != null);
    
    String! id = (String)main_node.get_attrib_value("name");
    if (catch excuse = id) {
        lgr::error(Where.FILE, "Failed getting Material name from %s with excuse: %s\n", file_path, excuse);
        main_node = null;
        return;
    } 
    
    self.name = id;
    self.path = file_path;

    foreach (node : main_node.children) {
       if(node == null) continue;
       if(node.name == INVALID_NODE_NAME) continue;
       if(node.name == "comments") {
            io::printfn("%s", node.value);
       }
       
       if(node.name == "maps") {
            foreach(map: node.children) {
                if(map.name == INVALID_NODE_NAME) continue;
                switch(map.name)
                {
                    case "albedo":
                        self.maps.diffuse = astmng::assetManager.getTexture(map.value);
                    case "normal":
                        self.maps.normal  = astmng::assetManager.getTexture(map.value);
                    case "specular":
                        self.maps.spec    = astmng::assetManager.getTexture(map.value);
                    default:
                       unreachable("invalid material maps found");
                }
            }
       }
       
       if(node.name == "sound") {
            String attribute_name = "impact";
            String! sound_shader_name = (String)node.get_attrib_value(attribute_name);
            if (catch excuse = sound_shader_name) {
                io::printf("Material %s attribute %s not found: %s\n", node.name, attribute_name, excuse);
                continue;
            }
            
            // TODO make sound shaders
            //self.sound = astmng::assetManager.getSound(sound_shader_name);
       }
    }
    /*
    
    mlNode node = doc.get_node("Material");
    
    ssert(node.name == "Material");
    
    elf.name = node.node.get_attrib_value("Name");
    elf.path = file_path;
    
    tring albedo = node.get_attrib_value("Diffuse").extractFileBaseByCopy();
    elf.maps.diffuse = astmng::assetManager.getTexture(albedo);
    io::printfn("{");
    foreach(atribute : material_node.attributes) {
        io::printfn("%s = %s", atribute.name, atribute.value);
    }
    io::printfn("}");
    */
}


//////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
////////////////////// DELETE WHEN NOT USEFULL ////////////

/*
interface AssetInterface {
	fn void load(String path, typeid type, String name);
	fn void unload();
}

struct Asset (AssetInterface)
{
	String name;
	String path;
	any    data;
}

fn Asset* make_new(String name, String filepath, typeid type) {
    Asset* asset = mem::new(Asset);
    asset.load(filepath, type, name);
    return asset;
}

fn void free_Asset(Asset* asset) {
    mem::free(asset);
    asset = null;
}

fn void Asset.load(&self, String path, typeid type, String name = "") @dynamic {
	self.path = path;
    self.name = (name) ? name : fs::getFileName(path);
   //mem::@assert_leak() {
        switch {
            case type == Texture2D.typeid:
                Texture2D* tex = mem::new(Texture2D);
                mem::move(tex, &&rl::loadTexture(path.zstr_tcopy()), Texture2D.sizeof);
                self.data = any_make(tex, type);
            case type == Shader.typeid:
                Shader* shader = mem::new(Shader);
                ZString extra_path = "";
                if(path.ends_with(".vs")) {
                    if(fs::fileExists(path.tconcat(".fs"))) {
                        extra_path = path.tconcat(".fs").zstr_tcopy();
                    }
                    mem::move(shader, &&rl::loadShader(path.zstr_tcopy(), extra_path), Shader.sizeof);
                } else if (path.ends_with(".fs")) {
                    if(fs::fileExists(path.tconcat(".vs"))) {
                        extra_path = path.tconcat(".vs").zstr_tcopy();
                    }
                    mem::move(shader, &&rl::loadShader(extra_path, path.zstr_tcopy()), Shader.sizeof);
                } else {
                    assert(path.contains(".") == false);
                    mem::move(shader, &&rl::loadShader(path.tconcat(".vs").zstr_tcopy(), path.tconcat(".fs").zstr_tcopy()), Shader.sizeof);
                }
                self.data = any_make(shader, type);
            case type == Sound.typeid:
                Sound* sound = mem::new(Sound);
                mem::move(sound, &&rl::loadSound(path.zstr_tcopy()), Sound.sizeof);
                self.data = any_make(sound, type);
            case type == Music.typeid:
                Music* music = mem::new(Music);
                mem::move(music, &&rl::loadMusicStream(path.zstr_tcopy()), Music.sizeof);
                self.data = any_make(music, type);
            case type == Font.typeid:
                Font* font = mem::new(Font);
                mem::move(font, &&rl::loadFont(path.zstr_tcopy()), Font.sizeof);
                self.data = any_make(font, type);
            default:
                unreachable("Can't load Asset \"%s\" at \"%s\", is unknown type.", self.name, self.path);
        }
   //};
}

<*
* @require self.data != null; 
*>
fn void Asset.unload(&self) @dynamic {
	switch {
		case self.data.type == Texture2D.typeid:
			rl::unloadTexture(*anycast(self.data, Texture2D)!!);
		case self.data.type == Shader.typeid:
			rl::unloadShader(*anycast(self.data, Shader)!!);
		case self.data.type == Sound.typeid:
			rl::unloadSound(*anycast(self.data, Sound)!!);
		case self.data.type == Music.typeid:
			rl::unloadMusicStream(*anycast(self.data, Music)!!);
		case self.data.type == Font.typeid:
			rl::unloadFont(*anycast(self.data, Font)!!);
		default:
			unreachable("Can't unload Asset \"%s\" at \"%s\", is unknown type.", self.name, self.path);
	}
	mem::free(self);
}
// end_region module

//////////////////////// ASSET MANAGER /////////////////////////////////
// region module
module engine::assets::astmng;

// region imports
import std::io::path;
import std::collections::list;
import thirdparty::raylib5::rl;
import game::main;
import engine::assets_api::asapi;
import engine::logging::lgr;
import engine::filesystem::fs;
import engine::misc;
// end_region

faultdef INVALID_ASSETS_PATH_STRING,
	     MALFORMED_PATHS_FILE,
	     UNKNOWN_FOLDER,
	     FOLDER_SCAN_ERROR,
	     ASSET_LOAD_ERROR,
	     SMALL_ASSET_PATH,
	     ASSET_RETRIVAL_ERROR,
	     MISSING_ASSET;


// NOTE(HM) 
// If this is changed need to update FILE_EXTENSIONS_ARRAY in hm_lib_funcs.c3 as well.
const String[*] VALID_ASSET_EXTENSIONS = {
	".png",
	".jpg",
	".tga",
	".dds",
	".bmp",
	".mp3",
	".vs",
	".fs",
	".wav",
	".ogg",
	".fnt"
};

alias AssetListPtr = List{Asset*};

struct Manager {
	AssetListPtr assets;
}

Manager local_manager @local;
Manager* assetManager = &local_manager;

<*
* @param asset "the asset to register"
* @require asset != null
*>
fn void Manager.register(&self, Asset* asset) @local @inline {
	self.assets.push(asset);
}

fn void Manager.listAssets(&self) @if($feature(_DEBUG)) {
	AssetListPtr texture_assets;
	AssetListPtr shader_assets;
	AssetListPtr sound_assets;
	AssetListPtr music_assets;
	AssetListPtr font_assets;
	if(self.assets.len()) 
	{
		foreach(asset: self.assets) {
			if(asset) {
				//String name;
				//String path;
				//any    data;
				switch {
					case asset.data.type == Texture2D.typeid:
						texture_assets.push(asset);
					case asset.data.type == Shader.typeid:
						shader_assets.push(asset);
					case asset.data.type == Sound.typeid:
						sound_assets.push(asset);
					case asset.data.type == Music.typeid:
						music_assets.push(asset);
					case asset.data.type == Font.typeid:
						font_assets.push(asset);
					default:
						unreachable("Can't push asset \"%s\" at \"%s\", for listing, is unknown type.", asset.name, asset.path);
				}
			}
		}
	}
	
	if(texture_assets.len()) 
	{
		lgr::info(Where.CONSOLE, "[TEXTURES]");
		foreach(asset: texture_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(shader_assets.len()) 
	{
		lgr::info(Where.CONSOLE, "[SHADERS]");
		foreach(asset: shader_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path[0:asset.path.len - 3]);
		}
	}
	if(sound_assets.len()) 
	{
		lgr::info(Where.CONSOLE, "[SOUNDS]");
		foreach(asset: sound_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(music_assets.len()) 
	{
		lgr::info(Where.CONSOLE, "[MUSIC]");
		foreach(asset: music_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(font_assets.len()) 
	{
		lgr::info(Where.CONSOLE, "[FONTS]");
		foreach(asset: font_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
}

// WARNING(HM) 06/11/2024
// To be used only at game exit, for now assets are all loaded at game start and stay in RAM, 
// during the entire game run, aka they only get freed at game end.
// I made this like so because, one I don't have many assets in this game for now,
// nor a way to make individual levels, when that is done I will change this,
// for now getting them hot from RAM, is very fast, compared
// 	to reading the data from the HD/SSD/MD2 drive.
fn void Manager.releaseAllAssets(&self) @inline {
	if(self.assets.len()) {
		foreach(asset: self.assets) {
			if(asset) {
				asset.unload();
			}
		}
		self.assets.free();
	}
}

<*
@require self.assets.len() > 0
*>
fn Asset* Manager.getAsset(&self, String name) @local @inline {
$if $feature(_DEBUG):
	bool failed;
$endif
	
	foreach(asset: self.assets) {
		String asset_name = asset.name;
		
		if(asset_name == name) {
$if $feature(_DEBUG):		
		failed = false;
$endif
			return asset;
		}
		
$if $feature(_DEBUG):		
		failed = true;
$endif
	} //foreach

$if $feature(_DEBUG):
	if(failed) { // to get a valid asset panic
		unreachable();
	}
$endif
	
	return null;
}

fn Asset* Manager.getAssetExt(&self, String name, typeid type) {

	foreach(asset: self.assets) {
		if(asset.name == name && asset.data.type == type) {
			return asset;
		}
	}
	
	return null;
}

<*
@ensure return != null
*>
fn Texture2D* Manager.getTexture(&self, String name) @inline {
    if(name != "") 
    {
        Asset* asset = local_manager.getAsset(name);
        if(asset) {
            assert(asset.data.ptr != null);
            return (Texture2D*)asset.data.ptr;
        }
    }
    
    lgr::warning(Where.FILE,  "[Asset Manager]: Requesting texture asset but returning default texture, because no asset name was provided.");
    return &main::gpGame.default_texture;
}

<*
@ensure return != null
*>
fn Shader* Manager.getShader(&self, String name) @inline {
	Asset* asset = local_manager.getAsset(name);
	if(asset) {
		assert(asset.data.ptr != null);
		return (Shader*)asset.data.ptr;
	} else {
        lgr::warning(Where.FILE,  "[Asset Manager]: Requesting shader asset but returning default shader, because no asset name was provided.");
		return &main::gpGame.default_shader;
	}
}

<*
@ensure return != null
*>
fn Sound* Manager.getSound(&self, String name) @inline {
	Asset* asset = local_manager.getAsset(name);
	if(asset) return (Sound*)asset.data.ptr;
	
    lgr::warning(Where.FILE,  "[Asset Manager]: Requesting sound asset but returning default sound, because no asset name was provided.");
	return &main::gpGame.default_sound;
}

<*
@ensure return != null
*>
fn Music* Manager.getMusic(&self, String name) @inline {
	Asset* asset = local_manager.getAsset(name);
	if(asset) return (Music*)asset.data.ptr;
	
    lgr::warning(Where.FILE,  "[Asset Manager]: Requesting music asset but returning default music, because no asset name was provided.");
	return &main::gpGame.default_music;
}

<*
@ensure return != null
*>
fn Font* Manager.getFont(&self, String name) @inline {
	Asset* asset = local_manager.getAsset(name);
	if(asset) return (Font*)asset.data.ptr;
	
    lgr::warning(Where.FILE,  "[Asset Manager]: Requesting font asset but returning default font, because no asset name was provided.");
	return &main::gpGame.default_font;
}

// end_region module

// NOTE(HM) If this bugs out, consider using rl::getFileNameWithoutExt
// TODO(HM) Test this in speed versus rl::getFileNameWithoutExt
// fn String getAssetNameNoExtFrom(String path) @inline {
	// return path.extractFileBaseByCopy().stripExtension();
// }

fn void loadAsset(String path, String* extension) {
	// load and register it if necessary
	// first see if the asset already exists in the asset data base
	// if it does no need to load it again
	foreach(asset : local_manager.assets) {
		if(asset != null && asset.name == fs::getFileNameWithoutExt(path)) return;
	}
	
	Asset* new_asset = mem::new(Asset);
	
	switch(*extension)
	{
	case ".png":
	case ".jpg":
	case ".tga":
		new_asset.load(path, Texture2D.typeid);
	case ".vs":
	case ".fs":
		new_asset.load(path, Shader.typeid);
	case ".mp3": nextcase;
	case ".ogg":
		new_asset.load(path, Music.typeid);
	case ".wav":
		new_asset.load(path, Sound.typeid);
	case ".fnt":
		new_asset.load(path, Font.typeid);
	};
	
	local_manager.register(new_asset);
}

fn void? loadAssetsRecursively(String basepath, String parent_folder = "") @inline @local {
	String search_path = basepath;
	if(parent_folder != "") {
		if (parent_folder.ends_with("\\")) {
			search_path = parent_folder.tconcat(basepath).tconcat("\\");
		} else {
			search_path = parent_folder.tconcat("\\").tconcat(basepath).tconcat("\\");
		}
	}
	
	PathList? paths = path::ls(tmem, path::temp(search_path));
	if(catch excuse = paths) {
		lgr::warning(Where.FILE,  "Unable to get files from folder: %s with excuse: %s", search_path, excuse);
		return FOLDER_SCAN_ERROR?;
	}
	
	foreach(path: paths)
	{
		String path_ = search_path.tconcat(path.str_view());
		if(fs::isFile(path_)) { // try to load it
			String file_name = fs::getFileNameWithoutExt(path_);
			// ignore default assets those are handled directly
			if (file_name == "default") continue; // to next file
			
			String extension = fs::getFileExtension(path_);
			bool valid_file;
			
			foreach(ext: VALID_ASSET_EXTENSIONS) {
				if(extension == ext) { valid_file = true; break; }
			}
			
			if(valid_file == false) {
				continue; // to next file
			}
			
			// from here should be a valid file
			
			String asset_path = search_path;
			if (asset_path.ends_with("\\")) {
				asset_path = asset_path.tconcat(path.str_view());
			} else {
				asset_path = asset_path.tconcat("\\").tconcat(path.str_view());
			}
			
			// NOTE(HM) 06/11/2024 
			// When looking at C3 strings in Visual Studio dbg, take note of the 
			// 	string len value, this is important, because the watch window will show them as 
			// 	a normal char[] (array of characters) and so will ignore the len value, 
			// 	displaying all characters, untill a zero or null terminator character is found.
			// 	meaning it will display invalid characters.
			// Thou the strings will work fine when used, like when compared bellow for example.
			// This caused me confusion a bunch of times, I was expecting to see cliped/cut strings 
			// 	in VS but they always showed as if no cut was ever done. 
			// To see them as expected, look at C3 strings in watch window, 
			// 	like so -> str.ptr, len
			loadAsset(asset_path, &extension);
			continue; // to next file
			
		} else { // is a child folder/Directory
			loadAssetsRecursively(path.str_view(), search_path)!;
		}
	}
}

<*
*@require main::gpGame.app_base_folder.len > 0
*>
fn void? loadAssets() {

	float loadAsset_st = @start_profile_zone();
	defer @end_profile_zone(loadAsset_st);
	
	loadAssetsRecursively(main::gpGame.app_base_folder)!!;
	
	$if $feature(_DEBUG):
		//assetManager.listAssets();
	$endif
}
