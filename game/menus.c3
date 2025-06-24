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

    - Create a Desktop
    gui::Desktop main_menu;
    - init the Desktop
    main_menu.ini(...);
    - create any children panels/widgets
    gui::WidgetButton main_menu_button;
    - init the Widget and add it to Desktop
    main_menu_button.init();
    main_menu_button.addTo(&main_menu);

    or

    - Create a Desktop
    gui::Desktop menu;
    - init the Desktop
    menu.ini(...);

    menu.@addChildren() 
    {
        // create any children panels/widgets
        {
            gui::WidgetButton button0;
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
import engine::misc;
import engine::logging::lgr;
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
// end_region

// region alias
// end_region

// region constants
const SCREEN_TOP_CORNER = (Vec2f) {0.0f, 0.0f};
// end_region

fn Desktop* getActiveMenu() @local @inline {
	return main::gpGame.guiActive;
}

fn void setGUI(Desktop* menu) 
{
    Desktop* guiActive;

    // if the menu is set to null, deactivate the current menu
	if (menu == null)
    {
        guiActive = getActiveMenu();
        if ( guiActive != null ) {
            guiActive.activate(false, main::gpGame.time_ms);
            main::gpGame.guiActive = null;
        }
		return;
	}

    //else set the current menu
    guiActive = main::gpGame.guiActive = menu;

    // todo
	if (guiActive == main::gpGame.main_menu) 
    {
        if(main::gpGame.editor.isOpened()) 
        {
            if(main::game_cursor_hidden() == false) main::hide_game_cursor();
        } 
        else 
        {
           if(main::game_cursor_hidden()) main::show_game_cursor();
        }
		//SetSaveGameGuiVars();
		//SetMainMenuGuiVars();
	} /*else if ( guiActive == main::gpGame.restart_menu ) {
		SetSaveGameGuiVars();
	}*/

	// NOTE(HM) i'm 99.9% sure this sets a event data struct to catch key presses
	//sysEvent_t  ev;
	//memset( &ev, 0, sizeof( ev ) );
	//ev.evType = SE_NONE;

	//guiActive->HandleEvent( &ev, com_frameTime );
	guiActive.activate( true, main::gpGame.time_ms );
}

fn void start(Desktop* gui) {
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
        if(!rl::isMusicStreamPlaying(gui.music_stream)) rl::playMusicStream(gui.music_stream);
    }

    setGUI(gui);

	//console->Close();
}

fn void stop() {
    Desktop* guiActive = getActiveMenu();
	//ClearWipe();

	// clear mapSpawned and demo playing flags
	//UnloadMap();

	// disconnect async client
	//idAsyncNetwork::client.DisconnectFromServer();

	// kill async server
	//idAsyncNetwork::server.Kill();

    // stop sound world
    if(guiActive)
    {
        if(rl::isMusicValid(guiActive.music_stream)) {
            // todo fade out the music stream
            if(rl::isMusicStreamPlaying(guiActive.music_stream)) rl::stopMusicStream(guiActive.music_stream);
            //rl::unloadMusicStream(guiActive.music_stream);
        }
    }
	//if ( sw ) {
		//sw->StopAllSounds();
	//}

	//insideUpdateScreen = false;
	//insideExecuteMapChange = false;

	// drop all guis
	setGUI(null);
}

fn void exit() {
	stop(); // menu

	// go back to the game sounds
	//soundSystem->SetPlayingSoundWorld( sw );

	// unpause the game sound world
	//if ( sw != NULL && sw->IsPaused() ) {
		//sw->UnPause();
	//}
}


// region MAIN MENU

fn WidgetText* create_menu_label(Vec2f pos, String text, int font_size, Color color, Desktop* menu) @local @inline {
    WidgetText* label = gui::createLabel("", text, color, menu);
    label.setFontSize(font_size);
    label.setPositionV(pos);
    return label;
}

const MAX_CALLBACK_PTRS @local = 10;
struct MenuButtonDef 
{
    Vec2f size;
    Color default_color;
    Color over_color;
    Color label_color;
    WidgetTextAlign label_align;
    WidgetCallback[MAX_CALLBACK_PTRS] callbacks;
}

macro create_menu_button(Vec2f pos, String text, MenuButtonDef* bdef, Desktop* menu) @local {
    WidgetButton* button = gui::createButton();
    button.name = button.name.tconcat(text);
    button.addTo(menu);
    button.setSizeV(bdef.size);
    button.setPositionV(pos);
    button.setDefaultColor(bdef.default_color);
    button.setOverColor(bdef.over_color);
    //
    float button_width  = bdef.size.x;
    float button_height = bdef.size.y;
    WidgetText* label   = gui::createLabel(text, text, bdef.label_color, menu);
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
    // callbacks
    button.onOver        = bdef.callbacks[0];//&button_onOver;
    button.onStopOver    = bdef.callbacks[1];//&button_onStopOver;
    button.onPress       = bdef.callbacks[2];//&start_button_onPress;
    button.onSinglePress = bdef.callbacks[3];//&start_button_onSinglePress;
    button.onRelease     = bdef.callbacks[4];//&button_onRelease;
}
    
fn Desktop* mainMenuCreate(int screenWidth, int screenHeight)
{
    Desktop* menu = mem::new(Desktop);
    menu.init("MainMenu");
    menu.setColor(rl::DARKGRAY);
    
    main::gpGame.mode = main::GameMode.MENU;

    String music_path = main::gpGame.app_base_folder.tconcat("music\\main_menu\\Swallow.ogg");
    if(fs::fileExists(music_path))
    {
        lgr::info(Where.FILE, "\tloading %s music: %s", menu.name, music_path);
    } else { 
        unreachable("music path not found: %s", music_path);
    }
    menu.music_stream = rl::loadMusicStream(music_path.zstr_tcopy());
    rl::setMusicVolume(menu.music_stream, 1.0f);

    Vec2f screen_center       = (Vec2f) {(float)screenWidth/2.0f, (float)screenHeight / 2.0f};
    Vec2f screen_top_center   = (Vec2f) {(float)screenWidth/2.0f, 0.0f};
    float screen_half_width   = screen_center.x;
    float screen_half_height  = screen_center.y;
    
    Vec2f default_button_size = { 0.10f*screenWidth, 0.05f*screenHeight };
    float button_width, button_height;
    button_width  = default_button_size.x;
    button_height = default_button_size.y;
    
// region widgets

    /*
    gui::WidgetContainer ct;

    ct.@container( menu, {
        .direction = gui::TOP_TO_BOTTOM,
        .background = rl::RED,
        .padding = {8, 8, 8, 8},
        .itemGap = 16,
        .minSize = { .w = 200 },
        .border_between = {2, rl::GREEN }
    }; WidgetContainer* pct )
    {
        //pct.register(any_make(create_menu_label({200, 200}, "test", 12, rl::GRAY, menu), WidgetText.typeid));
        //pct.register(any_make(create_menu_label({200, 200}, "test2", 12, rl::GRAY, menu), WidgetText.typeid));
    };
    */

    // region LABELS
    //*************
    // TITLE
    //*************
    const TITLE           = "FlatHead";
    const TITLE_FONT_SIZE = 50;
    float text_len = (float)rl::measureText(TITLE.zstr_tcopy(), TITLE_FONT_SIZE);
    Vec2f title_offset = misc::VEC_RIGHT * screen_top_center.x;
    title_offset -= {text_len / 2.0f, 0.0f};
    title_offset += misc::VEC_DOWN * (0.10f * screenHeight);
    create_menu_label(title_offset, TITLE, TITLE_FONT_SIZE, rl::GRAY, menu);
    //*************
    // SUBTITLE
    //*************
    const SUBTITLE           = "engine";
    const SUBTITLE_FONT_SIZE = 16;
    text_len = (float)rl::measureText(SUBTITLE.zstr_tcopy(), SUBTITLE_FONT_SIZE);
    Vec2f subtitle_offset = misc::VEC_RIGHT * screen_top_center.x;
    subtitle_offset -= {text_len / 2.0f, 0.0f};
    subtitle_offset += misc::VEC_DOWN * (0.18f * screenHeight);
    create_menu_label(subtitle_offset, SUBTITLE, SUBTITLE_FONT_SIZE, rl::RAYWHITE, menu);
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
    btn_def.callbacks[0] = &button_onOver;
    btn_def.callbacks[1] = &button_onStopOver;
    btn_def.callbacks[2] = &start_button_onPress;
    btn_def.callbacks[3] = &start_button_onSinglePress;
    btn_def.callbacks[4] = &button_onRelease;
    
    offset += misc::VEC_RIGHT * screen_half_width;
    offset -= {button_width / 2.0f, 0.0f};
    offset += misc::VEC_DOWN * (screenHeight / button_height) * 10;
    create_menu_button(offset, "START", &btn_def, menu);

    //************
    // QUIT
    //************
    btn_def.callbacks[2] = &quit_button_onPress;
    btn_def.callbacks[3] = &quit_button_onSinglePress;
    
    offset += misc::VEC_DOWN * button_height;
    offset.y += 0.5f * button_height;
    create_menu_button(offset, "QUIT", &btn_def, menu);
    
    //************
    // OPTIONS
    //************
    btn_def.callbacks[2] = &options_button_onPress;
    btn_def.callbacks[3] = &options_button_onSinglePress;
    
    offset += misc::VEC_DOWN * button_height;
    offset.y += 0.5f * button_height;
    create_menu_button(offset, "OPTIONS", &btn_def, menu);
    // end_region BUTTONS
// end_region widgets
    
    return menu;
}







// region callbacks

// generic button callbacks
fn void button_onOver(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if(self.active_visible_infocus() && self.asFocus()) {
        self.setColor(self.over_color);
    }
}

// generic button callbacks
fn void button_onStopOver(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if(self.color != self.default_color) self.setColor(self.default_color);
}

// generic button callbacks
fn void button_onRelease(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.active_visible_infocus() && self.asFocus()) {
        self.setColor(self.default_color);
        self.pressed = false;
        self.press_count = 0;
    }
}

<*
    generic button callback
    
    @param [in] widget : "widget calling this function"
    @require widget != null
*>
fn void button_onPress(Widget* widget) {
    WidgetButton* self = (WidgetButton*)widget;
    if (self.active() == false || self.asFocus() == false) return;
    if (self.pressed == false) {
        self.setColor(self.pressed_color);

        if (rl::isSoundValid(*self.interaction_sound)) {
            if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
        }
    }
    self.pressed = true;
    self.press_count++;
}

<*
    generic button callback
    
    @param [in] widget : "widget calling this function"
    @require widget != null
*>
fn void button_onSinglePress(Widget* widget) {
    WidgetButton* self = (WidgetButton*)widget;
    if (self.active() == false || self.asFocus() == false) return;

    if (rl::isSoundValid(*self.interaction_sound)) {
       if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
    }
    self.setColor(self.pressed_color);
}

// while the button is kept pressed
fn void start_button_onPress(Widget* widget) {
    button_onPress(widget);
}

fn void start_button_onSinglePress(Widget* widget) {
    button_onSinglePress(widget);
    menu::exit();
}

fn void quit_button_onPress(Widget* widget) {
    button_onPress(widget);
}

fn void quit_button_onSinglePress(Widget* widget) {
    button_onSinglePress(widget);
    main::quitGame();
}

fn void options_button_onPress(Widget* widget) {
    button_onPress(widget);
}

fn void options_button_onSinglePress(Widget* widget) {
    button_onSinglePress(widget);
    lgr::info(Where.CONSOLE, "Options Menu is still not done.");
    //lgr::info(Where.CONSOLE, "Pressed Count = %s.", ((WidgetButton*)widget).press_count);
    // TODO(HM) 
    //  Need to create a options menu
    //  I have two options, one create a new Desktop
    //  or two reuse the main menu desktop and create a overlay "window"
    //  thou for the overlay I will have to handle overlaping widgets...
    //gui::setGui();
}
// end_region Main Menu

// end_region
