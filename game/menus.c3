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

module game::gui::menu;

/**
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
**/

// region modules
import std::io;
import std::core::mem; // for malloc
import std::math::vector;
import std::collections::list;
import engine::gui;
import engine::misc;
import game::main;
import thirdparty::raylib5::rl;
// end_region

// region alias
// end_region

// region constants
// end_region

fn Desktop* getActiveMenu() @local {
	return main::gpGame.guiActive;
}

fn void setGUI(Desktop* menu) {
    main::gpGame.guiActive = menu;
    Desktop* guiActive     = main::gpGame.guiActive;
	if ( !guiActive ) {
		return;
	}

    // todo
	/*if ( guiActive == main::gpGame.main_menu ) {
		SetSaveGameGuiVars();
		SetMainMenuGuiVars();
	} else if ( guiActive == main::gpGame.restart_menu ) {
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
    Desktop* guiActive = getActiveMenu();
    
    // if already started
	if ( guiActive == gui ) {
		return;
	}

	// pause the game sound world
	/*if ( sw != NULL && !sw->IsPaused() ) {
		sw->Pause();
	}*/

	// start playing the menu sounds
	//soundSystem->SetPlayingSoundWorld( menuSoundWorld );

    setGUI(gui);

	//console->Close();
}

fn void stop() {
	//ClearWipe();

	// clear mapSpawned and demo playing flags
	//UnloadMap();

	// disconnect async client
	//idAsyncNetwork::client.DisconnectFromServer();

	// kill async server
	//idAsyncNetwork::server.Kill();

    // stop sound world
	//if ( sw ) {
		//sw->StopAllSounds();
	//}

	//insideUpdateScreen = false;
	//insideExecuteMapChange = false;

	// drop all guis
	setGUI(null);
}

fn void exit() {
	main::gpGame.guiActive = null;

	// go back to the game sounds
	//soundSystem->SetPlayingSoundWorld( sw );

	// unpause the game sound world
	//if ( sw != NULL && sw->IsPaused() ) {
		//sw->UnPause();
	//}
}


// region MAIN MENU
fn Desktop* mainMenuCreate(int screenWidth, int screenHeight) {
    Desktop* menu = mem::new(Desktop);
    menu.init("MainMenu");
    menu.setColor(rl::DARKGRAY);

    Vec2f screen_corner       = {0, 0};
    Vec2f offset              = screen_corner;
    Vec2f default_button_size = { 0.10f* screenWidth, 0.05f*screenHeight };
    float button_width, button_height;
// region widgets
    //*************
    // TITLE
    //*************
    Vec2f title_offset;
    title_offset += misc::VEC_RIGHT * (((float)screenWidth / 2.0f) - (button_width / 2.0f));
    WidgetText* title_label = gui::createLabel("", "FlatHead", rl::GRAY, menu);
    title_label.setFontSize(50);
    title_offset -= title_label.getWidth() / 2;
    title_offset += misc::VEC_DOWN * (0.25f * screenHeight);
    title_label.setPositionV(title_offset);
    //*************
    // SUBTITLE
    //*************
    Vec2f subtitle_offset;
    subtitle_offset += misc::VEC_RIGHT * (((float)screenWidth / 2.0f) - (button_width / 2.0f));
    WidgetText* subtitle_label = gui::createLabel("", "engine", rl::RAYWHITE, menu);
    //subtitle_label.setFontSize(10);
    subtitle_offset -= subtitle_label.getWidth() / 2;
    subtitle_offset += misc::VEC_DOWN * (0.22f * screenHeight);
    subtitle_label.setPositionV(subtitle_offset);
    //*************
    // START
    //*************
    WidgetButton* start_button = gui::createButton("Start", menu);
    start_button.setSizeV(default_button_size);
    button_width  = start_button.getWidth();
    button_height = start_button.getHeight();
    offset += misc::VEC_RIGHT * (((float)screenWidth / 2.0f) - (button_width / 2.0f));
    offset += misc::VEC_DOWN * (screenHeight / button_height) * 10;
    start_button.setPositionV(offset);
    start_button.setDefaultColor(rl::YELLOW);
    start_button.setOverColor(rl::RED);
    //
    WidgetText* start_btn_label = gui::createLabel("", "START", rl::DARKGRAY, menu);
    //start_btn_label.setAlign(WidgetTextAlign.RIGHT);
    start_btn_label.setPositionV(offset);
    start_btn_label.addToPosition(
        x: 0.15f * button_width,
        y: 0.25f * button_height
    );
    //
    // callbacks
    start_button.onOver        = &button_onOver;
    start_button.onStopOver    = &button_onStopOver;
    start_button.onPress       = &start_button_onPress;
    start_button.onSinglePress = &start_button_onSinglePress;
    start_button.onRelease     = &button_onRelease;
    //************
    // QUIT
    //************
    WidgetButton* quit_button = gui::createButton("Quit", menu);
    quit_button.setSizeV(default_button_size);
    offset += misc::VEC_DOWN * button_height;
    offset.y += (0.50f* button_height);
    quit_button.setPositionV(offset);
    quit_button.setDefaultColor(rl::YELLOW);
    quit_button.setOverColor(rl::RED);
    //
    WidgetText* quit_btn_label = gui::createLabel("", "QUIT", rl::DARKGRAY, menu);
    //start_btn_label.setAlign(WidgetTextAlign.RIGHT);
    quit_btn_label.setPositionV(offset);
    quit_btn_label.addToPosition(
        x: 0.15f * button_width,
        y: 0.25f * button_height
    );
    // callbacks
    quit_button.onOver        = &button_onOver;
    quit_button.onStopOver    = &button_onStopOver;
    quit_button.onPress       = &quit_button_onPress;
    quit_button.onSinglePress = &quit_button_onSinglePress;
    quit_button.onRelease     = &button_onRelease;
// end_region widgets
    
    return menu;
}







// region callbacks

// generic button callbacks
fn void button_onOver(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.setColor(self.over_color);
}

// generic button callbacks
fn void button_onStopOver(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.isInteractive() == false) return;
    self.setColor(self.default_color);
}

// generic button callbacks
fn void button_onRelease(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.setColor(self.default_color);
    self.pressed = false;
    self.press_count = 0;
}

// generic button callbacks
fn void button_onPress(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.isInteractive() == false || self.asFocus() == false) return;
    if (self.pressed == false) {
        self.setColor(self.pressed_color);

        if (rl::isSoundValid(*self.interaction_sound)) {
            if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
        }
    }
    self.pressed = true;
    self.press_count++;
}

// generic button callbacks
fn void button_onSinglePress(Widget* widget) {
    assert(widget != null);
    WidgetButton* self = (WidgetButton*)widget;
    if (self.isInteractive() == false || self.asFocus() == false) return;

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
// end_region Main Menu

// end_region
