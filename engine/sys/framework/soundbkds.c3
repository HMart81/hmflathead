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
/* UNFINISHED BACKEND INTERFACE */

module engine::sys::framework::soundbkd @private;

import std::io, std::os::win32;
import std::collections::list;
import game::main;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import engine::assets_api::astmng;
import thirdparty::raylib5::rl;
import thirdparty::plmpeg::plm; // for plm::PLM_AUDIO_SAMPLES_PER_FRAME

// signture = fn void(void* bufferdata, CUInt frames);
alias HMAudioCallback = rl::AudioCallback;

// *************** AUDIO DEVICE *********************
// Just a way to handle the sound device as a "thing"
// instead of lose functions... 
// **************************************************
fn void initAudioDevice() @inline
{
	rl::initAudioDevice();
	rl::setAudioStreamBufferSizeDefault(4096);
}
fn void closeAudioDevice() @inline => rl::closeAudioDevice();
fn bool isAudioDeviceReady() @inline => rl::isAudioDeviceReady();
// Set master volume (listener)
fn void setMasterVolume(float volume) @inline => rl::setMasterVolume(volume);
// Get master volume (listener)
fn float getMasterVolume() @inline => rl::getMasterVolume();

// Audio device Object
typedef AudioDevice @public = void*;

<*
	@require rl::isWindowReady() == true
*>
fn void AudioDevice.init(self) @inline => initAudioDevice();
fn void AudioDevice.close(self) @inline => closeAudioDevice();
fn bool AudioDevice.isReady(self) @inline => isAudioDeviceReady();

const SOUND_MAX_VOLUME @local = 6.0f;
<*
    Sets the volume globably for the main listener not each sound.
    @param volume : "volume is a value from 0.0 to SOUND_MAX_VOLUME, 1.0 is the default"
    @require volume <= SOUND_MAX_VOLUME : "a limit to prevent damaging hears and the sound hardware"
    @require self.isReady()
*>
fn void AudioDevice.setVolume(self, float volume = 1.0f) @inline
{
    if(volume < 0.0f) volume = 0.0f;
    setMasterVolume(volume);
}

<*
    Mutes the entire sound system
    @require self.isReady()
*>
fn void AudioDevice.mute(self) @inline
{
	self.setVolume(0.0f);
}

<*
    unmutes the entire sound system
    @require self.isReady()
*>
fn void AudioDevice.unmute(self) @inline
{
	self.setVolume(1.0f);
}

<*
    Gets the mute state from the sound system
    @require self.isReady()
*>
fn bool AudioDevice.isSilent(self) @inline
{
	return (self.getVolume() == 0.0f);
}

<*
    @require self.isReady()
*>
fn float AudioDevice.getVolume(self) @inline => getMasterVolume();

<*
    Gets the count of current sounds playing by the audio device,
    this is seperate from the total sounds playing, per soundworld.
    @require self.isReady()
*>
fn float AudioDevice.getSoundsPlaying(self) @inline => rl::getSoundsPlaying();


// *************** Sound Data ***********************
// a wrapper around RLSound just a way to give raylib 
// sounds some more data and controls
// **************************************************

// dedicated folders inside the game data base folder
// sounds and music are retrieved using a relative path
// in relation to the respective folders defined here.
const SOUNDS_FOLDER = "sounds\\";
const MUSIC_FOLDER  = "music\\";

constdef SoundChannels
{
	MONO = 1,
	STEREO,
	FIVE_DOT_1  @if($defined(MULTI_CHANNEL_AUDIO)),
	SIX_DOT_1   @if($defined(MULTI_CHANNEL_AUDIO)),
	SEVEN_DOT_1  @if($defined(MULTI_CHANNEL_AUDIO))
}

constdef SoundType
{
	WAVE = 0,
	OGG,
	MP3,
	FLAC
}

struct HMSound @public 
{
	inline RLSound super; // less than 10 seconds sounds
    Path path;
	String name;
    int id;
	float volume;
	// flags
    bool paused;
}

fn bool HMSound.isValid(self) @inline
{
	return rl::isSoundValid(self.super) && ((self.path.len & self.id) != 0);
}

// Extension will be included in the name.
fn void HMSound.setName(&self) @inline
{
	// should I remove extension?
	// what if I have to sounds with the same name but
	// diferent extensions?
	// Right now I will not remove the extension as is
	// a way to diferentiate sounds
	self.name = self.path.basename();
}

fn SoundType HMSound.type(&self) @inline
{
	switch
	{
		case self.path.has_extension(".wav"):
			return WAVE;
		case self.path.has_extension(".ogg"):
			return OGG;
		case self.path.has_extension(".mp3"):
			return MP3;
		case self.path.has_extension(".flac"):
			return FLAC;
		default: unreachable();
	}
}

<*
    @param [in] relative_path : "a relative path from within Sounds folder to the wanted sound"
	@require relative_path.len > 0
	@require game::pContext.app_base_folder.len > 0
    @require game::pContext.audio_device.isReady()
    @ensure rl::isSoundValid(self.super)
*>
fn HMSound*? HMSound.load(&self, Path relative_path)
{
    { // unload previous sound
        if(rl::isSoundValid(self.super)) self.unload();
    }
    String sounds_folder = game::pContext.app_base_folder.tconcat(SOUNDS_FOLDER);
    self.path  = path::tnew(sounds_folder)!.tappend(relative_path).tcopy()!;
	// now load the real sound data using Raylib function and allocator
    self.super = rl::loadSound(self.path.zstr_tcopy());
	if(rl::isSoundValid(self.super))
	{
    	self.setVolume(1.0f);
	} 
	else
	{
		log::error(FILE, "Failed to load sound '%s' returning default sound instead!", self.name);
		self.super = game::pContext.default_sound;
	}
    return self;
}

fn void HMSound.unload(&self) @inline
{
	if(self.isPlaying()) self.stop();
	rl::unloadSound(self.super);
}

fn void HMSound.setVolume(&self, float volume) @inline
{
	if(volume < 0) volume = 0.0f;
	self.volume = volume;
	if(volume > 1.5f) {
		log::warning(FILE, "Volume of Sound '%s' was set to '%d' past default '1.0f' this may be harmfull.", self.name, volume);
	}
	rl::setSoundVolume(self.super, volume);  // Set volume for a sound (0.0 to 1.0)
}

fn float HMSound.getVolume(&self) @inline => self.volume;
fn void HMSound.setPitch(&self, float pitch) @inline => rl::setSoundPitch(self.super, pitch);   // Set pitch for a sound (1.0 = normal)
fn void HMSound.setPan(&self, float pan) @inline => rl::setSoundPan(self.super, pan);   // Set pan for a sound (0.0 = left, 0.5 = center, 1.0 = right)
fn bool HMSound.isPlaying(&self) @inline => rl::isSoundPlaying(self.super);
fn void HMSound.play(&self) @inline => rl::playSound(self.super);
fn void HMSound.stop(&self) @inline
{
    rl::stopSound(self.super);
}

fn void HMSound.update(&self)
{
    // does nothing for now
}

fn void HMSound.pause(&self) @inline 
{
    rl::pauseSound(self.super);
    self.paused = true;
}

fn void HMSound.resume(&self) @inline
{
    rl::resumeSound(self.super);
    self.paused = false;
}


// *************** Music data *********************
// a wrapper around RLMusic just a way to give raylib 
// music streams some more id data
// **************************************************
struct HMMusic @public 
{
	inline RLMusic super; // sounds larger than 10 seconds
    Path path;
	String name;
    int id;
	float volume;
    bool paused;
}

fn void HMMusic.unload(&self) @inline
{
	if(self.isPlaying()) self.stop();
	rl::unloadMusicStream(self.super);
}

// Extension will be included in the name.
fn void HMMusic.setName(&self) @inline
{
	self.name = self.path.basename();
}

fn SoundType HMMusic.type(&self) @inline
{
	switch
	{
		case self.super.ctxType == RLMusicCtxType.OGG.ordinal:
			return OGG;
		case self.super.ctxType == RLMusicCtxType.MP3.ordinal:
			return MP3;
		case self.super.ctxType == RLMusicCtxType.FLAC.ordinal:
			return FLAC;
		case self.super.ctxType == RLMusicCtxType.NONE.ordinal:
		case self.super.ctxType == RLMusicCtxType.WAV.ordinal:
		case self.super.ctxType == RLMusicCtxType.QOA.ordinal:
		case self.super.ctxType == RLMusicCtxType.XM.ordinal:
		case self.super.ctxType == RLMusicCtxType.MOD.ordinal:
		default: unreachable();
	}
}

fn void HMMusic.play(&self)      => rl::playMusicStream(self.super);
fn bool HMMusic.isPlaying(&self) => rl::isMusicStreamPlaying(self.super);
fn void HMMusic.update(&self)    => rl::updateMusicStream(self.super);
fn void HMMusic.stop(&self)      => rl::stopMusicStream(self.super);

fn void HMMusic.pause(&self)
{
    rl::pauseMusicStream(self.super);
    self.paused = true;
}

fn void HMMusic.resume(&self)
{
    rl::resumeMusicStream(self.super);
    self.paused = false;
}

fn void HMMusic.seek(&self, float position) => rl::seekMusicStream(self.super, position);

fn void HMMusic.setVolume(&self, float volume) @inline
{
	if(volume < 0) volume = 0.0f;
	self.volume = volume;
	if(volume > 1.5f) {
		log::warning(FILE, "Volume of Music '%s' was set to '%d' past default '1.0f' this may be harmfull.", self.name, volume);
	}
	rl::setMusicVolume(self.super, volume);  // Set volume for a sound (0.0 to 1.0)
}

fn float HMMusic.getVolume(&self) @inline => self.volume;

fn void HMMusic.setPitch(&self, float pitch) => rl::setMusicPitch(self.super, pitch);
fn void HMMusic.setPan(&self, float pan)     => rl::setMusicPan(self.super, pan);
fn float HMMusic.getTimeLength(&self)        => rl::getMusicTimeLength(self.super);
fn float HMMusic.getTimePlayed(&self)        => rl::getMusicTimePlayed(self.super);

<*
    @param [in] relative_path : "a relative path from the sounds folder to the music"
	@require relative_path.len > 0
	@require game::pContext.app_base_folder.len > 0
	@require game::pContext.audio_device.isReady()
    @ensure rl::isMusicValid(self.super)
*>
fn HMMusic*? HMMusic.load(&self, Path relative_path)
{
    { // when loading a new music, unload previous music if it exists
        if(rl::isMusicValid(self.super)) rl::unloadMusicStream(self.super);
    }
    String musics_folder  = game::pContext.app_base_folder.tconcat(MUSIC_FOLDER);
    self.path  = path::tnew(musics_folder)!.tappend(relative_path).tcopy()!;
    // now load the real music data using Raylib function
	self.super = rl::loadMusicStream(self.path.zstr_tcopy());
	if(rl::isMusicValid(self.super))
	{
    	self.setVolume(1.0f);
	}
	else
	{
		log::error(FILE, "Failed to load music '%s'! returning default music.", self.name);
		self.super = game::pContext.default_music;
	}
    return self;
}

/******************************************************************************************
**                                                                                       **
**                      Sound Backend interface                                          **
**                                                                                       **
******************************************************************************************/

const MAX_SOUND_WORLD_PLAYING_SOUNDS = 64;
// todo should I have a max limit of sounds playing or not, in a sound world?

const usz SOUND_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator soundArena;

interface SoundWorldBackend
{
    fn void	init(String);
    fn int?	addSound(Path);
    fn int?	addMusic(Path);
    fn void update();
    fn void pause();
	fn void playSound(String, bool);
	fn HMSound* getSound(int);
	fn HMSound* getSoundByName(String);
	fn HMMusic* getMusic(int);
	fn HMMusic* getMusicByName(String);
    fn void	shutdown();
}

alias SoundList = List{HMSound*};
alias MusicList = List{HMMusic*};
alias AudioPlayingList = SoundList;

struct HMSoundWorld (SoundWorldBackend) @public
{
	String name;
	bool active;
	bool shutdown_done; // prevents double shutdown of the sound world by things that share the same one
    DynamicArenaAllocator mem_arena;
    SoundList sounds;
    MusicList musics;
}

<*
    @param [&inout] snd_world : "pointer to sound world to create the sound in"
*>
fn HMSound*? create_sound(HMSoundWorld* snd_world) @inline @local
{
    return alloc::new(&snd_world.mem_arena, HMSound);
}

<*
@param [&inout] snd_world : "pointer to sound world to create the music in"
*>
fn HMMusic* create_music(HMSoundWorld* snd_world) @inline @local
{
    return alloc::new(&snd_world.mem_arena, HMMusic);
}

<*
	@param [in] name : "name of the sound world"
*>
fn void HMSoundWorld.init(&self, String name) @dynamic
{
	// init sound world memory pool/arena
    self.name = name.tcopy();
    self.mem_arena.init(mem, SOUND_ARENA_PAGE_SIZE);
	self.sounds.init(&self.mem_arena);
	self.musics.init(&self.mem_arena);
}

fn void HMSoundWorld.shutdown(&self) @dynamic
{
	if(self.shutdown_done) return;
    foreach(sound : self.sounds) sound.unload();
    foreach(music : self.musics) music.unload();
    self.mem_arena.free();
	self.shutdown_done = true;
}

fn HMSoundWorld* HMSoundWorld.activate(&self)
{
    self.active = true;
	return self;
}

fn void HMSoundWorld.deactivate(&self)
{
    self.active = false;
}

fn bool HMSoundWorld.isActive(&self) @dynamic => self.active;

/*
	If passing null stop the current playing sound world.
*/
fn void setPlayingSoundWorld(HMSoundWorld* snd_world) @public
{
    if(snd_world == null)
	{
        HMSoundWorld* current_sound_world = game::pContext.current_sound_world;
        if(current_sound_world) current_sound_world.deactivate();
        return;
    }
    // else enable the sound world
    game::pContext.current_sound_world = snd_world.activate();
}

fn bool HMSoundWorld.hasSoundsPlaying(&self)
{
	foreach(sound : self.sounds)
	{
		if(sound.isPlaying())
		{
			return true;
		}
	}
	foreach(music : self.musics)
	{
		if(music.isPlaying())
		{
			return true;
		}
	}
	return false;
}

fn int HMSoundWorld.soundsPlayingCount(self)
{
	int result;
	foreach(sound : self.sounds)
	{
		if(sound.isPlaying())
		{
			result++;
		}
	}
	foreach(music : self.musics)
	{
		if(music.isPlaying())
		{
			result++;
		}
	}
	return result;
}

fn void HMSoundWorld.update(&self) @dynamic
{
    if(self.isActive()) 
    {
        foreach(sound : self.sounds)
		{
			sound.update();
		}
		foreach(music : self.musics)
		{
			music.update();
		}
    }
}

fn void HMSoundWorld.pause(&self) @dynamic
{
    if(self.isActive())
    {
        foreach(music : self.musics)
		{
		    if(music.isPlaying())
			{
                music.pause();
            }
	    }
        foreach(sound : self.sounds)
		{
		    if(sound.isPlaying())
			{
                sound.pause();
            }
	    }
        self.deactivate();
    }
}

fn void HMSoundWorld.unpause(&self) @dynamic
{
	if(!self.isActive())
    {
		self.activate();
	}

	foreach(music : self.musics)
	{
		bool paused = music.paused;
		if(!music.isPlaying() && paused)
		{
			music.resume();
		}
	}
	foreach(sound : self.sounds)
	{
		bool paused = sound.paused;
		if(!sound.isPlaying() && paused)
		{
			sound.resume();
		}
	}
}

fn void HMSoundWorld.stop(&self) @dynamic
{
    if(self.isActive())
    {
        self.deactivate();
        foreach(music : self.musics)
		{
		    if(music.isPlaying() || music.paused)
			{
                music.stop();
            }
	    }
        foreach(sound : self.sounds)
		{
		    if(sound.isPlaying() || sound.paused)
			{
                sound.stop();
            }
	    }
    }
}

<*
    @param [in] relative_path : "relative path to sound to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? HMSoundWorld.addSound(&self, Path relative_path) @dynamic
{
    // create a new speaker
    HMSound* sound = create_sound(self)!;
    sound.load(relative_path)!;
    sound.id = (int)self.sounds.len() + 1;
    self.sounds.push(sound);
    return sound.id;
}

<*
    @param [&inout] sndwld : "sound world to add sound to"
    @param [in] relative_path : "relative path to sound to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? addSoundTo(HMSoundWorld* sndwld, Path relative_path) @public
{
    return sndwld.addSound(relative_path);
}

<*
    @param [in] relative_path : "relative path to music to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? HMSoundWorld.addMusic(&self, Path relative_path) @dynamic
{
    HMMusic* music = create_music(self);
    music.load(relative_path)!;
    music.id = (int)self.musics.len() + 1;
    self.musics.push(music);
    return music.id;
}

<*
    @param [&inout] sndwld : "sound world to add music to"
    @param [in] relative_path : "relative path to music to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? addMusicTo(HMSoundWorld* sndwld, Path relative_path) @public
{
    return sndwld.addMusic(relative_path)!;
}

<*
    @param id : "id of sound emitter"
	@require id >= 1
    @ensure return != null
*>
fn HMSound* HMSoundWorld.getSound(&self, int id) @dynamic
{
    return self.sounds[--id];
}

<*
    @param id : "id of music emitter"
    @require id >= 1
    @ensure return != null
*>
fn HMMusic* HMSoundWorld.getMusic(&self, int id) @dynamic
{
   return self.musics[--id];
}

<*
    @param [in] name : "the name of the sound you want to get extension included"
    @require name.len > 0
*>
fn HMSound* HMSoundWorld.getSoundByName(&self, String name) @dynamic
{
    foreach(sound : self.sounds)
	{
		if(sound.name == name) return sound;
	}
    return null;
}

<*
    @param [in] name : "the name of the music you want to get extension included"
    @require name.len > 0
*>
fn HMMusic* HMSoundWorld.getMusicByName(&self, String name) @dynamic
{
    foreach(music : self.musics)
	{
		if(music.name == name) return music;
	}
    return null;
}

fn void HMSoundWorld.playSound(&self, String name, bool is_music = false) @dynamic
{
	if(self.soundsPlayingCount() >= 64)
	{
		log::warning(FILE, "Cannot play more sounds on '%s' because max capacity was reached!", self.name);
		return;
	}

    if(is_music)
	{
        foreach(music : self.musics)
		{
            if(music.name == name)
			{
                if(!music.isPlaying())
				{
                    music.play();
                    break;
                }
            }
        }
    } 
    else
    {
        foreach(sound : self.sounds)
		{
            if(sound.name == name)
			{
                sound.play();
                break;
            }
        }
    }
}

fn void HMSoundWorld.stopSound(&self, String name, bool is_music = false) @dynamic
{
    if(self.soundsPlayingCount() <= 0)
	{
		return;
	}

    if(is_music)
    {
        foreach(i, music : self.musics)
        {
            if(music.name == name)
            {
                music.stop();
                break;
            }
        }
    }
    else
    {
        foreach(i, sound : self.sounds)
        {
            if(sound.name == name)
            {
                sound.stop();
                break;
            }
        }
    }
}

fn void HMSoundWorld.pauseSound(&self, String name, bool is_music = false) @dynamic
{
	if(self.soundsPlayingCount() <= 0)
	{
		return;
	}

    if(is_music)
    {
        foreach(music : self.musics)
        {
            if(music.name == name)
            {
                if(!music.isPlaying())
                {
                    return;
                }
                music.pause();
                return;
            }
        }
    }
    else
    {
        foreach(sound : self.sounds)
        {
            if(sound.name == name)
            {
                if(!sound.isPlaying())
                {
                    return;
                }
                sound.pause();
                return;
            }
        }
    }
}

fn void HMSoundWorld.resumeSound(&self, String name, bool is_music = false) @dynamic
{
    if(is_music)
    {
        foreach(music : self.musics)
        {
            if(music.name == name)
            {
                if(music.isPlaying())
                {
                    return;
                }
                music.resume();
                return;
            }
        }
    }
    else
    {
        foreach(sound : self.sounds)
        {
            if(sound.name == name)
            {
                if(sound.isPlaying())
                {
                    return;
                }
                sound.resume();
                return;
            }
        }
    }
}

fn void HMSoundWorld.removeSound(&self, String name) @dynamic
{
	HMSound* sound = self.getSoundByName(name);
    if(sound) sound.unload();
}

fn void HMSoundWorld.removeMusic(&self, String name) @dynamic
{
	HMMusic* music = self.getMusicByName(name);
    if(music) music.unload();
}



/*



fn Vec2f HMSoundWorld.getMonitorPosition(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorPosition((int)monitor_index);
}

fn int HMSoundWorld.getMonitorRefreshRate(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorRefreshRate((int)monitor_index);
}

fn int HMSoundWorld.getMonitorCount(&self) @dynamic
{
	return rl::getMonitorCount();
}

fn void HMSoundWorld.setBackGroundColor(&self, RLColor color) @dynamic @inline
{
    rl::clearBackground(color);
}

/*fn void HMSoundWorld.initialize(&self) @dynamic
{
    setWindowFlag(rl::FLAG_WINDOW_HIGHDPI);
    setWindowFlag(rl::FLAG_VSYNC_HINT); // try enabling V-Sync
    setWindowFlag(rl::FLAG_MSAA_4X_HINT); // try enabling MSAA 4X
}*/

fn WindowHandle? HMSoundWorld.createWindow(&self, String title, int width, int height, RLConfigFlag flags) @dynamic
{
    if(flags) rl::setConfigFlags(flags);

    rl::initWindow(width, height, title.zstr_tcopy());
    if(!rl::isWindowReady()) return WINDOW_CREATION_FAILED~;

    self.window = rl::getWindowHandle();
    if(self.window) { return self.window; } else { return FAILED_TO_GET_WINDOW_HANDLE~; }
}

fn bool? HMSoundWorld.isWindowReady(&self) @dynamic
{
	return (rl::isWindowReady()) ? true : WINDOW_CREATION_FAILED~;
}

fn bool HMSoundWorld.isWindowFullscreen(&self) @dynamic
{
	return rl::isWindowFullscreen();
}

fn bool HMSoundWorld.isWindowHidden(&self) @dynamic
{
	return rl::isWindowHidden();
}

fn bool HMSoundWorld.isWindowMinimized(&self) @dynamic
{
	return rl::isWindowMinimized();
}

fn bool HMSoundWorld.isWindowMaximized(&self) @dynamic
{
	return rl::isWindowMaximized();
}

fn bool HMSoundWorld.isWindowFocused(&self) @dynamic
{
    return rl::isWindowFocused();
}

fn bool HMSoundWorld.isWindowResized(&self) @dynamic
{
	return rl::isWindowResized();
}

fn int HMSoundWorld.getScreenWidth(&self) @dynamic
{
	return rl::getScreenWidth();
}

fn int HMSoundWorld.getScreenHeight(&self) @dynamic
{
	return rl::getScreenHeight();
}

fn int HMSoundWorld.getRenderWidth(&self) @dynamic
{
	return rl::getRenderWidth();
}

fn int HMSoundWorld.getRenderHeight(&self) @dynamic
{
	return rl::getRenderHeight();
}

fn void HMSoundWorld.shutdown(&self) @dynamic
{
    rl::closeWindow();
    if(self.window != null) self.window = null;
}

module engine::sys::framework::backends::bkend @if($feature(BACKEND_RGFW));

import std::io;
import game::main;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import thirdparty::rgfw17::rgfw;

/*
int main() {
	RGFW_window* win = RGFW_createWindow("name", RGFW_RECT(100, 100, 500, 500), (u64)0);

	RGFW_window_setIcon(win, icon, RGFW_AREA(3, 3), 4);

	while (RGFW_window_shouldClose(win) == RGFW_FALSE) {
		while (RGFW_window_checkEvent(win)) {
		    if (win->event.type == RGFW_quit || RGFW_isPressed(win, RGFW_escape))
			    break;
        }

		RGFW_window_swapBuffers(win);

		glClearColor(1, 1, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	RGFW_window_close(win);
}
*/

// Backend interface
interface IBackend {
    fn void	initialize() @optional;
    fn void	createWindow(String title, int width, int height);
    fn void setWindowIcon(Sprite icon) @optional;
    fn void setGLHint(int hint, int value) @optional;
    fn void	shutdown();
    fn void	pollEvents();
    fn void	swapBuffers();
}

alias WindowHandle = RGFW_window*;

struct HMSoundWorld (IBackend) 
{
    WindowHandle window;
}


fn void HMSoundWorld.initialize(&self) @dynamic
{
    rgfw::init();
}

fn void HMSoundWorld.createWindow(&self, String title, int width, int height) @dynamic
{
    self.window = rgfw::createWindow(title.zstr_tcopy(), rgfw::Rect(100, 100, width, height), (long)0);
}

macro HMSoundWorld.renderLoop(HMSoundWorld* rd; @body) {
    while (rgfw::window_shouldClose(rd.window) == rgfw::FALSE) {
        // Clear screen
        // todo
        //gl::clearColor(1, 1, 1, 1);
        //gl::clear(GL_COLOR_BUFFER_BIT);
        rd.pollEvents();
        @body;
        rd.swapBuffers();
    }
}

fn void HMSoundWorld.shutdown() @dynamic
{
    rgfw::window_close(self.window);
    // or perhaps self.window.close();
}

fn void HMSoundWorld.pollEvents() @dynamic @inline
{
    while (rgfw::window_checkEvent(self.window)) {
        if (self.window.event.type == rgfw::quit) break;
    }
}

fn void HMSoundWorld.swapBuffers() @dynamic
{
    rgfw::window_swapBuffers(self.window);
    // or perhaps self.window.swapBuffers();
}


