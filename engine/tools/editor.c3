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

/* TODO(HM): 
    - Implement the editor console.
    - Implement the editor file system.
    - Implement the editor undo/redo system.
    - Implement the editor save/load system.
    - Implement the editor settings system.

    - Implement file drop system.
    // example from raygui c code:
    if (IsFileDropped())
        {
            FilePathList droppedFiles = LoadDroppedFiles();

            if ((droppedFiles.count > 0) && IsFileExtension(droppedFiles.paths[0], ".rgs")) GuiLoadStyle(droppedFiles.paths[0]);

            UnloadDroppedFiles(droppedFiles);    // Clear internal buffers
        }

        example of a text input box made using raylib instead:
        https://github.com/raysan5/raylib/blob/master/examples/text/text_input_box.c
*/


module engine::editor::ed;

import std::io;
import engine::misc;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import game::main;

//const Icon[] ICONS = {
    // Icon.FILE_SAVE,
    // Icon.FILE_OPEN,
    // Icon.FILE_NEW,
    // Icon.FILE_ADD,
    // Icon.FILE_DELETE,
    // Icon.FOLDER_FILE_OPEN,
    // Icon.FOLDER_OPEN,
    // Icon.FOLDER_SAVE,
    // Icon.FILE_SAVE_CLASSIC,
// //};

const CInt CONSOLE_FONT_SIZE = 12;
const CInt CONSOLE_MAX_LINES = 1000;

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

    float scr_width = (float)rl::getScreenWidth();
    float scr_height = (float)rl::getScreenHeight();
    float x, y, w, h;
    x = 0.25f * scr_width;
    y = 0.05f * scr_height;
    w = scr_width / 2.0f;
    h = scr_height / 2.0f;
    self.main_window = { x, y, w, h };
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

fn bool Editor.isOpened(&self) => self.flags.is_opened;

fn void Editor.close(&self) @inline
{
    if (!self.flags.is_opened) {
        return;
    }
    self.flags.is_opened = false;
    self.setInvisible();
    main::gpGame.mode = GameMode.NONE;
}


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
    rgui::enable();
    //rgui::setState(STATE_NORMAL);
}

fn bool Editor.isActive(&self) => self.flags.is_active;

fn void Editor.setInactive(&self) @inline
{
    if (!self.flags.is_active) {
        return;
    }
    self.flags.is_active = false;
    rgui::disable();
    //rgui::setState(STATE_DISABLED);
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
    rgui::unlock();
}

fn void Editor.setUnresizable(&self) @inline
{
    if (!self.flags.is_resizable) {
        return;
    }
    self.flags.is_resizable = false;
    rgui::lock();
}

fn void Editor.setMinimizable(&self) @inline
{
    // TODO(HM): Implement minimizable window when possible.
    // if (self.flags.is_minimizable) {
    //     return;
    // }
    // self.flags.is_minimizable = true;
}

fn void Editor.setUnminimizable(&self) @inline
{
    // if (!self.flags.is_minimizable) {
    //     return;
    // }
    // self.flags.is_minimizable = false;
}

fn void Editor.setMaximizable(&self) @inline
{
    // if (self.flags.is_maximizable) {
    //     return;
    // }
    // self.flags.is_maximizable = true;
}

fn void Editor.setUnmaximizable(&self) @inline
{
    // if (!self.flags.is_maximizable) {
    //     return;
    // }
    // self.flags.is_maximizable = false;
}

fn void Editor.setClosable(&self) @inline
{
    // if (self.flags.is_closable) {
    //     return;
    // }
    // self.flags.is_closable = true;
}

fn void Editor.setUnclosable(&self) @inline
{
    // if (!self.flags.is_closable) {
    //     return;
    // }
    // self.flags.is_closable = false;
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
    if (self.isOpened() == false && self.isVisible() == false && self.isActive() == false) {
        return;
    }

    if (self.isMouseOver()) 
    {
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
    if (self.isActive() == false || self.isVisible() == false) {
        return;
    }

    // draw the entire editor here
    if (self.flags.is_active)
    {
        // draw the background
        rl::drawRectangleRec(self.main_window, self.background_color);

        // draw the main window
        //rgui::setStyle(DEFAULT, rgui::BORDER, (int)self.background_color.r);
        //rgui::setStyle(DEFAULT, rgui::BASE,   (int)self.background_color.g);
        //rgui::setStyle(DEFAULT, rgui::TEXT,   (int)self.background_color.b);
        //rgui::setStyle(DEFAULT, rgui::OTHER,  (int)self.background_color.a);

        //rgui::setStyle(DEFAULT, 4, (int)self.main_window.x);
        //rgui::setStyle(DEFAULT, 5, (int)self.main_window.y);
        //rgui::setStyle(DEFAULT, 6, (int)self.main_window.width);
        //rgui::setStyle(DEFAULT, 7, (int)self.main_window.height);

        // draw the editor window
       if(rgui::windowBox(self.main_window, "Editor")) {
            self.close();
       }
       drawEditorMainToolBar(self.main_window);
       drawEditorConsole(self.main_window);
    }
}

fn void drawEditorMainToolBar(Rectangle area)
{
    Vec2f anchor = {area.x, area.y};
    float tb_y_anchor = 0.0075f * area.height;
    Vec2f btn_size = {20.0f, 20.0f};


    // Open Folder Button
    Vec2f btn0_pos = anchor + misc::VEC_RIGHT * 0.08f * area.width;
    btn0_pos.y += tb_y_anchor;
    String btn0_type = Icon.FOLDER_OPEN.str;

    @button(btn0_pos, btn_size, btn0_type, &openFolderButtonCallback){};

    // Save Button
    Vec2f btn1_pos = btn0_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    String btn1_type = Icon.FILE_SAVE_CLASSIC.str;

    @button(btn1_pos, btn_size, btn1_type, &saveButtonCallback){};

    // Undo Button
    Vec2f btn2_pos = btn1_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    String btn2_type = Icon.UNDO_FILL.str;

    @button(btn2_pos, btn_size, btn2_type, &undoButtonCallback){};

    // Redo Button
    Vec2f btn3_pos = btn2_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    String btn3_type = Icon.REDO_FILL.str;
    @button(btn3_pos, btn_size, btn3_type, &redoButtonCallback){};
}


fn void drawEditorConsole(Rectangle area)
{
    // top left corner of the editor window
    Vec2f anchor = {area.x, area.y};
    float lft_lip = 0.008f * area.width;
    float rgt_lip = 0.008f * area.width;
    float buttom_lip = 0.020f * area.height;
    Vec2f console_size = {
        area.width - (lft_lip + rgt_lip),
        0.25f * area.height
    };

    Vec2f console_pos = anchor + lft_lip + misc::VEC_DOWN * area.height;
    console_pos.y -= (console_size.y + buttom_lip);

    //rgui::setStyle(TEXTBOX, rgui::TEXT_READONLY, 1);
    //rgui::textBox(misc::makeRect(console_pos, console_size), "Console", CONSOLE_FONT_SIZE, false);

    Vec2f textInputePos = console_pos + misc::VEC_DOWN * console_size.y;
    Vec2f textInputSize = {console_size.x, console_size.y};
    ZString buttons = string::tformat_zstr("%s", "OK;Cancel");
    DString textInputBuffer = dstring::new_with_capacity(tmem, 256);
    defer textInputBuffer.free();
    CInt textMaxSize = 256;
    // Text Input Box control, ask for text, supports secret
    int interaction = rgui::textInputBox(misc::makeRect(textInputePos, textInputSize), "", "Console Input", buttons, textInputBuffer.zstr_view(), textMaxSize, null);
    if(interaction == 1) {
        io::printfn("Text input box OK button pressed.");
    } else if(interaction == 2) {
        io::printfn("Text input box Cancel button pressed.");
    } else if(interaction == 0) {
        io::printfn("Text input box closed.");
    }
}

// #region DRAWING HELPERS

// coordinates are in pixels
fn void drawVerticalLine(Vec2f start, float lenght) @inline @local
{
    float w = 2.0f;
    start += misc::VEC_DOWN * lenght;
    Vec2f end = start + misc::VEC_DOWN * lenght;

    rgui::line({ start.x, start.y, w, end.y }, "");
}

fn void drawHorizontalLine(Vec2f start, float lenght) @inline @local
{
    float h = 2.0f;
    start += misc::VEC_RIGHT * lenght;
    Vec2f end = start + misc::VEC_RIGHT * lenght;

    rgui::line({ start.x, start.y, end.x, h }, "");
}

alias ButtonfuncCallback = fn void(void*);

macro @button(Vec2f pos, Vec2f size, String text, ButtonfuncCallback callback = null; @body) @local
{
    var rec = (Rectangle){pos.x, pos.y, size.x, size.y};
    if(rgui::button(rec, text.zstr_tcopy())) {
        if (callback != null) {
            callback(null);
        }
        @body();
    }
}
// #endregion DRAWING HELPERS


// #region EDITOR BUTTONS CALLBACKS
fn void openFolderButtonCallback(void* data) @inline @local
{
    io::printfn("Open folder button pressed.");
}

fn void saveButtonCallback(void* data) @inline @local
{
    io::printfn("Save button pressed.");
}

fn void undoButtonCallback(void* data) @inline @local
{
    io::printfn("Undo button pressed.");
}

fn void redoButtonCallback(void* data) @inline @local
{
    io::printfn("Redo button pressed.");
}

// #endregion EDITOR BUTTONS CALLBACKS