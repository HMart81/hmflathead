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

// do not use bugs and incomplete :(
module engine::sys::videoplay::vid @private @if($feature(VIDEO_PLAYBACK_ENABLE));

import game::main;
import std::io;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import std::collections::list;
import thirdparty::raylib5::rl;
import thirdparty::plmpeg::plm;
import engine::sys::framework::platform::platf;
import game::camview;

const VIDEO_FILE_EXTENSION = ".mpg";
const VIDEOS_FOLDER_PATH   = "videos"+++platf::PATHSEPERATOR_STR;
const COLOR_CHANNELS  @local = 3;
const BYTES_PER_PIXEL @local = COLOR_CHANNELS * Uint8_t.sizeof;

alias gpGame = game::gpGame;

alias VideoFile   = File;
alias VideoPlayer = PLM_t; // video player to play videos
alias VideoFrame  = RLTexture2D;

const TRUE @local  = 1;
const FALSE @local = 0;

faultdef VIDEO_MISSING_FILE,
         VIDEO_LOAD_FAILED,
         VIDEO_OPEN_FAILD,
         VIDEO_READ_FAILED,
         VIDEO_CLOSE_FAILED;

struct VidMovie @public
{
    // this is set at init time
    String path; // full path
    String name; // name only
    CLong modtime; // modification time

    // this is done at play time
    float time_since_last_call;

    // video data
    int samplerate; // for audio
    float framerate;
    float duration; // in seconds
	bool is_playing;
	bool should_play;
	bool is_ready;
	VideoPlayer plyr;
	VideoFrame frame;
}

fn void VidMovie.renderFrame(&self, Vec2f position, Vec2f size) @public
{
	if(self.is_ready && self.should_play) 
	{
		if(rl::isTextureValid(self.frame)) 
		{
			//rl::drawTexture(self.frame, (int)position.x, (int)position.y, rl::WHITE);
			rl::drawTexturePro(
				self.frame,
				(RLRectangle){0.0f, 0.0f, (float)self.frame.width, (float)-self.frame.height},
				(RLRectangle){position.x, position.y, size.x, size.y},
				(RLVector2){0.0f, 0.0f},
				0.0f,
				rl::WHITE
			);
		}
	}
}

<*
	@param [&in] frame : "pointer to the current plm frame to update the video frame"
*>
fn void VidMovie.updateFrame(&self, VideoPlayer mpeg, PLMframe *frame)
{
	int w, h;
	w = mpeg.get_width();
	h = mpeg.get_height();
	// create image to hold frame data
	// compute stride
	usz stride = w * BYTES_PER_PIXEL;
	usz dataSize = stride * h;
	// allocate memory for frame data
	char* fileData = (char*)mem::malloc(dataSize);
    frame.to_rgb((Uint8_t*)fileData, (int)stride);
	RLImage image = rl::loadImageFromMemory(".png", fileData, (CInt)dataSize);
	defer rl::unloadImage(image);
	
    image.width     = w;
    image.height    = h;
    image.mipmaps = 1;
    image.format = rl::RLPixelFormat.UNCOMPRESSED_R8G8B8;

	// unload previous texture frame
	if(rl::isTextureValid(self.frame)) {
		rl::unloadTexture(self.frame);
	}
	// update texture frame
	self.frame = rl::loadTextureFromImage(image);
}

<*
	@param loop : "should the video loop when it ends"
	@param audio : "should the video play audio"
*>
fn bool VidMovie.preparePlayer(&self, bool loop = false, bool audio = false) @public @nodiscard
{
    VideoFile? video = fs::openFile(self.path, fs::FILE_READ_BINARY);
	if(catch excuse = video ) {
		log::warning(FILE, "failed to open video %s to play with error: %s", self.name, excuse);
		return false;
	} else { // successfully opened video file
		assert(self.plyr == null);
		self.plyr = plm::create_with_file(video.file, TRUE);

		if(self.plyr == null) {
			log::warning(FILE, "failed to create video player to play video: %s", self.name);
			return false;
		}

		if (!self.plyr.has_headers()) {
			log::warning(FILE, "Invalid MPEG video found %s has no valid headers.", self.name);
			unreachable();
		}

		if (!self.plyr.probe(5000 * 1024)) {
			log::warning(FILE, "No MPEG video or audio streams found in %s", self.name);
			unreachable();
		}

		self.samplerate = self.plyr.get_samplerate();
		self.framerate  = (float)self.plyr.get_framerate();
		self.duration   = (float)self.plyr.get_duration();

		vid::initDecodingSystem(self);

		(loop)  ? self.plyr.set_loop(TRUE) : self.plyr.set_loop(FALSE);
		(audio) ? self.plyr.set_audio_enabled(TRUE) : self.plyr.set_audio_enabled(FALSE);
		self.plyr.set_audio_stream(0);

		self.is_ready = true;
	}

	return self.is_ready;
}

fn void VidMovie.decode(&self) @public
{
	if(!self.should_play) return;

	assert(self.is_ready == true);

	// Decode
	if(!self.plyr.has_ended()) {
		self.plyr.decode(self.time_since_last_call);
		self.time_since_last_call += gpGame.time_sec;
		self.is_playing = true;
	} else {
		// Stop playback
		self.stop();
		self.is_playing = false;
	}
}

fn void VidMovie.start(&self) @public @inline
{
	self.should_play = true;
}

fn void VidMovie.stop(&self) @public @inline
{
	self.should_play = false;
}

fn void VidMovie.reset(&self) 
{
    self.path = "";
    self.name = "";
	self.modtime = 0;
    self.time_since_last_call = 0.0f;
    self.samplerate = 0;
    self.framerate = 0.0f;
    self.duration = 0.0f;
	self.is_playing = false;
	self.should_play = false;
	self.is_ready = false;
	if(self.plyr != null) {
		self.plyr.destroy();
		self.plyr = null;
	}
	if(rl::isTextureValid(self.frame)) rl::unloadTexture(self.frame);
}


//////////////////////////////////////////// VIDEO CABINET ////////////////////////////////////////////

alias VideoListPtr = List{VidMovie*};
// place to hold all videos
struct VideoCabinet @public
{
    String movies_folder;
    VideoListPtr movies;
}

fn void VideoCabinet.setMoviesDirectory(&self, String movies_dir) @local @inline
{
    self.movies_folder = movies_dir.tcopy();
}

fn void VideoCabinet.initMoviesDirectory(&self) @local @inline
{
	String videos_path = gpGame.app_base_folder.tconcat(VIDEOS_FOLDER_PATH);
	/*if(catch excuse = fs::makeDirectory_IfNotExist(videos_path)) {
		log::error(FILE, "failed to create videos directory at path: %s with excuse %s", videos_path, excuse);
	}*/
    self.setMoviesDirectory(videos_path);
}

<*
	Create and initialize a video cabinet
	@param [inout] vidc : "pointer to the video cabinet"
*>
fn void? initVideoCabinet(VideoCabinet** vidc) @public
{
	(*vidc) = mem::new(VideoCabinet);
	(*vidc).initMoviesDirectory();
	if(catch excuse = (*vidc).registerVideos()) {
		log::error(FILE, "failed to register videos inside video cabinet with excuse %s.",  excuse);
		(*vidc).movies_folder = "";
		mem::free((*vidc));
		vidc = null;
	}
}

fn void VideoCabinet.addMovie(&self, VidMovie* movie) @public @inline
{
	self.movies.push(movie);
}

fn void? VideoCabinet.registerVideos(&self) 
{
    assert(self.movies_folder != "");

    if(fs::makeDirectory_IfNotExist(self.movies_folder)!!)
    {
        RLFilePathList videos_files = fs::loadDirectoryFiles(self.movies_folder);
        defer {
            if(videos_files.count) fs::unloadDirectoryFiles(videos_files);
        };

        if(videos_files.count)
        {
            String path_view = videos_files.paths[0].str_view();
            for(int i = 0; i < videos_files.count; path_view = videos_files.paths[i++].str_view()) 
            {
                if(fs::isFile(path_view))
                {
                    if(fs::getFileExtension(path_view) == VIDEO_FILE_EXTENSION) {
                        self.addMovie(
                            mem::new(VidMovie, {
                                .path = path_view.tcopy(),
                                .name = fs::getFileNameWithoutExt(path_view).tcopy(),
                                .modtime = fs::getFileModTime(path_view)
                            })
                        );
                    } else {
                        log::warning(FILE, "found unsuported file '%s' inside videos folder.\n\t-For now only mpg videp (mpeg1 with or without mp2 audio) is supported.", path_view);
                    }
                } else {
                    log::warning(FILE, "found sub directory '%s' inside videos folder.\n\t-For now any mpg video, needs to be put in the root of the videos folder, no sub directories please.", path_view);
                }
            }
        } else {
            log::warning(FILE, "Found no videos to register inside videos folder.");
        }
    }
}


fn bool VideoCabinet.hasMovie(&self, String name) @public
{
	if(self.movies.len() == 0) 
	{
		return false;
	}

	foreach(movie : self.movies) 
	{
		if(movie.name == name) 
		{
			return true;
		}
	}

	return false;
}

// todo return a default error video maybe?
fn VidMovie* VideoCabinet.getMovie(&self, String vid_name) @public
{
    foreach(movie : self.movies) 
    {
        if(movie.name == vid_name) 
        {
            return movie;
		}
    }
    return null;
}

<*
    @param [&inout] vidc : "pointer to the video player"
*>
fn void deinitVideoCabinet(VideoCabinet* vidc) @public
{
    
    if(vidc.movies.len()) {
        foreach(movie : vidc.movies) {
            movie.reset();
        }
        vidc.movies.clear();
    }
    mem::free(vidc);
}

/*
struct PLMframe copy pasted from lpmpeg.c3i for doc reasons only
{
	double time;
	uint width;
	uint height;
	PLMplane y;
	PLMplane cr;
	PLMplane cb;
}
*/

<*
	@param [&in] mpeg : "pointer to the mpeg player"
	@param [&in] frame : "pointer to the decoded frame"
	@param [&in] user : "pointer to some user data"
*>
fn void on_video(VideoPlayer mpeg, PLMframe *frame, void *user) 
{
	var video @safeinfer = (VidMovie*)user;
    video.updateFrame(mpeg, frame);
}

fn void on_audio(PLM_t mpeg, PLMsamples *samples, void *user) {
	VidMovie *self = (VidMovie *)user;

	// Hand the decoded samples over to SDL
	
	int size = float.sizeof * samples.count * 2;
    Buffer* buffer = buffer::create_with_capacity(size);
    buffer.write((Uint8_t*)&samples.left[0], samples.left.len);
    buffer.write((Uint8_t*)&samples.right[0], samples.right.len);
    PLMaudio* audio = plm::audio::create_with_buffer(buffer, 1);
    RLWave raw = {
        .frameCount = size,
        .sampleRate = audio.get_samplerate(),
        .sampleSize = 32,
        .channels   = 2,
        .data = audio.buffer.bytes
    };
    if(rl::isWaveValid(raw)) {
        RLSound snd = rl::loadSoundFromWave(raw);
        if(rl::isSoundValid(snd)) {
            rl::playSound(snd);
        }
    }
    audio.destroy();
    buffer.destroy();
	//SDL_QueueAudio(self->audio_device, samples->interleaved, size);
}

<*
	@param [&in] video : "pointer to the video movie data"
*>
fn void initDecodingSystem(VidMovie* video)
{
    plm::set_video_decode_callback(video.plyr, &on_video, video);
	plm::set_audio_decode_callback(video.plyr, &on_audio, video);
}