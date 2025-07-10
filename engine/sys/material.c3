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
module game::material::mat @private;

// region imports
import game::main; // for file logging or console logging
import engine::misc;
import std::io, std::math;
import game::material::mtr;
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

alias StageArgument = StringTuple; // alias for a stage argument, which is a tuple of two strings (name, value)
alias MaterialStageArgList = List{StageArgument*};

faultdef MAT_INVALID_PATH,
         MAT_UNKNOWN_MATERIAL,
	     MAT_UNKNOWN_FOLDER,
         MAT_LOAD_ERROR,
         MAT_PARSING_ERROR,
	     MAT_SMALL_PATH_ERROR;


/*
Model model = LoadModel("resources/models/obj/castle.obj");                 // Load model
Texture2D texture = LoadTexture("resources/models/obj/castle_diffuse.png"); // Load model texture
model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;            // Set map diffuse texture

// Material loading/unloading functions
Material *LoadMaterials(const char *fileName, int *materialCount);                    // Load materials from model file
Material LoadMaterialDefault(void);                                                   // Load default material (Supports: DIFFUSE, SPECULAR, NORMAL maps)
bool IsMaterialValid(Material material);                                              // Check if a material is valid (shader assigned, map textures loaded in GPU)
void UnloadMaterial(Material material);                                               // Unload material from GPU memory (VRAM)
void SetMaterialTexture(Material *material, int mapType, Texture2D texture);          // Set texture for a material map type (MATERIAL_MAP_DIFFUSE, MATERIAL_MAP_SPECULAR...)
void SetModelMeshMaterial(Model *model, int meshId, int materialId);                  // Set material for a mesh
*/

// Material stage index
alias MatStageIndex                 = int;
const MatStageIndex STAGE_DIFFUSE   @public = 0;    // only one supported (for now...)
const MatStageIndex STAGE_SPECULAR  @public = 1;
const MatStageIndex STAGE_NORMAL    @public = 2;
const MatStageIndex STAGE_OCCLUSION @public = 3;    // Ambient occlusion material
const MatStageIndex STAGE_EMISSION  @public = 4;    // Emission material
const MatStageIndex STAGE_HEIGHT    @public = 5;    // Heightmap material
const MatStageIndex STAGE_CUBEMAP   @public = 6;    // Cubemap material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
const MatStageIndex STAGE_VIDEO     @public = 7;    // video map stage
const MatStageIndex STAGE_SOUND     @public = 8;    // sound map stage

// Don't forget to update this max value if adding more stages above!!!
const MAX_STAGE_INDICES = (STAGE_SOUND);
// just in case...
$assert MAX_STAGE_INDICES == STAGE_SOUND;

// NOTE(HM) raylib has the MaterialMap already that is almost equivalent, should we use that?
// Material stage represents each texture type in a material
struct MaterialStage
{
    //NOTE(HM) width and Height are encoded on the Texture2D data
    Texture2D tex;
    Color color;
    // Todo perhaps rethink this per stage args stuff....
    MaterialStageArgList args;
}

<*
    @param [&in] node : "node we are looking at"
*>
fn void MaterialStage.register_args(&self, XmlNode* node)
{
    if(node.hasAttributes() == false) return;

    foreach (arg : node.attributes)
    {
       if(arg == null) continue;
       // else
       self.args.push(mem::new(StageArgument, {arg.name.tcopy(), arg.value.tcopy()}));
    }
}

<*
    @param [&in] node : "current node we are parsing"
    @param [inout] mat : "the material we belong to"
    @require mat != null
*>
fn void MaterialStage.handle_args(&self, XmlNode* node, HMaterial* mat)
{
    //io::printfn("START parsing stage '%s' arguments:", node.name);
    MaterialStage* stage = self;

    foreach (arg : stage.args)
    {
       if(arg == null) continue;
       
       switch(arg.first)
       {
        case NodeAttrib.CLAMP:
        case NodeAttrib.ALPHA:
            float alpha = misc::clamp01f(arg.second.to_float()!!);
             // multiply previous alpha values by our new value
            if(alpha > 0.0f && alpha < 1.0f) {
                stage.color.a = (char)(math::floor(misc::@mapValueRangeToOther(stage.color.a, 0, 255, 0.0f, 1.0f) * alpha)) * 255;
                // set the material coverage to match
                mat.coverage = MatMC.TRANSLUCENT;
            }
            // if (rl::isTextureValid(self.tex))
            // {
            //     // get current GPU VRAM image into RAM for easy manipulation
            //     Image image = rl::loadImageFromTexture(self.tex);
               
            //     // create a alpha mask from the new alpha channel data
            //     Image imageAlpha = rl::imageFromChannel(image, 3);
            //     // apply its data to the entire image
            //     rl::imageAlphaMask(&image, imageAlpha);
            //     //
            //     // clear older GPU VRAM image data
            //     rl::unloadTexture(self.tex);
            //     // load the new data to GPU VRAM
            //     self.tex = rl::loadTextureFromImage(image);
            // }
        case NodeAttrib.TILE_H:
        case NodeAttrib.TILE_V:
        case NodeAttrib.SCROLL_X:
        case NodeAttrib.SCROLL_Y:
        case NodeAttrib.TRANSLATE_X:
        case NodeAttrib.TRANSLATE_Y:
           io::printfn("  %s = %s,", arg.first, arg.second);
        default:
           io::printfn("Unnused stage argument '%s' found in node '%s' of material '%s' in file '%s'!", arg.first, node.name, mat.name, mat.mtrfile.path);
       }
    }
    //io::printfn("END parsing stage '%s' arguments:", node.name);
}

fn void MaterialStage.loadTexture(&self, String path) @inline
{
    self.tex = misc::loadTexture(path);
}

fn void MaterialStage.clear(&self)
{
    rl::unloadTexture(self.tex);
    foreach (arg : self.args)
    {
       if(arg != null) mem::free(arg);
    }
}

// todo
struct MaterialVideoStage
{
    inline MaterialStage super;
}

enum MatMC @public //Material Coverage
{
	BAD,
	OPAQUE,			// completely fills the triangle
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
$assert Contents.sizeof <= 32;

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
    
    MatMC coverage;
    Contents contentes;
    Flags flags;

    Shader shader; // shader used by this material, if any
    
    MaterialStage[MAX_STAGE_INDICES] maps;

    //////////////////////// for the future...
    //MaterialStage normal;
    //MaterialStage spec;
    //Texture2D* bump;
    //Texture2D* rough;
    //Texture2D* metal;
    //Texture2D* ao;
    //Texture2D* cube;
    //shdshd::Sound* sound;
    ///////////////////////
    
    // NOTE(HM) Perhaps this should be a string with the mtr path in it, not a pointer to some data in memory,
    // that could be freed anytime?
    MTRFile* mtrfile;  // pointer to mtr data in memory where this material is defined
}

fn void HMaterial.save(&self, SaveFile* file) @dynamic @public {
    @todo();
}

fn void HMaterial.reload(&self, SaveFile* file) @dynamic @public {
    @todo();
}

fn void HMaterial.init(&self) @public
{
	self.coverage = MatMC.OPAQUE;
    // TODO(HM) solve this stuff with c3 enums not being able to be used as flags
    // use constants instead of enums for this?
    //self.contentes |= (Contents.SOLID.flag & Contents.OPAQUE.flag);
    self.comment  = "<no comment>";
    self.getStage(mat::STAGE_DIFFUSE).color = rl::WHITE;

    // NOTE(HM) all materials start with the default game shader
    self.shader = main::getDefaultShaderCopy();
}

fn void HMaterial.free(&self) @public
{
	foreach(stage : self.maps) stage.clear();
    if(self.mtrfile) self.mtrfile = null;

    // NOTE(HM) this will free the shader if it is not the default shader
    if(self.shader.isValid()) 
    {
        Shader* default_shader = main::getDefaultShader();
        if(self.shader.id != default_shader.id && 
           self.shader.locs != default_shader.locs) { 
            rl::unloadShader(self.shader);
        }
    }
}

fn void HMaterial.setShader(&self, Shader shader) @inline @public
{
    self.shader = shader;
}

// @untested
fn void HMaterial.copy(&self, HMaterial* other)
{
	self.getStage(mat::STAGE_DIFFUSE).tex = *other.getTexture(mat::STAGE_DIFFUSE);
    self.getStage(mat::STAGE_DIFFUSE).args.add_all(&other.getStage(mat::STAGE_DIFFUSE).args);
}

<*
 @param index : "stage index to get the necessary texture data." 
 @require index >= 0 && index < MAX_STAGE_INDICES
*>
fn MaterialStage* HMaterial.getStage(&self, MatStageIndex index) @inline @public
{
    return &self.maps[index];
}

fn Texture2D* HMaterial.getTexture(&self, MatStageIndex index, bool isPBR = false) @public
{
    switch(index)
    {
        case STAGE_NORMAL:
        case STAGE_SPECULAR:
        case STAGE_HEIGHT:
        case STAGE_EMISSION:
        case STAGE_OCCLUSION:
        case STAGE_CUBEMAP:
        case STAGE_VIDEO:
        case STAGE_SOUND: 
            @todo();
        case STAGE_DIFFUSE:
        default:
            return &self.getStage(STAGE_DIFFUSE).tex;
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

<*
    @param [&in] node : "current node we are parsing"
*>
fn void HMaterial.parse_node_atributes(&self, XmlNode* node) @public
{
    if(node.hasAttributes() == false) return;

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
                self.coverage = MatMC.TRANSLUCENT;
            } else {
                self.coverage = MatMC.OPAQUE;
            }
        case NodeAttrib.PATH:
        case NodeAttrib.KIND:
           io::printfn("  %s = %s,", atrb.name, atrb.value);
        default:
           io::printfn("Unnused attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, self.name, self.mtrfile.path);
       }
    }
    //io::printfn("END parsing node '%s' attributes:", node.name);
}

<*
    @param [&in] maps_node : "node we are currently parsing"
*>
fn void HMaterial.parse_maps(&self, XmlNode* maps_node) @public
{
    foreach(node: maps_node.children)
    {
        if(mtr::isXmlNode(node, Node.TEXT)) continue;
        
        switch(node.name)
        {
            case Node.ALBEDO:
                foreach(child: node.children)
                {
                    if(child == null) continue;

                    switch 
                    {
                        case mtr::isXmlNode(child, Node.MAP):
                            // create the full path by concatenating the relative material path to the game base folder
                            String texture_path = main::gpGame.app_base_folder.tconcat(child.getText());
                            if(texture_path.extractFileBaseByCopy() == "default.png") {
                                self.getStage(STAGE_DIFFUSE).tex = main::gpGame.default_texture;
                            } else {
                                self.getStage(STAGE_DIFFUSE).loadTexture(texture_path);
                                $if $feature(_DEBUG):
                                    lgr::info(Where.FILE, "Loaded texture '%s' for material '%s' in file '%s'", texture_path, self.name, self.mtrfile.path);
                                $endif
                            }
                        case mtr::isXmlNode(child, Node.COLOR):
                            self.getStage(STAGE_DIFFUSE).color = mtr::xmlStrColorToColor(child.getText());
                        case mtr::isXmlNode(child, Node.ARGS):
                            if(child.hasAttributes()) 
                            {
                                self.getStage(STAGE_DIFFUSE).register_args(child);
                                self.getStage(STAGE_DIFFUSE).handle_args(child, self);
                            }
                        default:
                            unreachable("Invalid node: %s child for material node %s.", child.name, node.name);
                    }
                }
            case Node.VIDEO_MAP: break;
                /*if(node.hasAttributes())
                {
                   parse_node_atributes(node, self, file);
                }*/
            case Node.NORMAL: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(Node.MAP))
                    // {
                        // self.normal.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(Node.ARGS) || child.hasAttributes()) {
                        // get_material_map_atributes_data(&self.normal, child);
                        // parse_material_map_args(&self.normal, child, self, mtr_data);
                    // }
                // }
            case Node.SPECULAR: break;
                // foreach(child: node.children)
                // {
                    // if(child == null) continue;
                    // if(child.isNode(Node.MAP))
                    // {
                        // self.spec.tex = astmng::assetManager.getTexture(child.value);
                    // }
                    // if(child.isNode(Node.ARGS) || child.hasAttributes()) {
                        // get_material_map_atributes_data(&self.spec, child);
                        // parse_material_map_args(&self.spec, child, self, mtr_data);
                    // }
                // }
            default:
               unreachable("invalid material maps node found!!");
        }
    }
}

<*
    @param [&in] node : "node to get data from"
*>
fn void HMaterial.parse_comment(&self, XmlNode* node) @inline @public
{
    String str  = node.getText();
    if(str != "") self.comment = str.tcopy();
}

<*
    @param [&in] node : "node to get data from"
*>
fn void HMaterial.parse_sound(&self, XmlNode* node) @inline @public
{
   self.parse_node_atributes(node);
            
   // TODO make sound shaders
   //self.sound = astmng::assetManager.getSound(sound_shader_name);
}

<*
    @param [&in] node : "node to get data from"
*>
fn void HMaterial.parse_shader(&self, XmlNode* node) @inline @public
{
    if(node.hasAttributes() == false) return;

    String shader_path = (String)node.getAttribute(NodeAttrib.PATH).value;
    if(shader_path == "") {
        lgr::warning(Where.FILE, "Material '%s' in file '%s' has a shader node but no path for it defined!", self.name, self.mtrfile.path);
        return;
    }

    // // load the shader from the path
    // char[] to_trim;
    // uint count = (uint)shader_path.count("/");
    // if(count > 1) 
    // {
    //    usz? index;
    //    while(count) 
    //    {
    //        index = shader_path.index_of_char_from('/', index);
    //        if(catch excuse = index) {
    //             lgr::error(Where.FILE, "Failed to find shader path '%s' for material '%s' in file '%s'! with excuse: %s", shader_path, self.name, self.mtrfile.path, excuse);
    //             return;
    //        }
    //        to_trim = shader_path[:index + 1];
    //        count--;
    //    }
    // } 
    // else
    // {
    //     to_trim = shader_path[:shader_path.index_of_char('/') + 1]!!;
    // }

    // NOTE(HM) I'm appending the extension here just as a placeholder, to make it easy to get the shader name.
    String shader_name = fs::getFileNameWithoutExt(shader_path.tconcat(".fs"));
    Shader shader = *astmng::assetManager.getShader(shader_name);
    if(!shader.isValid()) {
        lgr::error(Where.FILE, "Failed to load shader '%s' for material '%s' in file '%s'!", shader_path, self.name, self.mtrfile.path);
        return;
    }


    if(node.children.len() > 0)
    {
        // parse the shader arguments
        foreach(child: node.children)
        {
            switch
            {
                /*
                <vertex_attribute loc="0" value="-1" />
                <vertex_attribute loc="1" value="-1" />
                <vertex_attribute loc="2" value="-1" />
                <vertex_attribute loc="3" value="-1" />
                <uniform id="somename" value="-1" />
                <texture2D map="" />
                <texture3D map="" />
                */
                case child.name == Node.VERTEX_ATTRIBUTE.str:
                    if(child.hasAttributes())
                    {
                        foreach (atrb : child.attributes)
                        {
                            int loc = -1;
                            switch(atrb.name)
                            {
                                case NodeAttrib.LOCATION: // only for shaders
                                    loc = atrb.value.to_int()!!;
                                    if(loc < 0 || loc >= MAX_STAGE_INDICES) {
                                        lgr::error(Where.FILE, "Invalid value '%d' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                                loc, atrb.name, node.name, self.name, self.mtrfile.path);
                                        continue;
                                    }
                                case NodeAttrib.VALUE:
                                    if(atrb.value == "-1") continue; // -1 means no value, skip this attribute
                                    // else
                                    ShdLocInd loc_ind = ShdLocInd.from_ordinal(loc);
                                    bool is_vector2, is_vector3, is_color, is_matrix;
                                    switch(loc_ind)
                                    {
                                        case VERTEX_POSITION:
                                            is_vector3 = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_POSITION.str);
                                        case VERTEX_TEXCOORD01:
                                            is_vector2 = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_TEXCOORD01.str);
                                        case VERTEX_TEXCOORD02:
                                            is_vector2 = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_TEXCOORD02.str);
                                        case VERTEX_NORMAL:
                                            is_vector3 = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_NORMAL.str);
                                        case VERTEX_TANGENT:
                                            is_vector3 = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_TANGENT.str);
                                        case VERTEX_COLOR:
                                            is_color = true;
                                            shader.locs[loc] = shader.getAttributeLocation(ShdLocInd.VERTEX_COLOR.str);
                                        case MATRIX_MVP:
                                        case MATRIX_VIEW:
                                        case MATRIX_PROJECTION:
                                        case MATRIX_MODEL:      
                                        case MATRIX_NORMAL:     
                                        case VECTOR_VIEW:       
                                        case COLOR_DIFFUSE:     
                                        case COLOR_SPECULAR:    
                                        case COLOR_AMBIENT:     
                                        case MAP_ALBEDO:        
                                        case MAP_METALNESS:     
                                        case MAP_NORMAL:        
                                        case MAP_ROUGHNESS:     
                                        case MAP_OCCLUSION:     
                                        case MAP_EMISSION:      
                                        case MAP_HEIGHT:        
                                        case MAP_CUBEMAP:       
                                        case MAP_IRRADIANCE:    
                                        case MAP_PREFILTER:     
                                        case MAP_BRDF:          
                                        case DEPTH0:            
                                        case DEPTH1:            
                                        case DEPTH2:            
                                        case DEPTH3:            
                                            @todo();
                                        default:
                                            lgr::error(Where.FILE, "Invalid stage index '%d' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                                loc, atrb.name, node.name, self.name, self.mtrfile.path);
                                    }

                                    Vector2 pos;
                                    if(is_vector2) 
                                    {
                                        pos = getVector2FromString(atrb.value);
                                        if(pos.x == 0.0f && pos.y == 0.0f) {
                                            lgr::error(Where.FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                                atrb.value, atrb.name, node.name, self.name, self.mtrfile.path);
                                            continue;
                                        }
                                        float[*] arr = {pos.x, pos.y};
                                        shader.setAttributeLocValueV(loc, arr[..]);
                                    }
                                    if(is_vector3) 
                                    {
                                        pos = getVector2FromString(atrb.value);
                                        if(pos.x == 0.0f && pos.y == 0.0f) {
                                            lgr::error(Where.FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                                atrb.value, atrb.name, node.name, self.name, self.mtrfile.path);
                                            continue;
                                        }
                                        Vec3f pos3 = {pos.x, pos.y, 0.0f}; // assuming z is 0 for 2D attributes
                                        shader.setAttributeLocValueV(loc, pos3[..]);
                                    }
                                    else if(is_color) 
                                    {
                                        Color color = getColorFromString(atrb.value);
                                        float[*] color_arr = {(float)color.r, (float)color.g, (float)color.b, (float)color.a};
                                        shader.setAttributeLocValueV(loc, color_arr[..]);
                                    }
                                    else if(is_matrix) 
                                    {
                                        @todo();
                                    }
                                default:
                                io::printfn("Unnused attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, self.name, self.mtrfile.path);
                            }
                        }
                    }
                    else 
                    {
                        lgr::warning(Where.FILE, "Vertex attribute node '%s' in material '%s' in file '%s' has no attributes!", child.name, self.name, self.mtrfile.path);
                    }
                default:
                    lgr::warning(Where.FILE, "Unnused shader node '%s' found in material '%s' in file '%s'!", child.name, self.name, self.mtrfile.path);
            }
        }
    }

    self.setShader(shader);
}

fn Vector2 getVector2FromString(String str) @inline @local
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

fn Color getColorFromString(String str) @inline @local
{
    String[] slice = str.tsplit(", ");
    if(slice.len == 0) {
        return rl::WHITE; // default color
    }

    if(slice.len == 1) {
        char value = slice[0].to_uchar()!!;
        return {value, value, value, 255}; // use the same value for r, g, b and full alpha
    } else if(slice.len == 3) {
        return {slice[0].to_uchar()!!, slice[1].to_uchar()!!, slice[2].to_uchar()!!, 255}; // full alpha
    } else if(slice.len == 4) {
        return {slice[0].to_uchar()!!, slice[1].to_uchar()!!, slice[2].to_uchar()!!, slice[3].to_uchar()!!};
    }

    return rl::WHITE; // default color
}

////////////////////////////////////////////////////////////////////////////////
//
//              MTRFile - Material file data structure
//
///////////////////////////////////////////////////////////////////////////////

module game::material::mtr @private;

// region imports
import game::material::mat;
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

const MTR_VERSION_STRING = "1.0.0"; // the version of the mtr file format
const MTR_FILE_EXT = ".mtr"; // the extension of the mtr file
const MAX_MATERIALS_PER_FILE = 100; // the maximum number of materials per mtr file
const MAX_MATERIALS_OVERALL = 1000; // the maximum number of materials in the game

alias MaterialList       = List{HMaterial*};

faultdef MTR_INVALID_PATH,
	     MTR_MALFORMED_FILE,
	     MTR_UNKNOWN_FOLDER,
	     MTR_FOLDER_SCAN_ERROR,
	     MTR_LOAD_ERROR,
         MTR_VERSION_MISMATCH,
         MTR_MATERIAL_PARSING_ERROR,
	     MTR_SMALL_PATH_ERROR,
	     MTR_RETRIVAL_ERROR,
	     MTR_MISSING;

// NOTE(HM) This represents every usefull node in the mtr xml file 
enum Node : int (inline String str) @public
{
    ROOT             = "MTR",
    TEXT             = "#text",
    MATERIAL         = "MATERIAL",
    COMMENT          = "comments",
    MAPS             = "maps",
    MAP              = "map",
    VIDEO_MAP        = "video_map",
    ARGS             = "args",
    COLOR            = "color",
    ALBEDO           = "albedo",
    NORMAL           = "normal",
    SPECULAR         = "specular",
    SOUND            = "sound",
    SHADER           = "shader",
    VERTEX_ATTRIBUTE = "vertex_attribute",
    UNIFORM          = "uniform",
    TEXTURE2D        = "texture2D",
    TEXTURE3D        = "texture3D",
}

<*
    @param [&in] node : "node to compare the name"
*>
fn bool isXmlNode(XmlNode* node, Node kind) @inline @public => (node.name == kind.str) ? true : false;


// NOTE(HM) This represents the atributes assigned to a xml node
enum NodeAttrib : int (inline String str) @public
{
    // general
    NAME        = "name",
    VERSION     = "version",
    PATH        = "path",
    KIND        = "kind",
    TRANSLUCENT = "translucent",

    // shader specific
    LOCATION    = "loc", // shader location for the attribute
    VALUE       = "value", // used for vertex attributes and uniforms

    // map arguments
    CLAMP       = "clamp",
    TILE_H      = "tileH",
    TILE_V      = "tileV",
    SCROLL_X    = "scrollX",
    SCROLL_Y    = "scrollY",
    TRANSLATE_X = "translateX",
    TRANSLATE_Y = "translateY",
    ALPHA       = "alpha"
}

// NOTE(HM) This is the data structure represents a material file, it contains a list of materials and their data
struct MTRFile @public
{
    String path;        // path to the mtr file on disk.
    String version;     // version of the mtr file format, should be MTR_VERSION_STRING.
    MaterialList mats;  // list of materials in this file.
}

fn void MTRFile.init(&self, String path) @inline @public
{
    self.path = path.copy(mem);
    self.version = MTR_VERSION_STRING;
    self.mats.reserve(MAX_MATERIALS_PER_FILE);
}

fn void MTRFile.unload(&self) @inline @public
{
	foreach(mat: self.mats) mat.free();
    self.mats.free();
}

<*
    @param [&in] mat : "material to register"
*>
fn void MTRFile.register(&self, HMaterial* mat) @inline @public
{
    if(self.mats.len() >= MAX_MATERIALS_PER_FILE) {
        lgr::error(Where.FILE, "Maximum number of materials per mtr file reached (%d), cannot register material '%s' in file '%s'.", MAX_MATERIALS_PER_FILE, mat.name, self.path);
        return;
    }
    self.mats.push(mat);
}

// @Performance This will probably be very slow with many materials...
// TODO(HM) make this faster by using a hash table
fn HMaterial* MTRFile.findMaterial(&self, String name) @public
{
	foreach(mat: self.mats) {
		if(mat.name == name) return mat;
	}
    
	return null;
}


fn void MTRFile.printMaterials(&self) @inline @public
{
    // Remove the comments if you want to print the materials in the console.
    /*
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
    */
}

fn bool? MTRFile.load(&self, File file) @inline @public
{
    XmlDoc*? doc = xml::read_file(file);
    defer doc.free()!!;
    
    if(catch excuse = doc)
    {
       lgr::warning(Where.FILE, " Failed to load/open MTR xml file [%s] with excuse: %s", self.path, excuse);
       return MTR_LOAD_ERROR?;
    }
    
    return self.parse(doc);
}

<*
    @param [&in] doc : "mtr (xml) file to parse"
*>
fn bool? MTRFile.parse(&self, XmlDoc* doc)
{
    bool invalid_mtr = doc.rootNode.name != Node.ROOT.str;
    if(invalid_mtr)
    {
       lgr::error(Where.FILE, " Malformed material data file '%s', root node expected to be 'MTR' but is '%s' instead.", self.path, doc.rootNode.name);
       return MTR_MALFORMED_FILE?;
    }

    String? version = (String)doc.rootNode.getAttribute(NodeAttrib.VERSION).value;
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
        return MTR_VERSION_MISMATCH?;
    }

    // else everything should be fine from here, so keep parsing this material data
    self.version = version.tcopy();
    
    // now parse each MTR xml node
    foreach (node : doc.rootNode.children)
    {
        $if $feature(_DEBUG):
            if(node == null) 
            {
                lgr::error(Where.FILE, "Null node found in mtr file '%s', skipping it.", self.path);
                return MTR_MATERIAL_PARSING_ERROR?;
            }
        $endif

        switch
        {
            // Skip any text nodes assigned to the root node (shouldn't happen now though).
            // Text nodes are handled further by the material parser, so we don't need to handle them here.
            case isXmlNode(node, Node.TEXT):
                lgr::error(Where.FILE, "Unexpected 'TEXT' node found in body of MTR '%s'! Text = '%s' ", fs::getFileNameWithoutExt(self.path), node.value);
                // This was caused by a bug in the xml reader code (not very easy to solve but I worked around it). 
                // The xml reader, treats any end char '>', as always being followed by a Text "node", 
                //  (free text between a '>' and a '<'), so in some situations, it created empty text nodes, 
                //  like when after a '>' char, came the start char '<' of another node, 
                //  but you add in between them, empty characters (space, new line), but even so 
                //  the xml reader, still considered those as valid "text". 
                // Because the xml reader, reads character by character, is not easy to solve this, 
                //  so it will create a text node, regardless if is empty or not.  
                // The workaround, was to test for empty text nodes and just don't register them, in the xml doc file.
                return MTR_MATERIAL_PARSING_ERROR?;
            case mtr::isXmlNode(node, Node.MATERIAL):
                HMaterial* mat = self.parse_material(node);
                if(mat) {
                    self.register(mat);
                } else {
                    lgr::error(Where.FILE, "Failed to parse material node '%s' in mtr file '%s'", node.name, self.path);
                    return MTR_MATERIAL_PARSING_ERROR?;
                }
            default:
                lgr::warning(Where.FILE, " Unexpected node in mtr file '%s', expected <MATERIAL> found <%s>", self.path, node.name);
                $if $feature(_DEBUG):
                    return MTR_MATERIAL_PARSING_ERROR?;
                $else
                    continue;
                $endif
        }
    } // end foreach node
    
    return true;
}

// @Performance This will probably be very slow with many mtr files and material definitions...
fn bool check_material_existance(String name)
{
    MaterialDataBase* mtr_db = &main::gpGame.mtrDB;
    foreach(mtr: mtr_db.data)
    {
        foreach(mat: mtr.mats) {
		    if(mat.name == name)  return true;
        }
    }
    
    return false;
}

<*
    @param [&in] in_node : "material node we are currently parsing"
*>
fn HMaterial* MTRFile.parse_material(&self, XmlNode* in_node)
{
    // create the material structure to save the parsed data into
    HMaterial* mat = mem::new(HMaterial);
    mat.init();
    
    // first get material name
    String? mat_name = (String)in_node.getAttribute(NodeAttrib.NAME).value;
    if (catch excuse = mat_name)
    {
        lgr::error(Where.FILE, "Failed to get material name attribute in %s with excuse: %s\n", self.path, excuse);
        mat.free();
        mem::free(mat);
        return null;
    }
    
    if (mat_name == "")
    {
        lgr::error(Where.FILE, "material with empty or no name in %s\n", self.path);
        mat.free();
        mem::free(mat);
        return null;
    }

    // check if the material name already exists in the game
    if(check_material_existance(mat_name) == true)
    {
        lgr::warning(Where.FILE, "material with name '%s' already exists in %s\n", mat_name, self.path);
        mat.free();
        mem::free(mat);
        return null;
    }
    
    // else everything should be fine from here, so keep parsing this material data
    mat.name = mat_name.tcopy();
    mat.mtrfile = self; // set the material file pointer to this mtr file
    
    // parse extra material attributes if any
    if(in_node.hasAttributes()) mat.parse_node_atributes(in_node);

    // start parsing the material child nodes
    foreach (node : in_node.children)
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
                // this is a text node, so we just skip it, as it should not be here
                // TODO(HM) handle this better, maybe by removing it from the xml doc?
                lgr::warning(Where.FILE, "Unexpected text node found in material '%s'! Text = '%s' ", mat.name, node.value);
                continue;
            case Node.COMMENT.str: 
                mat.parse_comment(node);
            case Node.ARGS.str: 
                if(node.hasAttributes() == true) {
                    mat.parse_node_atributes(node);
                } else {
                    lgr::warning(Where.FILE, "Malformed node '%s' found in material '%s', expected attributes.", node.name, mat.name);
                }
                continue;
            case Node.MAPS.str: 
                mat.parse_maps(node);
                continue;
            case Node.SHADER.str:
                mat.parse_shader(node);
                continue;
            case Node.SOUND.str: 
                mat.parse_sound(node);
                continue;
       }
    }
    
    return mat;
}



//////////////////
// #region private
//////////////////

fn Color xmlStrColorToColor(String _value) @public
{
    String[] chars = _value.tsplit(" ");
    assert(chars.len == 4);
    
    Color result;
    
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

<*
    @param [in] mat : "material data to print"
    @require mat != null
*>
fn void print_material_map_data(HMaterial* mat) @local
{
    if(mat)
    {
        Color color = mat.getStage(mat::STAGE_DIFFUSE).color;
        Texture2D* tex = &mat.getStage(mat::STAGE_DIFFUSE).tex;
        io::printfn("   [map : 'Diffuse']");
        io::printfn("       tex: \"id: %s, w: %s, h: %s, mp: %s, pf: %s\"", tex.id, tex.width, tex.height, tex.mipmaps, tex.format);
        io::printfn("       color: \"%s, %s , %s, %s\"", color.r, color.g, color.b, color.a);
        foreach(i, arg : mat.getStage(mat::STAGE_DIFFUSE).args) {
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
import game::material::mtr, game::material::mat;
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
        default_material.getStage(mat::STAGE_DIFFUSE).tex = main::gpGame.default_texture;
        default_material.getStage(mat::STAGE_DIFFUSE).color = rl::WHITE;
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
    uint index;

    uint count = (uint)main::gpGame.mtrDB.data.len();
    if(count == 0) {
        lgr::error(Where.FILE, "No material files loaded in the game, cannot get material '%s'", material_name);
        return null;
    }

    do { // @Performance This is a linear search, so it will be slow with many materials.
        // NOTE(HM): This is done this way because findMaterial() from MTRFile returns null 
        // if the material is not found in the mtr data, so while we have materials in the data base
        // we need to keep looking through all of them.
        mat = main::gpGame.mtrDB.data[index++].findMaterial(material_name);
    } while(mat == null && index < count);

    // just for testing purposes
    if(mat != null) {
	    assert(rl::isTextureValid(*mat.getTexture(mat::STAGE_DIFFUSE)));
    }
    
	return mat;
}

<*
 @param [inout] mtr : "the mtr file to register"
 @require mtr != null
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
