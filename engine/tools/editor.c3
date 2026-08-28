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

module engine::tools @private @if($feature(MICROUI_ENABLE) &&& !$feature(RGUI_ENABLE));
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


import std::io, std::core::ascii, std::collections::list;
import engine::gui;
import engine::misc;
import engine::sys::cvar;
import thirdparty::raylib5::rl;
import thirdparty::microui::mu;  // micro ui
import engine::filesystem::fs::win32;
import std::os::win32;
import engine::logging::log;
import game::main;

const CInt CONSOLE_FONT_SIZE @local = 12;
const CInt CONSOLE_MAX_LINES @local = 1000;
const CInt CONSOLE_INPUT_MAX_LINE_LENGTH @local = 1024;

CVar con_debug @public = { "con_debug", CvFlag.BOOL|CvFlag.TOOL, "0", "enables console debugging mode"};

fn void register_cvars() @public @inline
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

constdef EditorKind : inline int @local
{
    MAIN_EDITOR = 1,
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
    bool is_fullscreen;
    bool is_docked;
    bool is_dockable;
}

struct Editor @public
{
    EditorFlags flags;

    // gui context
    RLColor background_color;
    RLRectangle main_window_rect;
    MU_Context ctx;

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

<*
	Initialize all default setting the editor needs at start
	@param [&inout] editor : "the editor context/data structure"
*>
fn void initDefaults(Editor* editor) @inline @public
{
    editor.flags.is_minimizable = true;
    editor.flags.is_maximizable = true;
    editor.flags.is_closable = true;

    editor.background_color = {0x18, 0x18, 0x18, 0xFF};

    float scr_width = (float)rl::getScreenWidth();
    float scr_height = (float)rl::getScreenHeight();
    editor.main_window_rect = {
        .x = 0.25f * scr_width,
        .y = 0.05f * scr_height,
        .w = scr_width / 2.0f,
        .h = scr_height / 2.0f
    };

    editor.con_input_edit_mode = true; // the console input is in edit mode by default
    editor.listView_Active = 1; // the active item in the list view of the console history
    editor.listView_Focus = -1; // the focused item in the list view of the console history
}

<*
	De-Initialize all data of the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void deinit(Editor* editor) @inline @public
{
    editor.border_color = null;
    
    // free the editor console history
    if (editor.con_history.len() > 0) {
        editor.con_history.free();
    }
    // free the editor input buffer
    mem::clear(&editor.con_input_buffer, CONSOLE_INPUT_MAX_LINE_LENGTH);
    // clear the auto complete buffer
    editor.autoCompleteClear();
}

<*
	Open the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void open(Editor* editor) @inline @public
{
    if (isOpen(editor)) return;
    
    editor.flags.is_opened = true;
    editor.kind = EditorKind.MAIN_EDITOR;
    setVisible(editor); // also sets the editor to active
    game::pContext.mode = GameMode.EDITOR;
}

<*
	Close the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void close(Editor* editor) @inline @public
{
    if (!isOpen(editor)) return;
    
    editor.flags.is_opened = false;
    setInvisible(editor); // also sets the editor to inactive and unfocused
    game::pContext.mode = GameMode.NONE;
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isOpen(Editor* editor) @inline @public
{
	return (game::pContext.mode == GameMode.EDITOR && editor.flags.is_opened);
}

<*
	What kind of editor is being interacted with right now
	@param [&in] editor : "the editor context/data structure"
*>
fn EditorKind getOpenEditorKind(Editor* editor) => editor.kind;

<*
	Set the editor to being the window in focus
	aka the mouse is over the editor window
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "boolean to set focus true or false, true by default"
*>
fn void setfocus(Editor* editor, bool choice = true) @inline
{
    editor.flags.is_focused = choice;
    if(choice) editor.ctx.set_focus((MU_Id)0);
}

<*
	If the editor is the window in focus
	aka the mouse is over the editor window
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isFocused(Editor* editor) @inline @public => editor.flags.is_focused;

<*
	Set the editor active
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setActive(Editor* editor) @inline
{
    if (isActive(editor)) return;
    editor.flags.is_active = true;
    rgui::enable();
}

<*
	Ask if the editor is active
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isActive(Editor* editor) @inline => editor.flags.is_active;

<*
	Deactivate the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void deactivate(Editor* editor) @inline
{
    if (isActive(editor) == false) {
        return;
    }
    editor.flags.is_active = false;
    rgui::disable();
}

<*
	Make editor visible
	@param [&inout] editor : "the editor context/data structure"
	@param activate : "if should activate the editor at the same time, default is yes"
*>
fn void setVisible(Editor* editor, bool activate = true) @inline
{
    if (isVisible(editor)) return;
    
    editor.flags.is_visible = true;
    if(activate) setActive(editor);
}

<*
	Make editor invisible
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setInvisible(Editor* editor) @inline
{
    if (isVisible(editor) == false)  return;
    
    editor.flags.is_visible = false;
    deactivate(editor);
    setfocus(editor, false);
}

<*
	Ask if editor is visible
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isVisible(Editor* editor) @inline => editor.flags.is_visible;

<*
	Set editor to resizable
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setResizable(Editor* editor) @inline
{
    if (isResizable(editor)) return;
    
    editor.flags.is_resizable = true;
    rgui::unlock();
}

<*
	Lock editor size, so it can't be resizable
	@param [&inout] editor : "the editor context/data structure"
*>
fn void lockSize(Editor* editor) @inline
{
    if (isResizable(editor) == false) return;
    
    editor.flags.is_resizable = false;
    rgui::lock();
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isResizable(Editor* editor) @inline => editor.flags.is_resizable;


<*
	Editor window can be minimized/hidden to OS taskbar 
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setMinimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY))
{
    if (isMinimizable(editor)) return;
    editor.flags.is_minimizable = true;
}

<*
	Disable Editor window minimization to OS taskbar 
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setUnminimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY))
{
    if (isMinimizable(editor) == false) return;
    editor.flags.is_minimizable = false;
}

<*
	Ask if editor is minimizable
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isMinimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY)) => editor.flags.is_minimizable;

<*
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "if should make the editor fullscreen, default is yes"
*>
fn void enableFullscreen(Editor* editor, bool choice = true) @inline
{
    if (isFullscreen(editor)) return;
    editor.flags.is_fullscreen = choice;
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isFullscreen(Editor* editor) @inline => editor.flags.is_fullscreen;


<*
	Editor windows can be dockable
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "the default is yes"
*>
fn void setDockable(Editor* editor, bool choice = true) @inline
{
    if (isDockable(editor)) return;
    editor.flags.is_dockable = choice;
}

<*
	Ask if editor is dockable
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isDockable(Editor* editor) @inline => editor.flags.is_dockable;


<*
    WARNING(HM)
    If the 2D camera view is zoomed or rotated, this will break.
    in those cases this will require conversion from 
    world space coordinates to camera space.
	@param [&in] editor : "the editor context/data structure"
    @require game::pContext.view.camera.zoom == 1.0f
*>
fn bool isMouseOver(Editor* editor)
{
    if (isVisible(editor) == false) return false;

    // gets mouse position in pixel coordinates...
    Vec2f mouseWorldPos = rl::getMousePosition();

    Vec2f mouse_rect_size = game::getGameCursorSize() * 0.5f; // half the size of the game cursor
    //RLRectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_rect_size);
    RLRectangle mouseRect = {
        .pos  = mouseWorldPos, 
        .size = mouse_rect_size
    };

    if (rl::checkCollisionRecs(mouseRect, editor.main_window_rect)) return true;

    return false;
}

macro @noUpdate(#editor) @local => (!isVisible(#editor) || !isOpen(#editor) || !isActive(#editor));

<*
	@param [&inout] editor : "the editor context/data structure"
*>
fn void update(Editor* editor) @public
{
    if (@noUpdate(editor)) return;

    if (setfocus(editor, isMouseOver(editor)))
    {
        if(game::game_cursor_visible()) game::hide_game_cursor();
        if(!game::system_cursor_visible()) game::show_system_cursor();
    } else {
        if(game::system_cursor_visible()) game::hide_system_cursor();
        game::show_game_cursor();
    }

    if(editor.input_dialog_open_count > 1) {
        unreachable("input_dialog_open_count > 1, this should never happen.");
    }
}


macro @noDraw(#editor) @local => (!isVisible(#editor) || !isOpen(#editor));

<*
	@param [&inout] editor : "the editor context/data structure"
*>
fn void draw(Editor* editor) @public
{
    if (@noDraw(editor)) return;

    switch(editor.kind) 
    {
        case MAIN_EDITOR:      drawMainEditor(editor);
        case MATERIAL_EDITOR:  drawMaterialEditor(editor);
        case GUI_EDITOR:       drawGuiEditor(editor);
        case SCENE_EDITOR:     drawSceneEditor(editor);
        case ANIMATION_EDITOR: drawAnimationEditor(editor);
        case SOUND_EDITOR:     drawSoundEditor(editor);
        case SCRIPT_EDITOR:    drawScriptEditor(editor);
    }
}

<* 
    Draws the main editor window.
    @param [&inout] editor: "the editor to draw."
*>
fn void drawMainEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the main editor drawing logic.
    //io::printfn("Drawing main editor...");

    // draw the background
    rl::drawRectangleRec(editor.main_window_rect, editor.background_color);

    // draw the main editor window
    bool _close = rgui::windowBox(editor.main_window_rect, "Editor");
    if(_close) close(editor);

    // draw the main editor tool bar
    drawEditorMainToolBar(editor);
    // draw the main editor console
    drawEditorConsole(editor);
	// draw color border
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
    RLRectangle area = editor.main_window_rect;

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
    @param [&inout] editor: "the editor to draw the console for."
*>
fn void drawEditorConsole(Editor* editor)
{
    RLRectangle area = editor.main_window_rect;

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
        if(input_text.len && isVisible(editor) && enter_pressed) {
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
    float console_size_y = 0.25f * editor.main_window_rect.height;
    int max_lines = ((int)console_size_y / CONSOLE_FONT_SIZE) - 1; // -1 to account for the input box line
    if (editor.con_history.len() >= max_lines) {
        editor.con_history.pop()!!;
    }
    editor.con_history.push(input_text);
}

macro void con_printfn(String fmt, ...) @public @builtin {
	DString str = dstring::temp_with_capacity(fmt.len + $vaarg.len * 8);
	str.appendf(fmt, ...$vaarg);
	game::pContext.editor.con_history.push(str.str_view().copy(mem));
}

<* 
    Parses the console input and executes the command.
    @param [&inout] editor: "the editor to parse the console input for."
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
            close(editor);
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
            game::pContext.mode = GameMode.EDITOR;
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
    switch(editor.kind) 
    {
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
    w = (int)game::pContext.screen.w;
    h = (int)game::pContext.screen.h;
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

//////////////////////////////////////////////////////////////
// #region EDITOR BUTTONS CALLBACKS
//////////////////////////////////////////////////////////////
fn void openFolderButtonCallback(void* data) @inline @local
{
    io::printfn("Open folder button pressed.");
    // NOTE(HM) doesn't work causes a unaligned acess error
    $if $defined(env::WIN32):
    Win32_LPCSTR path = (Win32_LPCSTR)&game::pContext.app_base_folder.zstr_tcopy()[0];
    Win32_LPCSTR operation = (Win32_LPCSTR)&string::tformat_zstr("%s", "explore")[0];
    // To open a folder = ShellExecute(handle, "open", <fully_qualified_path_to_folder>, NULL, NULL, SW_SHOWNORMAL);
    // To explore a folder = ShellExecute(handle, "explore", <fully_qualified_path_to_folder>, NULL, NULL, SW_SHOWNORMAL);
    /*if(*(Win32_INT*)win32::shellExecuteA(null, "open", "explorer.exe", (Win32_LPCSTR)game::pContext.app_base_folder.zstr_tcopy(), null, win32::Sw.SHOWNORMAL.ordinal) < 32) {
        log::warning(FILE, "Editor: Unable to open base folder to explore.");
    }*/
    win32::shellExecuteA(null, operation, path, null, null, win32::Sw.SHOWNORMAL.ordinal);
    $endif
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

//////////////// ************************************
/////////////// *************************************
/////////////// *************************************
////////////        <<<<< RGUI VERSION >>>>>
///////////// ***************************************
///////////// ***************************************
///////////// ***************************************

// UNFINISHED!!!!!!!!!!!!!!
module engine::tools @private @if($feature(RGUI_ENABLE));
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


import std::io, std::core::ascii, std::collections::list;
import engine::gui;
import engine::misc;
import engine::sys::cvar;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import thirdparty::microui::mu;  // micro ui
import engine::filesystem::fs::win32;
import std::os::win32;
import engine::logging::log;
import game::main;

const CInt CONSOLE_FONT_SIZE @local = 12;
const CInt CONSOLE_MAX_LINES @local = 1000;
const CInt CONSOLE_INPUT_MAX_LINE_LENGTH @local = 1024;

CVar con_debug @public = { "con_debug", CvFlag.BOOL|CvFlag.TOOL, "0", "enables console debugging mode"};

fn void register_cvars() @public @inline
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

constdef EditorKind : inline int @local
{
    MAIN_EDITOR = 1,
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
    bool is_fullscreen;
    bool is_docked;
    bool is_dockable;
}

struct Editor @public
{
    EditorFlags flags;

    RLColor background_color;
    RLRectangle main_window_rect;

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

<*
	Initialize all default setting the editor needs at start
	@param [&inout] editor : "the editor context/data structure"
*>
fn void initDefaults(Editor* editor) @inline @public
{
    editor.flags.is_minimizable = true;
    editor.flags.is_maximizable = true;
    editor.flags.is_closable = true;

    editor.background_color = {0x18, 0x18, 0x18, 0xFF};

    float scr_width = (float)rl::getScreenWidth();
    float scr_height = (float)rl::getScreenHeight();
    editor.main_window_rect = {
        .x = 0.25f * scr_width,
        .y = 0.05f * scr_height,
        .w = scr_width / 2.0f,
        .h = scr_height / 2.0f
    };

    editor.con_input_edit_mode = true; // the console input is in edit mode by default
    editor.listView_Active = 1; // the active item in the list view of the console history
    editor.listView_Focus = -1; // the focused item in the list view of the console history
}

<*
	De-Initialize all data of the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void deinit(Editor* editor) @inline @public
{
    editor.border_color = null;
    
    // free the editor console history
    if (editor.con_history.len() > 0) {
        editor.con_history.free();
    }
    // free the editor input buffer
    mem::clear(&editor.con_input_buffer, CONSOLE_INPUT_MAX_LINE_LENGTH);
    // clear the auto complete buffer
    editor.autoCompleteClear();
}

<*
	Open the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void open(Editor* editor) @inline @public
{
    if (isOpen(editor)) return;
    
    editor.flags.is_opened = true;
    editor.kind = EditorKind.MAIN_EDITOR;
    setVisible(editor); // also sets the editor to active
    game::pContext.mode = GameMode.EDITOR;
}

<*
	Close the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void close(Editor* editor) @inline @public
{
    if (!isOpen(editor)) return;
    
    editor.flags.is_opened = false;
    setInvisible(editor); // also sets the editor to inactive and unfocused
    game::pContext.mode = GameMode.NONE;
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isOpen(Editor* editor) @inline @public
{
	return (game::pContext.mode == GameMode.EDITOR && editor.flags.is_opened);
}

<*
	What kind of editor is being interacted with right now
	@param [&in] editor : "the editor context/data structure"
*>
fn EditorKind getOpenEditorKind(Editor* editor) => editor.kind;

<*
	Set the editor to being the window in focus
	aka the mouse is over the editor window
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "boolean to set focus true or false, true by default"
*>
fn bool setfocus(Editor* editor, bool choice = true) @inline
{
    editor.flags.is_focused = choice;
    (choice) ? rgui::setState(STATE_FOCUSED) : rgui::setState(STATE_NORMAL);
    return choice;
}

<*
	If the editor is the window in focus
	aka the mouse is over the editor window
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isFocused(Editor* editor) @inline @public => editor.flags.is_focused;

<*
	Set the editor active
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setActive(Editor* editor) @inline
{
    if (isActive(editor)) return;
    editor.flags.is_active = true;
    rgui::enable();
}

<*
	Ask if the editor is active
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isActive(Editor* editor) @inline => editor.flags.is_active;

<*
	Deactivate the editor
	@param [&inout] editor : "the editor context/data structure"
*>
fn void deactivate(Editor* editor) @inline
{
    if (isActive(editor) == false) {
        return;
    }
    editor.flags.is_active = false;
    rgui::disable();
}

<*
	Make editor visible
	@param [&inout] editor : "the editor context/data structure"
	@param activate : "if should activate the editor at the same time, default is yes"
*>
fn void setVisible(Editor* editor, bool activate = true) @inline
{
    if (isVisible(editor)) return;
    
    editor.flags.is_visible = true;
    if(activate) setActive(editor);
}

<*
	Make editor invisible
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setInvisible(Editor* editor) @inline
{
    if (isVisible(editor) == false)  return;
    
    editor.flags.is_visible = false;
    deactivate(editor);
    setfocus(editor, false);
}

<*
	Ask if editor is visible
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isVisible(Editor* editor) @inline => editor.flags.is_visible;

<*
	Set editor to resizable
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setResizable(Editor* editor) @inline
{
    if (isResizable(editor)) return;
    
    editor.flags.is_resizable = true;
    rgui::unlock();
}

<*
	Lock editor size, so it can't be resizable
	@param [&inout] editor : "the editor context/data structure"
*>
fn void lockSize(Editor* editor) @inline
{
    if (isResizable(editor) == false) return;
    
    editor.flags.is_resizable = false;
    rgui::lock();
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isResizable(Editor* editor) @inline => editor.flags.is_resizable;


<*
	Editor window can be minimized/hidden to OS taskbar 
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setMinimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY))
{
    if (isMinimizable(editor)) return;
    editor.flags.is_minimizable = true;
}

<*
	Disable Editor window minimization to OS taskbar 
	@param [&inout] editor : "the editor context/data structure"
*>
fn void setUnminimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY))
{
    if (isMinimizable(editor) == false) return;
    editor.flags.is_minimizable = false;
}

<*
	Ask if editor is minimizable
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isMinimizable(Editor* editor) @inline @if($defined(HAS_MINIMIZATION_ABILITY)) => editor.flags.is_minimizable;

<*
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "if should make the editor fullscreen, default is yes"
*>
fn void enableFullscreen(Editor* editor, bool choice = true) @inline
{
    if (isFullscreen(editor)) return;
    editor.flags.is_fullscreen = choice;
}

<*
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isFullscreen(Editor* editor) @inline => editor.flags.is_fullscreen;


<*
	Editor windows can be dockable
	@param [&inout] editor : "the editor context/data structure"
	@param choice : "the default is yes"
*>
fn void setDockable(Editor* editor, bool choice = true) @inline
{
    if (isDockable(editor)) return;
    editor.flags.is_dockable = choice;
}

<*
	Ask if editor is dockable
	@param [&in] editor : "the editor context/data structure"
*>
fn bool isDockable(Editor* editor) @inline => editor.flags.is_dockable;


<*
    WARNING(HM)
    If the 2D camera view is zoomed or rotated, this will break.
    in those cases this will require conversion from 
    world space coordinates to camera space.
	@param [&in] editor : "the editor context/data structure"
    @require game::pContext.view.camera.zoom == 1.0f
*>
fn bool isMouseOver(Editor* editor)
{
    if (isVisible(editor) == false) return false;

    // gets mouse position in pixel coordinates...
    Vec2f mouseWorldPos = rl::getMousePosition();

    Vec2f mouse_rect_size = game::getGameCursorSize() * 0.5f; // half the size of the game cursor
    //RLRectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_rect_size);
    RLRectangle mouseRect = {
        .pos  = mouseWorldPos, 
        .size = mouse_rect_size
    };

    if (rl::checkCollisionRecs(mouseRect, editor.main_window_rect)) return true;

    return false;
}

macro @noUpdate(#editor) @local => (!isVisible(#editor) || !isOpen(#editor) || !isActive(#editor));

<*
	@param [&inout] editor : "the editor context/data structure"
*>
fn void update(Editor* editor) @public
{
    if (@noUpdate(editor)) return;

    if (setfocus(editor, isMouseOver(editor)))
    {
        if(game::game_cursor_visible()) game::hide_game_cursor();
        if(!game::system_cursor_visible()) game::show_system_cursor();
    } else {
        if(game::system_cursor_visible()) game::hide_system_cursor();
        game::show_game_cursor();
    }

    if(editor.input_dialog_open_count > 1) {
        unreachable("input_dialog_open_count > 1, this should never happen.");
    }
}


macro @noDraw(#editor) @local => (!isVisible(#editor) || !isOpen(#editor));

<*
	@param [&inout] editor : "the editor context/data structure"
*>
fn void draw(Editor* editor) @public
{
    if (@noDraw(editor)) return;

    switch(editor.kind) 
    {
        case MAIN_EDITOR:      drawMainEditor(editor);
        case MATERIAL_EDITOR:  drawMaterialEditor(editor);
        case GUI_EDITOR:       drawGuiEditor(editor);
        case SCENE_EDITOR:     drawSceneEditor(editor);
        case ANIMATION_EDITOR: drawAnimationEditor(editor);
        case SOUND_EDITOR:     drawSoundEditor(editor);
        case SCRIPT_EDITOR:    drawScriptEditor(editor);
    }
}

<* 
    Draws the main editor window.
    @param [&inout] editor: "the editor to draw."
*>
fn void drawMainEditor(Editor* editor) @inline
{
    // TODO(HM): Implement the main editor drawing logic.
    //io::printfn("Drawing main editor...");

    // draw the background
    rl::drawRectangleRec(editor.main_window_rect, editor.background_color);

    // draw the main editor window
    bool _close = rgui::windowBox(editor.main_window_rect, "Editor");
    if(_close) close(editor);

    // draw the main editor tool bar
    drawEditorMainToolBar(editor);
    // draw the main editor console
    drawEditorConsole(editor);
	// draw color border
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
    RLRectangle area = editor.main_window_rect;

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
    @param [&inout] editor: "the editor to draw the console for."
*>
fn void drawEditorConsole(Editor* editor)
{
    RLRectangle area = editor.main_window_rect;

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
        if(input_text.len && isVisible(editor) && enter_pressed) {
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
    float console_size_y = 0.25f * editor.main_window_rect.height;
    int max_lines = ((int)console_size_y / CONSOLE_FONT_SIZE) - 1; // -1 to account for the input box line
    if (editor.con_history.len() >= max_lines) {
        editor.con_history.pop()!!;
    }
    editor.con_history.push(input_text);
}

macro void con_printfn(String fmt, ...) @public @builtin {
	DString str = dstring::temp_with_capacity(fmt.len + $vaarg.len * 8);
	str.appendf(fmt, ...$vaarg);
	game::pContext.editor.con_history.push(str.str_view().copy(mem));
}

<* 
    Parses the console input and executes the command.
    @param [&inout] editor: "the editor to parse the console input for."
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
            close(editor);
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
            game::pContext.mode = GameMode.EDITOR;
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
    switch(editor.kind) 
    {
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
    w = (int)game::pContext.screen.w;
    h = (int)game::pContext.screen.h;
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

//////////////////////////////////////////////////////////////
// #region EDITOR BUTTONS CALLBACKS
//////////////////////////////////////////////////////////////
fn void openFolderButtonCallback(void* data) @inline @local
{
    io::printfn("Open folder button pressed.");
    // NOTE(HM) doesn't work causes a unaligned acess error
    $if $defined(env::WIN32):
    Win32_LPCSTR path = (Win32_LPCSTR)&game::pContext.app_base_folder.zstr_tcopy()[0];
    Win32_LPCSTR operation = (Win32_LPCSTR)&string::tformat_zstr("%s", "explore")[0];
    // To open a folder = ShellExecute(handle, "open", <fully_qualified_path_to_folder>, NULL, NULL, SW_SHOWNORMAL);
    // To explore a folder = ShellExecute(handle, "explore", <fully_qualified_path_to_folder>, NULL, NULL, SW_SHOWNORMAL);
    /*if(*(Win32_INT*)win32::shellExecuteA(null, "open", "explorer.exe", (Win32_LPCSTR)game::pContext.app_base_folder.zstr_tcopy(), null, win32::Sw.SHOWNORMAL.ordinal) < 32) {
        log::warning(FILE, "Editor: Unable to open base folder to explore.");
    }*/
    win32::shellExecuteA(null, operation, path, null, null, win32::Sw.SHOWNORMAL.ordinal);
    $endif
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
