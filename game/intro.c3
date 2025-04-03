module game::intro;

// region modules
import std::io;
import std::core::mem; // for malloc
import std::collections::list;
import game::main;
import engine::gui;
import engine::input;
import thirdparty::raylib5::rl;
import game::serialize::svs; // save system
import game::low_level::cvar;
// end_region

// region defines
alias FrameQueue  = List{Frame*};
// end_region

// region constants
const FRAME_TIME = 1000; // ms = 1 sec
const SHOW_TIME = 5000; // ms 
// end_region

// region cvars
Cvar skip_intro @public = { "skip_intro", CvarType.BOOLEAN, "0", "skip displaying the intro" };

fn void register_cvars() @public {
    cvar::@register(&skip_intro);
}
// end_region

struct Frame @local {
    gui::Panel* image;
    int draw_time;
    int start_time;
    int end_time;
}

struct IntroAnimation (SaveSystemInterface) {
   FrameQueue frames;
   Frame* current_frame;

   int fade_in_time;
   int fade_out_time;
   int current_frame_index;
   int next_start_time;
   
   bool should_play;
}

fn void IntroAnimation.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void IntroAnimation.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void initIntroAnimation(IntroAnimation* anim) {
    /*anim.frames.reserve(60);
    for(int i = 0; i < 60; i++) {
        Frame* frame = mem::new(Frame);
        frame.image  = mem::new(Panel);
        frame.image.initV({0,0}, {main::gpGame.screen.w, main::gpGame.screen.h},  rl::WHITE);
        frame.image.setTexture(main::asstManager.getTexture("logo_hm.png"));
        //
        anim.frames.push(frame);
    }*/
    Frame* frame1 = mem::new(Frame);
    frame1.image  = mem::new(Panel);
    frame1.image.initV({0,0}, {main::gpGame.screen.w, main::gpGame.screen.h},  rl::WHITE);
    frame1.image.setTexture(main::asstManager.getTexture("logo_hm.png"));
    frame1.draw_time = SHOW_TIME;
    //
    anim.frames.push(frame1);
    anim.current_frame = frame1;
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
}

fn void stop(IntroAnimation* anim) @inline {
    anim.should_play = false;
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
        
        if(main::gpGame.time_ms >= SHOW_TIME || stop_anim ) {
            stop(anim);
            return false;
        }
        
        if(anim.frames.len() > 1) {
            if(anim.current_frame_index > anim.frames.len()) loop(anim);
    
            if(main::gpGame.time_ms >= anim.next_start_time) {
                anim.current_frame_index++;
                anim.next_start_time = main::gpGame.time_ms + FRAME_TIME;
            }
        }
    }
    
    /*
    if(anim.should_play == false) return false;
    
    int index = 0;
    
    do {
        bool stop_anim = input::getAction("noIntro").fnBecameTriggered();
        
        int current_time = main::gpGame.time_ms;
        if (!stop_anim && anim.current_frame && index == 0) // first frame
        {
            anim.current_frame.start_time = current_time;
            anim.current_frame.end_time   = anim.current_frame.start_time + anim.current_frame.draw_time;
            continue;
        }

        if(!stop_anim && anim.current_frame && anim.current_frame.end_time > 0 && 
           current_time <= anim.current_frame.end_time)
        {
            return true;
        }
        else if(stop_anim) {
            if(anim.current_frame && anim.frames.len() > 1 && index < anim.frames.len()) {
                anim.current_frame = anim.frames[index += 1];
                anim.current_frame.start_time = main::gpGame.time_ms;
                anim.current_frame.end_time   = anim.current_frame.start_time + anim.current_frame.draw_time;
            } else {
                anim.current_frame = null;
            }
        }
    } while(anim.current_frame != null);
  
    // todo don't skip the entire intro?
    deinitIntroAnimation(anim);
    
    return false;
    */
}

fn void drawIntroAnimation(IntroAnimation* anim) {
    if(anim == null) return;
    
    /*if(anim.current_frame) {
        anim.current_frame.image.draw();
    }*/
    
    anim.frames[anim.current_frame_index].image.draw();
}


