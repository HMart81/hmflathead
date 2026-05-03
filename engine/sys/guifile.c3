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

// region module
module engine::sys::guip @private;

// region imports
import game::main; // for file logging or console logging
import engine::misc;
import engine::sys::framework::glsl;
import std::io, std::math;
import game::material::mtr;
import game::serialize::svs;
import game::material::manager::mtrmng;
import engine::logging::log;
import engine::filesystem::fs;
import engine::assets_api::astmng; // asset manager
import engine::sys::render2d::r2d;
import thirdparty::raylib5::rl;
import thirdparty::library::xml;
import std::collections::list, std::collections::tuple;
import engine::gui::window::uiwin;
// end_region

////////////////////////////////////////////////////////////////////////////////
//
//              GUIP File - file data structure
//
///////////////////////////////////////////////////////////////////////////////

alias WindowArgument = StringPair; // alias for a window arguments, which are a tuple of two strings (key, value)
alias WindowArgList = List{WindowArgument*};

const GUIP_VERSION_STRING = "1.0.0"; // the version of the file format
const GUIP_FILE_EXT = ".guip"; // the extension of the file

faultdef GUIP_INVALID_PATH,
	     GUIP_MALFORMED_FILE,
	     GUIP_UNKNOWN_FOLDER,
	     GUIP_FOLDER_SCAN_ERROR,
	     GUIP_READ_ERROR,
         GUIP_VERSION_MISMATCH,
         GUIP_PARSING_ERROR,
	     GUIP_SMALL_PATH_ERROR,
	     GUIP_RETRIVAL_ERROR,
	     GUIP_MISSING;

// NOTE(HM) This represents every main node in the guip xml file 
constdef GUIPNode : inline String @public
{
    ROOT             = "GUIP",
    TEXT             = "#text",
    WINDOW           = "window",
    PAIR             = "pair"
}

<*
    @param [&in] node : "node to compare the name"
*>
fn bool isXmlNode(XmlNode* node, GUIPNode kind) @inline @public => (node.name == kind) ? true : false;

// NOTE(HM) This represents the atributes assigned to every guip node
constdef GUIPNodeAttrib : inline String @public
{
    // general
    VERSION    = "version",
    NAME       = "name",
	RECT 	   = "rect",
    KEY        = "key",
    VAL        = "val"
}

constdef GUIPWinParm : inline String @public
{
	DESKTOP     = "window",
    VISIBLE     = "visible",
    BACKGROUND  = "background",
    MATCOLOR    = "matcolor",
    BACKCOLOR   = "backcolor",
    BORDERSIZE  = "bordersize",
    BORDERCOLOR = "bordercolor",
    FORECOLOR   = "forecolor",
    MATSCALEX   = "matscalex",
    MATSCALEY   = "matscaley",
    TEXT        = "text",
    TEXTSCALE   = "textscale",
    TEXTCOLOR   = "textcolor",
    FONT        = "font",
}

fn UIWindow*? read(String file_path)
{
	File? file = fs::openFile(game::gpGame.app_base_folder.tconcat(file_path));
	if(catch excuse = file)
    {
       log::warning(FILE, "Failed to open GUIP file [%s] with excuse: %s", file_path, excuse);
       return GUIP_READ_ERROR~;
    }

    XmlDoc*? doc = xml::read_file(file);
    defer doc.free()!!;
    
    if(catch excuse = doc)
    {
       log::warning(FILE, "Failed to read GUIP file [%s] with excuse: %s", file_path, excuse);
       return GUIP_READ_ERROR~;
    }
    
    return parse(doc, file_path);
}

<*
    @param [&in] doc : "xml doc file to parse"
	@param [in] file_path : "virtual path to the guip file"
*>
fn UIWindow*? parse(XmlDoc* doc, String file_path)
{
    bool invalid_guip = doc.rootNode.name != GUIPNode.ROOT;
    if(invalid_guip)
    {
       log::error(FILE, "Malformed guip file '%s', expected root 'GUIP' got '%s' instead.", file_path, doc.rootNode.name);
       return GUIP_MALFORMED_FILE~;
    }

    String? version = (String)doc.rootNode.getAttribute(GUIPNodeAttrib.VERSION).value;
    if (catch excuse = version)
    {
        log::error(FILE, "Failed to get guip %s version with excuse: %s\n", file_path, excuse);
        return GUIP_PARSING_ERROR~;
    }
    // else got version, so check if it matches the current version
    // TODO(HM) handle version changes.
    if(version != GUIP_VERSION_STRING)
    {
        log::error(FILE, "Invalid version for guip file '%s', expected '%s' got '%s' instead.", file_path, GUIP_VERSION_STRING, version);
        return GUIP_VERSION_MISMATCH~;
    }

    // else everything should be fine from here, so keep parsing
    
    // now parse each xml node
    foreach (node : doc.rootNode.children)
    {
        $if $feature(_DEBUG):
            if(node == null) 
            {
                log::error(FILE, "A null xml node was found in file '%s'!!", file_path);
                return GUIP_PARSING_ERROR~;
            }
        $endif

        switch
        {
            case isXmlNode(node, GUIPNode.TEXT):
                log::error(FILE, "Unexpected 'TEXT' node found in body of guip '%s'! Text = '%s' ", fs::getFileNameWithoutExt(file_path), node.value);
                return GUIP_PARSING_ERROR~;
            case isXmlNode(node, GUIPNode.WINDOW):
                return parse_window(node, file_path);
            default:
                log::warning(FILE, "Unexpected node '%s' in guip file '%s'", node.name, file_path);
                $if $feature(_DEBUG):
                    return GUIP_PARSING_ERROR~;
                $else
                    continue;
                $endif
        }
    } // end foreach node
    
    return GUIP_PARSING_ERROR~;
}


<*
    @param [&in] in_node : "material node we are currently parsing"
*>
fn UIWindow*? parse_window(XmlNode* in_node, String file_path)
{
	// first get material name
    String? win_name = (String)in_node.getAttribute(GUIPNodeAttrib.NAME).value;
    if (catch excuse = win_name)
    {
        log::error(FILE, "Failed to get name of a window inside '%s' with excuse: %s\n", file_path, excuse);
        return GUIP_PARSING_ERROR~;
    }

	// should this really be a error?
	if (win_name.is_empty())
    {
        log::error(FILE, "window with empty or no name inside '%s'\n", file_path);
        return GUIP_PARSING_ERROR~;
    }

	// windows with "window" name are always set to fullscreen

	bool is_desktop = (win_name == GUIPWinParm.DESKTOP);

    // else init the window structure in RAM to save the parsed data into
    UIWindow* uiwin = mem::new(UIWindow);

	bool early_out;
    defer {
        if(early_out) {
            uiwin.clear();
            mem::free(uiwin);
        }
    }

    uiwin.init(win_name, isDesktop: is_desktop, shouldRegister: true);

	String? rect_d = (String)in_node.getAttribute(GUIPNodeAttrib.RECT).value;
    if (catch excuse = rect_d)
    {
        log::error(FILE, "Failed to get rect dimensions of a window inside '%s' with excuse: %s\n", file_path, excuse);
		early_out = true;
        return GUIP_PARSING_ERROR~;
    }

	RLRectangle rect = getRect(rect_d, win_name, file_path)!;

	uiwin.setPositionV(rect.pos);
	uiwin.setSize(rect.w, rect.h);

    /////////////////////////////////////////////
    // NOTE(HM) this is the main part of the guip parsing, 
	// where we parse all the child nodes and set the data accordingly
    foreach (node : in_node.children)
    {
       // just in case...
       if(node == null) {
            log::warning(FILE, "Null child node found in '%s' of guip '%s', skipping it.", win_name, file_path);
            continue;
       }

       switch(node.name)
       {
            case GUIPNode.TEXT:
                log::warning(FILE, "Unexpected text node '%s' found in window '%s' of guip '%s'", node.name, win_name, file_path);
                continue;
            /*case GUIPNode.COMMENT: 
                //uiwin.parse_comment(node);
				nextcase default;*/
            case GUIPNode.PAIR: 
                parse_pair(node, win_name, file_path, &uiwin);
			default:
				log::warning(FILE, "Unknown node '%s' in window '%s' of guip '%s'", node.name, win_name, file_path);
                continue;
       }
    }
    
    return uiwin;
}

<*
    @param [&in] node : "xml node we are currently parsing"
    @param [in] win_name : "uiwin window we are currently parsing"
    @param [in] file_path : "guip file we are currently parsing"
    @param [&inout] uiwin : "pointer to UIWindow we are currently parsing"
*>
fn void parse_pair(XmlNode* node, String win_name, String file_path, UIWindow** uiwin) 
{
	WindowArgument arg;

	arg.first  = (String)(*node).getAttribute(GUIPNodeAttrib.KEY).value;
	arg.second = (String)(*node).getAttribute(GUIPNodeAttrib.VAL).value;

    WidgetText* label @noinit;

	bool arg_read_warn;

	switch(arg.first)
	{
    	case GUIPWinParm.VISIBLE:
			if(try value = arg.second.to_int()) {
				(value) ? (*uiwin).show() : (*uiwin).hide();
			} else {
				arg_read_warn = true;
			}
    	case GUIPWinParm.BACKGROUND:
			(*uiwin).setBackgroundTexture(arg.second);
    	case GUIPWinParm.MATCOLOR: @todo();
    	case GUIPWinParm.BACKCOLOR: @todo();
    	case GUIPWinParm.BORDERSIZE: @todo();
    	case GUIPWinParm.BORDERCOLOR: @todo();
    	case GUIPWinParm.FORECOLOR: @todo();
    	case GUIPWinParm.MATSCALEX: @todo();
    	case GUIPWinParm.MATSCALEY: @todo();
    	case GUIPWinParm.TEXT:
            int label_count; 
            foreach(it : (*uiwin).childWidgets) {
                if(it.kind == gui::KIND_TEXT) label_count++;
            }
            label = mem::new(WidgetText);
            label.name = string::tformat("label%d", label_count);
	        label.setText(arg.second);
            label.addTo(*uiwin);
    	case GUIPWinParm.TEXTSCALE:
            if(try value = arg.second.to_int()) {
                if(label) label.setFontSize(value);
			} else {
				arg_read_warn = true;
			}
    	case GUIPWinParm.TEXTCOLOR:
            if(label) label.setTextColor(getColor(arg.second));
    	case GUIPWinParm.FONT:
            if(label) label.setFont(game::gpGame.getfont(arg.second));
		default:
			log::warning(FILE, "Malformed pair in window '%s' of guip '%s'", win_name, file_path);
	}

	if(arg_read_warn) {
		log::warning(FILE, "Unnable to convert value \"%s\" of arg \"%s\" of window '%s' of guip '%s'!", arg.second, arg.first, win_name, file_path);
	}
}

fn RLRectangle? getRect(String str, String win_name, String file_path) @inline @local
{
	str.remove_spaces();
    String[] slice = str.tsplit(",");
    if(slice.len == 0) {
        unreachable("invalid rect param for window '%s' in guip '%s'", win_name, file_path);
    }

	float x, y, w, h;
    x = slice[0].to_float()!;
    y = slice[1].to_float()!;
    w = slice[2].to_float()!;
    h = slice[3].to_float()!;

    return {x, y, w, h};
}

<*
    Converts a xml normalized <color>1 1 1 1</color> node
    into a 0 to 255 low dynamic range raylib RLColor.
    @param [in] _value : "xml color value"
    @require _value.len > 0 && _value.len <= 7 && _value.count(" ") == 3
*>
fn RLColor getColor(String _value) @local
{
    return mtr::xmlStrColorToColor(_value);
}
