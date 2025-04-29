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

module engine::editor::ed;

import std::io;
import engine::misc;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import game::main;


struct EditorFlags @local
{
    bool is_opened;
    bool is_active;
    bool is_visible;
    bool is_focused;
    bool is_resizable;
    bool is_minimizable;
    bool is_maximizable;
    bool is_closable;
    bool is_fullscreenable;
    bool is_docked;
    bool is_dockable;
}

struct Editor {
    EditorFlags flags;

    Color background_color;
    Rectangle main_window;

    GuiState gui_state;
}

fn void Editor.initDefaults(&self) @inline
{
    self.flags.is_minimizable = true;
    self.flags.is_maximizable = true;
    self.flags.is_closable = true;

    self.background_color = {0x18, 0x18, 0x18, 0xFF};
    self.main_window = (Rectangle){0, 0, (float)rl::getScreenWidth() / 2.0f, (float)rl::getScreenHeight() / 2.0f};
}

fn void Editor.open(&self) @inline
{
    if (self.flags.is_opened) {
        return;
    }
    self.flags.is_opened = true;
    self.setActive();
    self.setVisible();
    main::gpGame.mode = GameMode.EDITOR;
}

fn void Editor.close(&self) @inline
{
    if (!self.flags.is_opened) {
        return;
    }
    self.flags.is_opened = false;
    self.setInvisible();
    main::gpGame.mode = GameMode.NONE;
}

fn bool Editor.isOpened(&self) => self.flags.is_opened;

fn void Editor.setFocused(&self) @inline
{
    if (self.flags.is_focused) {
        return;
    }
    self.flags.is_focused = true;
    rgui::setState(STATE_FOCUSED);
}

fn void Editor.unfocus(&self) @inline
{
    if (!self.flags.is_focused) {
        return;
    }
    self.flags.is_focused = false;
    rgui::setState(STATE_NORMAL);
}

fn bool Editor.focused(&self) => self.flags.is_focused && rgui::getState() == STATE_FOCUSED;

fn void Editor.setActive(&self) @inline
{
    if (self.flags.is_active) {
        return;
    }
    self.flags.is_active = true;
    rgui::setState(STATE_NORMAL);
}

fn void Editor.setInactive(&self) @inline
{
    if (!self.flags.is_active) {
        return;
    }
    self.flags.is_active = false;
    rgui::setState(STATE_DISABLED);
}

fn void Editor.setVisible(&self) @inline
{
    if (self.flags.is_visible) {
        return;
    }
    self.flags.is_visible = true;
}

fn void Editor.setInvisible(&self) @inline
{
    if (!self.flags.is_visible) {
        return;
    }
    self.flags.is_visible = false;
    self.setInactive();
    self.unfocus();
}

fn bool Editor.isVisible(&self) => self.flags.is_visible;

fn void Editor.setResizable(&self) @inline
{
    if (self.flags.is_resizable) {
        return;
    }
    self.flags.is_resizable = true;
}

fn void Editor.setUnresizable(&self) @inline
{
    if (!self.flags.is_resizable) {
        return;
    }
    self.flags.is_resizable = false;
}

fn void Editor.setMinimizable(&self) @inline
{
    if (self.flags.is_minimizable) {
        return;
    }
    self.flags.is_minimizable = true;
}

fn void Editor.setUnminimizable(&self) @inline
{
    if (!self.flags.is_minimizable) {
        return;
    }
    self.flags.is_minimizable = false;
}

fn void Editor.setMaximizable(&self) @inline
{
    if (self.flags.is_maximizable) {
        return;
    }
    self.flags.is_maximizable = true;
}

fn void Editor.setUnmaximizable(&self) @inline
{
    if (!self.flags.is_maximizable) {
        return;
    }
    self.flags.is_maximizable = false;
}

fn void Editor.setClosable(&self) @inline
{
    if (self.flags.is_closable) {
        return;
    }
    self.flags.is_closable = true;
}

fn void Editor.setUnclosable(&self) @inline
{
    if (!self.flags.is_closable) {
        return;
    }
    self.flags.is_closable = false;
}

fn void Editor.setFullscreenable(&self) @inline
{
    if (self.flags.is_fullscreenable) {
        return;
    }
    self.flags.is_fullscreenable = true;
}

fn void Editor.setUnfullscreenable(&self) @inline
{
    if (!self.flags.is_fullscreenable) {
        return;
    }
    self.flags.is_fullscreenable = false;
}

fn void Editor.setDockable(&self) @inline
{
    if (self.flags.is_dockable) {
        return;
    }
    self.flags.is_dockable = true;
}

fn void Editor.setUndockable(&self) @inline
{
    if (!self.flags.is_dockable) {
        return;
    }
    self.flags.is_dockable = false;
}

//    WARNING(HM)
//    If the 2D camera view is changed in any way besides moving in x and y
//    like if the camera is zoomed or the camera is rotated, this will break.
//    If so it will require conversion from world space coordinates to camera space.
fn bool Editor.isMouseOver(&self) @local
{
    if (self.isVisible() == false) return false;

    // gets windows mouse position...
    Vec2f mouseWorldPos = rl::getMousePosition().toVec2f();

    // a small 32x32 pixels box
    const Vec2f MOUSE_SIZE = {32, 32};
    Rectangle mouseRect = misc::@recFromVecs(mouseWorldPos, MOUSE_SIZE);

    if (rl::checkCollisionRecs(mouseRect, self.main_window)) return true;

    return false;
}

fn void Editor.update(&self) @inline
{
    if (self.isVisible() == false) {
        return;
    }

    if (self.isMouseOver()) {
        self.setFocused();
        if(main::game_cursor_visible()) main::hide_game_cursor();
        if(!main::system_cursor_visible()) main::show_system_cursor();
    } else {
        self.unfocus();
        if(main::system_cursor_visible()) main::hide_system_cursor();
        main::show_game_cursor();
    }
}

fn void Editor.draw(&self, int screenWidth, int screenHeight) 
{
    if (self.isVisible() == false) {
        return;
    }

    // draw the entire editor here
    if (self.flags.is_active)
    {
       self.flags.is_active = !rgui::windowBox(self.main_window, "Editor");
       float xpos = self.main_window.x + self.main_window.width - 1.0f;
       float ypos = self.main_window.y + self.main_window.height - 1.0f;
       rgui::button((Rectangle){xpos, ypos, 20.0f, 20.0f}, "#1#X");
    }
}

// #region DRAWING HELPERS
fn void drawLine(float start, float end, float w, float h) @inline @local
{
    rgui::line((Rectangle){ start, end, w, h }, "");
}
// #endregion DRAWING HELPERS