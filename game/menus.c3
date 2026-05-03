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

// TODO(HM) Remake the menu system to be imediate mode?
// TODO(HM) Add a options menu
module game::gui::menu;

/*
    GUI creation process:

    - Create a UIWindow
    	UIWindow main_menu;
    - init the UIWindow
    	main_menu.ini(...);
    - create any children panels/widgets
    	WidgetButton main_menu_button;
    - init the Widget and add it to UIWindow
    	main_menu_button.init();
    	main_menu_button.addTo(&main_menu);

    or

    - Create a UIWindow
    	UIWindow menu;
    - init the UIWindow
    	menu.ini(...);
	- add children using the addChildren block
		menu.@addChildren() 
		{
			// create any children panels/widgets
			{
				WidgetButton button0;
				// init the Widget
				button0.init();
				button0.addTo(self);
			}
    };
*/

// region modules
import std::io;
import std::core::mem; // for malloc
import std::math::vector;
import std::collections::list;
import game::main;
import engine::gui;
import engine::sys::ui;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
// end_region

// region alias
alias gpGame @local = game::gpGame;
// end_region

// region constants
const SCREEN_TOP_CORNER = (Vec2f) {0.0f, 0.0f}; // In Raylib the top-left corner is (0,0), is different from OpenGL where the bottom-left corner is (0,0)
// end_region

fn UIWindow* getActiveMenu() @local @inline 
{
	return game::gpGame.guiActive;
}

fn void setGUI(UIWindow* menu) 
{
    UIWindow* guiActive;

    // if the menu is set to null, deactivate the current menu
	if (menu == null) 
    {
        guiActive = getActiveMenu();
        if ( guiActive != null ) {
            guiActive.deactivate();
        }
        game::gpGame.guiActive = null;
		return;
	}

    //else set the current menu
    guiActive = game::gpGame.guiActive = menu;
    if(guiActive.hidden()) {
        guiActive.show();
    }

	if (guiActive == game::gpGame.main_menu) 
    {
        if(game::gpGame.mode != game::GameMode.MENU) game::gpGame.mode = game::GameMode.MENU;

        if(game::gpGame.editor.isOpened()) {
            if(game::game_cursor_visible()) game::hide_game_cursor();
        } else {
           if(game::game_cursor_hidden()) game::show_game_cursor();
        }
        
        // todo set the gui vars
		//SetSaveGameGuiVars();
		//SetMainMenuGuiVars();
	} /*else if ( guiActive == game::gpGame.restart_menu ) {
		SetSaveGameGuiVars();
	}*/

	// NOTE(HM) i'm 99.9% sure this creates and inits a event data struct to catch key presses
	//sysEvent_t  ev;
	//memset( &ev, 0, sizeof( ev ) );
	//ev.evType = SE_NONE;

	//guiActive.handleEvent( &ev, com_frameTime );
	//guiActive.activate( true, game::gpGame.time_ms );
    guiActive.setFocus(true);
}

fn void start(UIWindow* gui) 
{
    // if already started
	if ( getActiveMenu() == gui ) {
		return;
	}

	// pause the game sound world
	/*if ( sw != NULL && !sw->IsPaused() ) {
		sw->Pause();
	}*/

	// start playing the menu sounds
	//soundSystem->SetPlayingSoundWorld( menuSoundWorld );
    if(rl::isMusicValid(gui.music_stream)) {
        if(!rl::isMusicStreamPlaying(gui.music_stream) && !game::gpGame.pause_all_music) rl::playMusicStream(gui.music_stream);
    }

    setGUI(gui);

	//console->Close();
}

fn void stop(UIWindow* guiActive = getActiveMenu()) 
{
	// clear mapSpawned
	//UnloadMap();

    // stop gui sound world
	//if ( guiActive.soundWorld ) {
		//guiActive.soundWorld.stopAllSounds();
	//}

    if(guiActive)
    {
        if(rl::isMusicValid(guiActive.music_stream)) {
            // todo fade out the music stream
            if(rl::isMusicStreamPlaying(guiActive.music_stream)) rl::stopMusicStream(guiActive.music_stream);
            //rl::unloadMusicStream(guiActive.music_stream);
        }
    }

	// drop all guis
	setGUI(null);
}

fn void exit() 
{
	stop(); // any menu

    // TODO(HM) This should be set ONLY when we are sure we are ingame and not
    // in some other state, right now is set when all menus exit what is not 
	// total guarantie that we are returning to the game world.
    game::gpGame.mode = GameMode.PLAYING;

	// go back to the game sounds
	//soundSystem->SetPlayingSoundWorld( sw );

	// unpause the game sound world
	//if ( sw != NULL && sw->IsPaused() ) {
		//sw->UnPause();
	//}
}


//////////////////////////////////////////////////////////////////
//////////////////////// region MAIN MENU ////////////////////////
<*
    Create a checkbox for the menu

    @param [in] text : "checkbox label text"
    @param [&in] bdef : "button callbacks definition struct pointer"
    @ensure return != null : "pointer to the created checkbox"
*>
fn WidgetCheckBox* UIWindow.create_menu_checkbox(&self, String text, MenuButtonDef* bdef) @inline 
{
    WidgetCheckBox* checkbox = gui::createCheckBox("Checkbox 1");
    checkbox.setColor(rl::DARKGRAY);
    checkbox.addTo(self);
    // set the checkbox properties
    checkbox.onOver        = bdef.cbs[CallBack.OVER]; // &button_onOver;
    checkbox.onStopOver    = bdef.cbs[CallBack.STOP_OVER]; // &button_onStopOver;
    checkbox.onPress       = bdef.cbs[CallBack.PRESS]; // &start_button_onPress;
    checkbox.onSinglePress = bdef.cbs[CallBack.SINGLE_PRESS]; // &start_button_onSinglePress;
    checkbox.onRelease     = bdef.cbs[CallBack.RELEASE]; // &button_onRelease;
    checkbox.onLoad        = &button_onLoad;

    // button on load callback runs right now when the button is created
    // perhaps rename this to onCreate?
    if(checkbox.onLoad) checkbox.onLoad(checkbox);

    return checkbox;
}

<*
    init a checkbox for the menu

    @param [&inout] chk : "checkbox to init"
	@param [in] name : "checkbox name"
	@param [in] label : "checkbox label text"
	@param [&in] bdef : "button callbacks definition struct pointer"
	@param [&inout] uiwin : "window to add the checkbox to"
*>
fn void init_checkbox(WidgetCheckBox* chk, String name, String label, MenuButtonDef* bdef, UIWindow* uiwin) 
{
	chk.init();
	chk.setName(name);
	chk.setLabel(label);
    chk.setColor(rl::DARKGRAY);
    chk.addTo(uiwin);
    // set the checkbox properties
    chk.onOver        = bdef.cbs[CallBack.OVER]; // &button_onOver;
    chk.onStopOver    = bdef.cbs[CallBack.STOP_OVER]; // &button_onStopOver;
    chk.onPress       = bdef.cbs[CallBack.PRESS]; // &start_button_onPress;
    chk.onSinglePress = bdef.cbs[CallBack.SINGLE_PRESS]; // &start_button_onSinglePress;
    chk.onRelease     = bdef.cbs[CallBack.RELEASE]; // &button_onRelease;
    chk.onLoad        = &button_onLoad;

    // button on load callback runs right now when the button is inited
    // perhaps rename this to onInit?
    if(chk.onLoad) chk.onLoad(chk);
}

fn WidgetText* UIWindow.create_menu_label(&self, String text, RLFont* font, int font_size, RLColor color) @inline 
{
    WidgetText* label = gui::createLabel(text, font, font_size, color);
    UIWindow* window = self;
    label.addTo(window);
    return label;
}

constdef CallBack : inline int @local
{
	OVER = 0,  // mouse over button
    STOP_OVER,
    PRESS,  // press down
    SINGLE_PRESS, // press down then release
	RELEASE
}

//const MAX_CALLBACK_PTRS @local = CallBack.len;
struct MenuButtonDef 
{
    Vec2f size;
    RLColor default_color;
    RLColor over_color;
    RLColor label_color;
    WidgetTextAlign label_align;
    //WidgetCallback[MAX_CALLBACK_PTRS] callbacks;
    WidgetCallback[CallBack.len] cbs;
}

<*
    Create a button for the menu

    @param pos : "button position"
    @param [in] text : "button label text"
    @param [&in] bdef : "button cbs definition struct pointer"
    @ensure return != null : "pointer to the created button"
*>
macro WidgetButton* UIWindow.create_menu_button(&self, Vec2f pos, String text, MenuButtonDef* bdef) @local 
{
    WidgetButton* button = gui::createButton();
    button.addTo(self);
    // set the button properties
    button.name = button.name.tconcat(text);
    button.setSizeV(bdef.size);
    button.setPositionV(pos);
    button.setDefaultColor(bdef.default_color);
    //
    float button_width  = bdef.size.x;
    float button_height = bdef.size.y;
    WidgetText* label   = mem::new(WidgetText);
    gui::init_label(label, text, game::gpGame.candara_font, 0, bdef.label_color, self);
    // set the label properties
    Vec2f label_offset  = pos;
    /*Vec2f label_offset  = pos + misc::VEC_RIGHT * (button_width / 2);
    label_offset       += misc::VEC_DOWN * (button_height / 2) * 0.5f;
    label_offset.x     -= (float)label.textlen() / 2;*/
    //label.setFontSize(60);
    label.setPositionV(label_offset);
    label.addToPosition(
       x: 0.5f * button_width - (float)label.textlen() / 2,
       y: 0.5f * button_height - ((button_height / 2) * 0.5f)
    );
    label.bindTo(button);

    // button interaction callbacks
    button.onOver        = bdef.cbs[CallBack.OVER]; // &button_onOver;
    button.onStopOver    = bdef.cbs[CallBack.STOP_OVER]; // &button_onStopOver;
    button.onPress       = bdef.cbs[CallBack.PRESS]; // &start_button_onPress;
    button.onSinglePress = bdef.cbs[CallBack.SINGLE_PRESS]; // &start_button_onSinglePress;
    button.onRelease     = bdef.cbs[CallBack.RELEASE]; // &button_onRelease;
    button.onLoad        = &button_onLoad;

    // button on load callback runs right now when the button is created
    // perhaps rename this to onCreate?
    if(button.onLoad) button.onLoad(button);

    return button;
}

constdef Desk : inline int @local
{
	OPTIONS = 0,
	EXTRA
}

fn UIWindow* mainMenuCreate(int screenWidth, int screenHeight)
{
    // Menu creation
    Vec2f screen_center       = game::gpGame.view.origin; //(Vec2f) {(float)screenWidth/2.0f, (float)screenHeight / 2.0f};
    float screen_half_width   = screen_center.x;
    float screen_half_height  = screen_center.y;
    Vec2f screen_top_center   = {screen_half_width, 0.0f};

    UIWindow* desk_main = mem::new(UIWindow);
    desk_main.init("MainMenu", isDesktop: true, shouldRegister: true);
    desk_main.setColor(rl::DARKGRAY);
	// TODO(HM) change the concept of child windows
	// to something like child windows, because right now
	// I can only have one window open at the time...
	// So when opening the child window the parent gets hidden...
	// Need to find a way to have a window with more windows/pages.
	desk_main.childWindows.reserve(Desk.len);
	// create options uiwin
	desk_main.childWindows.insert_at(Desk.OPTIONS, mem::new(UIWindow));
    UIWindow* desk_options = desk_main.childWindows.get(Desk.OPTIONS);
    desk_options.init("OptionsMenu", shouldRegister: true);
    Vec2f desk_options_center = screen_center - desk_options.getSize() / 2.0f; 
    desk_options.setPositionV({
        desk_options_center.x,
        desk_options_center.y
        });
    desk_options.setColor(rl::GRAY);
    desk_options.hide();
    // link the menus
    desk_main.next = desk_options;
    desk_options.home = desk_main;
    desk_options.previous = desk_main;

	// create extra uiwin
	desk_main.childWindows.insert_at(Desk.EXTRA, mem::new(UIWindow));
    UIWindow* desk_extra = desk_main.childWindows.get(Desk.EXTRA);
    desk_extra.init("ExtraMenu", shouldRegister: true);
    desk_extra.setPositionV({
        desk_options_center.x,
        desk_options_center.y
        });
    desk_extra.setColor(rl::GRAY);
    desk_extra.hide();
    

    String music_path = game::gpGame.app_base_folder.tconcat("music\\main_menu\\Swallow.ogg");
    if(fs::fileExists(music_path))
    {
        log::info(FILE, "\tloading %s music: %s", desk_main.name, music_path);
    } else { 
        unreachable("music path not found: %s", music_path);
    }
    desk_main.music_stream = rl::loadMusicStream(music_path.zstr_tcopy());
    if(!rl::isMusicValid(desk_main.music_stream)) {
        unreachable("music stream not valid: %s", music_path);
    }
    desk_options.music_stream = desk_main.music_stream; // share the same music stream
    // add the windows to the shared music stream list
    desk_main.shared_music_stream_desktops.push(desk_main);
    desk_main.shared_music_stream_desktops.push(desk_options);

    rl::setMusicVolume(desk_main.music_stream, 1.0f);

    
    Vec2f default_button_size = { 0.10f*screenWidth, 0.05f*screenHeight };
    float button_width, button_height;
    button_width  = default_button_size.x;
    button_height = default_button_size.y;
    
// region widgets

    /*
    gui::WidgetContainer ct;

    ct.@container( desk_main, {
        .direction = gui::TOP_TO_BOTTOM,
        .background = rl::RED,
        .padding = {8, 8, 8, 8},
        .itemGap = 16,
        .minSize = { .w = 200 },
        .border_between = {2, rl::GREEN }
    }; WidgetContainer* pct )
    {
        //pct.register(any_make(create_menu_label({200, 200}, "test", 12, rl::GRAY, desk_main), WidgetText.typeid));
        //pct.register(any_make(create_menu_label({200, 200}, "test2", 12, rl::GRAY, desk_main), WidgetText.typeid));
    };
    */

    // region LABELS
    //*************
    // TITLE
    //*************
    const TITLE           = "FlatHead";
    const TITLE_FONT_SIZE = 50;
    RLFont* title_font = game::gpGame.trojan_pro_font;
    WidgetText* title_label = mem::new(WidgetText);
	gui::init_label(title_label, TITLE, title_font, TITLE_FONT_SIZE, rl::GRAY, desk_main);
    Vec2f title_offset = misc::VEC_RIGHT * screen_top_center.x;
    title_offset -= {title_label.text_len / 2.0f, 0.0f};
    title_offset += misc::VEC_DOWN * (0.10f * screenHeight);
    title_label.setPositionV(title_offset);
    title_label.setAlign(gui::WidgetTextAlign.LEFT);
    //*************
    // SUBTITLE
    //*************
    const SUBTITLE           = "engine";
    const SUBTITLE_FONT_SIZE = 16;
    RLFont* subtitle_font = game::gpGame.lucida_font;
    WidgetText* subtitle_label = mem::new(WidgetText);
	gui::init_label(subtitle_label, SUBTITLE, subtitle_font, SUBTITLE_FONT_SIZE, rl::RAYWHITE, desk_main);
    Vec2f subtitle_offset = misc::VEC_RIGHT * screen_top_center.x;
    subtitle_offset -= {subtitle_label.text_len / 2.0f, 0.0f};
    subtitle_offset += misc::VEC_DOWN * (0.18f * screenHeight);
    subtitle_label.setPositionV(subtitle_offset);
    subtitle_label.setAlign(gui::WidgetTextAlign.LEFT);
    // end_region LABELS
    
    // region BUTTONS
    Vec2f offset          = SCREEN_TOP_CORNER;
    
    MenuButtonDef btn_def;
    btn_def.size          = default_button_size;
    btn_def.default_color = rl::YELLOW;
    btn_def.over_color    = rl::RED;
    btn_def.label_color   = rl::SKYBLUE; //rl::DARKGRAY;
    //btn_def.label_align;
    
    //*************
    // START
    //*************
    btn_def.cbs[CallBack.OVER]         = &button_onOver;
    btn_def.cbs[CallBack.STOP_OVER]    = &button_onStopOver;
    btn_def.cbs[CallBack.PRESS]        = &start_button_onPress;
    btn_def.cbs[CallBack.SINGLE_PRESS] = &start_button_onSinglePress;
    btn_def.cbs[CallBack.RELEASE]      = &button_onRelease;
    
    offset += misc::VEC_RIGHT * screen_half_width;
    offset -= {button_width / 2.0f, 0.0f};
    offset += misc::VEC_DOWN * (screenHeight / button_height) * 10;
    String btn_string = gpGame.langdict.getString("0");
    desk_main.create_menu_button(offset, btn_string/*"START"*/, &btn_def);

    //************
    // QUIT
    //************
    btn_def.cbs[CallBack.PRESS]        = &quit_button_onPress;
    btn_def.cbs[CallBack.SINGLE_PRESS] = &quit_button_onSinglePress;
    
    offset += misc::VEC_DOWN * button_height;
    offset.y += 0.5f * button_height;
    btn_string = gpGame.langdict.getString("1");
    desk_main.create_menu_button(offset, btn_string/*"QUIT"*/, &btn_def);
    
    //************
    // OPTIONS
    //************
    btn_def.cbs[CallBack.PRESS]        = &options_button_onPress;
    btn_def.cbs[CallBack.SINGLE_PRESS] = &options_button_onSinglePress;
    
    offset += misc::VEC_DOWN * button_height;
    offset.y += 0.5f * button_height;
    btn_string = gpGame.langdict.getString("3");
    desk_main.create_menu_button(offset, btn_string/*"OPTIONS"*/, &btn_def);
    // end_region BUTTONS

    // region widgets options
    //************
    // Checkbox 1
    //******
    btn_def.cbs[CallBack.PRESS]        = null; //&checkbox1_onPress;
    btn_def.cbs[CallBack.SINGLE_PRESS] = &checkbox1_onSinglePress;

    //WidgetCheckBox* checkbox1 = desk_options.create_menu_checkbox("Checkbox 1", &btn_def);
    WidgetCheckBox* checkbox1 = mem::new(WidgetCheckBox);
	init_checkbox(checkbox1, "checkbox1", "no Sound", &btn_def, desk_options);
    offset = desk_options.getPosition();
    offset += misc::VEC_RIGHT * (desk_options.getSize().x / 2);
    offset += misc::VEC_DOWN * (0.20f * desk_options.getSize().y);
    checkbox1.setPositionV(offset);
    //checkbox1.setPositionV(desk_options_center);
    //************
    // GO TO MAIN MENU
    //************
    btn_def.cbs[CallBack.PRESS]        = &back_button_options_onPress;
    btn_def.cbs[CallBack.SINGLE_PRESS] = &back_button_options_onSinglePress;
    
    offset = desk_options.getPosition();
    offset += misc::VEC_RIGHT * (0.10f * (desk_options.getSize().x / 2));
    offset += misc::VEC_DOWN * desk_options.getSize().y;
    offset.y -= button_height + (0.5f * button_height);
    btn_string = gpGame.langdict.getString("4");
    desk_options.create_menu_button(offset, btn_string/*"BACK"*/, &btn_def);
// end_region widgets
    
    return desk_main;
}







// #region  ################ Button callbacks ##########################

// generic button callbacks
fn void button_onLoad(any widget) 
{
    assert(widget.ptr != null);
    switch (widget.type)
    {
        case WidgetButton.typeid:
        {
            WidgetButton* self = (WidgetButton*)widget.ptr;
            log::info(CONSOLE, "WidgetButton '%s' loaded.", self.name);
        }
        case WidgetCheckBox.typeid:
        {
            WidgetCheckBox* self = (WidgetCheckBox*)widget.ptr;
            log::info(CONSOLE, "WidgetCheckBox '%s' loaded.", self.name);
        }
        default:
        {
            unreachable("widget type not handled in button_onLoad: %s", widget.type);
        }
    }
    //log::info(Where.CONSOLE, "WidgetButton '%s' loaded.", self.name);
}

// generic button callbacks
fn void button_onOver(any widget/*Widget* widget*/) 
{
    assert(widget.ptr != null);
    switch (widget.type)
    {
        case WidgetButton.typeid:
        {
            WidgetButton* self = (WidgetButton*)widget.ptr;
            if(self.active_visible_infocus() && self.asFocus()) {
                self.setColor(rl::RED);
            }
        }
        case WidgetCheckBox.typeid:
        {
            WidgetCheckBox* self = (WidgetCheckBox*)widget.ptr;
            if(self.active_visible_infocus() && self.asFocus()) {
                self.setColor(rl::RED);
            }
        }
        case WidgetText.typeid:
        {
            WidgetText* self = (WidgetText*)widget.ptr;
            if(self.active_visible_infocus() && self.asFocus()) {
                self.setColor(rl::RED);
            }
        }
        default:
        {
            unreachable("widget type not handled in button_onOver: %s", widget.type);
        }
    }
    /*WidgetButton* self = (WidgetButton*)widget;
    if(self.active_visible_infocus() && self.asFocus()) {
        switch (self.kind)
        {
            case gui::KIND_CHECKBOX:
            case gui::KIND_TEXT:
            case gui::KIND_CONTAINER:
            case gui::KIND_BUTTON:
            default:
                self.setColor(rl::RED);
        }
    }*/
}

// generic button callbacks
fn void button_onStopOver(/*Widget* widget*/ any widget) 
{
    assert(widget.ptr != null);
    if(widget.type == WidgetButton.typeid) {
        WidgetButton* self = (WidgetButton*)widget.ptr;
        if(self.color != self.default_color) self.setColor(self.default_color);
        return;
    } else {
        unreachable("widget type %s is not a button!", widget.type);
    }
    //WidgetButton* self = (WidgetButton*)widget;
    //if(self.color != self.default_color) self.setColor(self.default_color);
}

// generic button callbacks
fn void button_onRelease(/*Widget* widget*/ any widget) 
{
    assert(widget.ptr != null);
    if(widget.type == WidgetButton.typeid) {
        WidgetButton* self = (WidgetButton*)widget.ptr;
        if (self.active_visible_infocus() && self.asFocus()) {
            self.setColor(self.default_color);
            self.pressed = false;
            self.press_count = 0;
        }
        return;
    } else {
        unreachable("widget type %s is not a button!", widget.type);
    }
    /*WidgetButton* self = (WidgetButton*)widget;
    if (self.active_visible_infocus() && self.asFocus()) {
        self.setColor(self.default_color);
        self.pressed = false;
        self.press_count = 0;
    }*/
}

<*
    generic button callback
    
    @param [in] widget : "widget calling this function"
    @require widget != null
*>
fn void button_onPress(/*Widget* widget*/ any widget) 
{
    assert(widget.ptr != null);
    if(widget.type == WidgetButton.typeid) {
        WidgetButton* self = (WidgetButton*)widget.ptr;
        if (self.active() == false || self.asFocus() == false) return;
        if (self.pressed == false) {
            self.setColor(rl::GREEN);

            if (rl::isSoundValid(*self.interaction_sound)) {
                if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
            }
        }
        self.pressed = true;
        self.press_count++;
        return;
    } else {
        unreachable("widget type %s is not a button!", widget.type);
    }
    /*WidgetButton* self = (WidgetButton*)widget;
    if (self.active() == false || self.asFocus() == false) return;
    if (self.pressed == false) {
        self.setColor(rl::GREEN);

        if (rl::isSoundValid(*self.interaction_sound)) {
            if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
        }
    }
    self.pressed = true;
    self.press_count++;*/
}

<*
    generic button callback
    
    @param [in] widget : "widget calling this function"
    @require widget.ptr != null
*>
fn void button_onSinglePress(any widget) 
{
    if(widget.type == WidgetButton.typeid) 
    {
        WidgetButton* self = (WidgetButton*)widget.ptr;
        if (self.active() == false || self.asFocus() == false) return;

        if (rl::isSoundValid(*self.interaction_sound)) {
           if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
        }
        self.setColor(rl::GREEN);
        //return;
    } else {
        unreachable("widget %s is not a valid button!", ((Widget*)widget.ptr).name);
    }
}

// while the button is kept pressed
fn void start_button_onPress(/*Widget* widget*/ any widget) 
{
    button_onPress(widget);
}

fn void start_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    menu::exit();
}

fn void quit_button_onPress(any widget) 
{
    button_onPress(widget);
}

fn void quit_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    game::quitGame();
}

fn void options_button_onPress(any widget) 
{
    button_onPress(widget);
}

fn void options_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    UIWindow* active_menu = getActiveMenu();
	if(active_menu.getName() == "MainMenu")
    {
        //UIWindow* next_menu = uiwin::gpManager.get("MainMenu");
        UIWindow* next_menu = active_menu.childWindows.get(Desk.OPTIONS);
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }
    /*if(active_menu) 
    {
        UIWindow* next_menu = active_menu.next;
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }*/
    //log::info(Where.CONSOLE, "Options Menu is still not done.");
    //log::info(Where.CONSOLE, "Pressed Count = %s.", ((WidgetButton*)widget).press_count);
    // TODO(HM) 
    //  Need to create a options menu
    //  I have two options, one create a new UIWindow
    //  or two reuse the main menu window and create a overlay "window"
    //  thou for the overlay I will have to handle overlaping widgets...
    //gui::setGui();
}

fn void back_button_options_onPress(any widget) 
{
    button_onPress(widget);
    UIWindow* active_menu = getActiveMenu();
	if(active_menu) {
        UIWindow* next_menu;
		switch(active_menu.getName())
		{
			case "MainMenu": break; 
			case "OptionsMenu":
			case "ExtraMenu":
				next_menu = uiwin::gpManager.get("MainMenu");
			default: unreachable();
		}
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }
    /*if(active_menu && active_menu.previous != null) {
        UIWindow* next_menu = active_menu.previous;
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }*/
}

fn void back_button_options_onSinglePress(any widget) 
{
    assert(widget.ptr != null);
    back_button_options_onPress(widget);
}

fn void checkbox1_onPress(any widget) 
{
    //
}

fn void checkbox1_onSinglePress(any widget) 
{
    assert(widget.ptr != null);
    if(widget.type == WidgetButton.typeid)
    {
        WidgetCheckBox* this = (WidgetCheckBox*)widget.ptr;
        this.setChecked(!this.checked);
        //log::info(CONSOLE, "Checkbox 1 is now %s.", this.isChecked() ? "checked" : "unchecked");
		if(this.isChecked()) {
			log::info(CONSOLE, "Checkbox 1 is now checked.");
			game::gpGame.pause_all_music = 1;
			if(rl::isMusicStreamPlaying(game::gpGame.guiActive.music_stream)) rl::pauseMusicStream(game::gpGame.guiActive.music_stream);
		} else {
			log::info(CONSOLE, "Checkbox 1 is now unchecked.");
			game::gpGame.pause_all_music = 0;
			if(!rl::isMusicStreamPlaying(game::gpGame.guiActive.music_stream)) rl::resumeMusicStream(game::gpGame.guiActive.music_stream);
		}
        // TODO(HM) do something with checkbox state
    } else {
        unreachable("widget %s is not a valid button!", ((Widget*)widget.ptr).name);
    }
}
// end_region Main Menu

// end_region
