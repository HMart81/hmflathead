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
            RLFilePathList droppedFiles = LoadDroppedFiles();

            if ((droppedFiles.count > 0) && IsFileExtension(droppedFiles.paths[0], ".rgs")) GuiLoadStyle(droppedFiles.paths[0]);

            UnloadDroppedFiles(droppedFiles);    // Clear internal buffers
        }

        example of a text input box made using raylib instead:
        https://github.com/raysan5/raylib/blob/master/examples/text/text_input_box.c

        // https://www.youtube.com/watch?v=w6Q-xmW729Y -- raygui tutorial on how to use the text input box.
*/

/*
module engine::tools::editor::anchor @private;

import engine::misc;
import std::collections::list;

// A Anchor is just a point where all editor widgets get connected
alias AnchorListPtrs = List{Anchor*};

struct Anchor @public @packed
{
    uint id;
    Vec2f point;
}

macro Anchor create(uint id, float x, float y) @public {
    Anchor local_anchor;
    local_anchor.id = id;
    local_anchor.point = {x, y};
    return local_anchor;
}

macro bool Anchor.equal(self, Anchor other) @operator(==)
{
    if(self.id == other.id && self.point == other.point) return true;

    return false;
}

macro bool Anchor.nequal(self, Anchor other) @operator(!=)
{
    return ((self == other) == false);
}

macro Vec2f Anchor.add(self, Vec2f vec) @operator(+)
{
    return self.point + vec;
}

macro Vec2f Anchor.sub(self, Vec2f vec) @operator(-)
{
    return self.point - vec;
}

macro Vec2f Anchor.addequals(self, Vec2f vec) @operator(+=)
{
    return self.point += vec;
}

macro Vec2f Anchor.subequals(self, Vec2f vec) @operator(-=)
{
    return self.point -= vec;
}

macro Vec2f Anchor.mul(self, Vec2f vec) @operator(*)
{
    return self.point * vec;
}

macro Vec2f Anchor.mulScaler(self, float sc) @operator(*)
{
    return self.point * sc;
}

macro Vec2f Anchor.mulScalerEqual(self, float sc) @operator(*=)
{
    return self.point *= sc;
}
*/

module engine::tools::editor;

import std::io, std::ascii, std::collections::list;
import engine::gui;
import engine::misc;
import engine::sys::cvar;
//import engine::tools::editor::anchor;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import game::main;

const CInt CONSOLE_FONT_SIZE @local = 12;
const CInt CONSOLE_MAX_LINES @local = 1000;
const CInt CONSOLE_INPUT_MAX_LINE_LENGTH @local = 1024;

Cvar con_debug @public = { "con_debug", CvarType.BOOL, "0", "enables console debugging mode"};

fn void register_cvars() @inline
{
    cvar::@register(&con_debug);
}

const MAX_EDIT_LINE @local = CONSOLE_INPUT_MAX_LINE_LENGTH;
struct AutoComplete @local
{
	bool valid;
	int	 length;
	char[MAX_EDIT_LINE] completionString;
	char[MAX_EDIT_LINE] currentMatch;
	int	 matchCount;
	int	 matchIndex;
	int	 findMatchIndex;
}

AutoComplete globalAutoComplete @local;

enum EditorKind @local
{
    MAIN_EDITOR,
    MATERIAL_EDITOR,
    GUI_EDITOR,
    SCENE_EDITOR,
    ANIMATION_EDITOR,
    SOUND_EDITOR,
    SCRIPT_EDITOR,
}

// Editor border colors for the editor window.
// This is used to set the screen box border color of the current open editor window.
const RLColor[*] EDITOR_BORDER_COLORS = {
    {0xFF, 0xFF, 0xFF, 0xFF}, // 0 white
    {0x00, 0x00, 0x00, 0xFF}, // 1 black
    {0xFF, 0x00, 0x00, 0xFF}, // 2 red
    {0x00, 0xFF, 0x00, 0xFF}, // 3 green
    {0x00, 0x00, 0xFF, 0xFF}, // 4 blue
    {0xFF, 0xFF, 0x00, 0xFF}, // 5 yellow
    {0x00, 0xFF, 0xFF, 0xFF}, // 6 cyan
    {0xFF, 0x00, 0xFF, 0xFF}, // 7 magenta
};

alias ConsoleHistory = List{String};

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

    RLColor background_color;
    RLRectangle main_window;

    GuiState gui_state;

    EditorKind kind; // the kind of editor currently opened
    EditorKind prev_kind; // the editor type that was previously opened
    RLColor* border_color; // the color of the screen box border of the current open editor window
    int input_dialog_open_count; // the number of input dialogs opened

    // shows or hides the console input window
    ConsoleHistory con_history;
    usz listView_scrollIndex; // scroll index for the list view of the console history
    int listView_Active;
    int listView_Focus;
    bool con_input_showWindow @if($defined(TextInputBox));


    char[CONSOLE_INPUT_MAX_LINE_LENGTH] con_input_buffer; // maximum length of the input line
    uint con_input_buffer_len;
    bool con_input_edit_mode; // if true, the console input is in edit mode, this means that the user can edit the input line
   
    String con_display_buffer; // the console display buffer, this is used to display the console input
    AutoComplete autoComplete; // auto complete struct for the console input
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

    self.con_input_edit_mode = true; // the console input is in edit mode by default
    self.listView_Active = 1; // the active item in the list view of the console history
    self.listView_Focus = -1; // the focused item in the list view of the console history
}

fn void Editor.deinit(&self) @inline
{
    self.border_color = null;
    
    // free the editor console history
    if (self.con_history.len() > 0) {
        self.con_history.free();
    }
    // free the editor input buffer
    mem::clear(&self.con_input_buffer, CONSOLE_INPUT_MAX_LINE_LENGTH);
    // clear the auto complete buffer
    self.autoCompleteClear();
}

fn void Editor.open(&self) @inline
{
    if (self.flags.is_opened) {
        return;
    }
    self.flags.is_opened = true;
    self.kind = EditorKind.MAIN_EDITOR;
    self.setVisible(); // also sets the editor to active
    game::gpGame.mode = GameMode.EDITOR;
}

fn bool Editor.isOpened(&self) => self.flags.is_opened;

fn EditorKind Editor.getOpenKind(&self) => self.kind;

fn void Editor.close(&self) @inline
{
    if (!self.flags.is_opened) {
        return;
    }
    self.flags.is_opened = false;
    self.setInvisible(); // also sets the editor to inactive and unfocused
    game::gpGame.mode = GameMode.NONE;
}


fn void Editor.setfocus(&self, bool choice) @inline
{
    self.flags.is_focused = choice;
    (choice) ? rgui::setState(STATE_FOCUSED) : rgui::setState(STATE_NORMAL);
}

fn bool Editor.focused(&self) => self.flags.is_focused;

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
    self.setActive();
}

fn void Editor.setInvisible(&self) @inline
{
    if (!self.flags.is_visible) {
        return;
    }
    self.flags.is_visible = false;
    self.setInactive();
    self.setfocus(false);
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
//    it will require conversion from world space coordinates to camera space.
fn bool Editor.isMouseOver(&self) @local
{
    if (self.isVisible() == false) return false;

    // gets windows mouse position...
    Vec2f mouseWorldPos = rl::getMousePosition();

    Vec2f mouse_rect_size = game::getGameCursorSize() * 0.5f; // half the size of the game cursor
    RLRectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_rect_size);

    if (rl::checkCollisionRecs(mouseRect, self.main_window)) return true;

    return false;
}

fn void Editor.update(&self) @inline
{
    if (self.isVisible() == false && self.isActive() == false) {
        return;
    }

    self.setfocus(self.isMouseOver());

    if (self.focused()) 
    {
        if(game::game_cursor_visible()) game::hide_game_cursor();
        if(!game::system_cursor_visible()) game::show_system_cursor();
    } else {
        if(game::system_cursor_visible()) game::hide_system_cursor();
        game::show_game_cursor();
    }

    if(self.input_dialog_open_count > 1) {
        unreachable("input_dialog_open_count > 1, this should never happen.");
    }
}

fn void Editor.draw(&self, int screenWidth, int screenHeight) 
{
    if (self.isActive() == false || self.isVisible() == false || self.isOpened() == false) {
        return;
    }

    switch(self.kind) 
    {
        case EditorKind.MAIN_EDITOR:      drawMainEditor(self);
        case EditorKind.MATERIAL_EDITOR:  drawMaterialEditor(self);
        case EditorKind.GUI_EDITOR:       drawGuiEditor(self);
        case EditorKind.SCENE_EDITOR:     drawSceneEditor(self);
        case EditorKind.ANIMATION_EDITOR: drawAnimationEditor(self);
        case EditorKind.SOUND_EDITOR:     drawSoundEditor(self);
        case EditorKind.SCRIPT_EDITOR:    drawScriptEditor(self);
    }
}

<* 
    Draws the main editor window.
    @param [&inout] editor: "the editor to draw."
*>
fn void drawMainEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the main editor drawing logic.
    io::printfn("Drawing main editor...");

    // draw the background
    rl::drawRectangleRec(editor.main_window, editor.background_color);

    // draw the main editor window
    if(rgui::windowBox(editor.main_window, "Editor")) {
        editor.close();
    }
    // draw the main editor tool bar
    drawEditorMainToolBar(editor);
    // draw the main editor console
    drawEditorConsole(editor);

    drawOpenEditorBorder(editor);
}

<* 
    Draws the material editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawMaterialEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the material editor drawing logic.
    io::printfn("Drawing material editor...");
}

<* 
    Draws the GUI editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawGuiEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the GUI editor drawing logic.
    io::printfn("Drawing GUI editor...");
}

<* 
    Draws the scene editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawSceneEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the scene editor drawing logic.
    io::printfn("Drawing scene editor...");
}

<* 
    Draws the animation editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawAnimationEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the animation editor drawing logic.
    io::printfn("Drawing animation editor...");
}

<* 
    Draws the sound editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawSoundEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the sound editor drawing logic.
    io::printfn("Drawing sound editor...");
}

<* 
    Draws the script editor window.
    @param [&in] editor: "the editor to draw."
*>
fn void drawScriptEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the script editor drawing logic.
    io::printfn("Drawing script editor...");
}

<* 
    Draws the main editor tool bar.
    @param [&in] editor: "the editor to draw the tool bar for."
*>
fn void drawEditorMainToolBar(Editor* editor)
{
    RLRectangle area = editor.main_window;

    Vec2f anchor = {area.x, area.y};
    float tb_y_anchor = 0.0075f * area.height;
    Vec2f btn_size = {20.0f, 20.0f};

    // Open Folder Button
    Vec2f btn0_pos = anchor + misc::VEC_RIGHT * 0.08f * area.width;
    btn0_pos.y += tb_y_anchor;
    @button(btn0_pos, btn_size, Icon.FOLDER_OPEN, &openFolderButtonCallback){};

    // Save Button
    Vec2f btn1_pos = btn0_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    @button(btn1_pos, btn_size, Icon.FILE_SAVE_CLASSIC, &saveButtonCallback){};

    // Undo Button
    Vec2f btn2_pos = btn1_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    @button(btn2_pos, btn_size, Icon.UNDO, &undoButtonCallback){};

    // Redo Button
    Vec2f btn3_pos = btn2_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    @button(btn3_pos, btn_size, Icon.REDO, &redoButtonCallback){};

$if $defined(TextInputBox):
    // open Console Button
    // TODO(HM): this should open the console window only, but for now it will open the console input box.
    Vec2f btn4_pos = btn3_pos + misc::VEC_RIGHT * btn_size.x * 1.5f;
    @button(btn4_pos, btn_size, Icon.WINDOW) {
        // open console window
        editor.con_input_showWindow = !editor.con_input_showWindow;
    };
$endif
}


// #region editor console
<* 
    Draws the editor console.
    @param [&in] editor: "the editor to draw the console for."
*>
fn void drawEditorConsole(Editor* editor)
{
    RLRectangle area = editor.main_window;

    // top left corner of the editor window
    Vec2f anchor = {area.x, area.y};
    float lft_lip = 0.008f * area.width;
    float rgt_lip = 0.008f * area.width;
    float buttom_lip = 0.020f * area.height;
    Vec2f console_size = {
        area.width - (lft_lip + rgt_lip),
        0.25f * area.height
    };
    Vec2f input_area = {console_size.x, 0.15f * console_size.y};
    Vec2f total_console_area = {console_size.x, console_size.y + input_area.y};

    Vec2f console_pos = anchor + misc::VEC_RIGHT * lft_lip + misc::VEC_DOWN * (area.height - total_console_area.y - buttom_lip);
    //console_pos.y -= (console_size.y + buttom_lip);

    //int prevTextBoxStyle = rgui::getStyle(TEXTBOX, rgui::TEXT_READONLY);
    //rgui::setStyle(TEXTBOX, rgui::TEXT_READONLY, 1);

    //rgui::textBox(misc::makeRect(console_pos, console_size), &editor.con_display_buffer, CONSOLE_FONT_SIZE, false);
    ZString console_hist_text; //= editor.con_history.first().zstr_tcopy();
    if(editor.con_history.len() > 0)
    {
        if(editor.con_history.len() > 1)
        {
            String previous;
            foreach(str : editor.con_history)
            {
                if(previous != "") {
                    console_hist_text = string::tformat_zstr("%s%s\n", previous, str.zstr_tcopy());
                } else {
                    console_hist_text = string::tformat_zstr("%s\n", str.zstr_tcopy());
                }
                previous = console_hist_text.str_view();
            }
        } else {
            if(try line = editor.con_history.first()) {
                console_hist_text = line.zstr_tcopy();
            }
        }
    } else {
        console_hist_text = "";
    }

    RLRectangle bounds = misc::makeRect(console_pos, console_size);
    // RLRectangle content = {rect.x, rect.y, rect.width, rect.height - input_area.y};
    // RLRectangle view = {};
    // RLVector2 scroll = {0.0f, 0.0f};
    // rgui::scrollPanel(rect, console_hist_text, content, &scroll, &view);

    List{ZString} console_hist_text_lines;
    foreach(str : editor.con_history)
    {
        if(str.len > 0) {
            console_hist_text_lines.push(str.zstr_tcopy());
        }
    }

    if(console_hist_text_lines.len() == 0) {
        console_hist_text_lines.push("No console history available.");
        rgui::listViewEx(bounds, &&console_hist_text_lines.first()!!, (CInt)console_hist_text.len(), (CInt*)&editor.listView_scrollIndex, &(CInt)editor.listView_Active, &(CInt)editor.listView_Focus);
    } else {
        rgui::textBox(misc::makeRect(console_pos, console_size), console_hist_text, MAX_EDIT_LINE, false);
    }


    //rgui::dummyRec(misc::makeRect(console_pos, console_size), "Console");
    //rgui::setStyle(TEXTBOX, rgui::TEXT_READONLY, prevTextBoxStyle);

     // draw the console input box
    //misc::drawDebugPoint(console_pos, rl::RED);
    //misc::drawDebugLine(console_pos, console_pos + misc::VEC_DOWN * console_size.y, rl::RED);
    Vec2f inputeBoxPos = console_pos + misc::VEC_DOWN * (console_size.y + input_area.y - buttom_lip);
    //misc::drawDebugPoint(inputeBoxPos, rl::GREEN);

$if $defined(TextInputBox):
    if(editor.con_input_showWindow && editor.input_dialog_open_count <= 1)
    {
        editor.input_dialog_open_count = 1;
       

        input_area = {console_size.x, console_size.y};
        const BTN_CLOSE = 0;
        const BTN_OK    = 1;
        const BTN_CLEAR = 2;
        ZString buttons = string::tformat_zstr("%s", "OK;Clear");
        // Text Input Box control, ask for text, supports secret
        int pressed = rgui::textInputBox(misc::makeRect(inputeBoxPos, input_area), "", "Console Input", buttons, (ZString)&editor.con_input_buffer[0], CONSOLE_INPUT_MAX_LINE_LENGTH, null);
        foreach(chr: editor.con_input_buffer) { 
            if(chr == 0) return; editor.con_input_buffer_len++;
        }
        switch(pressed) {
            case BTN_OK:    parse_console_input(editor);
            case BTN_CLEAR: clearConsoleInputBuffer(editor);
            case BTN_CLOSE: exitConsoleInput(editor);
            default:
                io::printfn("button pressed was value: %s", pressed);
        }
    }
$else
    //rgui::textBox(misc::makeRect(inputeBoxPos, input_area), (ZString)&editor.con_input_buffer[0], CONSOLE_FONT_SIZE, true);
    if(rgui::textBox(misc::makeRect(inputeBoxPos, input_area), (ZString)&editor.con_input_buffer[0], CONSOLE_INPUT_MAX_LINE_LENGTH, editor.con_input_edit_mode))
    {
        // this runs every time you press a key/M_Button inside the textbox area and at gui exit
        String input_text = ((ZString)&editor.con_input_buffer[0]).str_view();
        bool enter_pressed = rl::isKeyDown(rl::KEY_ENTER);
      /*  if (enter_pressed) {
            int stop_here = 1;
        }*/
        if(input_text.len && editor.isVisible() && enter_pressed) {
            // if the input text is not empty and the enter key is pressed, parse the console input
            parse_console_input(editor);
        }
        //editor.con_input_edit_mode = !editor.con_input_edit_mode;
    }
$endif
}

<* 
    Clears the console input buffer.
    @param [&in] editor: "the editor to clear the console input buffer for."
*>
fn void clearConsole(Editor* editor) @inline
{
    if(editor.con_history.len() > 0) {
        editor.con_history.clear();
    }
}

<* 
    eats the console input buffer.
    @param [&in] editor: "the editor to eat the console input buffer for."
*>
fn void eatConsoleInput(Editor* editor) @inline
{
    String input_text = ((ZString)&editor.con_input_buffer[0]).str_view();
    if(input_text != "") {
        mem::clear(&editor.con_input_buffer, CONSOLE_INPUT_MAX_LINE_LENGTH);
    }
}

<*
    exit the console input buffer and hides the console input window.
    @param [&in] editor: "the editor to exit the console input buffer for."
*>
fn void exitConsoleInput(Editor* editor) @inline @if($defined(TextInputBox))
{
    mem::clear(&editor.con_input_buffer, CONSOLE_INPUT_MAX_LINE_LENGTH);
    editor.con_input_showWindow = false; 
    editor.input_dialog_open_count = 0;
}

fn void addToConsoleHistory(Editor* editor, String input_text) //@inline
{
    float console_size_y = 0.25f * editor.main_window.height;
    int max_lines = ((int)console_size_y / CONSOLE_FONT_SIZE) - 1; // -1 to account for the input box line
    if (editor.con_history.len() >= max_lines) {
        editor.con_history.pop()!!;
    }
    editor.con_history.push(input_text);
}

macro void con_printfn(String fmt, ...) @public @builtin {
	DString str = dstring::temp_with_capacity(fmt.len + $vacount * 8);
	str.appendf(fmt, $vasplat);
	game::gpGame.editor.con_history.push(str.str_view().copy(mem));
}

<* 
    Parses the console input and executes the command.
    @param [&in] editor: "the editor to parse the console input for."
*>
fn void parse_console_input(Editor* editor) //@inline
{
    String input_text = ((ZString)&editor.con_input_buffer[0]).str_view();

    bool add_to_history = true;
    // TODO(HM): Implement a better console input parser.
    // This function should parse the console input and execute the command.
    io::printfn("Console input: %s", input_text);
    switch(input_text) 
    {
//$if $defined(TextInputBox):
//        case "exit":
//            exitConsoleInput(editor);
//$else
        case "exit":
            add_to_history = false; // do not add the exit command to the console history
            nextcase "quit";
//$endif
        case "quit":
$if $defined(TextInputBox):
            add_to_history = false; // do not add the quit command to the console history
            exitConsoleInput(editor);
$endif
            editor.close();
        case "clear":
            // todo(HM): ability to clear the console input buffer using key combination
            add_to_history = false; // do not add the clear command to the console history
            clearConsole(editor);
        case "help":
        case "h":
            add_to_history = false; // do not add the help command to the console history
            con_printfn("Console help: \n - exit/quit: exits the editor \n - clear: clears the console history \n - help: shows this help message \n - debug: enables console debug mode \n - debug off: disables console debug mode \n - debug info: shows debug info");
        case gui::ui_editGui.name:
            add_to_history = false; // do not add the ui_editGUI command to the console history
            /*editor.editor_opened_prev = editor.kind;
            editor.kind = EditorKind.GUI_EDITOR;
            editor.setActive();
            editor.setVisible();
            game::gpGame.mode = GameMode.EDITOR;
            con_printfn("GUI Editor opened.");*/
            (guieditor::is_opened()) ?  guieditor::close() : guieditor::open();
            nextcase "quit";
        default:
            con_printfn("Unknown command: %s", input_text);
            io::printfn("Unknown command: %s", input_text);
    }

    if(input_text != "" && add_to_history != false)
    {
        // if the input text is not empty and not 'clear' or 'help' command, add it to the console history
        addToConsoleHistory(editor, input_text.copy(mem));
        eatConsoleInput(editor);
    }
}

// #endregion editor console
<* 
    Draws the border around the open editor window.
    This is used to visually distinguish between different editor windows.
    @param [&inout] editor: "the editor to draw the border for."
*>
fn void drawOpenEditorBorder(Editor* editor) @inline
{
    switch(editor.kind) {
        case EditorKind.MAIN_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[0]; // white
            break;
        case EditorKind.MATERIAL_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[3]; // green
            break;
        case EditorKind.GUI_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[5]; // yellow
            break;
        case EditorKind.SCENE_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[4]; // blue
            break;
        case EditorKind.ANIMATION_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[2]; // red
            break;
        case EditorKind.SOUND_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[6]; // cyan
            break;
        case EditorKind.SCRIPT_EDITOR:
            editor.border_color = &EDITOR_BORDER_COLORS[7]; // magenta
            break;
    }

    int w, h;
    w = (int)game::gpGame.screen.w;
    h = (int)game::gpGame.screen.h;
    rl::drawRectangleLinesEx({0, 0, w, h}, 2.0f, *editor.border_color);
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

macro @button(Vec2f pos, Vec2f size, ZString text, ButtonfuncCallback callback = null; @body) @local
{
    var rec = (RLRectangle){pos.x, pos.y, size.x, size.y};
    if(rgui::button(rec, text)) {
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


// #region CONSOLE INPUT

fn void Editor.autoCompleteClear(&self) @inline
{
    self.autoComplete.valid = false;
    self.autoComplete.length = 0;
    self.autoComplete.matchCount = 0;
    self.autoComplete.matchIndex = 0;
    self.autoComplete.findMatchIndex = 0;
    mem::clear(&globalAutoComplete.completionString, MAX_EDIT_LINE);
    mem::clear(&globalAutoComplete.currentMatch, MAX_EDIT_LINE);
}

fn void findMatches( String s ) 
{
	if ( s != globalAutoComplete.completionString[..] ) {
		return;
	}
	globalAutoComplete.matchCount++;
	if ( globalAutoComplete.matchCount == 1 ) {
        globalAutoComplete.currentMatch = s[0:globalAutoComplete.currentMatch.len];
		return;
	}

    int i;
	// cut currentMatch to the amount common with s
	for ( i; s[i]; i++ ) {
		if ( ascii::to_lower( globalAutoComplete.currentMatch[i] ) != ascii::to_lower( s[i] ) ) {
			globalAutoComplete.currentMatch[i] = 0;
			break;
		}
	}
	globalAutoComplete.currentMatch[i] = 0;
}

fn void findIndexMatch( String s )
{
	if ( s != globalAutoComplete.completionString[..] ) {
		return;
	}

	if( globalAutoComplete.findMatchIndex == globalAutoComplete.matchIndex ) {
        globalAutoComplete.currentMatch = s[0:globalAutoComplete.currentMatch.len];
	}

	globalAutoComplete.findMatchIndex++;
}


fn void printMatches( String s ) {
	if ( s == globalAutoComplete.currentMatch[..] ) {
		io::printfn( "    %s", s );
	}
}


fn void printCvarMatches( String s ) {
    if ( s == globalAutoComplete.currentMatch[..] ) {
		io::printfn( "    %s = \"%s\"", s, cvar::getCVarString( s ) );
	}
}
// #endregion CONSOLE INPUT
