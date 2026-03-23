module game::intro;

// region modules
import std::io;
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
// end_region

// region defines
alias FrameQueue = List{Frame*};
const FADE_FRAMES = true; // comment this to disable the fade effect
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
CVar skip @public = { "skip_intro", CvarType.BOOL, "0", "skip displaying the intro" };

fn void register_cvars() @public 
{
    cvar::@register(&skip);
}
// end_region

struct Frame @local 
{
    RLTexture2D image;
	struct text {
		String msg;
		RLFont* font;
		Vec2f pos;
		float font_size;
		float spacing;
		RLColor color;
	}
    //Vec2f pos;
    //Vec2f size;
    RLRectangle source_rect;
    RLRectangle dest_rect;
    RLColor color;
    int fade_in_start_time;
    int fade_out_start_time;
    bool fade_in_done;
    bool fade_out_done;
}

<*
    @param [&inout] frame : "frame to deinitialize"
*>
fn void deinit_frame(Frame* frame) @local
{
	rl::unloadTexture(frame.image);
    mem::free(frame);
    frame = null;
}

<*
    @param [&inout] frame : "frame to draw"
*>
fn void draw(Frame* frame) @local
{
	if(rl::isTextureValid(frame.image)) 
	{
		//rl::setBlendFactors(rl::RL_ONE, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_FUNC_ADD);
		//rl::setBlendMode(RLBlendMode.CUSTOM);
		//rl::@blendMode(RLBlendMode.ALPHA_PREMUL)
		//{
			// NOTE(HM) center of the texture (rotation/scale point), 
			// it's relative to destination rectangle dimentions, not the screen dimentions.
			rl::drawTexturePro(frame.image, frame.source_rect, frame.dest_rect, {0, 0}, 0.0f, frame.color);
		//};
	} else {
		r2d::@drawRect(frame.dest_rect, frame.color);
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
   int epilepsy_time;
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
    int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    ZString path = game::gpGame.app_base_folder.tconcat(texture_path).zstr_tcopy();
    Frame* frame = mem::new(Frame);
    frame.image = rl::loadTexture(path);
    assert(rl::isTextureValid(frame.image));
    frame.source_rect = {0, 0, frame.image.width, frame.image.height};
	frame.dest_rect = {0, 0, w, h};
	rl::setTextureFilter(frame.image, RLTextureFilter.BILINEAR);
    rl::setTextureWrap(frame.image, RLTextureWrap.CLAMP);
    frame.color = rl::WHITE;
    $if($defined(FADE_FRAMES)):
    frame.color.a = 0; // start with a transparent frame for fade in
    $endif
    anim.frames.push(frame);
}

<*
    @param [&inout] anim : "animation to push the frame into"
*>
fn void makeTextFrame(IntroAnimation* anim, String message = "undefined", RLColor _color = rl::CTRANSPARENT) @local 
{
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
}

fn void drawEpilepsyWarning(int w, int h) @local 
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


fn void initAnimation(IntroAnimation* anim) @local
{
    makeTexturedFrame("images/gui/raylib_intro.png", anim);
    makeTexturedFrame("images/gui/logo_hm.png", anim);
    //
    input::makeKeyboardAction("skipIntro", rl::KEY_ESCAPE);
    input::@makeAction({.name = "skipFrame", .kind = KEYBOARD, .key1 = rl::KEY_SPACE});

    /*
    // test unurdered_remove
    List{int} a;
    a.reserve(5);
    a.push(1); a.push(2); a.push(3); a.push(4); a.push(5);
    log::info("Before unurdered_remove: %s", a);
    misc::unurdered_remove{int}(&a, 1); // remove the element at index 1 (value 2)
    log::info("After unurdered_remove: %s", a);*/
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
    @param [&inout] anim : "animation to handle"
*>
fn void init_anim_timing(IntroAnimation* anim, int time_ms) @local
{
    // full anim duration
    int frames_count = (int)anim.frames.len();
    anim.epilepsy_time = time_ms + EPILEPSY_TEXT_DURATION;
    anim.full_duration = anim.epilepsy_time + (FRAME_TIME * frames_count);
    // set the next frame to show after the required time
    //anim.next_frame_time = anim.full_duration - FRAME_TIME;
    /*foreach(int i, &frame : anim.frames)
    {
        if(i == 0) {
            (*frame).fade_in_start_time  = time_ms;
        } else {
            (*frame).fade_in_start_time  = anim.frames[--i].fade_out_start_time + FADE_OUT_TIME;
        }
        (*frame).fade_out_start_time = (*frame).fade_in_start_time + FADE_IN_TIME + VISIBLE_DURATION;
    }*/
    //anim.frames[0].fade_in_start_time  = time_ms;
    //anim.frames[0].fade_out_start_time = anim.frames[0].fade_in_start_time + FADE_IN_TIME + VISIBLE_DURATION;
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
    log::info(CONSOLE, "intro-setup: %s", game::gpGame.time_ms);
}

fn void IntroAnimation.stop(&self)
{
    self.should_play = false;
    deinitAnimation(self);
    game::gpGame.mode = GameMode.NONE;
     // restarts from the main menu;
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
	int current_time = game::gpGame.time_ms;

    if(!anim.timing_initialized) {
        init_anim_timing(anim, current_time);
        log::info(CONSOLE, "intro-timing-init: %s", current_time);
    }

    //  if animation played to the end or we skipped the intro
    if(current_time >= anim.full_duration || input::getAction("skipIntro").fnBecameTriggered()) {
        anim.stop();
        return;
    }

    game::gpGame.mode = GameMode.INTRO;

    
    // if a single frame
    if(anim.frames.len() == 1) {
        // go on displaying the same frame for the duration of the animation
        anim.loop_frame(0);
    }
    else if(current_time > anim.epilepsy_time) // change frame after a time
    {
        Frame* current_frame = anim.frames[anim.current_frame_index];

        // if no more frames to play get out
        if(anim.current_frame_index >= anim.frames.len()) {
            anim.stop();
            return;
        }

        if(current_frame.fade_out_done) {
            anim.current_frame_index++;
            if(anim.current_frame_index >= anim.frames.len()) {
                anim.current_frame_index = 0;
                anim.stop();
            } else {
                int i = anim.current_frame_index;
                // this will set only the time, after the first frame is done
                anim.frames[i].fade_in_start_time = current_time;
            }
        }
    }
}

fn void drawAnimation(IntroAnimation* anim, int w, int h) @if(!$defined(FADE_FRAMES))
{
    if(anim == null) return;
	if(anim.frames.len() == 0) return;

	// draw a black rect as background to prevent seeing the clear color of the screen
    r2d::@drawRect({0, 0, w, h}, rl::BLACK);

    int current_time = game::gpGame.time_ms;
    if(current_time < anim.epilepsy_time) {
        drawEpilepsyWarning();
    } else {
        // draw current frame
        anim.frames[anim.current_frame_index].draw();
    }

}

float alpha @local = 0.0f;
bool should_fade_in @local = false;
bool should_fade_out @local = false;
<*
    @param [&inout] anim : "animation to play"
    @require anim.frames.len() > 0
*>
fn void drawAnimation(IntroAnimation* anim) @if($defined(FADE_FRAMES))
{
    int current_time = game::gpGame.time_ms;
    int w, h;
    w = game::gpGame.screen.w;
    h = game::gpGame.screen.h;
    // draw a black rect as background to prevent seeing the clear color of the screen
    r2d::@drawRect({0, 0, w, h}, rl::BLACK);

    if(current_time < anim.epilepsy_time) 
    {
        drawEpilepsyWarning(w, h);
    } 
    else 
    {
        if(anim.frames.len() == 0) return;
        
        // current frame
        Frame* frame = anim.frames[anim.current_frame_index];

        /*if(current_time == frame.fade_in_start_time) {
            should_fade_in = true;
            //@debug_break(1);
        }*/
        
        /*if(current_time == frame.fade_out_start_time) {
            should_fade_out = true;
            //@debug_break(1);
        }*/

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
        
        if(frame.fade_in_done && /*should_fade_out &&*/ !frame.fade_out_done && 
        current_time >= frame.fade_out_start_time) {
            alpha = misc::move_toward(alpha, 0.0f, FADE_OUT_SPEED);
            if(alpha < 0.0f) alpha = 0.0f;
            frame.color.a = (char)(alpha * 255);
            if(frame.color.a == 0) {
                frame.fade_out_done = true;
                alpha = 0.0f;
                //should_fade_out = false;
            }
        }

        draw(frame);
        /*rl::drawText(string::tformat_zstr("time: %s", current_time), 50, 100, 16, rl::RED);
        rl::drawText(string::tformat_zstr("frame: %s", anim.current_frame_index), 50, 118, 16, rl::RED);
        rl::drawText(string::tformat_zstr("frame color: {%s,%s,%s,%s}", 
        frame.color.r,
        frame.color.g,
        frame.color.b,
        frame.color.a), 
        50, 134, 16, rl::RED);
        rl::drawText(string::tformat_zstr("frame st time: %s", frame.fade_out_start_time), 50, 150, 16, rl::RED);
        */
    }
}


