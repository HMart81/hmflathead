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
import engine::sys::framework::glsl;
import std::io, std::math;
import game::material::mtr;
import game::serialize::svs;
import game::material::manager::mtrmng;
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

alias StageArgument = StringPair; // alias for a stage argument, which is a tuple of two strings (name, value)
alias MaterialStageArgList = List{StageArgument*};

faultdef MAT_INVALID_PATH,
         MAT_UNKNOWN_MATERIAL,
	     MAT_UNKNOWN_FOLDER,
         MAT_LOAD_ERROR,
         MAT_PARSING_ERROR,
	     MAT_SMALL_PATH_ERROR;


/*
RLModel model = LoadModel("resources/models/obj/castle.obj");                 // Load model
RLTexture2D texture = LoadTexture("resources/models/obj/castle_diffuse.png"); // Load model texture
model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;            // Set map diffuse texture

// RLMaterial loading/unloading functions
RLMaterial *LoadMaterials(const char *fileName, int *materialCount);                    // Load materials from model file
RLMaterial LoadMaterialDefault(void);                                                   // Load default material (Supports: DIFFUSE, SPECULAR, NORMAL maps)
bool IsMaterialValid(RLMaterial material);                                              // Check if a material is valid (shader assigned, map textures loaded in GPU)
void UnloadMaterial(RLMaterial material);                                               // Unload material from GPU memory (VRAM)
void SetMaterialTexture(RLMaterial *material, int mapType, RLTexture2D texture);          // Set texture for a material map type (MATERIAL_MAP_DIFFUSE, MATERIAL_MAP_SPECULAR...)
void SetModelMeshMaterial(RLModel *model, int meshId, int materialId);                  // Set material for a mesh
*/

const NEW_MATERAL_SYSTEM = true; // enable the new material system, still WIP

const int TEXTURE_NONE      @public = 0;
const int TEXTURE_DIFFUSE   @public = 1;
const int TEXTURE_SPECULAR  @public = 2;
const int TEXTURE_NORMAL    @public = 3;
const int TEXTURE_OCCLUSION @public = 4;
const int TEXTURE_EMISSION  @public = 5;
const int TEXTURE_HEIGHT    @public = 6;
const int TEXTURE_CUBEMAP   @public = 7;

// TODO(HM) Support more than one stage type per material, 
// for example more than one diffuse map, etc.
// RLMaterial stage index
alias MatStageIndex = int;
const MatStageIndex STAGE_DIFFUSE   @public = TEXTURE_DIFFUSE;    // only one supported (for now...)
const MatStageIndex STAGE_SPECULAR  @public = TEXTURE_SPECULAR;
const MatStageIndex STAGE_NORMAL    @public = TEXTURE_NORMAL;
const MatStageIndex STAGE_OCCLUSION @public = TEXTURE_OCCLUSION;    // Ambient occlusion material
const MatStageIndex STAGE_EMISSION  @public = TEXTURE_EMISSION;    // Emission material
const MatStageIndex STAGE_HEIGHT    @public = TEXTURE_HEIGHT;    // Heightmap material
const MatStageIndex STAGE_CUBEMAP   @public = TEXTURE_CUBEMAP;    // Cubemap material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
const MatStageIndex STAGE_VIDEO     @public = 8;    // video map stage
const MatStageIndex STAGE_SOUND     @public = 9;    // sound map stage
// Don't forget to update this max value if adding more stages above!!!
const MAX_STAGE_INDICES = (STAGE_SOUND);
// just in case...
$assert MAX_STAGE_INDICES == STAGE_SOUND;

alias StageLighting = int;  // Stage lighting type
const StageLighting SL_AMBIENT  @public = 0;    // execute after lighting
const StageLighting SL_BUMP     @public = 1;    // bump mapping stage, used for normal maps
const StageLighting SL_DIFFUSE  @public = 2;    // diffuse lighting stage, used for diffuse maps
const StageLighting SL_SPECULAR @public = 3;    // specular lighting stage, used for specular maps

const int BLEND_NONE     @public = rl::RL_ZERO | rl::RL_ONE;                       // used when defining an alpha mask that doesn't draw
const int BLEND_BLEND    @public = rl::RL_SRC_ALPHA | rl::RL_ONE_MINUS_SRC_ALPHA;
const int BLEND_ADD      @public = rl::RL_ONE | rl::RL_ONE;
const int BLEND_SCREEN   @public = rl::RL_ONE_MINUS_DST_COLOR | rl::RL_ONE;
const int BLEND_DODGE    @public = rl::RL_DST_COLOR | rl::RL_ONE;                  // even softer additive
const int BLEND_MODULATE @public = rl::RL_DST_COLOR | rl::RL_ZERO;                 // used for modulate and multiply



/* 
TODO(HM) potencial new future material file and stage system in XML format:

<MTR version="1.0" generator="hmflathead mtrgen v0.1">
    <library_materials>
        <material name="images/textures/brick" path="materials/images/textures/brick.mtr" />
        <material name="images/textures/figure">
            <comments>This is a figure texture material</comments>
            <editor_image path="images/textures/figure_preview.png" />
            <-- fallback material used when this main material is unsupported -->
            <fallback_material name="images/textures/brick" />
            <-- global parameters, affect the entire material -->
            <globals 
                sort="10" 
                coverage="translucent" 
                contents="solid, terrain" 
                flags="alpha_test, no_shadows"
            />
            <library_stages>
                <stage type="diffuse" blend_mode="blend">
                    <map path="images/textures/figure.png" />
                    <-- local parameters, affect only this stage -->
                    <parms alpha="0.5" wrap_s="repeat" wrap_t="repeat" />
                </stage>
                <stage type="normal">
                    <map path="images/textures/figure_normal.png" />
                </stage>
                <stage type="specular">
                    <map path="images/textures/figure_specular.png" />
                </stage>
            </library_stages>
        </material>
    </library_materials>
</MTR>
*/
// NOTE(HM) raylib has the RLMaterialMap already that is almost equivalent, should we use that?
// RLMaterial stage represents each texture type in a material
struct MaterialStage @public
{
    //int kind; // kind of stage, used to identify the stage type, for example diffuse, specular, normal, etc.

    //NOTE(HM) width and Height are encoded on the RLTexture2D data
    RLTexture2D tex;
    RLColor color;
    int drawStateBits @if(!$defined(NEW_MATERAL_SYSTEM)); // draw state bits for this stage, used for blending and who knows other effects
    union @if($defined(NEW_MATERAL_SYSTEM))
    {
        int drawStateBits; // draw state bits for this stage, used for blending and who knows other effects
        int blendMode @NewMatSystem(1); // is the same as drawStateBits
    }
    int lighting; // lighting type for this stage, used for lighting calculations
    
    // Todo perhaps rethink this per stage args stuff....
    MaterialStageArgList args;

    MatStageIndex type @NewMatSystem(1); // is also a index
    StageArgument[MAX_STAGE_ARGS] new_args @NewMatSystem(1); // array of arguments for this stage
}

<*
    @param [&in] node : "node we are looking at"
*>
fn void MaterialStage.register_args(&self, XmlNode* node) @deprecated
{
    if(node.hasAttributes() == false) return;

    foreach (arg : node.attributes)
    {
       if(arg == null) continue;
       // else
       self.args.push(mem::new(StageArgument, {arg.name.tcopy(), arg.value.tcopy()}));
    }
}

fn void MaterialStage.loadTexture(&self, String path) @inline
{
    self.tex = r2d::loadTexture(path);
}

fn void MaterialStage.clear(&self)
{
    if(rl::isTextureValid(self.tex)) {
        rl::unloadTexture(self.tex);
    }
    
    if(self.args.len() > 0)
    {
        // NOTE(HM) free all the arguments in the list
        foreach (arg : self.args)
        {
            if(arg != null) mem::free(arg);
        }
        self.args.clear();
    }
}

// todo
struct MaterialVideoStage
{
    inline MaterialStage super;
}

alias Coverage @public = int; //RLMaterial Coverage
const Coverage COVERAGE_BAD         @public = -1; // invalid coverage type
const Coverage COVERAGE_OPAQUE      @public =  0; // completely fills the triangle
const Coverage COVERAGE_PERFORATED  @public =  1; // may have alpha tested holes
const Coverage COVERAGE_TRANSLUCENT	@public =  2; // blended with background
//
//
// TODO(HM) implement this new stage system
attrdef @NewMatSystem(value) = @tag("version", value), @if($defined(NEW_MATERAL_SYSTEM));

const int MAX_STAGE_ARGS @if($defined(NEW_MATERAL_SYSTEM)) = 16; // max number of arguments per stage
struct NewStage @if($defined(NEW_MATERAL_SYSTEM)) @public
{
    RLTexture2D tex; // GPU texture id
    MatStageIndex type; // is also a index
    int blendMode;
    StageLighting lighting;
    RLColor color;
    StageArgument[MAX_STAGE_ARGS] args; // array of arguments for this stage
}

fn void NewStage.init(&self, MatStageIndex _type = STAGE_DIFFUSE, int _lighting = SL_DIFFUSE) @public @if($defined(NEW_MATERAL_SYSTEM))
{
    //self.tex = rl::INVALID_TEXTURE;
    self.type = _type; // invalid type
    //self.blendMode = BLEND_NONE;
    self.lighting = _lighting;
    self.color = rl::WHITE;
    //self.args.clear();
}

fn void NewStage.free(&self) @public @if($defined(NEW_MATERAL_SYSTEM))
{
    if(rl::isTextureValid(self.tex) || self.tex != rl::INVALID_TEXTURE) {
        rl::unloadTexture(self.tex);
    }
    foreach(arg : self.args) {
        arg.first = "";
        arg.second = "";
    }
}
///////////////////////////////////////////
//
//



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
    
    uint sort; // sort value for this material, used to sort materials by their sort value, lower values are rendered first
    Coverage coverage;
    int contentes;
    Flags flags;

    RLShader shader; // shader used by this material, if any
    
    // TODO(HM) support more than one diffuse map stage, etc.
    // for more complex materials.
    MaterialStage[MAX_STAGE_INDICES] maps;
    
    // NOTE(HM) Perhaps this should be a string with the mtr path in it, 
    // not a pointer to some data in memory, that could be freed anytime...
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
	//self.coverage |= COVERAGE_OPAQUE;
    // TODO(HM) solve this stuff with c3 enums not being able to be used as flags
    // use constants instead of enums for this?
    self.contentes |= (Contents.SOLID.flag | Contents.OPAQUE.flag);
    self.comment  = "<no comment>";

    // diffuse stage is the only one supported for now
    self.getStage(STAGE_DIFFUSE).color = rl::WHITE;
    self.getStage(STAGE_DIFFUSE).drawStateBits |= BLEND_NONE; // default blend mode
    self.getStage(STAGE_DIFFUSE).lighting = SL_DIFFUSE; // default lighting stage
    //
    self.getStage(STAGE_OCCLUSION).color = rl::WHITE;
    self.getStage(STAGE_OCCLUSION).drawStateBits |= BLEND_MODULATE;
    self.getStage(STAGE_OCCLUSION).lighting = SL_DIFFUSE; // default lighting stage
    //
    self.getStage(STAGE_SPECULAR).color = rl::BLACK; // default specular color
    self.getStage(STAGE_SPECULAR).drawStateBits |= BLEND_NONE; // default blend mode
    self.getStage(STAGE_SPECULAR).lighting = SL_SPECULAR; // default lighting stage
    //
    self.getStage(STAGE_NORMAL).color = rl::WHITE;
    self.getStage(STAGE_NORMAL).drawStateBits |= BLEND_NONE; // default blend mode
    self.getStage(STAGE_NORMAL).lighting = SL_BUMP; // default lighting stage
    //
    self.getStage(STAGE_EMISSION).color = rl::WHITE;
    self.getStage(STAGE_EMISSION).drawStateBits |= BLEND_ADD; // default blend mode
    self.getStage(STAGE_EMISSION).lighting = SL_AMBIENT;

    // NOTE(HM) all materials start with the default game shader
    //self.shader = game::getDefaultShaderCopy();
}

fn void HMaterial.free(&self) @public
{
	foreach(stage : self.maps) stage.clear();
    if(self.mtrfile) self.mtrfile = null;

    // NOTE(HM) this will free the shader if it is not the default shader
    if(self.shader.isValid()) 
    {
        assert(self.shader.id != 0, "Invalid shader id for material '%s' in file '%s'!", self.name, self.mtrfile.path);
        if(self.shader.id != game::getDefaultShader().id) { 
            rl::unloadShader(self.shader);
        }
    }
}

// TODO(HM) make this print a more detailed material info
fn void HMaterial.print(self) @public //@local
{
    RLColor color = self.getStage(mat::STAGE_DIFFUSE).color;
    RLTexture2D* tex = &self.getStage(mat::STAGE_DIFFUSE).tex;
    io::printfn("[material : '%s']", self.name);
    if(self.comment.len && self.comment != "<no comment>") {
        io::printfn(" comment = \"%s\"", self.comment);
    }
    io::printfn(" [map : 'Diffuse']");
    io::printfn("  tex: \"id: %s, w: %s, h: %s, mp: %s, pf: %s\"", tex.id, tex.width, tex.height, tex.mipmaps, tex.format);
    io::printfn("  color: \"%s, %s , %s, %s\"", color.r, color.g, color.b, color.a);
    foreach(i, arg : self.getStage(mat::STAGE_DIFFUSE).args) {
        io::printfn("  arg%d: \"%s = %s\"", i, arg.first, arg.second);
    }
}

fn void HMaterial.setShader(&self, RLShader shader) @inline @public
{
    self.shader = shader;
}

fn void HMaterial.setCoverage(&self, Coverage cv) @public
{
    if(self.coverage & cv) return;

    switch(cv)
    {
        case COVERAGE_OPAQUE:
            self.coverage |= COVERAGE_OPAQUE;
            if(self.coverage & COVERAGE_TRANSLUCENT) {
                self.coverage &= ~COVERAGE_TRANSLUCENT;
            }
        case COVERAGE_TRANSLUCENT:
            self.coverage |= COVERAGE_TRANSLUCENT;
            if(self.coverage & COVERAGE_OPAQUE) {
                self.coverage &= ~COVERAGE_OPAQUE;
            }
        case COVERAGE_PERFORATED:
            self.coverage |= COVERAGE_PERFORATED;
            if(self.coverage & COVERAGE_OPAQUE) {
                self.coverage &= ~COVERAGE_OPAQUE;
            }
        default:
            unreachable();
    }
}

// @untested
<*
    Deep copy of a shader data
    @param [&in] other : "the other material to copy data from"
*>
fn void HMaterial.copy(&self, HMaterial* other)
{
    /*if(other == null) {
        log::error(Where.FILE, "Cannot copy material from null pointer!");
        return;
    }*/
    
    // NOTE(HM) Perhaps this should be a string with the mtr path in it, 
    // not a pointer to some data in memory, that could be freed anytime...
    //MTRFile* mtrfile;  // pointer to mtr data in memory where this material is defined
    self.name = other.name.tcopy();
    self.comment = other.comment.tcopy();
    self.coverage = other.coverage;
    self.contentes = other.contentes;
    self.flags = other.flags;
    self.shader = other.shader; // NOTE(HM) this will copy the shader id, not the shader itself, so it is safe to do this
    self.mtrfile = other.mtrfile; // NOTE(HM) this will copy the pointer, not the data itself, so it is safe to do this
    // copy the material stages
    for (int index = 0; index < MAX_STAGE_INDICES; index++)
    {
        MaterialStage* stage = self.getStage(index);
        MaterialStage* other_stage = other.getStage(index);
        stage.tex = other_stage.tex; // NOTE(HM) this will copy the texture id, not the texture itself, so it is safe to do this
        stage.color = other_stage.color;
        stage.args.clear();
        foreach (arg : other_stage.args)
        {
            if(arg != null) stage.args.push(mem::new(StageArgument, {arg.first.tcopy(), arg.second.tcopy()}));
        }
    }
	//self.getStage(mat::STAGE_DIFFUSE).tex = *other.getTexture(mat::TEXTURE_DIFFUSE);
    //self.getStage(mat::STAGE_DIFFUSE).args.add_all(&other.getStage(mat::STAGE_DIFFUSE).args);
}

<*
 @param index : "stage index to get the necessary texture data." 
 @require index >= 0 && index < MAX_STAGE_INDICES
*>
fn MaterialStage* HMaterial.getStage(&self, MatStageIndex index) @inline @public
{
    return &self.maps[index];
}

<*
    Gets the texture for the given stage index
    @param index : "stage index to get the necessary texture data." 
    @require index >= 0 && index < MAX_STAGE_INDICES
    @param isPBR : "if true, will get the PBR texture, otherwise will get the standard texture"
*>
fn RLTexture2D* HMaterial.getTexture(&self, MatStageIndex index, bool isPBR = false) @public
{
    switch(index)
    {
        case TEXTURE_SPECULAR:  return &self.getStage(STAGE_SPECULAR).tex;
        case TEXTURE_NORMAL:    return &self.getStage(STAGE_NORMAL).tex;
        case TEXTURE_OCCLUSION: return &self.getStage(STAGE_OCCLUSION).tex;
        case TEXTURE_EMISSION:  return &self.getStage(STAGE_EMISSION).tex;
        case TEXTURE_HEIGHT:    return &self.getStage(STAGE_HEIGHT).tex;
        case TEXTURE_CUBEMAP:   return &self.getStage(STAGE_CUBEMAP).tex;
        //case STAGE_VIDEO:     //return &self.getStage(STAGE_VIDEO).tex;
        //case STAGE_SOUND:     //return &self.getStage(STAGE_SOUND).tex;
           //@todo();
        case TEXTURE_NONE:
            unreachable("Material '%s' in file '%s' has no texture for stage index %d!", self.name, self.mtrfile.path, index);
        case TEXTURE_DIFFUSE:
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

    foreach (atrb : node.attributes)
    {
       if(atrb == null) continue;
       
       switch(atrb.name)
       {
        case NodeAttrib.NAME:
            if(node.name == "MATERIAL") break; // MATERIAL name atrribute is handled seperately
        case NodeAttrib.PATH:
        case NodeAttrib.KIND:
            log::info(CONSOLE, "  %s = %s,", atrb.name, atrb.value);
        default:
            log::warning(CONSOLE, "Unnused attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, node.name, self.name, self.mtrfile.path);
       }
    }
}

<*
    @param [&in] stage_node : "xml node we are currently parsing"
*>
fn void HMaterial.parse_stage(&self, XmlNode* stage_node) @public
{
@off() 
{
    String stage_type = stage_node.getAttribute(NodeAttrib.TYPE).value;
    if(stage_type.is_empty()) {
        log::error(Where.FILE, "RLMaterial '%s' in file '%s' has a stage node without a type attribute!", self.name, self.mtrfile.path);
        return;
    }
    // NOTE(HM) we only support diffuse stage for now, so we will just ignore the rest
    if(stage_type != Node.STAGE_DIFFUSE.str) {
        log::warning(Where.FILE, "RLMaterial '%s' in file '%s' has a stage node of type '%s', which is not supported yet! Skipping it.", self.name, self.mtrfile.path, stage_type);
        return;
    }

    MaterialStage* stage;
    defer self.registerStage(stage);
    stage.color = rl::WHITE; // default color for the stage

    switch(stage_type)
    {
        case Node.STAGE_DIFFUSE.str:
            stage.kind = Node.STAGE_DIFFUSE;
            stage.drawStateBits |= BLEND_NONE; // default blend mode
            stage.lighting = SL_DIFFUSE; // default lighting stage
        case Node.STAGE_OCCLUSION.str:
            stage.kind = Node.STAGE_OCCLUSION;
            stage.drawStateBits |= BLEND_MODULATE; // default blend mode
            stage.lighting = SL_DIFFUSE; // default lighting stage
        case Node.STAGE_SPECULAR.str:
            stage.kind = Node.STAGE_SPECULAR;
            stage.drawStateBits |= BLEND_NONE; // default blend mode
            stage.lighting = SL_SPECULAR; // default lighting stage
        case Node.STAGE_NORMAL.str:
            stage.kind = Node.STAGE_NORMAL;
            stage.drawStateBits |= BLEND_NONE; // default blend mode
            stage.lighting = SL_BUMP; // default lighting stage
        case Node.STAGE_EMISSION.str:
            stage.kind = Node.STAGE_EMISSION;
            stage.drawStateBits |= BLEND_ADD; // default blend mode
            stage.lighting = SL_AMBIENT; // default lighting stage
        case Node.STAGE_HEIGHT.str:
            stage.kind = Node.STAGE_HEIGHT;
        case Node.STAGE_CUBEMAP.str:
            stage.kind = Node.STAGE_CUBEMAP;
        case Node.STAGE_VIDEO.str:
            stage.kind = Node.STAGE_VIDEO;
        case Node.STAGE_SOUND.str:
            stage.kind = Node.STAGE_SOUND;
            // TODO(HM) implement sound stage
            self.parse_sound(stage_node);
            return; // we are done here, no need to parse the rest of the stage node
        default:
            log::error(Where.FILE, "Invalid stage node '%s' found in material '%s' in file '%s'!", stage_node.name, self.name, self.mtrfile.path);
    }

    foreach(child: stage_node.children)
    {
        if(child == null) continue;

        switch 
        {
            case mtr::isXmlNode(child, Node.BLEND):
                self.parse_blend(child, stage);
            case mtr::isXmlNode(child, Node.MAP):
                // create the full path by concatenating the relative material path to the game base folder
                String texture_path = game::gpGame.app_base_folder.tconcat(child.getAttribute(NodeAttrib.URL).value);
                if(texture_path.is_empty()) {
                    unreachable("RLMaterial '%s' in file '%s' has a stage node with a map node without a url attribute!", self.name, self.mtrfile.path);
                }
                // check if the texture path is valid, if not, use the default texture
                if(texture_path.ends_with("/") || texture_path.ends_with("\\")) {
                    unreachable("RLMaterial '%s' in file '%s' has a stage node with a map node with an invalid url attribute '%s'!", self.name, self.mtrfile.path, texture_path);
                }
                // now check the texture type by priority file extension
                texture_path = texture_path.tconcat(".dds");
                if(fs::fileExists(texture_path) == false) 
                {
                    // try to load the texture as a png file
                    texture_path = texture_path.treplace(".dds", ".png");
                    if(fs::fileExists(texture_path) == false) 
                    {
                        // try to load the texture as a tga file
                        texture_path = texture_path.treplace(".png", ".tga");
                        if(fs::fileExists(texture_path) == false) 
                        {
                            // try to load the texture as a .jpg file
                            texture_path.treplace(".tga", ".jpg");
                            if(fs::fileExists(texture_path) == false) 
                            {
                               unreachable("Failed to find a supported file extension for texture '%s'!", texture_path.removeExtension());
                            }
                        }
                    }
                }

                stage.loadTexture(texture_path);
                $if $feature(_DEBUG):
                    log::info(Where.FILE, "Loaded '%s' texture '%s' for material '%s' in file '%s'", stage.kind.str, texture_path, self.name, self.mtrfile.path);
                $endif
            case mtr::isXmlNode(child, Node.KEYWORD):
                self.parse_keyword(child, stage);
            default:
                unreachable("Invalid node: %s child for material node %s.", child.name, node.name);
        }
    }
}; // off   
}


<*
    Todo(HM): deprecate this in the future, use parse_stage instead. 
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
                            // path is relative to the game base folder
                            String relative_texture_path = child.getText();
                            if(relative_texture_path.extractFileBaseByCopy() == "default.png") {
                                self.getStage(STAGE_DIFFUSE).tex = game::gpGame.default_texture;
                            } else {
                                self.getStage(STAGE_DIFFUSE).loadTexture(relative_texture_path);
                                $if $feature(_DEBUG):
                                    log::info(Where.FILE, "Loaded texture '%s' for material '%s' in file '%s'", relative_texture_path, self.name, self.mtrfile.path);
                                $endif
                            }
                        case mtr::isXmlNode(child, Node.BLEND):
                            self.parse_blend(child, self.getStage(STAGE_DIFFUSE));
                            // NOTE(HM) this is a blend map, we will use it to blend two textures together
                            // TODO(HM) implement this
                            //log::warning(Where.FILE, "Blend is not implemented yet! Skipping node '%s' in material '%s' in file '%s'", child.name, self.name, self.mtrfile.path);
                        case mtr::isXmlNode(child, Node.COLOR):
                            self.getStage(STAGE_DIFFUSE).color = mtr::xmlStrColorToColor(child.getText());
                        case mtr::isXmlNode(child, Node.KEYWORD):
                            self.parse_keyword(child);
                            // if(child.hasAttributes()) 
                            // {
                            //     self.getStage(STAGE_DIFFUSE).register_args(child);
                            //     self.getStage(STAGE_DIFFUSE).handle_args(child, self);
                            // }
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
fn void HMaterial.parse_keyword(&self, XmlNode* node) @public
{
    String keyword = node.getText();
    if(keyword.is_empty()) {
        log::warning(Where.FILE, "RLMaterial '%s' in file '%s' has a empty keyword node!", self.name, self.mtrfile.path);
        return;
    }

    if(keyword.has_spaces()) {
        //keyword = keyword.treplace(" ", ""); // remove spaces from the keyword
        keyword.remove_spaces(); // remove spaces from the keyword
    }

    StageArgument arg;
    if(keyword.contains("="))
    {
        // split the keyword by the '=' character
        // NOTE(HM) this is a simple way to parse key=value pairs, but it is not very robust
        // perhaps we should use a more robust parser in the future?
        // for now, we will just split the string and use the first part as the key and the second part as the value
        String[] data = keyword.tsplit("=");
        assert(data.len > 0, "Invalid keyword '%s' found in material '%s' in file '%s'!", keyword, self.name, self.mtrfile.path);
        assert(data[0].len > 0, "Invalid keyword '%s' found in material '%s' in file '%s'! Value before = is empty!", keyword, self.name, self.mtrfile.path);
        assert(data[1].len > 0, "Invalid keyword '%s' found in material '%s' in file '%s'! Value after = is empty!", keyword, self.name, self.mtrfile.path);
        arg.first = data[0].tcopy();
        arg.second = data[1].tcopy();
    }
    else
    {
        // else, just use the keyword as the key and an empty string as the value
        arg.first = keyword.tcopy();
        //arg.second = "";
    }

    switch (arg.first)
    {
        case NodeKeyword.TRANSLUCENT.str:
            self.setCoverage(COVERAGE_TRANSLUCENT);
        case NodeKeyword.ALPHA.str:
            self.setCoverage(COVERAGE_PERFORATED);
            float alpha = misc::clamp01f(arg.second.to_float()!!);
             // multiply previous alpha values by our new value
            if(alpha > 0.0f && alpha < 1.0f) {
                // set the material coverage to match
                if ((bool)(self.coverage & COVERAGE_TRANSLUCENT) == false) self.setCoverage(COVERAGE_TRANSLUCENT);
            }
            MaterialStage* stage = self.getStage(STAGE_DIFFUSE);
            stage.color.a = (char)misc::@mapValueRangeToOther(alpha, 0.0f, 1.0f, 0, 255);
            self.flags.has_AlphaTest = true;
        case NodeKeyword.SORT.str:
            self.sort = arg.second.to_uint()!!;
        case NodeKeyword.CLAMP.str:
        case NodeKeyword.ALPHAZEROCLAMP.str:
        case NodeKeyword.TILE_H:
        case NodeKeyword.TILE_V:
        case NodeKeyword.SCROLL_X:
        case NodeKeyword.SCROLL_Y:
        case NodeKeyword.TRANSLATE_X:
        case NodeKeyword.TRANSLATE_Y:
            @todo();
        default:
            log::warning(Where.FILE, "Unknown keyword '%s' found in material '%s' in file '%s'!", keyword, self.name, self.mtrfile.path);
    }
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


fn int HMaterial.nameToSrcBlendMode(&self, String name ) 
{
    switch(name)
    {
        case "GL_ONE":
        case "gl_one": return rl::RL_ONE;
        case "GL_ZERO": 
        case "gl_zero": return rl::RL_ZERO;
        case "GL_DST_COLOR": 
        case "gl_dst_color": return rl::RL_DST_COLOR;
        case "GL_ONE_MINUS_DST_COLOR": 
        case "gl_one_minus_dst_color": return rl::RL_ONE_MINUS_DST_COLOR;
        case "GL_SRC_ALPHA": 
        case "gl_src_alpha": return rl::RL_SRC_ALPHA;
        case "GL_ONE_MINUS_SRC_ALPHA": 
        case "gl_one_minus_src_alpha": return rl::RL_ONE_MINUS_SRC_ALPHA;
        case "GL_DST_ALPHA": 
        case "gl_dst_alpha": return rl::RL_DST_ALPHA;
        case "GL_ONE_MINUS_DST_ALPHA": 
        case "gl_one_minus_dst_alpha": return rl::RL_ONE_MINUS_DST_ALPHA;
        case "GL_SRC_ALPHA_SATURATE": 
        case "gl_src_alpha_saturate": return rl::RL_SRC_ALPHA_SATURATE;
    }

	log::warning(Where.FILE, "unknown blend mode '%s' in material '%s'", name, self.name);
	self.flags.has_defaulted = true;

	return rl::RL_ONE;
}


fn int HMaterial.nameToDstBlendMode(&self, String name ) 
{
    switch(name)
    {
        case "GL_ONE": 
        case "gl_one": return rl::RL_ONE;
        case "GL_ZERO": 
        case "gl_zero": return rl::RL_ZERO;
        case "GL_SRC_ALPHA": 
        case "gl_src_alpha": return rl::RL_SRC_ALPHA;
        case "GL_ONE_MINUS_SRC_ALPHA": 
        case "gl_one_minus_src_alpha": return rl::RL_ONE_MINUS_SRC_ALPHA;
        case "GL_DST_ALPHA": 
        case "gl_dst_alpha": return rl::RL_DST_ALPHA;
        case "GL_ONE_MINUS_DST_ALPHA": 
        case "gl_one_minus_dst_alpha": return rl::RL_ONE_MINUS_DST_ALPHA;
        case "GL_SRC_COLOR": 
        case "gl_src_color": return rl::RL_SRC_COLOR;
        case "GL_ONE_MINUS_SRC_COLOR": 
        case "gl_one_minus_src_color": return rl::RL_ONE_MINUS_SRC_COLOR;
    }

	log::warning(Where.FILE, "unknown blend mode '%s' in material '%s'", name, self.name);
	self.flags.has_defaulted = true;

	return rl::RL_ONE;
}

<*
    @param [&in] node : "node to get data from"
    @param [&inout] stage : "stage to set data for"
*>
fn void HMaterial.parse_blend(&self, XmlNode* node, MaterialStage *stage ) 
{
    if(node.hasAttributes() == false) return;

    String mode = (String)node.getAttribute(NodeAttrib.BLEND_MODE).value;

	// baked blending combinations
    switch(mode)
    {
        case "blend":
            stage.drawStateBits = BLEND_BLEND;
            return; // we are done here
        case "add":
            stage.drawStateBits = BLEND_ADD;
            return; // we are done here
        case "screen": // soft additive
            stage.drawStateBits = BLEND_SCREEN;
            return; // we are done here
        case "dodge": // even softer additive
            stage.drawStateBits = BLEND_DODGE;
        case "filter":
        case "modulate":
        case "multiply":
            stage.drawStateBits = BLEND_MODULATE;
            return; // we are done here
        case "none":
            // none is used when defining an alpha mask that doesn't draw
            stage.drawStateBits = BLEND_NONE;
            return; // we are done here
        case "bumpmap":
            stage.lighting = SL_BUMP;
            return; // we are done here
        case "diffusemap":
            stage.lighting = SL_DIFFUSE;
            return; // we are done here
        case "specularmap":
            stage.lighting = SL_SPECULAR;
            return; // we are done here
	}

    // custom blending modes
    String[] tokens = mode.tsplit(",");
    assert(tokens.len == 2, "Invalid blend mode '%s' in material '%s' in file '%s'! Expected two tokens separated by a comma.", mode, self.name, self.mtrfile.path);

	int srcBlend = self.nameToSrcBlendMode( tokens[0] );
	int dstBlend = self.nameToDstBlendMode( tokens[1] );

	stage.drawStateBits = srcBlend | dstBlend;
}

enum ShaderLayoutLocation : inline int
{
    VERTEX_POSITION,    // layout location: 0
    VERTEX_TEXCOORD01,  // layout location: 1
    VERTEX_NORMAL,      // layout location: 2
    VERTEX_COLOR,       // layout location: 3
    VERTEX_TANGENT,     // layout location: 4
    VERTEX_TEXCOORD02,  // layout location: 5
}

struct ShaderVertexAttribute @local
{
    ShaderLayoutLocation loc; // layout location of the attribute set in the material
    RLShdrAttrbDatTyp type; // type of the attribute
}

struct ShaderUniform @local
{
    String id; // name of the uniform
    RLShdUniTyp type; // type of the uniform
}

<*
    @param [&in] child : "node to get data from"
    @param [&inout] shader : "shader to set the vertex attribute for"
*>
fn void HMaterial.parse_vertex_attribute(&self, XmlNode* child, RLShader* shader)
{
    // NOTE(HM) this is a node that defines a vertex attribute for the shader
    // it should have attributes like type, location and value
    if(child.hasAttributes())
    {
        ShaderVertexAttribute attrb;
        foreach NODE: (atrb : child.attributes)
        {
            switch(atrb.name)
            {
                case NodeAttrib.TYPE:
                    switch(atrb.value)
                    {
                        case "float":
                            attrb.type = RLShdrAttrbDatTyp.FLOAT;
                        case "vec2":
                            attrb.type = RLShdrAttrbDatTyp.VEC2;
                        case "vec3":
                            attrb.type = RLShdrAttrbDatTyp.VEC3;
                        case "vec4":
                            attrb.type = RLShdrAttrbDatTyp.VEC4;
                        default:
                            log::error(Where.FILE, "Invalid type '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                            break NODE; // continue to the next node
                    }
                case NodeAttrib.LOCATION:
                    int loc = atrb.value.to_int()!!;
                    attrb.loc = ShaderLayoutLocation.from_ordinal(loc);
                    if(loc < 0 || loc >= 6) 
                    {
                        log::error(Where.FILE, "Invalid value '%d' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                loc, atrb.name, child.name, self.name, self.mtrfile.path);
                        break NODE; // continue to the next node
                    }
                case NodeAttrib.VALUE:
                    if(atrb.value == "-1") break NODE; // -1 means no value, skip all
                    // else
                    /*
                    String attrb_id;
                    switch(attrb.loc)
                    {
                        case VERTEX_POSITION:   attrb_id = RLShdLocInd.VERTEX_POSITION.str;
                        case VERTEX_TEXCOORD01: attrb_id = RLShdLocInd.VERTEX_TEXCOORD01.str;
                        case VERTEX_NORMAL:     attrb_id = RLShdLocInd.VERTEX_NORMAL.str;
                        case VERTEX_COLOR:      attrb_id = RLShdLocInd.VERTEX_COLOR.str;
                        case VERTEX_TANGENT:    attrb_id = RLShdLocInd.VERTEX_TANGENT.str;
                        case VERTEX_TEXCOORD02: attrb_id = RLShdLocInd.VERTEX_TEXCOORD02.str;
                        default:
                            log::error(Where.FILE, "Invalid stage index '%d' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                loc, atrb.name, node.name, self.name, self.mtrfile.path);
                            continue NODE; // continue to the next node
                    }

                    shader.locs[loc] = shader.getAttributeLocation(attrb_id);
                    */

                    int loc = attrb.loc.ordinal;
                    switch(attrb.type)
                    {
                        case RLShdrAttrbDatTyp.FLOAT:
                            float f = atrb.value.to_float()!!;
                            if(f == 0.0f) {
                                log::error(FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                    atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                                break NODE; // continue to the next node
                            }
                            shader.setValue(loc, (void*)&f, RLShdrAttrbDatTyp.FLOAT.ordinal);
                        case RLShdrAttrbDatTyp.VEC2:
                            Vec2f vec2 = getVector2FromString(atrb.value);
                            if(vec2.x == 0.0f && vec2.y == 0.0f) {
                                log::error(FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                    atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                                break NODE; // continue to the next node
                            }
                            float[*] arr = {vec2.x, vec2.y};
                            shader.setValueV(loc, (void*)&arr, RLShdrAttrbDatTyp.VEC2.ordinal, 1);
                        case RLShdrAttrbDatTyp.VEC3:
                            Vec3f vec3 = getVector3FromString(atrb.value);
                            if(vec3.x == 0.0f && vec3.y == 0.0f && vec3.z == 0.0f) {
                                log::error(FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                    atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                                break NODE; // continue to the next node
                            }
                            float[*] arr = {vec3.x, vec3.y, vec3.z};
                            shader.setValueV(loc, (void*)&arr, RLShdrAttrbDatTyp.VEC3.ordinal, 1);
                        case RLShdrAttrbDatTyp.VEC4:
                            Vec4f vec4 = getVector4FromString(atrb.value);
                            if(vec4.x == 0.0f && vec4.y == 0.0f && vec4.z == 0.0f && vec4.w == 0.0f) {
                                log::error(FILE, "Invalid value '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                    atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                                break NODE; // continue to the next node
                            }
                            float[*] arr = {vec4.x, vec4.y, vec4.z, vec4.w};
                            shader.setValueV(loc, (void*)&arr, RLShdrAttrbDatTyp.VEC4.ordinal, 1);
                        default:
                            log::error(FILE, "Invalid type '%s' for attribute '%s' in node '%s' of material '%s' in file '%s'!", 
                                atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                            break NODE; // continue to the next node
                    }
                default:
                    log::warning(CONSOLE, "Unnused attribute '%s' found in node '%s' of material '%s' in file '%s'!", atrb.name, child.name, self.name, self.mtrfile.path);
            }
        }
    }
    else 
    {
        log::warning(FILE, "Vertex attribute node '%s' in material '%s' in file '%s' has no attributes!", child.name, self.name, self.mtrfile.path);
    }
}

<*
    @param [&in] child : "node to get data from"
    @param [&inout] shader : "shader to set the uniform for"
*>
fn void HMaterial.parse_uniform(&self, XmlNode* child, RLShader* shader)
{
    if(child.hasAttributes())
    {
        ShaderUniform uniform;
        foreach NODE: (atrb : child.attributes)
        {
            switch(atrb.name)
            {
                case NodeAttrib.ID:
                    uniform.id = atrb.value.tcopy();
                case NodeAttrib.TYPE:
                    switch(atrb.value)
                    {
                        case "float": break; // NOTE(HM) this zero so is set to float by default
                            //uniform.type = RLShdUniTyp.FLOAT;
                        case "vec2":
                            uniform.type = RLShdUniTyp.VEC2;
                        case "vec3":
                            uniform.type = RLShdUniTyp.VEC3;
                        case "vec4":
                            uniform.type = RLShdUniTyp.VEC4;
                        case "sampler2D":
                            uniform.type = RLShdUniTyp.SAMPLER2D;
                        default:
                            log::error(Where.FILE, "Invalid type '%s' for uniform '%s' in node '%s' of material '%s' in file '%s'!", 
                                atrb.value, atrb.name, child.name, self.name, self.mtrfile.path);
                            break NODE; // continue to the next node
                    }
                case NodeAttrib.VALUE:
                    if(atrb.value == "-1") break NODE; // continue to the next node
                    // else
                    int loc = shader.getUniformLocation(uniform.id.zstr_tcopy());
                    switch(uniform.type)
                    {
                        case RLShdUniTyp.FLOAT:
                            float f = atrb.value.to_float()!!;
                            shader.setValue(loc, (void*)&f, RLShdUniTyp.FLOAT.ordinal);
                        case RLShdUniTyp.VEC2:
                            Vec2f vec2 = getVector2FromString(atrb.value);
                            shader.setValueV(loc, (void*)&&((float[2]){vec2.x, vec2.y}), RLShdUniTyp.VEC2.ordinal, 1);
                        case RLShdUniTyp.VEC3:
                            Vec3f vec3 = getVector3FromString(atrb.value);
                            shader.setValueV(loc, (void*)&&((float[3]){vec3.x, vec3.y, vec3.z}), RLShdUniTyp.VEC3.ordinal, 1);
                        case RLShdUniTyp.VEC4:
                            Vec4f vec4 = getVector4FromString(atrb.value);
                            shader.setValueV(loc, (void*)&&((float[4]){vec4.x, vec4.y, vec4.z, vec4.w}), RLShdUniTyp.VEC4.ordinal, 1);
                        case RLShdUniTyp.SAMPLER2D:
                            RLTexture2D tex = *astmng::assetManager.getTexture(atrb.value);
                            if(!rl::isTextureValid(tex)) {
                                log::error(Where.FILE, "Failed to load texture '%s' for sampler2D uniform '%s' in node '%s' of material '%s' in file '%s'!", 
                                    atrb.value, uniform.id, child.name,
                                    self.name, self.mtrfile.path);
                                break NODE; // continue to the next node
                            }
                            shader.setValueTexture(loc, tex);
                        default:
                            log::error(Where.FILE, "Invalid value '%s' for uniform '%s' in node '%s' of material '%s' in file '%s'!", 
                                atrb.value, uniform.id, child.name, self.name, self.mtrfile.path);
                            break NODE; // continue to the next node
                }
                default:
                    log::error(Where.FILE, "Invalid shader uniform type '%s' for uniform '%s' in node '%s' of material '%s' in file '%s'!", 
                                uniform.type, uniform.id, child.name, self.name, self.mtrfile.path);
                    break NODE; // continue to the next node
            }
        }
    }
    else
    {
        log::warning(Where.FILE, "shader uniform node '%s' in material '%s' in file '%s' has no attributes!", child.name, self.name, self.mtrfile.path);
    }
}

<*
    @param [&in] node : "node to get data from"
*>
fn void HMaterial.parse_shader(&self, XmlNode* node) @public
{
    String shader_path = (String)node.getAttribute(NodeAttrib.PATH).value;
    if(shader_path.is_empty()) {
        log::warning(Where.FILE, "RLMaterial '%s' in file '%s' has a shader node but no path for it defined!", self.name, self.mtrfile.path);
        return;
    }

    // NOTE(HM) I'm appending the extension here just as a placeholder, to make it easy to get the shader name.
    RLShader shader;
    shader_path = shader_path.tconcat(".tp");
    String shader_name = fs::getFileNameWithoutExt(shader_path);
    if(RLShader* shader_found = astmng::assetManager.getShader(shader_name))
    {
        shader = *shader_found; // use the shader from the asset manager
        $if $feature(_DEBUG):
            log::info(Where.FILE, "Using shader '%s' for material '%s' in file '%s'", shader_name, self.name, self.mtrfile.path);
        $endif
    }
    else
    {
        // load the shader from the file system
        shader_path = shader_path.stripExtension();
        shader = glsl::loadShader(shader_path.tconcat(".vs"), shader_path.tconcat(".fs"));
    }

    if(!shader.isValid()) {
        log::error(Where.FILE, "Failed to load shader '%s' for material '%s' in file '%s'!", shader_path, self.name, self.mtrfile.path);
        return;
    }


    if(node.children.len() > 0)
    {
        // parse the shader arguments
        foreach(child: node.children)
        {
            switch
            {
                case child.name == Node.VERTEX_ATTRIBUTE.str:
                    self.parse_vertex_attribute(child, &shader);
                case child.name == Node.UNIFORM.str:
                    self.parse_uniform(child, &shader);
                default:
                    log::warning(Where.FILE, "Unnused shader node '%s' found in material '%s' in file '%s'!", child.name, self.name, self.mtrfile.path);
            }
        }
    }

    self.setShader(shader);
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

fn RLColor getColorFromString(String str) @inline @local
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
//              MTRFile - RLMaterial file data structure
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
import engine::logging::log;
import engine::filesystem::fs;
import engine::assets_api::astmng; // asset manager
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
    BLEND            = "blend", // used for blending two textures together
    VIDEO_MAP        = "video_map",
    KEYWORD          = "keyword", // global or stage keywords
    COLOR            = "color",
    ALBEDO           = "albedo",
    NORMAL           = "normal",
    SPECULAR         = "specular",
    SOUND            = "sound",
    SHADER           = "shader",
    VERTEX_ATTRIBUTE = "vertex_attribute",
    UNIFORM          = "uniform"
}

<*
    @param [&in] node : "node to compare the name"
*>
fn bool isXmlNode(XmlNode* node, Node kind) @inline @public => (node.name == kind.str) ? true : false;

enum NodeKeyword : int (inline String str) @public
{
    // general
    TRANSLUCENT    = "translucent",
    CLAMP          = "clamp",
    ALPHAZEROCLAMP = "alphazeroclamp",   // prevents the alpha channel of this material from tiling by forcing 100% opacity outside normalized UV coordinates
    SORT           = "sort",             // used to sort materials by their sort value, lower values are rendered first
    ALPHA          = "alpha",
    TILE_H         = "tileH",
    TILE_V         = "tileV",
    SCROLL_X       = "scrollX",
    SCROLL_Y       = "scrollY",
    TRANSLATE_X    = "translateX",
    TRANSLATE_Y    = "translateY",
}

// NOTE(HM) This represents the atributes assigned to a xml node
enum NodeAttrib : int (inline String str) @public
{
    // general
    NAME        = "name",
    VERSION     = "version",
    PATH        = "path",
    KIND        = "kind",
    BLEND_MODE  = "mode", // used for blending modes in the material

    // shader specific
    LOCATION    = "loc", // shader location for the attribute
    VALUE       = "value", // used for vertex attributes and uniforms
    TYPE        = "type", // used for vertex attributes and uniforms
    ID          = "id", // used for uniforms
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
    self.path = path.tcopy();
    self.version = MTR_VERSION_STRING;
    self.mats.reserve(MAX_MATERIALS_PER_FILE);
}

fn void MTRFile.unload(&self) @inline @public
{
    if(self.mats.len() == 0) return; // nothing to unload

	foreach(mat: self.mats) mat.free();
    self.mats.free();
}

<*
    @param [&in] mat : "material to register"
*>
fn void MTRFile.register(&self, HMaterial* mat) @inline @public
{
    if(self.mats.len() >= MAX_MATERIALS_PER_FILE) {
        log::error(Where.FILE, "Maximum number of materials per mtr file reached (%d), cannot register material '%s' in file '%s'.", MAX_MATERIALS_PER_FILE, mat.name, self.path);
        return;
    }
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
    // Remove the comments if you want to print the materials in the console.
    /*
    io::printfn("[MTR '%s' v: %s]", fs::getFileNameWithoutExt(self.path), self.version);
    io::printfn("{");
    if(self.mats.len()) {
        foreach(mat: self.mats) mat.print();
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
       log::warning(Where.FILE, " Failed to load/open MTR xml file [%s] with excuse: %s", self.path, excuse);
       return MTR_LOAD_ERROR~;
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
       log::error(Where.FILE, " Malformed material data file '%s', root node expected to be 'MTR' but is '%s' instead.", self.path, doc.rootNode.name);
       return MTR_MALFORMED_FILE~;
    }

    String? version = (String)doc.rootNode.getAttribute(NodeAttrib.VERSION).value;
    if (catch excuse = version)
    {
        log::error(Where.FILE, "Failed to get material version attribute in %s with excuse: %s\n", self.path, excuse);
        return false;
    }
    // else got version, so check if it matches the current version
    // TODO(HM) handle version changes.
    if(version != MTR_VERSION_STRING)
    {
        log::error(Where.FILE, " Invalid material data file '%s', version expected to be '%s' but is '%s' instead.", self.path, MTR_VERSION_STRING, version);
        return MTR_VERSION_MISMATCH~;
    }

    // else everything should be fine from here, so keep parsing this material data
    self.version = version.tcopy();
    
    // now parse each MTR xml node
    foreach (node : doc.rootNode.children)
    {
        $if $feature(_DEBUG):
            if(node == null) 
            {
                log::error(Where.FILE, "Null node found in mtr file '%s', skipping it.", self.path);
                return MTR_MATERIAL_PARSING_ERROR~;
            }
        $endif

        switch
        {
            // Skip any text nodes assigned to the root node (shouldn't happen now though).
            // Text nodes are handled further by the material parser, so we don't need to handle them here.
            case isXmlNode(node, Node.TEXT):
                log::error(Where.FILE, "Unexpected 'TEXT' node found in body of MTR '%s'! Text = '%s' ", fs::getFileNameWithoutExt(self.path), node.value);
                // This was caused by a bug in the xml reader code (not very easy to solve but I worked around it). 
                // The xml reader, treats any end char '>', as always being followed by a Text "node", 
                //  (free text between a '>' and a '<'), so in some situations, it created empty text nodes, 
                //  like when after a '>' char, came the start char '<' of another node, 
                //  but you add in between them, empty characters (space, new line), but even so 
                //  the xml reader, still considered those as valid "text". 
                // Because the xml reader, reads character by character, is not easy to solve this, 
                //  so it will create a text node, regardless if is empty or not.  
                // The workaround, was to test for empty text nodes and just don't register them, in the xml doc file.
                return MTR_MATERIAL_PARSING_ERROR~;
                //
            case mtr::isXmlNode(node, Node.MATERIAL):
                HMaterial* mat = self.parse_material(node);
                if(mat) {
                    self.register(mat);
                } else {
                    log::error(Where.FILE, "Failed to parse material node '%s' in mtr file '%s'", node.name, self.path);
                    return MTR_MATERIAL_PARSING_ERROR~;
                }
            default:
                log::warning(Where.FILE, " Unexpected node in mtr file '%s', expected <MATERIAL> found <%s>", self.path, node.name);
                $if $feature(_DEBUG):
                    return MTR_MATERIAL_PARSING_ERROR~;
                $else
                    continue;
                $endif
        }
    } // end foreach node
    
    return true;
}

// @Performance This will probably be very slow with many mtr files 
// and material definitions...
// TODO(HM) make this faster by using a hash table
fn bool check_material_existance(String name, MTRFile* mtr_file = null) @inline @public
{
    // first check if the material name already exists in the current passed mtr file
    if(mtr_file != null) if(mtr_file.findMaterial(name) != null) return true;

    // else check for it in the global material database
    // NOTE(HM) this is a slow operation, so use it with caution
    MaterialDataBase* mtr_db = &game::gpGame.mtrDB;
    foreach(mtr: mtr_db.data) {
        if(mtr.findMaterial(name) != null) return true;
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
        log::error(Where.FILE, "Failed to get material name attribute in %s with excuse: %s\n", self.path, excuse);
        mat.free();
        mem::free(mat);
        return null;
    }
    
    if (mat_name.is_empty())
    {
        log::error(Where.FILE, "material with empty or no name in %s\n", self.path);
        mat.free();
        mem::free(mat);
        return null;
    }

    // check if the material name already exists in the database
    if(check_material_existance(mat_name, self) == true)
    {
        log::warning(Where.FILE, "material with name '%s' already exists in %s\n", mat_name, self.path);
        mat.free();
        mem::free(mat);
        return null;
    }
    
    // else everything should be fine from here, so keep parsing this material data
    mat.name = mat_name.tcopy();
    mat.mtrfile = self; // set the material file pointer to this mtr file
    
    // parse extra material attributes if any
    mat.parse_node_atributes(in_node);

    /////////////////////////////////////////////
    // NOTE(HM) this is the main part of the material parsing, where we parse all the child nodes of the material node
    // and set the material data accordingly
    foreach (node : in_node.children)
    {
       // just in case...
       if(node == null) {
            log::warning(Where.FILE, "Null child node found for material '%s', skipping it.", mat.name);
            continue;
       }

       switch(node.name)
       {
            case Node.TEXT.str:
                // NOTE(HM) free text nodes are not supported here, so we just skip them
                /*
                <MATERIAL name="somename">
                    some free text here, that should not be here
                <maps>
                    <albedo>
                        <map>images/icons/stickman.png</map>
                        <keyword>alpha=0.5</keyword>
                    </albedo>
                </maps>
                </MATERIAL>
                */
                log::warning(Where.FILE, "Unexpected text node found in material '%s'! Text = '%s' ", mat.name, node.value);
                continue;
            case Node.COMMENT.str: 
                mat.parse_comment(node);
            case Node.KEYWORD.str: 
                mat.parse_keyword(node);
            /*case Node.STAGE.str: // TODO(HM) this should be used in the future to use individual stage nodes, but is disabled for now
                mat.parse_stage(node);
                continue;*/
            case Node.MAPS.str:  // TODO(HM) deprecate this in the future
                /*log::warning(Where.FILE, "Deprecated node '%s' found in material '%s', use '%s' instead.", 
                    node.name, mat.name, Node.STAGE.str);*/
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
// RLMaterial Manager
//////////////////////////

module game::material::manager::mtrmng @private;

// region imports
import std::io;
import game::main; // for file logging or console logging
import engine::misc;
import game::material::mtr, game::material::mat;
import engine::logging::log;
import std::collections::list, std::collections::tuple;
import engine::assets_api::astmng; // asset manager
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
		log::warning(Where.FILE,  "Unable get mtr files paths from folder: %s with excuse: %s", search_path, excuse);
		return FOLDER_SCAN_ERROR~;
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
                log::warning(Where.FILE, " unexpected '%s' file name found inside material folder.", file_name);
				continue; // to next file
			}
			
			if(fs::getFileExtension(asset_path) != ".mtr") 
            {
                log::warning(Where.FILE, " unexpected file type '%s' found inside material folder.", file_name);
				continue; // to next file
			}
			
            //****
			// from here should be a mtr file
            //****

            if(file::get_size(asset_path)! < 10) // TODO(HM) make this a constant
            {
                log::warning(Where.FILE, " mtr file [%s] is too small to be valid, skipping it.", asset_path);
                continue; // to next file
            }
            
            // we have a valid size file, so now try to open it

            File? file = fs::openFile(asset_path, "r");
            defer file.close()!!;
            
            if(catch excuse = file) 
            {
               log::warning(Where.FILE, " Failed to open mtr file [%s] with excuse: %s", asset_path, excuse);
               // DOC(HM) I need to always return from a catch or the excuse will not unwrap,
               // causing variable shadow error, preventing me from using excuse again bellow.
               continue; // to next file
            }

            // we could open it, so now try to load and save it's data
            MTRFile* mtr_file = mem::new(MTRFile);
            mtr_file.path = asset_path;
            
            if(catch excuse = mtr_file.load(file))
            {
                log::warning(Where.FILE, " Failed to load [%s]", asset_path);
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
    @require game::gpGame.app_base_folder.len > 0
*>
fn void? loadMaterialFilesTo(MaterialDataBase* db) @inline @public
{
    String material_folder = game::gpGame.app_base_folder.tconcat("materials").tconcat("\\");
	load_mtr_files(material_folder, db)!!;

    // see if we have a default material file, if not create one
    if(db.getMaterial("default_material") == null)
    {
        // TODO(HM) Makes this use the default material definition
        // from the HMaterial.defaultDefinition() function
        log::error(Where.FILE, "Default material not found in mtr database, creating one...");
        HMaterial* default_material = mem::new(HMaterial);
        default_material.init();
        default_material.name = "default_material";
        default_material.getStage(mat::STAGE_DIFFUSE).tex = game::gpGame.default_texture;
        default_material.getStage(mat::STAGE_DIFFUSE).color = rl::WHITE;
        db.data[0].register(default_material);
    }
}

<*
    Performance: This will probably be very slow with many materials...

    @param [in] material_name : "name of the material to search for"
    @require material_name.len > 0
    @require game::gpGame.mtrDB.data.len() > 0
*>
fn HMaterial* getMaterial(String material_name) @public
{
    HMaterial* mat;
    uint index;

    uint count = (uint)game::gpGame.mtrDB.data.len();
    if(count == 0) {
        log::error(Where.FILE, "No material files loaded in the game, cannot get material '%s'", material_name);
        return null;
    }

    do { // @Performance This is a linear search, so it will be slow with many materials.
        // NOTE(HM): This is done this way because findMaterial() from MTRFile returns null 
        // if the material is not found in the mtr data, so while we have materials in the data base
        // we need to keep looking through all of them.
        mat = game::gpGame.mtrDB.data[index++].findMaterial(material_name);
    } while(mat == null && index < count);

    // just for testing purposes
    if(mat != null) {
	    assert(rl::isTextureValid(*mat.getTexture(mat::TEXTURE_DIFFUSE)));
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

fn void MaterialDataBase.listMTRs(&self) @public 
{
    $if $feature(_DEBUG):
        if(self.data.len())
        {
            log::info(CONSOLE, "[MATERIAL FILES]");
            foreach(mtr: self.data) {
                String trimmed_path = "...\\".tconcat(mtr.path.strip(game::gpGame.app_base_folder));
                io::printfn("%s\t-> \"%s\"%s", ansi::color_rgb(171, 218, 217), trimmed_path, Ansi.RESET);
            }
        }
    $endif
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
