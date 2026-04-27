module game::intro;

// region modules
import std::io;
import std::math;
import std::core::mem; // for malloc
import std::collections::list;
import game::main;
import engine::gui;
import game::gui::menu;
import engine::misc;
import engine::input;
import thirdparty::raylib5::rl;
import engine::logging::log;
import engine::sys::cvar;
import engine::sys::render2d::r2d; // 2D rendering
import engine::sys::videoplay::vid @public;
// end_region

// region defines
alias FrameQueue = List{Frame*};
//const FADE_FRAMES = true; // comment this to disable the fade effect
alias pGame = game::gpGame;
// end_region

// region constants
const EPILEPSY_TEXT_DURATION = 12000; // ms
const FADE_IN_TIME     = 5000; // ms
const VISIBLE_DURATION = 2000;
const FADE_OUT_TIME    = 5000; // ms
const FRAME_TIME       = FADE_IN_TIME + VISIBLE_DURATION + FADE_OUT_TIME; // ms
const FADE_IN_SPEED    = 0.005f;
const FADE_OUT_SPEED   = 0.006f;
const FONT_SPACING     = 3.0f;
// end_region

// region cvars
CVar skip @public = { "skip_intro", CvFlag.BOOL, "0", "skip displaying the intro" };

fn void register_cvars() @public 
{
    cvar::@register(&skip);
}
// end_region

constdef FrameKind : inline int 
{
	NONE = 0,
	COLOR,
	IMAGE,
	VIDEO
}

struct Frame @local 
{
    RLTexture2D texture; // @deprecated
	FrameKind kind; 
	VidMovie* movie @if($feature(VIDEO_PLAYBACK_ENABLE));
    int duration;
	struct text // @deprecated
	{
		String msg;
		RLFont* font;
		Vec2f pos;
		float font_size;
		float spacing;
		RLColor color;
	}
    RLRectangle source_rect;
    RLRectangle dest_rect;
    RLColor color; // @deprecated
    int fade_in_start_time; // @deprecated
    int fade_out_start_time; // @deprecated
    bool fade_in_done; // @deprecated
    bool fade_out_done; // @deprecated
}

<*
    @param [&inout] frame : "frame to deinitialize"
*>
fn void deinit_frame(Frame* frame) @local
{
	switch
	{
		case frame.kind == COLOR:
            @todo();
		case frame.kind == IMAGE:
			if(rl::isTextureValid(frame.texture)) 
			{
				rl::unloadTexture(frame.texture);
			}
		case frame.kind == VIDEO:
			$if $feature(VIDEO_PLAYBACK_ENABLE):
				if(frame.movie != null) {
					if(frame.movie.is_playing) frame.movie.stop();
					frame.movie = null;
				}
			$endif
		default: unreachable("Invalid kind of frame for intro animation.");
	}
	// now free the frame itself
    mem::free(frame);
    frame = null;
}

<*
    @param [&inout] frame : "frame to draw"
*>
fn void draw(Frame* frame) @local
{
	switch
	{
		case frame.kind == COLOR:
			r2d::@drawRect(frame.dest_rect, frame.color);
		case frame.kind == IMAGE:
			if(rl::isTextureValid(frame.texture)) {
				rl::drawTexturePro(frame.texture, frame.source_rect, frame.dest_rect, {0, 0}, 0.0f, frame.color);
			}
		case frame.kind == VIDEO:
			$if $feature(VIDEO_PLAYBACK_ENABLE):
				if(frame.movie != null) {
					frame.movie.draw();
				}
			$endif
		default: unreachable("Invalid kind of frame for intro animation.");
	}

	if(frame.text.msg != "") {
		frame.text.font = game::gpGame.candara_font;
		frame.text.font_size = 20.0f;
		frame.text.spacing = 1.0f;
		frame.text.color = rl::LIME;
		rl::drawTextEx(
            font : *frame.text.font,
            text : string::tformat_zstr("%s", frame.text.msg),
            position : frame.text.pos, 
			fontSize : frame.text.font_size,
			spacing  : frame.text.spacing,
			tint : frame.text.color,
        );
	}
}

struct IntroAnimation 
{
   FrameQueue frames;
   int current_frame_index;
   int full_duration;
   bool should_play;
   bool timing_initialized;
}

<*
    @param [&inout] anim : "animation to push the frame into"
    @param texture_path : "path to the texture used as the frame image, always starting at images folder"
*>
fn void makeTexturedFrame(String texture_path, IntroAnimation* anim) @local 
{
    /*
	int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    ZString path = game::gpGame.app_base_folder.tconcat(texture_path).zstr_tcopy();
    Frame* frame = mem::new(Frame);
    frame.texture = rl::loadTexture(path);
    assert(rl::isTextureValid(frame.texture));
	frame.kind = IMAGE;
    frame.source_rect = {0, 0, frame.texture.width, frame.texture.height};
	frame.dest_rect = {0, 0, w, h};
	rl::setTextureFilter(frame.texture, RLTextureFilter.BILINEAR);
    rl::setTextureWrap(frame.texture, RLTextureWrap.CLAMP);
    frame.color = rl::WHITE;
    $if($defined(FADE_FRAMES)):
    frame.color.a = 0; // start with a transparent frame for fade in
    $endif
    anim.frames.push(frame);
	*/
}

<*
    @param [&inout] anim : "animation to push the frame into"
*>
fn void makeTextFrame(IntroAnimation* anim, String message = "undefined", RLColor _color = rl::CTRANSPARENT) @local 
{
    /*
	int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    Frame* frame = mem::new(Frame);
	frame.text.msg = message;
	frame.dest_rect = {0, 0, w, h};
    frame.color = _color;
    $if($defined(FADE_FRAMES)):
    frame.color.a = 0; // start with a transparent frame for fade in
    $endif
    anim.frames.push(frame);
	*/
}

<*
    @param [&inout] anim : "animation to push the frame into"
*>
fn void makeColorFrame(RLColor _color, IntroAnimation* anim) @local 
{
	int w = game::gpGame.screen.w;
    int h = game::gpGame.screen.h;
    Frame* frame = mem::new(Frame);
	frame.dest_rect = {0, 0, w, h};
    frame.color = _color;
    anim.frames.push(frame);
}

<*
    @param [&inout] anim : "animation to push the frame into"
	@param _audio : "enable audio for video"
*>
fn void makeVideoFrame(String video_name, IntroAnimation* anim, bool _audio = false, String audio_name = "") @local @if($feature(VIDEO_PLAYBACK_ENABLE))
{
    int w = game::gpGame.screen.w;
    int h = game::gpGame.screen.h;
	bool failed;
    Frame* frame = mem::new(Frame);
	defer if(failed) {
		log::warning(FILE, "\tCannot create frame video '%s' for intro!", video_name);
		mem::free(frame);
		frame = null;
	}
	frame.kind  = VIDEO;
	frame.movie = game::vidCabinet.getMovie(video_name);
    if(frame.movie == null) failed = true;
	
	if(failed) {
		// do nothing and go on to the defer code
	} else {
		$if $defined(vid::AUDIO_SEPERATE):
		if(_audio) frame.movie.track_name = (audio_name) ? audio_name : "default.mp3";
		$endif
		if(frame.movie.preparePlayer(audio: _audio)) {
			frame.movie.fullscreen = true;
            frame.movie.enable();
			anim.frames.push(frame);
		} else {
			log::warning(FILE, "\tFailed to prepare player for frame video '%s' for intro animation!", video_name);
			failed = true;
		}
	}
}


constdef FrmIndex : inline int
{
	EPILEPSY = 0,
	RAY_LOGO,
	HM_LOGO
}

// Warning(HM) make sure to create the frames in the order
// of the FrmIndex above!!!!
// Also audio for videos is broken so don't use it. :(
fn void initAnimation(IntroAnimation* anim) @local
{
	makeVideoFrame("epiwarn", anim);
	//makeVideoFrame("test_credits", anim, _audio: true);
	//makeVideoFrame("hm_logo", anim, _audio: true, audio_name: "hm_logo_audio.ogg");
	makeVideoFrame("hm_logo", anim);
	makeVideoFrame("ray_intro", anim);
    input::makeKeyboardAction("skipIntro", rl::KEY_ESCAPE);
    input::@makeAction({.name = "skipFrame", .kind = KEYBOARD, .key1 = rl::KEY_SPACE});
}

fn void deinitAnimation(IntroAnimation* anim) @local
{
    foreach(frame : anim.frames) {
        if(frame) {
            deinit_frame(frame);
        }
    }
    input::removeAction("skipIntro");
    input::removeAction("skipFrame");
}

fn void hide_cursors() @local @inline
{
    if(game::game_cursor_visible()) game::hide_game_cursor();
    if(game::gpGame.screen.state.fullscreen || 
       game::gpGame.screen.state.borderless) 
    {
        if(game::system_cursor_enabled()) game::disable_system_cursor();
    }
}

<*
     /*if(frame.kind != VIDEO) {
            frame.duration = time_ms + FRAME_TIME;
        }*/

    @param [&inout] anim : "animation to handle"
*>
fn void init_anim_timing(IntroAnimation* anim, int time_ms) @local
{
    int old_frame_duration;
	foreach(frame : anim.frames) {
        if(frame.kind != VIDEO) {
            unreachable("non video frames for intro not supported anymore!!!");
        }
        if(frame.movie == null) {
            $if $feature(_DEBUG):
                unreachable();
            $else
                continue; // skip frames with no video
            $endif
        }

        frame.duration = time_ms + old_frame_duration + (int)math::ceil(frame.movie.duration * 1000);
        old_frame_duration = frame.duration;
        anim.full_duration += frame.duration;
    }
    anim.timing_initialized = true;
}

<*
    @param [&inout] anim : "animation to handle"
*>
fn void play(IntroAnimation* anim) 
{
    anim.should_play = true;
    menu::stop(); // if any menu is up close it
    setup(anim);
}

<*
    @param [&inout] anim : "animation to handle"
*>
fn void setup(IntroAnimation* anim) @local 
{
    hide_cursors();
    initAnimation(anim);
    //log::info(CONSOLE, "intro-setup: %s", game::gpGame.time_ms);
}

fn void IntroAnimation.stop(&self)
{
    self.should_play = false;
    deinitAnimation(self);
    game::gpGame.mode = GameMode.NONE;
     // goes to the main menu;
    game::disconnect();
}

fn void IntroAnimation.loop(&self) @inline 
{
    if(self.current_frame_index) self.current_frame_index = 0;
}

fn void IntroAnimation.loop_frame(&self, uint idx) @inline 
{
    if(self.current_frame_index != idx) self.current_frame_index = idx;
}

<*
    @param [&inout] anim : "animation to update"
*>
fn void update(IntroAnimation* anim)
{
	if(!anim.should_play) return;

    Frame* current_frame @noinit;
    game::gpGame.mode = GameMode.INTRO;

	int current_time = game::gpGame.time_ms;

    // init frames durations has to be done here because it 
    // requires the current time for each frame
    if(!anim.timing_initialized) {
        init_anim_timing(anim, current_time);
        log::info(CONSOLE, "intro-timing-init: %s", current_time);
    }

    if(current_time >= anim.full_duration || input::getAction("skipIntro").fnBecameTriggered()) {
        anim.stop();
        return;
    }

    current_frame = anim.frames[anim.current_frame_index];

    // trigger the first frame
    if(current_time < current_frame.duration && !current_frame.movie.is_playing) 
    {
        current_frame.movie.start();
    }

    // skip frames
    if(input::getAction("skipFrame").fnBecameTriggered()) {
        anim.current_frame_index += 1; // go to next frame
        current_frame = null;
        if(anim.current_frame_index >= anim.frames.len()) {
            anim.current_frame_index = 0;
            anim.stop();
            return;
        }
    }
    
    // if a single frame
    if(anim.frames.len() == 1) {
        // go on displaying the same frame for the duration of the animation
        anim.loop_frame(0);
    }
    else // change frame after a time
    {
        if(!current_frame) current_frame = anim.frames[anim.current_frame_index];

        switch(current_frame.kind)
        {
            case IMAGE: // @deprecated...
                if(current_frame.fade_out_done) {
                    anim.current_frame_index++;
                    if(anim.current_frame_index >= anim.frames.len()) {
                        anim.current_frame_index = 0;
                        anim.stop();
                    } else {
                        // set next frame fade in start time
                        // index was updated above already
                        // so idx here already means the next frame index
                        int idx = anim.current_frame_index;
                        anim.frames[idx].fade_in_start_time = current_time;
                    }
                }
            case VIDEO:
                $if $feature(VIDEO_PLAYBACK_ENABLE):
                    if(current_time > current_frame.duration) {
                        anim.current_frame_index += 1; // go to next frame
                        if(anim.current_frame_index >= anim.frames.len()) {
                            anim.current_frame_index = 0;
							anim.stop();
        					return;
                        }
                        // start the next frames
                        anim.frames[anim.current_frame_index].movie.start();
                    } else {
                        // update the current video frames and audio if any
                        if(current_frame.movie != null) {
                            current_frame.movie.update();
                        }
                    }
                $endif
            case COLOR: break;
            default: unreachable("None or Unrecognized frame kind!!!");
        }
    }
}

<*
    @param [&inout] anim : "animation to play"
    @require anim.frames.len() > 0
*>
fn void drawAnimation(IntroAnimation* anim) @if(!$defined(FADE_FRAMES))
{
	if(!anim.should_play) return;

    // draw a full screen black frame to hide the stuff behind it
    r2d::drawRectangleRec({0,0,game::gpGame.screen.w, game::gpGame.screen.w}, rl::BLACK);

    int current_time = game::gpGame.time_ms;
    // current frame
    Frame* frame = anim.frames[anim.current_frame_index];
    draw(frame);

    { // debug code
        rl::drawText(string::tformat_zstr("Frame: %s", frame.movie.name), 50, 100, 16, rl::RED);
        rl::drawText(string::tformat_zstr("time: %s", current_time), 50, 118, 16, rl::RED);
        rl::drawText(string::tformat_zstr("frame: %s", anim.current_frame_index), 50, 136, 16, rl::RED);
        rl::drawText(string::tformat_zstr("frame duration: %s", frame.duration), 50, 154, 16, rl::RED);
    }
}

float alpha @local @if($defined(FADE_FRAMES)) = 0.0f;
bool should_fade_in @local @if($defined(FADE_FRAMES)) = false;
bool should_fade_out @local @if($defined(FADE_FRAMES)) = false;
<*
	@deprecated
    @param [&inout] anim : "animation to play"
    @require anim.frames.len() > 0
*>
fn void drawAnimation(IntroAnimation* anim) @if($defined(FADE_FRAMES))
{
    int current_time = game::gpGame.time_ms;
    int w = game::gpGame.screen.w;
    int h = game::gpGame.screen.h;

    // only if frame is not a video...
    if(anim.frames[anim.current_frame_index].kind != VIDEO) {
        // draw a black rect as background to prevent seeing the clear color of the screen
		r2d::@drawRect({0, 0, w, h}, rl::BLACK);
	}

    { // draw frames
        if(anim.frames.len() == 0) return;
        
        // current frame
        Frame* frame = anim.frames[anim.current_frame_index];

        if(frame.kind == IMAGE)
        {
            if(!frame.fade_in_done) {
                alpha = misc::move_toward(alpha, 1.0f, FADE_IN_SPEED);
                if(alpha > 1.0f) alpha = 1.0f;
                frame.color.a = (char)(alpha * 255);
                //frame.color = rl::colorLerp(frame.color, rl::WHITE, 0.05f);
                //log::info(CONSOLE, "fading IN");
                //log::info(CONSOLE, "color alpha: %d", frame.color.a);
                // if fade in is done, mark it as done
                if(frame.color.a == 255) {
                    //log::info(CONSOLE, "STOP fading IN");
                    frame.fade_in_done = true;
                    frame.fade_out_start_time = current_time + VISIBLE_DURATION;
                    //should_fade_in = false;
                }
            }

            //io::printfn("RLColor = %s", misc::printColor(anim.frames[anim.current_frame_index].image.color));
        
            if(frame.fade_in_done && !frame.fade_out_done && current_time >= frame.fade_out_start_time) {
                alpha = misc::move_toward(alpha, 0.0f, FADE_OUT_SPEED);
                if(alpha < 0.0f) alpha = 0.0f;
                frame.color.a = (char)(alpha * 255);
                if(frame.color.a == 0) {
                    frame.fade_out_done = true;
                    alpha = 0.0f;
                    //should_fade_out = false;
                }
            }
        }

        draw(frame);

        { // debug code
            rl::drawText(string::tformat_zstr("time: %s", current_time), 50, 100, 16, rl::RED);
            rl::drawText(string::tformat_zstr("frame: %s", anim.current_frame_index), 50, 118, 16, rl::RED);
            /*rl::drawText(string::tformat_zstr("frame color: {%s,%s,%s,%s}", 
            frame.color.r,
            frame.color.g,
            frame.color.b,
            frame.color.a), 
            50, 134, 16, rl::RED);*/
            if(frame.kind == IMAGE)
            {
                rl::drawText(string::tformat_zstr("frame st time: %s", frame.fade_out_start_time), 50, 150, 16, rl::RED);
            } else {
                rl::drawText(string::tformat_zstr("frame duration: %s", frame.duration), 50, 150, 16, rl::RED);
            }
        }
    }
}


// unused but saved code

/*fn void drawEpilepsyWarning(int w, int h) @local //@deprecated("use the new mpg video instead")
{
	/////////
	// Title
	float title_size = 0.05f*h;
	RLFont* _font  = pGame.candara_font;
	float fontSize = title_size;
	ZString text   = string::tformat_zstr("%s", "PHOTOSENSITIVITY / EPILEPSY SEIZURES");
    Vec2f textDimensions = rl::measureTextEx(*_font, text, fontSize, FONT_SPACING);
	float textlen  = textDimensions.x;
    float x_pos, y_pos;
    x_pos = (float)(w / 2) - (float)(textlen / 2);
    y_pos = 0.25f * h;
	rl::drawTextEx(
            font : *_font,
            text : text,
            position : {.x = x_pos, .y = y_pos},
			fontSize : fontSize,
			spacing  : FONT_SPACING,
			tint : rl::RED,
        );
	///////////
    // Subtile
    _font    = pGame.candara_light_font;
	fontSize = 0.85f*title_size;
	text     = string::tformat_zstr("%s", "READ THIS NOTICE BEFORE PLAYING");
    textDimensions = rl::measureTextEx(*_font, text, fontSize, FONT_SPACING);
	textlen  = textDimensions.x;
	// NOTE(HM) xpos here this is not the same as the x_pos value above
	// textlen in this case is the subtitle len (see lines of code above this comment)
    x_pos = (float)(w / 2) - (float)(textlen / 2);
	y_pos = y_pos + textDimensions.y;
	rl::drawTextEx(
            font : *_font,
            text : text,
            position : {.x = x_pos, .y = y_pos},
			fontSize : fontSize,
			spacing  : FONT_SPACING,
			tint : rl::RED,
        );
	///////////
    // Message
    const MESSAGE = 
    `
	A percentage of people may experience epileptic seizures when exposed to certain kinds of flashing lights.
	Even people with no history of epilepsy, may experience epileptic symptoms or seizures while playing.
	If you or any of your relatives has an epileptic condition or had seizures of any kind, consult your physician 
	before playing this game.
	
	If you or your children experience any of the following symptoms while playing:
		dizziness, altered vision, eye or muscle twitching,
		involuntary movements, loss of awareness, disorientation, or convulsions.
	IMMEDIATELY STOP and consult a physician.
	Parents should watch for or ask their children about the above symptoms.
	You may reduce risk of photosensitive epileptic seizures by taking the following precautions:
		sit farther from the screen, use a smaller screen, play in a well-lit room,
		do not play when you are drowsy or fatigued.`;
	

    _font    = pGame.trojan_pro_font;
	text     = string::tformat_zstr("%s", MESSAGE); 
	fontSize = 0.50f*title_size;
    textDimensions = rl::measureTextEx(*_font, text, fontSize, FONT_SPACING);
	if(textDimensions.x > h) {
		fontSize = 0.75f*fontSize;
    	textDimensions = rl::measureTextEx(*_font, text, fontSize, FONT_SPACING);
	}
	textlen  = textDimensions.x;
    x_pos = (float)(w / 2) - (float)(textlen / 2);
	//if((x_pos + textlen) > h) x_pos -= 0.02f*textlen;
	y_pos = y_pos + (0.35f * textDimensions.y);
	rl::@setTextLineSpacing(6) 
	{
		rl::drawTextEx(
				font : *_font,
				text : text,
				position : {.x = x_pos, .y = y_pos},
				fontSize : fontSize,
				spacing  : FONT_SPACING,
				tint : rl::RAYWHITE,
			);
	};
}
*/


