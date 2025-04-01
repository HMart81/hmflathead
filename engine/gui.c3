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
    TODO: 
        A ingame gui edit mode for easy placement of widgets
        Perhaps even create a simple gui editor using raygui buttons and such...
*/
module engine::gui;

// region modules
import std::io;
import std::core::mem; // for malloc
import std::math;
import std::collections::list;
import raylib5::rl;
import engine::misc;
import engine::assets::astmng; // asset manager
import engine::logging::lgr;
import game::main;
import game::actors::ent;
import game::serialize::svs; // save system
import game::low_level::cvar;
// end_region

// region alias
alias assetManager @private = astmng::assetManager;
// end_region

// region constants
//const bool PANEL_PROFILE = true;
const bool DEBUG_PANELS   = true;
const int  MIN_PANEL_SIZE = 32;
// end_region

// region cvars
Cvar ui_debugDraw @public = { "ui_debugDraw", CvarType.BOOLEAN, "1", "show debug visualization for gui development" };
//Cvar ui_editGUI   @public = { "ui_editGUI", CvarType.BOOLEAN, "0", "turn on gui editing functionality for gui development" };


fn void register_cvars() @public {
    cvar::@register(&ui_debugDraw);
    //cvar::@register(&ui_editGUI);
}
// end_region

enum PanelShape : inline int 
{
    BOX,
    ROUNDED_BOX
}

/////////////////////////////////// ************** /////////////////////////

// NOTE(HM) Panel is a simple data structure representing a big square or image, 
// used for background images or single color rectangles, buttons, etc...
struct Panel (SaveSystemInterface)
{
   PanelShape shape;
   Rectangle  rect;
   Color      color;
   Texture2D* tex;
}

fn void Panel.save(&self, SaveFile* file) @dynamic {
    svs::writeInt(file, self.shape);
    svs::writeRect(file, self.rect);
    svs::writeColor(file, self.color);
    // cannot save pointers
    // cannot save Texture2D's because they are saved on GPU memoru
    // TODO(HM) turn textures into a asset that can be saved and reloaded...
}

fn void Panel.reload(&self, SaveFile* file) @dynamic {
    int value;
    svs::readInt(file, &value);
    self.shape = PanelShape.from_ordinal(value);
    svs::readRect(file, &self.rect);
    svs::readColor(file, &self.color);
}

fn void Panel.initRec(&self, Rectangle rect, Color color = rl::COLOR_RED) @inline {
    self.shape = BOX;  // @hardcode
    self.rect  = rect;
    self.color = color;
}

fn void Panel.initV(&self, Vec2f pos, Vec2f size, RColor color) @inline {
    Rectangle temp = {pos.x, pos.y, size.x, size.y};
    self.initRec(temp, color);
}

fn void Panel.init(&self) @inline {
    Rectangle temp = {0, 0, MIN_PANEL_SIZE, MIN_PANEL_SIZE};
    self.initRec(temp, rl::WHITE);
}

fn void Panel.deinit(&self) @inline {
    if(self.tex) self.tex = null;
}

fn void Panel.setShape(&self, PanelShape shape) @inline => self.shape = shape;

<*
    @param w_scaler "value to scale x coordinate with"
    @param h_scaler "value to scale y coordinate with"
    @require w_scaler >= 0.0 && w_scaler <= 1.0f
    @require h_scaler >= 0.0 && h_scaler <= 1.0f
*>
fn void Panel.scale(&self, float w_scaler, float h_scaler) @inline {
    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
}

<*
    @param scale "vector to scale the panel with"
    @require scale.x >= 0.0 && scale.x <= 1.0f
    @require scale.y >= 0.0 && scale.y <= 1.0f
*>
fn void Panel.scaleV(&self, Vec2f scale) @inline {
    self.scale(scale.x, scale.y);
}

<*
    @param amount "value to scale equaly both coordinates with"
    @require amount >= 0.0 && amount <= 1.0f
*>
fn void Panel.scale_equaly(&self, float amount) @inline {
    self.scale(amount, amount);
}

<*
    Sets the size of the Panel, units is in pixels.
*>
fn void Panel.setSize(&self, float w, float h) @inline {
    self.rect.width  = w;
    self.rect.height = h;
}

<*
    Sets the size of the Panel, vector units is in pixels.
*>
fn void Panel.setSizeV(&self, Vec2f scale) @inline {
    self.setSize(scale.x, scale.y);
}

<*
    gets the size of the Panel, units is in pixels.
*>
fn Vec2f Panel.getSize(&self) @inline {
    return { self.rect.width, self.rect.height };
}

<*
    gets the width of the Panel, units is in pixels.
*>
fn float Panel.getWidth(&self) @inline {
    return self.rect.width;
}

<*
    gets the height of the Panel, units is in pixels.
*>
fn float Panel.getHeight(&self) @inline {
    return self.rect.height;
}

<*
    replaces the position of the Panel, units is in pixels.
*>
fn void Panel.setPosition(&self, float x, float y) @inline {
    self.rect.x = x;
    self.rect.y = y;
}

<*
    replaces position of the Panel, vector units is in pixels.
*>
fn void Panel.setPositionV(&self, Vec2f pos) @inline {
    self.setPosition(pos.x, pos.y);
}

<*
    adds to existing position of the Panel, units is in pixels.
*>
fn void Panel.addToPosition(&self, float x, float y) @inline {
    self.rect.x += x;
    self.rect.y += y;
}

<*
    adds to existing position of the Panel, vector units is in pixels.
*>
fn void Panel.addToPositionV(&self, Vec2f pos) @inline {
    self.addToPosition(pos.x, pos.y);
}

<*
    gets current position of the Panel, vector units is in pixels.
*>
fn Vec2f Panel.getPosition(&self) @inline {
    return { self.rect.x, self.rect.y };
}

<*
    @param [in] tex "texture to assign to the panel"
    @require tex != null
*>
fn void Panel.setTexture(&self, Texture2D* tex) @inline {
    self.tex = tex;
}

fn bool Panel.asTexture(&self) @inline => self.tex != null;

fn bool Panel.isValid(&self) @inline {
    if(self.rect.width  >= MIN_PANEL_SIZE && 
       self.rect.height >= MIN_PANEL_SIZE ) return true;
       
    return false;
}

fn void Panel.draw(&self) 
{
    if(self.asTexture()) 
    {
        // TODO(HM) find how to draw a image on a rounded rectangle!?
        if (rl::isTextureValid(*self.tex)) {
            Vec2f tex_size = {self.tex.width, self.tex.height};
            Rectangle source = {0, 0, tex_size.x, tex_size.y};
            // NOTE(HM) 
            // center of the texture (rotation/scale point), it's relative to destination rectangle dimentions, not the screen
            rl::drawTexturePro(*self.tex, source, self.rect, {0, 0}, 0.0f, self.color);
        }
    } else {
        if(self.shape == BOX) {
            misc::@drawRect(self.rect, self.color);
        } else if(self.shape == ROUNDED_BOX) {
            rl::drawRectangleRounded(self.rect, 0.65f, 6, self.color);
        }
    }
}

//////////////// ******** WIDGET'S ******** ////////////////////////

// NOTE(HM) Widget is a data structure representing anything inside a gui, like buttons and such.


struct WidgetFlags {
    union {
        bool isHidden;
        bool should_hide;
    }
    bool isInteractive;
    bool asFocus;
}

interface WidgetInterface
{
    fn void init();
    fn void initExt() @optional;
    fn void deinit();
    fn void update();
    fn void hide();
    fn void show();
    fn void draw();
    fn bool asFocus();
    fn bool hidden();
    fn bool isMouseOver() @optional;
    fn bool isWithinScreenBounds() @optional;
    fn void addTo(Desktop*, String);
    fn void setInteractive(bool);
    fn bool isInteractive();
    fn Desktop* getDesktop();
    fn void bindTo(Widget* other);
    fn bool bound();
    fn void unbind();
    fn String getName();
    fn void link(Widget* other);
    fn bool isLinked();
    fn void unlink();
    fn void setColor(rl::Color);
}

const KIND_TEXT    = 1;
const KIND_BUTTON  = 2;

alias WidgetCallback = fn void(Widget*);

struct Widget (WidgetInterface) 
{
    // extends Panel (super/base class)
    inline Panel super;
    
    int id;  // used to uniquily identify each widget on a gui
    String name;
    int layer;
    int kind;
    WidgetFlags flags;
    

    Widget* next;
    struct parent {
        Desktop* desktop;
        Widget* other;
    }

    // callbacks
    WidgetCallback onOver;
    WidgetCallback onStopOver;
    WidgetCallback onPress;
    WidgetCallback onSinglePress;
    WidgetCallback onDoublePress;
    WidgetCallback onRelease;
    WidgetCallback onEnterKey;
}

fn void Widget.init(&self) @dynamic {
    self.super.init();
}

fn void Widget.deinit(&self) @dynamic{
    self.super.deinit();
    self.unlink();
    self.unbind();
    self.parent.desktop = null;
}

fn void Widget.update(&self) @dynamic {
    if(self.hidden()) return;

    if (self.isMouseOver()) {
        self.flags.asFocus = true;
    } else {
        self.flags.asFocus = false;
    }
    
    if(self.bound()) {
        // if bound our position is updated to always be relative to the parent origin
        Vec2f parent_origin = self.parent.other.getPosition();
        Vec2f old_offset    = self.getPosition() - parent_origin;
        Vec2f new_offset    = parent_origin + old_offset;
        self.setPositionV(new_offset);
    }
}

fn void Widget.hide(&self) @inline @dynamic {
    if(self.hidden()) return;
    self.flags.isHidden = true;
}

fn void Widget.show(&self) @inline @dynamic {
    if(!self.hidden()) return;
    self.flags.isHidden = false;
}

fn void Widget.draw(&self) @dynamic {
    if(self.hidden()) return;
    
    self.super.draw();
}

fn bool Widget.asFocus(&self) @inline @dynamic => self.flags.asFocus;
fn bool Widget.hidden(&self)  @inline @dynamic => self.flags.isHidden;

//    WARNING(HM)
//    If the 2D camera view is changed in any way besides moving in x and y
//    like if the camera is zoomed or the camera is rotated, this will break.
//    If so it will require conversion from world space coordinates to camera space.
fn bool Widget.isMouseOver(&self) @dynamic
{
    if (self.hidden()) return false;

    // gets windows mouse position...
    Vec2f mouseWorldPos = rl::getMousePosition().toVec2f();

    // a small 32x32 pixels box
    Vec2f mouse_size = main::getGameCursorSize();
    Rectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_size);

    if (rl::checkCollisionRecs(mouseRect, self.rect)) return true;

    return false;
}

fn bool Widget.isWithinScreenBounds(&self) @dynamic
{
    //if (self.hidden()) return false;

    int w, h;
    w = main::gpGame.screen.w;
    h = main::gpGame.screen.h;

    Rectangle screen_bounds = {
    .x      = 0,
    .y      = 0,
    .width  = w,
    .height = h
    };

    return rl::checkCollisionRecs(screen_bounds, self.rect) ? true : false;
}

<*
* @param in desktop "parent desktop"
* @require desktop != null
*>
fn void Widget.addTo(&self, Desktop* desktop, String name) @dynamic {
    self.parent.desktop = desktop;
    if (self.parent.desktop.isInteractive) self.setInteractive(true);

    self.id = (int)self.parent.desktop.children.len() + 1;
    
    // set name based on desktop name
    if(name == "") {
        name = "Widget";
    } else {
        name.tconcat("_Widget");
    }
    
    if (self.id < 10) {
        self.name = string::tformat("%s_%s%d", self.parent.desktop.name, name.tconcat("0"), self.id);
        if (self.bound()) {
            self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.name, name.tconcat("0"), self.id);
        }
    } else {
      self.name = string::tformat("%s_%s%d", self.parent.desktop.name, name, self.id);
      if (self.bound()) {
          self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.name, name, self.id);
      }
    }
    
    self.parent.desktop.addChild(self);
}

fn void Widget.setInteractive(&self, bool choice) @inline @dynamic {
    self.flags.isInteractive = choice;
}

fn bool Widget.isInteractive(&self) @inline @dynamic => self.flags.isInteractive;

<*
* @ensure return != null
*>
fn Desktop* Widget.getDesktop(&self) @dynamic => self.parent.desktop;

<*
* @param in other "parent widget"
* @require other != null
*>
fn void Widget.bindTo(&self, Widget* other) @dynamic {
    if(self.bound()) {
        lgr::warning(Where.CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.id, other.id, self.parent.other.id);
        return;
    }
    
    // we are now bound to the parent
    self.parent.other = other;

    // our position is now relative to the parent origin
    Vec2f desktop_origin = {0, 0};
    Vec2f parent_origin  = other.getPosition();
    Vec2f old_offset     = self.getPosition() - desktop_origin;
    Vec2f new_offset     = parent_origin + old_offset; //(our_pos - parent_origin);
    self.setPositionV(new_offset);
    //
}

fn bool Widget.bound(&self) @dynamic {
    return (self.parent.other != null) ? true : false;
}

fn void Widget.unbind(&self) @dynamic {
     if(!self.bound()) {
        return;
    }
    
    self.parent.other = null;
}

fn String Widget.getName(&self) @inline @dynamic => self.name;

fn void Widget.link(&self, Widget* other) @dynamic {
    if (other == null) return;

    if (self.isLinked()) {
        lgr::warning(Where.CONSOLE, "Cannot link %s to %s because is already linked to %s.", self.id, other.id, self.next.id);
        return;
    }

    self.next = other;
}

fn bool Widget.isLinked(&self) @dynamic {
    return (self.next != null) ? true : false;
}

fn void Widget.unlink(&self) @inline @dynamic {
    if (self.isLinked()) self.next = null;
}

fn void Widget.setColor(&self, Color color) @dynamic {
    self.super.color = color;
}

/////////////////////////////////////// extra widgets //////////////////////////////////////////////////////

enum WidgetTextAlign
{
    CENTER,
    LEFT,
    RIGHT,
}

struct WidgetText {
    // extends Widget (super/base class)
    inline Widget super;

    String text;
    int text_len;
    // todo use a font
    int font_size;
    Color text_color;
    WidgetTextAlign align;
}

<*
* @param in desk "desktop where this widget will live"
* @require desk != null
*>
fn void WidgetText.init(&self) @inline {
    self.super.init();
    self.setColor({0, 0, 0, 0});
    self.kind = KIND_TEXT;
    self.font_size = 20; //@hardcode
    self.text_color = rl::WHITE; //@hardcode
    self.align = WidgetTextAlign.CENTER;
}

fn void WidgetText.deinit(&self) @inline {
    self.super.deinit();
}

<*
* @require self.text != ""
*>
fn void WidgetText.updateBounds(&self) @local {
    self.text_len = rl::measureText(self.text.zstr_tcopy(), self.font_size);
    self.setSize((float)self.text_len, (float)self.font_size);
}

fn void WidgetText.setText(&self, String text) {
    self.text = text;
    self.updateBounds();
}

fn void WidgetText.setTextColor(&self, Color color) @inline {
    self.text_color = color;
}

fn void WidgetText.setAlign(&self, WidgetTextAlign align) @inline {
    self.align = align;
}

fn void WidgetText.setFontSize(&self, int size) @inline {
    self.font_size = size;
    self.updateBounds();
}

fn void WidgetText.update(&self) {
    self.super.update();
}

fn void WidgetText.draw(&self) @inline {
    if (self.hidden()) return;

    self.super.draw();
    
    Vec2f center;
    ZString text = self.text.zstr_tcopy();
    //int text_len = rl::measureText(text, self.font_size);
    
    switch (self.align)
    {
    case CENTER:
        center = {
            self.rect.x + self.rect.width / 2,
            self.rect.y + self.rect.height / 2
        };
        center.x -= (float)(self.text_len / 2);
        center.y -= (float)self.font_size / 2;
    case LEFT:
        center = {
            self.rect.x,
            self.rect.y
        };
    case RIGHT:
        center = {
            self.rect.x + self.rect.width,
            self.rect.y
        };
        center.x -= self.text_len;
    }
    
    rl::drawText(text, (int)center.x, (int)center.y, self.font_size, self.text_color);
}

<*
* @param in menu "desktop where this widget will live"
* @require menu != null
* @ensure return != null
*>
fn WidgetText* createLabel(String name, String text, Color text_color, Desktop* menu) {
    WidgetText* label = mem::new(WidgetText);
    label.init();
    if(name == "") {
        name = "Label";
    } else {
        name.tconcat("_Label");
    }
    label.addTo(menu, name);
    label.setText(text);
    label.setTextColor(text_color);
    return label;
}


struct WidgetButton {
    // extends Widget (super/base class)
    inline Widget super;
    
    Color default_color;
    Color over_color;
    Color pressed_color;
    Color activated_color;
    bool pressed;
    bool activated;
    Sound* interaction_sound;
    //bool sound_played;
    bool reset;
    int press_count;
}

<*
* @param in desk "desktop where this widget will live"
* @require desk != null
*>
fn void WidgetButton.init(&self) @inline {
    self.super.init();
    self.kind = KIND_BUTTON;
    self.setColor(rl::WHITE); //@hardcode
    self.setOverColor(rl::RED); //@hardcode
    self.setPressedColor(rl::GREEN); //@hardcode
    self.setActivatedColor(rl::BLUE); //@hardcode
    self.setSound(&main::gpGame.default_sound); //@hardcode todo give this a better sound
}

fn void WidgetButton.deinit(&self) @inline {
    self.super.deinit();
    if (self.interaction_sound) self.interaction_sound = null;
}

fn void WidgetButton.setColor(&self, Color color) @dynamic {
    self.super.setColor(color);
}

fn void WidgetButton.setDefaultColor(&self, Color color) @inline {
    self.default_color = color;
    self.setColor(color);
}
fn void WidgetButton.setOverColor(&self, Color color)      @inline => self.over_color      = color;
fn void WidgetButton.setActivatedColor(&self, Color color) @inline => self.activated_color = color;
fn void WidgetButton.setPressedColor(&self, Color color)   @inline => self.pressed_color   = color;

fn void WidgetButton.setSound(&self, Sound* sound) @inline {
    self.interaction_sound = sound;
}

/*
fn void WidgetButton.onEnterKey(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.onSinglePress();
}
*/


fn void WidgetButton.manage_interactions(&self) @local{
    if (self.isInteractive() == false) return;

    //main::lgr::info(Where.CONSOLE, "Gui: I'm over button: %s", self.name);
    if (self.asFocus()) 
    {
        if(self.onOver) self.onOver(self);

        if (rl::isMouseButtonDown(MouseButton.LEFT) && self.press_count >= 1) {
            //main::lgr::info(Where.CONSOLE, "Gui: I'm pressing button: %s", self.name);
            if (self.onPress) self.onPress(self);
        }
        // pressed once
        if (rl::isMouseButtonDown(MouseButton.LEFT) && self.press_count == 0) {
            if (self.onSinglePress) self.onSinglePress(self);
        }

        if (rl::isMouseButtonReleased(MouseButton.LEFT)) {
            if (self.onRelease) self.onRelease(self);
        }

        if (rl::isKeyPressed(rl::KEY_ENTER) && !rl::isKeyPressedRepeat(rl::KEY_ENTER)) {
            if (self.onEnterKey) self.onEnterKey(self);
        }
    } else {
        if (self.onStopOver) self.onStopOver(self);
    }
}

fn void WidgetButton.update(&self)
{
    // NOTE(HM) still so much to learn about OOP...
    // I need to manully call the root widget update,
    // that is the update method from the super class Panel 
    // for the focus code to work
    self.super.update(); // for isMouseOver to run...
    //
    self.manage_interactions();
}

fn void WidgetButton.draw(&self) {
    self.super.draw();
}

<*
* @param in menu "desktop where this widget will live"
* @require menu != null
* @ensure return != null
*>
fn WidgetButton* createButton(String name, Desktop* menu) {
    WidgetButton* button = mem::new(WidgetButton);
    button.init();
    if(name == "") {
        name = "Button";
    } else {
        name.tconcat("_Button");
    }
    button.addTo(menu, name);
    return button;
}


//////////////////////////////////// DESKTOP //////////////////////////////////////

/*
    NOTE(HM) 
    
    A Desktop can be thought like a OS desktop, a place 
        where you put all icons, buttons and windows.
    Is where the entire GUI construct lives.
    
    BASIC GUI creation process:
    
    - Create a Desktop
        gui::Desktop main_menu;
    - init the Desktop
        main_menu.ini(...);
    - create any widgets
        gui::WidgetButton main_menu_button;
    - init the Widget and add it to Desktop
        main_menu_button.init();
        main_menu_button.addTo(&main_menu);
*/

alias ChildrenQueue = List{Widget*};

struct Desktop (SaveSystemInterface) {
    // id
    String name;
    
    // visuals
    Rectangle rect;
    Color color;
    Texture2D* tex;
    //
    
    // flags
    bool isInteractive;
    bool visible;
    bool active;
    bool loading; // when eventually we load guis from a file
    //
    // to handle timing while the desktop is open/active
    int time; // milliseconds
    
    // Lists
    ChildrenQueue children;
    // todo make a queue for hidden children to better control what to hide and show, 
    // when hidding or showing the desktop
}

fn void Desktop.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Desktop.reload(&self, SaveFile* file) @dynamic {
// todo
}

// todo
fn bool Desktop.initFromFile(&self, ZString path, bool cache ) {
/*

	if ( !path.len ) {
		// FIXME: Memory leak!!
		return false;
	}

	self.loading = true;
    
	source = qpath;
	state.Set( "text", "Test Text!" );

	idParser src( LEXFL_NOFATALERRORS | LEXFL_NOSTRINGCONCAT | LEXFL_ALLOWMULTICHARLITERALS | LEXFL_ALLOWBACKSLASHSTRINGCONCAT );

	//Load the timestamp so reload guis will work correctly
	fileSystem->ReadFile(qpath, NULL, &timeStamp);

	src.LoadFile( qpath );

	if ( src.IsLoaded() ) {
		idToken token;
		while( src.ReadToken( &token ) ) {
			if ( idStr::Icmp( token, "windowDef" ) == 0 ) {
				desktop->SetDC( &uiManagerLocal.dc );
				if ( desktop->Parse( &src, rebuild ) ) {
					desktop->SetFlag( WIN_DESKTOP );
					desktop->FixupParms();
				}
				continue;
			}
		}

		state.Set( "name", qpath );
	} else {
		desktop->SetDC( &uiManagerLocal.dc );
		desktop->SetFlag( WIN_DESKTOP );
		desktop->name = "Desktop";
		desktop->text = va( "Invalid GUI: %s", qpath );
		desktop->rect = idRectangle( 0.0f, 0.0f, 640.0f, 480.0f );
		desktop->drawRect = desktop->rect;
		desktop->foreColor = idVec4( 1.0f, 1.0f, 1.0f, 1.0f );
		desktop->backColor = idVec4( 0.0f, 0.0f, 0.0f, 1.0f );
		desktop->SetupFromState();
		common->Warning( "Couldn't load gui: '%s'", qpath );
		loading = false;
		return false;
	}

	interactive = desktop->Interactive();

	if ( uiManagerLocal.guis.Find( this ) == NULL ) {
		uiManagerLocal.guis.Append( this );
	}

*/
	self.loading = false;
	return true;
}


fn void Desktop.init(&self, String name) @inline {
    self.name = string::tformat("Desktop_%s", name);
    //
    //
    assert(rl::isWindowReady() == true);
    self.rect = { // @hardcode
        .x      = 0,
        .y      = 0, 
        .width  = main::gpGame.screen.w,
        .height = main::gpGame.screen.h,
    };
    
    self.color = rl::WHITE;
    //
    self.isInteractive = true;
    self.show();
    
    Desktop* this = self;
    local_manager.register(this);
}


fn void Desktop.deinit(&this) @inline {
    this.clear();
    // last clear ourself
    if(this.tex) this.tex = null;
    local_manager.unregister(this);
}

fn void Desktop.activate(&self, bool activate, int _time) {
	self.time   = _time;
	self.active = activate;
}

fn void Desktop.stateChanged(&self, int _time, bool redraw ) {
	self.time = _time;
	if (redraw) {
		self.redraw(_time);
	}
	/*if ( state.GetBool( "noninteractive" ) ) {
		interactive = false;
	}
	else {
		if (desktop) {
			interactive = desktop->Interactive();
		} else {
			interactive = false;
		}
	}*/
}

fn String Desktop.getName(&self) @inline => self.name;

fn void Desktop.setColor(&self, Color color) @inline => self.color = color;

// delete all down to the basic desktop
fn void Desktop.clear(&self) @inline
{
    if (self.children.len()) 
    {
        foreach(child: self.children) 
        {
            switch (child.kind) 
            {
                case KIND_BUTTON:
                    ((WidgetButton*)child).deinit(); 
                case KIND_TEXT:
                    ((WidgetText*)child).deinit(); 
                default:
                   ((Widget*)child).deinit(); 
            }
        }
    }
}

fn bool Desktop.hidden(&self) @inline => !self.visible;

fn void Desktop.update(&self) 
{
    if(self.hidden()) return;
    
    if (self.children.len()) 
    {
        foreach(child: self.children) 
        {
            switch (child.kind) 
            {
                case KIND_BUTTON:
                    ((WidgetButton*)child).update(); 
                case KIND_TEXT:
                    ((WidgetText*)child).update(); 
                default:
                   ((Widget*)child).update(); 
            }
        }
    }
}

fn void Desktop.hide(&self) 
{
    if(self.hidden()) return;
    
    self.visible = false;

    // hide children
    
    if (self.children.len()) 
    {
        foreach(child: self.children) 
        {
           switch (child.kind) 
           {
                case KIND_BUTTON:
                    ((WidgetButton*)child).hide(); 
                case KIND_TEXT:
                    ((WidgetText*)child).hide(); 
                default:
                   ((Widget*)child).hide(); 
            }
        }
    }
}

fn void Desktop.show(&self) {
    if(!self.hidden()) return;
    
    self.visible = true;
    
    // todo find a way to only show certain children not all
    
    if (self.children.len()) {
        foreach(child: self.children) {
            switch (child.kind) {
                case KIND_BUTTON:
                    ((WidgetButton*)child).show(); 
                case KIND_TEXT:
                    ((WidgetText*)child).show(); 
                default:
                   ((Widget*)child).show(); 
            }
        }
    }
}

fn void Desktop.drawCursor(&self) {
	if ( self.isInteractive ) {
		main::show_game_cursor();
	} else {
		main::hide_game_cursor();
	}
}

fn void Desktop.redraw(&self, int _time)  {
    if(self.hidden()) return;
    
    /*if ( r_skipGuiShaders.GetInteger() > 5 ) {
		return;
	}*/
    
	if (!self.loading) {
		self.time = _time;
	}
    
    self.drawCursor();
    
    if(self.tex) {
        assert(rl::isTextureValid(*self.tex));
        rl::drawTexture(*self.tex, (int)self.rect.x, (int)self.rect.y, self.color);
    } else {
        misc::@drawRect(self.rect, self.color);
    }
    
    // now handle our children
    if (self.children.len()) {
        foreach(child: self.children) {
           switch (child.kind) {
                case KIND_BUTTON:
                    ((WidgetButton*)child).draw(); 
                case KIND_TEXT:
                    ((WidgetText*)child).draw(); 
                default:
                   ((Widget*)child).draw(); 
            }
        }
    }
    
    self.debug();
}

fn void Desktop.draw(&self, int time) {
    Desktop* guiActive = main::gpGame.guiActive;

    if ( guiActive ) {
		guiActive.redraw(time);
	}
}

fn void Desktop.addChild(&self, Widget* child) @inline @local {
    self.children.push(child);
}

fn void Desktop.debug(&self) 
{
    if(ui_debugDraw.getBool()) 
    {
        int scr_w, scr_h;
        float lineThick  = 1.0f;
        scr_w = main::gpGame.screen.w;
        scr_h = main::gpGame.screen.h;
/*
        Vec2f w_startPos; // = {0, 0};
        Vec2f h_startPos; // = {0, 0};
        // draw a background grid
        for(int i = 0; i < scr_w; i++) {
            for(int j = 0; j < scr_h; j++) {
                rl::drawLineEx( 
                    h_startPos.toVector2(), 
                    (h_startPos + misc::VEC_RIGHT * scr_w).toVector2(), 
                    lineThick, rl::GRAY
                );
                float h_line_seperation = (0.05f * scr_w);
                h_startPos += (Vec2f){h_line_seperation, 0};
            }
            rl::drawLineEx(
                w_startPos.toVector2(), 
                (w_startPos + misc::VEC_DOWN * scr_h).toVector2(), 
                lineThick, rl::GRAY
            );
            float w_line_seperation = (0.05f * scr_h);
            w_startPos += (Vec2f){0, w_line_seperation};
        }
*/
        // draw a react around the destop area itself
        rl::drawRectangleLinesEx(self.rect, 2.0f, rl::RED);
        // show destop name
        Vec2f dbg_text_pos;
        dbg_text_pos += misc::VEC_RIGHT * (0.10f * scr_w);
        dbg_text_pos += misc::VEC_DOWN * (0.05f * scr_h);
        String desktop_name = string::tformat("GUI: \"%s\"", self.name);
        rl::drawText(desktop_name.zstr_tcopy(), (int)dbg_text_pos.x, (int)dbg_text_pos.y, 9, rl::RED);
        // show destop time
        dbg_text_pos += misc::VEC_DOWN * (0.025f * scr_h);
        String time = string::tformat("GUI TIME: \"%s\"", self.time);
        rl::drawText(time.zstr_tcopy(), (int)dbg_text_pos.x, (int)dbg_text_pos.y, 9, rl::RED);
        
        // draw the children BBox
        // now handle our children
        if (self.children.len()) 
        {
            foreach(child: self.children)
            {
               dbg_text_pos = {child.rect.x, child.rect.y};
               dbg_text_pos += misc::VEC_UP * (0.30f * child.rect.height); 
               rl::drawText(
                    string::tformat("(w:%dpx, h:%dpx) : (w:%d%%, h:%d%%)", child.rect.x, child.rect.y, 
                    ((child.rect.x * 100) / scr_w), ((child.rect.y * 100) / scr_h)).zstr_tcopy(),
                    (int)dbg_text_pos.x, (int)dbg_text_pos.y, 9, rl::RED
               );
               // draw widget center
               rl::drawCircle((int)child.rect.x, (int)child.rect.y, 2.0f, rl::SKYBLUE);
               rl::drawRectangleLinesEx(child.rect, 1.5f, rl::RED);
            }
        }
    }
}


//////////////////////////////////// DESKTOP MANAGER //////////////////////////////////////

alias DesktopList = List{Desktop*};

// NOTE(HM) TODO(HM) Rename to MenuOS?
// Every user GUI should have at lest one Desktop,
// is a data structure to put everything that makes up a user GUI inside.
struct DesktopManager {
    DesktopList desktops; 
}

DesktopManager local_manager @local;
DesktopManager* gpDeskManager = &local_manager;

<*
* @param in desk "the desktop to register"
* @require desk != null
*>
fn void DesktopManager.register(&self, Desktop* _desk) @inline {
    foreach(desk : self.desktops) {
        if(desk.name == _desk.name) {
            lgr::warning(Where.CONSOLE, "Cannot register \"%s\" because is already registered.", desk.name);
            return;
        }
    }
    
    self.desktops.push(_desk);
}

<*
* @param in desk "the desktop to remove"
* @require desk != null
*>
fn void DesktopManager.unregister(&self, Desktop* _desk) @inline {
    foreach(desk : self.desktops) {
        if(desk.name == _desk.name) {
            self.desktops.remove_item(desk);
            desk = null;
            return;
        }
    }
}

fn void DesktopManager.update(&self) {
// $if $defined(PANEL_PROFILE):
    // ProfileInfo* panel_profile_info = @start_profile_zone("Panel draw");
    // defer @end_profile_zone(*panel_profile_info);
// $endif

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            if(desk.active) desk.update();
        }
    }
}

fn void DesktopManager.draw(&self, int screenWidth, int screenHeight) @inline {

// $if $defined(PANEL_PROFILE):
    // ProfileInfo* panel_profile_info = @start_profile_zone("Panel draw");
    // defer @end_profile_zone(*panel_profile_info);
// $endif

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            desk.draw(main::gpGame.time_ms);
        }
    }
}

fn void DesktopManager.free(&self) {
    if(self.desktops.len()) foreach(desk: self.desktops) desk.deinit();
    
    self.desktops.free();
}






