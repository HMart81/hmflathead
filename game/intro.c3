module game::intro;

// region modules
import std::io;
import std::core::mem; // for malloc
import std::collections::list;
import game::main;
import engine::gui;
import engine::input;
import raylib5::rl;
import game::serialize::svs; // save system
import game::low_level::cvar;
// end_region

// region defines
def FrameQueue  = List(<Frame*>);
// end_region

// region constants
const DEFAULT_SHOW_TIME = 3000; // ms
// end_region

// region cvars
Cvar intro_skip @public = { "intro_skip", CvarType.BOOLEAN, "0", "skip displaying the intro" };

fn void register_cvars() @public {
    cvar::@register(&intro_skip);
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

   bool should_play;
}

fn void IntroAnimation.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void IntroAnimation.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void initIntroAnimation(IntroAnimation* anim) {
    Frame* frame1 = mem::new(Frame);
    frame1.image  = mem::new(Panel);
    frame1.image.initV({0,0}, {main::gpGame.screen.w, main::gpGame.screen.h},  rl::WHITE);
    frame1.image.setTexture(main::asstManager.getTexture("logo_hm.png"));
    frame1.draw_time = DEFAULT_SHOW_TIME;
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

fn void triggerIntroAnimation(IntroAnimation* anim) {
    if(intro_skip.getBool()) return;
    
    anim.should_play = true;
}

fn bool updateIntroAnimation(IntroAnimation* anim) {
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
            anim.current_frame.image.update();
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
}

fn void drawIntroAnimation(IntroAnimation* anim) {
    if(anim == null) return;
    
    if(anim.current_frame) {
        anim.current_frame.image.draw();
    }
}


/*

fn void start_button_onOver(Widget* button) {
    //main::lgr::info(Where.CONSOLE, "Main Menu: I'm Over button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).over_color;
}

fn void start_button_onStopOver(Widget* button) {
    main::lgr::info(Where.CONSOLE, "Main Menu: Got out off button: %s", button.name);
}

fn void start_button_onRelease(Widget* button) {
    main::lgr::info(Where.CONSOLE, "Main Menu: Released button: %s", button.name);
}

fn void start_button_onPress(Widget* button) {
    //main::lgr::info(Where.CONSOLE, "Main Menu: I'm pressing button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).pressed_color;
}

fn void start_button_onSinglePress(Widget* button) {
    WidgetButton* btn = ((WidgetButton*)button);
    main::lgr::info(Where.CONSOLE, "Main Menu: I pressed button: %s once.", btn.name);
    if(/*!btn.sound_played && */rl::isSoundValid(*btn.interaction_sound)) {
        rl::playSound(*btn.interaction_sound);
        //btn.sound_played = true;
    }
}


