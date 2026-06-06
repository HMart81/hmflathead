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

module engine::sys::framework::soundbkd::sndbk @private;

import std::io, std::os::win32;
import engine::filesystem::fs;
import engine::logging::log;
import engine::misc;
import std::collections::list;
import game::main;
import thirdparty::raylib5::rl;

// sign = fn void(void* bufferdata, CUInt frames);
alias HMAudioCallback = rl::AudioCallback;

// *************** AUDIO DEVICE *********************
// Just a way to handle the sound device as a "thing"
// instead of lose functions... 
// **************************************************
fn void initAudioDevice() @inline => rl::initAudioDevice();
fn void closeAudioDevice() @inline => rl::closeAudioDevice();
fn bool isAudioDeviceReady() @inline => rl::isAudioDeviceReady();
// Set master volume (listener)
fn void setMasterVolume(float volume) @inline => rl::setMasterVolume(volume);
// Get master volume (listener)
fn float getMasterVolume() @inline => rl::getMasterVolume();

// Audio device Object
typedef AudioDevice @public = void*;

fn void AudioDevice.init(self) @inline => initAudioDevice();
fn void AudioDevice.close(self) @inline => closeAudioDevice();
fn bool AudioDevice.isReady(self) @inline => isAudioDeviceReady();
fn void AudioDevice.setVolume(self, float volume /*0.0 to 1.0*/) @inline => setMasterVolume(volume);
fn float AudioDevice.getVolume(self) @inline => getMasterVolume();
fn float AudioDevice.getActiveSounds(self) @inline => rl::getSoundsPlaying();


// *************** Sound Data ***********************
// a wrapper around RLSound just a way to give raylib 
// sounds some more data
// **************************************************
struct HMSound @public 
{
	inline RLSound super; // less than 10 seconds sounds
    Path path;
	String name;
    int id;
	float volume;
}

fn bool HMSound.isValid(self) @inline
{
	return rl::isSoundValid(self.super) && ((self.name.len & self.path.len & self.id) != 0);
}

<*
    @param relative_path : "a relative path from the sounds folder to the sound"
    @param [in] sndwld : "pointer to the current Sound World"
    @require relative_path.len > 0
    @require sndwld != null
    @ensure self.isValid()
*>
fn void? HMSound.load(&self, Path relative_path, HMSoundWorld* sndwld) @inline
{
    String _path = game::pContext.app_base_folder.tconcat("sounds").tconcat("\\");
    self.path  = path::tnew(_path)!.tappend(relative_path).tcopy()!;
    self.super = rl::loadSound(self.path.zstr_tcopy());
	self.name  = self.path.basename();
    self.id    = (int)sndwld.sounds.len() + 1;
    self.setVolume(1.0f);
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
fn void HMSound.pause(&self) @inline => rl::pauseSound(self.super);
fn void HMSound.resume(&self) @inline => rl::resumeSound(self.super);


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
}

fn void HMMusic.play(&self) => rl::playMusicStream(self.super);
fn bool HMMusic.isPlaying(&self) => rl::isMusicStreamPlaying(self.super);
fn void HMMusic.update(&self) => rl::updateMusicStream(self.super);
fn void HMMusic.stop(&self) => rl::stopMusicStream(self.super);
fn void HMMusic.pause(&self) => rl::pauseMusicStream(self.super);
fn void HMMusic.resume(&self) => rl::resumeMusicStream(self.super);
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

fn void HMMusic.unload(&self)
{
	rl::unloadMusicStream(self.super);
}

// object from where sound emenates (sound source/emitter)
struct HMSpeaker <Type> @public
{
	Type audio;

    HMSoundWorld* sndwld;
    bool free;
	int fadeTime;
	int fadeDuration;
}

fn void HMSpeaker.clearAudio(&self) @inline
{
    self.audio.unload();
}

// a non-immediate free will let all currently playing sounds complete
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
		// fade sound
		float start_volume = self.audio.getVolume();
		float currentVolume = start_volume;
		float fadeStep = start_volume / (self.fadeDuration * 100.0f); // Adjust volume in 100 steps
		int sleepTime = self.fadeDuration * 10; // Sleep time in milliseconds

		while (currentVolume > 0.0f) {
			currentVolume -= fadeStep;
			if (currentVolume < 0.0f) currentVolume = 0.0f;
			
			// Set the audio volume here
			self.audio.setVolume(currentVolume);
			
			// Sleep for a short duration to create the fade effect
			game::waitFrame(sleepTime);
		}

		if (currentVolume == 0.0f) self.audio.stop();
	}
	
	self.audio.unload();
}

// Sound Backend interface

const usz SOUND_ARENA_PAGE_SIZE = 256 * 1024; // 256 KB
DynamicArenaAllocator soundArena;

interface SoundWorldBackend
{
    fn void	init(String);
    fn int?	addSound(Path);
    fn int?	addMusic(Path);
	fn HMSpeaker{HMSound}* getSoundEmitter(int);
	fn HMSpeaker{HMSound}* getSoundEmitterByName(String);
	fn HMSpeaker{HMMusic}* getMusicEmitter(int);
	fn HMSpeaker{HMMusic}* getMusicEmitterByName(String);
    fn void	shutdown();
}

alias SoundEmitterList = List{HMSpeaker{HMSound}*};
alias MusicEmitterList = List{HMSpeaker{HMMusic}*};

struct HMSoundWorld (SoundWorldBackend) @public
{
	String name;
    SoundEmitterList sounds;
    MusicEmitterList musics;
    DynamicArenaAllocator mem_arena;
	bool active;
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

<*
    @param path : "path to sound to add to the world"
    @require path.len > 0
*>
fn int? HMSoundWorld.addSound(&self, Path path) @dynamic
{
    // see if some speaker is free
    foreach(snd : self.sounds) {
        if(snd.free) {
            snd.audio.load(path, self)!;
            return snd.audio.id;
        }
    }

    // else create a new speaker
    HMSpeaker{HMSound}* new_speaker = alloc::new(&self.mem_arena, HMSpeaker{HMSound});
    new_speaker.audio.load(path, self)!;
    /*
    new_speaker.audio = {
            .super = rl::loadSound(path.zstr_tcopy()), // less than 10 seconds sounds
            .path = path,
            .name = path.basename(),
            .id = (int)self.sounds.len() + 1
    };
    */
	self.sounds.push(new_speaker);
    return new_speaker.audio.id;
}

fn int? HMSoundWorld.addMusic(&self, Path path) @dynamic
{
    HMSpeaker{HMMusic}* new_speaker = alloc::new(&self.mem_arena, HMSpeaker{HMMusic});
    new_speaker.audio = {
            .super = rl::loadMusicStream(path.zstr_tcopy()), // more than 10 seconds sounds
            .path = path,
            .name = path.basename(),
            .id = (int)self.musics.len() + 1
        };
	self.musics.push(new_speaker);
    return new_speaker.audio.id;
}

fn HMSpeaker{HMSound}* HMSoundWorld.getSoundEmitter(&self, int id) @dynamic
{
    foreach(speaker : self.sounds) {
		if(speaker.audio.id == id) return speaker;
	}

    return null;
}

fn HMSpeaker{HMMusic}* HMSoundWorld.getMusicEmitter(&self, int id) @dynamic
{
    foreach(speaker : self.musics) {
		if(speaker.audio.id == id) return speaker;
	}

    return null;
}

fn HMSpeaker{HMSound}* HMSoundWorld.getSoundEmitterByName(&self, String name) @dynamic
{
    foreach(speaker : self.sounds) {
		if(speaker.audio.name == name) return speaker;
	}

    return null;
}

fn HMSpeaker{HMMusic}* HMSoundWorld.getMusicEmitterByName(&self, String name) @dynamic
{
    foreach(speaker : self.musics) {
		if(speaker.audio.name == name) return speaker;
	}

    return null;
}

fn void HMSoundWorld.playSound(&self, String name) @dynamic
{
    foreach(speaker : self.sounds) {
		if(speaker.audio.name == name) speaker.audio.play();
	}
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


