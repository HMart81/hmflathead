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
// end_region

// region defines
alias FrameQueue  = List{Frame*};
// end_region

// region constants
const FADE_IN_TIME     = 1000; // ms
const VISIBLE_DURATION = 3000;
const FADE_OUT_TIME    = 1000; // ms
const FRAME_TIME       = FADE_IN_TIME + VISIBLE_DURATION + FADE_OUT_TIME; // ms
// end_region

// region cvars
Cvar skip_intro @public = { "skip_intro", CvarType.BOOLEAN, "0", "skip displaying the intro" };

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
}

struct IntroAnimation (SaveSystemInterface) 
{
   FrameQueue frames;
   
   int current_frame_index;
   int next_frame_time;
   int duration;
   
   bool should_play;
   bool timing_initialized;
}

fn void IntroAnimation.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void IntroAnimation.reload(&self, SaveFile* file) @dynamic {
// todo
}

macro makeFrame(String material_name, IntroAnimation* anim) @local {
    int w, h;
    w = main::gpGame.screen.w;
    h = main::gpGame.screen.h;
    Frame* frame = mem::new(Frame);
    frame.image  = mem::new(Panel);
    frame.image.initV({0,0}, {w,h},  {0xFF,0xFF,0xFF,0} /*rl::WHITE*/);
    frame.image.setMaterial(material_name);
    anim.frames.push(frame);
}

fn void initIntroAnimation(IntroAnimation* anim) {
    makeFrame("gui/raylib_intro", anim);
    makeFrame("gui/logo", anim);
    //
    input::makeKeyboardAction("noIntro", rl::KEY_ESCAPE);
}

fn void deinitIntroAnimation(IntroAnimation* anim) {
    foreach(frame : anim.frames) {
        if(frame) {
            frame.image.deinit();
            frame.image = null;
            mem::free(frame);
        }
    }
    
    input::removeAction("noIntro");
}

fn void play(IntroAnimation* anim) @inline {
    if(skip_intro.getBool()) return;
    
    anim.should_play = true;
    main::gpGame.mode = GameMode.INTRO;

    if(main::game_cursor_visible()) main::hide_game_cursor();
    if(main::gpGame.screen.state.fullscreen || main::gpGame.screen.state.borderless) 
    {
        if(main::system_cursor_enabled()) main::disable_system_cursor();
    }
    
    if(!anim.timing_initialized) {
        // each frame duration
        anim.next_frame_time    = main::gpGame.time_ms + FRAME_TIME;
        // full anim duration
        anim.duration           = main::gpGame.time_ms + (int)anim.frames.len() * anim.next_frame_time;
        anim.timing_initialized = true;
    }
}

fn void stop(IntroAnimation* anim) @inline {
    anim.should_play = false;
    main::gpGame.mode = GameMode.NONE;
}

fn void loop(IntroAnimation* anim) @inline {
    anim.current_frame_index = 0;
}

fn bool updateIntroAnimation(IntroAnimation* anim) {
    while(true) 
    {
        if(anim.should_play == false) {
            deinitIntroAnimation(anim);
            return false;
        }
        
        bool stop_anim = input::getAction("noIntro").fnBecameTriggered();
        
        if(main::gpGame.time_ms >= anim.duration || stop_anim ) {
            stop(anim);
            return false;
        }
        
        if(anim.frames.len() > 1) 
        {
            //if(anim.current_frame_index > anim.frames.len()) loop(anim);
            if(anim.current_frame_index >= anim.frames.len()) {
                stop(anim);
                continue;
            }
            
            // set next frame
            if(main::gpGame.time_ms >= anim.next_frame_time) {
                anim.current_frame_index++;
                anim.next_frame_time = main::gpGame.time_ms + FRAME_TIME;
            }
        }
    }
}

fn void drawIntroAnimation(IntroAnimation* anim, int w, int h) {
    if(anim == null) return;
    
    //misc::@drawRect({0, 0, w, h}, (Color){0x18, 0x18, 0x18, 0xFF});
    misc::@drawRect({0, 0, w, h}, rl::BLACK);
    
    if(main::gpGame.time_ms <= anim.next_frame_time - FADE_IN_TIME) {
        anim.frames[anim.current_frame_index].image.fadeIn(0.1f);
    }
    
    //io::printfn("Color = %s", misc::printColor(anim.frames[anim.current_frame_index].image.color));
    anim.frames[anim.current_frame_index].image.draw();
    
    if(main::gpGame.time_ms >= anim.next_frame_time - FADE_OUT_TIME) {
        anim.frames[anim.current_frame_index].image.fadeOut(0.1f);
    }
}


