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

// Sound System - Ignore UNFINISHED

module engine::sys::sndsys;

// region modules
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
import engine::misc;
import game::main;
//import game::assets::sprt; // sprite
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import engine::assets_api::asset; // for the asset system
import engine::assets_api::astmng; // asset manager
//import raygui5::rgui;
//import thirdparty::raylib5::rmath;
//import game::serialize::svs; // save system
import engine::logging::log;
// end_region

// SSMusic management functions
/*
// Checks if a music stream is valid (context and buffers initialized)
    fn bool isMusicValid(SSMusic music)
// Load music stream from file
    fn SSMusic loadMusicStream(ZString fileName)
// Load music stream from data
    fn SSMusic loadMusicStreamFromMemory(ZString fileType, char* data, int dataSize) 
// Unload music stream
    fn void unloadMusicStream(SSMusic music) 
// Start music playing
    fn void playMusicStream(SSMusic music) 
// Check if music is playing
    fn bool isMusicStreamPlaying(SSMusic music) 
// Updates buffers for music streaming
    fn void updateMusicStream(SSMusic music) 
// Stop music playing
    fn void stopMusicStream(SSMusic music) 
// Pause music playing
    fn void pauseMusicStream(SSMusic music) 
// Resume playing paused music
    fn void resumeMusicStream(SSMusic music) 
// Seek music to a position (in seconds)
    fn void seekMusicStream(SSMusic music, float position) 
// Set volume for music (1.0 is max level)
    fn void setMusicVolume(SSMusic music, float volume) 
// Set pitch for a music (1.0 is base level)
    fn void setMusicPitch(SSMusic music, float pitch) 
// Set pan for a music (0.5 is center)
    fn void setMusicPan(SSMusic music, float pan) 
// Get music time length (in seconds)
    fn float getMusicTimeLength(SSMusic music) 
// Get current music time played (in seconds)
    fn float getMusicTimePlayed(SSMusic music) 
*/

struct SSWave 
{
	inline RLWave super;
	String name;
}

alias SSMusicDatabase = List{Asset{RLMusic}*};
alias SSSoundDatabase = List{Asset{RLSound}*};
alias SSWavDatabase = List{SSWave*};

alias SSSoundWorlds = List{SoundWorld*};
SSSoundWorlds sound_worlds;

struct SoundWorld 
{
	String name;
	SSMusicDatabase music;
	SSSoundDatabase sounds;
	SSWavDatabase waves;
	// placeholder for future sound world data
}

fn void SoundWorld.addMusic(&self, Asset{RLMusic}* music_asset) @extern("addMusic")
{
	self.music.push(music_asset);
}

fn void SoundWorld.addSound(&self, Asset{RLSound}* sound_asset) @extern("addSound")
{
	self.sounds.push(sound_asset);
}

fn void SoundWorld.addWave(&self, SSWave* wave_ptr) @extern("addWave")
{
	self.waves.push(wave_ptr);
}

// getters
fn Asset{RLMusic}* SoundWorld.getMusicByName(&self, String music) @nodiscard @extern("getMusicByName")
{
	foreach(music_asset : self.music) {
		if(music_asset.name == music) {
			return music_asset;
		}
	}
	return null;
}

fn Asset{RLSound}* SoundWorld.getSoundByName(&self, String sound) @nodiscard @extern("getSoundByName")
{
	foreach(sound_asset : self.sounds) {
		if(sound_asset.name == sound) {
			return sound_asset;
		}
	}
	return null;
}

fn RLWave* SoundWorld.getWaveByName(&self, String wave_name) @nodiscard @extern("getWaveByName")
{
	foreach(wave_ptr : self.waves) {
		if(wave_ptr.name == wave_name) {
			return wave_ptr;
		}
	}
	return null;
}

fn void SoundWorld.removeMusic(&self, Asset{RLMusic}* music_asset) @extern("removeMusic")
{
	self.music.remove_item(music_asset);
}

fn void SoundWorld.removeSound(&self, Asset{RLSound}* sound_asset) @extern("removeSound")
{
	self.sounds.remove_item(sound_asset);
}

fn void SoundWorld.removeWave(&self, SSWave* wave_ptr) @extern("removeWave")
{
	wave_ptr.name = ""; // clear name for safety
	rl::unloadWave(wave_ptr.super); // unload the wave data
	mem::free(wave_ptr); // free the wave struct
	self.waves.remove_item(wave_ptr);
}

fn void SoundWorld.clearMusic(&self) @extern("clearMusic")
{
	self.music.clear();
}

fn void SoundWorld.clearSounds(&self) @extern("clearSounds")
{
	self.sounds.clear();
}

fn void SoundWorld.clearWaves(&self) @extern("clearWaves")
{
	self.waves.clear();
}

fn void SoundWorld.clearAll(&self) @extern("clearAll")
{
	self.music.clear();
	self.sounds.clear();
	self.waves.clear();
}

fn void SoundWorld.playMusic(&self, Asset{RLMusic}* music_asset) @extern("playMusic")
{
	if(rl::isMusicValid(music_asset.data)) {
		if(!rl::isMusicStreamPlaying(music_asset.data)) {
			rl::playMusicStream(music_asset.data);
		}
	}
}

fn void SoundWorld.playMusicByName(&self, String music_name) @extern("playMusicByName")
{
	foreach(music_asset : self.music) {
		if(music_asset.name == music_name) {
			self.playMusic(music_asset);
			return;
		}
	}
}

fn void SoundWorld.resumeMusic(&self, Asset{RLMusic}* music_asset) @extern("resumeMusic")
{
	if(!rl::isMusicStreamPlaying(music_asset.data)) {
		rl::resumeMusicStream(music_asset.data);
	}
}

fn void SoundWorld.pauseMusic(&self, Asset{RLMusic}* music_asset) @extern("pauseMusic")
{
	if(rl::isMusicStreamPlaying(music_asset.data)) {
		rl::pauseMusicStream(music_asset.data);
	}
}

fn void SoundWorld.stopMusic(&self, Asset{RLMusic}* music_asset) @extern("stopMusic")
{
	if(rl::isMusicStreamPlaying(music_asset.data)) {
		rl::stopMusicStream(music_asset.data);
	}
}

////////////////////////////////////////////////////////////////////////
////////////////// Sound World Management Functions //////////////////

<*
 @param [&in] sw : "sound world to register"
*>
fn void registerSoundWorld(SoundWorld* sw) @extern("registerSoundWorld")
{
	sound_worlds.push(sw);
}

fn SoundWorld* createSoundWorld(String name) @extern("createSoundWorld")
{
	SoundWorld* sw = mem::new(SoundWorld);
	sw.name = name.tcopy();
	return sw;
}

fn void destroySoundWorld(SoundWorld* sw) @extern("destroySoundWorld")
{
	// unload all music
	foreach(music_asset : sw.music) {
		rl::unloadMusicStream(music_asset.data);
		mem::free(music_asset);
	}
	sw.music.clear();
	
	// unload all sounds
	foreach(sound_asset : sw.sounds) {
		rl::unloadSound(sound_asset.data);
		mem::free(sound_asset);
	}
	sw.sounds.clear();
	
	// unload all waves
	foreach(wave_ptr : sw.waves) {
		rl::unloadWave(*wave_ptr);
		mem::free(wave_ptr);
	}
	sw.waves.clear();
	
	mem::free(sw);
}

fn void updateSoundWorld(SoundWorld* sw) @extern("updateSoundWorld")
{
	// update all music streams
	foreach(music_asset : sw.music) {
		rl::updateMusicStream(music_asset.data);
	}
	// no need to update sounds or waves
}

fn void silenceSoundWorld(SoundWorld* sw) @extern("silenceSoundWorld")
{
	// stop all music streams
	foreach(music_asset : sw.music) {
		rl::stopMusicStream(music_asset.data);
	}
	// stop all sounds
	foreach(sound_asset : sw.sounds) {
		rl::stopSound(sound_asset.data);
	}
	// no need to stop waves
}

fn void silenceSoundWorldByName(String name) @extern("silenceSoundWorldByName")
{
	foreach(sw : sound_worlds) {
		if(sw.name == name) {
			silenceSoundWorld(sw);
			return;
		}
	}
}

fn void init() {
    rl::initAudioDevice();
}

/*
fn bool? populateMusicDataBase() {
    String music_folder = game::gpGame.app_base_folder.tconcat("\\").tconcat("music\\");
	PathList? paths = path::ls(tmem, path::temp(music_folder));
	if(catch excuse = paths) {
		log::warning(Where.FILE,  "Unable to get audio from folder music with excuse: %s", excuse);
		return astmng::FOLDER_SCAN_ERROR~;
	}
	
	foreach(path: paths)
	{
		String path_ = music_folder.tconcat(path.str_view());
		if(fs::isFile(path_)) { // try to load it
			String file_name = fs::getFileNameWithoutExt(path_);
			// ignore default assets those are handled directly
            // if (file_name.starts_with("default_")) {
                // continue; // to next file
            // }
			//if (file_name == "default") continue; // to next file
			
			String extension = fs::getFileExtension(path_);
            if(extension != ".mp3" && extension != ".ogg") {
                log::warning(Where.FILE, "Non valid audio \"%s\" inside music folder.", file_name);
                continue; // to next file
            }
			
			// from here should be a valid audio file
			String asset_path;
            bool mp3file;
            mp3file = (extension == ".mp3");
            if(mp3file) {
                asset_path = music_folder.tconcat(file_name).tconcat(".mp3");
            } else {
                assert(extension == ".ogg");
                asset_path = music_folder.tconcat(file_name).tconcat(".ogg");
            }
            
            sndsys::SSMusic* music = mem::new(sndsys::SSMusic);
			
			music.stream = rl::loadMusicStream(asset_path.zstr_tcopy());
            music_data.push(music);
			continue; // to next file
			
		} else { // is a child folder/Directory
			//loadAssetsRecursively(path.str_view(), search_path)!;
		}
	}
    
    return false;
}

struct SSMusic {
    RLMusic stream;
    float timePlayed;  // Time played normalized [0.0f..1.0f]
    bool pause;
}

<*
 @param [&in] music : "music to stop"
*>
fn void stopMusic(SSMusic* music) {
    rl::stopMusicStream(music.stream);
}

<*
 @param [&in] music : "music to play"
*>
fn void playMusic(SSMusic* music) {
    rl::playMusicStream(music.stream);
}

<*
 @param [&in] music : "music to restart"
*>
fn void restartMusic(SSMusic* music) {
    stopMusic(music);
    playMusic(music);
}

<*
 @param [&in] music : "music to pause"
*>
fn void pauseMusic(SSMusic* music) {
    rl::pauseMusicStream(music.stream);
}

<*
 @param [&in] music : "music to resume"
*>
fn void resumeMusic(SSMusic* music) {
    rl::resumeMusicStream(music.stream);
}

