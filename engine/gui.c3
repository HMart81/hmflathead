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

// region defines
def assetManager = astmng::assetManager @private;
// end_region

// region constants
//const bool PANEL_PROFILE = true;
const bool DEBUG_PANELS  = true;
const int MIN_PANEL_SIZE = 32;
// end_region

// region cvars
Cvar ui_debugDraw @public = { "ui_debugDraw", CvarType.BOOLEAN, "1", "show debug visualization for gui development" };

fn void register_cvars() @public {
    cvar::@register(&ui_debugDraw);
}
// end_region

struct Flags {
    union {
        bool isHidden;
        bool should_hide;
    }
    bool isInteractive;
    bool asFocus;
}

enum PanelShape {
    BOX,
    ROUNDED_BOX
}

enum PanelKind {
    BASIC,
    IMAGE
}

/////////////////////////////////// ************** /////////////////////////

// NOTE(HM) Panel is a data representing a big square or image, 
// used for background images or single color rectangles...
struct Panel (SaveSystemInterface)
{
    PanelKind kind;
    Flags flags;
    
    struct visual {
        PanelShape shape;
        Rectangle rect;
        Color color;
        Texture2D* tex;
    }
    
}

fn void Panel.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Panel.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void Panel.initRec(&self, Rectangle rect, Color color = rl::COLOR_RED) @inline {
    self.kind         = PanelKind.BASIC;
    self.visual.shape = BOX;  // @hardcode
    self.visual.rect  = rect;
    self.visual.color = color;
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
    self.hide();
    if(self.visual.tex)     self.visual.tex = null;
}

/*
<*
* @param [in] desk "desktop where this panel will live"
* @require desk != null "Panel's require a desktop"
*>
fn void Panel.addTo(&self, Desktop* desk) @inline {
    desk.addChild(any_make(self, Panel.typeid));
    self.flags.isInteractive = desk.isInteractive;
    self.id                  = (int)desk.children.len() + 1;
    self.name                = string::tformat("%s_%s%d", desk.name, "Panel", self.id);
    self.parent.desktop      = desk;
}
*/

fn bool Panel.hidden(&self) @inline => self.flags.isHidden;


//    WARNING(HM)
//    If the 2D camera view is changed in any way besides moving in x and y
//    like if the camera is zoomed or the camera is rotated, this will break.
//    If so it will require conversion from world space coordinates to camera space.
fn bool Panel.isMouseOver(&self)
{
    if (self.hidden()) return false;

    // gets windows mouse position...
    Vec2f mouseWorldPos = rl::getMousePosition().toVec2f();

    // a small 32x32 pixels box
    Vec2f mouse_size = main::getGameCursorSize();
    Rectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_size);

    if (rl::checkCollisionRecs(mouseRect, self.visual.rect)) return true;

    return false;
}

fn void Panel.setShape(&self, PanelShape shape) @inline => self.visual.shape = shape;

fn bool Panel.asFocus(&self) @inline => self.flags.asFocus;

fn void Panel.scale(&self, float w, float h) @inline {
    self.visual.rect.width  *= w;
    self.visual.rect.height *= h;
}

fn void Panel.scaleV(&self, Vec2f scale) @inline {
    self.scale(scale.x, scale.y);
}

fn void Panel.scale_equaly(&self, float amount) @inline {
    self.scale(amount, amount);
}

fn void Panel.setSize(&self, float w, float h) @inline {
    self.visual.rect.width  = w;
    self.visual.rect.height = h;
}

fn void Panel.setSizeV(&self, Vec2f scale) @inline {
    self.setSize(scale.x, scale.y);
}

fn Vec2f Panel.getSize(&self) @inline {
    return { self.visual.rect.width, self.visual.rect.height };
}

fn float Panel.getWidth(&self) @inline {
    return self.visual.rect.width;
}

fn float Panel.getHeight(&self) @inline {
    return self.visual.rect.height;
}

fn void Panel.setPosition(&self, float x, float y) @inline {
    self.visual.rect.x = x;
    self.visual.rect.y = y;
}

fn void Panel.setPositionV(&self, Vec2f pos) @inline {
    self.setPosition(pos.x, pos.y);
}

fn void Panel.addToPosition(&self, float x, float y) @inline {
    self.visual.rect.x += x;
    self.visual.rect.y += y;
}

fn void Panel.addToPositionV(&self, Vec2f pos) @inline {
    self.addToPosition(pos.x, pos.y);
}

fn Vec2f Panel.getPosition(&self) @inline {
    return { self.visual.rect.x, self.visual.rect.y };
}

<*
* @param in tex "texture to assign to the panel"
* @require tex != null
*>
fn void Panel.setTexture(&self, Texture2D* tex) @inline {
    self.visual.tex = tex;
    self.kind = PanelKind.IMAGE;
}

fn bool Panel.asTexture(&self) @inline => self.visual.tex != null;

fn bool Panel.isValid(&self) @inline {
    if(self.visual.rect.width  >= MIN_PANEL_SIZE && 
       self.visual.rect.height >= MIN_PANEL_SIZE ) return true;
       
    return false;
}

fn bool Panel.isWithinScreenBounds(&self) {
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

    return rl::checkCollisionRecs(screen_bounds, self.visual.rect) ? true : false;
}

fn void Panel.hide(&self) @inline {
    if(self.hidden()) return;
    self.flags.isHidden = true;
}

fn void Panel.show(&self) @inline {
    if(!self.hidden()) return;
    self.flags.isHidden = false;
}

fn void Panel.update(&self) {
    if(self.hidden()) return;

    if (self.isMouseOver()) {
        self.flags.asFocus = true;
    } else {
        self.flags.asFocus = false;
    }
}

fn void Panel.draw(&self) {
    if(self.hidden()) return;
    
    if(ui_debugDraw.getBool()) {
        rl::drawRectangleLinesEx(self.visual.rect, 2.0f, rl::RED);
    }
    
    switch (self.kind) {
        case BASIC:
            if(self.visual.shape == BOX) {
                misc::@drawRect(self.visual.rect, self.visual.color);
            } else if(self.visual.shape == ROUNDED_BOX) {
                rl::drawRectangleRounded(self.visual.rect, 0.65f, 6, self.visual.color);
            }
        case IMAGE:
            // TODO(HM) find how to draw a image on a rounded rectangle!?
            $if $feature(_DEBUG) :
                assert(self.asTexture() == true);
            $endif
            if (rl::isTextureValid(*self.visual.tex)) {
                Vec2f tex_size = {self.visual.tex.width, self.visual.tex.height};
                Rectangle source = {0, 0, tex_size.x, tex_size.y};
                // NOTE(HM) 
                // center of the texture (rotation/scale point), it's relative to destination rectangle dimentions, not the screen
                rl::drawTexturePro(*self.visual.tex, source, self.visual.rect, {0, 0}, 0.0f, self.visual.color);
            }
    }
}

//////////////// ************************ ////////////////////////

// NOTE(HM) Widget is a data structure representing anything inside a gui, like buttons and such.

def WidgetCallback = fn void(Widget*);

interface WidgetInterface
{
    fn void init();
    fn void initExt() @optional;
    fn void deinit();
    fn void update();
    fn void draw();
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

struct Widget (WidgetInterface) {
    // extends Panel (super/base class)
    inline Panel super;
    
    int id;  // used to uniquily identify each widget on a gui
    String name;
    int layer;
    int kind;

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
    self.super.update();
    
    if(self.hidden()) return;
     
    if(self.bound()) {
        // if bound our position is updated to always be relative to the parent origin
        Vec2f parent_origin = self.parent.other.getPosition();
        Vec2f old_offset    = self.getPosition() - parent_origin;
        Vec2f new_offset    = parent_origin + old_offset;
        self.setPositionV(new_offset);
    }
}

fn void Widget.draw(&self) @dynamic {
    self.super.draw();
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
        name.concat("_Widget");
    }
    
    if (self.id < 10) {
        self.name = string::tformat("%s_%s%d", self.parent.desktop.name, name.concat("0"), self.id);
        if (self.bound()) {
            self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.name, name.concat("0"), self.id);
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
    self.super.visual.color = color;
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
            self.visual.rect.x + self.visual.rect.width / 2,
            self.visual.rect.y + self.visual.rect.height / 2
        };
        center.x -= (float)(self.text_len / 2);
        center.y -= (float)self.font_size / 2;
    case LEFT:
        center = {
            self.visual.rect.x,
            self.visual.rect.y
        };
    case RIGHT:
        center = {
            self.visual.rect.x + self.visual.rect.width,
            self.visual.rect.y
        };
        center.x -= self.text_len;
    }
    
    rl::drawText(text, (int)center.x, (int)center.y, self.font_size, self.text_color);
    
    if(ui_debugDraw.getBool()) {
       rl::drawCircle((int)center.x, (int)center.y, 1.0f, rl::RED);
    }
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
        name.concat("_Label");
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
        name.concat("_Button");
    }
    button.addTo(menu, name);
    return button;
}


//////////////////////////////////// DESKTOP //////////////////////////////////////

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
*/

def ChildrenQueue = List(<Widget*>);

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
    // to handle timing while the menu is open/active
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
fn void Desktop.clear(&self) @inline {
    if (self.children.len()) {
        foreach(child: self.children) {
            switch (child.kind) {
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

fn void Desktop.update(&self) {
    if(self.hidden()) return;
    
    if (self.children.len()) {
        foreach(child: self.children) {
            switch (child.kind) {
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

fn void Desktop.hide(&self) {
    if(self.hidden()) return;
    
    self.visible = false;

    // hide children
    
    if (self.children.len()) {
        foreach(child: self.children) {
           switch (child.kind) {
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


//////////////////////////////////// DESKTOP MANAGER //////////////////////////////////////

def DesktopList = List(<Desktop*>);

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






