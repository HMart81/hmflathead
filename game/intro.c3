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
alias FrameQueue  = List{Frame*};
// end_region

// region constants
const FADE_IN_TIME     = 2000; // ms
const VISIBLE_DURATION = 3000;
const FADE_OUT_TIME    = 2000; // ms
const FRAME_TIME       = FADE_IN_TIME + VISIBLE_DURATION + FADE_OUT_TIME; // ms
// end_region

// region cvars
Cvar skip_intro @public = { "skip_intro", CvarType.BOOL, "1", "skip displaying the intro" };

fn void register_cvars() @public 
{
    cvar::@register(&skip_intro);
}
// end_region

struct Frame @local 
{
    gui::Panel* image;
    int fade_in_time;
    int fade_out_time;
    bool fade_in_done;
    bool fade_out_done;
}

struct IntroAnimation 
{
   FrameQueue frames;
   
   int current_frame_index;
   int next_frame_time;
   int duration;
   
   bool should_play;
   bool timing_initialized;
}

macro makeFrame(String material_name, IntroAnimation* anim) @local {
    int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    Frame* frame = mem::new(Frame);
    frame.image  = mem::new(Panel);
    frame.image.initV({0,0}, {w,h},  {0xFF,0xFF,0xFF,0} /*rl::WHITE*/);
    frame.image.setMaterial(material_name);
    frame.fade_in_time  = FADE_IN_TIME;
    frame.fade_out_time = FADE_IN_TIME;
    anim.frames.push(frame);
}

fn void initAnimation(IntroAnimation* anim) {
    makeFrame("gui/raylib_intro", anim);
    makeFrame("gui/logo", anim);
    //
    input::makeKeyboardAction("skipIntro", rl::KEY_ESCAPE);
}

fn void deinitAnimation(IntroAnimation* anim) {
    foreach(frame : anim.frames) {
        if(frame) {
            frame.image.deinit();
            frame.image = null;
            mem::free(frame);
        }
    }
    
    input::removeAction("skipIntro");
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
        // each frame duration
        anim.next_frame_time    = game::gpGame.time_ms + FRAME_TIME;
        // full anim duration
        int frames_amout = (int)anim.frames.len();
        anim.duration           = game::gpGame.time_ms + (frames_amout * FRAME_TIME);
        anim.timing_initialized = true;
        foreach(&frame : anim.frames)
        {
            (*frame).fade_in_time  += game::gpGame.time_ms;
            (*frame).fade_out_time += game::gpGame.time_ms;
        }
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
    if(game::gpGame.time_ms >= anim.duration || input::getAction("skipIntro").fnBecameTriggered()) {
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
        //if(anim.current_frame_index > anim.frames.len()) loop(anim);
        // no more frames to play get out
        if(anim.current_frame_index >= anim.frames.len()) {
            anim.stop();
            return;
        }

        // else set next frame index to play after the required time
        if(game::gpGame.time_ms >= anim.next_frame_time) {
            anim.current_frame_index++;
            anim.next_frame_time = game::gpGame.time_ms + FRAME_TIME;
        }
    }
}

fn void drawAnimation(IntroAnimation* anim, int w, int h) {
    if(anim == null) return;
    
    //misc::@drawRect({0, 0, w, h}, (RLColor){0x18, 0x18, 0x18, 0xFF});
    r2d::@drawRect({0, 0, w, h}, rl::BLACK);

    /*foreach(&frame : anim.frames)
    {
        (*frame).fade_in_time  += game::gpGame.time_ms;
        (*frame).fade_out_time += game::gpGame.time_ms;
    }*/

    Frame* frame = anim.frames[anim.current_frame_index];
    int current_time = game::gpGame.time_ms;
    if(!frame.fade_in_done && current_time <= frame.fade_in_time) {
        frame.image.fadeIn(0.5f);
    } else {
        if(!frame.fade_in_done) frame.fade_in_done = true;
    }
    
    //io::printfn("RLColor = %s", misc::printColor(anim.frames[anim.current_frame_index].image.color));
    if(frame.fade_in_done) frame.image.draw();
    
    if(frame.fade_in_done && !frame.fade_out_done && game::gpGame.time_ms <= frame.fade_out_time) {
        frame.image.fadeOut(0.5f);
    } else {
        if(!frame.fade_out_done) frame.fade_out_done = true;
    }
}


