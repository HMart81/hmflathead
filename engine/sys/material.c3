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
module game::material::mtr @private;

// region imports
import std::io, std::math;
import game::main; // for file logging or console logging
import engine::misc;
import game::serialize::svs;
import game::material::manager::mtrmng;
import engine::logging::lgr;
import engine::filesystem::fs;
import engine::assets::astmng;
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

alias MaterialList       = List{HMaterial*};
alias MaterialMapArgList = List{StringTuple*};

faultdef INVALID_PATH_STRING,
	     MALFORMED_MTR_FILE,
	     UNKNOWN_FOLDER,
         MATERIAL_PARSING_ERROR,
	     FOLDER_SCAN_ERROR,
	     MTR_LOAD_ERROR,
	     SMALL_PATH_ERROR,
	     MTR_RETRIVAL_ERROR,
	     MISSING_MTR;


// NOTE(HM) This represents every usefull node in the mtr xml file 
enum Node : int (inline String str)
{
    //INVALID   = "[35, 116, 101, 120, 116]", // = "[#text]" for some reason the current third party xml reader I use, creates this invalid #text node...
    ROOT      = "MTR",
    TEXT      = "#text",
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

// NOTE(HM) This represents the atributes assigned to a xml node
enum NodeAttrib : int (inline String str)
{
    NAME     = "name",
    VERSION  = "version",
    PATH     = "path",
    KIND     = "kind",
    TRANSLUCENT = "translucent",
}

// NOTE(HM) The same as above but particular to the "map" and "video_map" nodes
// and are called arguments instead of attributes...
enum MapArgs : int (inline String name)
{
    CLAMP    = "clamp",
    TILE_H   = "tileH",
    TILE_V   = "tileV",
    SCROLL_X = "scrollX",
    SCROLL_Y = "scrollY",
    TRANSLATE_X = "translateX",
    TRANSLATE_Y = "translateY",
    ALPHA = "alpha"
}


// TODO(HM) rename this to shader stage or something like that
struct MatMap
{
    //NOTE(HM) width and Height are encoded on the Texture2D data
    Texture2D tex;
    Color color;
    MaterialMapArgList args;
}

fn void MatMap.clear(&self) 
{
    //if(self.tex) self.tex = null;
    rl::unloadTexture(self.tex);
    foreach (arg : self.args)
    {
       if(arg != null) mem::free(arg);
    }
}

struct MatVidMap
{
    inline MatMap super;
}

enum MatMC @public //Material Coverage
{
	BAD,
	OPAQUE,			// completely fills the triangle, will have black drawn on fillDepthBuffer
	PERFORATED,		// may have alpha tested holes
	TRANSLUCENT		// blended with background
}

// contents flags used to mark entities in the game, max 31 bits
enum Contents : int (inline int flag)
{
	SOLID				= misc::@bit(0),	// an eye is never valid in a solid
	OPAQUE				= misc::@bit(1),	// blocks visibility (for ai)
	WATER				= misc::@bit(2),	// used for water
	PLAYERSOLID			= misc::@bit(3),	// solid to players
	MONSTERSOLID		= misc::@bit(4),	// solid to monsters
	MOVEABLESOLID		= misc::@bit(5),	// solid to moveable entities
	BLOOD				= misc::@bit(6),	// used to detect blood decals
	BODY				= misc::@bit(7),	// used for actors
	PROJECTILE			= misc::@bit(8),	// used for projectiles
	CORPSE				= misc::@bit(9),	// used for dead bodies
	RENDERMODEL		    = misc::@bit(10),	// used for render models for collision detection
	TRIGGER			    = misc::@bit(11),	// used for triggers
	FLASHLIGHT_TRIGGER	= misc::@bit(12),	// used for triggers that are activated by the flashlight
	TERRAIN			    = misc::@bit(13),	// used to mark surfaces as terrain
    ///
    PLACEHOLDER0	    = misc::@bit(14),
    PLACEHOLDER1	    = misc::@bit(15),
    PLACEHOLDER2	    = misc::@bit(16),
    PLACEHOLDER3	    = misc::@bit(17),
    PLACEHOLDER4	    = misc::@bit(18),
    PLACEHOLDER5	    = misc::@bit(19),
    PLACEHOLDER6	    = misc::@bit(20),
    PLACEHOLDER7	    = misc::@bit(21),
    PLACEHOLDER8	    = misc::@bit(22),
    PLACEHOLDER9	    = misc::@bit(23),
    PLACEHOLDER10	    = misc::@bit(24),
    PLACEHOLDER11	    = misc::@bit(25),
    PLACEHOLDER12	    = misc::@bit(26),
    PLACEHOLDER13	    = misc::@bit(27),
    PLACEHOLDER14	    = misc::@bit(28),
    PLACEHOLDER15	    = misc::@bit(28),
    PLACEHOLDER16	    = misc::@bit(30),
    PLACEHOLDER17	    = misc::@bit(31),
}

bitstruct Flags : char
{
    bool has_AlphaTest;
	bool has_defaulted;
    bool ignoreAlphaTest;
	bool noShadows;
	bool forceShadows;
	bool editor_visible; // in use (visible) per editor
}

struct HMaterial  (SaveSystemInterface) @public
{
    String name;
    String comment;

    MTRFile* mtrfile;
    
    MatMC coverage;
    Contents contentes;
    Flags flags;
    
    MatMap diffuse;
    //MatMap normal;
    //MatMap spec;
    //Texture2D* bump;
    //Texture2D* rough;
    //Texture2D* metal;
    //Texture2D* ao;
    //Texture2D* cube;
    
    //shdshd::Sound* sound;
}

fn void HMaterial.save(&self, SaveFile* file) @dynamic @public {
// todo
}

fn void HMaterial.reload(&self, SaveFile* file) @dynamic @public {
// todo
}

fn void HMaterial.init(&self) @public
{
	self.coverage = MatMC.OPAQUE;
    // TODO(HM) solve this stuff with c3 enums not being able to be used as flags
    // use constants instead of enums for this?
    //self.contentes |= (Contents.SOLID.flag & Contents.OPAQUE.flag);
    self.comment  = "<none>";
    self.diffuse.color = rl::WHITE;
}

fn void HMaterial.free(&self)
{
	self.diffuse.clear();
    if(self.mtrfile) self.mtrfile = null;
}

// @untested
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
            return &self.diffuse.tex;
    }
}


fn String HMaterial.defaultDefinition(self) @inline
{
    String matdef = `
    <MATERIAL name="default_material">
        <comments>This is the required default material</comments>
        <maps>
            <albedo>
                <map>images/default.png</map>
            </albedo>
        </maps>
    </MATERIAL>
    `;
    
	return string::format(mem, "%s", matdef);
}


////////////////////////////////////////////////
//
// MTRFile - Material file data structure
//
///////////////////////////////////////////////

const MTR_VERSION_STRING = "1.0.0"; // the version of the mtr file format

struct MTRFile @public
{
    String path;        // path to the mtr file.
    String version;     // version of the mtr file format, should be MTR_VERSION_STRING.
    MaterialList mats;  // list of materials in this file.
}

fn void MTRFile.unload(&self) @inline @public
{
	foreach(mat: self.mats) mat.free();
    self.mats.free();
}

<*
    @param [in] mat : "material to register"
    @require mat != null
*>
fn void MTRFile.register(&self, HMaterial* mat) @inline @public
{
    self.mats.push(mat);
}

// @Performance This will probably be very slow with many materials...
// TODO(HM) make this faster by using a hash table
fn HMaterial* MTRFile.findMaterial(&self, String name) @inline @public
{
	foreach(mat: self.mats) {
		if(mat.name == name) return mat;
	}
    
	return null;
}


fn void MTRFile.printMaterials(&self) @inline @public
{
    io::printfn("[MTR '%s' v: %s]", fs::getFileNameWithoutExt(self.path), self.version);
    io::printfn("{");
    if(self.mats.len()) {
        foreach(mat: self.mats)
        {
             io::printfn("[material : '%s']", mat.name);
             if(mat.comment.len) {
                io::printfn("\tcomment = \"%s\"", mat.comment);
             }
             print_material_map_data(mat);
        }
    }
    io::printfn("};");
}

fn bool? MTRFile.load(&self, File file) @inline @public
{
    if(self.parse(file) == false) {
        return MATERIAL_PARSING_ERROR?;
    }
    
    return true;
}

fn bool MTRFile.parse(&self, File file)
{
    XmlDoc*? doc = xml::read_file(file);
    defer doc.free()!!;
    
    if(catch excuse = doc)
    {
       lgr::warning(Where.FILE, " Failed to open MTR xml file [%s] with excuse: %s", self.path, excuse);
       return false;
    }
    
    bool invalid_mtr = doc.rootNode.name != Node.ROOT.str;
    if(invalid_mtr)
    {
       lgr::error(Where.FILE, " Malformed material data file '%s', root node expected to be 'MTR' but is '%s' instead.", self.path, doc.rootNode.name);
       return false;
    }

    String? version = (String)doc.rootNode.get_attrib_value(NodeAttrib.VERSION);
    if (catch excuse = version)
    {
        lgr::error(Where.FILE, "Failed to get material version attribute in %s with excuse: %s\n", self.path, excuse);
        return false;
    }
    // else got version, so check if it matches the current version
    // TODO(HM) handle version changes.
    if(version != MTR_VERSION_STRING)
    {
        lgr::error(Where.FILE, " Invalid material data file '%s', version expected to be '%s' but is '%s' instead.", self.path, MTR_VERSION_STRING, version);
        return false;
    }

    self.version = version.copy(mem);
    
    // now parse each MTR xml node
    foreach (node : doc.rootNode.children)
    {
       if(node == null) {
            lgr::warning(Where.FILE, "Null node found in mtr file '%s', skipping it.", self.path);
            continue;
       }

       // Skip any text nodes assigned to the root node (shouldn't happen now though).
       // Text nodes are handled further by the material parser, so we don't need to handle them here.
       if(isXmlNode(node, Node.TEXT)) 
       {
            // This is caused by a bug in the xml reader code (not easy to solve but I worked around it). 
            // The xml reader, treats any end char '>', as always being followed by a Text "node", 
            //  (text between a '>' and a '<'), so in some situtions, it creates empty text nodes, 
            //  like when after a '>' char, came the start char '<' of another node but you add in between them,
            //  spaces or new lines, the xml reader still considers those as valid "text", 
            //  the reader, reads character by character so is not easy to solve this, 
            //  so it will create a text node, regardless if will be empty or not in the end.  
            // The workaround, it now tests for empty text nodes and doesn't register them, in the xml doc file. 
            //continue;
            unreachable("Unexpected text node found in body of MTR '%s'! Text = '%s' ", fs::getFileNameWithoutExt(self.path), node.value);
       }

       if(isXmlNode(node, Node.MATERIAL)) 
       {
            HMaterial* mat = parse_material_node(node, self);
            if(mat) {
                self.register(mat);
            } else {
                //lgr::error(Where.FILE, "Failed to parse material node '%s' in mtr file '%s'", node.name, self.path);
                unreachable("Failed to parse material node '%s' in mtr file '%s'", node.name, self.path);
            }
       } else {
            lgr::warning(Where.FILE, " Unexpected node in mtr file '%s', expected <MATERIAL> found <%s>", self.path, node.name);
            continue;
       }
    }
    
    return true;
}

fn bool check_material_existance(String name) @inline
{
    MaterialDataBase* mtr_db = &main::gpGame.mtrDB;
    foreach(mtr: mtr_db.data)
    {
        bool material_exists = mtr.findMaterial(name) != null;
        if(material_exists) 
        {
            lgr::warning(Where.FILE, "material with name '%s' already exists in %s\n", name, mtr.path);
            return true;
        }
    }
    
    return false;
}

<*
    @param [in] mat_node : "material node we are currently parsing"
    @param [in] file : "parsed mtr file data"
    @require mat_node != null && file != null
*>
fn HMaterial* parse_material_node(XmlNode* mat_node, MTRFile* file)
{
    // create the material structure to save the parsed data into
    HMaterial* mat = mem::new(HMaterial);
    mat.init();
    
    // first get material name
    String? mat_name = (String)mat_node.get_attrib_value(NodeAttrib.NAME);
    if (catch excuse = mat_name)
    {
        lgr::error(Where.FILE, "Failed to get material name attribute in %s with excuse: %s\n", file.path, excuse);
        mat.free();
        mem::free(mat);
        return null;
    }
    
    if (mat_name == "")
    {
        lgr::error(Where.FILE, "material with empty or no name in %s\n", file.path);
        mat.free();
        mem::free(mat);
        return null;
    }

    // check if the material name already exists in the game
    if(check_material_existance(mat_name) == true)
    {
        // file warning print is done inside check_material_existance() function
        mat.free();
        mem::free(mat);
        return null;
    }
    
    // else everything should be fine from here, so keep parsing this material data
    mat.name = mat_name.copy(mem);
    mat.mtrfile = file;
    
    // parse extra material attributes if any
    if(mat_node.attributes.len() > 1)
    {
        parse_node_atributes(mat_node, mat);
    }

    // start parsing the material child nodes
    foreach (node : mat_node.children)
    {
       // just in case...
       if(node == null) {
            lgr::warning(Where.FILE, "Null child node found for material '%s', skipping it.", mat.name);
            continue;
       }

       //(node.name == kind.str)
       switch(node.name)
       {
            // free text nodes are not supported
            case Node.TEXT.str:
            {
                // this is a text node, so we just skip it, as it should not be here
                // TODO(HM) handle this better, maybe by removing it from the xml doc?
                lgr::warning(Where.FILE, "Unexpected text node found in material '%s'! Text = '%s' ", mat.name, node.value);
                continue;
            }
            case Node.COMMENT.str: 
                parse_material_comment(node, mat);
            case Node.ARGS.str: 
            {
                if(node.asAttributes() == true) {
                    parse_node_atributes(node, mat);
                } else {
                    lgr::warning(Where.FILE, "Malformed node '%s' found in material '%s', expected attributes.", node.name, mat.name);
                }
                continue;
            }
            case Node.MAPS.str: 
            {
                parse_material_maps(node, mat);
                continue;
            }
            case Node.SOUND.str: 
            {
                parse_material_sound(node, mat);
                continue;
            }
       }
    }
    
    return mat;
}

<*
    @param [inout] mat : "material to save parsed data into"
    @require mat != null
*>
fn void parse_material_comment(XmlNode* node, HMaterial* mat) @inline @local
{
    String str  = getNodeText(node);
    if(str != "") mat.comment = str.copy(mem);
}

<*
    @param [inout] mat : "material to save parsed data into"
    @param node : "node we are currently parsing"
    @require mat != null && node.asAttributes() == true
*>
fn void parse_material_sound(XmlNode* node, HMaterial* mat) @inline @local
{
   parse_node_atributes(node, mat);
            
   // TODO make sound shaders
   //self.sound = astmng::assetManager.getSound(sound_shader_name);
}

<*
    @param [inout] mat : "material to save parsed data into"
    @param [in] maps_node : "node we are currently parsing"
    @require mat != null && maps_node != null
*>
fn void parse_material_maps(XmlNode* maps_node, HMaterial* mat) 
{
    foreach(node: maps_node.children)
    {
        if(isXmlNode(node, Node.TEXT)) continue;
        
        switch(node.name)
        {
            case Node.ALBEDO:
                foreach(child: node.children)
                {
                    if(child == null) continue;

                    if(isXmlNode(child, Node.MAP))
                    {
                        String texture_path = main::gpGame.app_base_folder.tconcat(getNodeText(child));
                        if(texture_path.extractFileBaseByCopy() == "default.png")
                        {
                            mat.diffuse.tex = main::gpGame.default_texture;
                        } else {
                            mat.diffuse.tex = misc::loadTexture(texture_path);
                        $if $feature(_DEBUG):
                            lgr::info(Where.FILE, "Loaded texture '%s' for material '%s' in file '%s'", texture_path, mat.name, mat.mtrfile.path);
                        $endif
                        }
                    }

                    if(isXmlNode(child, Node.COLOR))
                    {
                        // TODO(HM) handle bad color definitions...
                        mat.diffuse.color = xmlStrColorToColor(getNodeText(child));
                    }

                    if(isXmlNode(child, Node.ARGS)) 
                    {
                        if(child.asAttributes()) 
                        {
                            register_material_map_args(&mat.diffuse, child);
                            handle_material_map_args(&mat.diffuse, child, mat);
                        }
                    }
                }
            case Node.VIDEO_MAP: break;
                /*if(node.asAttributes())
                {
                   parse_node_atributes(node, mat, file);
                }*/
            case Node.NORMAL: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(Node.MAP))
                    // {
                        // mat.normal.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(Node.ARGS) || child.asAttributes()) {
                        // get_material_map_atributes_data(&mat.normal, child);
                        // parse_material_map_args(&mat.normal, child, mat, mtr_data);
                    // }
                // }
            case Node.SPECULAR: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(Node.MAP))
                    // {
                        // mat.spec.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(Node.ARGS) || child.asAttributes()) {
                        // get_material_map_atributes_data(&mat.spec, child);
                        // parse_material_map_args(&mat.spec, child, mat, mtr_data);
                    // }
                // }
            default:
               unreachable("invalid material maps node found!!");
        }
    }
}


<*
    @param [in] node : "current node we are parsing"
    @param [inout] mat : "the material we are saving data into"
    @require node != null && mat != null && node.asAttributes() == true
*>
fn void parse_node_atributes(XmlNode* node, HMaterial* mat)
{
    //io::printfn("START parsing node '%s' attributes:", node.name);
    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       
       switch(atrb.name)
       {
        case NodeAttrib.NAME:
            if(node.name == "MATERIAL") continue; // name atrribute is handled seperately
            nextcase default;
        case NodeAttrib.TRANSLUCENT:
            if(atrb.value == "1") {
                mat.coverage = MatMC.TRANSLUCENT;
            } else {
                mat.coverage = MatMC.OPAQUE;
            }
        case NodeAttrib.PATH:
        case NodeAttrib.KIND:
           io::printfn("  %s = %s,", atrb.name, atrb.value);
        default:
           io::printfn("Unnused attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, mat.name, mat.mtrfile.path);
       }
    }
    //io::printfn("END parsing node '%s' attributes:", node.name);
}

<*
    @param [in] node : "node we are looking at"
    @param [inout] map : "the texture map we are registing data into"
    @require node != null && map != null && node.asAttributes() == true
*>
fn void register_material_map_args(MatMap* map, XmlNode* node)
{
    foreach (arg : node.attributes)
    {
       if(arg == null) continue;
       // else
       map.args.push(mem::new(StringTuple, {arg.name.copy(mem), arg.value.copy(mem)}));
    }
}

<*
    @param [inout] map : "the texture map we are getting parsed data from"
    @param [in] node : "current node we are parsing"
    @param [inout] mat : "the material we are saving data into"
    @require map != null && node != null && mat != null
*>
fn void handle_material_map_args(MatMap* map, XmlNode* node, HMaterial* mat)
{
    //io::printfn("START parsing map '%s' arguments:", node.name);
    foreach (arg : map.args)
    {
       if(arg == null) continue;
       
       switch(arg.first)
       {
        case MapArgs.CLAMP:
        case MapArgs.ALPHA:
            float alpha = misc::clamp01f(arg.second.to_float()!!);
             // multiply previous alpha values by our new value
            if(alpha > 0.0f && alpha < 1.0f) {
                map.color.a = (char)(math::floor(misc::@mapValueRangeToOther(map.color.a, 0, 255, 0.0f, 1.0f) * alpha)) * 255;
                // set the material coverage to match
                mat.coverage = MatMC.TRANSLUCENT;
            }
            // if (rl::isTextureValid(map.tex))
            // {
            //     // get current GPU VRAM image into RAM for easy manipulation
            //     Image image = rl::loadImageFromTexture(map.tex);
               
            //     // create a alpha mask from the new alpha channel data
            //     Image imageAlpha = rl::imageFromChannel(image, 3);
            //     // apply its data to the entire image
            //     rl::imageAlphaMask(&image, imageAlpha);
            //     //
            //     // clear older GPU VRAM image data
            //     rl::unloadTexture(map.tex);
            //     // load the new data to GPU VRAM
            //     map.tex = rl::loadTextureFromImage(image);
            // }
        case MapArgs.TILE_H:
        case MapArgs.TILE_V:
        case MapArgs.SCROLL_X:
        case MapArgs.SCROLL_Y:
        case MapArgs.TRANSLATE_X:
        case MapArgs.TRANSLATE_Y:
           io::printfn("  %s = %s,", arg.first, arg.second);
        default:
           io::printfn("Unnused map argument '%s' found in node '%s' of material '%s' in file '%s'!", arg.first, node.name, mat.name, mat.mtrfile.path);
       }
    }
    //io::printfn("END parsing map '%s' arguments:", node.name);
}

//////////////////
// #region private
//////////////////

<*
    @param [in] node : "node to compare the name"
    @require node != null
*>
fn bool isXmlNode(XmlNode* node, Node kind) @inline @local => (node.name == kind.str) ? true : false;

<*
    @param [in] node : "node to get text from"
    @require node != null
*>
fn String getNodeText(XmlNode* node) @local
{
    String result;
    usz child_count = node.children.len();
    while(child_count > 0 && node.children[child_count - 1].name == Node.TEXT.str) {
        result = result.tconcat(node.children[child_count - 1].value);
        child_count--;
    }
    
    /*if(child_count >= 1) {
        assert(isXmlNode(node.children[0], Node.TEXT));
        String result = node.children[0].value;
        if(child_count > 1) {
            for(int i = 1; i < child_count; i++) {
                result = result.tconcat(node.children[i].value);
            }
        }
        return result;
    }*/
    
    return result;
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
    @param [in] mat : "material data to print"
    @require mat != null
*>
fn void print_material_map_data(HMaterial* mat) @local
{
    if(mat)
    {
        io::printfn("   [map : 'Diffuse']");
        io::printfn("       tex: \"id: %s, w: %s, h: %s, mp: %s, pf: %s\"", mat.diffuse.tex.id, mat.diffuse.tex.width, mat.diffuse.tex.height, mat.diffuse.tex.mipmaps, mat.diffuse.tex.format);
        io::printfn("       color: \"%s, %s , %s, %s\"", mat.diffuse.color.r, mat.diffuse.color.g, mat.diffuse.color.b, mat.diffuse.color.a);
        foreach(i, arg : mat.diffuse.args) {
            io::printfn("       arg%d: \"%s = %s\"", i, arg.first, arg.second);
        }
    }
}

// #endregion private

//////////////////////////
// Material Manager
//////////////////////////

module game::material::manager::mtrmng @private;

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

alias MTR_FileList = List{MTRFile*};

struct MaterialDataBase @public
{
    MTR_FileList data;
}


fn HMaterial* MaterialDataBase.getMaterial(&self, String material_name) @local
{
    return getMaterial(material_name);
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
fn void? load_mtr_files(String search_path, MaterialDataBase* database) @local
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
                lgr::warning(Where.FILE, " unexpected file type '%s' found inside material folder.", file_name);
				continue; // to next file
			}
			
            //****
			// from here should be a mtr file
            //****

            if(file::get_size(asset_path)! < 10) // TODO(HM) make this a constant
            {
                lgr::warning(Where.FILE, " mtr file [%s] is too small to be valid, skipping it.", asset_path);
                continue; // to next file
            }
            
            // we have a valid size file, so now try to open it

            File? file = fs::openFile(asset_path, "r");
            defer file.close()!!;
            
            if(catch excuse = file) 
            {
               lgr::warning(Where.FILE, " Failed to open mtr file [%s] with excuse: %s", asset_path, excuse);
               // DOC(HM) I need to always return from a catch or the excuse will not unwrap,
               // causing variable shadow error, preventing me from using excuse again bellow.
               continue; // to next file
            }

            // we could open it, so now try to load and save it's data
            MTRFile* mtr_file = mem::new(MTRFile);
            mtr_file.path = asset_path;
            
            if(catch excuse = mtr_file.load(file))
            {
                lgr::warning(Where.FILE, " Failed to load [%s]", asset_path);
                mem::free(mtr_file);
                continue; // to next file
            }
			
            // every thing was fine, so save the mtr file, in material files database
            database.register(mtr_file);
		}
        
		//continue to next file
	}
}

<*
    @param [inout] db : "material file data base"
    @require main::gpGame.app_base_folder.len > 0
*>
fn void? loadMaterialFilesTo(MaterialDataBase* db) @inline @public
{
    String material_folder = main::gpGame.app_base_folder.tconcat("materials").tconcat("\\");
	load_mtr_files(material_folder, db)!!;

    // see if we have a default material file, if not create one
    if(db.getMaterial("default_material") == null)
    {
        // TODO(HM) Makes this use the default material definition
        // from the HMaterial.defaultDefinition() function
        lgr::error(Where.FILE, "Default material not found in mtr database, creating one...");
        HMaterial* default_material = mem::new(HMaterial);
        default_material.init();
        default_material.name = "default_material";
        default_material.diffuse.tex = main::gpGame.default_texture;
        default_material.diffuse.color = rl::WHITE;
        db.data[0].register(default_material);
    }
}

<*
    Performance: This will probably be very slow with many materials...

    @param [in] material_name : "name of the material to search for"
    @require material_name.len > 0
    @require main::gpGame.mtrDB.data.len() > 0
*>
fn HMaterial* getMaterial(String material_name) @public
{
    HMaterial* mat;
    usz index, count;

    count = main::gpGame.mtrDB.data.len();
    if(count == 0) {
        lgr::error(Where.FILE, "No material files loaded in the game, cannot get material '%s'", material_name);
        return null;
    }

    do {
        // NOTE(HM): This is done this way because getMaterial() from MTRFile returns null 
        // if the material is not found in the mtr data, so while we have materials in the data base
        // we need to keep looking through all of them.
        mat = main::gpGame.mtrDB.data[index++].findMaterial(material_name);
    } while(mat == null && index < count);

    // just for testing purposes
    if(mat != null) {
	    assert(rl::isTextureValid(mat.diffuse.tex));
    }
    
	return mat;
}

<*
* @param [inout] mtr : "the mtr file to register"
* @require mtr != null
*>
fn void MaterialDataBase.register(&self, MTRFile* mtr) @local @inline {
	self.data.push(mtr);
}

fn void MaterialDataBase.listMTRs(&self) @public @if($feature(_DEBUG)) 
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
// To be used only at game exit, 
// for now ALL mtr files, are loaded at game start and stay in RAM, 
// during the entire game run. They only get freed at game end.
// This is done this way, because I don't have many mtr files in this game, for now,
// if that ever changes someday, I will have to refactor all of this.
// For now getting them hot from RAM, is faster then reading the data from the HD/SSD/MD2 drive.
fn void MaterialDataBase.clear(&self) @inline @public
{
	if(self.data.len()) 
    {
		foreach(mtr: self.data) mtr.unload();
		self.data.free();
	}
}
