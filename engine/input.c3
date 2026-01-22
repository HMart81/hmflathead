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

// TODO(HM) Detect if the same key combo is being assign to many actions
// NOTE(HM) This doesn't handle mouse wheel detection, is only for keyboard and mouse button keys,
//          mouse wheel data retrievel is done using either raylib functions:
//              fn float getMouseWheelMove()
//              fn RLVector2 getMouseWheelMoveV()

module engine::input;

// region C3 modules
import std::io;
//import std::core::mem; // for malloc
//import std::math;
import std::collections::list;
import game::main;
//import game::actors::ent;
import thirdparty::raylib5::rl;
//import raygui;
import engine::misc;
import engine::logging::log;
//import game::assets_api::astmng; // asset manager
// end_region

// region defines
//alias assetManager = astmng::assetManager @private;
//alias WidgetQueue  = List{Widget*};
//alias DesktopList  = List{Action*};
alias ActionQueue    = List{Action*};
alias ActionCallBack = fn void(args...);
// end_region

// region constants
const MAX_ACTION_COUNT @local = 1024;

enum ActionKind {
    UNKNOWN,
    KEYBOARD,
    MOUSE,
    GAMEPAD,
    MOBILE
}

macro String actionKindToString(ActionKind k) {
    switch (k)
    {
        case UNKNOWN : return "UNKNOWN";
        case KEYBOARD: return "KEYBOARD";
        case MOUSE   : return "MOUSE";
        case GAMEPAD : return "GAMEPAD";
        case MOBILE  : return "MOBILE";
        default      : return "UNKNOWN";
    }
}
// end_region

interface ActionInterface 
{
	//Update special logic for the action. Normally empty
	fn void updateLogic(float timeStep) @optional;
	//Filled in by the class that inherits from Action.
	//return true if the action is being triggered
	fn bool fnIsTriggered() @optional;
	//return A value from the input, ie the relative mouse x position.
	fn float getValue() @optional;
	//The name of the key, ie for keyboard the name of the key is returned.
	fn String getInputName() @optional;
	//The name of the input kind. ie KEYBOARD, MOUSE, GAMEPAD, MOBILE
	fn String getInputKind() @optional;
}

struct Action (ActionInterface)
{
    typeid type;
    String name;

    ActionKind kind;
    
    struct keyboard {
        RLKeyboardKey key1;
        RLKeyboardKey key2;  // for alternative keys like alt, shift, ctrl, etc...
    }
    struct mouse {
        RLMouseButton btn;
    }
    struct gamepad {
        RLGamepadButton btn;
        /*
        LEFT_X,           // Gamepad left stick X axis
        LEFT_Y,           // Gamepad left stick Y axis
        RIGHT_X,          // Gamepad right stick X axis
        RIGHT_Y,          // Gamepad right stick Y axis
        LEFT_TRIGGER,     // Gamepad back trigger left, pressure level: [1..-1]
        RIGHT_TRIGGER     // Gamepad back trigger right, pressure level: [1..-1]
        */
        RLGamepadAxis   axis;
    }
    //
    RLGesture gesture;  // for mobile phones
    
    // pointer to the function this action should trigger
    ActionCallBack callback;

	bool becameTriggered;
	bool isTriggered;
    //
	bool triggerDown;
	double timeCount;
}

fn bool Action.fnIsTriggered(&self) @dynamic @nodiscard
{
    switch (self.kind) 
    {
        case KEYBOARD:
            bool hasExtKey = self.keyboard.key2 != rl::KEY_NULL;
            if (hasExtKey) 
            {
				return (rl::isKeyPressed(self.keyboard.key1) && rl::isKeyDown(self.keyboard.key2)) ? true : false; 
            }
            else if(rl::isKeyDown(self.keyboard.key1))
            {
                return true;
            }
        case MOUSE:
            if (rl::isMouseButtonDown(self.mouse.btn))
            {
                bool hasExtKey = self.keyboard.key2 != rl::KEY_NULL;
                if(hasExtKey) {
                   return rl::isKeyDown(self.keyboard.key2);
                }
                
                return true;
            }
        case GAMEPAD:
        case MOBILE:
        default:
            return false;
    }
    
    return false;
}

/*
 * returns true if the action was just triggered, else false
 */
fn bool Action.wasTriggered(&self)
{
    bool previously_triggered    = self.becameTriggered;
    bool not_currently_triggered = !self.fnIsTriggered();
    if(previously_triggered && not_currently_triggered) {
        self.becameTriggered = false;
        return true;
    }

    return false;
}

/*
 * return true if the action just became triggered, else false
 */
fn bool Action.fnBecameTriggered(&self)
{
    if(!self.isTriggered && self.fnIsTriggered()) {
        self.isTriggered = true;
        return true;
    }

    return false;
}

/*
* return true if the action just was double triggered (double clicked), else false
*/
fn bool Action.fnDoubleTriggered(&self, float limit)
{
    if(!self.triggerDown && self.fnIsTriggered())
    {
        self.triggerDown = true;

        if(self.timeCount < 0 || self.timeCount > limit) {
            self.timeCount = 0;
            return false;
        } else {
            self.timeCount   = 0;
            self.isTriggered = true;
            return true;
        }
    }

    return false;
}

/*
* Update the Action, called by action manager
*/
fn void Action.update(&self, float timeStep)
{
    self.updateLogic(timeStep);

    if(!self.fnIsTriggered()) {
        self.isTriggered = false;
        self.triggerDown = false;

        if(self.timeCount >= 0) self.timeCount += timeStep;
    } else {
        self.becameTriggered = true;
    }

    self.handleInput();
}

fn void Action.handleInput(&self) 
{
    if (self.isTriggered /*self.wasTriggered()*/) {
        if(self.callback != null) self.callback();
    }

    /*
    if (input::gpManager.getActionByName("quit").fnDoubleTriggered(0.250f)) {
        log::info(Where.CONSOLE, "Quit Action DOUBLE triggered!!!!!!");
    }

    if (input::gpManager.getActionByName("quit").wasTriggered()) {
        log::info(Where.CONSOLE, "Quit Action WAS triggered!!!!!!");
    }
    */
}

	//-----------------------------------------------------------------------

fn void Action.updateLogic(&self, float timeStep) @dynamic
{
 //
}

fn String Action.getName(&self) => self.name;

<*
 @param name : "the name of the action to create"
 @param key1 : "the main key for the action"
 @param key2 : "an optional secondary key for the action, like alt, shift, ctrl, etc..."
 @param func : "an optional callback function to call when the action is triggered"
 @require name != ""
 @require key1 != rl::KEY_NULL && key2 != key1
*>
fn void makeKeyboardAction(String name, RLKeyboardKey key1, RLKeyboardKey key2 = rl::KEY_NULL, ActionCallBack func = null)  @inline
{
    if(name == "" || key1 == rl::KEY_NULL) {
        log::warning(Where.CONSOLE, "Cannot create keyboard action with empty name or KEY_NULL key.");
        return;
    }

    if(local_manager.actions.len() >= MAX_ACTION_COUNT) {
        log::warning(Where.CONSOLE, "Cannot create more actions, reached the max limit of %d actions.", MAX_ACTION_COUNT);
        return;
    }

    foreach(act : local_manager.actions)
	{
		if(act.name == name) {
        	log::warning(CONSOLE, "Cannot create another action named \"%s\", is already taken.", name);
       		return;
    	}

        if(act.kind == ActionKind.KEYBOARD && act.keyboard.key1 == key1 && act.keyboard.key2 == key2) {
            log::warning(CONSOLE, "Cannot give key1 \"%s\" and key2 \"%s\" to action \"%s\", they are already taken by action \"%s\".", getKeyboardKeyName(key1), getKeyboardKeyName(key2), name, act.name);
            return;
        }
    }

    Action* action       = mem::new(Action);
    action.type          = Action.typeid;
    action.name          = name;
    action.kind          = ActionKind.KEYBOARD;
    action.callback      = func;
    action.keyboard.key1 = key1;
    action.keyboard.key2 = key2;
    action.timeCount     = -1.0;
    local_manager.actions.push(action);
}

fn void makeMouseAction(String name, RLMouseButton btn, RLKeyboardKey key = rl::KEY_NULL, ActionCallBack func = null)  @inline
{
    Action* action       = mem::new(Action);
    action.type          = Action.typeid;
    action.name          = name;
    action.kind          = ActionKind.MOUSE;
    action.mouse.btn     = btn;
    action.keyboard.key2 = key;
    action.callback      = func;
    action.timeCount     = -1.0;
    local_manager.actions.push(action);
}

fn void makeGamepadAction(String name, RLGamepadButton btn, RLGamepadAxis axis, ActionCallBack func = null)  @inline
{
    Action* action      = mem::new(Action);
    action.type         = Action.typeid;
    action.name         = name;
    action.kind         = ActionKind.GAMEPAD;
    action.gamepad.btn  = btn;
    action.gamepad.axis = axis;
    action.callback     = func;
    action.timeCount     = -1.0;
    local_manager.actions.push(action);
}

struct Input_Action_Entry 
{
	String name;
	ActionKind kind;
	RLKeyboardKey key1;
	RLKeyboardKey key2;
	RLMouseButton btn;
	RLGamepadButton gbtn;
	RLGamepadAxis axis;
	ActionCallBack func;
}
alias MakeInputActionFunc = fn void(Input_Action_Entry* entry);
fn void makeInputActionImp(Input_Action_Entry entry, MakeInputActionFunc func) @inline
{
	if(func != null) {
		func(&entry);
	}
}
macro void @makeAction(Input_Action_Entry entry) 
{
	makeInputActionImp(entry, fn void(Input_Action_Entry* e) {
		switch (e.kind)
		{
			case KEYBOARD:
				makeKeyboardAction(e.name, e.key1, e.key2, e.func);
			case MOUSE:
				makeMouseAction(e.name, e.btn, e.key2, e.func);
			case GAMEPAD:
				makeGamepadAction(e.name, e.gbtn, e.axis, e.func);
			default:
				log::warning(Where.CONSOLE, "Cannot create action \"%s\", unknown kind.", e.name);
		}
	});
}

fn RLKeyboardKey getKeyCodeFromStr(String name) @inline
{
    // NOTE(HM) this is used to get the key enum value from a string
    // like "KEY_A" or "KEY_LEFT" etc.
    //return rl::getKeyPressedFromName(stringTotempzstring(name));
    switch(name)
    {
        case "KEY_NULL":            return rl::KEY_NULL;
        case "KEY_APOSTROPHE":      return rl::KEY_APOSTROPHE;
        case "KEY_COMMA":           return rl::KEY_COMMA;
        case "KEY_MINUS":           return rl::KEY_MINUS;
        case "KEY_PERIOD":          return rl::KEY_PERIOD;
        case "KEY_SLASH":           return rl::KEY_SLASH;
        case "KEY_ZERO":            return rl::KEY_ZERO;
        case "KEY_ONE":             return rl::KEY_ONE;
        case "KEY_TWO":             return rl::KEY_TWO;
        case "KEY_THREE":           return rl::KEY_THREE;
        case "KEY_FOUR":            return rl::KEY_FOUR;
        case "KEY_FIVE":            return rl::KEY_FIVE;
        case "KEY_SIX":             return rl::KEY_SIX;
        case "KEY_SEVEN":           return rl::KEY_SEVEN;
        case "KEY_EIGHT":           return rl::KEY_EIGHT;
        case "KEY_NINE":            return rl::KEY_NINE;
        case "KEY_SEMICOLON":       return rl::KEY_SEMICOLON;
        case "KEY_EQUAL":           return rl::KEY_EQUAL;
        case "KEY_A":               return rl::KEY_A;
        case "KEY_B":               return rl::KEY_B;
        case "KEY_C":               return rl::KEY_C;
        case "KEY_D":               return rl::KEY_D;
        case "KEY_E":               return rl::KEY_E;
        case "KEY_F":               return rl::KEY_F;
        case "KEY_G":               return rl::KEY_G;
        case "KEY_H":               return rl::KEY_H;
        case "KEY_I":               return rl::KEY_I;
        case "KEY_J":               return rl::KEY_J;
        case "KEY_K":               return rl::KEY_K;
        case "KEY_L":               return rl::KEY_L;
        case "KEY_M":               return rl::KEY_M;
        case "KEY_N":               return rl::KEY_N;
        case "KEY_O":               return rl::KEY_O;
        case "KEY_P":               return rl::KEY_P;
        case "KEY_Q":               return rl::KEY_Q;
        case "KEY_R":               return rl::KEY_R;
        case "KEY_S":               return rl::KEY_S;
        case "KEY_T":               return rl::KEY_T;
        case "KEY_U":               return rl::KEY_U;
        case "KEY_V":               return rl::KEY_V;
        case "KEY_W":               return rl::KEY_W;
        case "KEY_X":               return rl::KEY_X;
        case "KEY_Y":               return rl::KEY_Y;
        case "KEY_Z":               return rl::KEY_Z;
        case "KEY_LEFT_BRACKET":    return rl::KEY_LEFT_BRACKET;
        case "KEY_BACKSLASH":       return rl::KEY_BACKSLASH;
        case "KEY_RIGHT_BRACKET":   return rl::KEY_RIGHT_BRACKET;
        case "KEY_GRAVE":           return rl::KEY_GRAVE;
        case "KEY_SPACE":           return rl::KEY_SPACE;
        case "KEY_ESCAPE":          return rl::KEY_ESCAPE;
        case "KEY_ENTER":           return rl::KEY_ENTER;
        case "KEY_TAB":             return rl::KEY_TAB;
        case "KEY_BACKSPACE":       return rl::KEY_BACKSPACE;
        case "KEY_INSERT":          return rl::KEY_INSERT;
        case "KEY_DELETE":          return rl::KEY_DELETE;
        case "KEY_RIGHT":           return rl::KEY_RIGHT;
        case "KEY_LEFT":            return rl::KEY_LEFT;
        case "KEY_DOWN":            return rl::KEY_DOWN;
        case "KEY_UP":              return rl::KEY_UP;
        case "KEY_PAGE_UP":         return rl::KEY_PAGE_UP;
        case "KEY_PAGE_DOWN":       return rl::KEY_PAGE_DOWN;
        case "KEY_HOME":            return rl::KEY_HOME;
        case "KEY_END":             return rl::KEY_END;
        case "KEY_CAPS_LOCK":       return rl::KEY_CAPS_LOCK;
        case "KEY_SCROLL_LOCK":     return rl::KEY_SCROLL_LOCK;
        case "KEY_NUM_LOCK":        return rl::KEY_NUM_LOCK;
        case "KEY_PRINT_SCREEN":    return rl::KEY_PRINT_SCREEN;
        case "KEY_PAUSE":           return rl::KEY_PAUSE;
        case "KEY_F1":              return rl::KEY_F1;
        case "KEY_F2":              return rl::KEY_F2;
        case "KEY_F3":              return rl::KEY_F3;
        case "KEY_F4":              return rl::KEY_F4;
        case "KEY_F5":              return rl::KEY_F5;
        case "KEY_F6":              return rl::KEY_F6;
        case "KEY_F7":              return rl::KEY_F7;
        case "KEY_F8":              return rl::KEY_F8;
        case "KEY_F9":              return rl::KEY_F9;
        case "KEY_F10":             return rl::KEY_F10;
        case "KEY_F11":             return rl::KEY_F11;
        case "KEY_F12":             return rl::KEY_F12;
        case "KEY_LEFT_SHIFT":      return rl::KEY_LEFT_SHIFT;
        case "KEY_LEFT_CONTROL":    return rl::KEY_LEFT_CONTROL;
        case "KEY_LEFT_ALT":        return rl::KEY_LEFT_ALT;
        case "KEY_LEFT_SUPER":      return rl::KEY_LEFT_SUPER;
        case "KEY_RIGHT_SHIFT":     return rl::KEY_RIGHT_SHIFT;
        case "KEY_RIGHT_CONTROL":   return rl::KEY_RIGHT_CONTROL;
        case "KEY_RIGHT_ALT":       return rl::KEY_RIGHT_ALT;
        case "KEY_RIGHT_SUPER":     return rl::KEY_RIGHT_SUPER;
        case "KEY_KB_MENU":         return rl::KEY_KB_MENU;
        case "KEY_KP_0":            return rl::KEY_KP_0;
        case "KEY_KP_1":            return rl::KEY_KP_1;
        case "KEY_KP_2":            return rl::KEY_KP_2;
        case "KEY_KP_3":            return rl::KEY_KP_3;
        case "KEY_KP_4":            return rl::KEY_KP_4;
        case "KEY_KP_5":            return rl::KEY_KP_5;
        case "KEY_KP_6":            return rl::KEY_KP_6;
        case "KEY_KP_7":            return rl::KEY_KP_7;
        case "KEY_KP_8":            return rl::KEY_KP_8;
        case "KEY_KP_9":            return rl::KEY_KP_9;
        case "KEY_KP_DECIMAL":      return rl::KEY_KP_DECIMAL;
        case "KEY_KP_DIVIDE":       return rl::KEY_KP_DIVIDE;
        case "KEY_KP_MULTIPLY":     return rl::KEY_KP_MULTIPLY;
        case "KEY_KP_SUBTRACT":     return rl::KEY_KP_SUBTRACT;
        case "KEY_KP_ADD":          return rl::KEY_KP_ADD;
        case "KEY_KP_ENTER":        return rl::KEY_KP_ENTER;
        case "KEY_KP_EQUAL":        return rl::KEY_KP_EQUAL;
        case "KEY_BACK":            return rl::KEY_BACK;
        case "KEY_MENU":            return rl::KEY_MENU;
        case "KEY_VOLUME_UP":       return rl::KEY_VOLUME_UP;
        case "KEY_VOLUME_DOWN":     return rl::KEY_VOLUME_DOWN;
        default:
            log::error(FILE, "Unknown key name: %s", name);
            return rl::KEY_NULL; // unknown key
    }
}

<*
 @param name : "the name of the action to retrieve"
 @require name != ""
*>
fn Action* getAction(String name) @inline 
{
    return local_manager.getActionByName(name);
}

fn void removeAction(String name) @inline 
{
    if(name == "") return;
    
    foreach(act : local_manager.actions) {
        if(act.name == name) {
            local_manager.remove(act);
            return;
        }
    }
}

fn String getKeyboardKeyName(RLKeyboardKey k) 
{
    switch (k)
    {
        case rl::KEY_NULL         : return "KEY_NULL";
        case rl::KEY_APOSTROPHE   : return "KEY_APOSTROPHE";
        case rl::KEY_COMMA        : return "KEY_COMMA";
        case rl::KEY_MINUS        : return "KEY_MINUS";
        case rl::KEY_PERIOD       : return "KEY_PERIOD";
        case rl::KEY_SLASH        : return "KEY_SLASH";
        case rl::KEY_ZERO         : return "KEY_ZERO";
        case rl::KEY_ONE          : return "KEY_ONE";
        case rl::KEY_TWO          : return "KEY_TWO";
        case rl::KEY_THREE        : return "KEY_THREE";
        case rl::KEY_FOUR         : return "KEY_FOUR";
        case rl::KEY_FIVE         : return "KEY_FIVE";
        case rl::KEY_SIX          : return "KEY_SIX";
        case rl::KEY_SEVEN        : return "KEY_SEVEN";
        case rl::KEY_EIGHT        : return "KEY_EIGHT";
        case rl::KEY_NINE         : return "KEY_NINE";
        case rl::KEY_SEMICOLON    : return "KEY_SEMICOLON";
        case rl::KEY_EQUAL        : return "KEY_EQUAL";
        case rl::KEY_A            : return "KEY_A";
        case rl::KEY_B            : return "KEY_B";
        case rl::KEY_C            : return "KEY_C";
        case rl::KEY_D            : return "KEY_D";
        case rl::KEY_E            : return "KEY_E";
        case rl::KEY_F            : return "KEY_F";
        case rl::KEY_G            : return "KEY_G";
        case rl::KEY_H            : return "KEY_H";
        case rl::KEY_I            : return "KEY_I";
        case rl::KEY_J            : return "KEY_J";
        case rl::KEY_K            : return "KEY_K";
        case rl::KEY_L            : return "KEY_L";
        case rl::KEY_M            : return "KEY_M";
        case rl::KEY_N            : return "KEY_N";
        case rl::KEY_O            : return "KEY_O";
        case rl::KEY_P            : return "KEY_P";
        case rl::KEY_Q            : return "KEY_Q";
        case rl::KEY_R            : return "KEY_R";
        case rl::KEY_S            : return "KEY_S";
        case rl::KEY_T            : return "KEY_T";
        case rl::KEY_U            : return "KEY_U";
        case rl::KEY_V            : return "KEY_V";
        case rl::KEY_W            : return "KEY_W";
        case rl::KEY_X            : return "KEY_X";
        case rl::KEY_Y            : return "KEY_Y";
        case rl::KEY_Z            : return "KEY_Z";
        case rl::KEY_LEFT_BRACKET : return "KEY_LEFT_BRACKET";
        case rl::KEY_BACKSLASH    : return "KEY_BACKSLASH";
        case rl::KEY_RIGHT_BRACKET: return "KEY_RIGHT_BRACKT";
        case rl::KEY_GRAVE        : return "KEY_GRAVE";
        case rl::KEY_SPACE        : return "KEY_SPACE";
        case rl::KEY_ESCAPE       : return "KEY_ESCAPE";
        case rl::KEY_ENTER        : return "KEY_ENTER";
        case rl::KEY_TAB          : return "KEY_TAB";
        case rl::KEY_BACKSPACE    : return "KEY_BACKSPACE";
        case rl::KEY_INSERT       : return "KEY_INSERT";
        case rl::KEY_DELETE       : return "KEY_DELETE";
        case rl::KEY_RIGHT        : return "KEY_RIGHT";
        case rl::KEY_LEFT         : return "KEY_LEFT";
        case rl::KEY_DOWN         : return "KEY_DOWN";
        case rl::KEY_UP           : return "KEY_UP";
        case rl::KEY_PAGE_UP      : return "KEY_PAGE_UP";
        case rl::KEY_PAGE_DOWN    : return "KEY_PAGE_DOWN";
        case rl::KEY_HOME         : return "KEY_HOME";
        case rl::KEY_END          : return "KEY_END";
        case rl::KEY_CAPS_LOCK    : return "KEY_CAPS_LOCK";
        case rl::KEY_SCROLL_LOCK  : return "KEY_SCROLL_LOCK";
        case rl::KEY_NUM_LOCK     : return "KEY_NUM_LOCK";
        case rl::KEY_PRINT_SCREEN : return "KEY_PRINT_SCREEN";
        case rl::KEY_PAUSE        : return "KEY_PAUSE";
        case rl::KEY_F1           : return "KEY_F1";
        case rl::KEY_F2           : return "KEY_F2";
        case rl::KEY_F3           : return "KEY_F3";
        case rl::KEY_F4           : return "KEY_F4";
        case rl::KEY_F5           : return "KEY_F5";
        case rl::KEY_F6           : return "KEY_F6";
        case rl::KEY_F7           : return "KEY_F7";
        case rl::KEY_F8           : return "KEY_F8";
        case rl::KEY_F9           : return "KEY_F9";
        case rl::KEY_F10          : return "KEY_F10";
        case rl::KEY_F11          : return "KEY_F11";
        case rl::KEY_F12          : return "KEY_F12";
        case rl::KEY_LEFT_SHIFT   : return "KEY_LEFT_SHIFT";
        case rl::KEY_LEFT_CONTROL : return "KEY_LEFT_CONTROL";
        case rl::KEY_LEFT_ALT     : return "KEY_LEFT_ALT";
        case rl::KEY_LEFT_SUPER   : return "KEY_LEFT_SUPER";
        case rl::KEY_RIGHT_SHIFT  : return "KEY_RIGHT_SHIFT";
        case rl::KEY_RIGHT_CONTROL: return "KEY_RIGHT_CONTRL";
        case rl::KEY_RIGHT_ALT    : return "KEY_RIGHT_ALT";
        case rl::KEY_RIGHT_SUPER  : return "KEY_RIGHT_SUPER";
        case rl::KEY_KB_MENU      : return "KEY_KB_MENU";
        case rl::KEY_KP_0         : return "KEY_KP_0";
        case rl::KEY_KP_1         : return "KEY_KP_1";
        case rl::KEY_KP_2         : return "KEY_KP_2";
        case rl::KEY_KP_3         : return "KEY_KP_3";
        case rl::KEY_KP_4         : return "KEY_KP_4";
        case rl::KEY_KP_5         : return "KEY_KP_5";
        case rl::KEY_KP_6         : return "KEY_KP_6";
        case rl::KEY_KP_7         : return "KEY_KP_7";
        case rl::KEY_KP_8         : return "KEY_KP_8";
        case rl::KEY_KP_9         : return "KEY_KP_9";
        case rl::KEY_KP_DECIMAL   : return "KEY_KP_DECIMAL";
        case rl::KEY_KP_DIVIDE    : return "KEY_KP_DIVIDE";
        case rl::KEY_KP_MULTIPLY  : return "KEY_KP_MULTIPLY";
        case rl::KEY_KP_SUBTRACT  : return "KEY_KP_SUBTRACT";
        case rl::KEY_KP_ADD       : return "KEY_KP_ADD";
        case rl::KEY_KP_ENTER     : return "KEY_KP_ENTER";
        case rl::KEY_KP_EQUAL     : return "KEY_KP_EQUAL";
        default: return "UNKNOWN";
    }
}

fn void listActions() @inline 
{
    local_manager.listActions();
}

fn String getMouseBtnName(RLMouseButton btn) @inline @local 
{
    switch (btn)
    {
        case rl::RLMouseButton.LEFT  : return "MOUSE_BUTTON_LEFT";
        case rl::RLMouseButton.RIGHT : return "MOUSE_BUTTON_RIGHT";
        case rl::RLMouseButton.MIDDLE: return "MOUSE_BUTTON_MIDDLE";
        case rl::RLMouseButton.SIDE  : return "MOUSE_BUTTON_SIDE";
        case rl::RLMouseButton.EXTRA : return "MOUSE_BUTTON_EXTRA";
        case rl::RLMouseButton.FORWARD: return "MOUSE_BUTTON_FORWARD";
        case rl::RLMouseButton.BACK  : return "MOUSE_BUTTON_BACK";
        default: return "UNKNOWN";
    }
}

<*
    @param [&in] action : "the action to retrieve the main button name from"
*>
fn String getMainBtnNameFrom(Action* action) @inline @local 
{
    switch (action.kind)
    {
        case KEYBOARD: return getKeyboardKeyName(action.keyboard.key1);
        case MOUSE   : return getMouseBtnName(action.mouse.btn);
        case GAMEPAD : return "GAMEPAD BTN"; // TODO(HM) implement this
        case MOBILE  : return "MOBILE GESTURE"; // TODO(HM) implement this
        default      : return "UNKNOWN";
    }
}

fn void printKeyActions() @inline
{
    io::printfn("\n============== Input Actions =====================");
    usz count = local_manager.actions.len();
    if(count == 0) {
        io::printfn("No input actions to print found.");
    } else {
        foreach(act: local_manager.actions) {
            io::printfn("\t-> %s Action: \"%s\" - Key1: %s - Key2: %s", actionKindToString(act.kind), act.name, getMainBtnNameFrom(act), getKeyboardKeyName(act.keyboard.key2));
        }
        io::printfn("Total actions: %d", count);
    }
    io::printfn("============== Input Actions END =====================\n");
}


struct ActionManager {
    ActionQueue actions;
}

ActionManager local_manager @local;
ActionManager* gpManager = &local_manager;

<*
 @param [&in] action : "the action to register"
*>
fn void ActionManager.register(&self, Action* action) @inline 
{
    foreach(act : self.actions) 
    {
        if(act.name == action.name) {
            log::warning(CONSOLE, "Cannot register \"%s\" because action with that name already exists.", action.name);
			$if $feature(_DEBUG):
				unreachable();
            $else
				return;
			$endif
        }
    }
    
    self.actions.push(action);
}

<*
	@param name : "the name of the action to retrieve"
	@require name != ""
*>
fn Action* ActionManager.getActionByName(&self, String name) @inline @local @nodiscard
{
    if(name == "") return null;
    
    foreach(action : self.actions) {
        if(action.name == name) {
            return action;
        }
    }
    
    return null;
}


fn ActionQueue ActionManager.getActionsByKind(&self, ActionKind kind) @inline {
   assert(kind != UNKNOWN);
    
   ActionQueue actions;
    
    foreach(action : self.actions) {
        if(action.kind == kind) {
            actions.push(action);
        }
    }
    
    return actions;
}

fn void ActionManager.unregister(&self, Action* action) @inline @local {
    if(action == null) return;
    
    foreach(act : self.actions) {
        if(act.name == action.name) {
            self.actions.remove_item(act);
            act = null;
            return;
        }
    }
}

fn void ActionManager.remove(&self, Action* action) @inline {
    self.unregister(action);
}

fn void ActionManager.update(&self) 
{
    if(self.actions.len())
    {
        foreach(act: self.actions) {
            act.update(main::gpGame.dt);
        }
    }
    
    // todo detect actions with the same keys
}

fn void ActionManager.free(&self) 
{
    if(self.actions.len()) {
        foreach(action: self.actions) {
            if(action.callback) action.callback = null;
        }
    }
    
    self.actions.free();
}

fn void ActionManager.listActions(&self) @local @inline
{
    if(self.actions.len()) {
        log::info(FILE, "[ KEY ACTIONS ]");
        foreach(action: self.actions) {
           log::info(FILE, "\t-> \"%s\" : {%s, %s},", action.name, getKeyboardKeyName(action.keyboard.key1), getKeyboardKeyName(action.keyboard.key2));
        }
        log::info(FILE, "[ END ACTIONS ]]");
    }
}

// TODO(HM) Move this to the cmds module
// region input cmds
fn void quitGame() {
    main::gpGame.should_quit = true;
}
// endregion


