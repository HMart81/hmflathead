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

    - Create a GUIWindow
    	GUIWindow main_menu;
    - init the GUIWindow
    	main_menu.ini(...);
    - create any children panels/widgets
    	GUIWidgetButton main_menu_button;
    - init the GUIWidget and add it to GUIWindow
    	main_menu_button.init();
    	main_menu_button.addTo(&main_menu);

    or

    - Create a GUIWindow
    	GUIWindow menu;
    - init the GUIWindow
    	menu.ini(...);
	- add children using the addChildren block
		menu.@addChildren() 
		{
			// create any children panels/widgets
			{
				GUIWidgetButton button0;
				// init the GUIWidget
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
import engine::sys::ctype;
import engine::tools;
import engine::logging::log;
import engine::filesystem::fs;
import thirdparty::raylib5::rl;
import engine::sys::framework::language::lang;
import engine::sys::framework::soundbkd;
import engine::assets_api::astmng;
// end_region

// region alias
alias pGameContext @local  = game::pContext;
// end_region

// region constants
// NOTE(HM) In Raylib window top-left corner is (0,0), 
// is different from OpenGL where the bottom-left corner is (0,0)
// this means that when rendering images sometimes they 
// need to be inverted to display correctly.
// UPDATE(HM) No need to invert anymore, that is done in the shader now.
const SCREEN_TOP_CORNER = (Vec2f) {0.0f, 0.0f}; 
// end_region

fn GUIWindow* getActiveMenu() @local @inline 
{
	return pGameContext.guiActive;
}

fn void setGUI(GUIWindow* menu) 
{
    GUIWindow* guiActive;

    // if the incoming menu is set to null, deactivate the current menu
	if (menu == null)
    {
        guiActive = getActiveMenu();
        if ( guiActive != null ) {
            guiActive.deactivate();
        }
        pGameContext.guiActive = null;
		return;
	}

    // else set the current menu to the desired one
    guiActive = menu;
    if(guiActive.hidden()) {
        guiActive.show();
    }
    // update the global game pointer to the gui
	pGameContext.guiActive = guiActive;

	if (guiActive == pGameContext.main_menu)
    {
        if(pGameContext.mode != game::GameMode.MENU) {
			pGameContext.mode = game::GameMode.MENU;
		}

        if(editor::isOpen(&pGameContext.editor)) {
            if(game::game_cursor_visible()) game::hide_game_cursor();
        } else {
           if(game::game_cursor_hidden()) game::show_game_cursor();
        }
	}

    guiActive.setFocus(true);
}

fn void start(GUIWindow* gui) 
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
	soundbkd::setPlayingSoundWorld( &main_menu_sound_world );
	if(!pGameContext.pause_all_music) {
		main_menu_sound_world.playSound("Swallow", is_music: true);
	}

    setGUI(gui);

	//console->Close();
}

fn void stop(GUIWindow* guiActive = getActiveMenu()) 
{
	// clear mapSpawned
	//UnloadMap();

    // stop gui sound world
    if(guiActive)
    {
        if(guiActive.sound_world) {
            // todo fade out the music stream
            guiActive.sound_world.stop();
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
    pGameContext.mode = GameMode.PLAYING;

	// go back to the game sounds
	//soundSystem->SetPlayingSoundWorld( sw );

	// unpause the game sound world
	//if ( sw != NULL && sw->IsPaused() ) {
		//sw->UnPause();
	//}
}


//////////////////////////////////////////////////////////////////
/* #region MAIN MENU */

HMSoundWorld main_menu_sound_world;

<*
    Create a checkbox for the menu

    @param [in] text : "checkbox label text"
    @param [&in] bdef : "button callbacks definition struct pointer"
    @ensure return != null : "pointer to the created checkbox"
*>
fn GUIWidgetCheckBox* GUIWindow.create_menu_checkbox(&self, String text, MenuButtonDef* bdef) @inline 
{
    GUIWidgetCheckBox* checkbox = gui::createCheckBox("Checkbox 1");
    checkbox.color = rl::DARKGRAY;
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
fn void init_checkbox(GUIWidgetCheckBox* chk, String name, String label, MenuButtonDef* bdef, GUIWindow* uiwin) 
{
	chk.init();
	chk.name = name;
	chk.setLabel(label);
    chk.color = rl::DARKGRAY;
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

fn GUIWidgetLabel* create_label(String text, RLColor color, GUIWindow* uiwin)
{
    GUIWidgetLabel* label = mem::new(GUIWidgetLabel);
    gui::init_label(label, text, pGameContext.font_candara, 0, color, uiwin);
	return label;
}

constdef CallBack : inline int @local
{
	OVER = 0,  // mouse over button
    STOP_OVER,
    PRESS,  // press down
    SINGLE_PRESS, // press down then release
	RELEASE,
    CREATE // on button creation
}

struct MenuButtonDef
{
    Vec2f pos;
    Vec2f size;
    RLColor default_color;
    RLColor over_color;
    RLColor label_color;
    TextAlign label_align;
    GUIWidgetCallback[CallBack::len] cbs;
}

<*
    Create a button with a text label for the menu

    @param [&inout] uiwin : "the window to create the button for"
    @param [in] text : "button label text"
    @param [&in] bdef : "button cbs definition struct pointer"
    @ensure return != null : "pointer to the created button"
*>
fn GUIWidgetButton* create_text_button(GUIWindow* uiwin, String text, MenuButtonDef* bdef) 
{
    GUIWidgetButton* button = gui::createButton();
    defer {
        button.addTo(uiwin);
    };
    // set the button properties
    button.name = button.name.tconcat(text);
    button.setSizeV(bdef.size);
    button.setPositionV(bdef.pos);
    button.setDefaultColor(bdef.default_color);
	//button.hide();
    //
    float button_width  = bdef.size.x;
    float button_height = bdef.size.y;

	GUIWidgetLabel* label = create_label(text, bdef.label_color, uiwin);
    // set the label properties
    label.setPositionV(bdef.pos);
    Vec2f label_offset  = {
        .x = 0.5f * button_width - (float)label.textlen() / 2,
        .y = 0.5f * button_height - ((button_height / 2) * 0.5f)
    };
    label.addToPositionV(label_offset);
    label.bindTo(button);

    // button interaction callbacks
    button.onOver        = bdef.cbs[CallBack.OVER];
    button.onStopOver    = bdef.cbs[CallBack.STOP_OVER];
    button.onPress       = bdef.cbs[CallBack.PRESS];
    button.onSinglePress = bdef.cbs[CallBack.SINGLE_PRESS];
    button.onRelease     = bdef.cbs[CallBack.RELEASE];
    button.onLoad        = bdef.cbs[CallBack.CREATE];

    // button on load callback runs right now when the button is created
    // perhaps rename this to onCreate?
    if(button.onLoad) button.onLoad(button);

    return button;
}

<*
    Create a button for the menu

    @param [&in] bdef : "button cbs definition struct pointer"
    @ensure return != null : "pointer to the created button"
*>
fn GUIWidgetButton* create_menu_button(GUIWindow* uiwin, MenuButtonDef* bdef) 
{
    GUIWidgetButton* button = gui::createButton();
    defer {
        button.addTo(uiwin);
    };
    // set the button properties
    button.name = "Menu_Button";
    button.setSizeV(bdef.size);
    button.setPositionV(bdef.pos);
    button.setDefaultColor(bdef.default_color);
    //

    // button interaction callbacks
    button.onOver        = bdef.cbs[CallBack.OVER]; // &button_onOver;
    button.onStopOver    = bdef.cbs[CallBack.STOP_OVER]; // &button_onStopOver;
    button.onPress       = bdef.cbs[CallBack.PRESS]; // &start_button_onPress;
    button.onSinglePress = bdef.cbs[CallBack.SINGLE_PRESS]; // &start_button_onSinglePress;
    button.onRelease     = bdef.cbs[CallBack.RELEASE]; // &button_onRelease;
    button.onLoad        = bdef.cbs[CallBack.CREATE];

    // button on load callback runs right now when the button is created
    // perhaps rename this to onCreate?
    if(button.onLoad) button.onLoad(button);

    return button;
}

<*
    Create a desktop
*>
macro GUIWindow* @desktop(String name, int page_count = 0; @body(GUIWindow*))
{
	GUIWindow* desktop = mem::new(GUIWindow);
    desktop.init(name, isDesktop: true);
	desktop.setPageCount(page_count);
	@body(desktop);
	return desktop;
}

/*
<*
    Create a window page
*>
macro GUIWindow* @page(String name, GUIWindow* desk; @body(GUIWindow*))
{
	GUIWindow* page = mem::new(GUIWindow);
    page.init(name);
	page.desktop = desk;
	@body(page);
	return page;
}
*/

// Main Meny extra windows indices
const MAINMENU_OPTIONS = 0;
const MAINMENU_EXTRA   = 1;
const MAINMENU_PAGE_COUNT = 2; // update this is more consts are define above this

fn GUIWindow* mainMenuCreate(int screenWidth, int screenHeight)
{
    // Menu creation
	return @desktop("MainMenu", MAINMENU_PAGE_COUNT; GUIWindow* desk_main)
	{
		desk_main.setColor(rl::DARKGRAY);
		Vec2f screen_center       = desk_main.getAnchor(GUIAnchorID.CENTER); //game::getScreenCenterPos();
		float screen_half_width   = screen_center.x;
		float screen_half_height  = screen_center.y;
		Vec2f screen_top_center   = desk_main.getAnchor(GUIAnchorID.TOP_CENTER); //{screen_half_width, 0.0f};


		// create window options
		GUIWindow* window_options = mem::new(GUIWindow);
		window_options.init("OptionsMenu", w: (int)(0.75f*desk_main.rect.w), h: (int)(0.75f*desk_main.rect.h));
		window_options.setColor(rl::GRAY);
		desk_main.addPage(MAINMENU_OPTIONS, window_options);
		window_options.desktop = desk_main;
		Vec2f page_options_offset = screen_center - window_options.getSize() / 2.0f;
		window_options.setPositionV({
			.x = page_options_offset.x,
			.y = page_options_offset.y
		});
		Vec2f page_top_corner =  window_options.getAnchor(GUIAnchorID.TOP_CENTER);
		// link the menus
		// TODO change this to a virtual machine of states
		// or a particular menu current state
		// like case OPTIONS_OPEN: we are seeing the options page
		// or even GUIWindow* current_page = &desk_main;
		//desk_main.next = window_options;
		window_options.previous = desk_main;
		window_options.hide();

		// create window extra
		GUIWindow* window_extra = mem::new(GUIWindow);
		window_extra.init("ExtraMenu",  w: (int)(0.75f*desk_main.rect.w), h: (int)(0.75f*desk_main.rect.h));
		window_extra.setColor(rl::GRAY);
		desk_main.addPage(MAINMENU_EXTRA, window_extra);
		window_extra.desktop = desk_main;
		window_extra.setPositionV({
			.x = page_options_offset.x,
			.y = page_options_offset.y
		});
		window_extra.hide();
		
		// relative to the music folder inside data folder
		String music_folder = pGameContext.app_base_folder.tconcat("music\\");
		String music_path = "main_menu\\Swallow.ogg";
		String fullpath = music_folder.tconcat(music_path);
		if(fs::fileExists(fullpath))
		{
			log::info(FILE, "\tloading %s music: %s", desk_main.name, fullpath);
		}
		else
		{ 
			unreachable("music path not found: %s", music_path);
		}

		main_menu_sound_world.init("SoundWorld_MainMenu");
		main_menu_sound_world.addMusic(music_path.to_tpath())!!;
		//@catch(soundbkd::addMusicTo(&main_menu_sound_world, music_path.to_tpath()));
		//@catch(main_menu_sound_world.addMusicAsset(astmng::get_asset{RLMusic}("Swallow.ogg")));
		desk_main.sound_world = &main_menu_sound_world;
		window_options.sound_world = desk_main.sound_world;
		window_extra.sound_world = desk_main.sound_world;
		//HMSpeaker{HMMusic}* music = main_menu_sound_world.getMusicEmitter(main_menu_music_id)!!;
		//if(music) music.audio.setVolume(1.0f);
		
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
			//pct.register(any_make(create_menu_label({200, 200}, "test", 12, rl::GRAY, desk_main), GUIWidgetLabel));
			//pct.register(any_make(create_menu_label({200, 200}, "test2", 12, rl::GRAY, desk_main), GUIWidgetLabel));
		};
		*/

		// region LABELS
		//*************
		// TITLE
		//*************
		const TITLE           = "FlatHead";
		const TITLE_FONT_SIZE = 50;
		RLFont* title_font = pGameContext.font_trojan_pro;
		GUIWidgetLabel* title_label = mem::new(GUIWidgetLabel);
		gui::init_label(title_label, TITLE, title_font, TITLE_FONT_SIZE, rl::GRAY, desk_main);
		Vec2f title_offset = misc::VEC_RIGHT * screen_top_center.x;
		title_offset -= {title_label.text_len / 2.0f, 0.0f};
		title_offset += misc::VEC_DOWN * (0.10f * screenHeight);
		title_label.setPositionV(title_offset);
		title_label.setAlign(TextAlign.LEFT);
		//*************
		// SUBTITLE
		//*************
		const SUBTITLE           = "engine";
		const SUBTITLE_FONT_SIZE = 16;
		RLFont* subtitle_font = pGameContext.font_lucida;
		GUIWidgetLabel* subtitle_label = mem::new(GUIWidgetLabel);
		gui::init_label(subtitle_label, SUBTITLE, subtitle_font, SUBTITLE_FONT_SIZE, rl::RAYWHITE, desk_main);
		Vec2f subtitle_offset = misc::VEC_RIGHT * screen_top_center.x;
		subtitle_offset -= {subtitle_label.text_len / 2.0f, 0.0f};
		subtitle_offset += misc::VEC_DOWN * (0.145f * screenHeight);
		subtitle_label.setPositionV(subtitle_offset);
		subtitle_label.setAlign(TextAlign.LEFT);
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
		btn_def.cbs[CallBack.CREATE]       = &button_onLoad;
		
		offset += misc::VEC_RIGHT * screen_half_width;
		offset -= {button_width / 2.0f, 0.0f};
		offset += misc::VEC_DOWN * (screenHeight / button_height) * 10;
		String btn_string = lang::dict.getString(0);
		btn_def.pos = offset;
		create_text_button(desk_main, btn_string/*"START"*/, &btn_def);

		//************
		// QUIT
		//************
		btn_def.cbs[CallBack.PRESS]        = &quit_button_onPress;
		btn_def.cbs[CallBack.SINGLE_PRESS] = &quit_button_onSinglePress;
		
		offset += misc::VEC_DOWN * button_height;
		offset.y += 0.5f * button_height;
		btn_string = lang::dict.getString(1);
		btn_def.pos = offset;
		create_text_button(desk_main, btn_string/*"QUIT"*/, &btn_def);
		
		//************
		// OPTIONS
		//************
		btn_def.cbs[CallBack.PRESS]        = &options_button_onPress;
		btn_def.cbs[CallBack.SINGLE_PRESS] = &options_button_onSinglePress;
		
		offset += misc::VEC_DOWN * button_height;
		offset.y += 0.5f * button_height;
		btn_string = lang::dict.getString(3);
		btn_def.pos = offset;
		create_text_button(desk_main, btn_string/*"OPTIONS"*/, &btn_def);
		// end_region BUTTONS

		// region widgets options
		//************
		// Checkbox 1
		//******
		btn_def.cbs[CallBack.PRESS]        = null; //&checkbox1_onPress;
		btn_def.cbs[CallBack.SINGLE_PRESS] = &checkbox1_onSinglePress;

		//GUIWidgetCheckBox* checkbox1 = window_options.create_menu_checkbox("Checkbox 1", &btn_def);
		GUIWidgetCheckBox* checkbox1 = mem::new(GUIWidgetCheckBox);
		init_checkbox(checkbox1, "checkbox1", "no Sound", &btn_def, window_options);
		offset = window_options.getPosition();
		offset += misc::VEC_RIGHT * (window_options.getSize().x / 2);
		offset += misc::VEC_DOWN * (0.20f * window_options.getSize().y);
		checkbox1.setPositionV(offset);
		checkbox1.setSize(20, 20);
		//************
		// GO TO MAIN MENU
		//************
		btn_def.cbs[CallBack.PRESS]        = &back_button_options_onPress;
		btn_def.cbs[CallBack.SINGLE_PRESS] = &back_button_options_onSinglePress;
		
		offset = window_options.getPosition();
		offset += misc::VEC_RIGHT * (0.10f * (window_options.getSize().x / 2));
		offset += misc::VEC_DOWN * window_options.getSize().y;
		offset.y -= button_height + (0.5f * button_height);
		btn_def.pos = offset;
		btn_string = lang::dict.getString(4);
		create_text_button(window_options, btn_string/*"BACK"*/, &btn_def);
	// end_region widgets
    
    //return desk_main;
	};
}

 /* #endregion Main Menu */




////////////////////////////////////////////////////////////////////////
/* #region  ################ Button callbacks ########################## */

// generic button callbacks
<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void button_onLoad(any widget) 
{
    switch (widget.type)
    {
        case GUIWidgetButton:
        {
            GUIWidgetButton* self = (GUIWidgetButton*)widget.ptr;
            log::info(CONSOLE, "GUIWidgetButton '%s' loaded.", self.name);
        }
        case GUIWidgetCheckBox:
        {
            GUIWidgetCheckBox* self = (GUIWidgetCheckBox*)widget.ptr;
            log::info(CONSOLE, "GUIWidgetCheckBox '%s' loaded.", self.name);
        }
        default:
        {
            unreachable("widget type not handled in button_onLoad: %s", widget.type);
        }
    }
    //log::info(Where.CONSOLE, "GUIWidgetButton '%s' loaded.", self.name);
}

// generic button callbacks
<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void button_onOver(any widget/*GUIWidget* widget*/) 
{
	if(rl::isMouseButtonDown(RLMouseButton.LEFT))
	{
		return;
	}

    switch (widget.type)
    {
        case GUIWidgetButton:
        case GUIWidgetCheckBox:
        case GUIWidgetLabel:
        {
            GUIWidget* self = (GUIWidget*)widget.ptr;
            if(self.active_visible_infocus() && self.isHot())
            {
            	self.setColor(GUIActionColor.OVER);
            }
        }
        default:
        {
            unreachable("widget type not handled in button_onOver: %s", widget.type);
        }
    }
}

// generic button callbacks
<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void button_onStopOver(/*GUIWidget* widget*/ any widget) 
{

    switch (widget.type)
    {
        case GUIWidgetButton:
        case GUIWidgetCheckBox:
        case GUIWidgetLabel:
        {
            GUIWidget* self = (GUIWidget*)widget.ptr;
    		if(self.isHot()) return;
            if(self.active_visible_infocus())
            {
            	self.color = self.original_color;
            }
        }
        default:
        {
            unreachable("widget type not handled in button_onOver: %s", widget.type);
        }
    }
}

// generic button callbacks
<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void button_onRelease(/*GUIWidget* widget*/ any widget) 
{
    if(widget.type == GUIWidgetButton)
	{
        GUIWidgetButton* self = (GUIWidgetButton*)widget.ptr;
        if (self.active_visible_infocus() && self.isHot())
		{
            self.color = self.original_color;
            self.pressed = false;
            self.press_count = 0;
        }
        return;
    } else {
        unreachable("widget type %s is not a button!", widget.type);
    }
    /*GUIWidgetButton* self = (GUIWidgetButton*)widget;
    if (self.active_visible_infocus() && self.asFocus()) {
        self.setColor(self.default_color);
        self.pressed = false;
        self.press_count = 0;
    }*/
}

<*
    generic button callback
    @param [&in] widget : "widget calling this function"
*>
fn void button_onPress(any widget)
{
    if(widget.type == GUIWidgetButton)
	{
        GUIWidgetButton* self = (GUIWidgetButton*)widget.ptr;
        if (self.active() == false || self.asFocus() == false || self.isHot() == false) return;
        if (self.pressed == false) 
		{
            self.setColor(GUIActionColor.MDOWN);

            // TODO(HM) change this to use the sound world
            if(!game::s_noaudio.getBool())
            {
                if (rl::isSoundValid(*self.interaction_sound) && 
                   !rl::isSoundPlaying(*self.interaction_sound))
                {
                    rl::playSound(*self.interaction_sound);
                }
            }
        }
        self.pressed = true;
		self.setColor(GUIActionColor.GRABED);
        self.press_count++;
        return;
    } else {
        unreachable("widget type %s is not a button!", widget.type);
    }
    /*GUIWidgetButton* self = (GUIWidgetButton*)widget;
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
    
    @param [&in] widget : "widget calling this function"
*>
fn void button_onSinglePress(any widget) 
{
    if(widget.type == GUIWidgetButton) 
    {
        GUIWidgetButton* self = (GUIWidgetButton*)widget.ptr;
        if (self.active() == false || self.asFocus() == false || !self.isHot()) return;

        // TODO(HM) change this to use the sound world
        if(!game::s_noaudio.getBool())
        {
            if (rl::isSoundValid(*self.interaction_sound)) {
            if(!rl::isSoundPlaying(*self.interaction_sound)) rl::playSound(*self.interaction_sound);
            }
        }
        self.setColor(GUIActionColor.MDOWN);
        //return;
    } else {
        unreachable("widget %s is not a valid button!", ((GUIWidget*)widget.ptr).name);
    }
}

// while the button is kept pressed
<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void start_button_onPress(/*GUIWidget* widget*/ any widget) 
{
    button_onPress(widget);
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void start_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    menu::exit();
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void quit_button_onPress(any widget) 
{
    button_onPress(widget);
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void quit_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    game::quitGame();
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void options_button_onPress(any widget) 
{
    button_onPress(widget);
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void options_button_onSinglePress(any widget) 
{
    button_onSinglePress(widget);
    GUIWindow* active_menu = getActiveMenu();
	if(active_menu.getName() == "MainMenu")
    {
        GUIWindow* next_menu = active_menu.getChildWindow(MAINMENU_OPTIONS);
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }
    /*if(active_menu) 
    {
        GUIWindow* next_menu = active_menu.next;
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }*/
    //log::info(Where.CONSOLE, "Options Menu is still not done.");
    //log::info(Where.CONSOLE, "Pressed Count = %s.", ((GUIWidgetButton*)widget).press_count);
    // TODO(HM) 
    //  Need to create a options menu
    //  I have two options, one create a new GUIWindow
    //  or two reuse the main menu window and create a overlay "window"
    //  thou for the overlay I will have to handle overlaping widgets...
    //gui::setGui();
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void back_button_options_onPress(any widget) 
{
    button_onPress(widget);
    GUIWindow* active_menu = getActiveMenu();
	if(active_menu) {
        GUIWindow* next_menu;
		switch(active_menu.getName())
		{
			case "MainMenu": break; 
			case "OptionsMenu":
			case "ExtraMenu":
				next_menu = gui::gpWindowManager.get("MainMenu");
			default: unreachable();
		}
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }
    /*if(active_menu && active_menu.previous != null) {
        GUIWindow* next_menu = active_menu.previous;
        if(next_menu != null)
        {
            stop(active_menu); // clear the current menu
            start(next_menu); // set the next menu
        }
    }*/
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void back_button_options_onSinglePress(any widget) 
{
    back_button_options_onPress(widget);
}

fn void checkbox1_onPress(any widget) 
{
    //
}

<*
    @param [&in] widget : "the widget we are dealing with"
*>
fn void checkbox1_onSinglePress(any widget) 
{
    if(widget.type == GUIWidgetButton)
    {
        GUIWidgetCheckBox* this = (GUIWidgetCheckBox*)widget.ptr;
        this.setChecked(!this.checked);
        //log::info(CONSOLE, "Checkbox 1 is now %s.", this.isChecked() ? "checked" : "unchecked");
		if(this.isChecked())
        {
			//log::info(CONSOLE, "Checkbox 1 is now checked.");
			pGameContext.pause_all_music = 1;
			if(pGameContext.guiActive)
            {
				HMSoundWorld* current_sound_world = pGameContext.guiActive.sound_world;
				if(current_sound_world)
                {
					if(current_sound_world.hasSoundsPlaying())
                    {
						//HMSpeaker{HMMusic*}[] = current_sound_world.getPlayingMusic();
						current_sound_world.pause();
					}
				}
			}
		} 
        else // not checked state
        {
			//log::info(CONSOLE, "Checkbox 1 is now unchecked.");
			pGameContext.pause_all_music = 0;
			if(pGameContext.guiActive)
            {
				HMSoundWorld* current_sound_world = pGameContext.guiActive.sound_world;
				if(current_sound_world) {
					current_sound_world.resumeSound("Swallow", is_music: true);
				}
			}
		}
    } 
    else 
    {
        unreachable("widget %s is not a valid button!", ((GUIWidget*)widget.ptr).name);
    }
}

/* #endregion button callbacks */
 
