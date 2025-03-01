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

/*
module game::gui::mainmenu;

// region C3 modules
import std::io;
import std::core::mem; // for malloc
import std::math;
import std::collections::list;
// end_region

// region custom modules
//import game::interfaces::gui;
import game::misc::hm;
import game::main;
import raylib5::rl;
//import ent;
//import misc::dyarray;
// end_region

// region defines
// end_region

// region constants
// end_region

fn Desktop* create(int screenWidth, int screenHeight) {
    Desktop* menu = mem::new(Desktop);
    menu.init("MainMenu", {0, 0, screenWidth, screenHeight }, rl::GRAY, null);
    
    Vec2f screen_corner       = {0, 0};
    Vec2f offset              = screen_corner;
    Vec2f default_button_size = { 0.10f* screenWidth, 0.05f*screenHeight };
    float button_width, button_height;
// region widgets
    // START
    WidgetButton* start_button = mem::new(WidgetButton);
    start_button.init(menu);
    defer { menu.addWidget(start_button); }
    start_button.setSizeV(default_button_size);
    button_width  = start_button.rect.width;
    button_height = start_button.rect.height;
    offset += misc::VEC_RIGHT * (((float)screenWidth / 2.0f) - (button_width / 2.0f));
    offset += misc::VEC_DOWN * button_height;
    start_button.setPositionV(offset);
    start_button.setDefaultColor(rl::YELLOW);
    start_button.setOverColor(rl::RED);
    start_button.onOver        = &start_button_onOver;
    start_button.onStopOver    = &start_button_onStopOver;
    start_button.onPress       = &start_button_onPress;
    start_button.onSinglePress = &start_button_onSinglePress;
    // QUIT
    WidgetButton* quit_button = mem::new(WidgetButton);
    quit_button.init(menu);
    defer { menu.addWidget(quit_button); }
    quit_button.setSizeV(default_button_size);
    offset += misc::VEC_DOWN * (0.10f*default_button_size.y);
    start_button.setPositionV(offset);
    start_button.setDefaultColor(rl::YELLOW);
    start_button.setOverColor(rl::RED);
// end_region widgets
    
    return menu;
}


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

/*
<*
* @param [in] menu "menu to draw"
* @require menu != null
*>
// fn void draw(Desktop* menu) {
    // menu.draw();
// }

<*
* @param [in] menu "menu to destroy"
* @require menu != null
*>
// fn void destroy(Desktop* menu) {
    // menu.clear();
// }
*/
