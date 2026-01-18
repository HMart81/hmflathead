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

/*
    TODO:
        A ingame gui edit mode for easy placement of widgets
        Perhaps even create a simple gui editor using raygui buttons and such...
*/

// region modules
import std::io;
import std::core::mem; // for malloc
import std::math;
import std::collections::list;
import engine::misc;
import engine::input;
//import engine::assets::astmng; // asset manager
import game::material::mat;
import game::material::manager::mtrmng;
import engine::logging::log;
import game::main;
import game::camview;
import game::actors::ent;
import game::serialize::svs; // save system
import engine::sys::cvar;
import thirdparty::raylib5::rl;
import thirdparty::raygui5::rgui;
import engine::sys::render2d::r2d; // 2D rendering
// end_region

// region cvars
Cvar ui_debugDraw @public = { "ui_debugDraw", CvarType.BOOL, "0", "show debug visualization for gui development, 0, 1, true, false" };
Cvar ui_editGui   @public = { "ui_editGui", CvarType.BOOL, "0", "turn on gui editing functionality for gui development, 0, 1, true, false" };


fn void register_cvars() @public 
{
    cvar::@register(&ui_debugDraw);
    cvar::@register(&ui_editGui);
}
// end_region


///////////////////////////////////////////////////////////////////////////
/*                                PANEL

    NOTE(HM) Panel is a simple data structure representing a big square or image, 
    used for background images or single color rectangles.
*/
///////////////////////////////////////////////////////////////////////////

// #region constants
//const bool PANEL_PROFILE = true;
const bool DEBUG_PANELS   = true;
const int  MIN_PANEL_SIZE = 32;

// mostly for the panel texture inversion ability
const uint HORIZONTAL_DIR = 1;
const uint VERTICAL_DIR   = 2;
// #endregion

enum PanelShape : const inline int
{
    BOX,
    ROUNDED_BOX
}

struct PanelFlags
{
    bool isHidden;
    bool isActive;
    // right now in focus and mouse over, mean the same thing 
    // but in the future we could have a system where they are seperate, 
    // you have a widget marked in focus but the mouse pointer not ontop of it.  
    bool inFocus;
    bool capture; // used to know if the panel is capturing mouse input
    bool isDestroyed; // used to mark panels that are being destroyed
    bool showBounds; // used to debug the panel bounds
}

struct Panel (SaveSystemInterface, Printable)
{
    int id;  // used to uniquily identify each panel
    String name;
    PanelFlags flags;
    PanelShape shape; // default is BOX
    RLRectangle  rect; // x, y, width, height
    RLColor      color; // material color overrides this color
    RLColor      color_selected; // for gui editor functionality
    HMaterial* mat;
}

fn void Panel.save(&self, SaveFile* file) @dynamic 
{
    svs::writeInt(file, self.shape);
    svs::writeRect(file, self.rect);
    svs::writeColor(file, self.color);
    svs::writeColor(file, self.color_selected);
    // cannot save pointers so just save the material name
    svs::writeString(file, (self.mat != null) ? self.mat.name : "");
}

fn void Panel.reload(&self, SaveFile* file) @dynamic 
{
    int value;
    svs::readInt(file, &value);
    self.shape = (PanelShape)value;
    svs::readRect(file, &self.rect);
    svs::readColor(file, &self.color);
    svs::readColor(file, &self.color_selected);
    String mat_name;
    svs::readString(file, &mat_name);
    self.mat = mtrmng::getMaterial(mat_name);
}

fn usz? Panel.to_format(&self, Formatter* f) @dynamic 
{
    return f.printf(`Panel { 
    "id" = %s,\n"name" = %s,\n"shape" = %s,\n"rect" = { x: %s, y: %s, width: %s, height: %s  },\n"color" = { r: %s, g: %s, b: %s, a: %s  },\n"material" = %s 
    }`, self.id, self.name, self.shape, self.rect.x, self.rect.y, self.rect.width, self.rect.height, self.color.r, self.color.g, self.color.b, self.color.a, (self.mat != null) ? self.mat.name : "null");
}

fn void Panel.initRec(&self, RLRectangle rect, RLColor color) @inline
{
    self.rect  = rect;
    self.color = color;
}

fn void Panel.initV(&self, Vec2f pos, Vec2f size, RLColor color) @inline
{
    self.initRec({pos.x, pos.y, size.x, size.y}, color);
}

fn void Panel.init(&self) @inline
{
    self.initRec({0, 0, MIN_PANEL_SIZE, MIN_PANEL_SIZE}, rl::WHITE);
}

fn void Panel.deinit(&self) @inline 
{ 
    if(self.mat) self.mat = null;
}

fn void Panel.setShape(&self, PanelShape shape) @inline => self.shape = shape;

<*
    Todo(HM) Make a way to select or view pannels with very low sizes or huge sizes

    @param w_scaler : "value to scale the panel horizontally, from 0.05f to INF"
    @param h_scaler : "value to scale the panel verticaly, from 0.05f to INF"
    @require w_scaler >= 0.05f && h_scaler >= 0.05f
*>
fn void Panel.scale(&self, float w_scaler, float h_scaler) @inline 
{
    if( w_scaler >= 0.05f && w_scaler < 0.06f &&
        h_scaler >= 0.05f && h_scaler < 0.06f )
    {
        log::warning(FILE, "scaled a panel to almost invisible size! Was that desired?");
    }

    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
}

<*
    @param scale : "vector to scale the panel with, from 0.05f to INF"
    @require scale.x >= 0.05f && scale.y >= 0.05f
*>
fn void Panel.scaleV(&self, Vec2f scale) @inline => self.scale(scale.x, scale.y);

<*
    @param amount : "value to scale equaly both coordinates with, from 0.05f to INF"
    @require amount >= 0.05f
*>
fn void Panel.scale_equaly(&self, float amount) @inline => self.scale(amount, amount);

<*
    @param w_scaler : "value to scale x coordinate with"
    @param h_scaler : "value to scale y coordinate with"
    @require w_scaler >= 0.05f && w_scaler <= 1.0f
    @require h_scaler >= 0.05f && h_scaler <= 1.0f
*>
fn void Panel.scaleNormalized(&self, float w_scaler, float h_scaler) @inline 
{
    float x, y;
    x = math::clamp(w_scaler, 0.05f, 1.0f);
    y = math::clamp(h_scaler, 0.05f, 1.0f);
    /*
    if(w_scaler < 0.05f) { w_scaler = 0.05f; }
    else if(w_scaler > 1.0f) { w_scaler = 1.0f; }

    if(h_scaler < 0.05f) { h_scaler = 0.05f; }
    else if(h_scaler > 1.0f) { h_scaler = 1.0f; }
    */

    self.rect.width  *= x;
    self.rect.height *= y;
}

<*
    Sets the size of the Panel, units is in pixels.
*>
fn void Panel.setSize(&self, float w, float h) @inline 
{
    self.rect.width  = w;
    self.rect.height = h;
}

<*
    Sets the size of the Panel, vector units is in pixels.
*>
fn void Panel.setSizeV(&self, Vec2f scale) @inline => self.setSize(scale.x, scale.y);

<*
    gets the size of the Panel, units is in pixels.
*>
fn Vec2f Panel.getSize(&self) @inline => { self.rect.width, self.rect.height };

<*
    gets the width of the Panel, units is in pixels.
*>
fn float Panel.getWidth(&self) @inline => self.rect.width;

<*
    gets the height of the Panel, units is in pixels.
*>
fn float Panel.getHeight(&self) @inline => self.rect.height;

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
fn void Panel.setPositionV(&self, Vec2f pos) @inline => self.setPosition(pos.x, pos.y);

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
fn void Panel.addToPositionV(&self, Vec2f pos) @inline => self.addToPosition(pos.x, pos.y);

<*
    gets current position of the Panel, vector units is in pixels.
*>
fn Vec2f Panel.getPosition(&self) @inline => { self.rect.x, self.rect.y };
<*
    gets current X position of the Panel, units is in pixels.
*>
fn float Panel.getX(&self) => self.rect.x;
<*
    gets current Y position of the Panel, units is in pixels.
*>
fn float Panel.getY(&self) => self.rect.y;

fn void Panel.setMaterial(&self, String material_name) @inline 
{
    self.mat = mtrmng::getMaterial(material_name);
}

fn bool Panel.hasMaterial(&self) @inline => self.mat != null;

fn void Panel.fadeIn(&self, float factor) {
    /*if(self.hasMaterial())
    {
        self.mat.
    } else {*/
        //self.color = rl::colorLerp(self.color, rl::WHITE, factor);
        self.color.a = (char)misc::move_toward(self.color.a, 255.0f, factor);
    //}
}

fn void Panel.fadeOut(&self, float factor) {
    //self.color = rl::colorLerp(self.color, misc::INVISIBLE_COLOR, factor);
    //self.color.a = math::lerp(self.color.a, 0, factor);
    self.color.a = (char)misc::move_toward(self.color.a, 0, factor);
}

fn bool Panel.isValid(&self) @inline {
    if(self.rect.width  >= MIN_PANEL_SIZE && 
       self.rect.height >= MIN_PANEL_SIZE ) return true;
       
    return false;
}

fn void Panel.hide(&self) @inline {
    if(self.hidden()) return;
    self.flags.isHidden = true;
    self.deactivate();
}

fn void Panel.show(&self) @inline {
    if(!self.hidden()) return;
    self.flags.isHidden = false;
    self.activate();
}

fn void Panel.debugBounds(&self, bool choice) @inline {
    self.flags.showBounds = choice;
}

fn bool Panel.displayBounds(&self) @inline {
    return self.flags.showBounds;
}

fn bool Panel.hidden(&self)  @inline => self.flags.isHidden;

fn void Panel.activate(&self) @inline {
    if(self.flags.isActive) return;
    self.flags.isActive = true;
}

fn void Panel.deactivate(&self) @inline {
    if(!self.flags.isActive) return;
    self.flags.isActive = false;
}

fn bool Panel.active(&self)  @inline => self.flags.isActive;

fn bool Panel.active_visible_infocus(&self) @inline => (self.active() && !self.hidden() && self.asFocus());

//    WARNING(HM)
//    If the 2D camera view is changed in any way besides moving in x and y
//    like if the camera is zoomed or the camera is rotated, this will break.
//    If so it will require conversion from world space coordinates to camera space.
fn bool Panel.isMouseOver(&self)
{
    if (!self.active() || self.hidden() || guieditor::as_focus() || main::gpGame.showMessageBox) return false;

    // gets windows mouse position...
    Vec2f mouseWorldPos = rl::getMousePosition();

    Vec2f mouse_size = main::getGameCursorSize() * 0.5f; // half size of the cursor
    RLRectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_size);

    if (rl::checkCollisionRecs(mouseRect, self.rect)) return true;

    return false;
}

fn bool Panel.asFocus(&self)  @inline => self.flags.inFocus;

fn void Panel.update(&self) 
{
    if((guieditor::enabled() && guieditor::as_focus()) || main::gpGame.show_microui_test_frames)
    {
       return; // do not update panels when in editor mode
    }

    if(!self.active() || self.hidden()) return;

    self.flags.inFocus = self.isMouseOver();
}

fn void Panel.draw(&self, bool selected = false)
{
    if(self.hidden()) return;

    if(self.hasMaterial())
    {
        // TODO(HM) find how to draw a image on a rounded rectangle!?

        RLTexture2D* texture = self.mat.getTexture(mat::STAGE_DIFFUSE);
        Vec2f texture_size = { texture.width, texture.height };
        RLRectangle source = { 0, 0, texture_size.x, texture_size.y };
        RLRectangle* dist = &self.rect;

        RLColor color = (selected) ? self.color_selected : self.mat.getStage(mat::STAGE_DIFFUSE).color;

        RLBlendMode blending;
        Coverage coverage = self.mat.coverage;
        switch //
        {
            case (bool)(coverage & mat::COVERAGE_OPAQUE): 
                break; // do nothing here
            case (bool)(coverage & mat::COVERAGE_PERFORATED) && (bool)(coverage & ~mat::COVERAGE_TRANSLUCENT):
                blending = RLBlendMode.ALPHA;
            case (bool)(coverage & mat::COVERAGE_TRANSLUCENT) && (bool)(coverage & ~mat::COVERAGE_PERFORATED):
                blending = RLBlendMode.ALPHA_PREMUL;
                if(color.a == 255) // if the color is opaque
				{
					color.a = 128; // half transparent
					float r = misc::@mapValueRangeToOther(color.r, 0, 255, 0.0f, 1.0f);
					float g = misc::@mapValueRangeToOther(color.g, 0, 255, 0.0f, 1.0f);
					float b = misc::@mapValueRangeToOther(color.b, 0, 255, 0.0f, 1.0f);
					float a = misc::@mapValueRangeToOther(color.a, 0, 255, 0.0f, 1.0f);

					color.r = (char)math::floor((r * a) * 255);
					color.g = (char)math::floor((g * a) * 255);
					color.b = (char)math::floor((b * a) * 255);
				}
            case (bool)(coverage & mat::COVERAGE_PERFORATED) && (bool)(coverage & mat::COVERAGE_TRANSLUCENT):
                    blending = RLBlendMode.CUSTOM_SEPARATE; // use the custom blending mode
            /*case (bool)(self.mat.coverage & (mat::COVERAGE_PERFORATED | mat::COVERAGE_TRANSLUCENT)):
                blending = RLBlendMode.CUSTOM; // custom blending mode*/
            case (bool)(coverage & mat::COVERAGE_BAD):
                log::error(FILE, "Panel with material %s has a bad material coverage type.", self.mat.name);
                unreachable();
        }

        switch (blending)
        {
            case RLBlendMode.ALPHA:
            case RLBlendMode.ALPHA_PREMUL:
                rl::@blendMode(blending)
                {
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                };
            case RLBlendMode.CUSTOM:
                rl::setBlendFactors(rl::RL_ONE, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_FUNC_ADD);
                rl::setBlendMode(rl::RLBlendMode.CUSTOM);
                rl::@blendMode(blending)
                {
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                };
            case RLBlendMode.CUSTOM_SEPARATE:
                rl::setBlendFactorsSeparate(rl::RL_SRC_ALPHA, rl::RL_ONE_MINUS_SRC_ALPHA, rl::RL_ONE, rl::RL_ONE, rl::RL_FUNC_ADD, rl::RL_MAX);
                rl::setBlendMode(rl::RLBlendMode.CUSTOM_SEPARATE);
                rl::@blendMode(blending)
                {
                    // NOTE(HM) center of the texture (rotation/scale point), 
                    // it's relative to destination rectangle dimentions, not the screen dimentions.
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                };
            default: // opaque unless the image has invisible pixels...
                // NOTE(HM) center of the texture (rotation/scale point), 
                // it's relative to destination rectangle dimentions, not the screen dimentions.
                rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
        }
    } 
    else
    {
        switch(self.shape)
        {
            case BOX:         r2d::@drawRect(self.rect, (selected) ? self.color_selected : self.color);
            case ROUNDED_BOX: r2d::drawRectangleRounded(self.rect, 0.65f, 6, (selected) ? self.color_selected : self.color);
            default: unreachable();
        }
    }

    if(self.displayBounds()) {
        r2d::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
    }
}

//////////////// ******** GUI FRAME && WIDGET'S STRUCTS ******** ////////////////////////

/*
alias WidgetList = List{any};
alias MouseOverCallback = fn bool(Widget*);
// A frame is a top-level panel that contains widgets

struct Frame (SaveSystemInterface)
{
    // extends Panel (super/base class)
    inline Panel super;
    String name;
    WidgetList widgets;
}

fn void Frame.save(&self, SaveFile* file) @dynamic {
    self.super.save(file);
    @todo();
}

fn void Frame.reload(&self, SaveFile* file) @dynamic {
    self.super.reload(file);
    @todo();
}

fn void Frame.init(&self, String name) @inline {
    assert(rl::isWindowReady() == true);

    // init panel stuff (inits default rect and color)
    self.super.init();

    // init the frame menbers
    self.super.name = string::tformat("Frame_%s", name);
    self.show();
    
    // todo
   // Frame* this = self;
    //local_manager.register(this);
}

fn void Frame.deinit(&self) @inline 
{
    self.super.deinit();
    if (self.widgets.len()) 
    {
        foreach(widget: self.widgets) 
        {
            switch (widget.type) 
            {
                case WidgetButton:
                    ((WidgetButton*)widget.ptr).deinit();
                case WidgetText:
                    ((WidgetText*)widget.ptr).deinit();
                case WidgetContainer:
                    ((WidgetContainer*)widget.ptr).deinit();
                default:
                   ((Widget*)widget.ptr).deinit(); 
            }
        }
    }
}

fn void Frame.update(&self) 
{
    self.super.update();
}

fn void Frame.draw(&self)
{
    self.super.draw();
}

macro void Frame.@create(&self, $name; @body(Frame* frame))
{
    self.init($name);
    body(frame);
}
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////// Widgets ////////////////////////////////////////////////////

// NOTE(HM) Widget is a general data structure representing anything inside a gui, like buttons and such.

const KIND_NONE      = 0;
const KIND_WIDGET    = 1;
const KIND_TEXT      = 2;
const KIND_BUTTON    = 3;
const KIND_CONTAINER = 4;
const KIND_CHECKBOX  = 5;

alias WidgetCallback = fn void(any);

interface WidgetInterface
{
    fn void init(int kind);
    fn void initExt() @optional;
    fn void deinit();
    fn void update();
    fn void draw();
    fn bool isWithinScreenBounds() @optional;
    fn bool isInWidget(int x, int y) @optional;
    fn void addTo(Desktop*);
    //fn void addToFrame(Frame*) @optional;
    fn Desktop* getDesktop();
    fn void bindTo(Widget* other);
    fn bool bound();
    fn void unbind();
    fn String getName();
    fn void link(Widget* other);
    fn bool isLinked();
    fn void unlink();
    fn void setColor(rl::RLColor);
//
    fn bool onMouseOver(int x, int y) @optional;
    fn bool onMouseStopOver() @optional;
    fn bool onMouseButton(int x, int y, RLMouseButton button, bool pressed) @optional;
    fn bool onMouseWheel(int x, int y, int scroll) @optional;
	fn bool onKey(uint key, bool pressed) @optional;
	fn bool onJoystickAxis(int axis, float value) @optional;
	fn bool onJoystickButton(int button, bool pressed) @optional;
	fn void onSize(int w, int h) @optional;
	fn void onFocus(bool focus) @optional;
}

struct Widget (WidgetInterface) 
{
    // extends Panel (super/base class)
    inline Panel super;
    
    //int layer;
    int kind;
    bool selected;  // for the gui editor

    // for binding
    struct parent 
    {
        Desktop* desktop;
        Widget* other;
    }
    // for linking
    Widget* next; // for linked list of widgets

    // callbacks
    WidgetCallback onOver; // called when the mouse is over the widget
    WidgetCallback onStopOver;
    WidgetCallback onPress;
    WidgetCallback onPressed;
    WidgetCallback onSinglePress;
    WidgetCallback onDoublePress;
    WidgetCallback onRelease;
    WidgetCallback onEnterKey; // called when the enter key is pressed while the widget is focused
    WidgetCallback onLoad;   // called when the widget is loaded
}

fn void Widget.init(&self, int kind = KIND_NONE) @dynamic {
    self.super.init();
    self.kind = KIND_WIDGET;
    if(kind != KIND_NONE) {
        self.kind = kind;
    }
}

fn void Widget.deinit(&self) @dynamic{
    self.unlink();
    self.unbind();
    self.parent.desktop = null;
    self.super.deinit();
}

fn void Widget.editor_interactions(&self) @local
{
    // when in gui edit mode, we can select widgets with the mouse
    // and they should all be set to not active, as that is part of
    // the gui logic and the editor doesn't care what widget is active
    // or not, no matter their state all will be selectable.
    if (self.asFocus() && self.isMouseOver())
    {
        if (input::Action* action = input::getAction("editor_select")) {
            if(action.fnIsTriggered()) self.toggleSelection();
        }
    }
}

fn void Widget.update(&self) @dynamic 
{
    // if we are bound to a parent widget, we need to update our position each frame
    // to be always relative to the parent origin.
    // NOTE(HM) This is done even if we are hidden or deactivated.
    if(self.bound())
    {
        Vec2f parent_origin = self.parent.other.getPosition();
        // WTF? Why do we need to add the parent pos and then 
        // remove it again for this to work?!
        Vec2f new_offset    = (self.getPosition() + parent_origin) - parent_origin;
        //
        self.setPositionV(new_offset);
    }

    self.super.update(); // mouse over is done in super update

    if((guieditor::enabled() && guieditor::as_focus()) || main::gpGame.show_microui_test_frames) { return; }
    else if (!self.active() || self.hidden()) { return; }

    if(guieditor::enabled())
    {
        // run editor keyboard interactions
        self.editor_interactions();
    }
}

// Function to calculate the color based on time
fn RLColor selected_color_anim(Widget* wgt) @inline @local
{
    if(!wgt) return {0, 0, 0, 1};
    
    assert(wgt.parent.desktop != null);
    int time = wgt.parent.desktop.time;
    int flicker_milliseconds = 200;
    
    RLColor color;
    int r,g,b,a;
    //r = (int) (math::sin(time / 100) + 1) * 128 + 127;
    //g = (int) (math::cos(time / 50) + 1) * 128 + 127;
    //b = (int) (math::sin(time / 20) + 255) * 128 + 127;
    r = wgt.color.r;
    g = wgt.color.g;
    b = wgt.color.b;
    color.r = (char) r;
    color.g = (char) g;
    color.b = (char) b;
    //color.a = 0xFF;
    color.a = (char) (math::sin(time / flicker_milliseconds) + 1) * 128 + 127;
    
    return color;
}

<*
 @param [in] wgt : "widget to draw the origin coordinates for"
 @require wgt != null
*>
fn void Widget.draw_origin_coordinates(Widget* wgt) @local @inline 
{
    if(!wgt.selected) return;
    
    int scr_w, scr_h;
    float lineThick  = 1.0f;
    scr_w = main::gpGame.screen.w;
    scr_h = main::gpGame.screen.h;
    
    Vec2f widget_center = wgt.getPosition();
    Vec2f widget_size   = wgt.getSize();
    
    // draw widget BBox and coordinates values
    Vec2f dbg_text_pos = widget_center;
    dbg_text_pos += misc::VEC_UP * (0.40f * widget_size.y);
    rl::drawText(
        string::tformat("(w:%dpx, h:%dpx) : (w:%d%%, h:%d%%)", widget_center.x, widget_center.y, 
        ((widget_center.x * 100) / scr_w), ((widget_center.y * 100) / scr_h)).zstr_tcopy(),
        (int)dbg_text_pos.x, (int)dbg_text_pos.y, 16, rl::RED
    );
    // draw widget center
    r2d::drawCircle((int)widget_center.x, (int)widget_center.y, 2.0f, rl::SKYBLUE);
    
    // draw lines going from widget center to the screen ends
    r2d::drawLineEx(widget_center,
        (widget_center + misc::VEC_LEFT * (scr_w - widget_center.x)),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center,
        (widget_center + misc::VEC_RIGHT * (scr_w - widget_center.x)),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center,
        (widget_center + misc::VEC_UP * (scr_h - widget_center.y)),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center,
        (widget_center + misc::VEC_DOWN * (scr_h - widget_center.y)),
        lineThick, rl::RED
    );
}

fn void Widget.draw(&self) @dynamic 
{
    if(self.hidden()) return;
    
    if(self.selected)
    {
        self.setSelectedColor(selected_color_anim(self));
        self.draw_origin_coordinates();
    }
    
    switch (self.kind)
    {
        case KIND_TEXT:
            // draw text label
            WidgetText* this = (WidgetText*)self;
            Vec2f center;
            ZString text = this.text.zstr_tcopy();
            if(text.len() > 0) 
            {
                switch (this.align)
                {
                case CENTER:
                    center = {
                        self.rect.x + self.rect.width / 2,
                        self.rect.y + self.rect.height / 2
                    };
                    center.x -= (float)(this.text_len / 2);
                    center.y -= (float)this.font_size / 2;
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
                    center.x -= this.text_len;
                }
                
                if(this.font != null) {
                    rl::drawTextEx(*this.font, text, {center.x, center.y}, (float)this.font_size, this.spacing, self.color);
                }
                else { rl::drawText(text, (int)center.x, (int)center.y, this.font_size, self.color); }
            }

            if(self.displayBounds()) {
                r2d::drawRectangleLinesEx(self.rect, 1.0f, rl::RED);
            }
        case KIND_CHECKBOX:
            // draw the checkbox
            WidgetCheckBox* this = (WidgetCheckBox*)self;
            Vec2f center = this.getPosition() + misc::VEC_LEFT * (this.getWidth() / 2.0f);
            center += misc::VEC_DOWN * (this.getHeight() / 2.0f);
            r2d::drawRectangle((int)center.x, (int)center.y, 20, 20, this.color);

            // draw the label
            if(this.label.len > 0) {
                Vec2f label_pos = center + misc::VEC_RIGHT * 25.0f;
                rl::drawText(this.label.zstr_tcopy(), (int)label_pos.x, (int)label_pos.y, 16, rl::BLACK);
            }
            
            if(this.isChecked()) {
                r2d::drawRectangleLines((int)center.x, (int)center.y, 20, 20, rl::BLACK);
                r2d::drawLineEx(center, (center + misc::VEC_RIGHT * 20), 2.0f, rl::GREEN);
                r2d::drawLineEx(center, (center + misc::VEC_DOWN * 20), 2.0f, rl::GREEN);
            }
        case KIND_CONTAINER:
        case KIND_BUTTON:
            self.super.draw(self.selected);
        default: break; // do nothing
    }
}

fn bool Widget.isWithinScreenBounds(&self) @dynamic
{
    //if (self.hidden()) return false;

    RLRectangle screen_bounds = {
    .x      = 0,
    .y      = 0,
    .width  = main::gpGame.screen.w,
    .height = main::gpGame.screen.h
    };

    return rl::checkCollisionRecs(screen_bounds, self.rect) ? true : false;
}

fn bool Widget.isInWidget(&self, int x, int y) @dynamic
{
    if (self.hidden()) return false;

    RLVector2 point = { (float)x, (float)y };
    return rl::checkCollisionPointRec(point, self.rect) ? true : false;
}

<*
 @param [in] desktop : "parent desktop"
 @require desktop != null
*>
fn void Widget.addTo(&self, Desktop* desktop) @dynamic 
{
    self.parent.desktop = desktop;
    // todo change this to activate logic like the panel system...
    if (self.parent.desktop.isInteractive) {
        self.activate();
    }

    self.super.id = (int)self.parent.desktop.children.len() + 1;
    
    // concatenate with desktop name
    if (self.super.id < 10) {
        self.super.name = string::tformat("%s_%s%d", self.parent.desktop.name, self.super.name.tconcat("0"), self.super.id);
        if (self.bound()) {
            self.super.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.super.name, self.super.name.tconcat("0"), self.super.id);
        }
    } else {
      self.super.name = string::tformat("%s_%s%d", self.parent.desktop.name, self.super.name, self.super.id);
      if (self.bound()) {
          self.super.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.super.name, self.super.name, self.super.id);
      }
    }
    
    self.parent.desktop.addChild(self);
}

<*
 @ensure return != null
*>
fn Desktop* Widget.getDesktop(&self) @dynamic => self.parent.desktop;

<*
 @param [in] other : "parent widget"
 @require other != null
*>
fn void Widget.bindTo(&self, Widget* other) @dynamic {
    if(self.bound()) {
        log::warning(Where.CONSOLE, "Cannot Bind %s to %s because is already bound to %s.", self.super.id, other.super.id, self.parent.other.super.id);
        return;
    }
    
    // we are now bound to the parent
    self.parent.other = other;

    // our position is now relative to the parent origin
    //Vec2f parent_origin  = other.getPosition();
    //Vec2f dist_offset    = self.getPosition() - parent_origin;
    //Vec2f new_offset     = parent_origin + dist_offset;
    //self.setPositionV(new_offset);
    //
}

fn bool Widget.bound(&self) @dynamic {
    return self.parent.other != null;
}

fn void Widget.unbind(&self) @dynamic {
    if(!self.bound()) {
        return;
    }
    
    self.parent.other = null;
}

fn String Widget.getName(&self) @inline @dynamic => self.super.name;

fn void Widget.link(&self, Widget* other) @dynamic {
    if (other == null) return;

    if (self.isLinked()) {
        log::warning(Where.CONSOLE, "Cannot link %s to %s because is already linked to %s.", self.super.id, other.super.id, self.next.id);
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

fn void Widget.setColor(&self, RLColor color) @dynamic 
{
    self.super.color = color;
}

fn void Widget.setSelectedColor(&self, RLColor color) @dynamic 
{
    self.super.color_selected = color;
}

// editor functions
fn void Widget.toggleSelection(&self) @inline => self.selected = !self.selected;
fn void Widget.select(&self) @inline => self.selected = true;
fn void Widget.deselect(&self) @inline => self.selected = false;


/////////////////////////////////////// extra widgets //////////////////////////////////////////////////////

enum WidgetTextAlign
{
    CENTER,
    LEFT,
    RIGHT,
}

struct WidgetText 
{
    // extends Widget (super/base class)
    inline WidgetButton super;

    String text;
    int text_len;
    RLFont* font;
    float spacing; // spacing between characters, used for text rendering
    int font_size;
    WidgetTextAlign align;
}


fn void WidgetText.init(&self) //@inline 
{
    self.super.init(KIND_TEXT);
    self.super.hide(); // don't show the button shape
    self.super.name = "TextLabel";
    self.setColor({0, 0, 0, 0});
    self.spacing    = 2.0f; //@hardcode, todo make this int a cvar
    self.font_size  = 20; //@hardcode
    self.setDefaultColor(rl::WHITE); //@hardcode
    self.align      = WidgetTextAlign.CENTER;
}

fn void WidgetText.deinit(&self) @inline {
    self.super.deinit();
    if(self.font) {
        // NOTE(HM) we don't deinit the font here, as it is done through the game singleton 
        // at game shutdown and they can also be shared between widgets.
        // rl::unloadFont(*self.font); // this will crash the game if the font is used by other widgets
        // so we just set it to null, and again the font will be deinitialized when the game closes.
        self.font = null;
    }
}

<*
 @require self.text != ""
*>
fn void WidgetText.updateBounds(&self) @local 
{
    if(self.font != null) {
        RLVector2 bounds = rl::measureTextEx(*self.font, self.text.zstr_tcopy(), (float)self.font_size, self.spacing);
        /*int txt_len = rl::measureText(self.text.zstr_tcopy(), self.font_size);
        if(txt_len > bounds.x) {
            bounds.x = (float)txt_len; // make sure the bounds are at least as wide as the text
        }*/
        self.text_len = (int)bounds.x;
        self.setSize(bounds.x, bounds.y);
    } else {
        self.text_len = rl::measureText(self.text.zstr_tcopy(), self.font_size);
        self.setSize((float)self.text_len, (float)self.font_size);
    }
}

fn Vec2f WidgetText.getBounds(&self) @inline {
    // returns the bounds of the text, not the widget
    return { (float)self.text_len, (float)self.font_size };
}

fn void WidgetText.setFont(&self, RLFont* font) @inline {
    if (font == null) {
        log::error(Where.CONSOLE, "WidgetText: Cannot set font to null.");
        return;
    }
    self.font = font;
    self.updateBounds();

}

fn void WidgetText.setText(&self, String text) {
    self.text = text;
    self.updateBounds();
}

fn int WidgetText.textlen(&self) @inline {
    return rl::measureText(self.text.zstr_tcopy(), self.font_size);
}

fn float WidgetText.textlenf(&self) @inline {
    return (float)rl::measureText(self.text.zstr_tcopy(), self.font_size);
}

fn void WidgetText.setTextColor(&self, RLColor color) @inline {
    self.color = color;
}

fn void WidgetText.setAlign(&self, WidgetTextAlign align) @inline {
    self.align = align;
}

fn void WidgetText.setFontSize(&self, int size) @inline {
    self.font_size = size;
    self.updateBounds();
}

fn void WidgetText.update(&self) 
{
    self.super.update();
}

fn void WidgetText.draw(&self) //@inline 
{
    self.super.draw();
}

<*
    Creates a new label widget with the given name and text.
    The label will use the given font and font size, if provided.
    The label will be deactivated by default, so it won't be interactive.
    The label will also be shown by default.
    Don't forget to free the label memory when you are done with it.

    @param name : "name of the label"
    @param text : "text to display on the label"
    @param font : "font to use for the label, can be null"
    @param font_size : "font size to use for the label, must be greater than 0 to be applied"
    @param text_color : "color of the text"
*>
fn WidgetText* createLabel(String name, String text, RLFont* font, int font_size, RLColor text_color) 
{
    WidgetText* label = mem::new(WidgetText);
    label.init();
    label.name = label.name.tconcat(text);
    label.setText(text);
    label.setTextColor(text_color);
    if (font != null) {
        label.setFont(font);
    }
    if (font_size > 0) {
        label.setFontSize(font_size);
    }
    // labels shouldn't be interactive (to save perf...)
    label.deactivate();
    label.show();
    return label;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//#################################### BUTTON ######################################################
////////////////////////////////////////////////////////////////////////////////////////////////////
// NOTE(HM) Button is a widget that can be pressed, 
// it has a default color and a sound that plays when pressed.

struct WidgetButton 
{
    // extends Widget (super/base class)
    inline Widget super;
    
    // panel already has a color variable
    // but this is the default color, used when the button color changes and we want to reset it
    // to the default color.
    RLColor default_color;
    bool pressed;
    bool activated;
    RLSound* interaction_sound;
    //bool sound_played;
    bool reset;
    int press_count;
}

fn void WidgetButton.init(&self, int kind = KIND_BUTTON) //@inline 
{
    self.super.init(kind);
    self.super.name = "Button";
    self.setDefaultColor(rl::WHITE); //@hardcode
    self.setSound(&main::gpGame.default_sound); //@hardcode, todo give this a better sound
}

fn void WidgetButton.deinit(&self) @inline {
    self.super.deinit();
    if (self.interaction_sound) self.interaction_sound = null;
}

fn void WidgetButton.setColor(&self, RLColor color) @dynamic {
    self.super.setColor(color);
}

fn void WidgetButton.setDefaultColor(&self, RLColor color) @inline {
    self.default_color = color;
    self.setColor(color);
}

fn void WidgetButton.setSound(&self, RLSound* sound) @inline {
    self.interaction_sound = sound;
}

/*
fn void WidgetButton.onEnterKey(&self) @inline {
    if (self.isInteractive() == false || self.asFocus() == false) return;
    self.onSinglePress();
}
*/

fn void WidgetButton.manage_interactions(&self) @local 
{
    if (self.active() == false) return;

    //main::log::info(Where.CONSOLE, "Gui: I'm over button: %s", self.super.name);
    if (self.asFocus() && self.selected == false)
    {
        if(self.onOver) self.onOver(any_make(self, WidgetButton.typeid));

        // Todo(HM) support keyboard/gamepad navigation to buttons
        // like using tab or arrow keys to navigate between buttons and enter to press them
        if(!ui_editGui.getBool()) 
        {
            if (rl::isMouseButtonDown(RLMouseButton.LEFT) && self.press_count >= 1) {
                //main::log::info(Where.CONSOLE, "Gui: I'm pressing button: %s", self.super.name);
                if (self.onPress) { 
                    self.onPress(any_make(self, WidgetButton.typeid));
                }
            }
            
            if (Action* action = input::getAction("Double Press")) {
                if (action.fnDoubleTriggered(0.250f) && self.onDoublePress) { 
                    self.onDoublePress(any_make(self, WidgetButton.typeid));
                }
            }
            
            if (Action* action = input::getAction("Single Press")) {
                if (action.fnBecameTriggered() && self.onSinglePress) { 
                    self.onSinglePress(any_make(self, WidgetButton.typeid)); 
                }
                // if(action.fnBecameTriggered()) {
                    // String[] array = {"apple", "banana", "apple", "orange", "banana"};
                    // int size = array.len;
                    // input::detect_duplicates(array, size);
                // }
            }

            if (rl::isMouseButtonReleased(RLMouseButton.LEFT)) {
                if (self.onRelease) { 
                    self.onRelease(any_make(self, WidgetButton.typeid)); 
                }
            }

            if (rl::isKeyPressed(rl::KEY_ENTER) && !rl::isKeyPressedRepeat(rl::KEY_ENTER)) {
                if (self.onEnterKey) { 
                    self.onEnterKey(any_make(self, WidgetButton.typeid)); 
                }
            }
        }
    } else {
        if (self.onStopOver) { 
            self.onStopOver(any_make(self, WidgetButton.typeid));
        }
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
    rl::@scissorMode((int)self.rect.x, (int)self.rect.y, (int)self.rect.width, (int)self.rect.height)
    {
        self.super.draw();
    };
}

<*
 @ensure return != null
*>
fn WidgetButton* createButton() @inline {
    WidgetButton* button = mem::new(WidgetButton);
    button.init();
    return button;
}

////////////////////////////////////////////////// Widget check box //////////////////////////////////////////////////////

alias CheckBoxListenerCallback = fn void(WidgetCheckBox*);
struct WidgetCheckBox 
{
    // extends Widget (super/base class)
    inline WidgetButton super;

    bool checked; // is the checkbox checked or not
    String label; // label for the checkbox

    CheckBoxListenerCallback onCheckBoxClicked;
}

fn void WidgetCheckBox.init(&self, int kind = KIND_CHECKBOX) @inline 
{
    self.super.init(kind);
    self.super.name = "CheckBox";
    self.super.setColor(rl::WHITE);
    self.onCheckBoxClicked = (CheckBoxListenerCallback)&WidgetCheckBox.onMouseButton;
}

fn void WidgetCheckBox.deinit(&self) @inline 
{
    self.super.deinit();
    if(self.label.len > 0) {
        self.label = "";
    }
}

fn void WidgetCheckBox.update(&self) @inline 
{
    self.super.update();
}

fn void WidgetCheckBox.draw(&self) @inline 
{
    self.super.draw();
}

fn bool WidgetCheckBox.onMouseButton(&self, int x, int y, RLMouseButton button, bool pressed) @dynamic
{
	if (button == RLMouseButton.LEFT && pressed)
	{
		self.checked = !self.checked;
		if(self.onCheckBoxClicked) self.onCheckBoxClicked(self);
	    return true;
	}

    return false;
}

fn void WidgetCheckBox.setChecked(&self, bool checked) @inline 
{
    self.checked = checked;
    self.setColor((checked) ? rl::GREEN : rl::WHITE);
}

fn bool WidgetCheckBox.isChecked(&self) @inline 
{
    return self.checked;
}

fn void WidgetCheckBox.setLabel(&self, String label) @inline 
{
    self.label = label;
}

fn WidgetCheckBox* createCheckBox(String label) @inline 
{
    WidgetCheckBox* checkbox = mem::new(WidgetCheckBox);
    checkbox.init();
    checkbox.setLabel(label);
    return checkbox;
}

//////////////////////////////////// CONTAINER //////////////////////////////////////
module engine::gui::container::cont;

import thirdparty::raylib5::rl;
import engine::gui::desktop::desk;
import engine::misc;
import std::collections::list;

alias ContainerQueue = List{any};

const uint TOP_TO_BOTTOM = 1;
const uint BOTTOM_TO_TOP = 2;
const uint LEFT_TO_RIGHT = 3;
const uint RIGHT_TO_LEFT = 4;

struct ContainerParams @packed
{
    uint direction;
    RLColor background;
    Vec4f padding;
    uint itemGap;
    struct minSize
    {
        uint w;
        uint h;
    }
    struct border_between
    {
        uint lineThick;
        RLColor color;
    }
}

struct WidgetContainer 
{
    inline Widget super;

    ContainerParams params;
    ContainerQueue children;
}

macro WidgetContainer.@container(&self, Desktop* desk, ContainerParams params; @body(self)) 
{
    self.init(params);
    desk.addChild(self);
    @body(self);
}

fn void WidgetContainer.init(&self, ContainerParams params) @inline 
{
    self.params = params;
    self.super.init();
    self.color = params.background;

    if(params.minSize.w != 0 && params.minSize.h == 0) 
    {
        self.setSize(params.minSize.w, 200);
    } 
    else if(params.minSize.w == 0 && params.minSize.h != 0) 
    {
        self.setSize(200, params.minSize.h);
    } 
    else if(params.minSize.w == 0 && params.minSize.h == 0) 
    {
        self.setSize(200, 200);
    } 
    else 
    {
        self.setSize(params.minSize.w, params.minSize.h);
    }

    self.kind = gui::KIND_CONTAINER;
}

fn void WidgetContainer.deinit(&self) @inline {
    self.super.deinit();
}

fn void WidgetContainer.update(&self) {
    self.super.update();

    float pad_left, pad_right, pad_top, pad_bottom;
    pad_left   = self.params.padding[0];
    pad_right  = self.params.padding[1];
    pad_top    = self.params.padding[2];
    pad_bottom = self.params.padding[3];
    
    Widget* previous;
    Vec2f offset;
    Vec2f anchor = self.getPosition() + misc::VEC_LEFT * pad_left;
    anchor += misc::VEC_DOWN * pad_top;

    foreach(i, child : self.children)
    {
        Widget* wdg = anycast(child, Widget)!!;
        defer previous = wdg;

        // todo
        switch(self.params.direction)
        {
            case TOP_TO_BOTTOM:
                if(i == 0) {
                    offset = anchor;
                    wdg.setPositionV(offset);
                } else {
                    offset += misc::VEC_DOWN * ( previous.getHeight() + self.params.itemGap);
                    wdg.setPositionV(offset);
                }

                if(i != 0, self.children.len() >= 2 && self.params.border_between.lineThick != 0)
                {
                    Vec2f start, end;
                    start = offset + misc::VEC_UP * ((float)self.params.itemGap / 2.0f);
                    end   = start + misc::VEC_LEFT * (self.getWidth() - pad_right);
                    rl::drawLineEx( start, end, 
                        self.params.border_between.lineThick, self.params.border_between.color
                    );
                }
            case BOTTOM_TO_TOP: @todo();
            case LEFT_TO_RIGHT: @todo();
            case RIGHT_TO_LEFT: @todo();
            default:
                unreachable("invalid WidgetContainer direction");
        }

        switch (child.type)
        {
            case WidgetButton.typeid:
                anycast(child, WidgetButton)!!.update();
            case WidgetText.typeid:
                anycast(child, WidgetText)!!.update();
            case WidgetContainer.typeid: // container inside another
                anycast(child, WidgetContainer)!!.update();
            default:
                unreachable("unkown gui widget typeid");
        }
    }
}

fn void WidgetContainer.draw(&self) {
    self.super.draw();

    foreach(child : self.children) {
        switch (child.type)
        {
            case WidgetButton.typeid:
                anycast(child, WidgetButton)!!.draw();
            case WidgetText.typeid:
                anycast(child, WidgetText)!!.draw();
            case WidgetContainer.typeid: // container inside another
                anycast(child, WidgetContainer)!!.draw();
            default:
                unreachable("unkown gui widget typeid");
        }
    }
}

fn void WidgetContainer.register(&self, any child) @inline {
    self.children.push(child);
    @catch(anycast(child, Widget).bindTo((Widget*)self));
}

//////////////////////////////////// DESKTOP //////////////////////////////////////
module engine::gui::desktop::desk;

import thirdparty::raylib5::rl;
import engine::misc;
import game::main;
import game::serialize::svs;
import std::collections::list;
import engine::logging::log;
import engine::sys::render2d::r2d;
import engine::gui::container::cont;
//import engine::tools::editor;
import engine::gui::guieditor;

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

// This should have been done using a list of 'any' types but I did this before
// really knowing that was a option and now changing this is a big refactor 
// and i'm to lazy to change this, at lest for now...
// todo change this to use the any list bellow...
alias ChildrenQueue = List{Widget*};
//alias ChildrenQueue = List{any};

struct Desktop (SaveSystemInterface) 
{
    // id
    String name;
    int number; // used to uniquily identify each desktop
    
    // visuals
    RLRectangle rect;
    RLColor color;
    // todo support more complex backgrounds
    RLTexture2D* tex;
    //
    
    // flags
    bool isInteractive;
    bool visible;
    bool active;
    bool loading; // when eventually we load guis from a file
    //
    // to handle timing while the desktop is open/active
    int time; // milliseconds

    RLMusic music_stream; // any music stream that we may want to attach to a desktop
    List{Desktop*} shared_music_stream_desktops; // list of desktops that share the same music stream
    
    // Lists
    ChildrenQueue children;
    // todo make a queue for hidden children to better control what to hide and show.

    Desktop* home; // the home desktop, where we can return to
    Desktop* previous; // for desktop linkage, so we can go back to the previous desktop
    Desktop* next;     // for desktop linkage, so we can go to the next
}

fn void Desktop.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Desktop.reload(&self, SaveFile* file) @dynamic {
// todo
}

// todo init this from a svg file
fn bool Desktop.initFromFile(&self, ZString path, bool cache ) 
{
    @todo();
    //return false;
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
	//self.loading = false;
	//return true;
}

<*
    Initializes the desktop with the given name, fullscreen mode, and size.
    If fullscreen is true, the desktop will cover the entire screen.
    If fullscreen is false, the desktop will be initialized with the given width and height.
    The desktop will be registered with the local manager.
    
    @param name : "name of the desktop"
    @param isFullscreen : "if true, the desktop will cover the entire screen"
    @param w : "width of the desktop, used only if isFullscreen is false"
    @param h : "height of the desktop, used only if isFullscreen is false"

    @require rl::isWindowReady() == true
*>
fn void Desktop.init(&self, String name, bool isFullscreen = true, int w = 800, int h = 600) @inline 
{
    self.name = string::tformat("Desktop_%s", name);
    self.number = (int)local_manager.desktops.len() + 1;
    //
    //
    if(isFullscreen)
    {
        self.rect = { // @hardcode
            .x      = 0,
            .y      = 0, 
            .width  = main::gpGame.screen.w,
            .height = main::gpGame.screen.h,
        };
    } 
    else 
    {
        self.rect = { // @hardcode
            .x      = 0,
            .y      = 0, 
            .width  = w,
            .height = h,
        };
    }
    
    self.color = rl::WHITE;
    //
    self.isInteractive = true;
    self.show();
    
    Desktop* this = self;
    local_manager.register(this);
}

fn void Desktop.deinit(&this) @inline 
{
    this.clear();
    // last clear ourself
    if(this.tex) this.tex = null;
    local_manager.unregister(this);
}

fn void Desktop.setFocus(&self, bool focus) @inline 
{
    if (focus) {
        self.activate(true, main::gpGame.time_ms);
    } else {
        self.activate(false, main::gpGame.time_ms);
    }
}

fn void Desktop.setPosition(&self, float x, float y) @inline 
{
    self.rect.x = x;
    self.rect.y = y;
}

fn void Desktop.setPositionV(&self, Vec2f pos) @inline 
{
    self.rect.x = pos.x;
    self.rect.y = pos.y;
}

fn Vec2f Desktop.getPosition(&self) @inline 
{
    return {self.rect.x, self.rect.y};
}

fn void Desktop.setSize(&self, float w, float h) @inline 
{
    self.rect.width  = w;
    self.rect.height = h;
}

fn Vec2f Desktop.getSize(&self) @inline 
{
    return {self.rect.width, self.rect.height};
}

fn void Desktop.activate(&self, bool activate = true, int _time = main::gpGame.time_ms) @inline {
	self.time   = _time;
	self.active = activate;
}

fn void Desktop.deactivate(&self, int _time = main::gpGame.time_ms) @inline {
    self.time   = _time;
    self.active = false;
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

fn void Desktop.setColor(&self, RLColor color) @inline => self.color = color;

// delete all down to the basic desktop
fn void Desktop.clear(&self) @inline
{
    if (self.children.len()) 
    {
        foreach(child: self.children) 
        {
            switch (child.kind) 
            {
                case gui::KIND_BUTTON:
                    ((WidgetButton*)child).deinit(); 
                case gui::KIND_TEXT:
                    ((WidgetText*)child).deinit(); 
                default:
                    child.deinit();
            }
        }
    }

    if(self.shared_music_stream_desktops.len()) 
    {
        if(self.shared_music_stream_desktops.first()!! == self) 
        {
            // if the first desktop in the list is the same as self, then we can unload the music stream
            if(rl::isMusicValid(self.music_stream)) 
            {
                // todo fade out the music stream
                //if(rl::isMusicStreamPlaying(self.music_stream)) rl::stopMusicStream(self.music_stream);
                rl::unloadMusicStream(self.music_stream);

                // then just zero the data for the rest of the desktop's and clear the shared music desktops list.
                for(int i = 1; i < self.shared_music_stream_desktops.len(); i++)
                {
                    (*self.shared_music_stream_desktops[i]).music_stream = {};
                }

                self.shared_music_stream_desktops.clear();
            }
        } 
    }

    if(self.home     != null) self.home     = null;
    if(self.previous != null) self.previous = null;
    if(self.next     != null) self.next     = null;
}

fn bool Desktop.hidden(&self) @inline => !self.visible;

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
                case gui::KIND_BUTTON:
                    ((WidgetButton*)child).hide(); 
                case gui::KIND_TEXT:
                    ((WidgetText*)child).hide(); 
                default:
                   ((Widget*)child).hide(); 
            }
        }
    }

    if(rl::isMusicValid(self.music_stream)) {
        if(rl::isMusicStreamPlaying(self.music_stream)) rl::pauseMusicStream(self.music_stream);
    }
}

fn void Desktop.show(&self) {
    if(!self.hidden()) return;
    
    self.visible = true;
    
    // todo find a way to only show certain children not all
    
    if (self.children.len()) {
        foreach(child: self.children) {
            switch (child.kind) {
                case gui::KIND_BUTTON:
                    ((WidgetButton*)child).show(); 
                case gui::KIND_TEXT:
                    ((WidgetText*)child).show(); 
                default:
                   ((Widget*)child).show(); 
            }
        }
    }

    if(rl::isMusicValid(self.music_stream)) {
        if(!rl::isMusicStreamPlaying(self.music_stream)) rl::resumeMusicStream(self.music_stream);
    }
}

fn void Desktop.drawCursor(&self) @inline
{
    if(main::gpGame.editor.isOpened()) return;
    
	if ( self.isInteractive && self.active && self.visible ) {
		if(main::game_cursor_hidden()) main::show_game_cursor();
	} else {
		if(main::game_cursor_visible()) main::hide_game_cursor();
	}
}

fn void Desktop.update(&self) 
{
    if(self.hidden() && self.active == false) return;
    
    if (self.children.len())
    {
        foreach(child: self.children)
        {
            switch (child.kind)
            {
                case gui::KIND_BUTTON:
                    ((WidgetButton*)child).update(); 
                case gui::KIND_TEXT:
                    ((WidgetText*)child).update();
                case gui::KIND_CHECKBOX:
                    ((WidgetCheckBox*)child).update();
                case gui::KIND_CONTAINER:
                    ((WidgetContainer*)child).update();
                default:
                    child.update(); 
            }
        }
    }

    if(rl::isMusicValid(self.music_stream)) {
        if(rl::isMusicStreamPlaying(self.music_stream) && 
                                        main::gpGame.pause_all_music)
        {
            rl::pauseMusicStream(self.music_stream);
        } 
        
        if(!rl::isMusicStreamPlaying(self.music_stream) && 
                                    !main::gpGame.pause_all_music)
        {
            // play music stream
            rl::resumeMusicStream(self.music_stream);
        }
        rl::updateMusicStream(self.music_stream);
    }
}

fn void Desktop.redraw(&self, int _time)  
{
    if(self.hidden()) return;
    
    /*if ( r_skipGuiShaders.GetInteger() > 5 ) {
		return;
	}*/
    
	if (!self.loading) {
		self.time = _time;
	}
    
    // draw Desktop background
    if(self.tex) {
        assert(rl::isTextureValid(*self.tex));
        rl::drawTexture(*self.tex, (int)self.rect.x, (int)self.rect.y, self.color);
    } else {
        r2d::@drawRect(self.rect, self.color);
    }

    self.drawCursor();
    
    // draw Desktop content/children
    if (self.children.len())
    {
        foreach(child: self.children) 
        {
           switch (child.kind) 
           {
                case gui::KIND_BUTTON:
                    ((WidgetButton*)child).draw();
                case gui::KIND_TEXT:
                    ((WidgetText*)child).draw();
                case gui::KIND_CONTAINER:
                    ((WidgetContainer*)child).draw();
                default:
                   child.draw();
            }
        }
    }
    
    self.debug();
}

<*
    Draws this desktop, but only if is the currently active GUI in the game,
    if not draws the other active desktop instead.
    This is a function that should be called from the main game loop.
    
    @param self : "the current desktop instance"
    @param time : "the current time in milliseconds"    
*>
fn void Desktop.draw(&self, int time) {
    Desktop* guiActive = main::gpGame.guiActive;

    if ( guiActive ) {
		guiActive.redraw(time);
	}
}

fn void Desktop.addChild(&self, Widget* child) @inline @local {
    self.children.push(child);
}

macro Desktop.@addChild(&self, Widget* child; @body(self)) 
{
    self.addChild(child);
    @body(self);
}

macro Desktop.@addChildren(&self; @body(self))
{
    @body(self);
}

macro Desktop.getChild(&self, int id) {
    Widget* child = self.children[id];
    if (child == null) {
        log::warning(CONSOLE, "Cannot get child %d from %s because is null.", id, self.super.name);
        return null;
    }
    return child;
}

fn void Desktop.debug(&self) 
{
    if(gui::ui_debugDraw.getBool())
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
                    h_startPos, 
                    (h_startPos + misc::VEC_RIGHT * scr_w), 
                    lineThick, rl::GRAY
                );
                float h_line_seperation = (0.05f * scr_w);
                h_startPos += (Vec2f){h_line_seperation, 0};
            }
            rl::drawLineEx(
                w_startPos, 
                (w_startPos + misc::VEC_DOWN * scr_h), 
                lineThick, rl::GRAY
            );
            float w_line_seperation = (0.05f * scr_h);
            w_startPos += (Vec2f){0, w_line_seperation};
        }
*/
        // draw a react around the destop area itself
        r2d::drawRectangleLinesEx(self.rect, 2.0f, rl::RED);
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
               if(child.selected) continue;
               
               dbg_text_pos = {child.rect.x, child.rect.y};
               dbg_text_pos += misc::VEC_UP * (0.30f * child.rect.height); 
               rl::drawText(
                    string::tformat("(w:%dpx, h:%dpx) : (w:%d%%, h:%d%%)", child.rect.x, child.rect.y, 
                    ((child.rect.x * 100) / scr_w), ((child.rect.y * 100) / scr_h)).zstr_tcopy(),
                    (int)dbg_text_pos.x, (int)dbg_text_pos.y, 9, rl::RED
               );
               // draw widget center
               r2d::drawCircle((int)child.rect.x, (int)child.rect.y, 2.0f, rl::SKYBLUE);
               r2d::drawRectangleLinesEx(child.rect, 1.5f, rl::RED);
            }
        }
    }
}

//////////////////////////////////// DESKTOP MANAGER //////////////////////////////////////

enum GUIMode : inline int
{
    NORMAL,
    EDITOR
}

alias DesktopList = List{Desktop*};

// NOTE(HM) TODO(HM) Rename to MenuOS?
// Every user GUI should have at lest one Desktop,
// is a data structure to put everything that makes up a user GUI inside.
struct DesktopManager {
    DesktopList desktops;
    GUIMode mode;
}

DesktopManager local_manager @local;
DesktopManager* gpManager = &local_manager;

<*
 @param [&in] _desk : "the desktop to register"
*>
fn void DesktopManager.register(&self, Desktop* _desk) @inline {
    foreach(desk : self.desktops) {
        if(desk.name == _desk.name) {
            log::warning(Where.CONSOLE, "Cannot register \"%s\" because is already registered.", desk.name);
            return;
        }
    }
    
    self.desktops.push(_desk);
}

<*
 @param [&inout] _desk : "the desktop to remove"
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

    /*if(ui_editGui.getBool()) {
        // enable edit mode
        if(self.mode != EDITOR) self.editor(true);
    } else {
        // disable edit mode
       if(self.mode == EDITOR) self.editor(false);
    }*/
    self.editor(gui::ui_editGui.getBool());

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            if(desk.active) {
                desk.update();
                if(self.mode == EDITOR && !main::gpGame.editor.focused()) {
                    // put something here
                }

                if(gui::ui_editGui.getBool()) {
                    guieditor::update(desk);
                }
            }
        }
    }
}

fn void DesktopManager.draw(&self, int screenWidth, int screenHeight) @inline {

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            desk.draw(main::gpGame.time_ms);
            
            if(self.mode == EDITOR && !main::gpGame.editor.isOpened()) {
                //drawGuiEditor(desk); TODO(HM) draw this through the new editor
            }

            if(gui::ui_editGui.getBool()) {
                // draw the gui editor
                guieditor::draw(desk);
            }
        }
    }
}

fn void DesktopManager.free(&self) {
    if(self.desktops.len()) foreach(desk: self.desktops) desk.deinit();
    
    self.desktops.free();
}

fn void DesktopManager.editor(&self, bool choice = false) {
    self.mode = (choice) ? EDITOR : NORMAL;
}

// *****************************************************************************
// @deprecated 
// NOTE(HM) TODO(HM) move this to a better place, like a gui editor file
// this should be renamed to something like gui_editor because we already have a editor in the game
// #region ***************************** GUI EDITOR ****************************
module engine::gui::guieditor;

import thirdparty::raylib5::rl;
import engine::gui::desktop::desk;
import thirdparty::raygui5::rgui;
import engine::logging::log;
import game::main;
import engine::misc;
//import game::serialize::svs;
//import std::collections::list;

alias game = main::gpGame;

const GUIE_MAJOR    = 0;
const GUIE_MINOR    = 1;
const GUIE_REVISION = 0;

macro bool drawButton(String text, RLVector2 pos) @local
{
    return rgui::button({pos.x, pos.y, 120, 30}, string::tformat("#191#%s", text).zstr_tcopy());
}

fn void open() @inline {
    if(game.guiActive == null) {
        log::error(Where.CONSOLE, "Cannot open gui editor because no gui is active.");
        return;
    }
    gui::ui_editGui.set("1");
}

fn void close() @inline {
    gui::ui_editGui.set("0");
    if(is_widget_debug_on()) disable_widget_debug();
}

fn bool is_opened() @inline {
    return gui::ui_editGui.getBool();
}

fn void enable_widget_debug()  @local @inline => gui::ui_debugDraw.set("1");
fn void disable_widget_debug() @local @inline => gui::ui_debugDraw.set("0");
fn bool is_widget_debug_on()   @local @inline => gui::ui_debugDraw.getBool();

fn bool enabled() @inline => desk::gpManager.mode == EDITOR;
fn bool as_focus() @inline {
    return (enabled() && game.editor.focused());
}

fn void move_selected(Widget* wgt)
{
    if(!wgt) return;
    
    float move_speed = 1.5f;
    if(rl::isKeyDown(rl::KEY_RIGHT)) {
        wgt.addToPositionV(misc::VEC_RIGHT * move_speed);
    }
    if(rl::isKeyDown(rl::KEY_LEFT)) {
        wgt.addToPositionV(misc::VEC_LEFT * move_speed);
    }
    if(rl::isKeyDown(rl::KEY_UP)) {
        wgt.addToPositionV(misc::VEC_UP * move_speed);
    }
    if(rl::isKeyDown(rl::KEY_DOWN)) {
        wgt.addToPositionV(misc::VEC_DOWN * move_speed);
    }
}

fn void update(Desktop* mng) 
{
    if(!mng || enabled() == false) return;
    
    foreach(wgt : mng.children) 
    {
        if(wgt.selected) {
            if(rl::isKeyPressed(rl::KEY_ESCAPE)) {
                wgt.deselect();
            } else {
                move_selected(wgt);
            }
        }
    }
}

fn void draw(Desktop* mng) 
{
    if(!mng || enabled() == false) return;
    
    int scr_w, scr_h;
    scr_w = game.screen.w;
    scr_h = game.screen.h;
    
    float left_marging = 0.025f * scr_w;
    float top_margin   = 0.05f  * scr_h;
    
    String editor_version = string::tformat("GUI EDITOR v: %s.%s.%s", GUIE_MAJOR, GUIE_MINOR, GUIE_REVISION);
    rgui::label({left_marging, top_margin, 120, 30}, editor_version.zstr_tcopy());
    
    // gui debug on off
    if(drawButton("Gui Debug", {left_marging, top_margin * 2})) {
        if(is_widget_debug_on()) {
            disable_widget_debug();
        } else {
            enable_widget_debug();
        }
    }
    
     // gui saving 
    if(drawButton("Gui SAVE", {left_marging, top_margin * 3})) {
        log::info(CONSOLE, "Trying to save gui \"%s\" but that is still not possible.", mng.name);
    }
    
    // close editor
    if(drawButton("Gui CLOSE", {left_marging, top_margin * 4})) {
        close();
    }
}

// end_region GUI EDITOR **************************





