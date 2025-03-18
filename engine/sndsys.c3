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

module engine::soundsystem::sndsys;

// region modules
import std::io;
import std::core::mem; // for malloc/new
import std::math;
import std::collections::list;
import engine::misc;
import engine::assets::astmng;
import game::main;
import game::assets::sprt; // sprite
import engine::filesystem::fs;
import raylib5::rl;
//import raygui5::rgui;
import raylib5::rmath;
import game::serialize::svs; // save system
import engine::logging::lgr;
// end_region

// Music management functions
/*
// Checks if a music stream is valid (context and buffers initialized)
    fn bool isMusicValid(Music music)
// Load music stream from file
    fn Music loadMusicStream(ZString fileName)
// Load music stream from data
    fn Music loadMusicStreamFromMemory(ZString fileType, char* data, int dataSize) 
// Unload music stream
    fn void unloadMusicStream(Music music) 
// Start music playing
    fn void playMusicStream(Music music) 
// Check if music is playing
    fn bool isMusicStreamPlaying(Music music) 
// Updates buffers for music streaming
    fn void updateMusicStream(Music music) 
// Stop music playing
    fn void stopMusicStream(Music music) 
// Pause music playing
    fn void pauseMusicStream(Music music) 
// Resume playing paused music
    fn void resumeMusicStream(Music music) 
// Seek music to a position (in seconds)
    fn void seekMusicStream(Music music, float position) 
// Set volume for music (1.0 is max level)
    fn void setMusicVolume(Music music, float volume) 
// Set pitch for a music (1.0 is base level)
    fn void setMusicPitch(Music music, float pitch) 
// Set pan for a music (0.5 is center)
    fn void setMusicPan(Music music, float pan) 
// Get music time length (in seconds)
    fn float getMusicTimeLength(Music music) 
// Get current music time played (in seconds)
    fn float getMusicTimePlayed(Music music) 
*/

def MusicDatabase = List(<sndsys::Music*>);
MusicDatabase music_data;

fn void init() {
    rl::initAudioDevice();
}

def SndSysError = astmng::AssetError;

fn bool! populateMusicDataBase() {
    String music_folder = main::gpGame.app_base_folder.tconcat("\\").tconcat("music\\");
	PathList! paths = path::temp_ls(path::temp_new(music_folder));
	if(catch excuse = paths) {
		lgr::warning(Where.FILE,  "Unable to get audio from folder music with excuse: %s", excuse);
		return SndSysError.FOLDER_SCAN_ERROR?;
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
            if(extension != ".mp3" && entension != ".ogg") {
                lgr::warning(Where.FILE, "Non valid audio \"%s\" inside music folder.", file_name);
                continue; // to next file
            }
			
			// from here should be a valid audio file
			String asset_path;
            bool mp3file;
            mapfile = extension == ".mp3";
            if(mp3file) {
                asset_path = music_folder.tconcat(file_name).tconcat(".mp3");
            } else {
                assert(entension == ".ogg");
                asset_path = music_folder.tconcat(file_name).tconcat(".ogg");
            }
            
            sndsys::Music* music = mem::new(sndsys::Music);
			
			music.stream = rl::loadMusicStream(asset_path);
            music_data.push(music);
			continue; // to next file
			
		} else { // is a child folder/Directory
			loadAssetsRecursively(path.str_view(), search_path)!;
		}
	}
}

fn void update() {
    if(music_data.len) {
        foreach(music, music_data) {
           rl::updateMusicStream(music.stream);
        }
    }
}

struct Music {
    rl::Music stream;
    float timePlayed;  // Time played normalized [0.0f..1.0f]
    bool pause;
}

<*
* @param in stream "music stream to stop"
* @require stream != null
*>
fn void stopMusic(Music* stream) {
    rl::stopMusicStream(*stream);
}

<*
* @param in stream "music stream to play"
* @require stream != null
*>
fn void playMusic(Music* stream) {
    rl::playMusicStream(*stream);
}

<*
* @param in stream "music stream to restart"
* @require stream != null
*>
fn void restartMusic(Music* stream) {
    stopMusic(music);
    playMusic(music);
}

<*
* @param in stream "music stream to pause"
* @require stream != null
*>
fn void pauseMusic(Music* stream) {
    rl::pauseMusicStream(*stream);
}

<*
* @param in stream "music stream to resume"
* @require stream != null
*>
fn void resumeMusic(Music* stream) {
    rl::resumeMusicStream(*stream);
}

