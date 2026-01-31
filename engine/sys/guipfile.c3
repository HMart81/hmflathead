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
// UNFINISHED!!!

module engine::sys::guipfile::guip;

import std::io, std::math, std::collections::list, std::io::path;
import thirdparty::library::xml;
import thirdparty::raylib5::rl;
import engine::filesystem::fs;
import engine::logging::log;
import engine::misc;
import game::main;
import std::ascii;

// ******************************************************************************
// NOTE(HM) This module handles the loading and parsing of .guip files
// this custom file format is similar to svg files but much simpler and easier to parse
// is used to define GUI elements and their properties
// ******************************************************************************

faultdef MALFORMED_GUIP_FILE,
         GUIP_PARSING_ERROR,
	     GUIP_LOAD_ERROR,
	     GUIP_READ_ERROR,
         GUIP_VALUE_ERROR,
	     MISSING_GUIP;

// enum ElemID : int (inline String str)
// {
//     INVALID             = "",     // not really a real svg element just used to mark invalid elements
//     VERSION             = "guipVersion",
//     PATH                = "path",
//     NUM_ELEM            = "numElements",
//     GUI                 = "gui",
//     RECT                = "rect",
//     GROUP               = "group",
//     ELLIPSE             = "ellipse",
//     IMAGE               = "image"
// }

alias GUIPFile = File;

const FILE_SIGNATURE @local = "GUIP";
const FILE_VERSION   @local = 1;

alias TransformKind = String;
const TransformKind TRANSFORM_NONE      = "none";
const TransformKind TRANSFORM_ROTATE    = "rotate";
const TransformKind TRANSFORM_TRANSLATE = "translate";
const TransformKind TRANSFORM_SCALE     = "scale";
const TransformKind TRANSFORM_MATRIX    = "matrix";

struct RLTransform
{
    TransformKind kind; // the kind of transform, like translate, rotate, scale, etc.
    union {
        Vec2f translation; // the translation vector, used for translate and scale
        Vec2f rotation; // the rotation vector, used for rotate
        Vec2f scale; // the scale vector, used for scale
    }
    Matrix4f matrix; // the matrix transform, used for matrix
}

struct GUIPElement
{
    typeid type; // the type of element
    String name; // the node id, this is used to identify the element in the guip file
    RLColor color; // the color of the element
    RLTransform transform; // the transform of the element, like translate, rotate, scale, etc.
}

fn void GUIPElement.init(&self)
{
    self.type = GUIPElement.typeid;
    self.color = rl::WHITE; // default color is white
    self.transform.scale = {1.0f, 1.0f}; // sets translation and rotation to the same value.
    self.transform.matrix = math::MATRIX4F_IDENTITY;
}

fn GUIPElement* createElement(String _name = "<noname>") {
    return mem::new(GUIPElement, {
        .type = GUIPElement.typeid,
        .name = _name,
        .color = rl::WHITE,
        .transform.scale = {1.0f, 1.0f},
        .transform.matrix = math::MATRIX4F_IDENTITY
    });
}

struct GUIPElement_Group
{
    inline GUIPElement super;

    ListOfElements elements; // the elements inside the group
}

fn void GUIPElement_Group.init(&self)
{
    self.super.init();
    self.type = GUIPElement_Group.typeid;
}

fn void GUIPElement_Group.register(&self, GUIPElement* elem)
{
    self.elements.push(elem);
}

struct GUIPElement_Rect
{
    inline GUIPElement super;

    RLRectangle rect; // the rectangle of the element
}

fn void GUIPElement_Rect.init(&self)
{
    self.super.init();
    self.type = GUIPElement_Rect.typeid;
}

struct GUIPElement_Path
{
    inline GUIPElement super;

    String data; // the path of the element
}

fn void GUIPElement_Path.init(&self)
{
    self.super.init();
    self.type = GUIPElement_Path.typeid;
}

struct GUIPElement_Ellipse
{
    inline GUIPElement_Rect super;
}

fn void GUIPElement_Ellipse.init(&self)
{
    self.super.init();
    self.type = GUIPElement_Ellipse.typeid;
}

struct GUIPElement_Image
{
    inline GUIPElement super;

    String path; // the path to the image file
    RLRectangle rect; // the rectangle of the image
}

fn void GUIPElement_Image.init(&self)
{
    self.super.init();
    self.type = GUIPElement_Image.typeid;
}

////////////////////////////////////////////////////////////////////////////////////
// NOTE(HM) this is the main struct that holds all the parsed guip file data

alias ListOfElements = List{GUIPElement*};

struct GUIPStructure
{
    int version; // the guip file version
    String path; // the path to the guip file
    ListOfElements elements; // the elements in the guip file
}

<* 
    @param [&in] elem : "elem to register in guip structure"
*>
fn void GUIPStructure.register(&self, GUIPElement* elem) @inline
{
    self.elements.push(elem);
}

fn void GUIPStructure.freeElements(&self)
{
    if(self.elements.len())
    {
        // free all child elements own data
        foreach(elem: self.elements) { mem::free(elem); }
        // now free our elements list
        self.elements.free();
    }
}

fn GUIPElement* GUIPStructure.findElementByName(&self, String name) @inline
{
    foreach(elem: self.elements) 
    {
        if(elem.name == name) return elem;
    }
    
    log::error(Where.FILE, "Failed to find element '%s' in guip file '%s'", name, self.path);
    return null;
}

fn GUIPElement* GUIPStructure.findElementByType(&self, typeid type) @inline
{
    foreach(elem: self.elements) 
    {
        if(elem.type == type) return elem;
    }
    
    log::error(Where.FILE, "Failed to find element of type '%s' in guip file '%s'", type, self.path);
    return null;
}

fn bool? GUIPStructure.load(&self, String path)
{
    if(path == "") {
        log::warning(Where.FILE, "GUIP file path was empty, cannot load guip file data!");
        return MISSING_GUIP~;
    }
    self.path = path;

    String file_data = fs::readEntireFileX(self.path)!;
    if(file_data == "") {
        log::error(Where.FILE, "Failed to read data from guip file '%s'", self.path);
        return GUIP_READ_ERROR~;
    }

    //self.parse(file_data)!;
    
    return true;
}

/*
<*
    @param [in] data : "the guip file data to parse"
    @require data.len > 0
*>
fn bool? GUIPStructure.parse(&self, String data) @local
{
    if(data == "") {
        log::error(Where.FILE, "Invalid guip file '%s', no data found!", self.path);
        return GUIP_PARSING_ERROR~;
    }

    String[] lines = data.tsplit("\n");

    foreach(line: lines)
    {
        line = line.trim();
        if(line.starts_with("//") || line == "") continue; // skip comments and empty lines

        String[] words = line.tsplit(" ");
        if(parts.len < 2) {
            log::error(Where.FILE, "Invalid guip file '%s', line '%s' is malformed!", self.path, line);
            return false;
        }

        switch(parts[0])
        {
            case "version":
                self.version = parts[1].to_int()!;
            case "numElements":
                self.num_elements = parts[1].to_int()!;
            case "element":
                // TODO(HM) parse the element data
                break;
            default:
                log::warning(Where.FILE, "Unknown guip file directive '%s' in file '%s'", parts[0], self.path);
        }
    }

    return true;
}











/*
enum AttrType : char
{
    INT,
    FLOAT,
    STRING,
    VEC2,
    VEC3,
    VEC4,
    FILE_PATH,
    URL
}

// NOTE(HM) this is the attribute struct that holds each SVGElement attribute data
struct SVGAttribute
{
    AttrType type;
    AttrID id;

    struct value
    {
        union {
             union {
                int i;
                float f;
            }
            Vec2f v2;
            Vec3f v3;
            Vec4f v4; // this one sets the real union size
        }

        String s;
        SVGElement* pelem; // this is used for url(#element_id) support
    }
}

alias ListOfPaths    = List{Path*};

struct SVGElemID 
{
    ElemID kind; // the kind of element
    String name; // the node id, this is used to identify the element in the svg file
}

// NOTE(HM) this represents a single svg element, it can be a group, a path, a circle, etc
struct SVGElement
{
    SVGElemID id;
    ListOfAttributes attributes;
    ListOfPaths paths;
}

<* 
    @param [in] atrb : "attribute to register in the element"
    @require atrb != null
*>
fn void SVGElement.register(&self, SVGAttribute* atrb) @inline
{
    self.attributes.push(atrb);
}

fn SVGAttribute* SVGElement.getAttrib(&self, AttrID id) @inline
{
	foreach(atrb: self.attributes) {
		if(atrb.id.ordinal == id.ordinal) return atrb;
	}
    
	return null;
}

fn SVGAttribute* SVGElement.findAttrib(&self, AttrType type) @inline
{
	foreach(atrb: self.attributes) {
		if(atrb.type == type) return atrb;
	}
    
	return null;
}

fn void SVGElement.free(&self) @inline
{
    self.id.kind = ElemID.INVALID; // mark as invalid
    self.id.name.free(mem);
    if(self.attributes.len()) self.attributes.free();
    if(self.paths.len()) self.paths.free();
}


//////////////////////////////////////////////////////////////////////
// Runtime SVG File Data
//////////////////////////////////////////////////////////////////////

// NOTE(HM) this is the file type we use to read svg files
typedef SVGFile = inline XmlDoc;
typedef SVGElemNode = inline XmlNode;
typedef SVGElemNodeAttribute = inline XmlAttribute;

// NOTE(HM) this is the main struct that holds all the parsed svg file data
struct SVGData 
{
    String path;
    ListOfElements elements;
}

<*
    @param [in] elem : "elem to register in svg data"
    @require elem != null
*>
fn void SVGData.register(&self, SVGElement* elem) @inline 
{
    self.elements.push(elem);
}

fn void SVGData.freeElements(&self)
{
	if(self.elements.len())
    {
        // free all child elements own data
        foreach(elem: self.elements) { elem.free(); }
        // now free our elements list
        self.elements.free();
    }
}

// This will probably be very slow with many materials...
// TODO(HM) make this faster by using a hash table
fn SVGElement* SVGData.findElementByID(&self, String id)
{
	foreach(elem: self.elements) 
    {   
        foreach(atrb: elem.attributes) 
        {
            // check if the element has an id attribute
            if(atrb.id == AttrID.ID && atrb.value.s == id) 
            {
                return elem;
            }
        }
	}

    log::error(Where.FILE, "Failed to find element '%s' in svg file '%s'", id, self.path);
	return null;
}

fn SVGElement* SVGData.findElementByName(&self, String name) 
{
	foreach(elem: self.elements) 
    {
        if(elem.id.name == name) return elem;
        // check if the element has url attribute, like url(#element_id)
        // and see if it points to the currect element
        SVGAttribute* url_atrb = elem.getAttrib(AttrID.CLIPPATH);
        while(url_atrb != null) 
        {
            if(url_atrb.value.pelem != null && url_atrb.value.pelem.id.name == name) {
                return url_atrb.value.pelem;
            }
            // try to find another url attribute
            url_atrb = elem.findAttrib(AttrType.URL);
        }
	}

    log::error(Where.FILE, "Failed to find element '%s' in svg file '%s'", name, self.path);
	return null;
}

fn bool? SVGData.load(&self)
{
    if(self.path == "") {
        log::error(Where.FILE, "SVG file path is empty, cannot load svg file data!");
        return SVG_FILE_PATH_EMPTY~;
    }
    // check if the file exists
    File file = fs::openFile(self.path)!;
    defer file.close()!!;
    if(file.file == null) {
        log::error(Where.FILE, "Failed to open svg file '%s'", self.path);
        return SVG_LOAD_ERROR~;
    }

    SVGFile* svg_file = (SVGFile*)xml::read_file(file)!;
    defer svg_file.free();
    if(svg_file == null) {
        log::error(Where.FILE, "Failed to read svg file '%s'", self.path);
        return SVG_LOAD_ERROR~;
    }

    if(self.parse(svg_file) == false) {
        return SVG_PARSING_ERROR~;
    }
    
    return true;
}

<*
    @param [in] doc : "the svg file document to parse"
    @require doc != null
*>
fn bool SVGData.parse(&self, SVGFile* doc) @local
{
    bool invalid_svg = (doc.rootNode.name == "" && doc.rootNode.name != ElemID.SVG);
    if(invalid_svg)
    {
       log::error(Where.FILE, " Invalid svg file '%s', root element should be 'svg' but is '%s' instead.", self.path, doc.rootNode.name);
       return false;
    }

     if(doc.rootNode.children.len() == 0) {
        log::error(Where.FILE, " Invalid svg file '%s', root <%s> has no children!", self.path, doc.rootNode.name);
        return false;
    }

    // create and register all elements and its attributes using recursion
    // starting at and including the root node
    register_SVGElemNode_data((SVGElemNode*)doc.rootNode, self);

    return true;
}

<*
    @param [in] svgElemNode : "the current node we are parsing"
    @param [inout] svgfile : "pointer to the main svg struct to save the element"
    @require svgElemNode != null && svgfile != null
*>
fn void register_SVGElemNode_data(SVGElemNode* svgElemNode, SVGData* svgfile) 
{
    SVGElement* elem = mem::new(SVGElement);
    foreach (elemID : ElemID.values)
    {
        if(svgElemNode.name == elemID.name)
        {
            elem.id.kind = elemID;
            break;
        }
    }
    //elem.name = xmlnode.name.copy(mem);
    svgfile.register(elem);
    
    // handle attributes if any
    if(svgElemNode.attributes.len())
    {
        parse_SVGElemNode_attributes(svgElemNode, elem, svgfile);
    }

    if(svgElemNode.children.len())
    {
        foreach (node : svgElemNode.children)
        {
            if(node == null || node.isNode(ElemID.INVALID)) continue;
            register_SVGElemNode_data((SVGElemNode*)node, svgfile);
        }
    }
}

/*
fn void get_node_Attributes(XmlNode* node, SVGData* svgfile, SVGElement* inElem = null)
{
    SVGElement* elem;
    if(inElem) { elem = inElem; } else { elem = svgfile.getElement(node.name); }

    if(elem)
    {
        foreach (atrb : node.attributes)
        {
            if(atrb == null) continue;
            //elem.register(mem::new(AttrData, {atrb.name.copy(mem), atrb.value.copy(mem)}));
            parse_attribute_data(atrb, elem);
        }
    } else {
        log::error(Where.FILE, " Failed to get attribute data for <%s> in svg file '%s'!!!", node.name, svgfile.path);
        unreachable();
    }
}
*/

enum TransfType : char (inline String str)
{
    NONE      = "none",
    ROTATE    = "rotate",
    TRANSLATE = "translate",
    SCALE     = "scale"
}

<*
    @param [in] svgElemNode : "the node we are looking at"
    @param [inout] elem : "svg SVGElement whose attributes we are creating"
    @param [inout] svgfile : "pointer to the main svg struct to save the element"
    @require svgElemNode != null && elem != null && svgfile != null
*>
fn void parse_SVGElemNode_attributes(SVGElemNode* svgElemNode, SVGElement* elem, SVGData* svgfile) //@inline
{
    /*foreach (atrb : svgElemNode.attributes)
    {
        if(atrb == null) continue;
        foreach (atrbID : AttrID.values)
        {
            if(atrb.name == atrbID.name)
            {
                parse_attribute_data((SVGElemNodeAttribute*)atrb, atrbID, elem, svgfile);
                break;
            }
        }
    }*/
    foreach (atrb : svgElemNode.attributes)
    {
        if(atrb == null) continue;
        parse_attribute_data((SVGElemNodeAttribute*)atrb, elem, svgfile);
    }
}

<*
    @param [in] inAtrb : "the attribute data from the xml file we are looking at"
    @param [inout] elem : "svg Element whose attributes we are looking at"
    @param [inout] svgdata : "pointer to the main svg struct to save the element"
    @require inAtrb != null && inAtrb.value.len > 1 && elem != null && svgdata != null
*>
fn void parse_attribute_data(SVGElemNodeAttribute* inAtrb, SVGElement* elem, SVGData* svgdata)
{
    bool should_register = true;
    SVGAttribute* new_atrb = mem::new(SVGAttribute);
    foreach (atrbID : AttrID.values)
    {
        if(inAtrb.name == atrbID.name)
        {
            new_atrb.id = atrbID;
            elem.id.name = new_atrb.id.name.copy(mem);
            break;
        }
    }
    
    defer { 
        if(should_register) {
            elem.register(new_atrb); 
        } else {
            mem::free(new_atrb);
        }
    }

    switch(new_atrb.id)
    {
        case AttrID.WIDTH:
        case AttrID.HEIGHT:
        case AttrID.VERSION:
        case AttrID.X:
        case AttrID.Y:
        case AttrID.CX:
        case AttrID.CY:
        case AttrID.RX:
        case AttrID.RY:
            if(is_integer_number(inAtrb.value)) {
                new_atrb.type = AttrType.INT;
            } else if(is_float_number(inAtrb.value)) {
                new_atrb.type = AttrType.FLOAT;
            } else {
                nextcase AttrID.INVALID;
            }
        case AttrID.VIEWBOX:
            int count;
            if(is_vector_number(inAtrb.value, &count)) {
                switch(count) {
                    case 1: new_atrb.type = AttrType.VEC2;
                    case 2: new_atrb.type = AttrType.VEC3;
                    case 3: new_atrb.type = AttrType.VEC4;
                }
                break;
            } else {
                nextcase AttrID.INVALID;
            }
        case AttrID.ID:
            new_atrb.type = AttrType.STRING;
        case AttrID.XMLSPACE:
        case AttrID.CLIPPATHUNITS:
        case AttrID.STYLE:
        case AttrID.PRESERVEASPECTRATIO:
            new_atrb.type = AttrType.STRING;
        case AttrID.XMLNSXLINK:
        case AttrID.XMLNS:
        case AttrID.XMLNSSVG:
        case AttrID.XLINKHREF:
            //elem.paths.push(&path::new(inAtrb.value)!);
            new_atrb.type  = AttrType.FILE_PATH;
        case AttrID.TRANSFORM:
            if(inAtrb.value.starts_with("translate") || inAtrb.value.starts_with("scale")) {
                new_atrb.type  = AttrType.VEC2;
            } else if(inAtrb.value.starts_with("rotate")) {
                new_atrb.type  = AttrType.VEC3;
            } else {
                log::warning(Where.FILE,  "Unknown transform value <%s> in file '%s'", inAtrb.value, svgdata.path);
            }
        case AttrID.D:
            new_atrb.type  = AttrType.STRING;
            // todo handle path data...
        case AttrID.CLIPPATH:
            new_atrb.type  = AttrType.URL;
        case AttrID.INVALID:
            log::warning(Where.FILE,  "SVG attrb <%s> in file '%s' is invalid", elem.id.name, svgdata.path);
            should_register = false;
            return;
        default:
            log::warning(Where.FILE,  "SVG attrb <%s> in file '%s' is still not supported", elem.id.name, svgdata.path);
            should_register = false;
            return;
    }

    switch(new_atrb.type) 
    {
        case AttrType.INT:
            if(try value = to_int(inAtrb.value)) {
                new_atrb.value.i = value;
            } else {
                log::warning(Where.FILE, "Failed to convert attribute '%s' value '%s' to int in file '%s'", 
                             elem.id.name, inAtrb.value, svgdata.path);
                should_register = false;
            }
        case AttrType.FLOAT:
            if(try value = to_float(inAtrb.value)) {
                new_atrb.value.f = value;
            } else {
                log::warning(Where.FILE, "Failed to convert attribute '%s' value '%s' to float in file '%s'", 
                             elem.id.name, inAtrb.value, svgdata.path);
                should_register = false;
            }
        case AttrType.STRING:
            new_atrb.value.s = inAtrb.value.copy(mem);
        case AttrType.VEC2:
            if(new_atrb.id == AttrID.TRANSFORM)
            {
                if(inAtrb.value.starts_with("translate")) {
                    new_atrb.value.v2 = get_transform_translation(inAtrb.value);
                } 
                else if(inAtrb.value.starts_with("scale")) {
                    new_atrb.value.v2 = get_transform_scale(inAtrb.value);
                }
                else if(inAtrb.value.starts_with("rotate")) {
                    nextcase AttrType.VEC3;
                } else {
                    log::warning(Where.FILE,  "Unknown transform value <%s> in file '%s'", inAtrb.value, svgdata.path);
                }
            } 
            else 
            {
                 if(try value = to_vec2(inAtrb.value)) {
                new_atrb.value.v2 = value;
                } else {
                    log::warning(Where.FILE, "Failed to convert attribute '%s' value '%s' to vec2 in file '%s'", 
                                elem.id.name, inAtrb.value, svgdata.path);
                    should_register = false;
                }
            }
        case AttrType.VEC3:
            if(new_atrb.id == AttrID.TRANSFORM)
            {
                if(inAtrb.value.starts_with("translate") || inAtrb.value.starts_with("scale")) 
                {
                    nextcase AttrType.VEC2;
                } 
                else if(inAtrb.value.starts_with("rotate")) {
                    new_atrb.value.v3 = get_transform_rotation(inAtrb.value);
                } else {
                    log::warning(Where.FILE,  "Unknown transform value <%s> in file '%s'", inAtrb.value, svgdata.path);
                }
            } 
            else 
            {
                if(try value = to_vec3(inAtrb.value)) {
                new_atrb.value.v3 = value;
                } else {
                    log::warning(Where.FILE, "Failed to convert attribute '%s' value '%s' to vec3 in file '%s'", 
                                elem.id.name, inAtrb.value, svgdata.path);
                    should_register = false;
                }
            }
        case AttrType.VEC4:
            if(try value = to_vec4(inAtrb.value)) {
                new_atrb.value.v4 = value;
            } else {
                log::warning(Where.FILE, "Failed to convert attribute '%s' value '%s' to vec4 in file '%s'", 
                             elem.id.name, inAtrb.value, svgdata.path);
                should_register = false;
            }
        case AttrType.FILE_PATH:
            if(inAtrb.value.starts_with("http") || inAtrb.value.starts_with("../") || inAtrb.value.contains("/") ) 
            {
                Path path;
                new_atrb.value.s = inAtrb.value.copy(mem);
                $switch:
                $case env::WIN32:
                    if(try result = path::for_windows(mem, inAtrb.value.copy(mem))) path = result;
                $case env::LINUX:
                    if(try result = path::for_posix(mem, inAtrb.value.copy(mem))) path = result;
                $default:
                    unreachable();
                $endswitch

                elem.paths.push(&path);
            } else {
                unreachable("Expected a valid file path in attribute '%s' with value '%s' in file '%s'", 
                            elem.id.name, inAtrb.value, svgdata.path);
            }
        case AttrType.URL:
           // this is a pointer to another element, like url(#element_id)
            if(inAtrb.value.starts_with("url(#") && inAtrb.value.ends_with(")"))
            {
                String value = inAtrb.value.trim_left("url(#").trim_right(")");
                new_atrb.value.pelem = svgdata.findElementByID(value);
                if(new_atrb.value.pelem == null) {
                    log::error(Where.FILE, "Failed to get element pointed by url '%s' in file '%s'", value, svgdata.path);
                }
            } else {
                log::warning(Where.FILE, "SVG attrb <%s> in file '%s' is not a valid pointer", elem.id.name, svgdata.path);
            }
    }
}


<*
    @param [in] value : "the string value to check if is a valid integer number"
    @require value != "" && value.len > 0
*>
fn bool is_integer_number(String value) @inline
{
    if(value.contains(".")) return false;

    return true;
}

<*
    @param [in] value : "the string value to check if is a valid integer number"
    @require value != "" && value.len > 0
*>
fn bool is_float_number(String value) //@inline
{
    if(value.contains(".") && value.count(".") == 1) 
    {
        foreach(i, c : value)
        {
            // we found the dot see if the next character is a valid digit
            // NOTE(HM) according to svg spec floats like ".5" are valid, while "5." are not, so we don't allow them.
            if(c == '.' && ascii::is_digit(value[++i])) return true;
        }
    }
    // if we reach here then the value is not a float
    return false;
}

fn bool is_vector_number(String value, int* out_count) @inline
{
    bool result = true;
    bool not_number;

    const char[*] INVALIDLIST = {'%', '#', '/', ':'};
    foreach OUTER: (c : value)
    {
        not_number = ascii::is_digit(c) == false;
        if(not_number)
        {
            if(c == ',' || c == ' ')
            {
                (*out_count)++;
                continue;
            }
            else
            {
                foreach(x : INVALIDLIST)
                {
                    if(c == x) 
                    {
                        result = false;
                        break OUTER;
                    } 
                }
            }
        }
    }

    return result;
}


/*
    12          A raw <integer> is also a <number>.
    4.01        Positive fraction
    -456.8      Negative fraction
    0.0         Zero
    +0.0        Zero, with a leading +
    -0.0        Zero, with a leading -
    .60         Fractional number without a leading zero
    10e3        Scientific notation
    -3.4e-2     Complicated scientific notation
*/

<*  
    @param [inout] value : "the string value to clean"
    @require value != null && value.len > 0
*>
fn void clean_value(String* value) @inline 
{
    if(value.ends_with("mm"))
    {
        (*value) = value.trim_right("mm");
    } 
    else if(value.ends_with("px")) 
    {
        (*value) = value.trim_right("px");
    } 
    else if(value.ends_with("%")) 
    {
        (*value) = value.trim_right("%");
    }
    else if(value.starts_with("+")) 
    {
        (*value) = value.trim_left("+");
    }
    else if(value.starts_with("#")) 
    {
        (*value) = value.trim_left("#");
    }
}

fn float? to_float(String value) @local @inline
{
    if(value.contains("e") || value.contains("E")) 
    {
        // NOTE(HM) we don't support scientific notation here, so we return an error
        return SVG_VALUE_ERROR~;
    }
    
    clean_value(&value);

    // if value starts with a dot we need to add a 0 before it
    if(value.starts_with(".")) 
    {
        value = "0".tconcat(value);
    }

    return value.to_float()!;
}

fn int? to_int(String value) @local @inline
{
    char first = value[0];
    if(value.len == 1) 
    {
        if(ascii::is_digit(first)) {
             return value.to_int()!;
        } else {
            unreachable("Expected a digit in the first character of the value '%s'", value);
        }
    } else if(value.len == 0) {
        unreachable("Expected a value with at least one character, found an empty string");
    }

    // check if the value is a hex number
    if(value.starts_with("#")) 
    {
        value = value.trim_left("#");
        value = "0x".tconcat(value);
        return value.to_int()!;
    } 
    else if(value.starts_with("+")) // this is optional in svg files
    {
        value = value.trim_left("+");
    }

    // TODO(HM) we should support float point percentages too, but for now we don't.
    if(value.ends_with("%") || value.ends_with("px")) 
    {
        // NOTE(HM) we don't support negative percentages or pixel count.
        if(value.starts_with("-")) {
            return SVG_VALUE_ERROR~;
        }
        // if we reach here then the value is a percentage or pixel count
        // so we need to remove the % or px from the end of the value
        value = value.trim_right("%").trim_right("px");
        int result = value.to_int()!;
        assert(result >= 0);
        return result;
    }

    if(value.contains("e") || value.contains("E")) 
    {
        // NOTE(HM) we don't support scientific notation here, so we return an error
        return SVG_VALUE_ERROR~;
    }

    return 0;
}

fn Vec2f? to_vec2(String value) @local @inline
{
    String[] values = value.tsplit(",");
    assert(values.len == 2);
    return {values[0].to_float()!, values[1].to_float()!};
}

fn Vec3f? to_vec3(String value) @local @inline
{
    assert(!value.contains(",") && value.contains(" "));
    String[] values = value.tsplit(" ");
    assert(values.len == 3);
    return {values[0].to_float()!,values[1].to_float()!,values[2].to_float()!};
}

fn Vec4f? to_vec4(String value) @local @inline
{
    assert(!value.contains(",") && value.contains(" "));
    String[] values = value.tsplit(" ");
    assert(values.len == 4);
    return {values[0].to_float()!,values[1].to_float()!,values[2].to_float()!,values[3].to_float()!};
}

fn Vec2f get_transform_translation(String value) {
    /*
        The translate(<x> [<y>]) transform function moves the object by x and y. If y is not provided, it is assumed to be 0.
        transform="translate(x) == transform="translate(x 0)
        transform="translate(0 y)
        transform="translate(x y)
    */
    // first remove the transform word
    String result = value.trim_left("translate");
    // now trim  '(' and ')'
    result = result.trim_left("(");
    result = result.trim_right(")");
    // now see if we are just passing x alone or not
    if(result.contains(",")) {
        Vec2f val;
        if(try v = to_vec2(result)) {
            val = v;
            return val;
        } else { 
            return {0, 0}; 
        }
    } else { // passing a single x coord
        if(try v = result.to_float()) {
            return {v, 0.0f};
        } else { 
            return {0, 0};
        }
    }
}

fn Vec2f get_transform_scale(String value) {
     /*
        The scale(<x> [<y>]) transform function specifies a scale operation by x and y. If y is not provided, it is assumed to be equal to x.
        transform="scale(x) == transform="scale(x x) scale equaly in x and y
        transform="scale(0 y)
        transform="scale(x y)
    */
    // first remove the starting word
    String result = value.trim_left("scale");
    // now trim  '(' and ')'
    result = result.trim_left("(");
    result = result.trim_right(")");
    // now see if we are just passing x alone or not
    if(result.contains(",")) {
        Vec2f val;
        if(try v = to_vec2(result)) {
            val = v;
            return val;
        } else { 
            return {0, 0};
        }
    } else { // passing a single x coord
        if(try x = result.to_float()) {
            return {x, x};
        } else { 
            return {0, 0};
        }
    }
}

fn Vec3f get_transform_rotation(String value) {
    /*
        The rotate(<a> [<x> <y>]) transform function specifies a rotation by a degrees about a given point. 
        If optional parameters x and y are not supplied, the rotation is about the origin of the current user coordinate system. 
        If optional parameters x and y are supplied, the rotation is about the point (x, y).

        <svg viewBox="-12 -2 34 14" xmlns="http://www.w3.org/2000/svg">
        <rect x="0" y="0" width="10" height="10" />

        <!-- rotation is done around the point 0,0 -->
        <rect x="0" y="0" width="10" height="10" fill="red" transform="rotate(100)" />

        <!-- rotation is done around the point 10,10 -->
        <rect
            x="0"
            y="0"
            width="10"
            height="10"
            fill="green"
            transform="rotate(100, 10, 10)" />
        </svg>
    */
    // first remove the first word
    String result = value.trim_left("rotate");
    // now trim  '(' and ')'
    result = result.trim_left("(");
    result = result.trim_right(")");
    // now see if we are just passing a single value alone
    if(result.contains(",")) {
        Vec3f val;
        if(try v = to_vec3(result)) {
            val = v;
            return val;
        } else { 
            return {0, 0, 0};
        }
    } else { // passing a single value
        if(try v = result.to_float()) {
            return {v, 0.0f, 0.0f};
        } else { 
            return {0, 0, 0};
        }
    }
}

/*
fn void get_data_from_xml_string_value(SVGElemNodeAttribute* inAtrb, AttrType* outype, AttrData* outdata) 
{
    bool isfloat, isint, isString;

    char first = inAtrb.value[0];
    if(inAtrb.value.len > 1)
    {
        // else is a integer
        
        // else is a string
        if(!isfloat && !isint && first != '#') 
        {
            outype = AttrType.STRING;
            outdata.s = inAtrb.value.copy(mem);
            return true;
        }

        return false;
    } 
    else if(inAtrb.len == 1)
    {
        if(ascii::is_digit(first)) {
            outype = AttrType.INT;
            outdata.i = inAtrb.value.to_int();

            return true;
        } else { // Todo rethink
            assert(ascii::is_alpha(first));
            outype = AttrType.STRING;
            outdata.s = inAtrb.value.copy(mem);
        }
    }
}
*/

fn bool valid_number(String data) {
    foreach(c : data) {
        if(c != '.' && (ascii::is_alpha(c) || ascii::is_blank(c))) return false;
    }

    return true;
}

fn bool handle_svg_elements(XmlNode* elem, SVGData* svgdata)
{
    switch(elem.name)
    {
        case ElemID.ANIMATE:
        case ElemID.ANIMATEMOTION:
        case ElemID.ANIMATETRANSFORM:
        case ElemID.CIRCLE:
        case ElemID.CLIPPATH:
        case ElemID.DEFS:
        case ElemID.DESC:
        case ElemID.ELLIPSE:
        case ElemID.FEBLEND:
        case ElemID.FECOLORMATRIX:
        case ElemID.FECOMPONENTTRANSFER:
        case ElemID.FECOMPOSITE:
        case ElemID.FECONVOLVEMATRIX:
        case ElemID.FEDIFFUSELIGHTING:
        case ElemID.FEDISPLACEMENTMAP:
        case ElemID.FEDISTANTLIGHT:
        case ElemID.FEDROPSHADOW:
        case ElemID.FEFLOOD:
        case ElemID.FEFUNCA:
        case ElemID.FEFUNCB:
        case ElemID.FEFUNCG:
        case ElemID.FEFUNCR:
        case ElemID.FEGAUSSIANBLUR:
        case ElemID.FEIMAGE:
        case ElemID.FEMERGE:
        case ElemID.FEMERGENODE:
        case ElemID.FEMORPHOLOGY:
        case ElemID.FEOFFSET:
        case ElemID.FEPOINTLIGHT:
        case ElemID.FESPECULARLIGHTING:
        case ElemID.FESPOTLIGHT:
        case ElemID.FETILE:
        case ElemID.FETURBULENCE:
        case ElemID.FILTER:
        case ElemID.FOREIGNOBJECT:
        case ElemID.G:
        case ElemID.IMAGE:
        case ElemID.LINE:
        case ElemID.LINEARGRADIENT:
        case ElemID.MARKER:
        case ElemID.MASK:
        case ElemID.METADATA:
        case ElemID.MPATH:
        case ElemID.PATH:
        case ElemID.PATTERN:
        case ElemID.POLYGON:
        case ElemID.POLYLINE:
        case ElemID.RADIALGRADIENT:
        case ElemID.RECT:
        case ElemID.SCRIPT:
        case ElemID.SET:
        case ElemID.STOP:
        case ElemID.STYLE:
        case ElemID.SVG:
        case ElemID.SWITCH:
        case ElemID.SYMBOL:
        case ElemID.TEXT:
        case ElemID.TEXTPATH:
        case ElemID.TITLE:
        case ElemID.TSPAN:
        case ElemID.USE:
        case ElemID.VIEW:
            nextcase default;
        case ElemID.INVALID:
            log::warning(Where.FILE,  "SVG element <%s> in file '%s' is marked invalid", elem.name, svgdata.path);
        default:
            log::warning(Where.FILE,  "SVG element <%s> in file '%s' is still not supported or valid", elem.name, svgdata.path);
    }

    return true;
}

/*
fn void SVGData.print(&self) @inline 
{
    io::printfn("\n%51s", "*");
    io::printfn("\n[SVG: '%s']", self.path);
    if(self.elements.len())
    {
        usz count = self.elements.len();
        io::printfn("['%s' %s]", count, (count == 1) ? "element" : "elements" );
        foreach(elem: self.elements)
        {
            io::printfn("('%s')", elem.name);
            if(elem.attributes.len()) 
            {
                io::printfn("{");
                foreach (atrb : elem.attributes)
                {
                    if(atrb == null) continue;
                    io::printfn("\t%s = \"%s\";", atrb.first, atrb.second);
                }
                io::printfn("}\n");
            }
        }
    }
    io::printfn("\n%51s", "*");
}

fn void SVGData.printTofile(&self, String path) @inline
{
    if(try file = fs::openFile(path, "w"))
    {
        io::fprintfn(&file, "[SVG: \"%s\"]", self.path);
        if(self.elements.len())
        {
            usz count = self.elements.len();
            io::fprintfn(&file, "['%s' %s]", count, (count == 1) ? "element" : "elements" );
            foreach(elem: self.elements)
            {
                io::fprintfn(&file, "(%s)", elem.name);
                if(elem.attributes.len()) 
                {
                    io::fprintfn(&file, "{");
                    foreach (atrb : elem.attributes)
                    {
                        if(atrb == null) continue;
                        io::fprintfn(&file, "\t%s = \"%s\";", atrb.first, atrb.second);
                    }
                    io::fprintfn(&file, "}\n");
                }
            }
        }
    } else {
        log::warning(Where.CONSOLE, "Failed to save svg '%s' parsed data to optimized file '%s'.", self.path, path);
        return;
    }
}
*/