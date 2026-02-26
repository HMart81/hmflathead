module game::intro;

// region modules
import std::io;
import std::core::mem; // for malloc
import std::collections::list;
import game::main;
import engine::gui;
import engine::misc;
import engine::input;
import thirdparty::raylib5::rl;
import game::serialize::svs; // save system
import engine::sys::cvar;
import engine::sys::render2d::r2d; // 2D rendering
// end_region

// region defines
alias FrameQueue = List{Frame*};
// end_region

// region constants
const FADE_IN_TIME     = 2000; // ms
const VISIBLE_DURATION = 2000;
const FADE_OUT_TIME    = 2000; // ms
const FRAME_TIME       = FADE_IN_TIME + VISIBLE_DURATION + FADE_OUT_TIME; // ms
// end_region

// region cvars
CVar skip_intro @public = { "skip_intro", CvarType.BOOL, "1", "skip displaying the intro" };

fn void register_cvars() @public 
{
    cvar::@register(&skip_intro);
}
// end_region

struct Frame @local 
{
    Panel* image;
    int fade_in_time;
    int fade_out_time;
    bool fade_in_done;
    bool fade_out_done;
}

<*
    @param [inout] frame : "frame to initialize"
    @param pos : "position of the frame on the screen"
    @param size : "size of the frame"
    @param color : "color of the frame (including alpha for fade in/out)"
*>
fn void init_frame(Frame* frame, Vec2f pos, Vec2f size, RLColor color) @local
{
	frame.image = mem::new(Panel);
	frame.image.initV(pos, size, color);
}

<*
    @param [&inout] frame : "frame to deinitialize"
*>
fn void deinit_frame(Frame* frame) @local
{
	frame.image.deinit();
	frame.image = null;
}

<*
    @param [&inout] frame : "frame to set material on"
    @param material_name : "name of the material to set on the frame"
*>
fn void setFrameMaterial(Frame* frame, String material_name) @local
{
	frame.image.setMaterial(material_name);
}

<*
    @param [&inout] frame : "frame to draw"
*>
fn void draw(Frame* frame) @local
{
	frame.image.draw();
}

struct IntroAnimation 
{
   FrameQueue frames;
   int current_frame_index;
   int next_frame_time;
   int full_duration;
   bool should_play;
   bool timing_initialized;
}

macro makeFrame(String material_name, IntroAnimation* anim) @local 
{
    int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    Frame* frame = mem::new(Frame);
    init_frame(frame, {0,0}, {w,h}, rl::WHITE);
    $if($defined(FADE_FRAMES)):
    frame.image.color.a = 0; // start with a transparent frame for fade in
    $endif
    setFrameMaterial(frame, material_name);
    anim.frames.push(frame);
}

fn void initAnimation(IntroAnimation* anim) 
{
    makeFrame("gui/raylib_intro", anim);
    makeFrame("gui/logo", anim);
    //
    input::makeKeyboardAction("skipIntro", rl::KEY_ESCAPE);
    input::@makeAction({.name = "skipFrame", .kind = KEYBOARD, 
		                .key1 = rl::KEY_SPACE});

    /*
    // test unurdered_remove
    List{int} a;
    a.reserve(5);
    a.push(1); a.push(2); a.push(3); a.push(4); a.push(5);
    log::info("Before unurdered_remove: %s", a);
    misc::unurdered_remove{int}(&a, 1); // remove the element at index 1 (value 2)
    log::info("After unurdered_remove: %s", a);*/
}

fn void deinitAnimation(IntroAnimation* anim) {
    foreach(frame : anim.frames) {
        if(frame) {
            deinit_frame(frame);
            mem::free(frame);
        }
    }
    
    input::removeAction("skipIntro");
    input::removeAction("skipFrame");
}

fn void hide_cursors() @local @inline
{
    if(game::game_cursor_visible()) game::hide_game_cursor();
    if(game::gpGame.screen.state.fullscreen || game::gpGame.screen.state.borderless) 
    {
        if(game::system_cursor_enabled()) game::disable_system_cursor();
    }
}

<*
    @param [&inout] anim : "animation to handle"
*>
fn void init_anim_timing(IntroAnimation* anim) @local @inline
{
    if(!anim.timing_initialized) {
        // full anim duration
        int frames_count = (int)anim.frames.len();
        anim.full_duration = game::gpGame.time_ms + (FRAME_TIME * frames_count);
        // set the next frame to show after the required time
        anim.next_frame_time = anim.full_duration - FRAME_TIME;
        foreach(int i, &frame : anim.frames)
        {
			if(i == 0) {
				(*frame).fade_in_time  = game::gpGame.time_ms;
				(*frame).fade_out_time = (*frame).fade_in_time + VISIBLE_DURATION;
				continue;
			}
            (*frame).fade_in_time  = game::gpGame.time_ms + (FRAME_TIME * i);
            (*frame).fade_out_time = (*frame).fade_in_time + VISIBLE_DURATION;
        }
        anim.timing_initialized = true;
    }
}

<*
    @param [&inout] anim : "animation to handle"
*>
fn bool play(IntroAnimation* anim) @inline {
    if(skip_intro.getBool()) return false;
    setup(anim);
    return true;
}

<*
    @param [&inout] anim : "animation to handle"
*>
fn void setup(IntroAnimation* anim) @inline @local {
    game::gpGame.mode = GameMode.INTRO;
    hide_cursors();
    init_anim_timing(anim);
    anim.should_play = true;
}

fn void IntroAnimation.stop(&self) @inline {
    game::gpGame.mode = GameMode.NONE;
    self.should_play = false;
}

fn void IntroAnimation.loop(&self) @inline {
    if(self.current_frame_index) self.current_frame_index = 0;
}

fn void IntroAnimation.loop_frame(&self, uint idx) @inline {
    if(self.current_frame_index != idx) self.current_frame_index = idx;
}

<*
    @param [&inout] anim : "animation to update"
*>
fn void update(IntroAnimation* anim)
{
    //  if animation played to the end or we skipped the intro
	int current_time = game::gpGame.time_ms;
    if(current_time >= anim.full_duration || input::getAction("skipIntro").fnBecameTriggered()) {
        anim.stop();
        return;
    }
    
    // if a single frame
    if(anim.frames.len() == 1) {
        // go on displaying the same frame for the duration of the animation
        anim.loop_frame(0);
    }
    else // change frame after a time
    {
        // if no more frames to play get out
        //if(anim.current_frame_index > anim.frames.len()) loop(anim);
        if(anim.current_frame_index >= anim.frames.len()) {
            anim.stop();
            return;
        }

        // else set next frame index to play after the required time
        if(current_time >= anim.next_frame_time) {
            anim.current_frame_index++;
            if(anim.current_frame_index >= anim.frames.len()) anim.current_frame_index = 0;
            anim.next_frame_time = current_time + FRAME_TIME;
        }
    }
}

const int FADE_FRAMES = 1; // set to 1 to enable fade in/out, 0 to disable
fn void drawAnimation(IntroAnimation* anim, int w, int h) @if(!$defined(FADE_FRAMES))
{
    if(anim == null) return;
	if(anim.frames.len() == 0) return;

	// draw a black rect as background to prevent seeing the clear color of the screen
    r2d::@drawRect({0, 0, w, h}, rl::BLACK);

	// draw current frame
    anim.frames[anim.current_frame_index].draw();
}

float alpha @local = 0.0f;
bool should_fade_in @local = false;
bool should_fade_out @local = false;
fn void drawAnimation(IntroAnimation* anim, int w, int h) @if($defined(FADE_FRAMES))
{
    if(anim == null) return;
	if(anim.frames.len() == 0) return;
    
	// draw a black rect as background to prevent seeing the clear color of the screen
    r2d::@drawRect({0, 0, w, h}, rl::BLACK);

	// draw current frame
    Frame* frame = anim.frames[anim.current_frame_index];
    int current_time = game::gpGame.time_ms;

    if(current_time == frame.fade_in_time) {
        should_fade_in = true;
    }
    else if(current_time == frame.fade_out_time) {
        should_fade_out = true;
    }

    if(should_fade_in && !frame.fade_in_done) {
		//frame.image.fadeIn(0.5f);
		// if we have an old frame and the current frame is still fading in, draw the old frame and fade in the current one on top of it
		//if(!frame.fade_in_done) {
			// current frame fade in
            //frame.image.color = rl::colorLerp(frame.image.color, rl::WHITE, 0.5f);
			//frame.image.color.a = (char)misc::move_toward((float)frame.image.color.a, 255.0f, 0.5f);
            alpha = misc::move_toward(alpha, 1.0f, 0.05f);
            frame.image.color = rl::fade(frame.image.color, alpha);
			// if fade in is done, mark it as done
			if(frame.image.color.a == 255) {
                frame.fade_in_done = true;
                should_fade_in = false;
                alpha = 0.0f;
            }
		//}
    }

    //io::printfn("RLColor = %s", misc::printColor(anim.frames[anim.current_frame_index].image.color));
    
    if(should_fade_out && frame.fade_in_done && !frame.fade_out_done) {
        //frame.image.fadeOut(0.5f);
        //frame.image.color = rl::colorLerp(frame.image.color, rl::CTRANSPARENT, 0.5f);
        alpha = misc::move_toward(alpha, 0.0f, 0.05f);
        frame.image.color = rl::fade(frame.image.color, alpha);
		// fade out current frame
		//frame.image.color.a = (char)(((float)(current_time - (frame.fade_out_time - FADE_OUT_TIME)) / FADE_OUT_TIME) * 255);
		if(frame.image.color.a == 0) {
            frame.fade_out_done = true;
            should_fade_out = false;
            alpha = 0.0f;
        }
    }

    draw(frame);
}


