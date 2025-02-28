module game::gui::intro;

// region C3 modules
import std::io;
import std::core::mem; // for malloc
import std::collections::list;
// end_region

// region custom modules
import game::main;
import engine::input;
import raylib5::rl;
import game::serialize::svs; // save system
// end_region

// region defines
def FrameQueue  = List(<Frame*>);
// end_region

// region constants
const DEFAULT_SHOW_TIME = 3000; // ms
// end_region

struct Frame @local {
    gui::Panel_Image* image;
    int draw_time;
    int start_time;
    int end_time;
}

struct IntroAnimation (SaveSystemInterface) {
   FrameQueue frames;
   Frame* current_frame;
   
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
    frame1.image  = gui::makePanelImage(
    main::asstManager.getTexture("logo_hm.png"),
    {0, 0, main::gpGame.screen.w, main::gpGame.screen.h}, 
    rl::WHITE);
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
            gui::releasePanelImage(frame.image);
            frame.image = null;
            mem::free(frame);
        }
    }
    
    input::removeAction("noIntro");
}

fn void triggerIntroAnimation(IntroAnimation* anim) {
    anim.should_play = true;
}

fn bool updateIntroAnimation(IntroAnimation* anim) {
    if(anim.should_play == false) return false;
    
    int index = 0;
    
    do {
        bool stop_anim = input::getAction("noIntro").fnBecameTriggered();
        
        if(anim.current_frame && 
           anim.current_frame.end_time > 0 && 
           main::gpGame.time_ms <= anim.current_frame.end_time && 
           stop_anim == false)
        {
            any panel = any_make(anim.current_frame.image, gui::Panel_Image.typeid);
            gui::updatePanel(panel);
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
        else if(anim.current_frame && !index) // first frame
        {
            anim.current_frame.start_time = main::gpGame.time_ms;
            anim.current_frame.end_time   = anim.current_frame.start_time + anim.current_frame.draw_time;
        }
    } while(anim.current_frame != null);
    
    // todo don't skip the entire intro?
    deinitIntroAnimation(anim);
    
    return false;
}

fn void drawIntroAnimation(IntroAnimation* anim) {
    if(anim == null) return;
    
    if(anim.current_frame) {
        any panel = any_make(anim.current_frame.image, gui::Panel_Image.typeid);
        gui::drawPanel(panel);
    }
}


/*

fn void start_button_onOver(Widget* button) {
    //main::gameLog("Main Menu: I'm Over button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).over_color;
}

fn void start_button_onStopOver(Widget* button) {
    main::gameLog("Main Menu: Got out off button: %s", button.name);
}

fn void start_button_onRelease(Widget* button) {
    main::gameLog("Main Menu: Released button: %s", button.name);
}

fn void start_button_onPress(Widget* button) {
    //main::gameLog("Main Menu: I'm pressing button: %s", button.name);
    ((WidgetButton*)button).color = ((WidgetButton*)button).pressed_color;
}

fn void start_button_onSinglePress(Widget* button) {
    WidgetButton* btn = ((WidgetButton*)button);
    main::gameLog("Main Menu: I pressed button: %s once.", btn.name);
    if(/*!btn.sound_played && */rl::isSoundValid(*btn.interaction_sound)) {
        rl::playSound(*btn.interaction_sound);
        //btn.sound_played = true;
    }
}


