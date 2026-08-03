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
import engine::filesystem::fs;
import engine::logging::log;
import engine::misc;
import std::collections::list;
import game::main;
import thirdparty::raylib5::rl;
import engine::assets_api::astmng;
import thirdparty::plmpeg::plm; // for plm::PLM_AUDIO_SAMPLES_PER_FRAME

// signture = fn void(void* bufferdata, CUInt frames);
alias HMAudioCallback = rl::AudioCallback;

// *************** AUDIO DEVICE *********************
// Just a way to handle the sound device as a "thing"
// instead of lose functions... 
// **************************************************
fn void initAudioDevice() @inline {
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
fn void AudioDevice.setVolume(self, float volume = 1.0f) @inline {
    if(volume < 0.0f) volume = 0.0f;
    setMasterVolume(volume);
}

<*
    @require self.isReady()
    @ensure return >= 0.0f
*>
fn float AudioDevice.getVolume(self) @inline => getMasterVolume();

<*
    Gets the total overall sounds playing that the sound device can ear
    this is seperate from the total sounds playing, per soundworld.
    @require self.isReady()
*>
fn float AudioDevice.getSoundsPlaying(self) @inline => rl::getSoundsPlaying();


// *************** Sound Data ***********************
// a wrapper around RLSound just a way to give raylib 
// sounds some more data and controls
// **************************************************
struct HMSound @public 
{
	inline RLSound super; // less than 10 seconds sounds
    Path path;
	String name;
    int id;
	float volume;
    bool paused;
}

fn bool HMSound.isValid(self) @inline
{
	return rl::isSoundValid(self.super) && ((self.name.len & self.path.len & self.id) != 0);
}

<*
    @param relative_path : "a relative path from the sounds folder to the sound"
    @param reuse : "if the sound should reuse a free speaker and not create a new one"
    @require relative_path.len > 0
    @require game::pContext.audio_device.isReady()
    @ensure rl::isSoundValid(self.super)
*>
fn HMSound*? HMSound.load(&self, Path relative_path, bool reuse = false)
{
    String sounds_folder = "sounds\\";
    String _path = game::pContext.app_base_folder.tconcat(sounds_folder);
    if(reuse) { // unload previous sound if necessary
        if(rl::isSoundValid(self.super)) rl::unloadSound(self.super);
    }
    self.path  = path::tnew(_path)!.tappend(relative_path).tcopy()!;
    self.super = rl::loadSound(self.path.zstr_tcopy());
    String base_name = self.path.basename();
    assert(base_name.contains("."));
    sz idx = base_name.index_of_char('.')!;
    String strip = base_name[idx..];
    self.name = base_name.strip_suffix(strip);
    self.setVolume(1.0f);
    return self;
}

fn void HMSound.unload(&self) @inline
{
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
fn void HMSound.stop(&self) @inline => rl::stopSound(self.super);
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

fn void HMMusic.play(&self) => rl::playMusicStream(self.super);
fn bool HMMusic.isPlaying(&self) => rl::isMusicStreamPlaying(self.super);
fn void HMMusic.update(&self) => rl::updateMusicStream(self.super);
fn void HMMusic.stop(&self) => rl::stopMusicStream(self.super);
fn void HMMusic.pause(&self) {
    rl::pauseMusicStream(self.super);
    self.paused = true;
}
fn void HMMusic.resume(&self) {
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
fn void HMMusic.setPan(&self, float pan) => rl::setMusicPan(self.super, pan);
fn float HMMusic.getTimeLength(&self) => rl::getMusicTimeLength(self.super);
fn float HMMusic.getTimePlayed(&self) => rl::getMusicTimePlayed(self.super);

<*
    @param relative_path : "a relative path from the sounds folder to the music"
    @param reuse : "if the music should reuse a free speaker and not create a new one"
    @require relative_path.len > 0
    @ensure rl::isMusicValid(self.super)
*>
fn HMMusic*? HMMusic.load(&self, Path relative_path, bool reuse = false)
{
    String root  = game::pContext.app_base_folder.tconcat("music\\");
    Path _path = root.to_tpath().tappend(relative_path)!;
    if(reuse) { // unload previous music if necessary
        if(rl::isMusicValid(self.super)) rl::unloadMusicStream(self.super);
    }
    self.path  = _path.tcopy();
    self.super = rl::loadMusicStream(self.path.zstr_tcopy());
    assert(self.path.basename().contains("."));
    sz idx = self.path.basename().index_of_char('.')!;
    String strip = self.path.basename()[idx..];
    self.name = self.path.basename().strip_suffix(strip);
    self.setVolume(1.0f);
    return self;
}

fn void HMMusic.unload(&self)
{
	rl::unloadMusicStream(self.super);
}

// object from where sound emenates (sound source/emitter)
// TODO(HM) make this into a real game entity
struct HMSpeaker <Type> @public
{
    // inline HMEntity super;

	Type audio;

    bool free;
	//int fadeTime;
	float fadeDuration; // seconds
    HMSoundWorld* sndwld;
}

fn void HMSpeaker.clearAudio(&self)
{
    self.audio.unload();
    self.sndwld = null;
}

// a non-immediate free, will let all currently playing sounds complete
// soundEmitters are not actually deleted, they are just marked as
// reusable by the soundWorld
fn void HMSpeaker.unload(&self, bool immediate = false)
{
    if(self.sndwld) self.sndwld = null;

	if(immediate) {
        self.clearAudio();
		return;
	}

	// else
	if(self.audio.isPlaying()) {
        $if $defined(FADE_SOUND_AT_EXIT):
            // fade sound
            float start_volume = self.audio.getVolume();
            float currentVolume = start_volume;
            if(!self.fadeDuration) self.fadeDuration = 1.0f/2; // seconds
            float fadeStep = start_volume / (self.fadeDuration * 100.0f); // Adjust volume in 100 steps
            int sleepTime = (int)(self.fadeDuration * 10); // Sleep time in milliseconds

            while (currentVolume > 0.0f) {
                currentVolume -= fadeStep;
                if (currentVolume < 0.0f) currentVolume = 0.0f;
                
                // Set the audio volume here
                self.audio.setVolume(currentVolume);
                
                // Sleep for a short duration to create the fade effect
                game::waitFrame(sleepTime);
            }

            if (currentVolume == 0.0f) self.audio.stop();
        $else
            self.audio.stop();
        $endif
	}
	
	self.clearAudio();
}

alias HMSoundSpeaker @public = HMSpeaker{HMSound};
alias HMMusicSpeaker @public = HMSpeaker{HMMusic};

<*
    @param [&inout] snd_world : "pointer to sound world to create the speaker in"
*>
fn HMSoundSpeaker*? create_sound_speaker(HMSoundWorld* snd_world) @inline @local
{
    return alloc::new(&snd_world.mem_arena, HMSoundSpeaker);
}

<*
@param [&inout] snd_world : "pointer to sound world to create the speaker in"
*>
fn HMMusicSpeaker* create_music_speaker(HMSoundWorld* snd_world) @inline @local
{
    return alloc::new(&snd_world.mem_arena, HMMusicSpeaker);
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
	fn HMSoundSpeaker* getSoundEmitter(int);
	fn HMSoundSpeaker* getSoundEmitterByName(String);
	fn HMMusicSpeaker* getMusicEmitter(int);
	fn HMMusicSpeaker* getMusicEmitterByName(String);
    fn void	shutdown();
}

alias SoundEmitterList = List{HMSoundSpeaker*};
alias MusicEmitterList = List{HMMusicSpeaker*};
alias AudioPlayingList = List{any};

struct HMSoundWorld (SoundWorldBackend) @public
{
	String name;
    SoundEmitterList sounds;
    MusicEmitterList musics;
    AudioPlayingList sounds_playing;
    DynamicArenaAllocator mem_arena;
	bool active;
}

<*
    add a sound/music to the sound world current sounds playing list.
    so you don't need to loop through the entire sounds in the world.
    @param [&inout] list : "the playing list"
*>
fn void addSoundToPlayingList(any sound, AudioPlayingList* list) @inline @local
{
    list.push(sound);
}

<*
    Remove a sound registered in the sound world current sounds playing list.
    @param [&inout] list : "the playing list"
*>
fn void removeSoundFromPlayingList(sz idx, AudioPlayingList* list) @inline @local
{
    list.remove_at(idx);
}

<*
    Remove a sound registered in the sound world current sounds playing list.
    @param [&inout] list : "the playing list"
*>
fn void removeSoundItemFromPlayingList(any sound, AudioPlayingList* list) @inline @local
{
    list.remove_item(sound);
}

fn void HMSoundWorld.init(&self, String name) @dynamic
{
    self.mem_arena.init(mem, SOUND_ARENA_PAGE_SIZE);
    self.name = name.tcopy();
}

fn void HMSoundWorld.activate(&self) @dynamic
{
    self.active = true;
}

fn void HMSoundWorld.deactivate(&self) @dynamic
{
    self.active = false;
}

fn bool HMSoundWorld.isActive(&self) @dynamic => self.active;

fn void setPlayingSoundWorld(HMSoundWorld* snd_world) @public
{
    if(!snd_world) {
        HMSoundWorld* current_sound_world = game::pContext.current_sound_world;
        if(current_sound_world) current_sound_world.deactivate();
        return;
    }
    // else
    snd_world.activate();
    game::pContext.current_sound_world = snd_world;
}

fn bool HMSoundWorld.hasSoundsPlaying(&self) => self.sounds_playing.len() > 0;

fn void HMSoundWorld.update(&self) @dynamic
{
    if(self.isActive()) 
    {
        foreach(music_speaker : self.musics) {
		    if(music_speaker.audio.isPlaying()) {
                music_speaker.audio.update();
            }
	    }
    }
}

fn void HMSoundWorld.pause(&self) @dynamic
{
    if(self.isActive())
    {
        foreach(music_speaker : self.musics) {
		    if(music_speaker.audio.isPlaying()) {
                music_speaker.audio.pause();
            }
	    }
        foreach(sound_speaker : self.sounds) {
		    if(sound_speaker.audio.isPlaying()) {
                sound_speaker.audio.pause();
            }
	    }
        // clear the playing lists
        self.sounds_playing.clear();
        self.deactivate();
    }
}

fn void HMSoundWorld.unpause(&self) @dynamic
{
    if(!self.isActive())
    {
        self.activate();
        foreach(music_speaker : self.musics) {
            bool paused = music_speaker.audio.paused;
		    if(!music_speaker.audio.isPlaying() && paused) {
                music_speaker.audio.resume();
                addSoundToPlayingList(any_make(music_speaker, HMMusicSpeaker), &self.sounds_playing);
            }
	    }
        foreach(sound_speaker : self.sounds) {
            bool paused = sound_speaker.audio.paused;
		    if(sound_speaker.audio.isPlaying() && paused) {
                sound_speaker.audio.resume();
                addSoundToPlayingList(any_make(sound_speaker, HMSoundSpeaker), &self.sounds_playing);
            }
	    }
    }
}

fn void HMSoundWorld.stop(&self) @dynamic
{
    if(self.isActive())
    {
        self.deactivate();
        foreach(music_speaker : self.musics) {
		    if(music_speaker.audio.isPlaying()) {
                music_speaker.audio.stop();
            }
	    }
        foreach(sound_speaker : self.sounds) {
		    if(sound_speaker.audio.isPlaying()) {
                sound_speaker.audio.stop();
            }
	    }
        // clear the playing lists
        self.sounds_playing.clear();
    }
}

<*
    @param [in] relative_path : "relative path to sound to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? HMSoundWorld.addSound(&self, Path relative_path) @dynamic
{
    // reuse speakers
    foreach(sound : self.sounds) {
        if(sound.free) {
            sound.audio.load(relative_path, reuse: true)!;
            return sound.audio.id;
        }
    }

    // create a new speaker
    HMSoundSpeaker* new_speaker = create_sound_speaker(self)!;
    self.sounds.push(new_speaker);
    new_speaker.audio.load(relative_path)!;
    new_speaker.audio.id = (int)self.sounds.len() + 1;
    new_speaker.sndwld = self;
    new_speaker.fadeDuration = 0.5f;
    return new_speaker.audio.id;
}

<*
    @param [&inout] sndwld : "sound world to add sound to"
    @param [in] relative_path : "relative path to sound to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? addSoundTo(HMSoundWorld* sndwld, Path relative_path) @public
{
    // reuse speakers
    foreach(sound : sndwld.sounds) {
        if(sound.free) {
            sound.audio.load(relative_path, reuse: true)!;
            return sound.audio.id;
        }
    }

    // create a new speaker
    HMSoundSpeaker* new_speaker = create_sound_speaker(sndwld)!;
    sndwld.sounds.push(new_speaker);
    new_speaker.audio.load(relative_path)!;
    new_speaker.audio.id = (int)sndwld.sounds.len() + 1;
    new_speaker.sndwld = sndwld;
    new_speaker.fadeDuration = 0.5f;
    return new_speaker.audio.id;
}

<*
    @param [in] relative_path : "relative path to music to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? HMSoundWorld.addMusic(&self, Path relative_path) @dynamic
{
     // reuse speakers
    foreach(music : self.musics) {
        if(music.free) {
            music.audio.load(relative_path, reuse: true)!;
            return music.audio.id;
        }
    }

    HMMusicSpeaker* new_speaker = create_music_speaker(self);
    self.musics.push(new_speaker);
    new_speaker.audio.load(relative_path)!;
    new_speaker.audio.id = (int)self.musics.len() + 1;
    new_speaker.sndwld = self;
    new_speaker.fadeDuration = 0.5f;
    return new_speaker.audio.id;
}

<*
    @param [&inout] sndwld : "sound world to add music to"
    @param [in] relative_path : "relative path to music to add to the world"
    @require relative_path.len > 0
    @ensure return >= 1
*>
fn int? addMusicTo(HMSoundWorld* sndwld, Path relative_path) @public
{
     // reuse speakers
    foreach(music : sndwld.musics) {
        if(music.free) {
            music.audio.load(relative_path, reuse: true)!;
            return music.audio.id;
        }
    }

    HMMusicSpeaker* new_speaker = create_music_speaker(sndwld);
    sndwld.musics.push(new_speaker);
    new_speaker.audio.load(relative_path)!;
    new_speaker.audio.id = (int)sndwld.musics.len() + 1;
    new_speaker.sndwld = sndwld;
    new_speaker.fadeDuration = 0.5f;
    return new_speaker.audio.id;
}

<*
    @param id : "id of sound emitter"
    @ensure return != null
*>
fn HMSoundSpeaker* HMSoundWorld.getSoundEmitter(&self, int id) @dynamic
{
    return self.sounds[--id];
}

<*
    @param id : "id of music emitter"
    @require id >= 1
    @ensure return != null
*>
fn HMMusicSpeaker* HMSoundWorld.getMusicEmitter(&self, int id) @dynamic
{
   return self.musics[(sz)(id - 1)];
}

fn HMSoundSpeaker* HMSoundWorld.getSoundEmitterByName(&self, String name) @dynamic
{
    foreach(speaker : self.sounds) {
		if(speaker.audio.name == name) return speaker;
	}

    return null;
}

fn HMMusicSpeaker* HMSoundWorld.getMusicEmitterByName(&self, String name) @dynamic
{
    foreach(speaker : self.musics) {
		if(speaker.audio.name == name) return speaker;
	}

    return null;
}

fn void HMSoundWorld.playSound(&self, String name, bool is_music = false) @dynamic
{
	if(self.sounds_playing.len() >= 64) return;

    if(is_music) {
        foreach(speaker : self.musics) {
            if(speaker.audio.name == name) {
                if(!speaker.audio.isPlaying()) {
                    speaker.audio.play();
                    addSoundToPlayingList(any_make(speaker, HMMusicSpeaker), &self.sounds_playing);
                }
            }
        }
    } else {
        foreach(speaker : self.sounds) {
            if(speaker.audio.name == name) {
                speaker.audio.play();
                addSoundToPlayingList(any_make(speaker, HMSoundSpeaker), &self.sounds_playing);
            }
        }
    }
}

fn void HMSoundWorld.stopSound(&self, String name, bool is_music = false) @dynamic
{
    if(self.sounds_playing.len() <= 0) return;

    if(is_music) {
        foreach(i, speaker : self.musics) {
            if(speaker.audio.name == name) {
                speaker.audio.stop();
                removeSoundItemFromPlayingList(any_make(speaker, HMMusicSpeaker), &self.sounds_playing);
            }
        }
    } else {
        foreach(i, speaker : self.sounds) {
            if(speaker.audio.name == name) {
                speaker.audio.stop();
                removeSoundItemFromPlayingList(any_make(speaker, HMSoundSpeaker), &self.sounds_playing);
            }
        }
    }
}

fn void HMSoundWorld.pauseSound(&self, String name, bool is_music = false) @dynamic
{
	if(self.sounds_playing.len() <= 0) return;

    if(is_music) {
        foreach(speaker : self.musics) {
            if(speaker.audio.name == name) {
                if(!speaker.audio.isPlaying()) {
                    return;
                }
                speaker.audio.pause();
                removeSoundItemFromPlayingList(any_make(speaker, HMMusicSpeaker), &self.sounds_playing);
                return;
            }
        }
    } else {
        foreach(speaker : self.sounds) {
            if(speaker.audio.name == name) {
                if(!speaker.audio.isPlaying()) {
                    return;
                }
                speaker.audio.pause();
                removeSoundItemFromPlayingList(any_make(speaker, HMSoundSpeaker), &self.sounds_playing);
                return;
            }
        }
    }
}

fn void HMSoundWorld.resumeSound(&self, String name, bool is_music = false) @dynamic
{
    if(is_music) {
        foreach(speaker : self.musics) {
            if(speaker.audio.name == name) {
                if(speaker.audio.isPlaying()) {
                    return;
                }
                speaker.audio.resume();
                return;
            }
        }
    } else {
        foreach(speaker : self.sounds) {
            if(speaker.audio.name == name) {
                if(speaker.audio.isPlaying()) {
                    return;
                }
                speaker.audio.resume();
                return;
            }
        }
    }
}

fn void HMSoundWorld.removeSound(&self, String name) @dynamic
{
	HMSoundSpeaker* speaker = self.getSoundEmitterByName(name);
    if(speaker) self.sounds.remove_item(speaker);
}


fn void HMSoundWorld.shutdown(&self) @dynamic
{
    foreach(speaker : self.sounds) speaker.unload();
    self.sounds.free();

    foreach(speaker : self.musics) speaker.unload();
    self.musics.free();
    self.mem_arena.free();
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


