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

// Incomplete :( 
// Plays videos just fine but embeded audio in the videos, 
// is mostly broken, particularly stereo sound but mono as issues as well just less
// and I don't know why. I really tried a bunch of things, even going as far as two 
// create two mono audio streams, one for the right and left channels but didnt worked.
// I saw online tutorials like this one 
// https://github.com/WEREMSOFT/c99-raylib-vide-player/blob/master/src/main.c
// and
// https://github.com/phoboslab/pl_mpeg/blob/master/pl_mpeg_player_sdl.c
// did everything they did for audio, nothing worked.
// Read online about samples versus audio frames and stuff and did all they said but
// again nothing helped. Perhaps there's a issue with audio streams and lp_mpeg mp2 sound!
// Right now for my sanity, I will try play audio seperate from videos, because that seems to work,
// the issue will be to syncronize those with the video...
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
import engine::sys::cvar;

// region cvars
CVar numSpeakers @public = { "numSpeakers", CvFlag.INT, "2", "number of speakers for sound playing" };

fn void register_cvars() @public 
{
    cvar::@register(&numSpeakers);
}
// end_region

const EXTENSION_MPG = ".mpg";
const EXTENSION_MPEG = ".mpeg";
const VIDEOS_FOLDER_PATH   = "videos"+++platf::PATHSEPERATOR_STR;
const COLOR_CHANNELS  @local = 3;
const BYTES_PER_PIXEL @local = COLOR_CHANNELS * Uint8_t.sizeof;

alias gpGame = game::gpGame;

alias VideoFile   = File;
alias VideoPlayer = PLM_t; // video player to play videos
alias VideoFrame  = RLImage;

const TRUE @local  = 1;
const FALSE @local = 0;

//const AUDIO_EMBEDED = 1; // comment to disable
const AUDIO_SEPERATE = 1; // uncomment to enable or vice versa

//const VIDEO_FRAME_RATE = 30;

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
    double time_since_last_call; // in seconds

	// this is set at init time or play time
	int startTime; // milliseconds
    // video data
    int samplerate; // for audio
    float framerate;
	int frame_count @if($defined(DEBUG_VIDEO));
    float duration; // in seconds
	bool is_playing;
	bool should_play; // sets it to play for later
	bool started;    // triggers video it now
	bool fullscreen;
	bool is_ready;
	bool set_frame_settings;
	bool paused;
	VideoPlayer* plyr; // each movie has its own video player
	// frame data 
	VideoFrame frame;
	RLTexture2D frame_texture;
	int frame_stride;
	int frame_data_size;

	// video sound data
	RLAudioStream audio @if($defined(AUDIO_EMBEDED)); // embeded audio streaming is broken for now :(
	PLMsamples *samples @if($defined(AUDIO_EMBEDED));
	// seperate audio system
	RLMusic audio @if($defined(AUDIO_SEPERATE));
	String track_name @if($defined(AUDIO_SEPERATE));
	float track_delay @if($defined(AUDIO_SEPERATE)); // how late to start the track
}

/*
// this was causing massive GPU memory leaking....
<*
	Render each frame as a GPU texture unto screen
	@param [&in] _frame : "frame data to render"
	@param screen : "screen area where play the frame"
	@require rl::isImageValid(*_frame) != false
	@require screen.size != VEC2_ZERO
*>
fn void renderFrame(RLImage* _frame, RLRectangle screen) @local
{
	RLTexture2D frame = rl::loadTextureFromImage(*_frame);
	rl::drawTexturePro(
		frame,
		(RLRectangle){0.0f, 0.0f, (float)frame.width, (float)frame.height},
		misc::makeRect(screen.pos, screen.size), VEC2_ZERO, 0.0f, rl::WHITE
	);
}
*/

fn void VidMovie.draw(&self, Vec2f position = VEC2_ZERO)
{
	if(self.is_ready && self.should_play && self.started)
	{
		assert(gpGame.render.isWindowReady()!!);
		Vec2f view_size = {
			.x = (self.fullscreen) ? gpGame.screen.w : self.frame.width,
			.y = (self.fullscreen) ? gpGame.screen.h : self.frame.height
		};

		if(self.fullscreen) if(position != VEC2_ZERO) position = VEC2_ZERO;

		RLTexture2D* frame = &self.frame_texture;
		rl::drawTexturePro(
			*frame,
			(RLRectangle){0.0f, 0.0f, (float)(*frame).width, (float)(*frame).height},
			misc::makeRect(position, view_size), VEC2_ZERO, 0.0f, rl::WHITE
		);

		$if $defined(DEBUG_VIDEO):
			self.frame_count++;
			rl::drawText(string::tformat_zstr("Video: fr: %s fc: %s", (int)self.framerate, self.frame_count), 50, 25, 16, rl::RED);
		$endif
	}
}

fn void VidMovie.drawWithinRect(&self, RLRectangle rect)
{
	if(self.is_ready && self.should_play && self.started) {
		assert(gpGame.render.isWindowReady()!!);
		RLTexture2D* frame = &self.frame_texture;
		rl::drawTexturePro(
			*frame,
			(RLRectangle){0.0f, 0.0f, (float)(*frame).width, (float)(*frame).height},
			rect, VEC2_ZERO, 0.0f, rl::WHITE
		);
	}
}

fn void freeFrameData(VideoFrame* frame, bool clear_all = false) @local @deprecated 
{
	if(!frame.data) return;
	mem::free(frame.data);
	frame.data = null;

	if(clear_all) {
		frame.width   = 0;
    	frame.height  = 0;
    	frame.mipmaps = 0;
    	frame.format  = 0;
	}
}

<*
	@param [&in] frame : "pointer to the current plm frame to update the video frame"
*>
fn void VidMovie.updateFrame(&self, PLMframe *frame) @MyInline
{
	if(!self.is_ready || !self.should_play || !self.started ) return;
    // converte YUV to required RGB data
    frame.to_rgb(self.frame.data, self.frame_stride);
	rl::updateTexture(self.frame_texture, self.frame.data);
}

fn void VidMovie.update_video(&self) @MyInline
{
	if(!self.is_ready || !self.should_play || !self.started ) return;

	PLMframe *frame = self.plyr.decode_video();
    // converte YUV to required RGB data
    frame.to_rgb(self.frame.data, self.frame_stride);
	rl::updateTexture(self.frame_texture, self.frame.data);
}

////////////////////////////////////////////////////////////////////////////////
////////////////////////////// AUDIO ///////////////////////////////////////////
constdef VidAudioMode : inline int
{
	NONE = 0,
	MONO,
	STEREO
}

// PLM_AUDIO_SAMPLES_PER_FRAME = 1152 always, according to lpmpeg library comment...
// 1 frame of audio in seconds = (PLM_AUDIO_SAMPLES_PER_FRAME/samplerate) 
// so given a 30fps video total audio samples size = (samplerate / 30) * frame size;
//
//const BUFFER_SIZE @local = 4096;
const AUDIO_F32 @local = 32; // bits
//const CHANNEL_COUNT  = VidAudioMode.MONO; // Using mono works for mono tracks but breaks stereo
const CHANNEL_COUNT    = VidAudioMode.STEREO; // Using Stereo for videos, will break mono and stereo!!!! ;(
// NOTE(HM) Each audio frame consists of one or two samples
const SAMPLE_SIZE      = float.sizeof; // 4 bytes
const AUDIO_FRAME_SIZE = SAMPLE_SIZE * CHANNEL_COUNT; // 1 frame in bytes
//
// this is the amount of SAMPLES to save on memory per tick
const BUFFER_SIZE = plm::PLM_AUDIO_SAMPLES_PER_FRAME;

<*
	@param [&in] samples : "pointer to the current plm audio samples to update the video sound"
*>
fn void VidMovie.updateAudio(&self, PLMsamples *samples) @MyInline
{
	if(!self.should_play && !self.started) return;

	$if $defined(AUDIO_EMBEDED):
		if (rl::isAudioStreamProcessed(self.audio))
		{
			//int size = samples.interleaved.len;
			int size = BUFFER_SIZE;
			rl::updateAudioStream(self.audio, &samples.interleaved[0], size);
		}
	$endif

	$if $defined(AUDIO_SEPERATE):
		if(gpGame.time_sec > self.track_delay) {
			if(rl::isMusicValid(self.audio)) rl::updateMusicStream(self.audio);
		}
	$endif
}

fn void VidMovie.update_audio(&self) @MyInline
{
	if(!self.should_play && !self.started) return;

	$if $defined(AUDIO_EMBEDED):
		if (rl::isAudioStreamProcessed(self.audio))
		{
			self.samples = self.plyr.decode_audio();
			//int size = samples.interleaved.len;
			int size = BUFFER_SIZE;
			rl::updateAudioStream(self.audio, &self.samples.interleaved[0], size);
		}
	$endif

	$if $defined(AUDIO_SEPERATE):
		if(rl::isMusicValid(self.audio)) rl::updateMusicStream(self.audio);
	$endif
}

fn void VidMovie.enableAudio(&self, bool enable = false) @MyInline
{
	if(!enable) return;
	assert(rl::isAudioDeviceReady());

	$if $defined(AUDIO_EMBEDED):
		self.plyr.set_audio_enabled(TRUE);
		self.plyr.set_audio_stream(0);

		if (self.plyr.get_num_audio_streams() > 0) 
		{
			// NOTE(HM) This has to be set before loadAudioStream
			rl::setAudioStreamBufferSizeDefault(BUFFER_SIZE);
			self.audio = rl::loadAudioStream(self.samplerate, AUDIO_F32, CHANNEL_COUNT);
			//rl::setAudioStreamVolume(self.audio, 1.0f);
			//rl::playAudioStream(self.audio);
			// Adjust the audio lead time according to the audio_spec buffer size
			self.plyr.set_audio_lead_time((double)BUFFER_SIZE / (double)self.samplerate);
		}
	$endif

	$if $defined(AUDIO_SEPERATE):
		if(self.track_name) {
			ZString track_path = game::gpGame.app_base_folder.tconcat("music/").tconcat(self.track_name).zstr_tcopy();
			self.audio = rl::loadMusicStream(track_path);
			self.track_delay = 0.0f; //(float)BUFFER_SIZE / self.samplerate;
		}
	$endif
}

fn bool VidMovie.audio_enabled(&self) @if($defined(AUDIO_EMBEDED)) => (self.plyr.get_audio_enabled() == TRUE) ? true : false;
fn bool VidMovie.audio_valid(&self)   @if($defined(AUDIO_EMBEDED)) => rl::isAudioStreamValid(self.audio);
fn bool VidMovie.audio_playing(&self) @if($defined(AUDIO_EMBEDED)) => (rl::isAudioStreamPlaying(self.audio) && !self.paused);

fn bool VidMovie.audio_enabled(&self) @if($defined(AUDIO_SEPERATE)) => self.audio_valid();
fn bool VidMovie.audio_valid(&self)   @if($defined(AUDIO_SEPERATE)) => rl::isMusicValid(self.audio);
fn bool VidMovie.audio_playing(&self) @if($defined(AUDIO_SEPERATE)) => (rl::isMusicStreamPlaying(self.audio) && !self.paused);


fn void VidMovie.audio_play(&self) @MyInline 
{
	if(self.audio_enabled() && self.audio_valid()) {
		if(!self.audio_playing()) {
			if(self.audio_paused()) {
				self.audio_resume();
			} else if(self.audio_stopped()) {
				$if $defined(AUDIO_EMBEDED):
					rl::playAudioStream(self.audio);
				$endif
				$if $defined(AUDIO_SEPERATE):
					rl::playMusicStream(self.audio);
					self.track_delay = gpGame.time_sec + ((float)BUFFER_SIZE / self.samplerate) * rl::getFrameTime();
				$endif
				if(self.paused) self.paused = false;
			}
			//log::info(CONSOLE, "starting video %s sound playing at: %s", self.name, gpGame.time_sec);
		}
	}
}

fn void VidMovie.audio_stop(&self) @MyInline
{
	if(self.audio_enabled() && self.audio_valid()) {
		if(self.audio_playing()) {
			$if $defined(AUDIO_EMBEDED):
				rl::stopAudioStream(self.audio);
			$endif
			$if $defined(AUDIO_SEPERATE):
				rl::stopMusicStream(self.audio);
				self.track_delay = 0.0f;//(float)BUFFER_SIZE / self.samplerate;
			$endif
			// right now to simplify things 
			// you cannot pause the audio seperatly from the video itself
			// aka if the video is paused audio is paused and vice versa
			self.paused = true;
			//log::info(CONSOLE, "Stopped video %s sound playing at: %s", self.name, gpGame.time_sec);
		}
	}
}

fn void VidMovie.audio_pause(&self) @MyInline
{
	$if $defined(AUDIO_EMBEDED):
		rl::pauseAudioStream(self.audio);
	$endif
	$if $defined(AUDIO_SEPERATE):
		rl::pauseMusicStream(self.audio);
	$endif
	self.paused = true;
}

fn void VidMovie.audio_resume(&self) @MyInline
{
	$if $defined(AUDIO_EMBEDED):
		rl::resumeAudioStream(self.audio);
	$endif
	$if $defined(AUDIO_SEPERATE):
		rl::resumeMusicStream(self.audio);
	$endif
	self.paused = false;
}

fn bool VidMovie.audio_paused(&self) @MyInline
{
	return (!self.audio_playing() && self.paused);
}

fn bool VidMovie.audio_stopped(&self) @MyInline
{
	return (!self.audio_playing() && !self.paused);
}

<*
	@param loop : "should the video loop when it ends"
	@param audio : "should the video play audio"
*>
fn bool VidMovie.preparePlayer(&self, bool loop = false, bool audio = false) @nodiscard
{
    VideoFile? video = fs::openFile(self.path, fs::FILE_READ_BINARY);
	if(catch excuse = video ) {
		log::warning(FILE, "failed to open video %s to play with error: %s", self.name, excuse);
		return false;
	} else { // successfully opened video file
		assert(self.plyr == null); // player should be null at this time (I think...)
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
		log::info(FILE,
			"Opened %s - framerate: %f, samplerate: %d, duration: %f", 
			self.name, 
			self.framerate,
			self.samplerate,
			self.duration
		);

		// was doing this on updateFrame but is better here
		// has the frames are always the same size and format thoughout the video
		int w = self.plyr.get_width();
		int h = self.plyr.get_height();
		self.frame.width   = w;
		self.frame.height  = h;
		self.frame.mipmaps = 1;
		self.frame.format  = RLPixelFormat.UNCOMPRESSED_R8G8B8; // 24bits no alpha (todo support alpha?, HDR?)
		// compute stride (a single row of pixels or frame width in bytes)
		self.frame_stride  = w * BYTES_PER_PIXEL;
		// compute data size (how many rows make the full frame data in bytes)
		self.frame_data_size = self.frame_stride * h;

		// allocate memory buffer for frame data
		// NOTE(HM) do not use C3 memory allocator when manually 
		// creating memory for Raylib types! 
		// This is because using the unload functions from Raylib
		// will not work with C3 mem allocator and will crash the app.
		// In this particular cases, use the internal Raylib rl::memAlloc.
		//Uint8_t* fileData = (Uint8_t*)mem::malloc(self.frame_data_size);
		Uint8_t* fileData = (Uint8_t*)rl::memAlloc(self.frame_data_size);
		self.frame.data = fileData;

		self.frame_texture = rl::loadTextureFromImage(self.frame);

		// init video and audio decode callbacks
		plm::set_video_decode_callback(self.plyr, &on_video, self);
		plm::set_audio_decode_callback(self.plyr, &on_audio, self);

		self.plyr.set_loop((loop) ? TRUE : FALSE);
		self.enableAudio(audio);

		self.is_ready = true;
		//self.set_frame_settings = true;
	}

	return self.is_ready;
}

fn void VidMovie.resetTime(&self, int time = 0) 
{
	/*
	//self.startTime = ( backEnd.viewDef ) ? 1000 * backEnd.viewDef->floatTime : -1;
	self.startTime = gpGame.time_ms;
	self.start();
	//status = FMV_PLAY;
	*/
}

// Todo support video pausing
const DEBUG_VIDEO = 1;
fn void VidMovie.update(&self)
{
	if(!self.should_play || !self.started) return;

	assert(self.is_ready == true);

	// Compute the delta time since the last update, limit max step to 
	// 1/framerate of a second
	double current_time = rl::getTime();
	double elapsed_time = current_time - self.time_since_last_call;
	if (elapsed_time > (1.0 / (double)self.framerate)) {
		elapsed_time = (1.0 / (double)self.framerate);
	}
	self.time_since_last_call = current_time;

	// Decode
	if(!self.plyr.has_ended()) {
		// decode both video and audio samples
		self.plyr.decode(elapsed_time);
		//if(self.plyr.get_time() < (current_time + elapsed_time)) self.update_video();
		//self.update_audio();
		$if $defined(DEBUG_VIDEO):
		self.frame_count++;
		$endif
		self.is_playing = true;
	} else {
		// Stop playback
		self.stop();
		self.is_playing = false;
	}
}

fn void VidMovie.start(&self) @MyInline
{
	self.started = !self.started;
    self.audio_play();
}

fn void VidMovie.stop(&self) @MyInline
{
	self.started = !self.started;
	self.audio_stop();
}

// TODO(HM) Right now I can't pause and unpause 
// a video need to learn how to do that first...
fn void VidMovie.pause(&self) @MyInline
{
	@todo();
	/*self.paused = true;
	if(self.audio_enabled() && self.audio_playing()) {
		self.audio_pause();
	}*/
}

fn void VidMovie.resume(&self) @MyInline
{
	@todo();
	/*self.paused = false;
	if(self.audio_enabled()) {
		if(self.audio_valid() && !self.audio_playing()) {
			self.audio_resume();
		}
	}*/
}
////////////////////////////////////////

fn void VidMovie.enable(&self) @MyInline => self.should_play = true;
fn void VidMovie.disable(&self) @MyInline => self.should_play = false;

fn void VidMovie.clear(&self) 
{
    self.path = "";
    self.name = "";
	if(self.plyr != null) 
	{
		// everything that needs the plyr has to be cleared here!!
		$if $defined(AUDIO_EMBEDED):
			if(self.audio_enabled() && self.audio_valid()) {
				if(self.audio_playing()) self.audio_stop();
					rl::unloadAudioStream(self.audio);
			}
		$endif
		self.plyr.destroy();
		self.plyr = null;
	}

	// need to manually free the RLImage data myself!??
	// theory: Maybe is because I used C3 new::malloc instead of Raylib memory allocator? 
    //freeFrameData(&self.frame, true);
	// NOTE(HM) Update I was right! After using raylib memAlloc function 
	// to allocate the buffer to the RLImage I was be able to use unloadImage and unloadTexture!
	rl::unloadImage(self.frame);
	if(rl::isTextureValid(self.frame_texture))
	{
		rl::unloadTexture(self.frame_texture);
	}

	$if $defined(AUDIO_SEPERATE):
	if(self.audio_enabled() && self.audio_valid()) {
		if(self.audio_playing()) self.audio_stop();
		rl::unloadMusicStream(self.audio);
	}
	$endif
}

fn void VidMovie.reset(&self) => self.clear();


//////////////////////////////////////////// VIDEO CABINET ////////////////////////////////////////////

alias VideoListPtr = List{VidMovie*};
// place to hold all videos
struct VideoCabinet @public
{
    String movies_folder;
    VideoListPtr movies;
}

fn void setCabinetMoviesDirectory(VideoCabinet* self, String movies_dir) @local @MyInline
{
    self.movies_folder = movies_dir.tcopy();
}

fn void initCabinetMoviesDirectory(VideoCabinet* self) @local @MyInline
{
	String videos_path = gpGame.app_base_folder.tconcat(VIDEOS_FOLDER_PATH);
	/*if(catch excuse = fs::makeDirectory_IfNotExist(videos_path)) {
		log::error(FILE, "failed to create videos directory at path: %s with excuse %s", videos_path, excuse);
	}*/
    setCabinetMoviesDirectory(self, videos_path);
}

<*
	Create and initialize a video cabinet
	@param [inout] vidc : "pointer to the video cabinet"
*>
fn void? initVideoCabinet(VideoCabinet** vidc) @public
{
	(*vidc) = mem::new(VideoCabinet);
	initCabinetMoviesDirectory((*vidc));
	if(catch excuse = (*vidc).registerVideos()) {
		log::error(FILE, "failed to register videos inside video cabinet with excuse %s.",  excuse);
		(*vidc).movies_folder = "";
		mem::free((*vidc));
		vidc = null;
	}
}

fn void VideoCabinet.addMovie(&self, VidMovie* movie) @MyInline
{
	self.movies.push(movie);
}

fn void? VideoCabinet.registerVideos(&self) 
{
    assert(self.movies_folder != "");

    if(fs::makeDirectory_IfNotExist(self.movies_folder)!!)
    {
        RLFilePathList files = fs::loadDirectoryFiles(self.movies_folder);
        defer {
            if(files.count) fs::unloadDirectoryFiles(files);
        };

        if(files.count)
        {
            for(int i = 0; i < files.count; i++)
            {
				String path_view = files.paths[i].str_view();
                if(fs::isFile(path_view))
                {
					//fs::getFileExtension(path_view)
                    if(path_view.ends_with(EXTENSION_MPG) || path_view.ends_with(EXTENSION_MPEG)) {
						String vid_name = fs::getFileNameWithoutExt(path_view);
						if(self.hasMovie(vid_name)) continue;
                        self.addMovie(
                            mem::new(VidMovie, {
                                .path = path_view.tcopy(),
                                .name = vid_name.tcopy(),
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

fn bool VideoCabinet.hasMovie(&self, String name) @MyInline
{
	return (self.movies.len() != 0 && self.getMovie(name) != null) ? true : false;
}

// todo return a default error video maybe?
fn VidMovie* VideoCabinet.getMovie(&self, String vid_name)
{
    foreach(movie : self.movies) {
        if(movie.name == vid_name) {
            return movie;
		}
    }
    return null;
}

fn void VideoCabinet.update(&self) @MyInline
{
	if(!self.movies.len()) return;
	foreach(movie : self.movies) {
        movie.update();
    }
}

fn void VideoCabinet.draw(&self) @MyInline
{
	if(!self.movies.len()) return;

	// update video frame for each video in cabinet library
	foreach(movie : self.movies) {
		movie.draw();
	}
}

<*
    @param [&inout] vidc : "pointer to the video player"
*>
fn void deinitVideoCabinet(VideoCabinet* vidc) @public
{
    if(vidc.movies.len()) {
        foreach(movie : vidc.movies) {
            movie.clear();
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
	Required video callback for decoding (cannot change function sigture)

	@param [&in] mpeg : "pointer to the mpeg player"
	@param [&in] frame : "pointer to the decoded frame"
	@param [&in] user : "pointer to some user data"
*>
fn void on_video(VideoPlayer* mpeg, PLMframe *frame, void *user) 
{
	//log::fatal(CONSOLE, "this should run!!!!");
	//@debug_break(ON);
	var video @safeinfer = (VidMovie*)user;
    video.updateFrame(frame);
}

<*
	Required audio callback for decoding (cannot change function sigture)

	@param [&in] mpeg : "pointer to the mpeg player"
	@param [&in] samples : "pointer to the decoded audio samples"
	@param [&in] user : "pointer to some user data"
*>
fn void on_audio(VideoPlayer* mpeg, PLMsamples *samples, void *user) 
{
	var video @safeinfer = (VidMovie *)user;
	video.updateAudio(samples);
}
