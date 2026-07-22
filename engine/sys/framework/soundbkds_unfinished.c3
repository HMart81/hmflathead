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

/*
module engine::sys::framework::soundbkd @private;

import std::io, std::os::win32;
import engine::filesystem::fs;
import engine::logging::log;
import engine::misc;
import std::collections::list;
import game::main;
import game::actors::ent;
import thirdparty::raylib5::rl;
import engine::sys::framework::hmdict;

// sign = fn void(void* bufferdata, CUInt frames);
alias HMAudioCallback = rl::AudioCallback;

// *************** AUDIO DEVICE *********************
// Just a way to handle the sound device as a "thing"
// instead of lose functions... 
// **************************************************
fn void initAudioDevice() @inline => rl::initAudioDevice();
fn void closeAudioDevice() @inline => rl::closeAudioDevice();
fn bool isAudioDeviceReady() @inline => rl::isAudioDeviceReady();

const SOUND_MAX_VOLUME @local = 6.0f;
<*
    Sets the volume globably for the main listener not each sound.
    @param volume : "volume is a value from 0.0 to SOUND_MAX_VOLUME, 1.0 is the default"
    @require volume <= SOUND_MAX_VOLUME : "a limit to prevent damaging hears and the sound hardware"
*>
fn void AudioDevice.setVolume(self, float volume = 1.0f) @inline {
    if(volume < 0.0f) volume = 0.0f;
    setMasterVolume(volume);
}

// Get master volume (listener)
fn float getMasterVolume() @inline => rl::getMasterVolume();

// Audio device Object
typedef AudioDevice @public = void*;

<*
	@require rl::isWindowReady() == true
*>
fn void AudioDevice.init(self) @inline => initAudioDevice();
//
fn void AudioDevice.close(self) @inline => closeAudioDevice();
fn bool AudioDevice.isReady(self) @inline => isAudioDeviceReady();
fn void AudioDevice.setVolume(self, float volume /*0.0 to 1.0*/) @inline => setMasterVolume(volume);
fn float AudioDevice.getVolume(self) @inline => getMasterVolume();
fn float AudioDevice.getActiveSounds(self) @inline => rl::getSoundsPlaying();

struct HMSound @public 
{
    Path path;
	String name;
    int id;
	float volume;
	any data;
}

fn bool HMSound.isValid(self) @inline
{
	bool isValid;
	switch
	{
		case self.data.type == RLSound:
			isValid = rl::isSoundValid(self.data);
		case self.data.type == RLMusic:
			isValid = rl::isMusicValid(self.data);
	}
	return isValid && ((self.name.len & self.path.len & self.id) != 0);
}

<*
    @param relative_path : "a relative path from the sounds folder to the sound"
    @param [in] sndwld : "pointer to the current Sound World"
    @require relative_path.len > 0
    @require sndwld != null
    @ensure self.isValid()
*>
fn HMSound*? HMSound.load(&self, Path relative_path, HMSoundWorld* sndwld) @inline
{
    String _path = game::pContext.app_base_folder.tconcat("sounds").tconcat("\\");
    self.path  = path::tnew(_path)!.tappend(relative_path).tcopy()!;
	ZString path = self.path.zstr_tcopy();
	switch
	{
		case self.data.type == RLSound:
    		self.data = any_make(rl::loadSound(path), RLSound);
		case self.data.type == RLMusic:
    		self.data = any_make(rl::loadMusicStream(path), RLMusic);
	}
	self.name  = self.path.basename();
    self.id    = (int)sndwld.sounds.len() + 1;
    self.setVolume(1.0f);
	return self;
}

fn void HMSound.unload(&self) @inline
{
	switch
	{
		case self.data.type == RLSound:
			rl::unloadSound(self.data);
		case self.data.type == RLMusic:
    		rl::unloadMusicStream(self.data);
		default: unreachable("HMSound.unload: failed to unload sound data");
	}
}

fn void HMSound.setVolume(&self, float volume) @inline
{
	if(volume < 0) volume = 0.0f;
	self.volume = volume;
	if(volume > 1.5f) {
		log::warning(FILE, "Volume of Sound '%s' was set to '%d' past default '1.0f' this may be harmfull.", self.name, volume);
	}
	switch
	{
		case self.data.type == RLSound:
			rl::setSoundVolume(self.data, volume);  // Set volume for a sound (0.0 to 1.0)
		case self.data.type == RLMusic:
    		rl::setMusicVolume(self.data, volume);
		default: unreachable("HMSound.setVolume: failed to set volume of sound data");
	}
}

fn float HMSound.getVolume(&self) @inline => self.volume;

fn void HMSound.setPitch(&self, float pitch) @inline 
{
	switch
	{
		case self.data.type == RLSound:
			rl::setSoundPitch(self.data, pitch);   // Set pitch for a sound (1.0 = normal)
		case self.data.type == RLMusic:
    		rl::setMusicPitch(self.data, pitch);
		default: unreachable("HMSound.setPitch: failed to set pitch of sound data");
	}
}

fn void HMSound.setPan(&self, float pan) @inline
{
	switch
	{
		case self.data.type == RLSound:
			rl::setSoundPan(self.data, pan);   // Set pan for a sound (0.0 = left, 0.5 = center, 1.0 = right)
		case self.data.type == RLMusic:
    		rl::setMusicPan(self.data, pan);
		default: unreachable("HMSound.setPan: failed to set pan of sound data");
	}
}

fn bool HMSound.isPlaying(&self) @inline
{
	switch
	{
		case self.data.type == RLSound:
			return rl::isSoundPlaying(self.data);
		case self.data.type == RLMusic:
    		return rl::isMusicStreamPlaying(self.data);
		default: unreachable("HMSound.isPlaying: failed!");
	}
}

fn void HMSound.play(&self) @inline
{
	switch
	{
		case self.data.type == RLSound:
			rl::playSound(self.data);
		case self.data.type == RLMusic:
    		rl::playMusicStream(self.data);
		default: unreachable("HMSound.play: failed to play sound!");
	}
}

fn void HMSound.update(&self) 
{
	switch
	{
		case self.data.type == RLSound:
			return;
		case self.data.type == RLMusic:
			rl::updateMusicStream(self.data);
	}
}

fn void HMSound.stop(&self) @inline 
{
	switch
	{
		case self.data.type == RLSound:
			rl::stopSound(self.data);
		case self.data.type == RLMusic:
			rl::stopMusicStream(self.data);
	}
}

fn void HMSound.pause(&self) @inline
{
	switch
	{
		case self.data.type == RLSound:
			rl::pauseSound(self.data);
		case self.data.type == RLMusic:
			rl::pauseMusicStream(self.data);
	}
}

fn void HMSound.resume(&self) @inline
{
	switch
	{
		case self.data.type == RLSound:
			rl::resumeSound(self.data);
		case self.data.type == RLMusic:
			rl::resumeMusicStream(self.data);
	}
}

fn void HMSound.seek(&self, float position)
{
	switch
	{
		case self.data.type == RLSound:
			return;
		case self.data.type == RLMusic:
			rl::seekMusicStream(self.data, position);
	}
}

fn float HMSound.getMusicTimeLength(&self)
{
	switch
	{
		case self.data.type == RLSound:
			return 0;
		case self.data.type == RLMusic:
			rl::getMusicTimeLength(self.data);
	}
}

fn float HMSound.getMusicTimePlayed(&self)
{
	switch
	{
		case self.data.type == RLSound:
			return 0.0f;
		case self.data.type == RLMusic:
			rl::getMusicTimePlayed(self.data);
	}
}

//******************************************************************
// object from where sound emenates (sound source/emitter)

alias SoundList = List{HMSound*};

const MAX_SOUNDS_PER_SPEAKER = 10;
const MAX_SOUNDS_PLAYING_PER_SPEAKER = 3;

struct HMSpeaker @public
{
	inline HMEntity super;
	SoundList sounds;
    HMSoundWorld* sndwld;
	HMDict spawnargs;
	int fadeTime;
	int fadeDuration;
}

fn void HMSpeaker.clear(&self) @inline
{
    if(self.sounds.len()) {
		foreach(sound : self.sounds) {
			sound.unload();
		}
	}
	self.sounds.clear();
	self.free();
}

fn void HMSpeaker.addSound(&self, HMSound* sound) @inline
{
	usz count = self.sounds.len();
    if( count < MAX_SOUNDS_PER_SPEAKER ) {
		self.sounds.push(sound);
	} else {
		log::warning(FILE, "HMSpeaker.addSound: Unable to add sound because this speaker '%s' is already full.", self.name);
		sound.unload();
	}
}

// a non-immediate free will let all currently playing sounds complete
// soundSpeakers are not actually deleted, they are just marked as
// reusable by the soundWorld
fn void HMSpeaker.unload(&self, bool immediate = false)
{
    if(self.sndwld) self.sndwld = null;

	if(immediate) {
		self.clear();
		super.kill();
		return;
	}

	// else
	if(self.sounds.len()) {
		foreach(sound : self.sounds)
		{
			if(sound.isPlaying()) {
				// fade sound
				float start_volume = sound.getVolume();
				float currentVolume = start_volume;
				float fadeStep = start_volume / (self.fadeDuration * 100.0f); // Adjust volume in 100 steps
				int sleepTime = self.fadeDuration * 10; // Sleep time in milliseconds

				while (currentVolume > 0.0f) {
					currentVolume -= fadeStep;
					if (currentVolume < 0.0f) currentVolume = 0.0f;
					
					// Set the audio volume here
					sound.setVolume(currentVolume);
					
					// Sleep for a short duration to create the fade effect
					game::waitFrame(sleepTime);
				}

				if (currentVolume == 0.0f) sound.stop();
			}
			sound.unload();
		}
	}
	self.clear();
	super.kill();
}

fn void HMSpeaker.activate(&self) @inline
{
	self.setAlive();
	active_speakers.push(self);
}

fn void HMSpeaker.deactivate(&self) @inline
{
	if(!self.isActive()) return;
	self.pause();
	self.setAlive(false);
	active_speakers.remove_item(self);
}

fn void HMSpeaker.think(&self, float dt) // update in other engines
{
	self.super.think();

    if(self.thinkflags & EntTh.THINK)
    {
		if(self.sounds.len() == 1 && !self.sounds[0].isPlaying()) self.sounds[0].play();

		if(self.sounds.len() >= 2) {
			foreach(sound : self.sounds) {
				if(!sound.isPlaying()) sound.play();
			}
		}
    }
}

fn bool HMSpeaker.isPlaying(&self) @inline
{
	foreach(sound : self.sounds) if(sound.isPlaying()) return true;
	return false;
}

fn void HMSpeaker.pause(&self) @inline
{
	if(!self.isActive()) return;
	foreach(sound : self.sounds) if(sound.isPlaying()) sound.pause();
}

fn void HMSpeaker.stop(&self) @inline
{
	foreach(sound : self.sounds) if(sound.isPlaying()) sound.stop();
}

 <*
    @param [&inout] snd_world : "pointer to sound world to create the speaker in"
    @param [&in] sound : "pointer to sound to add to speaker"
 *>
 fn HMSpeaker*? create_speaker(HMSoundWorld* snd_world, Vec2f pos, HMSound* sound) @inline
 {
	snd_world.speakers.push(alloc::new(&snd_world.mem_arena, HMSpeaker));
	HMSpeaker* speaker = snd_world.speakers.last()!;
	String name = string::tformat("%s::speaker%s", snd_world.name, snd_world.speakers.len());
	speaker.super.init(name, pos);
    speaker.sndwld = snd_world;
	speaker.addSound(sound);
    return speaker;
 }
// Sound Backend interface

const MAX_SOUND_WORLD_PLAYING_SOUNDS = 64;
// todo should I have a max limit of sounds playing or not, in a sound world?

const usz SOUND_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator soundArena;

interface SoundWorldBackend
{
    fn void	init(String);
    fn int?	registerSpeaker(HMSpeaker*);
    fn void update();
    fn void pause();
	fn HMSpeaker* getSpeaker(int);
	fn HMSpeaker* getSpeakerByName(String);
    fn void	shutdown();
}

const MAX_EMITTERS_PER_WORLD = 4000;
const MAX_EMITTERS_ACTIVE = 64;

alias SpeakerList = List{HMSpeaker*};
alias ActiveSpeakerList = List{HMSpeaker*};


struct HMSoundWorld (SoundWorldBackend) @public
{
    DynamicArenaAllocator mem_arena;
	String name;
    SpeakerList speakers;
	ActiveSpeakerList active_speakers;
	bool active;
}

fn void HMSoundWorld.init(&self, String name) @dynamic
{
    self.mem_arena.init(mem, SOUND_ARENA_PAGE_SIZE);
    self.name = name.tcopy();
	self.speakers.init(self.mem_arena);
	self.active_speakers.init(self.mem_arena);
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

fn void HMSoundWorld.update(&self) @dynamic
{
    if(self.isActive()) 
    {
        foreach(speaker : self.speakers) {
		    if(speaker.isPlaying()) {
                speaker.update();
            }
	    }
    }
}

fn void HMSoundWorld.pause(&self) @dynamic
{
    if(self.isActive())
    {
        foreach(speaker : self.speakers) {
		    if(speaker.isPlaying()) {
                speaker.pause();
            }
	    }
    }
}

<*
    @param [&in] speaker : "speaker to add to the world"
*>
fn int? HMSoundWorld.registerSpeaker(&self, HMSpeaker* speaker) @dynamic
{
	self.speakers.push(speaker);
    return self.speakers.last()!.id;
}

<*
    @param id : "id of sound emitter"
    @ensure return != null
*>
fn HMSpeaker* HMSoundWorld.getSpeaker(&self, int id) @dynamic
{
    return self.speakers[--id];
}

fn HMSpeaker* HMSoundWorld.getSpeakerByName(&self, String name) @dynamic
{
    foreach(speaker : self.speakers) {
		if(speaker.name == name) return speaker;
	}
    return null;
}

fn void HMSoundWorld.activateSpeaker(&self, String name) @dynamic
{
	if(active_speakers.len() >= MAX_EMITTERS_ACTIVE) return;

    foreach(speaker : self.speakers) {
		if(speaker.name == name) {
			speaker.activate();
		}
	}
}

fn void HMSoundWorld.stopSpeaker(&self, String name) @dynamic
{
    foreach(speaker : self.speakers) {
		if(speaker.name == name) {
			speaker.stop();
		}
	}
}

fn void HMSoundWorld.removeSpeaker(&self, String name) @dynamic
{
	HMSpeaker* speaker = self.getSpeakerByName(name);
    if(speaker) {
		speaker.unload();
		self.speakers.remove_item(speaker);
	}
}


fn void HMSoundWorld.shutdown(&self) @dynamic
{
	if(self.active_speakers.len()) self.active_speakers.clear();
    if(self.speakers.len()) self.speakers.clear();
    self.mem_arena.free();
}


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


