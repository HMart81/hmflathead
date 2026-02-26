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
module engine::assets_api::asset;

//import std::io;
//import thirdparty::raylib5::rl;
//import engine::misc;
//import engine::sys::framework::glsl;
//import engine::filesystem::fs;

struct Asset <Type>
{
	String name;
	String path;
    typeid type;
	Type   data;
}

// end_region module

////////////////////////////////////////////////////////////////////////
//////////////////////// ASSET MANAGER /////////////////////////////////
// region module
module engine::assets_api::astmng;


import std::io::path;
import std::collections::list;
import thirdparty::raylib5::rl;
import game::main;
import engine::assets_api::asset;
import engine::logging::log;
import engine::filesystem::fs;
import engine::misc;
import engine::telemetry::telem;
import engine::sys::framework::glsl;

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


// TODO(HM) Support more asset types, like the new HMaterial, etc.
alias AssetTextureListPtr = List{Asset{RLTexture2D}*};
alias AssetSoundListPtr   = List{Asset{RLSound}*};
alias AssetMusicListPtr   = List{Asset{RLMusic}*};
alias AssetFontListPtr    = List{Asset{RLFont}*};
alias AssetShaderListPtr  = List{Asset{RLShader}*};

struct Manager 
{
	AssetTextureListPtr textures; // list of texture assets 
    AssetSoundListPtr   sounds;   // list of sound assets
    AssetMusicListPtr   musics;   // list of music assets
    AssetFontListPtr    fonts;    // list of font assets
    AssetShaderListPtr  shaders;  // list of shader assets
}

Manager local_manager @local;
Manager* assetManager = &local_manager;

<*
	@param [inout] asset : "the asset to register, must be a pointer to an Asset struct of a supported type, like Asset{RLTexture2D}* for example."
	@require asset.ptr != null
*>
fn void Manager.register(&self, any asset)
{
    /*if(asset.ptr == null) {
        log::error(FILE, "Trying to register a null asset, skipping it.");
        return;
    }*/

    switch(asset.type)
    {
        case RLTexture2D.typeid:
            self.textures.push((Asset{RLTexture2D}*)asset.ptr);
        case RLSound.typeid:
            self.sounds.push((Asset{RLSound}*)asset.ptr);
        case RLMusic.typeid:
            self.musics.push((Asset{RLMusic}*)asset.ptr);
        case RLFont.typeid:
            self.fonts.push((Asset{RLFont}*)asset.ptr);
        case RLShader.typeid:
            self.shaders.push((Asset{RLShader}*)asset.ptr);
        default:
            log::error(FILE, "Trying to register an asset of unknown type!");
    }
}

fn void Manager.listAssets(&self) @if($feature(_DEBUG)) 
{
    /*
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
					case asset.data.type == RLTexture2D.typeid:
						texture_assets.push(asset);
					case asset.data.type == RLShader.typeid:
						shader_assets.push(asset);
					case asset.data.type == RLSound.typeid:
						sound_assets.push(asset);
					case asset.data.type == RLMusic.typeid:
						music_assets.push(asset);
					case asset.data.type == RLFont.typeid:
						font_assets.push(asset);
					default:
						unreachable("Can't push asset \"%s\" at \"%s\", for listing, is unknown type.", asset.name, asset.path);
				}
			}
		}
	}
	
	if(texture_assets.len()) 
	{
		log::info(Where.CONSOLE, "[TEXTURES]");
		foreach(asset: texture_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(shader_assets.len()) 
	{
		log::info(Where.CONSOLE, "[SHADERS]");
		foreach(asset: shader_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path[0:asset.path.len - 3]);
		}
	}
	if(sound_assets.len()) 
	{
		log::info(Where.CONSOLE, "[SOUNDS]");
		foreach(asset: sound_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(music_assets.len()) 
	{
		log::info(Where.CONSOLE, "[MUSIC]");
		foreach(asset: music_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
	if(font_assets.len()) 
	{
		log::info(Where.CONSOLE, "[FONTS]");
		foreach(asset: font_assets) {
			io::printfn("\t-> [%s , %s]", asset.name, asset.path);
		}
	}
    */
}

// WARNING(HM) 06/11/2024
// To be used only at game exit, for now ALL assets are loaded at game start and stay in RAM, 
// for the duration of the game, aka they only get freed at game end.
// I made this like so because, 
// one I don't have many assets in this game for now,
// two nor I have a way to make real individual levels, 
// when that is done, I will have to change this to only load assets at level load,
// for now getting them hot from RAM, is very fast, compared
// to reading the data from the HD/SSD/MD2 drive.
fn void Manager.releaseAllAssets(&self) @inline 
{
    if (self.textures.len() > 0) {
        foreach(texture: self.textures) {
            rl::unloadTexture(texture.data);
        }
        self.textures.free();
    }
    if (self.shaders.len() > 0) {
        foreach(shader: self.shaders) {
            rl::unloadShader(shader.data);
        }
        self.shaders.free();
    }
    if (self.sounds.len() > 0) {
        foreach(sound: self.sounds) {
            rl::unloadSound(sound.data);
        }
        self.sounds.free();
    }
    if (self.musics.len() > 0) {
        foreach(music: self.musics) {
            rl::unloadMusicStream(music.data);
        }
        self.musics.free();
    }
    if (self.fonts.len() > 0) {
        foreach(font: self.fonts) {
            rl::unloadFont(font.data);
        }
        self.fonts.free();
    }
}

/*
<*
@require self.assets.len() > 0
*>
fn Asset* Manager.getAsset(&self, String name, typeid type) @local /*@inline*/ 
{
$if $feature(_DEBUG):
	bool failed = true;
$endif
	
	foreach(asset: self.assets)
    {
        if(asset.data.type != type) continue; // skip assets that are not of the requested type

		String asset_name = asset.name;
		
		if(asset_name == name) 
        {
$if $feature(_DEBUG):		
		failed = false;
$endif
			return asset;
		}
	} //foreach

$if $feature(_DEBUG):
	if(failed) { // to get a valid asset panic
		unreachable();
	}
$endif
	
	return null;
}
*/

fn any Manager.getAsset(&self, String name, typeid type)
{
    String needle = "/";
    if(name.contains(needle)) {
        name = name.extractFileBase();
    }

    int i; // asset index

    i = self.hasAsset(name, type);
    if( i == -1 ) {
        log::error(FILE, "Asset with name \"%s\" and type \"%s\" not found in the asset manager.", name, type);
        return null;
    }
    
	switch(type)
    {
        case RLTexture2D.typeid:
            return any_make(&(*self.textures[i]).data, type);
        case RLSound.typeid:
            return any_make(&(*self.sounds[i]).data, type);
        case RLMusic.typeid:
            return any_make(&(*self.musics[i]).data, type);
        case RLFont.typeid:
            return any_make(&(*self.fonts[i]).data, type);
        case RLShader.typeid:
            return any_make(&(*self.shaders[i]).data, type);
        default:
            unreachable();
    }
}

/*
fn any Manager.getAsset(&self, String name, typeid type)
{
    String needle = "/";
    if(name.contains(needle)) {
        name = name.extractFileBase();
    }

    if(self.hasAsset(name, type) == false) {
        log::error(FILE, "Asset with name \"%s\" and type \"%s\" not found in the asset manager.", name, type);
        return null;
    }
    
	switch(type)
    {
        case RLTexture2D.typeid:
            foreach(texture: self.textures) {
                if(texture.name == name) {
                    return any_make(&texture.data, texture.type);
                }
            }
        case RLSound.typeid:
            foreach(sound: self.sounds) {
                if(sound.name == name) {
                    return any_make(&sound.data, sound.type);
                }
            }
        case RLMusic.typeid:
            foreach(music: self.musics) {
                if(music.name == name) {
                    return any_make(&music.data, music.type);
                }
            }
        case RLFont.typeid:
            foreach(font: self.fonts) {
                if(font.name == name) {
                    return any_make(&font.data, font.type);
                }
            }
        case RLShader.typeid:
            foreach(shader: self.shaders) {
                if(shader.name == name) {
                    return any_make(&shader.data, shader.type);
                }
            }
    }
	
	return null;
}
*/

/*
fn bool Manager.hasAsset(&self, String name, typeid type) @inline 
{
    if(name == "") return false; // no asset name provided

    switch(type)
    {
        case RLTexture2D.typeid:
            foreach(texture: self.textures) {
                if(texture.name == name) {
                    return true;
                }
            }
        case RLSound.typeid:
           foreach(sound: self.sounds) {
                if(sound.name == name) {
                    return true;
                }
            }
        case RLMusic.typeid:
           foreach(music: self.musics) {
                if(music.name == name) {
                    return true;
                }
            }
        case RLFont.typeid:
           foreach(font: self.fonts) {
                if(font.name == name) {
                    return true;
                }
            }
        case RLShader.typeid:
           foreach(shader: self.shaders) {
                if(shader.name == name) {
                    return true;
                }
            }
    }
    
    return false;
}
*/

fn int Manager.hasAsset(&self, String name, typeid type) @inline
{
    if(name == "") return -1; // no asset name provided

    switch(type)
    {
        case RLTexture2D.typeid:
            foreach(i, texture: self.textures) {
                if(texture.name == name) return (int)i;
            }
        case RLSound.typeid:
           foreach(i, sound: self.sounds) {
                if(sound.name == name) return (int)i;
            }
        case RLMusic.typeid:
           foreach(i, music: self.musics) {
                if(music.name == name) return (int)i;
            }
        case RLFont.typeid:
           foreach(i, font: self.fonts) {
                if(font.name == name) return (int)i;
            }
        case RLShader.typeid:
           foreach(i, shader: self.shaders) {
                if(shader.name == name) return (int)i;
            }
    }
    
    return -1;
}

<*
	@ensure return != null
*>
fn RLTexture2D* Manager.getTexture(&self, String name) @inline @nodiscard
{
    if(name != "") 
    {
        any asset = local_manager.getAsset(name, RLTexture2D.typeid);
        if(asset.ptr != null) {
            return (RLTexture2D*)&((Asset{RLTexture2D}*)asset.ptr).data;
        }
    }
    
    log::warning(Where.FILE,  "[Asset Manager]: Requesting texture asset but returning default texture, because no asset name was provided.");
    return &game::gpGame.default_texture;
}

<*
    @param name : "the name of the shader asset to retrieve"
    @require name != ""
    @ensure return != null
*>
fn RLShader* Manager.getShader(&self, String name) @nodiscard //@inline 
{
    any asset = local_manager.getAsset(name, RLShader.typeid);
    if(asset.ptr != null) {
        return (RLShader*)&((Asset{RLShader}*)asset.ptr).data;
    }

    log::warning(Where.FILE,  "[Asset Manager]: Requesting shader asset but returning default shader, because no asset name was provided.");
	return &game::gpGame.default_shader;
}

<*
	@ensure return != null
*>
fn RLSound* Manager.getSound(&self, String name) @nodiscard @inline 
{
    if(name != "") 
    {
        any asset = local_manager.getAsset(name, RLSound.typeid);
        if(asset.ptr != null) {
            return (RLSound*)&((Asset{RLSound}*)asset.ptr).data;
        }
    }

    log::warning(Where.FILE,  "[Asset Manager]: Requesting sound asset but returning default sound, because no asset name was provided.");
    return &game::gpGame.default_sound;
}

<*
	@ensure return != null
*>
fn RLMusic* Manager.getMusic(&self, String name) @nodiscard @inline 
{
    if(name != "") 
    {
        any asset = local_manager.getAsset(name, RLMusic.typeid);
        if(asset.ptr != null) {
            return (RLMusic*)&((Asset{RLMusic}*)asset.ptr).data;
        }
    }

    log::warning(Where.FILE,  "[Asset Manager]: Requesting music asset but returning default music, because no asset name was provided.");
    return &game::gpGame.default_music;
}

<*
	@ensure return != null
*>
fn RLFont* Manager.getFont(&self, String name) @nodiscard @inline 
{
	if(name != "") 
    {
        any asset = local_manager.getAsset(name, RLFont.typeid);
        if(asset.ptr != null) {
            return (RLFont*)&((Asset{RLFont}*)asset.ptr).data;
        }
    }

    log::warning(Where.FILE,  "[Asset Manager]: Requesting font asset but returning default font, because no asset name was provided.");
    return &game::gpGame.default_font;
}

//////////////////////////////////////////////////////////////////////
///////////////////////// ASSET LOADING FUNCTIONS /////////////////////
///////////////////////////////////////////////////////

<*
	Loads an asset from a given path and registers it in the asset manager.

	@param path : "the path to the asset to load, must be a valid path to an existing file, with a supported extension, like .png for example."
	@require path != "" : "if the path is empty, it can't be a valid asset file."
	@require path.len >= 5 : "because the shortest valid asset file name is 'a.png' which is 5 characters long, if the path is shorter than that, it can't be a valid asset file."
	@require fs::fileExists(path) && path.contains(".") : "if the file doesn't exist or doesn't have an extension, it can't be a valid asset file."
*>
fn void loadAsset(String path) 
{
    /*if(path == "") {
        log::error(Where.FILE, "Trying to load an asset with an empty path, skipping it.");
        return;
    }
    
    if(path.len < 5) {
        log::error(Where.FILE, "Trying to load an asset with a path that is too short, skipping it.");
        return;
    }
	
    if(!fs::fileExists(path)) {
        log::error(Where.FILE, "Trying to load an asset with a path that does not exist: %s", path);
        return;
    }*/

    bool should_load;
    String asset_name = fs::getFileNameWithoutExt(path);
	
    String extension = fs::getFileExtension(path);
	switch(extension)
	{
	case ".png":
	case ".jpg":
	case ".tga":
        should_load = local_manager.hasAsset(asset_name, RLTexture2D.typeid) == -1;
        if(should_load) 
        {
            //path = path.trim_right(extension);
            Asset{RLTexture2D}* new_asset = mem::new(Asset{RLTexture2D}, { 
                .name = asset_name, 
                .path = path, 
                .type = RLTexture2D.typeid,
                .data = rl::loadTexture(path.zstr_tcopy())
            });
            local_manager.register(any_make(new_asset, new_asset.type));
        }
	case ".vs":
	case ".fs":
        should_load = local_manager.hasAsset(asset_name, RLShader.typeid) == -1;
        if(should_load) 
        {
            //path = path.trim_right(extension);
            Asset{RLShader}* new_asset = mem::new(Asset{RLShader}, { 
                .name = asset_name, 
                .path = path, 
                .type = RLShader.typeid,
            });

            if(path.ends_with(".fs"))
            {
                // NOTE(HM) 09/07/2025
                // if given path is pixel shader, see if there is a vertex shader with the same name
                String vertex_shader_path = path.trim_right(".fs").tconcat(".vs");
                if(fs::fileExists(vertex_shader_path))
                {
                    new_asset.data = glsl::loadShader(vertex_shader_path, path);
                } 
                else 
                {
                    // if no vertex shader is found, try to use the default vertex shader
                    // WARNING(HM) 20/07/2025
                    // if inputs and outputs don't match, the shader will not work currently!
                    new_asset.data = glsl::loadShader("", path);
                }
            } 
            else if(path.ends_with(".vs")) 
            {
                // NOTE(HM) 09/07/2025
                // if given path is vertex shader, see if there is a pixel shader with the same name
                String pixel_shader_path = path.trim_right(".vs").tconcat(".fs");
                if(fs::fileExists(pixel_shader_path))
                {
                    new_asset.data = glsl::loadShader(path, pixel_shader_path);
                } 
                else 
                {
                    new_asset.data = glsl::loadShader(path, "");
                }
            } 
            else
            {
                unreachable("RLShader path must end with either \".fs\" or \".vs\", got: %s", path);
            }
            local_manager.register(any_make(new_asset, new_asset.type));
        }
	case ".mp3": nextcase;
	case ".ogg":
		should_load = local_manager.hasAsset(asset_name, RLMusic.typeid) == -1;
        if(should_load) 
        {
            //path = path.trim_right(extension);
            Asset{RLMusic}* new_asset = mem::new(Asset{RLMusic}, { 
                .name = asset_name, 
                .path = path, 
                .type = RLMusic.typeid,
                .data = rl::loadMusicStream(path.zstr_tcopy())
            });
            local_manager.register(any_make(new_asset, new_asset.type));
        }
	case ".wav":
		should_load = local_manager.hasAsset(asset_name, RLSound.typeid) == -1;
        if(should_load) 
        {
            //path = path.trim_right(extension);
            Asset{RLSound}* new_asset = mem::new(Asset{RLSound}, { 
                .name = asset_name, 
                .path = path, 
                .type = RLSound.typeid,
                .data = rl::loadSound(path.zstr_tcopy())
            });
            local_manager.register(any_make(new_asset, new_asset.type));
        }
	case ".fnt":
		should_load = local_manager.hasAsset(asset_name, RLFont.typeid) == -1;
        if(should_load) 
        {
            //path = path.trim_right(extension);
            Asset{RLFont}* new_asset = mem::new(Asset{RLFont}, { 
                .name = asset_name, 
                .path = path, 
                .type = RLFont.typeid,
                .data = rl::loadFontEx(path.zstr_tcopy(), 
                                       game::DEFAULT_FONT_SIZE, 
                                       null, 
                                       0
                                       )
            });
            assert(rl::isFontValid(new_asset.data), "Failed to load font from path: %s", path);
            local_manager.register(any_make(new_asset, new_asset.type));
        }
    default:
        unreachable("Can't load Asset \"%s\" at \"%s\", is missing or unknown type.", asset_name, path);
	};
}

fn void? loadAssetsRecursively(String basepath, String parent_folder = "") @inline @local 
{
	String search_path = basepath;
	if(parent_folder != "")
    {
		if (parent_folder.ends_with("\\")) {
			search_path = parent_folder.tconcat(basepath).tconcat("\\");
		} else {
			search_path = parent_folder.tconcat("\\").tconcat(basepath).tconcat("\\");
		}
	}
	
	PathList? paths = path::ls(tmem, path::temp(search_path));
	if(catch excuse = paths) {
		log::warning(Where.FILE,  "Unable to get list of files from folder: %s with excuse: %s", search_path, excuse);
		return FOLDER_SCAN_ERROR~;
	}
	
	foreach(path: paths)
	{
		String path_ = search_path.tconcat(path.str_view());
		if(fs::isFile(path_)) // try to load it
        { 
			String file_name = fs::getFileNameWithoutExt(path_);
			// NOTE(HM) ignore default assets those are handled directly
			if (file_name == "default" || file_name == "splash") continue; // to next file
			
			String extension = fs::getFileExtension(path_);
			bool valid_file;
			
			foreach(ext: VALID_ASSET_EXTENSIONS) {
				if(extension == ext) { valid_file = true; break; }
			}
			
			if(valid_file == false) {
                log::warning(Where.FILE,  "File %s is not a valid asset file, skipping it.", path_);
				continue; // to next file
			}
			
            //////////////////////////////////////////////////////////////////
			// from here should be a valid file
			
			String asset_path = search_path;
			if (asset_path.ends_with("\\")) {
				asset_path = path_; //asset_path.tconcat(path.str_view());
			} else {
				asset_path = asset_path.tconcat("\\").tconcat(path.str_view());
			}
			
			// NOTE(HM) 06/11/2024 
			// When looking at C3 strings in Visual Studio, take note of the 
			// 	    string len value, this is important, because the watch window will show them as 
			// 	    a ZString (char*) and so will ignore the C3 slice len value, ending 
            //      displaying more characters than necessary or untill a null terminator (zero) 
            //      character is found. Meaning for C3 String's, Visual Studio will display 
            //      invalid characters. This fact, caused me no end of confusion for a time.
            // I was expecting to see the sliced strings in VS but they always showed as if 
            //      no cut was ever made and that throw me for a loop. So to see them correctly, 
            //      look at C3 strings in VS watch window, like so: String.ptr, len
			loadAsset(asset_path);
			continue; // to next file
			
		} else { // is a child folder/Directory so do recursive a call
			loadAssetsRecursively(path.str_view(), search_path)!;
		}
	}
}

<*
*@require game::gpGame.app_base_folder.len > 0
*>
fn void? loadAssets() {

	telem::@profile_zone("loadAssets", false)
    {
        loadAssetsRecursively(game::gpGame.app_base_folder)!!;
        
        $if $feature(_DEBUG):
            //assetManager.listAssets();
        $endif
    }; // end @profile_zone
}



/*****************************************************************************
*
*                   Bellow is still very WIP
*
******************************************************************************/

/*

module game::assets::mtr;

// region c3 modules
import std::io;
// end_region

// region user module
import thirdparty::raylib5::rl;
//import game::misc::hm;
import tiny::xml;
import game::main; // for file logging or console logging
import game::assets::astmng;
// end_region

const String INVALID_NODE_NAME = "[35, 116, 101, 120, 116]";

interface MaterialInterface
{  
    fn void free();
    fn void load(String);
    fn void parse(String);
    fn void copy(RLMaterial*) @optional;
    fn RLTexture2D* getTexture(rl::MaterialMapIndex, bool);
}

struct RLMaterial (Printable, MaterialInterface)
{
    String name;
    String path;
    
    struct maps {
        RLTexture2D* diffuse; // for now is the only supported
        //
        RLTexture2D* normal;
        RLTexture2D* bump;
        RLTexture2D* spec;
        RLTexture2D* rough;
        RLTexture2D* metal;
        RLTexture2D* ao;
        RLTexture2D* cube;
    }
    
    //shdshd::RLSound* sound;
}

fn String RLMaterial.to_string(&self, Allocator allocator) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}

fn void RLMaterial.free(&self) @dynamic
{
	if(self.maps.diffuse) self.maps.diffuse = null;
    if(self.maps.normal)  self.maps.normal  = null;
    if(self.maps.bump)    self.maps.bump    = null;
    if(self.maps.spec)    self.maps.spec    = null;
    if(self.maps.rough)   self.maps.rough   = null;
    if(self.maps.metal)   self.maps.metal   = null;
    if(self.maps.ao)      self.maps.ao      = null;
    if(self.maps.cube)    self.maps.cube    = null;
    //if(self.sound)        self.sound        = null;
}

fn void RLMaterial.copy(&self, RLMaterial* other) @dynamic
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

fn RLTexture2D* RLMaterial.getTexture(&self, rl::MaterialMapIndex index, bool isPBR = false) @dynamic
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

fn void RLMaterial.load(&self, String file_path) @dynamic @inline
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

fn void RLMaterial.parse(&self, String file_path) @dynamic
{
/*
    // load test xml file
    String xml_path = local_game.app_base_folder.tconcat("images\\default.xml");
    File? xmlfile = io::file::open(xml_path, "r");
    defer xmlfile.close()!!;
    
    if(catch excuse = xmlfile) {
       log::raylibWarning("Failed to open test xml doc with excuse: %s", excuse);
    } else {
    
        XmlDoc* doc = xml::read_file(xmlfile)!!;
        defer doc.free();
        
        XmlNode material_node = doc.get_node("RLMaterial");
        
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
       log::warning(Where.FILE, " Failed to open material xml at [%s] with excuse: %s", file_path, excuse);
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
        log::error(Where.FILE, "Failed getting RLMaterial name from %s with excuse: %s\n", file_path, excuse);
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
                io::printf("RLMaterial %s attribute %s not found: %s\n", node.name, attribute_name, excuse);
                continue;
            }
            
            // TODO make sound shaders
            //self.sound = astmng::assetManager.getSound(sound_shader_name);
       }
    }
    /*
    
    mlNode node = doc.get_node("RLMaterial");
    
    ssert(node.name == "RLMaterial");
    
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


/***************************************************************
*
*                       RLSound RLShader
*
****************************************************************/
module game::assets::sndshd @private;

// region c3 modules
import std::io;
// end_region

// region user module
import thirdparty::raylib5::rl;
//import game::misc::hm;
import tiny::xml;
import game::main; // for file logging or console logging
import game::assets::astmng;
import std::collections::list, std::collections::map;
// end_region

alias Spawnarg             = game::StringTuple;
// global file sound list
alias SoundShaderList      = List{SoundShader*};
alias SoundShaderSoundList = List{sndshd::RLSound*};
// individual sound, sound list and spawnargs
alias SoundDefList         = List{SoundDef*};
alias SpawnargList         = List{Spawnarg*};

enum SoundKind : int {
    EFFECT,
    AMBIENT,
    VOICE,
    MUSIC
}

enum SoundFlags : int {
    GLOBAL,
    LOOP,
    NO_DUPS,
    NO_OCCLUSION,
    OMNIDIRECTIONAL,
    PRIVATE,
    SHAKES,
    UNCLAMPED,
    MASK_BACKLEFT, 
    MASK_BACKRIGHT, 
    MASK_BACKCENTER, 
    MASK_CENTER, 
    MASK_LEFT, 
    MASK_LFE, // subwoofer
    MASK_RIGHT, 
    FREQUENTLY_USED, 
    NO_RANDOM_START, 
    ON_DEMAND, 
    PLAY_ONCE
}

// This is the sndshd file itself
struct SoundShader
{
    String path;
    SoundShaderSoundList sounds;
}

fn void SoundShader.free(&self)
{
    if(self.sounds.len()) {
        foreach(sound : self.sounds) {
            sound.free();
            sound = null;
        }
        self.sounds.free();
    }
}

// this is the sound data/node inside each sound shader
struct RLSound (Printable) @public
{
    String name;
    String comment;
    SoundKind kind;
    
    // partner sound 
    SoundShader* altSound;
    
    int flags;
    
    // global spawnargs
    SpawnargList global_args;
    
    // list of real sounds defined for the RLSound
    SoundDefList sounds;
}

fn void RLSound.free_spawnargs(&self) @inline {
    foreach(it : self.global_args) {
        if(it) { mem::free(it); it = null; }
    }
}

fn void RLSound.free_sounds(&self) @inline {
    foreach(it : self.sounds) {
        if(it) { it.free(); it = null; }
    }
}

fn void RLSound.free(&self) {
    if(self.altSound) self.altSound = null;
    if(self.global_args.len()) {
        self.free_spawnargs();
    }
    if(self.sounds.len()) {
        self.free_sounds();
    }
}

struct SoundDef {
    String path;
    SpawnargList args;
    rl::RLSound* sound;
}

fn void SoundDef.free_spawnargs(&self) {
    foreach(it : self.args) {
        if(it) { mem::free(it); it = null; }
    }
}

fn void SoundDef.free(&self) {
    if(self.args.len()) {
        self.free_spawnargs();
    }
    if(self.sound) self.sound = null;
}

fn String RLSound.to_string(&self, Allocator allocator) @dynamic
{
	return string::format("%s", *self, allocator: allocator);
}


// TODO handle global args and each sound alias args seperatly
// This function should be only for global sound args 
fn void RLSound.setupFlags(&self) @inline
{
   foreach(spwarg : self.global_args) {
        switch(spwarg.first) {
            case "global": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.GLOBAL.ordinal;
                }
            case "looping": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.LOOP.ordinal;
                }
            case "no_dups": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.NO_DUPS.ordinal;
                }
            case "no_occlusion": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.NO_OCCLUSION.ordinal;
                }
            case "omnidirectional": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.OMNIDIRECTIONAL.ordinal;
                }
            case "private": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.PRIVATE.ordinal;
                }
            case "shakes": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.SHAKES.ordinal;
                }
            case "soundKind": // global
                switch(spwarg.second)
                {
                    case "VOICE":
                        self.kind = SoundKind.VOICE;
                    case "AMBIENT":
                        self.kind = SoundKind.AMBIENT;
                    case "MUSIC":
                        self.kind = SoundKind.MUSIC;
                    case "EFFECT":
                    default:
                        self.kind = SoundKind.EFFECT;
                }
            case "unclamped": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.UNCLAMPED.ordinal;
                }
            case "maxDistance": // global
                nextcase default;
                // TODO(HM):
                // The furthest you can get from the sound before it goes to zero volume 
                // maxDistance is the size of the physical sound entity times the volume amount;
            case "minDistance": // global
                nextcase default;
                // TODO(HM):
                // The closest you can get to the sound before it goes to full volume
                // minDistance = maxDistance minus minDistance times the max volume amount;
            case "mask_backleft":  // global
            case "mask_backright":  // global
            case "mask_backcenter":  // global
            case "mask_center":  // global
            case "mask_left":  // global
            case "mask_lfe":  // global
            case "mask_right": // global
                nextcase default;
            case "volume": // global
                float value = rl::textToFloat(spwarg.second.zstr_tcopy());
                foreach(sndDef : self.sounds) {
                    assert(sndDef.sound && rl::isSoundValid(*sndDef.sound));
                    bool volume_not_set = true;
                    // indivual sound volume overrides the global volume
                    foreach(arg : sndDef.args) {
                        if(arg.first == "volume") {
                            rl::setSoundVolume(self.sound, rl::textToFloat(arg.second.zstr_tcopy()));
                            volume_not_set = false;
                            break;
                        }
                    }
                    if(volume_not_set) rl::setSoundVolume(self.sound, value);
                }
            case "volumeDb": // global
                float db = rl::textToFloat(spwarg.second.zstr_tcopy());
                    
                float volume = @mapValueRangeToOther(db, -60.0f, 60.0f, 0.0f, 1.0f);
                //float volume = @clampfBinormalMapToRange(db, -60, 60);
                foreach(sndDef : self.sounds) {
                    assert(sndDef.sound && rl::isSoundValid(*sndDef.sound));
                    bool volume_not_set = true;
                    // indivual sound volume overrides the global volume
                    foreach(arg : sndDef.args) {
                        if(arg.first == "volume") {
                            rl::setSoundVolume(self.sound, rl::textToFloat(arg.second.zstr_tcopy()));
                            volume_not_set = false;
                            break;
                        }
                    }
                    if(volume_not_set) rl::setSoundVolume(self.sound, volume);
                }
            case "frequencyshift":
                // (1.0 is base level)
                assert(self.sound && rl::isSoundValid(*self.sound));
                float data, pitch;
                data = rl::textToFloat(spwarg.second.zstr_tcopy());
                if(data == 0.0f) break;
                if(data < -1.0) data = -1.0;
                if(data > 2.0)  data = 2.0f;
                if(data != 0.0f) rl::setSoundPitch(self.sound, pitch);
            case "frequentlyUsed": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.FREQUENTLY_USED.ordinal;
                }
            case "noRandomStart": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.NO_RANDOM_START.ordinal;
                }
            case "onDemand": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.ON_DEMAND.ordinal;
                }            
            case "playonce": // global
                if(spwarg.second == "1") {
                    self.flags |= SoundFlags.PLAY_ONCE.ordinal;
                }
            default:
                log::warning(Where.FILE, "Flag %s for SoundShader %s is still not finished!\n", spwarg.key, self.name);
        }
   }
}

fn void SoundShader.copy(&self, RLMaterial* other)
{

}

fn void SoundShader.update(&self)
{
    if(self.flags & SoundFlags.LOOP) {
        if(self.sounds.len()) {
            bool has_various_sounds = self.sounds.len() > 1;
            if(has_various_sounds) {
                foreach(i, snd : self.sounds) {
                    if(snd.sound == null) {
                        log::warning(Where.FILE, "Trying to play sound [%s] from SoundShader %s but has no sound to play!\n", i, self.name);
                        continue;
                    }
                    if(snd.spawnargs.len()) {
                        snd.free_spawnargs();
                    }
                }
            } else {
                shdshd::RLSound* snd = &self.sounds[0];
                if(snd.sound == null) log::warning(Where.FILE, "Trying to play SoundShader %s but has no sounds to play!\n", self.name);
            }
            
        } else {
            log::warning(Where.FILE, "Empty SoundShader %s found!\n", self.name);
        }
        //rl::playSound
    }
}

fn void SoundShader.playSound(&self, String sound_name)
{
    bool has_various_sounds = self.sounds.len() > 1;
    
   
}

fn void SoundShader.playSoundOneShot(&self, String sound_name)
{

}

fn void? loadSoundShaderRecursively(String basepath, String parent_folder = "") @local 
{
	String search_path = basepath;
	if(parent_folder != "") {
		if (parent_folder.ends_with("\\")) {
			search_path = parent_folder.tconcat(basepath).tconcat("\\");
		} else {
			search_path = parent_folder.tconcat("\\").tconcat(basepath).tconcat("\\");
		}
	}
	
	PathList! paths = path::temp_ls(path::temp_new(search_path));
	if(catch excuse = paths) {
		log::warning(Where.FILE, "Unable to get files from folder: %s with excuse: %s", search_path, excuse);
		return AssetError.FOLDER_SCAN_ERROR~;
	}
	
	foreach(path: paths)
	{
		ZString zpath = search_path.tconcat(path.str_view()).zstr_tcopy();
		bool isFile = rl::isPathFile(zpath);

		if(isFile) { // try to load it
			ZString file_name = rl::getFileNameWithoutExt(zpath);
			// ignore default assets those are handled directly
			//if (file_name.str_view() == "default") continue; // to next file
			
			String extension = rl::getFileExtension(zpath).str_view();
			bool valid_file  = extension == ".sndshd";
			if(valid_file == false) {
				continue; // to next file
			}
			
			// from here should be a valid file
			
			String sound_shader_path = search_path;
			if (sound_shader_path.ends_with("\\")) {
				sound_shader_path = sound_shader_path.tconcat(path.str_view());
			} else {
				sound_shader_path = sound_shader_path.tconcat("\\").tconcat(path.str_view());
			}
			
            SoundShader* new_sound_shader = mem::new(SoundShader);
            new_sound_shader.path = asset_path;
			new_sound_shader.load();
			continue; // to next file
			
		} else { // is a child folder/Directory
			loadSoundShaderRecursively(path.str_view(), search_path)!;
		}
	}
}

<*
*
* DOC: In here we create and setup each sound definition inside a sound shader file;
*
 @param in node "current node to populate with data"
 @require node != null
*>
fn void parse(XmlNode* node, SoundShader* shader) {
    shdshd::RLSound* sound = mem::new(shdshd::RLSound);
    defer shader.sounds.push(sound);
    
    sound.name = node.get_attrib_value("name");
    
    XmlNode* comment_node = node.findNextChild("comment");
    if(comment_node) self.comment = comment_node.value;
    
    XmlNode* altSound_node = node.findNextChild("altSound");
    if(altSound_node) {
        foreach(it : sndshd_list) {
            if(it.name == altSound_node.attributes[0].name) {
                self.altSound = &it;
            }
        }
    }
    
    XmlNode* spawnargs_node = node.findNextChild("spawnargs");
    if(spawnargs_node) {
        foreach(it : spawnargs_node.attributes) {
            if(it) {
                SPAWNARG* spawnarg = mem::new(SPAWNARG);
                spawnarg.key   = it.key;
                spawnarg.value = it.value;
                sound.spawnargs.push(spawnarg);
            }
        }
    }
    
    XmlNodeList sound_defs;
    defer sound_defs.free();
    
    node.find_nodes_by_tag_name("sound", &sound_defs);
    assert(sound_defs.len() > 0);
    
    foreach (s_node : sound_defs) {
        SoundDef* sound_def = mem::new(SoundDef);
        sound_def.path    = s_node.get_attrib_value("name")!!;
        String sound_path = s_node.get_attrib_value("path")!!;
        sound_def.sound   = astmng::getSound(sound_path.extractFileBaseByCopy());
        foreach(it : s_node.attributes) {
            if(it && it.key != "path") {
                SPAWNARG* spawnarg = mem::new(SPAWNARG);
                spawnarg.key   = it.key;
                spawnarg.value = it.value;
                sound_def.spawnargs.push(spawnarg);
            }
        }
        sound.sounds.push(sound_def);
    }
    
    sound.setupflags();
}

fn void SoundShader.load(&self)
{
    bool sucess;
    
    // load xml file
    File? file = io::file::open(self.path, "r");
    defer file.close()!!;
    
    if(catch excuse = file) {
       log::warning(Where.FILE, " Failed to open [%s] with excuse: %s", self.path, excuse);
       // DOC(HM) I need to return from a catch or the excuse will not unwrap,
       // and causes variable shadow error, preventing me from using excuse again bellow.
       return; 
    }
    
    XmlDoc*! doc = xml::read_file(file);
    defer doc.free();
    
    if(catch excuse = doc) {
       log::warning(Where.FILE, " Failed to read xml from [%s] with excuse: %s", self.path, excuse);
       return; 
    }
    
    // from here everything should be fine... i hope
    assert(doc != null);
       
    XmlNodeList soundNodes;
    defer soundNodes.free();
   
    doc.find_nodes_by_tag_name("SOUND", &soundNodes);
    
    if (soundNodes.len() <= 0) {
        log::warning(Where.FILE, "Failed getting sound nodes from %s with excuse: %s\n", self.path, excuse);
        return;
    }
    
    // else create the sound nodes
    foreach (node : soundNodes) {
        parse(node, self);
    }
    
    
    
    String! id = (String)main_node.get_attrib_value("name");
    if (catch excuse = id) {
        log::error(Where.FILE, "Failed getting RLMaterial name from %s with excuse: %s\n", self.path, excuse);
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
                io::printf("RLMaterial %s attribute %s not found: %s\n", node.name, attribute_name, excuse);
                continue;
            }
            
            // TODO make sound shaders
            //self.sound = astmng::assetManager.getSound(sound_shader_name);
       }
    }
    
    if(sucess) sndshd_list.push(self);
}


struct SoundShaderManager @local {
    SoundShaderList snd_shader_list;
}

SoundShaderManager local_manager @local;
SoundShaderManager* mng = &local_manager;

fn void SoundShaderManager.free(&self) {
    foreach(snd_shader : self.snd_shader_list) {
        snd_shader.free();
    }
}

fn void SoundShaderManager.update(&self) {
    foreach(snd_shader : self.snd_shader_list) {
        snd_shader.update();
    }
}
