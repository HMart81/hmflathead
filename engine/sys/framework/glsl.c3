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

//////////////////// shader stuff /////////////////

module engine::sys::framework::glsl;

import game::main;
import thirdparty::raylib5::rl;
import engine::filesystem::fs;
import engine::logging::log;

const String GLOBAL_SHADER_INCLUDE = `
#version 330
#extension GL_ARB_shading_language_420pack: enable

// default vertex layout locations
#define VERTEX_POSITION   0    // RLShader location: vertex attribute: position
#define VERTEX_TEXCOORD01 1    // RLShader location: vertex attribute: texcoord01
#define VERTEX_NORMAL     2    // RLShader location: vertex attribute: normal
#define VERTEX_COLOR      3    // RLShader location: vertex attribute: color
#define VERTEX_TANGENT    4    // RLShader location: vertex attribute: tangent
#define VERTEX_TEXCOORD02 5    // RLShader location: vertex attribute: texcoord02
// matrix locations
#define MATRIX_MVP        6    // RLShader location: matrix uniform: model-view-projection
#define MATRIX_VIEW       7    // RLShader location: matrix uniform: view (camera transform)
#define MATRIX_PROJECTION 8    // RLShader location: matrix uniform: projection
#define MATRIX_MODEL      9    // RLShader location: matrix uniform: model (transform)
#define MATRIX_NORMAL     10   // RLShader location: matrix uniform: normal
#define VECTOR_VIEW       11   // RLShader location: vector uniform: view
#define COLOR_DIFFUSE     12   // RLShader location: vector uniform: diffuse color
#define COLOR_SPECULAR    13   // RLShader location: vector uniform: specular color
#define COLOR_AMBIENT     14   // RLShader location: vector uniform: ambient color
// texture samplers
#define MAP_ALBEDO        15   // RLShader location: sampler2d texture: albedo (same as: SHADER_LOC_MAP_DIFFUSE)
#define MAP_METALNESS     16   // RLShader location: sampler2d texture: metalness (same as: SHADER_LOC_MAP_SPECULAR)
#define MAP_NORMAL        17   // RLShader location: sampler2d texture: normal
#define MAP_ROUGHNESS     18   // RLShader location: sampler2d texture: roughness
#define MAP_OCCLUSION     19   // RLShader location: sampler2d texture: occlusion
#define MAP_EMISSION      20   // RLShader location: sampler2d texture: emission
#define MAP_HEIGHT        21   // RLShader location: sampler2d texture: height
#define MAP_CUBEMAP       22   // RLShader location: samplerCube texture: cubemap
#define MAP_IRRADIANCE    23   // RLShader location: samplerCube texture: irradiance
#define MAP_PREFILTER     24   // RLShader location: samplerCube texture: prefilter
#define MAP_BRDF          25   // RLShader location: sampler2d texture: brdf
#define DEPTH0            26   // RLShader location: sampler2d texture: depth map 0
#define DEPTH1            27   // RLShader location: sampler2d texture: depth map 1
#define DEPTH2            28   // RLShader location: sampler2d texture: depth map 2
#define DEPTH3            29   // RLShader location: sampler2d texture: depth map 3
`;

const INCLUDE_DIRECTIVE @local = "#include";
const SHADER_HOME_PATH  @local = "shaders/";

<*
    This function replaces a special include directive in shader code for costum global code
    @param [&inout] shdcode : "the shader code to replace the directive on"
*>
fn void handleShaderIncludes(String* shdcode) @local
{
    uint include_count = (uint)(*shdcode).count(INCLUDE_DIRECTIVE);
    if(include_count > 0)
    {
        String[] lines = (*shdcode).tsplit("\r\n");
        foreach(String line : lines)
        {
            if(include_count == 0 ) break;

            if(line.is_empty()) continue; // skip empty lines
            if(line.starts_with("//")) continue; // skip comments
            if(line.starts_with("#"))
            {
                String[] tokens = line.tsplit(" ");
                foreach(String token : tokens) 
                {
                    if(token.is_empty()) continue; // skip empty tokens
                    token = token.trim(); // trim whitespace
                }

                String directive = tokens[0];
                if(directive != INCLUDE_DIRECTIVE) continue; // skip if not an include directive

                // NOTE(HM) we expect the include directive to be in the format: #include "path/to/include.inc"
                String include_path = tokens[1];
                String original_include_path = tokens[1].tcopy(); // keep the original path for later use

                if(include_path.contains(".\\") || include_path.contains("./")) {
                    // NOTE(HM) if the include path contains a slash or backslash, we will replace it with a forward slash
                    include_path = include_path.treplace("./", "\\").treplace(".\\", "\\");
                }

                if(include_path.starts_with("\"")) {
                    // NOTE(HM) remove the quotes
                    include_path = include_path.trim("\"");
                }
            
                include_path = SHADER_HOME_PATH.tconcat(include_path);

                assert(include_path.is_empty() == false, "Include path should not be empty!");

                // NOTE(HM) if the include path does not end with .inc, append it
                if(include_path.ends_with(".inc") == false) {
                    include_path = include_path.tconcat(".inc");
                }

                // NOTE(HM) now create the replace token, it will be used to detect the full include directive in the shader code
                // NOTE(HM) this will try to find the include directive text in the shader code, without caring about well-formedness
                String replace_directive = INCLUDE_DIRECTIVE.tconcat(" ").tconcat(original_include_path);

                assert(replace_directive.is_empty() == false, "replace directive should not be empty!");

                String? code_to_included = fs::readEntireFileX(main::gpGame.app_base_folder.tconcat(include_path));
                if(catch excuse = code_to_included) {
                    log::error(Where.FILE, "Failed to include file: %s, error: %s", include_path, excuse);
                    // NOTE(HM) if the file is not found, we will just remove the include directive
                    (*shdcode) = (*shdcode).treplace(replace_directive, "");
                    continue; // skip to next line
                }

                // NOTE(HM) else replace the full include directive with the code to include
                (*shdcode) = (*shdcode).treplace(replace_directive, code_to_included.tconcat("\n"));
                include_count -= 1;
            }
        }
    }
}

<*
    loads a shader file code to memory

    @param [in] vs_path : "path to the vertex shader, can be empty string"
    @param [in] fs_path : "path to frag/pixel shader, can be empty string"
*>
fn RLShader loadShader(String vs_path, String fs_path) @nodiscard
{
    // NOTE(HM) this is used to load a shader from a vertex and fragment shader file
    // if the paths are empty it will return the default shader
    if(vs_path.is_empty() && fs_path.is_empty()) {
        log::warning(Where.FILE, "Both vertex and fragment shader paths are empty, returning empty shader. -> %s::%s:%s", $$MODULE, $$FUNC, $$LINE);
        return {}; // return empty shader, afaik will use raylib default shaders
    }

    //String include_marker = "#include \"global.inc\"";
    
    // NOTE(HM) if the vertex shader path is empty, it will use the default raylib vertex shader
    String vs_shader_code;
    String fs_shader_code;

    if(vs_path.is_empty()) 
    {
        // NOTE(HM) use default vertex shader instead and try to load the custom fragment shader only
        String? code = fs::readEntireFileX(fs_path);
        if(catch excuse = code) {
            log::error(FILE, "Failed to read shader code from path: %s with excuse: %s", fs_path, excuse);
            return {};
        }
        fs_shader_code = code;
        if(fs_shader_code.is_empty()) {
            log::error(FILE, "Frag/pixel shader code from path: %s returned empty!", fs_path);
            return {}; // return empty shader will use raylib default shaders
        }

        // else
       if(fs_shader_code) handleShaderIncludes(&fs_shader_code);
        //if(fs_shader_code.contains(include_marker)) fs_shader_code = fs_shader_code.treplace(include_marker, SHADER_INCLUDE);

        return rl::loadShaderFromMemory("", fs_shader_code.zstr_tcopy());
    }

    // NOTE(HM) if the vertex shader path is not empty, we will try to read the custom vertex shader as well
    String? code = fs::readEntireFileX(vs_path);
    if(catch excuse = code) {
        log::error(FILE, "Failed to read shader code from path: %s with excuse: %s", fs_path, excuse);
        return {};
    }
    vs_shader_code = code;
    if(vs_shader_code.is_empty()) {
        log::warning(FILE, "Vertex shader code from path: %s returned empty!", vs_path);
        // if for some reason we fail to read our vertex shader, this will froce raylib default vertex shader
    }

    if(vs_shader_code.is_empty() && fs_path.is_empty()) {
        log::warning(FILE, "Both vertex and fragment shader paths are empty, returning empty shader. -> %s::%s:%s", $$MODULE, $$FUNC, $$LINE);
        return {}; // empty shader will force raylib default shaders
    }

    //if(vs_shader_code.contains(include_marker)) vs_shader_code = vs_shader_code.treplace(include_marker, SHADER_INCLUDE);
    if(vs_shader_code) handleShaderIncludes(&vs_shader_code);

    if(fs_path.is_empty()) 
    {
        // NOTE(HM) if the fragment shader path is empty, we will use the default raylib fragment shader
        return rl::loadShaderFromMemory(vs_shader_code.zstr_tcopy(), "");
    } 
    else
    {
        String? code2 = fs::readEntireFileX(fs_path);
        if(catch excuse = code2) {
            log::error(FILE, "Failed to read shader code from path: %s with excuse: %s", fs_path, excuse);
            return {};
        }
        fs_shader_code = code2; //fs::readEntireFileX(fs_path)!!;
        if(fs_shader_code.is_empty()) {
            log::error(Where.FILE, "Failed to load fragment shader from path: %s", fs_path);
            // NOTE(HM) we will use the default raylib fragment shader then
            return rl::loadShaderFromMemory(vs_shader_code.zstr_tcopy(), "");
        }
    }

    if(fs_shader_code) handleShaderIncludes(&fs_shader_code);
    
    // else both shaders are not empty, so we can load them
    return rl::loadShaderFromMemory(vs_shader_code.zstr_tcopy(), fs_shader_code.zstr_tcopy());
}

<*
    frees the memory of a given shader
    @param [&inout] shader : "shader to unload"
    @require shader != null
*>
fn void unloadShader(RLShader* shader) {
    rl::unloadShader(*shader);
}

fn void RLShader.setUniformFloatValue(self, String uniform_name, float value) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::RLShdUniTyp.FLOAT);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeFloatValue(self, String attribute_name, float value) //@inline 
{
    int locIndex = self.getAttributeLocation(attribute_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::RLShdUniTyp.FLOAT);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributelocFloatValue(self, int locIndex, float value) //@inline 
{
    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, self.locs[locIndex], (void*)&value, rl::RLShdUniTyp.FLOAT);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformFloatSliceValues(self, String uniform_name, float[] values) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::RLShdUniTyp.FLOAT, values.len);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeFloatSliceValues(self, String attribute_name, float[] values) //@inline 
{
    int locIndex = self.getAttributeLocation(attribute_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::RLShdUniTyp.FLOAT, values.len);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformIntValue(self, String uniform_name, int value) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::RLShdUniTyp.INT);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeIntValue(self, String attribute_name, int value) //@inline 
{
    int locIndex = self.getAttributeLocation(attribute_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValue(self, locIndex, (void*)&value, rl::RLShdUniTyp.INT);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformIntSliceValues(self, String uniform_name, int[] values) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::RLShdUniTyp.INT, values.len);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeIntSliceValues(self, String attribute_name, int[] values) //@inline 
{
    int locIndex = self.getAttributeLocation(attribute_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value array
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)values.ptr, rl::RLShdUniTyp.INT, values.len);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformVector2Value(self, String uniform_name, RLVector2 vec) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)&vec, rl::RLShdUniTyp.VEC2, 1);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeVector2Value(self, String attribute_name, RLVector2 vec) //@inline 
{
    int locIndex = self.getAttributeLocation(attribute_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader attribute location not found: %s", attribute_name);

    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueV(self, locIndex, (void*)&vec, rl::RLShdUniTyp.VEC2, 1);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setAttributeLocValueV(self, int locIndex, float[] vec) //@inline 
{
    // NOTE(HM) this is used to set a shader attribute value vector2
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        if(vec.len == 2) 
        {
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::RLShdUniTyp.VEC2, 1);
        } else if(vec.len == 3) {
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::RLShdUniTyp.VEC3, 1);
        } else if(vec.len == 4) {   
            rl::setShaderValueV(self, self.locs[locIndex], (void*)vec.ptr, rl::RLShdUniTyp.VEC4, 1);
        } else {
            log::warning(Where.FILE, "RLShader attribute value vector must be of size 2, 3 or 4.");
        }
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformMatrixValue(self, String uniform_name, RLMatrix mat) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value matrix
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueMatrix(self, locIndex, mat);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}

fn void RLShader.setUniformTexture(self, String uniform_name, RLTexture2D tex) //@inline 
{
    int locIndex = self.getUniformLocation(uniform_name.zstr_tcopy());
    assert(locIndex >= 0, "RLShader uniform location not found: %s", uniform_name);

    // NOTE(HM) this is used to set a shader uniform value texture
    // if the shader is invalid it will do nothing
    if(rl::isShaderValid(self)) {
        rl::setShaderValueTexture(self, locIndex, tex);
    } else {
        log::warning(Where.FILE, "RLShader is invalid, unable to set value.");
    }
}