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
module engine::svgui;

// region modules
import std::io;
import engine::sys::reader::svg;
import game::assets::sprt;
import thirdparty::library::xml;
import engine::filesystem::fs;
import engine::gui;
import std::math;
import std::collections::list;
import engine::misc;
import engine::input;
import game::material::mtr;
import game::material::manager::mtrmng;
import engine::logging::lgr;
import game::main;
import game::serialize::svs; // save system
import engine::sys::cvar;
import thirdparty::raylib5::rl;
import engine::sys::render2d::r2d; // 2D rendering
// end_region


///////////////////////////////////////////////////////////////////////////
//
//                                  Desktop
//
///////////////////////////////////////////////////////////////////////////
/*
struct SVGUI_Id @compact
{
    String id;
    int index; // used to identify the widget in the desktop
    int padding; // used to pad the id to a fixed size
}

struct SVGUI_Group
{
    SVGUI_Id id;
    Matrix3f transform;
}

struct SVGUI_Rectangle 
{
    Color color;
    SVGUI_Id id;
    Rectangle rect;
}

struct SVGUI_Ellipse 
{
    Color color;
    SVGUI_Id id;
    Vec2f center;
    Vec2f radius;
}

struct SVGUI_Path 
{
    Color color;
    SVGUI_Id id;
    List{Vec2f} points; // list of points that make up the path
    // TODO(HM) add more properties like stroke width, fill color, etc.
}

struct SVGUI_Image
{
    inline SVGUI_Rectangle rect; // rectangle to draw the image
    String image_path; // path to the image file
    HMaterial* mat; // material to use for the image
}
*/

// TODO(HM) turn this basic shapes into real widgets
struct UserInterface 
{
    String path;
    Desktop desktop; // the desktop that contains the user interface
    List{any} widgets; // list of groups in the user interface
}

<*
    @param [in] widget : "elem to register in user interface data"
    @require widget != null
*>
fn void UserInterface.register(&self, any widget) @inline 
{
    self.widgets.push(widget);
}

fn  UserInterface* loadUserInterface(String name, String path)
{
    if(path == "") {
        unreachable("user interface path is empty!");
    }

    if(name == "") {
        unreachable("user interface name is empty!");
    }

    // check if the file exists
    File file = fs::openFile(path)!!;
    defer file.close()!!;
    if(file.file == null) {
        unreachable("Failed to open svg file '%s'", path);
    }

    XmlDoc* xmlfile = xml::read_file(file)!!;
    defer xmlfile.free();
    if(xmlfile == null) {
        unreachable("Failed to read svg (xml) file '%s'", path);
    }

    if(xmlfile.rootNode.name != "svg")
    {
       // The root element of an SVG file should be 'svg'
       // If it's not, then the file is invalid.
       unreachable("Invalid svg file '%s', root element should be 'svg' but is '%s' instead.", path, xmlfile.rootNode.name);
    }

    if(xmlfile.rootNode.children.len() == 0) {
        unreachable(" Invalid svg file '%s', root <%s> has no children!", path, xmlfile.rootNode.name);
    }

    // Parse the SVG file and populate the user interface

    // first parse the root SVG element
    if(xmlfile.rootNode.hasAttributes() == false) {
        unreachable("Invalid svg file '%s', root element has not attributes!", path);
    }

    UserInterface* ui = mem::new(UserInterface);
    ui.path = path.tcopy();
    ui.desktop.init(name);
    ui.desktop.setColor(rl::WHITE); // set default color for the user interface

    //XmlAttribute
    foreach (attr : xmlfile.rootNode.attributes)
    {
       switch (attr.name)
       {
           case "width":
               ui.desktop.rect.width = attr.value.to_float()!!;
               if(ui.desktop.rect.width <= 0) {
                   unreachable("Invalid user interface width '%s' in SVG file '%s'", attr.value, path);
               }
           case "height":
               ui.desktop.rect.height = attr.value.to_float()!!;
               if(ui.desktop.rect.height <= 0) {
                   unreachable("Invalid user interface height '%s' in SVG file '%s'", attr.value, path);
               }
           default:
               io::printfn("Unsupported SVG attribute '%s' in file '%s'", attr.name, path);
       }
    }

    // handle the root SVG element children
    foreach (svg_elem : xmlfile.rootNode.children)
    {
        switch (svg_elem.name)
        {
            case "g": // group element
                // create a new group with the transform
                Widget* group = mem::new(Widget);
                group.init();
                group.name = svg_elem.getAttribute("id").value.tcopy(); // set the group name from the id attribute
                ui.register(any_make(group, Widget.typeid));

                XmlAttribute* group_attr_transform = svg_elem.getAttribute("transform");
                if(group_attr_transform == null) {
                    unreachable("Group element in SVG file '%s' has no transform attribute, using default identity matrix.", path);
                }
                switch (group_attr_transform.value)
                {
                    case "translate(0,0)":
                        // default position, do nothing
                        break;
                        case "matrix":
                            // parse the matrix transform// parse the transform attribute and apply it to the group
                            Matrix3f transform = parseMatrixTransform(group_attr_transform.value);
                            Vec2f position = {transform.m02, transform.m12}; // extract the translation part of the matrix
                            group.setPosition(position.x, position.y); // set the position from the transform
                    default:
                        // Unsupported transform, log a warning and use default position
                        io::printfn("Unsupported transform '%s' in SVG file '%s', using default position.", group_attr_transform.value, path);

                        
                }
            case "rect": // rectangle element
            {
                String id = svg_elem.getAttribute("id").value;
                switch
                {
                    case id.starts_with("rect_"):
                        Widget* rect = mem::new(Widget);
                        rect.name = id.tcopy();
                        ui.register(any_make(rect, Widget.typeid));
                        parse_rect_attributes(svg_elem, rect, ui.path);
                    case id.starts_with("button_"):
                        ui.createButton(svg_elem, id, ui.path);
                    default:
                        unreachable("Unsupported rectangle element '%s' in SVG file '%s'. Only 'rect_' and 'button' prefixed rectangles are supported.", id, path);
                }
            }
            default:
                // Ignore other types of nodes
                continue;
        }
    }
    //elem.name = xmlnode.name.copy(mem);
    // svgfile.register(elem);
    
    // // handle attributes if any
    // if(svgElemNode.attributes.len())
    // {
    //     parse_SVGElemNode_attributes(svgElemNode, elem, svgfile);
    // }

    // if(svgElemNode.children.len())
    // {
    //     foreach (node : svgElemNode.children)
    //     {
    //         if(node == null || node.isNode(ElemID.INVALID)) continue;
    //         register_SVGElemNode_data((SVGElemNode*)node, svgfile);
    //     }
    // }
    
    return ui;
}


/*
struct Matrix3x3
{
	union
	{
		struct
		{
			Real m00, m01, m02;
			Real m10, m11, m12;
			Real m20, m21, m22;
		}
		Real[9] m;
	}
}
*/

fn Matrix3f parseMatrixTransform(String transform_str) @inline
{
    //matrix(a, b, c, d, tx, ty)

    String[] parts = transform_str.trim_left("matrix(").transform_str.trim_right(")").transform_str.split(",");
    int a, b, c, d, tx, ty;
    a = parts[0].to_float()!!;
    b = parts[1].to_float()!!;
    c = parts[2].to_float()!!;
    d = parts[3].to_float()!!;
    tx = parts[4].to_float()!!;
    ty = parts[5].to_float()!!;
    Matrix3f result = {
        a,    c,    tx,
        b,    d,    ty,
        0.0f, 0.0f, 1.0f
    };
    return result;
}

fn void parse_rect_attributes(XmlNode* svg_elem, Widget* widget, String path) @inline
{
    // parse the rectangle attributes and set the rectangle properties
    XmlAttribute* width_attr  = svg_elem.getAttribute("width");
    XmlAttribute* height_attr = svg_elem.getAttribute("height");
    if(width_attr == null || height_attr == null) {
        unreachable("Rectangle element in SVG file '%s' has no width or height attributes.", path);
    }
    widget.rect.width  = width_attr.value.to_float()!!;
    widget.rect.height = height_attr.value.to_float()!!;

    XmlAttribute* x_attr = svg_elem.getAttribute("x");
    XmlAttribute* y_attr = svg_elem.getAttribute("y");
    if(x_attr != null && y_attr != null) {
        widget.setPosition(x_attr.value.to_float()!!, y_attr.value.to_float()!!);
    } else {
        widget.setPosition(0.0f, 0.0f); // default position
    }

    // handle fill color
    XmlAttribute* style = svg_elem.getAttribute("style");
    if(style != null) {
        widget.color = getColorFromStyle(style.value.split(";"));
    } else {
        widget.color = rl::WHITE; // default color
    }
}

fn Color getColorFromStyle(String[] styles) @inline
{
    foreach (style : styles)
    {
        if(style.starts_with("fill:")) {
            String color_str = style.trim_left("fill:");
            return getColorFromSVGHex(color_str);
        }
    }
    return rl::WHITE; // default color if no fill style is found
}

fn Color getColorFromSVGHex(String hex) @inline
{
    if(hex.length() != 6) {
        unreachable("Invalid color string '%s', expected format is '#RRGGBB'.", color_str);
    }

    // Convert a hex color string to a Color object
    String color_str = color_str.trim_left("#");
    uint hex_color = ("0x".concat(color_str)).toUInt()!!;
    return rl::getColor(hex_color);
}

macro UserInterface.createButton(&self, XmlNode* node, String id, String path) @local 
{
    /*
        style="fill:#8f878c;"
        width="13.893263"
        height="11.11898"
        x="33.640884"
        y="63.73539" 
    */
    WidgetButton* button = gui::createButton();
    button.name = id.tcopy();
    button.addTo(self.desktop);
    defer ui.register(any_make(button, WidgetButton.typeid));
    
    parse_rect_attributes(svg_elem, (Widget*)button, path);

    // Todo set this extra button properties
    button.setDefaultColor(bdef.default_color);
    button.setOverColor(bdef.over_color);
    //
    float button_width  = bdef.size.x;
    float button_height = bdef.size.y;
    int label_count;
    foreach(widget : self.widgets)
    {
        if(widget.type == WidgetText.typeid) {
            label_count++;
        }
    }
    String label_name   = id.concat(string::tformat("_label%s", label_count));
    Color label_color   = rl::DARKGRAY; // default label color
    WidgetText* label   = gui::createLabel(label_name, button.name, label_color, self.desktop);
    Vec2f label_offset  = button.rect.getPosition();
    label_offset += misc::VEC_RIGHT * self.desktop.rect.width * 0.5f;
    label_offset -= {button.rect.width / 2.0f, 0.0f};
    label_offset += misc::VEC_DOWN * (self.desktop.rect.height / button.rect.height) * 10;
    //label.setFontSize(60);
    label.setPositionV(label_offset);
    label.addToPosition(
       x: 0.5f * button.rect.width - (float)label.textlen() / 2,
       y: 0.5f * button.rect.height - ((button.rect.height / 2) * 0.5f)
    );
    label.bindTo(button);
    // callbacks
    // TODO(HM) add callbacks for the button
    //button.onOver        = &button_onOver;
    //button.onStopOver    = &button_onStopOver;
    //button.onPress       = &start_button_onPress;
    //button.onSinglePress = &start_button_onSinglePress;
    //button.onRelease     = &button_onRelease;
    //button.onDoublePress = &button_onDoublePress;
}