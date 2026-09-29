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

// ****** UNFINISHED *************
//////////////////////////////////
// TODO(HM) Detect if the same key combo is being assign to other actions
// Support arbitrary number of key/btn inputs, right now this is limited to 1 or two!
// NOTE(HM) This doesn't handle mouse wheel detection, is only for keyboard and mouse button keys,
//          mouse wheel data retrievel is done using either of these raylib functions:
//              fn float getMouseWheelMove()
//              fn RLVector2 getMouseWheelMoveV()

module engine::input_devices @if($feature(USE_INPUT_DEVICES));

struct InputDevice
{
	String name;
    ActionKind kind;
}

module engine::input_devices::keyboard @if($feature(USE_INPUT_DEVICES));

import std::io;
import std::collections::list;
import game::main;
import game::files::ini;
import thirdparty::raylib5::rl;
import engine::misc;
import engine::logging::log;

alias Key = CInt;

constdef KeyModifier : inline int
{
    NONE	= 0x00000,
    CTRL	= 0x00001,
    SHIFT	= 0x00002,
    ALT	    = 0x00004,
}

struct KeyPress @packed
{
    Key key;
    CInt unicode;
    KeyModifier modifier;
}
const NULL_KEYPRESS = (KeyPress){};

struct KeyboardDevice
{
    inline InputDevice device;
}

fn void KeyboardDevice.init(&self, String name)
{
    self.name = name;
    self.kind = ActionKind.KEYBOARD;
}

fn void KeyboardDevice.update(&self)
{

}

fn void KeyboardDevice.deinit(&self)
{

}

<*
    return true if pressed else false 
    @param key : "The key to check"
    @require key >= 0
*>
fn bool KeyboardDevice.keyIsDown(&self, Key key) @inline 
{
    return rl::isKeyDown(key);
}

<*
    Can be checked many times to see all key presses
    return key that is currently pressed. rl::KEY_NULL is no key. 
*>
fn KeyPress KeyboardDevice.getKey(&self) @inline 
{
    return (KeyPress) {
        .key = rl::getKeyPressed()
    };
}

<*
    Can be checked many times to see all key presses
    return key that is currently pressed. rl::KEY_NULL is no key.
*>
fn KeyPress KeyboardDevice.getUnicodeKey(&self) @inline 
{
    return (KeyPress) {
        .unicode = rl::getCharPressed(),
    };
}

<*
   return If ANY key is pressed
*>
fn bool KeyboardDevice.isAnykeyPressed(&self) @inline 
{
    return self.getKey().key != rl::KEY_NULL;
}


macro getModifierFromKey(Key key) 
{
    switch (key)
    {
    case rl::KEY_LEFT_SHIFT:
    case rl::KEY_RIGHT_SHIFT:
        return KeyModifier.SHIFT;
    case rl::KEY_LEFT_CONTROL:
    case rl::KEY_RIGHT_CONTROL:
        return KeyModifier.CTRL;
    case rl::KEY_LEFT_ALT:
    case rl::KEY_RIGHT_ALT:
        return KeyModifier.ALT;
    default: unreachable();
    }
}

macro getKeyFromModifier(KeyModifier mod) 
{
    switch (mod)
    {
    case KeyModifier.SHIFT:
        return rl::KEY_LEFT_SHIFT;
    case KeyModifier.CTRL:
        return rl::KEY_LEFT_CONTROL;
    case KeyModifier.ALT:
        return rl::KEY_LEFT_ALT;
    default: unreachable();
    }
}

/*
alias KeyModifierList  = List{KeyModifier};
<*
    todo Implement!
    return The current modifiers.
*>
fn KeyModifierList KeyboardDevice.getModifier(&self) 
{
    KeyModifierList result;
    KeyPress p = self.getKey();
    while(p.key)
    {
        if(isValidModifier(p.key) && self.keyIsDown(p.key))
        {
            result.push(getModifierFromKey(p.key));
        }
        p = self.getKey();
    }

    return result;
}*/

fn int KeyboardDevice.getModifier(&self) 
{
    int mod;
    mod |= (rl::isKeyDown(rl::KEY_RIGHT_CONTROL) || rl::isKeyDown(rl::KEY_LEFT_CONTROL)) ? KeyModifier.CTRL : 0;
    mod |= (rl::isKeyDown(rl::KEY_RIGHT_SHIFT) || rl::isKeyDown(rl::KEY_LEFT_SHIFT)) ? KeyModifier.SHIFT : 0;
    mod |= (rl::isKeyDown(rl::KEY_RIGHT_ALT) || rl::isKeyDown(rl::KEY_LEFT_ALT)) ? KeyModifier.ALT : 0;

    return mod;
}

<*
    return key that has been released
*>
fn KeyPress KeyboardDevice.getReleasedKey(&self) 
{
    KeyPress p = self.getKey();
    if(p.key && rl::isKeyUp(p.key)) {
        return p;
    } 
    return NULL_KEYPRESS;
}

/*
    return If ANY key is released
*/
fn bool KeyboardDevice.keyIsReleased(&self) 
{
    KeyPress p = self.getKey();
    if(p.key && rl::isKeyReleased(p.key)) {
        return true;
    } 
    return false;
}

<*
    return The name of the key as a string. 
    @param key : "The key to change to string."
*>
fn String KeyboardDevice.keyToString(&self, CInt key) 
{
    //return getKeyboardKeyName(key);
    return rl::getKeyName(key).str_view();
}

<*
    return The name of the mod key as a string. 
    @param mod : "The mod key to change to string."
*>
fn String KeyboardDevice.modifierKeyToString(&self, KeyModifier mod) 
{
    return getKeyboardKeyName(getKeyFromModifier(mod));
}

<*
    return enum of the key.
    @param [in] key_name : "Name of the key"
    @require key_name.len > 0
*>
fn CInt KeyboardDevice.stringToKey(&self, String key_name) 
{
    return getKeyCodeFromStr(key_name);
}

module engine::input_devices::mouse @if($feature(USE_INPUT_DEVICES));

struct MouseDevice 
{
    inline InputDevice device;
}