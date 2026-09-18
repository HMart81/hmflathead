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
module thirdparty::microui::mu @if($feature(MICROUI_ENABLE));

import std::io;
import std::core::string::conv;
import std::collections::list;
import engine::logging::log;
import engine::tools;
import game::main;
import thirdparty::raylib5::rl;

const VERSION = "2.02";

const COMMANDLIST_SIZE     =  (256 * 1024);
const ROOTLIST_SIZE        = 32;
const CONTAINERSTACK_SIZE  = 32;
const CLIPSTACK_SIZE       = 32;
const IDSTACK_SIZE         = 32;
const LAYOUTSTACK_SIZE     = 16;
const CONTAINERPOOL_SIZE   = 48;
const TREENODEPOOL_SIZE    = 48;
const MAX_WIDTHS           = 16;
const REAL_FMT             = "%.3g";
const SLIDER_FMT           = "%.2f";
const MAX_FMT              = 127;

const MU_Rect UNCLIPPED_RECT = {0, 0, 0x1000000, 0x1000000 };

// The default font size for MicroUI is set to 9 pixels.
const MICROUI_FONT_SIZE 	  = 10; 
const MICROUI_FONT_SPACING    = 1; // This is the spacing between characters in the font, used for text rendering.
const MAX_INPUT_TEXT          = 32; // Maximum length of input text in MicroUI text box's.

// type of commands/interactions done on the gui
const COMMAND_JUMP = 1;
const COMMAND_CLIP = 2;
const COMMAND_RECT = 3;
const COMMAND_TEXT = 4;
const COMMAND_ICON = 5;
const COMMAND_MAX  = 6;
//////////////////////////

alias Colorid = int;
const Colorid MU_COLOR_TEXT        = 0;
const Colorid MU_COLOR_BORDER      = 1;
const Colorid MU_COLOR_WINDOWBG    = 2;
const Colorid MU_COLOR_TITLEBG     = 3;
const Colorid MU_COLOR_TITLETEXT   = 4;
const Colorid MU_COLOR_PANELBG     = 5;
const Colorid MU_COLOR_BUTTON      = 6;
const Colorid MU_COLOR_BUTTONHOVER = 7;
const Colorid MU_COLOR_BUTTONFOCUS = 8;
const Colorid MU_COLOR_BASE        = 9;
const Colorid MU_COLOR_BASEHOVER   = 10;
const Colorid MU_COLOR_BASEFOCUS   = 11;
const Colorid MU_COLOR_SCROLLBASE  = 12;
const Colorid MU_COLOR_SCROLLTHUMB = 13;
const Colorid MU_COLOR_MAX         = 14;

struct MU_Stack <Type, MAX_SIZE> @local
{
	int idx;
	Type[MAX_SIZE] items;
}

alias MU_Stack_Chars             @local = MU_Stack{char, COMMANDLIST_SIZE};
alias MU_Stack_ContainerPtrsRoot @local = MU_Stack{MU_Container*, ROOTLIST_SIZE};
alias MU_Stack_ContainerPtrs     @local = MU_Stack{MU_Container*, CONTAINERSTACK_SIZE};
alias MU_Stack_Rect              @local = MU_Stack{MU_Rect, CLIPSTACK_SIZE};
alias MU_Stack_ID                @local = MU_Stack{MU_Id, IDSTACK_SIZE};
alias MU_Stack_Layout            @local = MU_Stack{MU_Layout, LAYOUTSTACK_SIZE};

macro max(a, b) @local => ((a) > (b) ? (a) : (b));
/*
macro min(a, b) @private => ((a) < (b) ? (a) : (b));
macro clamp(x, a, b) @private => min(b, max(a, x));
*/

constdef MU_Clip : inline int 
{
	PART = 1,
	ALL  = 2,
}

constdef MU_Icon : inline int
{
	CLOSE = 1,
	CHECK,
	COLLAPSED,
	EXPANDED,
	MAX
}

constdef MU_Res : inline int
{
	ACTIVE = (1 << 0),
	SUBMIT = (1 << 1),
	CHANGE = (1 << 2)
}

constdef MU_Opt : inline int
{
	ALIGNCENTER  = (1 << 0),
	ALIGNRIGHT   = (1 << 1),
	NOINTERACT   = (1 << 2),
	NOFRAME      = (1 << 3),
	NORESIZE     = (1 << 4),
	NOSCROLL     = (1 << 5),
	NOCLOSE      = (1 << 6),
	NOTITLE      = (1 << 7),
	HOLDFOCUS    = (1 << 8),
	AUTOSIZE     = (1 << 9),
	POPUP        = (1 << 10),
	CLOSED       = (1 << 11),
	EXPANDED     = (1 << 12)
}

constdef MU_Mouse : inline int
{
  LEFT    = (1 << 0),
  RIGHT   = (1 << 1),
  MIDDLE  = (1 << 2),
  SIDE    = (1 << 3),   // Mouse button side (advanced mouse device)
  EXTRA   = (1 << 4),   // Mouse button extra (advanced mouse device)
  FORWARD = (1 << 5),   // Mouse button fordward (advanced mouse device)
  BACK    = (1 << 6),   // Mouse button back (advanced mouse device)
}

constdef MU_Key : inline int
{
  SHIFT     = (1 << 0),
  CTRL      = (1 << 1),
  ALT       = (1 << 2),
  BACKSPACE = (1 << 3),
  RETURN    = (1 << 4),
  DELETE    = (1 << 5),
  END       = (1 << 6),
  HOME      = (1 << 7),
  LEFT      = (1 << 8),
  RIGHT     = (1 << 9),
  KEY_A     = (1 << 10),
  KEY_C     = (1 << 11),
  KEY_V     = (1 << 12),
  KEY_X     = (1 << 13),
}


alias MU_Id    = uint;
alias MU_Real  = float;
//alias MU_Font  = void*;
alias MU_Font  = RLFont*;
alias MU_Color = RLColor;
alias MU_Vec2  = int[<2>];

RLTexture2D font_atlas @local;

struct MU_Rect
{ 
	int x, y, w, h;
}

fn bool MU_Rect.equal(&self, MU_Rect other) @operator(==)
{
  return ( 
    self.x == other.x &&
    self.y == other.y &&
    self.w == other.w &&
    self.h == other.h
  );
}

fn bool MU_Rect.less(&self, MU_Rect other) @operator(<)
{
  return (
      self.x < other.x &&
      self.y < other.y &&
      self.w < other.w &&
      self.h < other.h
    );
}

fn MU_Rect RLRectangle.toMURect(self) @inline
{
	return { (int)self.x, (int)self.y, (int)self.width, (int)self.height };
}

fn RLRectangle MU_Rect.toRLRect(self) @inline
{
  return { (float)self.x, (float)self.y, (float)self.w, (float)self.h };
}

struct MU_PoolItem
{ 
	MU_Id id; 
	int last_update;
}

fn bool MU_PoolItem.equal(&self, MU_PoolItem other) @operator(==)
{
  return ( 
    self.id          == other.id &&
    self.last_update == other.last_update
  );
}

fn bool MU_PoolItem.nequal(&self, MU_PoolItem other) @operator(<)
{
  return ( 
    self.id          < other.id &&
    self.last_update < other.last_update
  );
}

struct MU_BaseCommand
{ 
	int type, size; 
}

fn bool MU_BaseCommand.equal(&self, MU_BaseCommand other) @operator(==)
{
  return ( 
    self.type == other.type &&
    self.size == other.size
  );
}

fn bool MU_BaseCommand.lessthan(&self, MU_BaseCommand other) @operator(<)
{
  return ( 
    self.type < other.type &&
    self.size < other.size
  );
}

struct MU_JumpCommand { MU_BaseCommand base; void *dst; }
struct MU_ClipCommand { MU_BaseCommand base; MU_Rect rect; }
struct MU_RectCommand { MU_BaseCommand base; MU_Rect rect; MU_Color color; }
struct MU_TextCommand { MU_BaseCommand base; MU_Font font; MU_Vec2 pos; MU_Color color; CChar[1] str; }
struct MU_IconCommand { MU_BaseCommand base; MU_Rect rect; int id; MU_Color color; }

struct MU_Command
{
	// NOTE: This union is used to store different command types in a single array.
	// The type field indicates which command type is currently stored.
	// The size field indicates the size of the command in bytes.
	// The union allows us to access the specific command data based on the type.
	union 
	{
		int type;
		MU_BaseCommand base;
		MU_JumpCommand jump;
		MU_ClipCommand clip;
		MU_RectCommand rect;
		MU_TextCommand text;
		MU_IconCommand icon;
	}
}

struct MU_Layout
{
  MU_Rect body;
  MU_Rect next;
  MU_Vec2 position;
  MU_Vec2 size;
  MU_Vec2 max;
  int[MAX_WIDTHS] widths;
  int items;
  int item_index;
  int next_row;
  int next_type;
  int indent;
}

/*
Windows are the primary container type in MicroUI. 
They appear as independent, movable, and resizable 
rectangles that can contain UI controls and other 
containers.
*/
struct MU_Container
{
  MU_Command* head; 
  MU_Command* tail;
  MU_Rect rect;         // The full rectangle of the container, including title bar and borders
  MU_Rect body;         // The inner content area where controls are placed
  MU_Vec2 content_size; // The size of the content within the container
  MU_Vec2 scroll;       // The current scroll position
  int zindex;           // Determines the stacking order of containers
  int open;             // Whether the container is currently open
}

struct MU_Style
{
  MU_Font font;
  MU_Vec2 size;
  int padding;
  int spacing;
  int indent;
  int title_height;
  int scrollbar_size;
  int thumb_size;
  MU_Color[MU_COLOR_MAX] colors;
}

alias TextWidthCallback  = fn int (MU_Font font, ZString str, int len);
alias TextHeightCallback = fn int (MU_Font font);
alias DrawFrameCallback  = fn void (MU_Context* ctx, MU_Rect rect, Colorid color);

struct MU_Context 
{
  /* callbacks */
	TextWidthCallback text_width;  // Required
	TextHeightCallback text_height; // Required
	DrawFrameCallback draw_frame; // Optional (has default)
  /* core state */
	MU_Style _style;
	MU_Style* style;
	MU_Id hover; // ID of control being hovered
	MU_Id focus; // ID of control with input focus
	MU_Id last_id; // Most recently generated ID   
	MU_Rect last_rect;
	int last_zindex;
	int updated_focus;
	int frame;
	MU_Container* hover_root;
	MU_Container* next_hover_root;
	MU_Container* scroll_target;
	char[MAX_FMT] number_edit_buf;
	MU_Id number_edit;
	/* stacks */
	MU_Stack_Chars command_list;
	MU_Stack_ContainerPtrsRoot root_list;
	MU_Stack_ContainerPtrs container_stack;
	MU_Stack_Rect clip_stack;
	MU_Stack_ID id_stack;
	MU_Stack_Layout layout_stack;
	/* retained state pools */
	MU_PoolItem[CONTAINERPOOL_SIZE] container_pool;
	MU_Container[CONTAINERPOOL_SIZE] containers;
	MU_PoolItem[TREENODEPOOL_SIZE] treenode_pool;
	/* input state */
	MU_Vec2 mouse_pos;
	MU_Vec2 last_mouse_pos;
	MU_Vec2 mouse_delta;
	MU_Vec2 scroll_delta;
	int mouse_down;
	int mouse_pressed;
	int key_down;
	int key_pressed;
	char[MAX_INPUT_TEXT] input_text;
}

extern fn MU_Vec2 vec2(int x, int y)  @cname("mu_vec2");
extern fn MU_Rect rect(int x, int y, int w, int h) @cname("mu_rect");
extern fn MU_Color color(int r, int g, int b, int a) @cname("mu_color");

// init microui context
extern fn void MU_Context.init(&self) @cname("mu_init");

<*
	@param [&inout] ctx : "pointer to microui context" 
	@param [in] font : "optional font to use"
	@param atlas : "the texture atlas for the icons"
	@require rl::isTextureValid(atlas)
*>
fn void init(MU_Context* ctx, MU_Font font = null, RLTexture2D atlas = {})
{
	ctx.init();
	if(font) {
		ctx.style.font = font;
	}
	font_atlas = atlas;
}

// render a microui frame/window
extern fn void MU_Context.begin(&self) @cname("mu_begin");
extern fn void MU_Context.end(&self) @cname("mu_end");
//

extern fn void MU_Context.set_focus(&self, MU_Id id) @cname("mu_set_focus");
extern fn MU_Id MU_Context.get_id(&self, void* data, int size) @cname("mu_get_id");
extern fn void MU_Context.push_id(&self, void* data, int size) @cname("mu_push_id");
extern fn void MU_Context.pop_id(&self) @cname("mu_pop_id");
extern fn MU_Container* MU_Context.get_current_container(&self) @cname("mu_get_current_container");
extern fn MU_Container* MU_Context.get_container(&self, ZString name) @cname("mu_get_container");
extern fn void MU_Context.bring_to_front(&self, MU_Container *cnt) @cname("mu_bring_to_front");

extern fn int MU_Context.pool_init(&self, MU_PoolItem *items, int len, MU_Id id) @cname("mu_pool_init");
extern fn int MU_Context.pool_get(&self, MU_PoolItem *items, int len, MU_Id id) @cname("mu_pool_get");
extern fn void MU_Context.pool_update(&self, MU_PoolItem *items, int idx) @cname("mu_pool_update");

// INPUT functions ///////////////////////////////////////////////////////////////////////////
extern fn void MU_Context.input_mousemove(&self, int x, int y) @cname("mu_input_mousemove");
extern fn void MU_Context.input_mousedown(&self, int x, int y, int btn) @cname("mu_input_mousedown");
extern fn void MU_Context.input_mouseup(&self, int x, int y, int btn) @cname("mu_input_mouseup");
extern fn void MU_Context.input_scroll(&self, int x, int y) @cname("mu_input_scroll");
extern fn void MU_Context.input_keydown(&self, int key) @cname("mu_input_keydown");
extern fn void MU_Context.input_keyup(&self, int key) @cname("mu_input_keyup");
extern fn void MU_Context.input_textfn(&self, ZString text) @cname("mu_input_text");
//


extern fn MU_Command* MU_Context.push_command(&self, int type, int size) @cname("mu_push_command");
extern fn int MU_Context.next_command(&self, MU_Command** cmd) @cname("mu_next_command");

// CLIP functions ///////////////////////////////////////////////////////////////
// Generate a clip command
extern fn void MU_Context.set_clip(&self, MU_Rect rect) @cname("mu_set_clip");
// Push a new clip rectangle onto the stack
extern fn void MU_Context.push_clip_rect(&self, MU_Rect rect) @cname("mu_push_clip_rect");
// Pop a clip rectangle from the stack
extern fn void MU_Context.pop_clip_rect(&self) @cname("mu_pop_clip_rect");
// Get the current clip rectangle
extern fn MU_Rect MU_Context.get_clip_rect(&self) @cname("mu_get_clip_rect");
// Check if a rectangle is clipped
extern fn int MU_Context.check_clip(&self, MU_Rect r) @cname("mu_check_clip");
/*
  Restricts drawing operations to specific regions of the screen, 
  preventing elements from drawing outside their containers and 
  improving performance by skipping off-screen elements.
*/
///////////

// DRAWING functions ///////////////////////////////////////////////////////////////////////////
extern fn void MU_Context.draw_rect(&self, MU_Rect rect, MU_Color color) @cname("mu_draw_rect");
extern fn void MU_Context.draw_box(&self, MU_Rect rect, MU_Color color) @cname("mu_draw_box");
extern fn void MU_Context.draw_text(&self, MU_Font font, ZString str, int len, MU_Vec2 pos, MU_Color color) @cname("mu_draw_text");
extern fn void MU_Context.draw_icon(&self, int id, MU_Rect rect, MU_Color color) @cname("mu_draw_icon");
extern fn void MU_Context.draw_control_frame(&self, MU_Id id, MU_Rect rect, int colorid, int opt) @cname("mu_draw_control_frame");
extern fn void MU_Context.draw_control_text(&self, ZString str, MU_Rect rect, int colorid, int opt) @cname("mu_draw_control_text");
macro draw_rect_bounds(MU_Rect rect) => rl::drawRectangleLinesEx(rect.toRLRect(), lineThick: 2.0f, color: rl::YELLOW);
//

// LAYOUT functions ///////////////////////////////////////////////////////////////////////////////////
extern fn void MU_Context.layout_row(&self, int items, int* widths, int height) @cname("mu_layout_row");
extern fn void MU_Context.layout_width(&self, int width) @cname("mu_layout_width");
extern fn void MU_Context.layout_height(&self, int height) @cname("mu_layout_height");
extern fn void MU_Context.layout_begin_column(&self) @cname("mu_layout_begin_column");
extern fn void MU_Context.layout_end_column(&self) @cname("mu_layout_end_column");
extern fn void MU_Context.layout_set_next(&self, MU_Rect r, int relative) @cname("mu_layout_set_next");
extern fn MU_Rect MU_Context.layout_next(&self) @cname("mu_layout_next");

//
extern fn int MU_Context.mouse_over(&self, MU_Rect rect) @cname("mu_mouse_over");
extern fn void MU_Context.update_control(&self, MU_Id id, MU_Rect rect, int opt) @cname("mu_update_control");

macro MU_Context.button(&self, label, icon = 0, opt = MU_Opt.ALIGNCENTER)   => self.button_ex(label.zstr_tcopy(), icon, opt);
macro MU_Context.textbox(&self, buf, bufsz)       => self.textbox_ex(buf, bufsz, 0);
macro MU_Context.slider(&self, value, lo, hi)     => self.slider_ex(value, lo, hi, 0, SLIDER_FMT, MU_Opt.ALIGNCENTER);
macro MU_Context.number(&self, value, step)       => self.number_ex(value, step, SLIDER_FMT, MU_Opt.ALIGNCENTER);
macro MU_Context.header(&self, label)             => self.header_ex(label.zstr_tcopy(), 0);
macro MU_Context.begin_treenode(&self, label)     => self.begin_treenode_ex(label.zstr_tcopy(), 0);
macro MU_Context.begin_window(&self, title, rect, MU_Opt opt = (MU_Opt)0) => self.begin_window_ex(title.zstr_tcopy(), rect, (int)opt);
macro MU_Context.begin_panel(&self, name, opt = 0) => self.begin_panel_ex(name.zstr_tcopy(), opt);

extern fn void MU_Context.text(&self, ZString text) @cname("mu_text");
extern fn void MU_Context.label(&self, ZString text) @cname("mu_label");
extern fn int MU_Context.button_ex(&self, ZString label, int icon, int opt) @cname("mu_button_ex");
extern fn int MU_Context.checkbox(&self, ZString label, int* state) @cname("mu_checkbox");
extern fn int MU_Context.textbox_raw(&self, ZString buf, int bufsz, MU_Id id, MU_Rect r, int opt) @cname("mu_textbox_raw");
extern fn int MU_Context.textbox_ex(&self, CChar* buf, int bufsz, int opt) @cname("mu_textbox_ex");
extern fn int MU_Context.slider_ex(&self, MU_Real *value, MU_Real low, MU_Real high, MU_Real step, ZString fmt, int opt) @cname("mu_slider_ex");
extern fn int MU_Context.number_ex(&self, MU_Real *value, MU_Real step, ZString fmt, int opt) @cname("mu_number_ex");
extern fn int MU_Context.header_ex(&self, ZString label, int opt) @cname("mu_header_ex");
extern fn int MU_Context.begin_treenode_ex(&self, ZString label, int opt) @cname("mu_begin_treenode_ex");
extern fn void MU_Context.end_treenode(&self) @cname("mu_end_treenode");
extern fn int MU_Context.begin_window_ex(&self, ZString title, MU_Rect rect, int opt) @cname("mu_begin_window_ex");
extern fn void MU_Context.end_window(&self) @cname("mu_end_window");
extern fn void MU_Context.open_popup(&self, ZString name) @cname("mu_open_popup");
extern fn int MU_Context.begin_popup(&self, ZString name) @cname("mu_begin_popup");
extern fn void MU_Context.end_popup(&self) @cname("mu_end_popup");
extern fn void MU_Context.begin_panel_ex(&self, ZString name, int opt) @cname("mu_begin_panel_ex");
extern fn void MU_Context.end_panel(&self) @cname("mu_end_panel");

struct MU_Open_ID @local
{
	String name;
	MU_Id id;
}
alias OpenMicroUIFrames = List{MU_Open_ID*};
OpenMicroUIFrames open_frames @public;

fn void register_open_window(String _name, MU_Id _id) @local
{
	foreach(it : open_frames)
	{
		if (it.id == _id) {
			return; // already registered
		}
	}

	open_frames.push( mem::new(MU_Open_ID, {
		.name = _name.tcopy(),
		.id = _id
	}));
}

fn void unregister_open_window(String _name) @local
{
	MU_Open_ID* item;
	foreach(i, it : open_frames)
	{
		if (it.name == _name)
		{
			item = open_frames[i];
			break; // found the frame to unregister
		}
	}
	if(item) open_frames.remove_item(item);
}

<*
    @require($Typeof($title) == String)
    @require($Typeof(#rect) == MU_Rect)
    @require($Typeof($opt) == MU_Opt)
*>
macro bool MU_Context.@make_window(&self, $title, #rect, bool register = true, $opt = (MU_Opt)0; @body) 
{
    if (self.begin_window($title, #rect, $opt) == MU_Res.ACTIVE)
    {
        if(register) register_open_window($title, self.last_id); // Register the window as open
        defer self.end_window();
        @body();
    }
    else
    {
        if(register) unregister_open_window($title.tcopy()); // Unregister the window as it is closed
        return false; // The window should close.
    }
    return true; // The window is open.
}

<*
    @require($Typeof($title) == String)
    @require($Typeof(#rect) == MU_Rect)
    @require($Typeof($opt) == MU_Opt)
*>
macro bool @doWindow(
  MU_Context* ctx, 
  $title, 
  #rect, 
  bool register = true, 
  $opt = (MU_Opt)0; @body) 
{
    if (ctx.begin_window($title, #rect, $opt) == MU_Res.ACTIVE)
    {
        if(register) register_open_window($title, ctx.last_id); // Register the window as open
        defer ctx.end_window();
        @body();
    }
    else
    {
        if(register) unregister_open_window($title.tcopy()); // Unregister the window as it is closed
        return false; // The window should close.
    }
    return true; // The window is open.
}

macro void @render(MU_Context* ctx; @body)
{
	// This macro is used to define a render function that processes the given body
	// with the current context. It allows for easy rendering of UI elements.
	ctx.begin();
	defer ctx.end();
	@body();
}

macro void MU_Context.@make_rows(&self, int n_rows, int* widths, int height = 0; @body)
{
	self.layout_row(n_rows, widths, height);
  @body();
}

macro bool MU_Context.@make_popup(&self, name; @body)
{
	if (self.begin_popup(name.zstr_tcopy())) {
		defer self.end_popup();
		@body();
	} else {
    return false; // should close.
  }
  return true; // still open
}

macro bool MU_Context.@make_treenode(&self, name; @body)
{
	if (self.begin_treenode(name)) {
		defer self.end_treenode();
		@body();
	} else {
    return false; // should close.
  }
  return true; // still open
}

macro void MU_Context.@layout_make_column(&self; @body)
{
	self.layout_begin_column();
	defer self.layout_end_column();
	@body();
}

macro void MU_Context.@make_panel(&self, $name, $opt = 0; @body)
{
	self.begin_panel($name, $opt);
	defer self.end_panel();
	@body();
}


/////////////////////////////////////////////////////////////////////////////////////
/////////////////////// Internal windows ////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

//char[64000] logbuf @local;
CChar[128] input_buf;
String logbuf @local = "";
int logbuf_updated @local = 0;

fn void write_log(String text) @local 
{
  // if we already have some text in the log buffer, append a newline before adding new text
  if(logbuf.len > 0) 
  {
    logbuf = logbuf.tconcat("\n");
  }
  logbuf = logbuf.tconcat(text);
  logbuf_updated = 1;
}

fn void log_window(MU_Context *ctx) 
{
  bool open = ctx.@make_window("Log Window", rect(350, 40, 300, 200)) 
  {
    /* output text panel */
    ctx.layout_row(1, (int[]) { -1 }, -25);
    MU_Container *panel;
    ctx.@make_panel("Log Output")
    {
      panel = ctx.get_current_container();
      ctx.layout_row(1, (int[]) { -1 }, -1);
      ctx.text(logbuf.zstr_tcopy());
    }; // end of log output panel

    if (logbuf_updated)
    {
      panel.scroll.y = panel.content_size.y;
      logbuf_updated = 0;
    }

    /* input textbox + submit button */
    int submitted;
    ctx.layout_row(2, (int[]) { -70, -1 }, 0);
    if (ctx.textbox(&input_buf[0], (int)input_buf.len) & MU_Res.SUBMIT)
    {
      ctx.set_focus(ctx.last_id);
      submitted = 0; // reset submitted flag
    }

    submitted = ctx.button("Submit");
    if (submitted) {
      write_log((String)input_buf[0..]);
      input_buf[0] = '\0';
    }
  }; // end of log window

  if (!open) 
  {
    // If the window was closed, reset the log buffer.
    logbuf = "";
    logbuf_updated = 0;
  }
}

// Test window function to demonstrate the usage of MicroUI

int[*] bg @local = { 90, 95, 100 };

fn void test_window(MU_Context* ctx)
{
  /* do window */
  bool open = ctx.@make_window("Demo Window", mu::rect(40, 40, 300, 450))
  {
    MU_Container *win = ctx.get_current_container();
    win.rect.w = max(win.rect.w, 240);
    win.rect.h = max(win.rect.h, 300);

    /* window info */
    if (ctx.header("Window Info")) 
    {
      win = ctx.get_current_container();
      ZString buf;
      ctx.layout_row(2, (int[]) { 54, -1 }, 0);
      ctx.label("Position:");
      buf = string::tformat_zstr("%d, %d", win.rect.x, win.rect.y); 
      ctx.label(buf);

      ctx.label("Size:");
      buf = string::tformat_zstr("%d, %d", win.rect.w, win.rect.h); 
      ctx.label(buf);
    }

    /* labels + buttons */
    if (ctx.header_ex("Test Buttons", MU_Opt.EXPANDED)) 
	  {
      ctx.layout_row(3, &&(int[*]) { 86, -110, -1 }, 0);
      ctx.label("Test buttons 1:");
      if (ctx.button("Button 1")) { io::printfn("Pressed button 1"); }
      if (ctx.button("Button 2")) { io::printfn("Pressed button 2"); }
      ctx.label("Test buttons 2:");
      if (ctx.button("Button 3")) { io::printfn("Pressed button 3"); }
      if (ctx.button("Popup")) { ctx.open_popup("Test Popup"); }
      ctx.@make_popup("Test Popup") 
      {
        ctx.button("Hello");
        ctx.button("World");
      };
    }

    /* tree */
    if (ctx.header_ex("Tree and Text", MU_Opt.EXPANDED)) 
	  {
      ctx.layout_row(2, &&(int[*]) { 140, -1 }, 0);
      ctx.@layout_make_column() 
	    {
		    ctx.@make_treenode("Test 1")
		    {
			    ctx.@make_treenode("Test 1a")
			    {
            ctx.label("Hello");
            ctx.label("world");
          };
          ctx.@make_treenode("Test 1b")
          {
            if (ctx.button("Button 1")) { io::printfn("Pressed button 1"); }
            if (ctx.button("Button 2")) { io::printfn("Pressed button 2"); }
          };
		    };
        ctx.@make_treenode("Test 2") 
        {
          ctx.layout_row(2, &&(int[*]) { 54, 54 }, 0);
          if (ctx.button("Button 3")) { io::printfn("Pressed button 3"); }
          if (ctx.button("Button 4")) { io::printfn("Pressed button 4"); }
          if (ctx.button("Button 5")) { io::printfn("Pressed button 5"); }
          if (ctx.button("Button 6")) { io::printfn("Pressed button 6"); }
        };
        ctx.@make_treenode("Test 3") 
        {
          int[3] checks = { 1, 0, 1 };
          ctx.checkbox("Checkbox 1", &checks[0]);
          ctx.checkbox("Checkbox 2", &checks[1]);
          ctx.checkbox("Checkbox 3", &checks[2]);
        };
	    }; // end of column

      ctx.@layout_make_column() 
      {
        ctx.layout_row(1, &&(int[*]) { -1 }, 0);
        ctx.text("Lorem ipsum dolor sit amet, consectetur adipiscing "
          "elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus "
          "ipsum, eu varius magna felis a nulla.");
      };
    } // end of tree

    /* background color sliders */
    if (ctx.header_ex("Background RLColor", MU_Opt.EXPANDED)) 
	{
		ctx.layout_row(2, (int[]){ -78, -1 }, 74);
		/* sliders */
		ctx.@layout_make_column() 
		{
			ctx.layout_row(2, &&(int[*]) { 46, -1 }, 0);
			ctx.label("Red:");   ctx.slider((MU_Real*)&bg[0], 0, 255);
			ctx.label("Green:"); ctx.slider((MU_Real*)&bg[1], 0, 255);
			ctx.label("Blue:");  ctx.slider((MU_Real*)&bg[2], 0, 255);
		};
		/* color preview */
		MU_Rect r = ctx.layout_next();
		ctx.draw_rect(r, mu::color(bg[0], bg[1], bg[2], 255));
		String buf = string::tformat("#%02X%02X%02X", bg[0], bg[1], bg[2]);
		ctx.draw_control_text(buf.zstr_tcopy(), r, MU_COLOR_TEXT, MU_Opt.ALIGNCENTER);
    }
  }; // end of window

  if (!open) 
  {
    // If the window was closed, reset the background color.
    bg = { 90, 95, 100 };
  }
}

fn void debug_window(MU_Context* ctx) @inline
{
	// This function is called to render the test window in the MicroUI context.
	// It is typically registered as a frame function to be processed in the main loop.
	bool open = ctx.@make_window("debug_window", mu::rect(50, 50, 400, 300))
	{
		// Here you can add UI elements and logic for the test window
		ctx.text("Put here any debug stuff you need.");
    ctx.@make_rows(1, (int[]) { 100 }, -1) 
    {
      ctx.checkbox("Pause RLMusic:", &game::pContext.pause_all_music);
    };
	};

  if (!open) 
  {
    // If the window was closed, you can perform any necessary cleanup or state reset.
  }
}

fn void statistics_window(MU_Context* ctx) @inline
{
	bool open = ctx.@make_window("stats_window", mu::rect(100, 50, 400, 300))
	{
    ctx.@make_rows(1, (int[]) { -1 }, -25)
    {
      MU_Container *panel;
      ctx.@make_panel("Frame Statistics")
      {
        panel = ctx.get_current_container();
        ctx.@make_rows(1, (int[]) { -1 }, -1)
        {
          int fps = rl::getFPS();
          float frame_time = rl::getFrameTime();
          String units = "ms";
          if (frame_time >= 1.0f) units = "sec";
          ZString frame_times = string::tformat_zstr("FPS: %s (ft: %.3f %s)", fps, frame_time, units);
          ctx.text(frame_times);
        };
      };
    };
    //
    //ctx.text("ms.");
	};

  if (!open) 
  {
    // If the window was closed, you can perform any necessary cleanup or state reset.
  }
}

// in this function we run all microui "frames"
fn void run_microui_frames(MU_Context* ctx) @inline
{
  if(game::pContext.show_microui_test_frames) 
  {
    ctx.run(&test_window);
    ctx.run(&log_window);
  	ctx.run(&debug_window);
  }

  if(game::pContext.show_statistics) 
  {
    ctx.run(&statistics_window);
  }

  if(game::developer.getBool() && game::editor.getBool()) {
	    tools::draw(&game::pContext.editor);
	}
}

/////////////////////////////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------------

alias MU_Frame = fn void (MU_Context* ctx);

fn void MU_Context.run(&self, MU_Frame frame) {
  if(frame) /*run*/ frame(self);
}

<*
  Processes all frames with the current context.
  @param [in] ctx : "The current MicroUI context."
  @param delta_time : "The time elapsed since the last frame, which can be used for animations"
  @require ctx != null
 *>
fn void process_frames(MU_Context* ctx, float delta_time) 
{
  @render(ctx)
  {
    // WARNING(HM) frames needs to be rendered within a @render() body, if not will cause a memory pool crash 
    run_microui_frames(ctx);
  };
}

/////////////////////////////////////
//////// microui callbacks
/////////////////////////////////////

fn int callback_text_width(MU_Font font, ZString text, int len)
{
    // mesure is in pixels
	if(font) {
		return (int)rl::measureTextEx(*font, text, MICROUI_FONT_SIZE, MICROUI_FONT_SPACING).x;
	} else {
    	return rl::measureText(rl::textFormat("%.*s", len, text), MICROUI_FONT_SIZE);
    	//int size = (int)rl::measureTextEx(rl::getFontDefault(), text, MICROUI_FONT_SIZE, MICROUI_FONT_SPACING).x;
    	//return size;
	}
}

fn int callback_text_height(MU_Font font)
{
	if(font) {
		return (int)rl::measureTextEx(*font, "#", MICROUI_FONT_SIZE, MICROUI_FONT_SPACING).y;
		//return (font.baseSize > MICROUI_FONT_SIZE) ? MICROUI_FONT_SIZE : font.baseSize;
	} else {
		return MICROUI_FONT_SIZE;
	}
}
///////////
///////////

fn void callback_draw_text(MU_Font font, ZString str, MU_Vec2 pos, MU_Color color)
{
		if(font) {
			rl::drawTextEx(*font, str, pos, MICROUI_FONT_SIZE, MICROUI_FONT_SPACING, color);
		} else {
			// Assuming cmd->text.font is a valid font pointer
			rl::drawText(str, pos.x, pos.y, MICROUI_FONT_SIZE, color);
		}
}

fn void callback_draw_rect(MU_Rect rect, MU_Color color) @inline
{
  // Draw a rectangle with the specified color
  rl::drawRectangle(rect.x, rect.y, rect.w, rect.h, color);
}

// called by MU_COMMAND_ICON
fn void callback_draw_icon(int id, MU_Rect rect, MU_Color color) @inline
{
	r_draw_icon(id, rect, color);
}

fn void callback_set_clip_rect(MU_Rect rect) @inline
{
	if(rect == UNCLIPPED_RECT)
	{
	// End any previous scissor mode to reset the clipping state
		rl::endScissorMode();
	}
	else
	{
	// Set the clipping rectangle for drawing operations
		rl::beginScissorMode(rect.x, rect.y, rect.w, rect.h);
	}
}

// NOTE(HM) this is the "buffer" for the input text
// WARNING(HM) Right now, for some reason, if you write a certain string size the ctx.input_textfn will crash.
// TODO(HM) Find why it crash's... 
String input_text @local;

<*
  Forwards text input from raylib to the MicroUI context.
  @param [&inout] ctx : "The current MicroUI context."
*>
fn void MU_Context.forward_text_input(MU_Context* ctx) //@local 
{
$if $defined(ENABLE_OLD_STRING):
    // Create a buffer to hold UTF8 text input
    // UTF8 is a "variable width encoding" so some characters may be 1 byte whereas other may be up to 4
    char[512] text_input;
    // This will track the index into the text_input buffer where characters bytes will be copied to
    uint text_input_offset;

    // This loops reads the characters currently pressed until we've read all the pressed characters or we hit the
    // limit of our text input buffer. We'd only hit the limit if someone was holding a LOT of characters
    for(int i = 0; text_input_offset < text_input.len; i++) 
    {
        // Get the pressed UTF8 character rune
        // Called multiple times since multiple keys may be pressed
        int pressed_rune = rl::getCharPressed();

        // If the pressed rune (Unicode character) is 0 there are no more keys pressed
        if(pressed_rune == 0) break;

        // UTF8 characters are stored using "variable width encoding"
        // This means a character could be represented by 1-4 bytes
        // Encoding the rune into UTF8 always returns 4 bytes, but the count indicates how many runes the character actually is
        char d = (char)pressed_rune; // Convert the rune to a char
        String bytes = string::tformat("%c", d);
        usz count = bytes.len; //conv::utf8_codepoints(bytes);

        // We'll copy from the start of the bytes array, up to the number of bytes used to represent the character, 
        // into our text input buffer at the current text input offset
        mem::copy(text_input[text_input_offset..], bytes[:count], count);

        // Finally we can offset the text_input_offset by the number of bytes we copied into the buffer
        text_input_offset += (uint)count;
    }

    // Now we can send our text_input buffer to mui so it knows the currently pressed characters
    // We'll just send a slice of the full text_input buffer, up to the latest input offset since it probably wasn't filled
    ctx.input_textfn(string::tformat_zstr("%s", (String)text_input[:text_input_offset]));
  $else
    //if(input_text.len) input_text = "";
    int key;
    while((key = rl::getKeyPressed()) != 0)
    {
        if(input_text.len >= MAX_INPUT_TEXT) break; // prevent buffer overflow

        int size;
        ZString text = rl::codepointToUTF8(rl::getCharPressed(), &size);
        String chr = (String)text[:size];
        if(chr[0] != '\0')
        {
            //input_text = (key == (int)rl::KEY_BACKSPACE) ? input_text.trim_right(chr) : input_text.tconcat(chr);
          input_text = input_text.tconcat(chr);
          //ctx.input_textfn(input_text.zstr_tcopy());
        }
        if(key == (int)rl::KEY_BACKSPACE) {
            int text_len   = input_text.len;
                input_text = (input_text.len >= 2) ? (String)input_text[:text_len - 1] : "";
        }
        //input_text.tconcat(text.str_view());
    }
    //input_text.tconcat("0"); // close the string
    ctx.input_textfn(input_text.zstr_tcopy());
    input_text = ""; // reset the input text buffer
  $endif
}


// This struct stores a mapping from a raylib mouse button enum to the equivalent mui enum
/*
struct MouseButtonMapping @local @compact
{
    RLMouseButton rl; // Raylib mouse button enum
    MU_Mouse mu;// MicroUI mouse button enum;
}*/

<*
  Forwards mouse input from raylib to the MicroUI context.
  @param [&inout] ctx : "The current MicroUI context."
*>
fn void MU_Context.forward_mouse_input(MU_Context* ctx) 
{
    // Get the current mouse position/scroll from raylib
    float scroll_speed = -30.0f; // scroll speed for mouse wheel.
    RLVector2 mouse_position = {rl::getMouseX(), rl::getMouseY()};
    float mouse_scroll = rl::getMouseWheelMove() * scroll_speed; // Invert the scroll direction to match mui's expectations

    // Send the mouse position/scroll to mui
    ctx.input_mousemove((int)mouse_position.x, (int)mouse_position.y);
    ctx.input_scroll(0, (int)mouse_scroll);

    // We'll create an array of mappings using the struct above
 /*
    MouseButtonMapping[*] mouseButtonMappings = {
        {RLMouseButton.LEFT, MU_Mouse.LEFT},
        {RLMouseButton.RIGHT, MU_Mouse.RIGHT},
        {RLMouseButton.MIDDLE, MU_Mouse.MIDDLE},
        {RLMouseButton.SIDE, MU_Mouse.SIDE},
        {RLMouseButton.EXTRA, MU_Mouse.EXTRA},
        {RLMouseButton.FORWARD, MU_Mouse.FORWARD},
        {RLMouseButton.BACK, MU_Mouse.BACK}
    };*/

    // Check each if each mouse button is down or released with Raylib and forward the event to mui if so
    // foreach(button : mouseButtonMappings) 
    // {
    //     if (rl::isMouseButtonPressed(button.rl)) {
    //         ctx.input_mousedown((int)mouse_position.x, (int)mouse_position.y, button.mu);
    //     }
    //     else if (rl::isMouseButtonReleased(button.rl)) {
    //         ctx.input_mouseup((int)mouse_position.x, (int)mouse_position.y, button.mu);
    //     }
    // }

    /*
      https://www.youtube.com/watch?v=-AFAY2IV4bk&t=3087s
      [quote] 
      I think the mouse buttons are defined as (1 << 0), (1 << 1), (1 << 2), etc, 
	  so that you can use that as a bitfield to check multiple mouse buttons at once. So instead of calling mu_input_mousedown/up on each iteration you probably can do
      int buttons = 0;
      for (int button = LEFT; button <= MIDDLE; ++button)
          if (Pressed(button)) buttons |= (1 << button);
      mu_input_mousedown(&ctx, x, y, buttons);
      mu_input_mouseup(&ctx, x, y, buttons); 
      [\quote]
    */
    for(int button = RLMouseButton.LEFT; button <= (int)RLMouseButton.MIDDLE; ++button)
    {
        if (rl::isMouseButtonPressed((RLMouseButton)button)) {
            ctx.input_mousedown((int)mouse_position.x, (int)mouse_position.y, 1 << button);
        }
        if (rl::isMouseButtonReleased((RLMouseButton)button)) {
            ctx.input_mouseup((int)mouse_position.x, (int)mouse_position.y, 1 << button);
        }
    }
}


// This struct stores a mapping from a raylib key enum to the equivalent mui enum
struct KeyMapping @local @compact
{
    int rl;
    MU_Key mu;
}

<*
  Forwards keyboard input from raylib to the MicroUI context.
  @param [&inout] ctx : "The current MicroUI context."
*>
fn void MU_Context.forward_keyboard_input(MU_Context* ctx)
{
    // We'll create an array of mappings using the struct above
    // We don't need to map every raylib key - just the ones mui needs for ui stuff
    KeyMapping[*] keyMappings = {
        {rl::KEY_LEFT_SHIFT,       MU_Key.SHIFT},
        {rl::KEY_RIGHT_SHIFT,      MU_Key.SHIFT},
        {rl::KEY_LEFT_CONTROL,     MU_Key.CTRL},
        {rl::KEY_RIGHT_CONTROL,    MU_Key.CTRL},
        {rl::KEY_LEFT_ALT,         MU_Key.ALT},
        {rl::KEY_RIGHT_ALT,        MU_Key.ALT},
        {rl::KEY_ENTER,            MU_Key.RETURN},
        {rl::KEY_KP_ENTER,         MU_Key.RETURN},
        {rl::KEY_BACKSPACE,        MU_Key.BACKSPACE},
        {rl::KEY_DELETE,           MU_Key.DELETE},
        {rl::KEY_END,              MU_Key.END},
        {rl::KEY_HOME,             MU_Key.HOME},
        {rl::KEY_LEFT,             MU_Key.LEFT},
        {rl::KEY_RIGHT,            MU_Key.RIGHT},
        {rl::KEY_A,                MU_Key.KEY_A},
        {rl::KEY_C,                MU_Key.KEY_C},
        {rl::KEY_V,                MU_Key.KEY_V},
        {rl::KEY_X,                MU_Key.KEY_X},
    };

    foreach(key : keyMappings) 
    {
        if (rl::isKeyPressed(key.rl)) {
            ctx.input_keydown(key.mu);
        }
        else if (rl::isKeyReleased(key.rl)) {
            ctx.input_keyup(key.mu);
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
// micro ui icons 
fn void r_draw_icon(int id, MU_Rect _rect, MU_Color color) @local 
{
	MU_Rect src = mu::ICONS[id]; //atlas[id].rect;
	int x = _rect.x + (_rect.w - src.w) / 2;
	int y = _rect.y + (_rect.h - src.h) / 2;
	// Assuming cmd->icon.id corresponds to a valid icon in the MicroUI icon set
	// Here we would draw the icon based on its ID and rectangle
	// For simplicity, we can use a placeholder drawing function
	//draw_rect(rect(x, y, src.w, src.h), color); // Placeholder for actual icon drawing logic
	rl::setBlendFactors(rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD);
	rl::@blendMode(RLBlendMode.CUSTOM) 
	{
		rl::drawTexturePro(font_atlas,
			(RLRectangle){src.x, src.y, src.w, src.h},
			(RLRectangle){x, y, src.w, src.h},
			(RLVector2){0, 0}, 0.0f, 
			color
		);
	};
}

const MU_Rect[*] ICONS =
{
  [MU_Icon.CLOSE] = { 88, 68, 16, 16 },   // MU_Icon.CLOSE
  [MU_Icon.CHECK] = { 0, 0, 18, 18 },     // MU_Icon.CHECK
  [MU_Icon.EXPANDED] = { 118, 68, 7, 5 }, // MU_Icon.EXPANDED
  [MU_Icon.COLLAPSED] = { 113, 68, 5, 7 }, // MU_Icon.COLLAPSED
  [ATLAS_WHITE] = { 125, 68, 3, 3 },      // ATLAS_WHITE
  [ATLAS_FONT+32] = { 84, 68, 2, 17 },    // ' '
  [ATLAS_FONT+33] = { 39, 68, 3, 17 },    // '!'
  [ATLAS_FONT+34] = { 114, 51, 5, 17 },   // '"'
  [ATLAS_FONT+35] = { 34, 17, 7, 17 },    // '#'
  [ATLAS_FONT+36] = { 28, 34, 6, 17 },    // '$'
  [ATLAS_FONT+37] = { 58, 0, 9, 17 },     // '%'
  [ATLAS_FONT+38] = { 103, 0, 8, 17 },    // '&'
  [ATLAS_FONT+39] = { 86, 68, 2, 17 },    // '''
  [ATLAS_FONT+40] = { 42, 68, 3, 17 },    // '('
  [ATLAS_FONT+41] = { 45, 68, 3, 17 },    // ')'
  [ATLAS_FONT+42] = { 34, 34, 6, 17 },    // '*'
  [ATLAS_FONT+43] = { 40, 34, 6, 17 },    // '+'
  [ATLAS_FONT+44] = { 48, 68, 3, 17 },    // ','
  [ATLAS_FONT+45] = { 51, 68, 3, 17 },    // '-'
  [ATLAS_FONT+46] = { 54, 68, 3, 17 },    // '.'
  [ATLAS_FONT+47] = { 124, 34, 4, 17 },   // '/'
  [ATLAS_FONT+48] = { 46, 34, 6, 17 },    // '0'
  [ATLAS_FONT+49] = { 52, 34, 6, 17 },    // '1'
  [ATLAS_FONT+50] = { 58, 34, 6, 17 },    // '2'
  [ATLAS_FONT+51] = { 64, 34, 6, 17 },    // '3'
  [ATLAS_FONT+52] = { 70, 34, 6, 17 },    // '4'
  [ATLAS_FONT+53] = { 76, 34, 6, 17 },    // '5'
  [ATLAS_FONT+54] = { 82, 34, 6, 17 },    // '6'
  [ATLAS_FONT+55] = { 88, 34, 6, 17 },    // '7'
  [ATLAS_FONT+56] = { 94, 34, 6, 17 },    // '8'
  [ATLAS_FONT+57] = { 100, 34, 6, 17 },   // '9'
  [ATLAS_FONT+58] = { 57, 68, 3, 17 },    // ':'
  [ATLAS_FONT+59] = { 60, 68, 3, 17 },    // ';'
  [ATLAS_FONT+60] = { 106, 34, 6, 17 },   // '<'
  [ATLAS_FONT+61] = { 112, 34, 6, 17 },   // '='
  [ATLAS_FONT+62] = { 118, 34, 6, 17 },   // '>'
  [ATLAS_FONT+63] = { 119, 51, 5, 17 },   // '?'
  [ATLAS_FONT+64] = { 18, 0, 10, 17 },    // '@'
  [ATLAS_FONT+65] = { 41, 17, 7, 17 },    // 'A'
  [ATLAS_FONT+66] = { 48, 17, 7, 17 },    // 'B'
  [ATLAS_FONT+67] = { 55, 17, 7, 17 },    // 'C'
  [ATLAS_FONT+68] = { 111, 0, 8, 17 },    // 'D'
  [ATLAS_FONT+69] = { 0, 35, 6, 17 },     // 'E'
  [ATLAS_FONT+70] = { 6, 35, 6, 17 },     // 'F'
  [ATLAS_FONT+71] = { 119, 0, 8, 17 },    // 'G'
  [ATLAS_FONT+72] = { 18, 17, 8, 17 },    // 'H'
  [ATLAS_FONT+73] = { 63, 68, 3, 17 },    // 'I'
  [ATLAS_FONT+74] = { 66, 68, 3, 17 },    // 'J'
  [ATLAS_FONT+75] = { 62, 17, 7, 17 },    // 'K'
  [ATLAS_FONT+76] = { 12, 51, 6, 17 },    // 'L'
  [ATLAS_FONT+77] = { 28, 0, 10, 17 },    // 'M'
  [ATLAS_FONT+78] = { 67, 0, 9, 17 },     // 'N'
  [ATLAS_FONT+79] = { 76, 0, 9, 17 },     // 'O'
  [ATLAS_FONT+80] = { 69, 17, 7, 17 },    // 'P'
  [ATLAS_FONT+81] = { 85, 0, 9, 17 },
  [ATLAS_FONT+82] = { 76, 17, 7, 17 },
  [ATLAS_FONT+83] = { 18, 51, 6, 17 },
  [ATLAS_FONT+84] = { 24, 51, 6, 17 },
  [ATLAS_FONT+85] = { 26, 17, 8, 17 },
  [ATLAS_FONT+86] = { 83, 17, 7, 17 },
  [ATLAS_FONT+87] = { 38, 0, 10, 17 },
  [ATLAS_FONT+88] = { 90, 17, 7, 17 },
  [ATLAS_FONT+89] = { 30, 51, 6, 17 },
  [ATLAS_FONT+90] = { 36, 51, 6, 17 },
  [ATLAS_FONT+91] = { 69, 68, 3, 17 },
  [ATLAS_FONT+92] = { 124, 51, 4, 17 },
  [ATLAS_FONT+93] = { 72, 68, 3, 17 },
  [ATLAS_FONT+94] = { 42, 51, 6, 17 },
  [ATLAS_FONT+95] = { 15, 68, 4, 17 },
  [ATLAS_FONT+96] = { 48, 51, 6, 17 },
  [ATLAS_FONT+97] = { 54, 51, 6, 17 },
  [ATLAS_FONT+98] = { 97, 17, 7, 17 },
  [ATLAS_FONT+99] = { 0, 52, 5, 17 },
  [ATLAS_FONT+100] = { 104, 17, 7, 17 },
  [ATLAS_FONT+101] = { 60, 51, 6, 17 },
  [ATLAS_FONT+102] = { 19, 68, 4, 17 },
  [ATLAS_FONT+103] = { 66, 51, 6, 17 },
  [ATLAS_FONT+104] = { 111, 17, 7, 17 },
  [ATLAS_FONT+105] = { 75, 68, 3, 17 },
  [ATLAS_FONT+106] = { 78, 68, 3, 17 },
  [ATLAS_FONT+107] = { 72, 51, 6, 17 },
  [ATLAS_FONT+108] = { 81, 68, 3, 17 },
  [ATLAS_FONT+109] = { 48, 0, 10, 17 },
  [ATLAS_FONT+110] = { 118, 17, 7, 17},
  [ATLAS_FONT+111] = { 0, 18, 7, 17 },
  [ATLAS_FONT+112] = { 7, 18, 7, 17 },
  [ATLAS_FONT+113] = { 14, 34, 7, 17 },
  [ATLAS_FONT+114] = { 23, 68, 4, 17 },
  [ATLAS_FONT+115] = { 5, 52, 5, 17 },
  [ATLAS_FONT+116] = { 27, 68, 4, 17 },
  [ATLAS_FONT+117] = { 21, 34, 7, 17 },
  [ATLAS_FONT+118] = { 78, 51, 6, 17 },
  [ATLAS_FONT+119] = { 94, 0, 9, 17 },
  [ATLAS_FONT+120] = { 84, 51, 6, 17 },
  [ATLAS_FONT+121] = { 90, 51, 6, 17 },
  [ATLAS_FONT+122] = { 10, 68, 5, 17 },
  [ATLAS_FONT+123] = { 31, 68, 4, 17 },
  [ATLAS_FONT+124] = { 96, 51, 6, 17 },
  [ATLAS_FONT+125] = { 35, 68, 4, 17 },
  [ATLAS_FONT+126] = { 102, 51, 6, 17 },
  [ATLAS_FONT+127] = { 108, 51, 6, 17 }
};