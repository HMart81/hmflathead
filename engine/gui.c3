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
def PanelQueue   = List(<Panel*>);
def WidgetQueue  = List(<Widget*>);
def DesktopList  = List(<Desktop*>);
// end_region

// region constants
//const bool PANEL_PROFILE = true;
const bool DEBUG_PANELS  = true;
const int MIN_PANEL_SIZE = 32;
// end_region

// region cvars
Cvar ui_debugDraw @public = { "ui_debugDraw", CvarType.BOOLEAN, "0", "show debug visualization for gui development" };

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
    typeid type;     // for easy introspection this.class == class type thing
    int id;          // used to uniquily identify each panel on a gui
    String name;
    PanelKind kind;  // this is what really diferentites all panels
    
    struct visual {
        PanelShape shape;
        Rectangle rect;
        Color color;
        Texture2D* tex;
    }
    
    struct parent {
        Desktop* desktop;
        Panel*   panel;
    }
    
    int layer;
    Flags flags;
}

fn void Panel.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Panel.reload(&self, SaveFile* file) @dynamic {
// todo
}

<*
* @param [in] panel `The panel we want to test with the mouse`
* @require panel != null
*>
fn bool isMouseOver(Panel* panel)  @local
{
    /* 
        WARNING(HM) 
        This requires conversion from "world" pos to camera pos
        or mouse overing will break if camera is zoomed or rotated
    */
    
    //Camera2D* cam        = &main::gpGame.view.camera;
    // gets windows mouse position...
    Vec2f mouseWorldPos   = rl::getMousePosition().toVec2f();
    
    // a small 32x32 pixels box
    Vec2f mouse_size      = main::getGameCursorSize();
    Rectangle mouseRect   = misc::@recFromVecs(mouseWorldPos, mouse_size);
    
    //rl::drawRectangleRec(mouseRect, rl::COLOR_RED);
    //rl::drawRectangleRec((*panel).rect, rl::COLOR_GREEN);
    
    if(rl::checkCollisionRecs(mouseRect, (*panel).visual.rect)) return true;
    
    return false;
}

fn void Panel.initRec(&self, Rectangle rect, Color color = rl::COLOR_RED) @inline {
    self.type = Panel.typeid;
    self.kind = PanelKind.BASIC;
    //
    self.visual.shape       = BOX;  // @hardcode
    self.visual.rect        = rect;
    self.visual.color       = color;
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
    if(self.visual.tex)     self.visual.tex     = null;
    if(self.bound())        self.unbind();
    if(self.parent.desktop) self.parent.desktop = null;
    if(self.parent.panel)   self.parent.panel   = null;
}

<*
* @param [in] desk "desktop where this panel will live"
* @require desk != null "Panel's require a desktop"
*>
fn void Panel.addTo(&self, Desktop* desk) @inline {
    desk.addPanel(self);
    self.flags.isInteractive = desk.isInteractive;
    self.id   = (int)desk.panels.len() + 1;
    self.name = string::tformat("%s_%s%d", desk.name, "Panel", self.id);
    self.parent.desktop = desk;
}

<*
* @param [in] parent "another panel we may be bound to"
* @require parent != null
*>
fn void Panel.bindTo(&self, Panel* other) @inline {
    if(self.bound()) {
        lgr::warning(Where.CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.id, other.id, self.parent.panel.id);
        return;
    }
    
    self.id   = other.id + 1;
    self.name = string::tformat("%s_%s_%s%d", other.parent.desktop.name, other.name, "Panel", self.id);
    
    self.flags.isInteractive = other.flags.isInteractive;
    
    // should be mostly {0, 0} but who knows...
    Vec2f desktop_origin = other.parent.desktop.rect.getPos().toVec2f();
    // our position is relative to the parent origin
    Vec2f parent_origin = desktop_origin + other.visual.rect.getPos().toVec2f();
    Vec2f offset        = parent_origin + (self.visual.rect.getPos().toVec2f() - parent_origin);
    self.visual.rect.x += offset.x;
    self.visual.rect.y += offset.y;
    //
    self.parent.panel = other;
}

fn bool Panel.bound(&self) @dynamic {
    return (self.parent.panel != null) ? true : false;
}

fn void Panel.unbind(&self) @dynamic {
    if(!self.bound()) {
        return;
    }
    
    self.parent.panel = null;
}

fn bool Panel.hidden(&self) @inline => self.flags.isHidden;

fn void Panel.update(&self) @inline {
    if(self.hidden()) return;
    
    if (isMouseOver(self)) {
        //main::lgr::info(Where.CONSOLE, "GUI: I'm over the Panel: %s", self.name);
        self.flags.asFocus = true;
    } else {
        self.flags.asFocus = false;
    }
    
    if(self.bound()) {
        // our position is relative to the parent origin
        Vec2f parent_origin = self.parent.panel.visual.rect.getPos().toVec2f();
        Vec2f offset        = parent_origin + (self.visual.rect.getPos().toVec2f() - parent_origin);
        self.visual.rect.x += offset.x;
        self.visual.rect.y += offset.y;
    }
}

fn void Panel.scale(&self, float w, float h) @inline {
    self.visual.rect.width  *= w;
    self.visual.rect.height *= h;
}

fn void Panel.setSize(&self, float w, float h) @inline {
    self.visual.rect.width  = w;
    self.visual.rect.height = h;
}

fn void Panel.setSizeV(&self, Vec2f scale) @inline {
    self.setSize(scale.x, scale.y);
}

fn void Panel.scaleV(&self, Vec2f scale) @inline {
    self.scale(scale.x, scale.y);
}

fn void Panel.scale_equaly(&self, float amount) @inline {
    self.scale(amount, amount);
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

<*
* @param in tex "texture to assign to the panel"
* @require tex != null
*>
fn void Panel.setTexture(&self, Texture2D* tex) @inline {
    self.visual.tex = tex;
    self.kind = PanelKind.IMAGE;
}

fn bool Panel.isValid(&self) @inline {
    if(self.visual.rect.x >= 0 &&
       self.visual.rect.y >= 0 &&
       self.visual.rect.width  >= MIN_PANEL_SIZE && 
       self.visual.rect.height >= MIN_PANEL_SIZE ) return true;
       
    return false;
}

fn void Panel.hide(&self) @inline {
    if(self.hidden()) return;
    self.flags.isHidden = true;
}

fn void Panel.show(&self) @inline {
    if(!self.hidden()) return;
    self.flags.isHidden = false;
}

fn Vec2f Panel.getPosition(&self) @inline {
    return {self.visual.rect.x, self.visual.rect.y};
}

fn Vec2f Panel.getSize(&self) @inline {
    return {self.visual.rect.width, self.visual.rect.height};
}

fn void Panel.draw(&self) @inline {
    if(self.flags.should_hide) return;
    
    if(ui_debugDraw.getBool()) {
        rl::drawRectangleLinesEx(self.visual.rect, 1.0f, rl::RED);
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
            assert(rl::isTextureValid(*self.visual.tex));
            Vec2f tex_size = {self.visual.tex.width, self.visual.tex.height};
            Rectangle source = {0, 0, tex_size.x, tex_size.y};
            // center of the texture (rotation/scale point), it's relative to destination rectangle dimentions, not the screen
            rl::drawTexturePro(*self.visual.tex, source, self.visual.rect, {0, 0}, 0.0f, self.visual.color);
    }
}

//////////////// ************************ ////////////////////////

// NOTE(HM) Widget is a data structure representing anything inside a gui, like buttons and such.

const DEFAULT_WIDGET_SIZE_VALUE      = 16;
const DEFAULT_WIDGET_POS_COORDINATE  = 0;

interface WidgetInterface
{
    // Desktop = place where all widgets live -> optional
    // Widget  = parent widget whe may be bound to -> optional
    // String  = name of the widget for printing
    // typeid  = the class/type of this widget
    fn void init(Desktop* desktop, typeid _type = Widget.typeid);
    fn void deinit();
    // 
    fn void initExt() @optional;
    fn void update() @optional;
    //
    fn void setBaseColor(rl::Color) @optional;
    fn void setPosition(float, float) @optional;
    fn void setPositionV(Vec2f) @optional;
    fn void setName(String) @optional;
    fn void setInteractive(bool) @optional;
    fn bool isInteractive() @optional;
    fn void setOverColor(rl::Color) @optional;
    fn void setActivatedColor(rl::Color) @optional;
    fn Desktop* getDesktop() @optional;
    fn void bindTo(Widget* other) @optional;
    fn bool bound() @optional;
    fn void unbind() @optional;
    fn void link(Widget* other) @optional;
    fn bool isLinked() @optional;
    fn bool asFocus() @optional;
    
    // callbacks
    fn void onOver()        @optional;
    fn void onStopOver()    @optional;
    fn void onPress()       @optional;
    fn void onSinglePress() @optional;
    fn void onDoublePress() @optional;
    fn void onRelease()     @optional;
    fn void onEnterKey()    @optional;
}

struct Widget (WidgetInterface) {
    // extends Panel (super/base class)
    inline Panel super;
    
    Widget* parent_widget;
    Widget* next;
}

<*
* @param in desktop "the desktop is the main area where widgets get put"
* @param in parent  "another widget we may be bound to"
* @require desktop != null
*>
fn void Widget.init(&self, Desktop* desktop, typeid _type = Widget.typeid) @dynamic {
    self.type = _type;
    self.visual.shape        = BOX;
    self.parent.desktop      = desktop;
    if(self.parent.desktop.isInteractive) self.setInteractive(true);
    
    self.id = (int)self.parent.desktop.widgets.len() + 1;
    // set name based on desktop name
    String name = "Widget";
    if(self.id < 10) {
        self.name = string::tformat("%s_%s%d", self.parent.desktop.name, name.concat("0"), self.id);
        if(self.parent_widget != null) {
            self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent_widget.name, name.concat("0"), self.id);
        }
    } else {
        self.name = string::tformat("%s_%s%d", self.parent.desktop.name, name, self.id);
        if(self.parent_widget != null) {
            self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent_widget.name, name, self.id);
        }
    }
    
    self.visual.color = rl::WHITE; // @hardcode
    self.visual.tex   = null;
    // position is relative to desktop origin
    Vec2f desktop_origin = self.parent.desktop.rect.getPos().toVec2f();
    self.visual.rect  = {
    desktop_origin.x + DEFAULT_WIDGET_POS_COORDINATE, 
    desktop_origin.y + DEFAULT_WIDGET_POS_COORDINATE, 
    DEFAULT_WIDGET_SIZE_VALUE, 
    DEFAULT_WIDGET_SIZE_VALUE
    };
    self.parent.desktop.addWidget(self);
}

fn void Widget.deinit(&self) @dynamic {
    if(self.visual.tex)     self.visual.tex     = null;
    if(self.parent_widget)  self.parent_widget  = null;
    if(self.parent.desktop) self.parent.desktop = null;
    if(self.parent.panel)   self.parent.panel   = null;
    if(self.next)           self.next = null;
}

fn void Widget.setPosition(&self, float x, float y) @dynamic @inline {
    self.visual.rect.x = x;
    self.visual.rect.y = y;
}

fn void Widget.setPositionV(&self, Vec2f pos) @dynamic @inline {
    self.setPosition(pos.x, pos.y);
}

fn void Widget.updatePos(&self) @inline @local {
    if(self.bound()) {
        Vec2f parent_origin = self.parent_widget.visual.rect.getPos().toVec2f();
        Vec2f our_origin    = self.visual.rect.getPos().toVec2f();
        Vec2f offset        = parent_origin + (our_origin - parent_origin);
        self.setPositionV(offset);
    }
}

<*
* @param in other "parent widget"
* @require other != null
* @require self.parent_widget == null
*>
fn void Widget.bindTo(&self, Widget* other) @dynamic {
    if(self.bound()) {
        lgr::warning(Where.CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.id, other.id, self.parent_widget.id);
        return;
    }
    
    self.parent_widget = other;
    // our position is relative to the parent origin both are relative to the desktop origin
    self.updatePos();
}

fn void Widget.link(&self, Widget* other) @dynamic {
    if(other == null) return;
    
    if(self.isLinked()) {
        lgr::warning(Where.CONSOLE, "Cannot link %s to %s because is already linked to %s.", self.id, other.id, self.next.id);
        return;
    }
    
    self.next = other;
}

fn bool Widget.bound(&self) @dynamic {
    return (self.parent_widget != null) ? true : false;
}

fn void Widget.unbind(&self) @dynamic {
    if(!self.bound()) {
        return;
    }
    
    self.parent_widget = null;
}

fn void Widget.update(&self) @dynamic {
    self.updatePos();
}

fn bool Widget.isLinked(&self) @dynamic {
    return (self.next != null) ? true : false;
}

fn Desktop* Widget.getDesktop(&self) @dynamic {
    return self.parent.desktop;
}

fn void Widget.setName(&self, String name) @dynamic {
    self.name = name;
}

fn void Widget.setInteractive(&self, bool choice) @inline  @dynamic {
    self.flags.isInteractive = choice;
}

fn bool Widget.isInteractive(&self) @inline @dynamic {
    return self.flags.isInteractive;
}

fn void Widget.setBaseColor(&self, rl::Color color) @inline @dynamic{
    self.visual.color = color;
}

fn void Widget.onOver(&self) @inline @dynamic {
    if (self.isInteractive() == false) return;
    self.flags.asFocus = true;
}

fn void Widget.onStopOver(&self) @inline @dynamic {
    if (self.isInteractive() == false) return;
    self.flags.asFocus = false;
}

fn bool Widget.asFocus(&self) @inline @dynamic {
    return self.flags.asFocus;
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
    int font_size;
    Color text_color;
    WidgetTextAlign align;
}

<*
* @param in desk "desktop where this widget will live"
* @require desk != null
*>
fn void WidgetText.init(&self, Desktop* desk, typeid _type = WidgetText.typeid) @inline {
    self.super.init(desk, _type);
    self.font_size = 20; //@hardcode
    self.text_color = rl::WHITE; //@hardcode
    self.align = WidgetTextAlign.CENTER;
}

fn void WidgetText.deinit(&self) @inline {
    self.super.deinit();
}

fn void WidgetText.setText(&self, String text) @inline {
    self.text = text;
}

fn void WidgetText.setTextColor(&self, Color color) @inline {
    self.text_color = color;
}

fn void WidgetText.setAlign(&self, WidgetTextAlign align) @inline {
    self.align = align;
}

fn void WidgetText.setFontSize(&self, int size) @inline {
    self.font_size = size;
}

fn void WidgetText.draw(&self) @inline {
    if (self.hidden()) return;

    switch (self.align)
    {
    case CENTER:
        rl::drawText(self.text.zstr_tcopy(), (int)self.visual.rect.x + (int)self.visual.rect.width / 2, (int)self.visual.rect.y + (int)self.visual.rect.height / 2, self.font_size, self.text_color);
    case LEFT:
        rl::drawText(self.text.zstr_tcopy(), (int)self.visual.rect.x, (int)self.visual.rect.y, self.font_size, self.text_color);
    case RIGHT:
        rl::drawText(self.text.zstr_tcopy(), (int)self.visual.rect.x + (int)self.visual.rect.width, (int)self.visual.rect.y, self.font_size, self.text_color);
    }
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
fn void WidgetButton.init(&self, Desktop* desk, typeid _type = WidgetButton.typeid) @inline {
    self.super.init(desk, _type);
    self.setDefaultColor(rl::WHITE); //@hardcode
    self.setBaseColor(self.default_color);
    self.setOverColor(rl::RED); //@hardcode
    self.setPressedColor(rl::GREEN); //@hardcode
    self.setActivatedColor(rl::BLUE); //@hardcode
    self.setSound(&main::gpGame.default_sound); //@hardcode todo give this a better sound
}

fn void WidgetButton.deinit(&self) @inline {
    self.super.deinit();
    if (self.interaction_sound) self.interaction_sound = null;
}

fn void WidgetButton.setDefaultColor(&self, Color color)   @inline => self.default_color   = color;
fn void WidgetButton.setOverColor(&self, Color color)      @inline => self.over_color      = color;
fn void WidgetButton.setPressedColor(&self, Color color)   @inline => self.pressed_color   = color;
fn void WidgetButton.setActivatedColor(&self, Color color) @inline => self.activated_color = color;

fn void WidgetButton.setSound(&self, Sound* sound) @inline {
    self.interaction_sound = sound;
}

fn void WidgetButton.onOver(&self) @inline {
    if (self.isInteractive() == false) return;

    self.super.onOver();
    self.setBaseColor(self.over_color);
}

fn void WidgetButton.onStopOver(&self) @inline {
    if (self.isInteractive() == false) return;

    self.super.onStopOver();
    self.setBaseColor(self.default_color);
}

// while the button is kept pressed
fn void WidgetButton.onPress(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;
    if (self.pressed == false) {
        self.setBaseColor(self.pressed_color);

        if (rl::isSoundValid(*self.interaction_sound)) {
            rl::playSound(*self.interaction_sound);
        }
    }
    self.pressed = true;
    self.press_count++;
}

fn void WidgetButton.onSinglePress(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;

    if (rl::isSoundValid(*self.interaction_sound)) {
        rl::playSound(*self.interaction_sound);
    }
    self.setBaseColor(self.pressed_color);
}

fn void WidgetButton.onRelease(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.setBaseColor(self.default_color);
    self.pressed = false;
    self.press_count = 0;
}

fn void WidgetButton.onEnterKey(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.onSinglePress();
}


fn void WidgetButton.manage_interactions(&self) @local{
    if (self.isInteractive() == false) return;

    //main::lgr::info(Where.CONSOLE, "Gui: I'm over button: %s", self.name);
    if (isMouseOver((Panel*)self)) {
        self.onOver();
    } else {
        self.onStopOver();
    }

    if (rl::isMouseButtonDown(MouseButton.LEFT)) {
        //main::lgr::info(Where.CONSOLE, "Gui: I'm pressing button: %s", self.name);
        self.onPress();
    }

    // pressed once
    if (rl::isMouseButtonDown(MouseButton.LEFT) && self.press_count == 0) {
        self.onSinglePress();
    }

    if (rl::isMouseButtonReleased(MouseButton.LEFT)) {
        self.onRelease();
    }

    if (rl::isKeyPressed(rl::KEY_ENTER) && !rl::isKeyPressedRepeat(rl::KEY_ENTER)) {
        self.onEnterKey();
    }
}

fn void WidgetButton.update(&self)
{
    
    // NOTE(HM) still so much to learn about OOP...
    // I need to manully call the root widget update,
    // that is the update method from the super class Panel 
    // for the focus code to work
    //self.update(); // for isMouseOver to run...
    //
    self.manage_interactions();
}

/**
    GUI creation process:
    
    - Create a gui Desktop
    gui::Desktop main_menu;
    - init the Desktop
    main_menu.ini(...);
    - create any extra children panels
    - and add them to the respective parent Desktop
    gui::Panel main_menu_button;
    main_menu_button.initRec(..., &main_menu);
**/

struct Desktop (SaveSystemInterface) {
    // id
    typeid type;
    String name;
    
    // visuals
    Rectangle rect;
    Color color;
    Texture2D* tex;
    //
    
    // flags
    bool isInteractive;
    bool asFocus;
    bool visible;
    //
    
    // Lists
    PanelQueue panels;
    // todo make a PanelQueue for hidden panels to better control what to hide and show, 
    // when hidding or showing the desktop
    WidgetQueue widgets;
    // todo make a WidgetQueue for hidden Widgets to better control what to hide and show
    // when hidding or showing the desktop
}

fn void Desktop.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Desktop.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void Desktop.init(&self, String name, RColor color = rl::WHITE, Texture2D* tex = null, typeid _type = Desktop.typeid) @inline {
    self.type = _type;
    self.name = string::tformat("Desktop_%s", name);
    //
    //
    self.rect = Rectangle {
        .x      = 0,
        .y      = 0, 
        .width  = main::gpGame.screen.w,
        .height = main::gpGame.screen.h,
    };
    
    self.color       = color;
    if(tex) self.tex = tex;
    //
    self.isInteractive = true;
    self.asFocus       = true;
    self.visible       = true;
    
    Desktop* this = self;
    local_manager.register(this);
}

// delete all down to the basic desktop
fn void Desktop.clear(&self) @inline {
    if(self.panels.len()) {
        foreach(child: self.panels) if(child) child.deinit();
    }
    
    if(self.widgets.len()) {
        foreach(child: self.widgets) if(child) child.deinit();
    }
}

fn void Desktop.deinit(&self) @inline {
    self.clear();
    // last clear ourself
    self.name        = "";
    self.rect        = {};
    self.color       = {};
    if(self.tex) self.tex = null;
    
    Desktop* this = self;
    local_manager.unregister(this);
}

fn bool Desktop.hidden(&self) @inline => !self.visible;

fn void Desktop.setFocus(&self, bool choice) @inline {
    self.asFocus = choice;
}

fn void Desktop.update(&self) {
    if(self.hidden()) return;
    
    if(self.panels.len()) {
        foreach_r (panel: self.panels) {
            panel.update();
        }
    }
    
    if(self.widgets.len()) {
        foreach_r (widget : self.widgets) {
            switch {
                //case widget.type == WidgetButton.typeid:
                //  ((WidgetButton*)widget).update();
                default:
                    widget.update();
            }
        }
    }
}

fn void Desktop.hide(&self) {
    if(self.hidden()) return;
    
    self.visible = false;
    
    // hide children
    
    if(self.panels.len()) {
        foreach_r (panel: self.panels) {
            panel.hide();
        }
    }
    
    if(self.widgets.len()) {
        foreach_r (widget : self.widgets) {
            switch {
                //case widget.type == WidgetButton.typeid:
                //  ((WidgetButton*)widget).hide();
                default:
                    widget.hide();
            }
        }
    }
}

fn void Desktop.show(&self) {
    if(!self.hidden()) return;
    
    self.visible = true;
    
    // todo find a way to only show certain children not all
    
    if(self.panels.len()) {
        foreach_r (panel: self.panels) {
            panel.show();
        }
    }
    
    if(self.widgets.len()) {
        foreach_r (widget : self.widgets) {
            switch {
                //case widget.type == WidgetButton.typeid:
                //  ((WidgetButton*)widget).show();
                default:
                    widget.show();
            }
        }
    }
}

fn void Desktop.draw(&self)  {
    if(self.hidden()) return;
    
    $if $defined(DEBUG_PANELS):
        rl::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
    $endif
    
    if(self.tex) {
        assert(rl::isTextureValid(*self.tex));
        rl::drawTexture(*self.tex, (int)self.rect.x, (int)self.rect.y, self.color);
    } else {
        misc::@drawRect(self.rect, self.color);
    }
    
    // now handle our data
    if(self.panels.len()) {
        foreach_r (panel: self.panels) {
            panel.draw();
        }
    }
    
    if(self.widgets.len()) {
        foreach_r(widget : self.widgets) {
            switch {
                //case widget.type == WidgetButton.typeid:
                //  ((WidgetButton*)widget).draw();
                default:
                    widget.draw();
            }
        }
    }
    
}

fn void Desktop.addPanel(&self, Panel* child) @inline {
    self.panels.push(child);
}

fn void Desktop.addWidget(&self, Widget* child) @inline {
    self.widgets.push(child);
}

// NOTE(HM) TODO(HM) Rename to MenuOS?
// Every user GUI should have at lest one Desktop,
// is a data structure to put everything that makes up a user GUI inside.
struct DesktopManager {
    DesktopList desktops;
}

DesktopManager local_manager @local;
DesktopManager* gpManager = &local_manager;

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

fn void DesktopManager.draw(&self, int screenWidth, int screenHeight) @inline {

$if $defined(PANEL_PROFILE):
    ProfileInfo* panel_profile_info = @start_profile_zone("Panel draw");
    defer @end_profile_zone(*panel_profile_info);
$endif

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            desk.draw();
        }
    }
}

fn void DesktopManager.free(&self) {
    if(self.desktops.len()) foreach(desk: self.desktops) desk.deinit();
    
    self.desktops.free();
}






