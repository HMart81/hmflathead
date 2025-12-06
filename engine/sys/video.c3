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

// do not use incomplete :(
module engine::sys::videoplay::vid;

import game::main;
import std::io;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import std::collections::list;
import thirdparty::raylib5::rl;
import thirdparty::plmpeg::plm;

const VIDEO_FILE_EXTENSION = ".mpg";
const VIDEOS_FOLDER_PATH = "videos/";

alias gpGame = main::gpGame;

alias VideoFile = File;

const TRUE @local = 1;
const FALSE @local = 0;

struct VidMovie
{
    // this is done at init time
    String path;
    String name;
    CLong modtime; // modification time

    // this is done at play time
    PLM_t* plyr;
    float time_since_last_call;

    struct data {
        int samplerate; // for audio
        float framerate;
        float duration;
    }
}

fn void VidMovie.destroy(&self) {
    if(self.plyr) self.plyr.destroy();
    mem::free(self);
}

alias VideoListPtr = List{VidMovie*};

struct VideoPlayer
{
    String movies_folder;
    VideoListPtr movies;
}

fn VideoPlayer* initVideoPlayer(String movies_dir) {
    return mem::new(VideoPlayer, {.movies_folder = movies_dir.tcopy()});
}

fn void VideoPlayer.setVideosPath(&self, String path) => self.movies_folder = path;

fn bool VideoPlayer.play(&self, String vid_name, bool loop = false) 
{
    foreach(movie : self.movies) 
    {
        if(movie.name == vid_name) 
        {
            VideoFile? video = fs::openFile(movie.path, fs::FILE_READ_BINARY);
            if(catch excuse = video ) {
                log::warning(FILE, "failed to open video %s to play with error: %s", movie.name, excuse);
            } else {
                movie.plyr = plm::create_with_file(video.file, 0);
                if(movie.plyr == null) {
                    log::warning(FILE, "failed to create video player to play video: %s", movie.name);
                    return false;
                }

                if (!movie.plyr.probe(5000 * 1024)) {
                   log::warning(FILE, "No MPEG video or audio streams found in %s", movie.name);
                   unreachable();
                }

                movie.data.samplerate = movie.plyr.get_samplerate();
                movie.data.framerate = (float)movie.plyr.get_framerate();
                movie.data.duration = (float)movie.plyr.get_duration();

                vid::initDecodingSystem(movie);

                (loop) ? movie.plyr.set_loop(TRUE) : movie.plyr.set_loop(FALSE);
	            movie.plyr.set_audio_enabled(TRUE);
	            movie.plyr.set_audio_stream(0);

                // Decode
                do {
                    movie.plyr.decode(movie.time_since_last_call);
                    movie.time_since_last_call += gpGame.time_sec;
                } while (!movie.plyr.has_ended());
            }
        }
    }
    return false;
}

/*
fn VidMovie* create_movie_data(String filename) {
    VideoFile? video = fs::openFile(filename, fs::FileMode.READ_BINARY);
    if(catch video ) {
        log::warning(FILE, "failed to open video %s to play with error: %s", video);
    } else {
        //@todo();
        VidMovie* vid = mem::new(VidMovie);
        vid.data = video;
        vid.name = 
    }
    return null;
}
*/

fn void? VideoPlayer.registerVideos(&self) 
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
                        self.movies.push(
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

<*
    @param [&in] vidp : "pointer to the video player"
*>
fn void deinitVideoPlayer(VideoPlayer* vidp) {
    
    if(vidp.movies.len()) {
        foreach(movie : vidp.movies) {
            movie.destroy();
        }
        vidp.movies.clear();
    }
    mem::free(vidp);
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
fn void on_video(PLM_t mpeg, PLMframe *frame, void *user) {
	VidMovie *self = (VidMovie *)user;

    RLImage image;
    image.width     = self.plyr.get_width();
    image.height    = self.plyr.get_height();
    int pixel_count = image.width * image.height;
    const COLOR_CHANNELS = 3;
    //image.data = (Uint8_t)mem::malloc(pixel_count * COLOR_CHANNELS);
    frame.to_rgb((Uint8_t*)image.data, pixel_count * COLOR_CHANNELS);
    image.mipmaps = 1;
    image.format = rl::RLPixelFormat.UNCOMPRESSED_R8G8B8A8;

    rl::RLTexture2D texture = rl::loadTextureFromImage(image);
    //float duration = self.data.duration;
    rl::drawTexture(texture, texture.width, texture.height, rl::WHITE);
    //
    rl::unloadImage(image);
    rl::unloadTexture(texture);
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
    @param [&in] video : "pointer to a video"
*>
fn void initDecodingSystem(VidMovie * video) {
    plm::set_video_decode_callback(video.plyr, &on_video, video);
	plm::set_audio_decode_callback(video.plyr, &on_audio, video);
}