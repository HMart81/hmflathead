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

module engine::sys::reader::svg;

import std::io, std::collections::list, std::io::path;
import thirdparty::library::xml;
import engine::filesystem::fs;
import engine::logging::log;
import engine::misc;
import game::main;
import std::ascii;

/* DOC(HM)

    *SVG is based on xml and it has significant white space!! :( 

    TODO(HM) 
    -> Clean path data before parsing?
    "Superfluous white space and separators such as commas can be eliminated 
    (e.g., "M 100 100 L 200 200" contains unnecessary spaces and could be expressed more compactly as "M100 100L200 200")."
    "The command letter (M m, L l, etc) can be eliminated on subsequent commands, 
        if the same command is used multiple times in a row (e.g., you can drop the second "L" in "M 100 200 L 200 100 L -100 -200" and use "M 100 200 L 200 100 -100 -200" instead)."
    Final clean "M 100 200L 200 100 -100 -200"

*/

//alias ListOfLines  = List{Line};
//alias ListOfCurves = List{Curve};
//alias ListOfArcs   = List{Arc};
//alias ListOfShapes = List{SVG_Shape};
//alias ListOfPaths  = List{SVG_D_Path};

faultdef MALFORMED_SVG_FILE,
         SVG_PARSING_ERROR,
	     SVG_LOAD_ERROR,
	     SVG_RETRIVAL_ERROR,
         SVG_VALUE_ERROR,
         SVG_FILE_PATH_EMPTY,
	     MISSING_SVG;


<*
    @param [in] node : "xml node to compare the given name with"
    @require node != null
*>
fn bool XmlNode.isNode(XmlNode* node, String name) @inline @local => (node.name == name) ? true : false;

// NOTE(HM) acording to Zeal Doc this is mostly complete (minus deprecated elements)
enum ElemID : int (inline String name)
{
    INVALID             = "",     // not really a real svg element just used to mark invalid elements
    ANIMATE             = "animate",
    ANIMATEMOTION       = "animateMotion",
    ANIMATETRANSFORM    = "animateTransform",
    CIRCLE              = "circle",
    CLIPPATH            = "clipPath",
    DEFS                = "defs",
    DESC                = "desc",
    ELLIPSE             = "ellipse",
    FEBLEND             = "feBlend",
    FECOLORMATRIX       = "feColorMatrix",
    FECOMPONENTTRANSFER = "feComponentTransfer",
    FECOMPOSITE         = "feComposite",
    FECONVOLVEMATRIX    = "feConvolveMatrix",
    FEDIFFUSELIGHTING   = "feDiffuseLighting",
    FEDISPLACEMENTMAP   = "feDisplacementMap",
    FEDISTANTLIGHT      = "feDistantLight",
    FEDROPSHADOW        = "feDropShadow",
    FEFLOOD             = "feFlood",
    FEFUNCA             = "feFuncA",
    FEFUNCB             = "feFuncB",
    FEFUNCG             = "feFuncG",
    FEFUNCR             = "feFuncR",
    FEGAUSSIANBLUR      = "feGaussianBlur",
    FEIMAGE             = "feImage",
    FEMERGE             = "feMerge",
    FEMERGENODE         = "feMergeNode",
    FEMORPHOLOGY        = "feMorphology",
    FEOFFSET            = "feOffset",
    FEPOINTLIGHT        = "fePointLight",
    FESPECULARLIGHTING  = "feSpecularLighting",
    FESPOTLIGHT         = "feSpotLight",
    FETILE              = "feTile",
    FETURBULENCE        = "feTurbulence",
    FILTER              = "filter",
    FOREIGNOBJECT       = "foreignObject",
    G                   = "g",
    IMAGE               = "image",
    LINE                = "line",
    LINEARGRADIENT      = "linearGradient",
    MARKER              = "marker",
    MASK                = "mask",
    METADATA            = "metadata",
    MPATH               = "mpath",
    PATH                = "path",
    PATTERN             = "pattern",
    POLYGON             = "polygon",
    POLYLINE            = "polyline",
    RADIALGRADIENT      = "radialGradient",
    RECT                = "rect",
    SCRIPT              = "script",
    SET                 = "set",
    STOP                = "stop",
    STYLE               = "style",
    SVG                 = "svg",   // this is the root element of the svg file
    SWITCH              = "switch",
    SYMBOL              = "symbol",
    TEXT                = "text",
    TEXTPATH            = "textPath",
    TITLE               = "title",
    TSPAN               = "tspan",
    USE                 = "use",
    VIEW                = "view",
}


alias AttrData = StringPair;
alias ListOfXmlAttributes = List{AttrData*};
alias ListOfAttributes    = List{SVGAttribute*};

// NOTE(HM) acording to Zeal application documentation there's 239 attributes 
// so this is very much incomplete.
// NOTE(HM) I'm still using here some deprecated attributes because the svg tool I use 
// still relies on them, at lest for now.
enum AttrID : char (inline String name)
{
    INVALID             = "",     // not really a real svg attribute just used to mark invalid ones
    WIDTH               = "width",
    HEIGHT              = "height",
    VIEWBOX             = "viewBox",
    VERSION             = "version",
    ID                  = "id",
    XMLSPACE            = "xml:space", // deprecated
    XMLNSXLINK          = "xmlns:xlink",
    XMLNS               = "xmlns",
    XMLNSSVG            = "xmlns:svg",
    XLINKHREF           = "xlink:href", // deprecated
    CLIPPATHUNITS       = "clipPathUnits",
    STYLE               = "style",
    X                   = "x",
    Y                   = "y",
    TRANSFORM           = "transform",
    CX                  = "cx",
    CY                  = "cy",
    RX                  = "rx",
    RY                  = "ry",
    D                   = "d",
    PRESERVEASPECTRATIO = "preserveAspectRatio",
    CLIPPATH            = "clip-path",
}

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

alias ListOfElements = List{SVGElement*};
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
        return SVG_FILE_PATH_EMPTY?;
    }
    // check if the file exists
    File file = fs::openFile(self.path)!;
    defer file.close()!!;
    if(file.file == null) {
        log::error(Where.FILE, "Failed to open svg file '%s'", self.path);
        return SVG_LOAD_ERROR?;
    }

    SVGFile* svg_file = (SVGFile*)xml::read_file(file)!;
    defer svg_file.free();
    if(svg_file == null) {
        log::error(Where.FILE, "Failed to read svg file '%s'", self.path);
        return SVG_LOAD_ERROR?;
    }

    if(self.parse(svg_file) == false) {
        return SVG_PARSING_ERROR?;
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
        return SVG_VALUE_ERROR?;
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
            return SVG_VALUE_ERROR?;
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
        return SVG_VALUE_ERROR?;
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

/* 


************************************************ old design **************************

enum PathIdent : inline int (String str)
{
    MOVETO                      = "m";
    MOVETO_ABS                  = "M";
    LINETO                      = "l";
    LINETO_ABS                  = "L",
    LINETO_HORIZONTAL           = "h",
    LINETO_HORIZONTAL_ABS       = "H",
    LINETO_VERTIVAL             = "v",
    LINETO_VERTIVAL_ABS         = "V",
    CLOSEPATH                   = "z",
    CLOSEPATH_ABS               = "Z",
    CURVETO                     = "c",
    CURVETO_ABS                 = "C",
    SMOOTH_CURVETO              = "s",
    SMOOTH_CURVETO_ABS          = "S",
    QUADRATIC_BCURVE            = "q",
    QUADRATIC_BCURVE_ABS        = "Q",
    QUADRATIC_SMOOTH_BCURVE     = "t",
    QUADRATIC_SMOOTH_BCURVE_ABS = "T",
    ARC                         = "a",
    ARC_ABS                     = "A"
}

struct BBox // Axis Aligned Bounding Box data
{
    Vec2f pos;
    Vec2f size;
}

struct ShapePrimCoords
{
    Vec2f start;
    Vec2f end;
}

// TODO(HM) Find a better name for this...
// This is main data structure where all svg data is peeked 
struct ManagerObj
{
    ListOfShapes shapes;
    float z; // todo rename this to be more discriptive
    RawData* svg_data;
}

// to finish conversion
fn f32 attibuteDataToFloat(ZString value, ZString* remainder) {
    int len = value.len;
    ZString buffer = (ZString)mem::malloc(len * char.sizeof + 1);
    defer{
        mem::free(buffer);
    };
    libc::strncpy(buffer, value, len * char.sizeof + 1);

    String result;
    ZString at;

    at = buffer;
    at = hm::EatSpaces(at);

    while (isdigit(*at) || *at == '.') {
        hm::Advance(&at, 1);
    }

    result = String(buffer, at);

    // save reminder data
    std::memcpy((*remainder), at, sizeof(&buffer[len] - at));

    return cString::ToFloat(buffer, 0.f);
}


// to finish conversion
fn String getScaleType(ZString str)
{
    int len     = str.len;
    int size    = len * char.sizeof + 1;

    ZString buffer = (ZString)mem::malloc(size);
    defer{
        mem::free(buffer);
    };

    libc::strncpy(buffer, str, size);

    ZString at = buffer;
    at = hm::EatSpaces(at);

    while (isdigit(*at) || *at == '.') {
        hm::Advance(&at, 1);
    }

    ZString lastChar = &buffer[len];

    return String(at, sizeof(lastChar - at));
}

// ***********************************************
// SVG FILE RAW SHAPE PRIMITIVE DATA
// ***********************************************

// *text* means previous data

// NOTE(HM) A line or "lineto"
// in a path, a line is represented with the letter L/l
// start is first relative, to the path main moveTo coordinate,
// then any other line, is relative to the last coordinate given before it.
//  -> l's or L's in a row, before a z or Z (endpath), can be omited but 
// then white space, becomes important, so IMO is best to keep 
// every lineto seperated by its own letter.
// 
// #moveTo#/#end# L end(x,y)

enum LineType : inline int
{
    NORMAL,		// uses the last giving coordinates and add's to the existing x,y coordinates
    HORIZONTAL, // uses the last giving coordinates and add's to the x coordinate alone
    VERTICAL	// uses the last giving coordinates and add's to the y coordinate alone
}

struct Line
{
    LineType type;
    // start is relative to moveTo or the coordinates of previous lines...
    Vec2f start;
    Vec2f end;
    uint abs_coordinates;
};



enum Curveid : inline int
{
    NONE,
    CUBIC_CURVETO,
    CUBIC_SMOOTH,
    QUADRADIC_CURVETO,
    QUADRADIC_SMOOTH,
}

struct Curve
{
    Curveid id;

    // #moveTo#/#end* C contr1(x,y) contr2(x,y) end(x,y)
    struct cubic {
        //const String& name = "CubicCurveto";
        Vec2f control1;
        Vec2f control2;

        // *start#/#end* S *contr2*(-x,-y) contr1(x,y) end(x,y)
        bool isSmooth;
        Vec2f control3; // only used if the cubic is smooth
    }

    // *moveTo#/#end* Q contr1(x,y) end(x,y)
    struct quadratic {
        //const String& name = "QuadraticCurveto";  // used for the casting...

        //struct QuadraticSmoothCurveto_s {
        //	const String& name = "QuadraticSmoothCurveto";  // used for the casting...
        //	
        //	Vec2f control = vec2f_zero;
        //} smooth = {};

        Vec2f control;

        // if is smooth is true 
        // *start#/#end* T *contr1*(-x,-y) end(x,y)
        // control point is assumed to be the reflection of the control point 
        // on the previous command relative to the current point.
        uint isSmooth = FALSE;
    }

    // start is relative to the last coordinates of moveTo or other curves end...
    Vec2f start;
    Vec2f end;
    uint abs_coordinates = FALSE;
};

// our control point is assumed to be the reflection (negation) of the control2 point 
// on the previous command relative to the current point.
fn void Curve.setSmoothControlData(&self, Vec2f* vec) {
    switch(self.id) {
        case CUBIC_SMOOTH:
            self.control3 = -vec;
        case QUADRADIC_SMOOTH:
            self.control = -vec;
    }
}


struct Arc
{
    // *moveTo#/#end* A axis(x,y) angle(x)  arcSweepValue(x,y) end(x,y)
    Vec2f start; // start
    Vec2f axis;
    Vec2f sweapValue; // 0,0; 0,1; 1,0; 1,1;
    Vec2f end;
    int angle; // in degrees normalized 180º
    uint abs_coordinates;
}


// ***********************************************
// SVG FILE RAW DATA
// ***********************************************

struct PathDef // represents attribute 'd' data 
{
    uint moveTOasAbsCoords = FALSE; // @irrelevant?
    // for moveto ident: 
    // if big M following coordinates are absolute 
    // if small m they are relative.

    uint asSpecialMoveTo = FALSE; // @irrelevant?
    // If after a M/m we see two or more par's of coordinates, set this to true.
    // In this special cases:
    //  - after the first par of moveTo coords, if no letter is found, all others coords are linetos(start,end) coords. 
    //  - if small (m) the first par of coords are Absolute, the rest until a letter is found, are Relative.
    //  - if big   (M) the first par of coords are Relative, the rest until a letter is found, are Absolute.

    Vec2f        moveTo;
    ListOfLines  lines; // linetos
    ListOfCurves curves;
    ListOfArcs   arcs;
}

fn void PathDef.clearPathsData(&self) {
    if (self.lines.len()) {
        //For(d.lines) if (it.start) it.start = null;
        lines.free();
    }
    if (self.curves.len()) {
        //For(d.curves) if (it.start) it.start = null;
        curves.free();
    }
    if (self.arcs.len()) {
        //For(d.arcs) if (it.start) it.start = null;
        arcs.free();
    }
}

/// <summary>
/// Represents the <g></g> element data, is a container used to group other SVG elements
/// </summary>
struct Group
{
    String id;
    struct transform {
        SVG_Tranform type;
        Vec2f value;
    };

    // the <path/> element
    struct path_elem
    {
        String data_string;
        // the ‘d’ attribute.
        // contains the moveto, line, curve (both cubic and quadratic Béziers), arc and closepath instructions.
        struct d {
            ListOfPaths paths;
        };

        String id;
    };
}


/// <summary>
/// The <svg></svg> main root Element
/// where all DATA parsed from the xml file will be saved
/// </summary>
struct RawData
{
    String sourcefile;
    String file_name;
    //
    String scale_type;
    SVG_BBox bounds;

    String version;
    String id;
    String description; // a place where some text is written to explain what the svg means to be or do
    // TODO handle the <defs\> element?
    SVG_G_Element g_elem; // the <g></g> Element, right now only one element is supported...

    // custum deep copy
    inline void Copy(const SVG_RAW_DATA& other) {
        sourcefile.assign(other.sourcefile);
        file_name.assign(other.file_name);
        scale_type.assign(other.scale_type);
        bounds.pos = other.bounds.pos;
        bounds.size = other.bounds.size;
        version.assign(other.version);
        id.assign(other.id);
        description.assign(other.description);
        g_elem.id.assign(other.g_elem.id);
        g_elem.path_elem.data_string.assign(other.g_elem.path_elem.data_string);
        g_elem.path_elem.id.assign(other.g_elem.path_elem.id);
        for (irange(i, 0, other.g_elem.path_elem.d.paths.count - 1)) {
            auto& it = other.g_elem.path_elem.d.paths[i];
            g_elem.path_elem.d.paths.Push(it);
        }
        g_elem.transform.type = other.g_elem.transform.type;
        g_elem.transform.value = other.g_elem.transform.value;
    };
};


/***********************************************************************************/
/***********************************************************************************/
struct SVG_EDGE {
    SVG_Vertex v1, v2;

    const SVG_Vertex& operator[](int index) const {
        assert(index >= 0 && index <= 1); 
        if (index == 0)
                return v1;
        else
            return v2;
    };
};

#if 0
struct SVG_FACE_TRIANGLE {
    Array<SVG_EDGE> tri = {};

    SVG_FACE_TRIANGLE() {
        tri.Reserve(3); // will reserve 16
        for (irange(i, 0, 3 - 1)) {
            tri.Push();
        }
    }
};

struct SVG_FACE_QUAD {
    Array<SVG_FACE_TRIANGLE> quad = {};

    SVG_FACE_QUAD() {
        quad.Reserve(2); // will reserve 16
        for (irange(i, 0, 2 - 1)) {
            quad.Push();
        }
    }
};

#endif // 0

struct SVG_Shape {
    Array<SVG_EDGE> edges = {};
};


// ****************************************************
// ****************************************************

template<typename T>
fn void CreateEdgesFromCurve(cGame* game, T& curve, Array<SVG_EDGE>& edges) {
    if (!game) return;

    f32 startTime = curve.GetTime(0);
    f32 endTime   = curve.GetTime(curve.GetNumValues() - 1);
    curve.MakeUniform(endTime);
    f32 length    = curve.GetLengthForTime(endTime);
    f32 t         = curve.GetTimeForLength(length, 0.01f);

    Vec2f newPoint, oldPoint = curve.GetCurrentValue(0);
    for (irange(i, 0, t)) {
        newPoint = curve.GetCurrentValue(i);
        if (oldPoint != newPoint) {
            //lldraw->DrawLine2D(oldPoint, newPoint, 100, colorRed);
            SVG_EDGE edge;
            edge.v1 = oldPoint;
            edge.v2 = newPoint;
            edges.Push(edge);
        }
        oldPoint = newPoint;
    }
    curve.Clear();
}

#if 0
template<typename T>
fn void DrawCurve(cGame* game, T& curve) {
    if (!game) return;

    f32 startTime = curve.GetTime(0);
    f32 endTime = curve.GetTime(curve.GetNumValues() - 1);
    curve.MakeUniform(endTime);
    f32 length = curve.GetLengthForTime(endTime);
    f32 t = curve.GetTimeForLength(length, 0.01f);
    auto* lldraw = game->GetGraphics()->GetLowLevel();
#if 0 // debug
    lldraw->DrawSprite(curve.GetCurrentValue(0), 8, colorCyan);
    lldraw->DrawSprite(curve.GetCurrentValue(0.5f * t), 8, colorCyan);
    lldraw->DrawSprite(curve.GetCurrentValue(t), 8, colorCyan);
#endif // 0
    Vec2f newPoint, oldPoint = curve.GetCurrentValue(0);
    for (irange(i, 0, t)) {
        newPoint = curve.GetCurrentValue(i);
        if (oldPoint != newPoint) {
            lldraw->DrawLine2D(oldPoint, newPoint, 100, colorRed);
        }
        oldPoint = newPoint;
    }
    curve.Clear();
}
#endif // 0


/// <summary>
/// TODO(HM) Is still not finished!!!!!!!!!!!!!!!!!!
/// The final game object that will be used to render the svg on screen
/// NOTE(HM) Piggyback on the GfxObject system, see GfxObjec.cpp and GraphicsDrawer.cpp
// ex: 
//
// svgobj = mpDrawer->CreateGfxObject("some.svg", cColor colorRed, false);
// -> that aboves does something like:
//  cGfxObject* pObject = hplNew( cGfxObject,(pMat,asFileName,true));

// if (abAddToList) mlstGfxObjects.push_back(pObject);
//
/* 
cGfxObject::cGfxObject(cSVG_Oject& obj)
{
    For(obj.verts)
        mvVtx.push_back(it.vert, it.uv, it.color);
}
*/
/// </summary>
/// <param name="game"></param>
/// <param name="file"></param>
/// <param name="color"></param>
cSVG_Object::cSVG_Object(cGame* game, const String& file, const cColor& color) {
    if (!game) return;

    mpGame = game;

    /*if (!mat)
    {
        mat = game->GetGraphics()->GetMaterialHandler()->Create(
            "SVG_Surface", "Diffuse", eMaterialPicture_Texture);
    }*/

    svg_data = SVG_LoadFromFile(file.c_str(), mpGame->GetSystem());
    bool sucess = (svg_data != null);
    if (!sucess) {
        LOG_WARNING("Was not able to parse svg data from: %s\n", file.c_str());
        return;
    }

    // delete this is only to skip the code bellow
    return;

    // TODO(HM) finish creating object !!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // 
    // first count the number of vertices/points needed
    int shapes_count = svg_data->g_elem.path_elem.d.paths.count;

    // a small alias for the svg paths
    auto& paths = svg_data->g_elem.path_elem.d.paths;

    // In case the default array capacity is not enough
    if (shapes_count > shapes.capacity) {
        shapes.Reserve(shapes_count);
    }

    // Init the shapes
    for(irange(i, 0, shapes_count - 1)) {
        shapes.Push();
    }

    SVG_D_Path* pPath;
    const auto normal = cVector3f(0, 0, -1); // towards the player
    ArrayForEach(pPath, paths)
    {
        SVG_D_Path& path = *pPath;

        For(shapes) 
        {
            auto& shape = it;
            if (path.lines.count) 
            {
                For(path.lines)
                {
                    auto& line = it;

                    SVG_EDGE edge;
                    // start
                    edge.v1.col  = colorWhite;
                    edge.v1.norm = normal;
                    edge.v1.pos  = line.start;
                    // end
                    edge.v2.col  = edge.v1.col;
                    edge.v2.norm = edge.v1.norm;
                    edge.v2.pos  = line.end;
                    shape.edges.Push(edge);
                }
            }
            if (path.curves.count) 
            {
                For(path.curves)
                {
                    auto& curve = it;

#if 0
// draw a QuadraticBezier (requires exactly three points)
                    auto* curve = new hmCurve_QuadraticBezier<Vec2f>();
                    curve->AddValue(0, Vec2f(500, 200));
                    curve->AddValue(50, Vec2f(750, 250));
                    curve->AddValue(100, Vec2f(600, 300));

                    f32 startTime = curve->GetTime(0);
                    f32 endTime = curve->GetTime(curve->GetNumValues() - 1);
                    curve->MakeUniform(endTime);
                    f32 length = curve->GetLengthForTime(endTime);
                    f32 t = curve->GetTimeForLength(length, 0.01f);
                    auto* lldraw = game->GetGraphics()->GetLowLevel();
                    lldraw->DrawSprite(curve->GetCurrentValue(0), 8, colorCyan);
                    lldraw->DrawSprite(curve->GetCurrentValue(0.5f * t), 8, colorCyan);
                    lldraw->DrawSprite(curve->GetCurrentValue(t), 8, colorCyan);
                    Vec2f newPoint, oldPoint = curve->GetCurrentValue(0);
                    for (irange(i, 0, t)) {
                        newPoint = curve->GetCurrentValue(i);
                        if (oldPoint != newPoint) {
                            lldraw->DrawLine2D(oldPoint, newPoint, 100, colorRed);
                        }
                        oldPoint = newPoint;
                    }
                    curve->Clear();
#endif // 0
                    switch (curve.id)
                    {
                    case Curve::Quadradic_Curveto:
                    case Curve::Quadradic_Smooth:
                    {
#if 0
                        Array<Vec2f> curve_points = {};
                        auto Quadratic = [&curve_points](const Vec2f p0, const Vec2f p1, const Vec2f p2) {
                            const f32 x0 = p0.x;
                            const f32 y0 = p0.y;

                            const f32 x1 = p1.x;
                            const f32 y1 = p1.y;

                            const f32 x2 = p2.x;
                            const f32 y2 = p2.y;

                            auto x = [&](f32 t) -> const f32 {
                                return std::powf(1.f - t, 2.f) * x0 + 2.f * (1.f - t) * t * x1 + std::powf(t, 2.f) * x2;
                            };

                            auto y = [&](f32 t) -> const f32 {
                                return std::powf(1.f - t, 2.f) * y0 + 2.f * (1.f - t) * t * y1 + std::powf(t, 2.f) * y2;
                            };

                            // Get all the points for a transition at 60 frames per second that lasts 1s
                            for (f32 t = 0.f; t <= 1.f; t = t + 1.f / 60.f) {
                                const f32 valX = x(t);
                                const f32 valY = y(t);
                                curve_points.Push({ valX, valY });
                            }
                            curve_points.Push({ 1.f, 0.f });
                        };

                        // Get the path points
                        Quadratic(curve.start, curve.quadratic.control, curve.end);

                        hmCurve_QuadraticBezier<Vec2f> quadcurve = {};
                        for (auto t = i = 0; i < curve_points.count; i++, t += 100) {
                            quadcurve.AddValue(t, curve_points[i]);
                        }
#else
                        hmCurve_QuadraticBezier<Vec2f> quadcurve = {};
                        quadcurve.AddValue(0, curve.start);
                        quadcurve.AddValue(50, curve.quadratic.control);
                        quadcurve.AddValue(100, curve.end);

                        //CreateEdgesFromCurve<hmCurve_QuadraticBezier<Vec2f>>(mpGame, quadcurve, curve);
#endif // 0


                        //DrawCurve<hmCurve_QuadraticBezier<Vec2f>>(game, quadcurve);
                    }
                    break;
                    case Curve::Cubic_Curveto:
                    {
                        // TODO create the curve data
                        // see https://pt.wikipedia.org/wiki/Curva_de_B%C3%A9zier
                        // and see https://en.wikipedia.org/wiki/Glossary_of_mathematical_symbols
                        // to help with the math symbology

#if 0
                        Array<Vec2f> curve_points = {};
                        auto Cubic = [&curve_points](const Vec2f p0, const Vec2f p1, const Vec2f p2, const Vec2f p3) {
                            const f32 x0 = p0.x;
                            const f32 y0 = p0.y;

                            const f32 x1 = p1.x;
                            const f32 y1 = p1.y;

                            const f32 x2 = p2.x;
                            const f32 y2 = p2.y;

                            const f32 x3 = p3.x;
                            const f32 y3 = p3.y;

                            auto y = [&](f32 t) -> const f32 {
                                return std::powf(1.f - t, 3.f) * y0 +
                                    3.f * std::powf(1.f - t, 2.f) * t * y1 +
                                    3.f * (1.f - t) * std::powf(t, 2.f) * y2 +
                                    std::powf(t, 3.f) * y3;
                            };

                            auto x = [&](f32 t) -> const f32 {
                                return std::powf(1.f - t, 3.f) * x0 +
                                    3.f * std::powf(1.f - t, 2.f) * t * x1 +
                                    3.f * (1.f - t) * std::powf(t, 2.f) * x2 +
                                    std::powf(t, 3.f) * x3;
                            };

                            for (int t = 0; t <= 1; t = t + 1 / 60) {
                                const f32 valX = x(t);
                                const f32 valY = y(t);
                                curve_points.Push({ valX,valY });
                            }
                            curve_points.Push({ 1,0 });
                        };

                        // Get the path points
                        Cubic(curve.start, curve.cubic.control1, curve.cubic.control2, curve.end);

                        hmCurve_CubicBezier<Vec2f> curveto = {};
                        for (auto t = i = 0; i < curve_points.count; i++, t += 100) {
                            curveto.AddValue(t, curve_points[i]);
                        }

                        DrawCurve<hmCurve_CubicBezier<Vec2f>>(game, curveto);
#endif // 0

                    }
                    break;
                    case Curve::Cubic_Smooth:
                    {
                        //SVG_Vertex vert;
                        //vert.col = colorWhite;
                        //vert.norm = cVector3f(0, 0, -1); // towards the player
                        //vert.pos = curve.cubic_smooth.control; // this is the negation of the last control of the previous curve
                        //winding.vertices.Push(vert);
                    }
                    break;
                    default:
                        // found empty curve this shouldn't happen
                        //assert(false);
                        break;
                    }

                }
            }
            if (path.arcs.count) 
            {
                //for (irange(i, 0, path.arcs.count - 1)) {
                //	auto& arc = path.arcs[i];
                //	SVG_Vertex st, ax, sv, ed;
                //	// start
                //	st.col = colorWhite;
                //	st.norm = cVector3f(0, 0, -1); // towards the player
                //	st.pos = arc.start;
                //	// end
                //	ed.col = colorWhite;
                //	ed.norm = cVector3f(0, 0, -1); // towards the player
                //	ed.pos = arc.end;
                //	// axis
                //	ax.norm = arc.axis;  // norm encodes the axis value
                //	// sweapValue
                //	ed.norm = arc.sweapValue; // norm encodes the sweap value

                //	SVG_Vertex verts[] = { st, ax, sv, ed };
                //	for(irange(j, 0, 4 - 1)) {
                //		it.edges.Push(edge);
                //	}
                //}
            }
        }
    }
}

cSVG_Object::~cSVG_Object()
{
    if (svg_data) {
        hplDelete(svg_data);
    }
}

void SVG::cSVG_Object::DrawShapes()
{
    auto drawer = mpGame->GetGraphics()->GetLowLevel();

    // @Performance very slow need to create the winding before this point.
    // doing this right now just for testing.
    For(shapes) {
        Array<cVertex> winding = {};
        defer{ winding.Release(); };

        int count = sizeof(cVertex) * (it.edges.count * 2);
        winding.Reserve(count);
        // init the vertex data
        For(it.edges) {
            for (irange(i, 0, 2 - 1)) {
                winding.Push(it[i]);
            }
        }
        drawer->DrawPoly(winding);
    }
}

#define AssertIsNumber()  assert(token.type == TOKENIZER::Token_Minus ||\
                        token.type == TOKENIZER::Token_Numeric)

#define IsEndOfPath(token) ((token) == "z" || (token) == "Z")

inline fn uint CheckUpperCase(const Token& token)
{
    const char& it = *token.text;

    if (it >= 'A' && it <= 'Z')
        return 1;
    else
        return 0;
}

inline fn void 
AdvanceToNextCoords(Tokenizer& tokenizer, Token& token) 
{
    if (token.type == TOKENIZER::Token_Minus) 
    {
        token = GetToken(&tokenizer);

        while (token.type != TOKENIZER::Token_Comma) 
        {
            // this will advance the comma and get the start of second coord
            token = GetToken(&tokenizer);
        }
    }
    else 
        token = GetToken(&tokenizer);

    // this will advance the second coordinate data
    if (token.type == TOKENIZER::Token_Comma) 
    {
        // this will advance the comma and get the start of second coord
        token = GetToken(&tokenizer);
        // the second coordinate data can start with a minus as well, skip it
        if (token.type == TOKENIZER::Token_Minus)
            token = GetToken(&tokenizer);
        // this will now advance the second coordinate data
        token = GetToken(&tokenizer);
    }
};

inline fn void 
SVG_SET_Q_CurveData(const Vec2f& start, Tokenizer& tokenizer, Token& token, Curve& outcurve) 
{
    outcurve.id = Curve::CURVE_ID::Quadradic_Curveto;
    // the start coords for the q curve
    outcurve.start = start;

    tFloatVec coords;

    // first our coordinate for the control point
    AssertIsNumber(); // just in case
    cString::GetFloatVec(token.text, coords);
    outcurve.quadratic.control = Vec2f(coords[0], coords[1]);

    // then our coordinate for the end point
    AdvanceToNextCoords(tokenizer, token);
    AssertIsNumber();
    coords.clear();
    cString::GetFloatVec(token.text, coords);
    outcurve.end = Vec2f(coords[0], coords[1]);
}

inline fn void SVG_SET_Path_MoveToData(const char current_ident, Tokenizer& tokenizer, SVG_D_Path& outpath) {
    // now get the next token
    Token token = GetToken(&tokenizer);
    AssertIsNumber();

    tFloatVec coords;
    cString::GetFloatVec(token.text, coords);
    outpath.moveTo = Vec2f(coords[0], coords[1]);
    // advance the tokanizer to the start of the second moveto coord
    // this because it will be skiped in the next loop
    if(*tokenizer.at == ',') {
        while (*tokenizer.at == ',') {
            hm::Advance(&tokenizer.at, 1);
        }
    }
    /*for (;;) {
        if (*tokenizer.at == ' ') break;
        hm::Advance(&tokenizer.at, 1);
    }*/
}

inline fn void SVG_SET_Path_LineToData(Line::LINE_TYPE type, const char current_ident, Tokenizer& tokenizer, SVG_D_Path& outpath) {
    // create the line in the stack
    auto line = hplNew(Line, ());
    line->type = type;
    const Line::LINE_TYPE& line_type = type;

    line->abs_coordinates = outpath.moveTOasAbsCoords;

    if (outpath.lines.count <= 0 && outpath.curves.count <= 0 && outpath.arcs.count <= 0)
        line->start = outpath.moveTo;
    else {
        if (outpath.lines.count)
            line->start = outpath.lines[outpath.lines.count - 1].end;
        else if (outpath.curves.count)
            line->start = outpath.curves[outpath.curves.count - 1].end;
        else if (outpath.arcs.count)
            line->start = outpath.arcs[outpath.arcs.count - 1].end;
        else
            assert(false); // NOTE(HM) if this triggers then isn't a valid path
    }

    // get the next token to retrieve the end coords
    bool isNegativeNumber = false;
    Token token = GetToken(&tokenizer);

    if (token.type == TOKENIZER::Token_Minus && line_type != Line::LINE_TYPE::normal)
    {
        // For v or h lines using single values by using a token
        // I need to advance the minus sign. 
        // This to be able to get a valid value for the cString::ToFloat func bellow
        // This means that I will only really give it positive values, 
        // so I need to save aprior if a value was negative or not
        // and set it accordingly bellow. 
        token = GetToken(&tokenizer);
        isNegativeNumber = true;
    }

#if 0

    auto value_string = String(token.text, (token.text + token.len));
    if (isNegativeNumber) {
        value_string = String("-").append(value_string);
    }
#endif // 0


    switch (line_type)
    {
    case Line::LINE_TYPE::normal:
    {
        tFloatVec coords;
        cString::GetFloatVec(token.text, coords);
        line->end  = Vec2f(coords[0], coords[1]);
    }
    break;
    case Line::LINE_TYPE::horizontal:
    {
        line->end = line->start;
        f32 value = cString::ToFloat(String(token.text, (token.text + token.len)).c_str()/*value_string.c_str()*/, 0.f);
        assert(value != 0); // just in case
        if (isNegativeNumber)
            value = -value;
        line->end.x += value;
    }
    break;
    case Line::LINE_TYPE::vertical:
    {
        line->end = line->start;
        f32 value = cString::ToFloat(String(token.text, (token.text + token.len)).c_str()/*value_string.c_str()*/, 0.f);
        assert(value != 0); // just in case
        if (isNegativeNumber)
            value = -value;
        line->end.y += value;
    }
    break;
    default:
        // TODO(HM) improve this error message...
        assert(false);
        hpl::Error("Invalide line type passed to lineto data:\n");
        break;
    }

    // save the line in the line array
    outpath.lines.Push(*line);
}

#if 0
fn SVG_D_Path* SVG_ParsePathData(const String& path_string) {
    // create the required path data to save the data in
    auto* path_data = hplNew(SVG_D_Path, ());
    SVG_D_Path& path = *path_data;

    if (!path_string.empty())
    {
        ZString buffer = (ZString)mem::malloc(path_string.length() + 1);
        defer{ mem::free(buffer) };

        libc::strncpy(buffer, path_string.c_str(), path_string.length() + 1);

        // create the tokenizer to parse the path data
        Tokenizer tokenizer = {};
        tokenizer.at = buffer;

        char older_ident, current_ident = 0;

        bool parsing = true;
        int parsed_cmds_count = 0;
        while (parsing)
        {
            Token token = GetToken(&tokenizer);
            switch (token.type)
            {
            case Token_Comma:
                // go to next token
                break;
            case Token_EndOfStream:
                if (parsed_cmds_count <= 0) LOG("%s", "Nothing to parse.\n");
                parsing = false;
                break;
            case Token_Unknown:
                LOG("Skiping unkown token: %d: %.*s\n", token.type, token.len, token.text);
                break;
            case Token_Minus: // will behave has a identifier...
            case Token_Numeric: // will behave has a identifier...
            case Token_Identifier:
            {
                bool should_break_main = false;
                current_ident = 0;

                // get out
                if (token == "z" || token == "Z") {
                    // current path end, go to the next path
                    parsing = false;
                    break;
                }

                // handling for the "special" lineTo's
                // after the moveTo data
                if (token.type == Token_Numeric || token.type == Token_Minus)
                {
                    AssertIsNumber(); // just in assert is really a number...
                    if (older_ident == PATH_IDENT_MOVETO || older_ident == PATH_IDENT_MOVETO_ABS) {
                        // this is where we skip the second modeTo coordinate...
                        token = GetToken(&tokenizer);
                        if (token.type != Token_Identifier)
                        {
                            path.asSpecialMoveTo = true;
                            current_ident = PATH_IDENT_LINETO;
                            goto PARSE;
                        }
                    }
                    else if (token.type == Token_Numeric ||
                        token.type == Token_Minus) {
                        // no need to set bellow what identifier it is because 
                        // is already found to not be one
                        goto PARSE;
                    }
                }


                if (token == "m") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_MOVETO;
                    goto PARSE;
                }
                else if (token == "M") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_MOVETO_ABS;
                    goto PARSE;
                }

                if (token == "l") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO;
                    goto PARSE;
                }
                else if (token == "L") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_ABS;
                    goto PARSE;
                }

                if (token == "h") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL;
                    goto PARSE;
                }
                else if (token == "H") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL_ABS;
                    goto PARSE;
                }

                if (token == "v") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL;
                    goto PARSE;
                }
                else if (token == "V") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL_ABS;
                    goto PARSE;
                }

                if (token == "c") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_CURVETO;
                    goto PARSE;
                }
                else if (token == "C") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_CURVETO_ABS;
                    goto PARSE;
                }

                if (token == "s") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO;
                    goto PARSE;
                }
                else if (token == "S") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO_ABS;
                    goto PARSE;
                }

                if (token == "q") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE;
                    goto PARSE;
                }
                else if (token == "Q") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE_ABS;
                    goto PARSE;
                }

                if (token == "t") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE;
                    goto PARSE;
                }
                else if (token == "T") {
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE_ABS;
                    goto PARSE;
                }

                if (token == "a")
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_ARC;
                else if (token == "A")
                    current_ident = ePATH_IDENT_TYPES::PATH_IDENT_ARC_ABS;

            PARSE:

                switch (current_ident)
                {
                case ePATH_IDENT_TYPES::PATH_IDENT_MOVETO:
                case ePATH_IDENT_TYPES::PATH_IDENT_MOVETO_ABS:
                {
                    SVG_SET_Path_MoveToData(current_ident, tokenizer, path);
                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO:
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_ABS:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::normal, current_ident, tokenizer, path);
                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL:
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL_ABS:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::horizontal, current_ident, tokenizer, path);
                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL:
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL_ABS:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::vertical, current_ident, tokenizer, path);
                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_CURVETO:
                case ePATH_IDENT_TYPES::PATH_IDENT_CURVETO_ABS:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO:
                case ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO_ABS:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE:
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE_ABS:
                {
                    Array<char> buffer = {};
                    defer{
                        buffer.Release();
                    };
                    buffer.Reserve(MAX_STRING_CHARS);
                    for (irange(i, 0, (int)strlen(token.text) - 1))
                    {
                        ZString it = &token.text[i];
                        if (*it == 'q' || *it == 'Q' || *it == ' ') continue;
                        buffer.Push(*it);
                        if (*it == 'z' || *it == 'Z') break;
                    }
                    //std::libc::strncpy(buffer, token.text, std::strlen(token.text) * char.sizeof);

                    //ZString at = buffer;
                    //hm::Advance(&at, 1); // skip the letter
                    //at = hm::EatSpaces(at); // removes the starting spaces after the letter if any

                    // count how many quadretos I need to create?
                    int q_coords_count = 0;
                    For(buffer) {
                        if (it == '\0' || std::isalpha(it)) break;
                        if (it == ',') q_coords_count += 1;
                    }
                    /*
                    while (true)
                    {
                        if (*at == ',') q_coords_count++;
                        else if(std::isalpha(*at)) break;
                        hm::Advance(&at, 1);
                    }*/

                    Array<Vec2f> coordsArray = {};
                    defer{
                        coordsArray.Release();
                    };
                    if (q_coords_count) coordsArray.Reserve(q_coords_count);

                    //// todo the rest bellow

                    // get the next token
                    token = GetToken(&tokenizer);
                    AssertIsNumber();


                    int curves_count = q_coords_count / 2;
                    path.curves.Reserve(curves_count);
                    for (irange(i, 0, curves_count - 1)) {
                        // WARNING(HM) Need to use free() to release the memory not delete!!!
                        // for some reason new causes a crash here!?
                        //auto* curve = (Curve*)std::calloc(1, sizeof(Curve));
                        path.curves.Push();
                    }
                    //auto curve = hplNew(hpl::Curve, ());

                    Vec2f start;
                    if (curves_count == 1) {
                        if (path.lines.count) {
                            start = path.lines[path.lines.count - 1].end;
                        }
                        else
                            start = path.moveTo;

                        SVG_SET_Q_CurveData(start, tokenizer, token, path.curves[0]);
                    }
                    else {
                        Fori(i, path.curves)
                        {
                            // handles first curve data only
                            if (i == 0) {
                                if (path.lines.count) {
                                    start = path.lines[path.lines.count - 1].end;
                                }
                                else
                                    start = path.moveTo;

                                SVG_SET_Q_CurveData(start, tokenizer, token, it);

                                // then advance to the next Q curve coords
                                if (token.type != Token_Identifier)
                                    AdvanceToNextCoords(tokenizer, token);

                                continue;
                            }

                            // @delete for debbugging only
                            if (i == curves_count - 1) {
                                int stop = 0;
                            }

                            if (IsEndOfPath(token)) break;

                            // if more than one curve 
                            // start coordinate of next curves is the previous curve end
                            start = path.curves[i - 1].end;
                            SVG_SET_Q_CurveData(start, tokenizer, token, it);

                            // then advance to the next Q curve coords
                            if (token.type != Token_Identifier) {
                                if (i == curves_count - 1) // last curve
                                    break;

                                AdvanceToNextCoords(tokenizer, token);
                            }
                        }
                    }

                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE:
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE_ABS:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_ARC:
                case ePATH_IDENT_TYPES::PATH_IDENT_ARC_ABS:
                {
                    assert(false); // not done
                }break;
                default:
                    should_break_main = true;
                    break;
                }

                if (should_break_main) break;
            }
            break;
            default:
                // NOTE(HM) token.len value will NOT print! 
                // The number shown on the print, is the token type or id, 
                // the token.len is only used to tell printf the amount of characters it should print
                // as the "token" is really a big string with other words in it
                //LOG_EXTERN_CONSOLE("%d: %.*s\n", token.type, token.len, token.text);
                break;
            }

            parsed_cmds_count += 1;
            older_ident = current_ident;
        }
    }

    return path_data;
}
#endif


inline fn ePATH_IDENT_TYPES IdentTypeFromToken(const Token& token, SVG_D_Path& path)
{
    ePATH_IDENT_TYPES current_ident;

    if (token == "m" || token == "M") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_MOVETO;
    }
    else if (token == "l" || token == "L") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO;
    }
    else if (token == "h" || token == "H") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL;
    }
    else if (token == "v" || token == "V") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL;
    }
    else if (token == "c" || token == "C") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_CURVETO;
    }
    else if (token == "s" || token == "S") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO;
    }
    else if (token == "q" || token == "Q") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE;
    }
    else if (token == "t" || token == "T") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE;
    }
    else if (token == "a" || token == "A") {
        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_ARC;
    }

    path.moveTOasAbsCoords = CheckUpperCase(token);

    return current_ident;
}

fn void SVG_ParsePathData(const String& path_string, SVG_D_Path& path) 
{
    if (!path_string.empty())
    {
        LOG("Parsin:", path_string.c_str());
        LOG("\n Path -> \"%s\"", path_string.c_str());

        ZString buffer = (ZString)mem::malloc(path_string.length() + 1);
        defer{ mem::free(buffer) };

        libc::strncpy(buffer, path_string.c_str(), path_string.length() + 1);

        // create the tokenizer to parse the path data
        Tokenizer tokenizer = {};
        tokenizer.at = buffer;

        char older_ident, current_ident = 0;

        bool parsing = true;
        int parsed_cmds_count = 0;

        while (parsing)
        {
            Token token = GetToken(&tokenizer);
            switch (token.type)
            {
            case Token_Comma:
                // go to next token
                break;
            case Token_EndOfStream:
                if (parsed_cmds_count <= 0) LOG("%s", " - Nothing to parse.\n");
                parsing = false;
                break;
            case Token_Unknown:
                LOG(" - Skiping unkown token: %d: %.*s\n", token.type, token.len, token.text);
                break;
            case Token_Minus: // will behave has a identifier...
            case Token_Numeric: // will behave has a identifier...
            case Token_Identifier:
            {
                current_ident = 0;

                if IsEndOfPath(token)
                {
                    // current path end, go to the next path
                    parsing = false;
                    break;
                }

                bool should_break_main = true; // break switch(token.type)

                // handling for the "special" lineTo's
                // after the moveTo data
                bool should_get_ident = true;
                if (token.type == Token_Numeric || token.type == Token_Minus)
                {
                    should_get_ident = false;

                    AssertIsNumber(); // just assert is really a number...
                    if (older_ident == PATH_IDENT_MOVETO) 
                    {
                        // this is where we skip the second moveTo coordinate...
                        token = GetToken(&tokenizer);
                        if (token.type != Token_Identifier)
                        {
                            path.asSpecialMoveTo = TRUE;
                            current_ident = PATH_IDENT_LINETO;
                        }
                        else 
                        {
                            should_get_ident = true;
                        }
                    }
                }
                
                if(should_get_ident)
                    current_ident = IdentTypeFromToken(token, path);


                switch (current_ident)
                {
                case ePATH_IDENT_TYPES::PATH_IDENT_MOVETO:
                {
                    SVG_SET_Path_MoveToData(current_ident, tokenizer, path);
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::normal, current_ident, tokenizer, path);
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::horizontal, current_ident, tokenizer, path);
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL:
                {
                    SVG_SET_Path_LineToData(Line::LINE_TYPE::vertical, current_ident, tokenizer, path);
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_CURVETO:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE:
                {
                    Array<char> buffer = {};
                    defer{
                        buffer.Release();
                    };
                    buffer.Reserve(MAX_STRING_CHARS);
                    for (irange(i, 0, (int)strlen(token.text) - 1))
                    {
                        ZString it = &token.text[i];
                        if (*it == 'q' || *it == 'Q' || *it == ' ') continue;
                        buffer.Push(*it);
                        if (*it == 'z' || *it == 'Z') break;
                    }
                    //std::libc::strncpy(buffer, token.text, std::strlen(token.text) * char.sizeof);

                    //ZString at = buffer;
                    //hm::Advance(&at, 1); // skip the letter
                    //at = hm::EatSpaces(at); // removes the starting spaces after the letter if any

                    // count how many quadretos I need to create?
                    int q_coords_count = 0;
                    For(buffer) {
                        if (it == '\0' || std::isalpha(it)) break;
                        if (it == ',') q_coords_count += 1;
                    }
                    /*
                    while (true)
                    {
                        if (*at == ',') q_coords_count++;
                        else if(std::isalpha(*at)) break;
                        hm::Advance(&at, 1);
                    }*/

                    Array<Vec2f> coordsArray = {};
                    defer{
                        coordsArray.Release();
                    };
                    if (q_coords_count) coordsArray.Reserve(q_coords_count);

                    //// todo the rest bellow

                    // get the next token
                    token = GetToken(&tokenizer);
                    AssertIsNumber();


                    int curves_count = q_coords_count / 2;
                    path.curves.Reserve(curves_count);
                    for (irange(i, 0, curves_count - 1)) {
                        // WARNING(HM) Need to use free() to release the memory not delete!!!
                        // for some reason new causes a crash here!?
                        //auto* curve = (Curve*)std::calloc(1, sizeof(Curve));
                        path.curves.Push();
                    }
                    //auto curve = hplNew(hpl::Curve, ());

                    Vec2f start;
                    if (curves_count == 1) {
                        if (path.lines.count) {
                            start = path.lines[path.lines.count - 1].end;
                        }
                        else
                            start = path.moveTo;

                        SVG_SET_Q_CurveData(start, tokenizer, token, path.curves[0]);

                        path.curves[0].abs_coordinates = path.moveTOasAbsCoords;
                    }
                    else {
                        Fori(i, path.curves)
                        {
                            // handles first curve data only
                            if (i == 0) {
                                if (path.lines.count) {
                                    start = path.lines[path.lines.count - 1].end;
                                }
                                else
                                    start = path.moveTo;

                                SVG_SET_Q_CurveData(start, tokenizer, token, it);

                                it.abs_coordinates = path.moveTOasAbsCoords;

                                // then advance to the next Q curve coords
                                if (token.type != Token_Identifier)
                                    AdvanceToNextCoords(tokenizer, token);

                                continue;
                            }

                            // @delete for debbugging only
                            if (i == curves_count - 1) {
                                int stop = 0;
                            }

                            if IsEndOfPath(token) 
                                break;

                            // if more than one curve 
                            // start coordinate of next curves is the previous curve end
                            start = path.curves[i - 1].end;
                            SVG_SET_Q_CurveData(start, tokenizer, token, it);

                            it.abs_coordinates = path.moveTOasAbsCoords;

                            // then advance to the next Q curve coords
                            if (token.type != Token_Identifier) {
                                if (i == curves_count - 1) // last curve
                                    break;

                                AdvanceToNextCoords(tokenizer, token);
                            }
                        }
                    }

                    should_break_main = true;
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE:
                {
                    assert(false); // not done
                }break;
                case ePATH_IDENT_TYPES::PATH_IDENT_ARC:
                {
                    assert(false); // not done
                }break;
                default:
                    break;
                }

                if (should_break_main) // break switch(token.type)
                    break;
            }
            break;
            default:
                // NOTE(HM) token.len value will NOT print! 
                // The number shown on the print, is the token type or id, 
                // the token.len is only used to tell printf the amount of characters it should print
                // as the "token" is really a big string with other words in it
                //LOG_EXTERN_CONSOLE("%d: %.*s\n", token.type, token.len, token.text);
                break;
            }

            parsed_cmds_count += 1;
            older_ident = current_ident;
        }

        LOG("\nDone.\n");
    }
}

/// <summary>
/// SVG_ParsePathData Parses the path data inside the svg file
/// </summary>
/// <param name="paths"></param>
/// <param name="svgout"></param>
/// <returns></returns>
#if 0
fn bool SVG_ParsePathData(const tStringVec& paths_vec, SVG_RAW_DATA& svgout) {
    // create the required path data to save the data in
    auto& paths = svgout.g_elem.path_elem.d.paths;
    paths.Reserve(paths_vec.size());

    Fori(i, paths_vec)
    {
        if (!it.empty())
        {
            // create the path object to save the path data in
            auto path = hplNew(SVG_D_Path, ());
            defer{
                paths.Push(*path);
            };

            // @delete for debbugging only
            //if (i == 2) {
                // TODO(HM) 
                // I need to handle special lines after the moveTo data still
                // right now this breaks, I'm stopping at path index 2 
                // because it has a special line after the moveto coords for testing
                //int stop = 0;
            //}

            ZString buffer = (ZString)mem::malloc(it.length() + 1);
            defer{ mem::free(buffer) };

            libc::strncpy(buffer, it.c_str(), it.length() + 1);

            // create the tokenizer to parse the path data
            Tokenizer tokenizer = {};
            tokenizer.at = buffer;

            char older_ident, current_ident = 0;

            bool parsing = true;
            int parsed_cmds_count = 0;
            while (parsing)
            {
                Token token = GetToken(&tokenizer);
                switch (token.type)
                {
                case Token_Comma:
                    // go to next token
                    break;
                case Token_EndOfStream:
                    if (parsed_cmds_count <= 0) LOG("%s", "Nothing to parse.\n");
                    parsing = false;
                    break;
                case Token_Unknown:
                    LOG("Skiping unkown token: %d: %.*s\n", token.type, token.len, token.text);
                    break;
                case Token_Minus: // will behave has a identifier...
                case Token_Numeric: // will behave has a identifier...
                case Token_Identifier:
                {
                    bool should_break_main = false;
                    current_ident = 0;

                    // get out
                    if (token == "z" || token == "Z") {
                        // current path end, go to the next path
                        parsing = false;
                        break;
                    }

                    // handling for the "special" lineTo's
                    // after the moveTo data
                    if (token.type == Token_Numeric || token.type == Token_Minus)
                    {
                        AssertIsNumber(); // just in assert is really a number...
                        if (older_ident == PATH_IDENT_MOVETO || older_ident == PATH_IDENT_MOVETO_ABS) {
                            // this is where we skip the second modeTo coordinate...
                            token = GetToken(&tokenizer);
                            if (token.type != Token_Identifier)
                            {
                                path->asSpecialMoveTo = true;
                                current_ident = PATH_IDENT_LINETO;
                                goto PARSE;
                            }
                        }
                        else if (token.type == Token_Numeric ||
                            token.type == Token_Minus) {
                            // no need to set bellow what identifier it is because 
                            // is already found to not be one
                            goto PARSE;
                        }
                    }


                    if (token == "m") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_MOVETO;
                        goto PARSE;
                    }
                    else if (token == "M") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_MOVETO_ABS;
                        goto PARSE;
                    }

                    if (token == "l") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO;
                        goto PARSE;
                    }
                    else if (token == "L") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_ABS;
                        goto PARSE;
                    }

                    if (token == "h") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL;
                        goto PARSE;
                    }
                    else if (token == "H") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL_ABS;
                        goto PARSE;
                    }

                    if (token == "v") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL;
                        goto PARSE;
                    }
                    else if (token == "V") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL_ABS;
                        goto PARSE;
                    }

                    if (token == "c") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_CURVETO;
                        goto PARSE;
                    }
                    else if (token == "C") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_CURVETO_ABS;
                        goto PARSE;
                    }

                    if (token == "s") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO;
                        goto PARSE;
                    }
                    else if (token == "S") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO_ABS;
                        goto PARSE;
                    }

                    if (token == "q") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE;
                        goto PARSE;
                    }
                    else if (token == "Q") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE_ABS;
                        goto PARSE;
                    }

                    if (token == "t") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE;
                        goto PARSE;
                    }
                    else if (token == "T") {
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE_ABS;
                        goto PARSE;
                    }

                    if (token == "a")
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_ARC;
                    else if (token == "A")
                        current_ident = ePATH_IDENT_TYPES::PATH_IDENT_ARC_ABS;

                PARSE:

                    switch (current_ident)
                    {
                    case ePATH_IDENT_TYPES::PATH_IDENT_MOVETO:
                    case ePATH_IDENT_TYPES::PATH_IDENT_MOVETO_ABS:
                    {
                        tFloatVec coords;
                        SVG_SET_Path_MoveToData(*path, current_ident, tokenizer, coords);
                        should_break_main = true;
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO:
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_ABS:
                    {
                        SVG_SET_Path_LineToData(Line::LINE_TYPE::normal, *path, current_ident, tokenizer);
                        should_break_main = true;
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL:
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_HORIZONTAL_ABS:
                    {
                        SVG_SET_Path_LineToData(Line::LINE_TYPE::horizontal, *path, current_ident, tokenizer);
                        should_break_main = true;
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL:
                    case ePATH_IDENT_TYPES::PATH_IDENT_LINETO_VERTIVAL_ABS:
                    {
                        SVG_SET_Path_LineToData(Line::LINE_TYPE::vertical, *path, current_ident, tokenizer);
                        should_break_main = true;
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_CURVETO:
                    case ePATH_IDENT_TYPES::PATH_IDENT_CURVETO_ABS:
                    {
                        assert(false); // not done
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO:
                    case ePATH_IDENT_TYPES::PATH_IDENT_SMOOTH_CURVETO_ABS:
                    {
                        assert(false); // not done
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE:
                    case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_BCURVE_ABS:
                    {
                        Array<char> buffer = {};
                        defer{
                            buffer.Release();
                        };
                        buffer.Reserve(MAX_STRING_CHARS);
                        for (irange(i, 0, (int)strlen(token.text) - 1))
                        {
                            ZString it = &token.text[i];
                            if (*it == 'q' || *it == 'Q' || *it == ' ') continue;
                            buffer.Push(*it);
                            if (*it == 'z' || *it == 'Z') break;
                        }
                        //std::libc::strncpy(buffer, token.text, std::strlen(token.text) * char.sizeof);

                        //ZString at = buffer;
                        //hm::Advance(&at, 1); // skip the letter
                        //at = hm::EatSpaces(at); // removes the starting spaces after the letter if any

                        // count how many quadretos I need to create?
                        int q_coords_count = 0;
                        For(buffer) {
                            if (it == '\0' || std::isalpha(it)) break;
                            if (it == ',') q_coords_count += 1;
                        }
                        /*
                        while (true)
                        {
                            if (*at == ',') q_coords_count++;
                            else if(std::isalpha(*at)) break;
                            hm::Advance(&at, 1);
                        }*/

                        Array<Vec2f> coordsArray = {};
                        defer{
                            coordsArray.Release();
                        };
                        if (q_coords_count) coordsArray.Reserve(q_coords_count);

                        //// todo the rest bellow

                        // get the next token
                        token = GetToken(&tokenizer);
                        AssertIsNumber();


                        int curves_count = q_coords_count / 2;
                        path->curves.Reserve(curves_count);
                        for (irange(i, 0, curves_count - 1)) {
                            // WARNING(HM) Need to use free() to release the memory not delete!!!
                            // for some reason new causes a crash here!?
                            //auto* curve = (Curve*)std::calloc(1, sizeof(Curve));
                            path->curves.Push();
                        }
                        //auto curve = hplNew(hpl::Curve, ());

                        Vec2f start;
                        if (curves_count == 1) {
                            if (path->lines.count) {
                                start = path->lines[path->lines.count - 1].end;
                            }
                            else
                                start = path->moveTo;

                            SVG_SET_Q_CurveData(path->curves[0], start, tokenizer, token);
                        }
                        else {
                            Fori(i, path->curves)
                            {
                                // handles first curve data only
                                if (i == 0) {
                                    if (path->lines.count) {
                                        start = path->lines[path->lines.count - 1].end;
                                    }
                                    else
                                        start = path->moveTo;

                                    SVG_SET_Q_CurveData(it, start, tokenizer, token);

                                    // then advance to the next Q curve coords
                                    if (token.type != Token_Identifier)
                                        AdvanceToNextCoords(tokenizer, token);

                                    continue;
                                }

                                // @delete for debbugging only
                                if (i == curves_count - 1) {
                                    int stop = 0;
                                }

                                if (IsEndOfPath(token)) break;

                                // if more than one curve 
                                // start coordinate of next curves is the previous curve end
                                start = path->curves[i - 1].end;
                                SVG_SET_Q_CurveData(it, start, tokenizer, token);

                                // then advance to the next Q curve coords
                                if (token.type != Token_Identifier) {
                                    if (i == curves_count - 1) // last curve
                                        break;

                                    AdvanceToNextCoords(tokenizer, token);
                                }
                            }
                        }

                        should_break_main = true;
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE:
                    case ePATH_IDENT_TYPES::PATH_IDENT_QUADRATIC_SMOOTH_BCURVE_ABS:
                    {
                        assert(false); // not done
                    }break;
                    case ePATH_IDENT_TYPES::PATH_IDENT_ARC:
                    case ePATH_IDENT_TYPES::PATH_IDENT_ARC_ABS:
                    {
                        assert(false); // not done
                    }break;
                    default:
                        should_break_main = true;
                        break;
                    }

                    if (should_break_main) break;
                }
                break;
                default:
                    // NOTE(HM) token.len value will NOT print! 
                    // The number shown on the print, is the token type or id, 
                    // the token.len is only used to tell printf the amount of characters it should print
                    // as the "token" is really a big string with other words in it
                    //LOG_EXTERN_CONSOLE("%d: %.*s\n", token.type, token.len, token.text);
                    break;
                }

                parsed_cmds_count += 1;
                older_ident = current_ident;
            }
        }
    }

    return true;
}
#endif // 0

fn bool SVG_ParsePathDataString(String& path_data, XMLElement& elem, ZString filepath, SVG_RAW_DATA& svgout) {
    // count how many paths are in the data, by counting the m's
    int path_count = 0;
    For(path_data) {
        if (it == 'M' || it == 'm') 
            path_count += 1;
    }

    if (path_count == 0) {
        LOG_ERROR("Invalid SVG file found! No \"m/M\" characters found in <path> \
        attribute 'd', in file: '%s'!\n", filepath);
        //
        hpl::Error("Invalid SVG file: \"&s\"\n", filepath);
        hpl::Error(" No valid paths found in <path> attribute 'd'!\n");
        return false;
    }

    ///
    // everything should be fine from here
    ///

    // cut the single path string, into separate strings for easy parsing
    tStringVec paths = {};
    paths.reserve(path_count);

    uint first = 1;
    int old_index = 0;
    ZString last_char_addres;
    Fori(i, path_data) {
        if (it == 'z' || it == 'Z') {
            if (first) {
                paths.push_back(path_data.substr(0, ((&path_data.at(i) - &path_data.at(0)) + 1) * char.sizeof));
                last_char_addres = &it;
                first = 0;
                old_index = i;
            }
            else {
                paths.push_back(path_data.substr(old_index + 1, ((&it - last_char_addres) + 1) * char.sizeof));
                last_char_addres = &it;
                old_index = i;
            }
            continue;
        }
    }

    // clear any space at the start of the path string
    For(paths) {
        //it = hm::EatSpaces(it);
        EatSpacesStartingFrom(0, it);
    }

    // create the required path buffers to save the data in
    for(irange(i, 0, paths.size() - 1))
        svgout.g_elem.path_elem.d.paths.Push();

    // now parse each individual path data string to get the required data
#if 0
    Fori(i, svgout.g_elem.path_elem.d.paths) {
        auto* data = SVG_ParsePathData(paths[i]);
        // deep copy data
        it = *data;
        // delete the pointer and older data
        hplDelete(data);
    }
#else
    Fori(i, svgout.g_elem.path_elem.d.paths) {
        SVG_ParsePathData(paths[i], it);
    }
#endif // 0


    /*if (SVG_ParsePathData(paths, svgout)) {
        return true; 
    }*/

    return true;
}
///////////////////

inline fn void SVG_Set_RootTransformData(SVG_RAW_DATA& svg, ZString transform) {
    auto* buffer = (ZString)mem::malloc(strlen(transform) * char.sizeof + 1);
    libc::strncpy(buffer, transform, strlen(transform) * char.sizeof + 1);
    defer{
        mem::free(buffer);
    };
#if 1
    Tokenizer tokenizer = {};
    tokenizer.at = buffer;

    bool parsing = true;
    int parsed_cmds_count = 0;
    while (parsing)
    {
        Token token = GetToken(&tokenizer);
        switch (token.type)
        {
        case Token_EndOfStream:
            if (parsed_cmds_count <= 0) LOG("%s", "Nothing to parse.\n");
            parsing = false;
            break;
        case Token_Unknown:
            LOG("Skiping unkown token: %d: %.*s\n", token.type, token.len, token.text);
            break;
        case Token_Identifier:
        {
            if (token == "translate")
                svg.g_elem.transform.type = Transform_Translate;
            else if (token == "rotate")
                svg.g_elem.transform.type = Transform_Rotate;
            else if (token == "scale")
                svg.g_elem.transform.type = Transform_Scale;
        }
        break;
        case Token_OpenParen:
        {
            Token token = GetToken(&tokenizer);
            AssertIsNumber();

            Vec2f coords = cString::ToVector2f(token.text, vec2f_zero);
            // save the first number
            svg.g_elem.transform.value.x = coords[0];
            // save the second number
            svg.g_elem.transform.value.y = coords[1];
        }
        break;
        case Token_CloseParen:
            parsing = false;
        break;
        default:
            // NOTE(HM) token.len value will NOT print! 
            // The number shown on the print, is the token type or id, 
            // the token.len is only used to tell printf the amount of characters it should print
            // as the "token" is really a big string with other words in it
            //LOG_EXTERN_CONSOLE("%d: %.*s\n", token.type, token.len, token.text);
            break;
        }

        parsed_cmds_count += 1;
    }
#else
    ZString at;
    ZString first_number_start;
    ZString second_number_start;

    at = buffer;
    while (*at != '\0') {
        // skip the word
        while (*at != '(') {
            Advance(&at, 1);
        }

        // close the word
        (*at) = '\0';

        // set the transform type
        if (String(buffer) == "translate")
            svg.g_elem.transform.type = svg.g_elem.transform.translate;
        else if (String(buffer) == "rotate")
            svg.g_elem.transform.type = svg.g_elem.transform.rotate;
        else if (String(buffer) == "translate")
            svg.g_elem.transform.type = svg.g_elem.transform.scale;

        // skip null terminator
        Advance(&at, 1);

        // set first number start pointer
        first_number_start = &(*at);

        // now skip the first number data
        while (*at != ',') {
            Advance(&at, 1);
        }

        // close the first number
        (*at) = '\0';

        //skip null terminator
        Advance(&at, 1);

        // save the first number
        svg.g_elem.transform.value.x = cString::ToFloat(first_number_start, 0.f);

        // set the first number start pointer
        second_number_start = &(*at);

        // skip the second number data
        while (*at != ')') {
            Advance(&at, 1);
        }

        // close the second number
        (*at) = '\0';

        // save the second number
        svg.g_elem.transform.value.y = cString::ToFloat(second_number_start, 0.f);
    }
#endif // 0
}

#if 0
fn bool ParseSVG(ZString filepath, SVG_RAW_DATA& svg, cSystem* mpSystem) {
    assert(filepath != null);

    u32 lStartTime = mpSystem->GetLowLevel()->GetTime();

    // TODO (change this for tixml2....)
    auto* pXmlDoc = hplNew(TiXmlDocument, (filepath));
    defer{
        hplDelete(pXmlDoc);
    };

    bool sucess = pXmlDoc->LoadFile();
    if (!sucess)
    {
        Error("Couldn't load SVG XML file '%s'!\n", filepath);
        //hplDelete(pXmlDoc);
        return false;
    }

    u32 lTime = mpSystem->GetLowLevel()->GetTime() - lStartTime;
#ifdef DEBUG
    Warning("Loading collada SVG file for '%s' took: %d ms\n", filepath, lTime);
#endif // DEBUG

    //Get the xml root element.
    TiXmlHandle docHandle(pXmlDoc);
    if (docHandle.ToNode() != null) {
        // Load main <svg> element.
        TiXmlElement* svgRoot = docHandle.FirstChildElement("svg").ToElement();
        if (!svgRoot)
        {
            Error("Couldn't find required SVG root element in: '%s'!\n", filepath);
            return false;
        }

        // TODO get element discription
        TiXmlElement* svgDescription = docHandle.FirstChildElement("desc").ToElement();
        if (svgDescription)
        {
            svg.description = svgDescription->Value();
        }


        // ******
        // get the width and height data
        ZString remainder = new char[MAX_STRING_CHARS];
        defer{
            delete[] remainder;
        };

        ZString w = svgRoot->Attribute("width");
        if (w && *w) {
            svg.width = SVG_AttibuteDataToFloat(w, &remainder);
        }

        ZString h = svgRoot->Attribute("height");
        if (h && *h) {
            svg.height = SVG_AttibuteDataToFloat(h, &remainder);
        }
        ///

        // get the scale type for the width and height
        if (!String(remainder).empty()) {
            auto meter = String(remainder);
            if (meter == "mm") svg.scale = svg.milimeter;
            else if (meter == "m") svg.scale = svg.meter;
            else svg.scale = svg.unknown;
        }
        /// <summary>
        /// parse bounds
        /// </summary>
        ZString viewBox_string = svgRoot->Attribute("viewBox");
        if (viewBox_string && *viewBox_string) {
            //auto* arr = hm::Array4fFromText(viewBox);
            tFloatVec coords = {};
            cString::GetFloatVec(viewBox_string, coords, NULL);
            if (coords.size()) {
                svg.bounds.pos = Vec2f(coords[0], coords[1]);
                svg.bounds.size = Vec2f(coords[2], coords[3]);
            }
        }
        //

        svg.version = cString::ToString(svgRoot->Attribute("version"), "");
        svg.id = cString::ToString(svgRoot->Attribute("id"), "");

        // TODO(HM) Parse <defs/> Element data
        // 
        // here
        //

        ////
        /// Parse the <g></g> Element
        ////
        TiXmlElement* svgG_Element = svgRoot->FirstChildElement("g");
        if (svgG_Element)
        {
            // set the id
            svg.g_elem.id = cString::ToString(svgG_Element->Attribute("id"), "");

            // set transform attribute data
            ZString transform = svgG_Element->Attribute("transform");
            if (transform && *transform) {
                SVG_Set_RootTransformData(svg, transform);
            }

            // now the main path data
            TiXmlElement* svgG_PathElement = svgG_Element->FirstChildElement("path");
            if (svgG_PathElement)
            {
                String path_data = svgG_PathElement->Attribute("d");
                if (path_data.empty())
                    return false;

                svg.g_elem.path_data.d.data_string = path_data;

                // count how many paths are in the data by counting the m?
                int path_count = 0;
                For(path_data) {
                    if (it == 'M' || it == 'm') path_count += 1;
                }

                if (path_count <= 0) {
                    Error("Invalid SVG file: &s\n", filepath);
                    Error(" error: No paths in <path> attribute!\n");
                    return false;
                }

                // everthing fine from here
                // 
                // cut the paths data into diferent strings
                tStringVec paths = {};
                paths.reserve(path_count);

                uint first = 1;
                int old_index = 0;
                ZString last_char_addres;
                Fori(i, path_data) {
                    if (it == 'z' || it == 'Z') {
                        if (first) {
                            paths.push_back(path_data.substr(0, ((&path_data.at(i) - &path_data.at(0)) + 1) * char.sizeof));
                            last_char_addres = &it;
                            first = 0;
                            old_index = i;
                        }
                        else {
                            paths.push_back(path_data.substr(old_index + 1, ((&it - last_char_addres) + 1) * char.sizeof));
                            last_char_addres = &it;
                            old_index = i;
                        }
                        continue;
                    }
                }


                SVG_ParsePathData(paths, svg);

                return true;
            }
        }
    }
    return false;
}
#else
fn SVG_RAW_DATA* SVG_LoadFromFile(ZString filepath, cSystem* mpSystem) 
{
    if ((filepath && *filepath) == false || !mpSystem) return null;

    u32 startTime   = mpSystem->GetLowLevel()->GetTime();
    bool loadSucess = false;

    // create the temp local stack object where to save the svg file data
    // needs to be defined at this function internal global scope
    SVG_RAW_DATA svg = {};
    //

    XMLDocument pXmlDoc;

    int xmlError = pXmlDoc.LoadFile(filepath);
    if (xmlError)
    {
        LOG_ERROR("Unable to load SVG file: '%s' with error : %d!\n", filepath, xmlError);
        return null;
    }

    XMLHandle docHandle(pXmlDoc);
    if (docHandle.ToNode() == null)
    {
        LOG_ERROR("XMLHandle returned null for SVG file: '%s'!\n", filepath);
        return null;
    }
    
    // find main <svg> root element.
    XMLElement* svgRoot = docHandle.FirstChildElement("svg").ToElement();
    if (!svgRoot)
    {
        LOG_ERROR("SVG - Unable to find required root element in file: '%s'!\n", filepath);
        return null;
    }

    // NOTE(HM) all well from here...

    // from what svg file is this data taken from
    svg.sourcefile = filepath;

    // get file name from path
    // 
    // swap '\' to '/'
    For(svg.sourcefile) {
        if(it == '\\') it = '/';
    }

    u32 offset = svg.sourcefile.find_last_of('/');
    String name   = cString::Sub(svg.sourcefile, offset + 1, svg.sourcefile.length() - (offset + 1));
    svg.file_name  = std::move(name); // includes the file type    //cString::Sub(name, 0, name.length() - name.find_first_of('.'));

    // get discription, if any
    XMLElement* svgDescription = svgRoot->FirstChildElement("g")->FirstChildElement("path")->FirstChildElement("desc")->ToElement();
    if (svgDescription) {
        svg.description = svgDescription->GetText();
    }

    // get the <svg> width and height data
    /*ZString remainder = hplNewArray(char, MAX_STRING_CHARS);
    defer {
        hplDeleteArray(remainder);
    };*/

    // get the scale_type for the width and height
    svg.scale_type = SVG_GetScaleType(svgRoot->Attribute("width"));

    /// <summary>
    /// parse bounds
    /// </summary>
    ZString viewBox_string = svgRoot->Attribute("viewBox");
    if (viewBox_string && *viewBox_string) {
        tFloatVec coords = {};
        cString::GetFloatVec(viewBox_string, coords, NULL);
        if (coords.size()) {
            svg.bounds.pos = Vec2f(coords[0], coords[1]);
            svg.bounds.size = Vec2f(coords[2], coords[3]); // this seems to be just a repetition of the width and height...
        }
    }
    //

    svg.version = cString::ToString(svgRoot->Attribute("version"), "");
    svg.id = cString::ToString(svgRoot->Attribute("id"), "");

    // TODO(HM) Parse <defs/> Element data
    // 
    // here
    //

    ////
    /// Now Parse the <g></g> Element
    ////
    XMLElement* svgG_Element = svgRoot->FirstChildElement("g");
    if (svgG_Element)
    {
        // get id attribute
        svg.g_elem.id = cString::ToString(svgG_Element->Attribute("id"), "");

        // get transform attribute
        ZString transform = svgG_Element->Attribute("transform");
        if (transform && *transform) {
            SVG_Set_RootTransformData(svg, transform);
        }

        // now get the child <path> element data
        XMLElement* svgG_PathElement = svgG_Element->FirstChildElement("path");
        if (svgG_PathElement)
        {
            // get attribute 'd' string
            String path_data_text = svgG_PathElement->Attribute("d");
            if (path_data_text.empty()) {
                LOG_ERROR("SVG - Empty attribute 'd' found in element: '%s' in file: '%s'!\n", svgG_Element->ToText(), filepath);
                return null;
            }

            // Now Parse the entire path data inside the 'd' attribute
            loadSucess = SVG_ParsePathDataString(path_data_text, *svgG_Element, filepath, svg);

            // save the string for later if needed, this needs to be done after parsing
            // because path_data_text variable becomes invalid after
            svg.g_elem.path_elem.data_string = std::move(path_data_text);

        } else {
            LOG_ERROR("SVG - Required <path> element missing in file: '%s'!\n", filepath);
            return null;
        }
    }
    else {
        LOG_ERROR("SVG - Required <g></g> element missing in file: '%s'!\n", filepath);
        return null;
    }

    // return a copy of it on the heap, don't forget to delete it later...
    if (loadSucess) 
    {
        auto* result = hplNew(SVG_RAW_DATA, ());
        // NOTE(HM) c++ lesson:
        // Doing memcpy bellow didn't worked as I expected, because it performs a shallow copy. 
        // This means that the structure itself is copied, but anything the structure references,is not copied.
        // 
        // so some stack data, was still being referenced and obviously got cleared after I returned from the function,
        // In my ignorance because I'm returning a pointer, to a peace of memory I created new on the heap, 
        // I thought was fully copying the stack data, aka doing a deep copy, to the heap memory. 
        // It seems I was not...
        // 
        //  memcpy(result, &svg, sizeof(SVG_RAW_DATA)); // does a shallow copy
        // 
        // I found a clue why in a stack overflow website reply of all places...
        // 
        // "When you do memcpy(retValue, &result, sizeof(result));, 
        // you are copying internal std::string structure, not the string data. 
        // Assign string instead: *retValue = result; "
        // https://stackoverflow.com/questions/26068358/string-getting-corrupted-when-reading-from-file
        // see also
        // https://stackoverflow.com/questions/13284033/copying-structure-in-c-with-assignment-instead-of-memcpy
        // this worked has intended but I don't like it because is less descriptive.
        //*result = svg;
        // 
        // ps: even thou the assignment above works I decided to make the deep copy myself.
        result->Copy(svg);

        // print how long it took to load the file
        int current_time = mpSystem->GetLowLevel()->GetTime();
        int totalTime    = (current_time - startTime);
        LOG("Loading svg: \"%s\" took: %.2f sec.\n", filepath, MS2SEC(totalTime));

        return result;
    }
    else 
        return null;
}
#endif // 0

