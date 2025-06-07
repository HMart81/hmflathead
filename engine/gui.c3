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
import game::material::mtr;
import game::material::manager::mtrmng;
import engine::logging::lgr;
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
Cvar ui_debugDraw @public = { "ui_debugDraw", CvarType.BOOLEAN, "0", "show debug visualization for gui development" };
Cvar ui_editGui   @public = { "ui_editGui", CvarType.BOOLEAN, "0", "turn on gui editing functionality for gui development" };


fn void register_cvars() @public 
{
    cvar::@register(&ui_debugDraw);
    cvar::@register(&ui_editGui);
}
// end_region


///////////////////////////////////////////////////////////////////////////
//
//                                  PANEL
//
///////////////////////////////////////////////////////////////////////////

// region alias
//alias assetManager @private = astmng::assetManager;
// end_region

// region constants
//const bool PANEL_PROFILE = true;
const bool DEBUG_PANELS   = true;
const int  MIN_PANEL_SIZE = 32;
// end_region

// mostly for the panel texture inversion ability
const uint HORIZONTAL_DIR = 1;
const uint VERTICAL_DIR   = 2;

enum PanelShape : inline int
{
    BOX,
    ROUNDED_BOX
}

/* 
    NOTE(HM) Panel is a simple data structure representing a big square or image, 
    used for background images or single color rectangles, buttons, etc...
*/
struct Panel (SaveSystemInterface)
{
   PanelShape shape;
   Rectangle  rect;
   Color      color; // material color overrides this color
   Color      selected_color; // for gui editor functionality
   HMaterial* mat;
}

fn void Panel.save(&self, SaveFile* file) @dynamic 
{
    svs::writeInt(file, self.shape);
    svs::writeRect(file, self.rect);
    svs::writeColor(file, self.color);
    // cannot save pointers
    // cannot save Texture2D's because they are saved on GPU memoru
    // TODO(HM) turn textures into a asset that can be saved and reloaded...
}

fn void Panel.reload(&self, SaveFile* file) @dynamic 
{
    int value;
    svs::readInt(file, &value);
    self.shape = PanelShape.from_ordinal(value);
    svs::readRect(file, &self.rect);
    svs::readColor(file, &self.color);
}

fn void Panel.initRec(&self, Rectangle rect, Color color) @inline
{
    self.rect  = rect;
    self.color = color;
    self.mat   = null;
}

fn void Panel.initV(&self, Vec2f pos, Vec2f size, RColor color) @inline
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

    @param w_scaler : "vector to scale the panel horizontally, from 0.05f to INF"
    @param h_scaler : "vector to scale the panel verticaly, from 0.05f to INF"
    @require w_scaler >= 0.05f && h_scaler >= 0.05f
*>
fn void Panel.scale(&self, float w_scaler, float h_scaler) @inline 
{
    if( w_scaler >= 0.05f && w_scaler < 0.06f &&
        h_scaler >= 0.05f && h_scaler < 0.06f )
    {
        lgr::warning(Where.FILE, "scaled a panel to almost invisible size! Was that desired?");
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
    self.rect.width  *= w_scaler;
    self.rect.height *= h_scaler;
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


fn void Panel.setMaterial(&self, String material_name) @inline 
{
    self.mat = mtrmng::getMaterial(material_name);
}

fn bool Panel.asMaterial(&self) @inline => self.mat != null;

fn void Panel.fadeIn(&self, float factor) {
    self.color = rl::colorLerp(self.color, rl::WHITE, factor);
}

fn void Panel.fadeOut(&self, float factor) {
    self.color = rl::colorLerp(self.color, misc::INVISIBLE_COLOR, factor);
}

fn bool Panel.isValid(&self) @inline {
    if(self.rect.width  >= MIN_PANEL_SIZE && 
       self.rect.height >= MIN_PANEL_SIZE ) return true;
       
    return false;
}

fn void Panel.draw(&self, bool selected = false)
{
    if(self.asMaterial())
    {
        // TODO(HM) find how to draw a image on a rounded rectangle!?

        Texture2D* texture = &self.mat.diffuse.tex;
        Vec2f texture_size = { texture.width, texture.height };
        Rectangle source = { 0, 0, texture_size.x, texture_size.y };
        Rectangle* dist = &self.rect;

        Color color = (selected) ? self.selected_color : self.mat.diffuse.color;

        BlendMode blending;
        switch (self.mat.coverage)
        {
            case MatMC.OPAQUE: break; // do nothing here
            case MatMC.PERFORATED:
                blending = BlendMode.ALPHA;
            case MatMC.TRANSLUCENT:
                blending = BlendMode.ALPHA_PREMUL;
                if(color.a >= 1.0f)
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
            case MatMC.BAD:
                lgr::error(Where.FILE, "Panel with material %s has a bad material coverage type.", self.mat.name);
                unreachable();
        }

        switch (blending)
        {
            case BlendMode.ALPHA:
            case BlendMode.ALPHA_PREMUL:
                rl::@blendMode(blending)
                {
                    rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
                };
            default: // opaque unless the image has invisible pixels...
                // NOTE(HM) center of the texture (rotation/scale point), 
                // it's relative to destination rectangle dimentions, not the screen dimentions.
                rl::drawTexturePro(*texture, source, *dist, {0, 0}, 0.0f, color);
        }
    } else {
        switch(self.shape)
        {
            case BOX:         r2d::@drawRect(self.rect, (selected) ? self.selected_color : self.color);
            case ROUNDED_BOX: r2d::drawRectangleRounded(self.rect, 0.65f, 6, (selected) ? self.selected_color : self.color);
            default: unreachable();
        }
    }
}

//////////////// ******** WIDGET'S ******** ////////////////////////

// NOTE(HM) Widget is a data structure representing anything inside a gui, like buttons and such.


struct WidgetFlags 
{
    union {
        bool isHidden;
        bool should_hide;
    }
    bool wasInteractive;
    bool isInteractive;
    bool asFocus;
    bool selected;  // for the editor
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
    fn void addTo(Desktop*);
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

const KIND_TEXT      = 1;
const KIND_BUTTON    = 2;
const KIND_CONTAINER = 3;

alias WidgetCallback = fn void(Widget*);

struct Widget (WidgetInterface) 
{
    // extends Panel (super/base class)
    inline Panel super;
    
    int id;  // used to uniquily identify each widget on a gui
    String name;
    //int layer;
    int kind;
    WidgetFlags flags;

    // for binding
    struct parent {
        Desktop* desktop;
        Widget* other;
    }
    // for linking
    Widget* next; // for linked list of widgets

    // callbacks
    WidgetCallback onOver;
    WidgetCallback onStopOver;
    WidgetCallback onPress;
    WidgetCallback onPressed;
    WidgetCallback onSinglePress;
    WidgetCallback onDoublePress;
    WidgetCallback onRelease;
    WidgetCallback onEnterKey;
}

fn void Widget.init(&self) @dynamic {
    self.super.init();
}

fn void Widget.deinit(&self) @dynamic{
    self.unlink();
    self.unbind();
    self.parent.desktop = null;
    self.super.deinit();
}

fn void Widget.editor_interactions(&self) @local
{
    // cannot select widgets that are not visible
    // todo(HM) make a force visible flag for edit mode?
    if (self.hidden()) return;
    // when in gui edit mode, we can select widgets with the mouse
    // and they should all be set to not interactive, as that is part of
    // the gui logic and the editor doesn't care what widget is interactive
    // or not, no matter their state all should be selectable.
    if (self.isInteractive()) return;
    
    if (self.asFocus())
    {
        if (input::Action* action = input::getAction("editor_select")) {
            if(action.fnIsTriggered()) self.select();
        }
    }
}

fn void Widget.update(&self) @dynamic {
    if(self.hidden() && !editor_enabled()) return;

    if (self.isMouseOver()) {
        self.flags.asFocus = true;
    } else {
        self.flags.asFocus = false;
    }
    
    if(editor_as_focus()) 
    {
        self.flags.asFocus = false;

        if(self.isInteractive()) {
            self.setInteractive(false);
        }
        self.editor_interactions();
    } else {
        if(!self.isInteractive() && self.flags.wasInteractive) self.setInteractive(true);
    }
    
    if(self.bound()) {
        // if bound our position is updated to always be relative to the parent origin
        Vec2f parent_origin = self.parent.other.getPosition();
        //self.setPositionV(self.getPosition() + parent_origin);
        Vec2f new_offset    = (self.getPosition() + parent_origin) - parent_origin;
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

// Function to calculate the color based on time
fn Color selected_color_anim(Widget* wgt) @inline @local
{
    if(!wgt) return {0, 0, 0, 1};
    
    assert(wgt.parent.desktop != null);
    int time = wgt.parent.desktop.time;
    int flicker_milliseconds = 200;
    
    Color color;
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
* @param [in] wgt : "widget to draw the origin coordinates for"
* @require wgt != null
*>
fn void Widget.draw_origin_coordinates(Widget* wgt) @local @inline 
{
    if(!wgt.selected()) return;
    
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
    r2d::drawLineEx(widget_center.toVector2(),
        (widget_center + misc::VEC_LEFT * (scr_w - widget_center.x)).toVector2(),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center.toVector2(),
        (widget_center + misc::VEC_RIGHT * (scr_w - widget_center.x)).toVector2(),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center.toVector2(),
        (widget_center + misc::VEC_UP * (scr_h - widget_center.y)).toVector2(),
        lineThick, rl::RED
    );
    r2d::drawLineEx(widget_center.toVector2(),
        (widget_center + misc::VEC_DOWN * (scr_h - widget_center.y)).toVector2(),
        lineThick, rl::RED
    );
}

fn void Widget.draw(&self) @dynamic 
{
    if(self.hidden()) return;
    
    if(self.selected())
    {
        self.setSelectedColor(selected_color_anim(self));
        self.draw_origin_coordinates();
    }
    
    self.super.draw(self.selected());
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

    Vec2f mouse_size = main::getGameCursorSize() * 0.5f; // half size of the cursor
    Rectangle mouseRect = misc::@recFromVecs(mouseWorldPos, mouse_size);

    if (rl::checkCollisionRecs(mouseRect, self.rect)) return true;

    return false;
}

fn bool Widget.isWithinScreenBounds(&self) @dynamic
{
    //if (self.hidden()) return false;

    Rectangle screen_bounds = {
    .x      = 0,
    .y      = 0,
    .width  = main::gpGame.screen.w,
    .height = main::gpGame.screen.h
    };

    return rl::checkCollisionRecs(screen_bounds, self.rect) ? true : false;
}

<*
* @param [in] desktop : "parent desktop"
* @require desktop != null
*>
fn void Widget.addTo(&self, Desktop* desktop) @dynamic {
    self.parent.desktop = desktop;
    if (self.parent.desktop.isInteractive) {
        self.flags.wasInteractive = true;
        self.setInteractive(true);
    }

    self.id = (int)self.parent.desktop.children.len() + 1;
    
    // concatenate with desktop name
    if (self.id < 10) {
        self.name = string::tformat("%s_%s%d", self.parent.desktop.name, self.name.tconcat("0"), self.id);
        if (self.bound()) {
            self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.name, self.name.tconcat("0"), self.id);
        }
    } else {
      self.name = string::tformat("%s_%s%d", self.parent.desktop.name, self.name, self.id);
      if (self.bound()) {
          self.name = string::tformat("%s_%s_%s%d", self.parent.desktop.name, self.parent.other.name, self.name, self.id);
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
* @param [in] other : "parent widget"
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

fn void Widget.setSelectedColor(&self, Color color) @dynamic {
    self.super.selected_color = color;
}

// editor functions
fn void Widget.select(&self) @inline @local
{
    if(self.flags.selected) return;
    
    self.flags.selected = true;
    //lgr::info(Where.CONSOLE, "Selected: %s", self.name);
}

fn void Widget.deselect(&self) @inline @local
{
    if(!self.flags.selected) return;
    
    self.flags.selected = false;
}

fn bool Widget.selected(&self) @inline @local => self.flags.selected;

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
    inline Widget super;

    String text;
    int text_len;
    // todo use a font
    int font_size;
    Color text_color;
    WidgetTextAlign align;
}


fn void WidgetText.init(&self) @inline 
{
    self.super.init();
    self.name = "TextLabel";
    self.setColor({0, 0, 0, 0});
    self.kind       = KIND_TEXT;
    self.font_size  = 20; //@hardcode
    self.text_color = rl::WHITE; //@hardcode
    self.align      = WidgetTextAlign.CENTER;
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

fn int WidgetText.textlen(&self) @inline {
    return rl::measureText(self.text.zstr_tcopy(), self.font_size);
}

fn float WidgetText.textlenf(&self) @inline {
    return (float)rl::measureText(self.text.zstr_tcopy(), self.font_size);
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
* @param [in] menu : "desktop where this widget will live"
* @require menu != null
* @ensure return != null
*>
fn WidgetText* createLabel(String name, String text, Color text_color, Desktop* menu) {
    WidgetText* label = mem::new(WidgetText);
    label.init();
    label.name = label.name.tconcat(text);
    label.addTo(menu);
    // labels shouldn't be interactive (to save perf...)
    label.flags.wasInteractive = false;
    label.setInteractive(false);
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
* @param [in] desk : "desktop where this widget will live"
* @require desk != null
*>
fn void WidgetButton.init(&self) @inline 
{
    self.super.init();
    self.kind = KIND_BUTTON;
    self.name = "Button";
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

fn void WidgetButton.manage_interactions(&self) @local 
{
    if (self.isInteractive() == false) return;

    //main::lgr::info(Where.CONSOLE, "Gui: I'm over button: %s", self.name);
    if (self.asFocus() && self.flags.selected == false)
    {
        if(self.onOver) self.onOver(self);

        if (rl::isMouseButtonDown(MouseButton.LEFT) && self.press_count >= 1) {
            //main::lgr::info(Where.CONSOLE, "Gui: I'm pressing button: %s", self.name);
            if (self.onPress) self.onPress(self);
        }
        
        if (Action* action = input::getAction("Double Press")) {
            if (action.fnDoubleTriggered(0.250f) && self.onDoublePress) self.onDoublePress(self);
        }
        
        if (Action* action = input::getAction("Single Press")) {
            if (action.fnBecameTriggered() && self.onSinglePress) self.onSinglePress(self);
            // if(action.fnBecameTriggered()) {
                // String[] array = {"apple", "banana", "apple", "orange", "banana"};
                // int size = array.len;
                // input::detect_duplicates(array, size);
            // }
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
* @ensure return != null
*>
fn WidgetButton* createButton() @inline {
    WidgetButton* button = mem::new(WidgetButton);
    button.init();
    return button;
}

//////////////////////////////////// CONTAINER //////////////////////////////////////

alias ContainerQueue = List{any};

const uint TOP_TO_BOTTOM = 1;
const uint BOTTOM_TO_TOP = 2;
const uint LEFT_TO_RIGHT = 3;
const uint RIGHT_TO_LEFT = 4;

struct ContainerParams @packed
{
    uint direction;
    Color background;
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
        Color color;
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

<*
* @param [in] desk : "desktop where this widget will live"
* @require desk != null
*>
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

    self.kind = KIND_CONTAINER;
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
                    rl::drawLineEx( start.toVector2(), end.toVector2(), 
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

    Music music_stream; // any music stream that we may want to attach to a desktop
    
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

// todo init this from a svg file
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
            // switch (child.type) 
            // {
            //     case WidgetButton.typeid:
            //     case WidgetText.typeid:
            //     case WidgetContainer.typeid:
            //         child.ptr.deinit();
            //     default:
            //         unreachable("unkown gui widget typeid");
            // }
        }
    }

    if(rl::isMusicValid(self.music_stream)) {
        // todo fade out the music stream
        if(rl::isMusicStreamPlaying(self.music_stream)) rl::stopMusicStream(self.music_stream);
        rl::unloadMusicStream(self.music_stream);
    }
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
                case KIND_BUTTON:
                    ((WidgetButton*)child).hide(); 
                case KIND_TEXT:
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
                case KIND_BUTTON:
                    ((WidgetButton*)child).show(); 
                case KIND_TEXT:
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
    
	if ( self.isInteractive ) {
		if(main::game_cursor_hidden()) main::show_game_cursor();
	} else {
		if(main::game_cursor_visible()) main::hide_game_cursor();
	}
}

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
                case KIND_CONTAINER:
                    ((WidgetContainer*)child).update();
                default:
                   ((Widget*)child).update(); 
            }
        }
    }

    if(rl::isMusicValid(self.music_stream)) {
        rl::updateMusicStream(self.music_stream);
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
                case KIND_BUTTON:
                    ((WidgetButton*)child).draw();
                case KIND_TEXT:
                    ((WidgetText*)child).draw();
                case KIND_CONTAINER:
                    ((WidgetContainer*)child).draw();
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
        lgr::warning(Where.CONSOLE, "Cannot get child %d from %s because is null.", id, self.name);
        return null;
    }
    return child;
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
               if(child.selected()) continue;
               
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
DesktopManager* gpDeskManager = &local_manager;

<*
* @param [in] desk : "the desktop to register"
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
* @param [inout] _desk : "the desktop to remove"
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

    /*if(ui_editGui.getBool()) {
        // enable edit mode
        if(self.mode != EDITOR) self.editor(true);
    } else {
        // disable edit mode
       if(self.mode == EDITOR) self.editor(false);
    }*/
    self.editor(ui_editGui.getBool());

    usz desktop_count = self.desktops.len();
    if(desktop_count >= 1) {
        foreach(desk: self.desktops) {
            if(desk.active) {
                desk.update();
                if(self.mode == EDITOR && !main::gpGame.editor.focused()) {
                    updateGuiEditor(desk);
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
// NOTE(HM) TODO(HM) move this to a better place, like a gui editor file
// @deprecated 
// this should be renamed to something like gui_editor because we already have a editor in the game
// #region ***************************** GUI EDITOR ****************************

const GUIE_MAJOR    = 0;
const GUIE_MINOR    = 1;
const GUIE_REVISION = 0;

macro bool drawEditorButton(String text, Vector2 pos) @local
{
    return rgui::button({pos.x, pos.y, 120, 30}, string::tformat("#191#%s", text).zstr_tcopy());
}

fn void editor_open() @inline {
    if(main::gpGame.guiActive == null) {
        lgr::error(Where.CONSOLE, "Cannot open gui editor because no gui is active.");
        return;
    }
    ui_editGui.set("1");
}

fn void editor_close() @inline {
    ui_editGui.set("0");
    if(editor_is_widget_debug_on()) editor_disable_widget_debug();
}

fn bool editor_is_opened() @inline {
    return ui_editGui.getBool();
}

fn void editor_enable_widget_debug()  @local @inline => ui_debugDraw.set("1");
fn void editor_disable_widget_debug() @local @inline => ui_debugDraw.set("0");
fn bool editor_is_widget_debug_on()   @local @inline => ui_debugDraw.getBool();

fn bool editor_enabled() @inline => local_manager.mode == EDITOR;
fn bool editor_as_focus() @inline {
    return (editor_enabled() && main::gpGame.editor.focused());
}

fn void editor_move_selected(Widget* wgt)
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

fn void updateGuiEditor(Desktop* mng) 
{
    if(!mng || editor_enabled() == false) return;
    
    foreach(wgt : mng.children) 
    {
        if(wgt.selected()) {
            if(rl::isKeyPressed(rl::KEY_ESCAPE)) {
                wgt.deselect();
            } else {
                editor_move_selected(wgt);
            }
        }
    }
}

fn void drawGuiEditor(Desktop* mng) 
{
    if(!mng || editor_enabled() == false) return;
    
    int scr_w, scr_h;
    scr_w = main::gpGame.screen.w;
    scr_h = main::gpGame.screen.h;
    
    float left_marging = 0.025f * scr_w;
    float top_margin   = 0.05f  * scr_h;
    
    String editor_version = string::tformat("GUI EDITOR v: %s.%s.%s", GUIE_MAJOR, GUIE_MINOR, GUIE_REVISION);
    rgui::label({left_marging, top_margin, 120, 30}, editor_version.zstr_tcopy());
    
    // gui debug on off
    if(drawEditorButton("Gui Debug", {left_marging, top_margin * 2})) {
        if(editor_is_widget_debug_on()) {
            editor_disable_widget_debug();
        } else {
            editor_enable_widget_debug();
        }
    }
    
     // gui saving 
    if(drawEditorButton("Gui SAVE", {left_marging, top_margin * 3})) {
         lgr::info(Where.CONSOLE, "Trying to save gui \"%s\" but that is still not possible.", mng.name);
    }
    
    // close editor
    if(drawEditorButton("Gui CLOSE", {left_marging, top_margin * 4})) {
        editor_close();
    }
}

// end_region GUI EDITOR **************************





