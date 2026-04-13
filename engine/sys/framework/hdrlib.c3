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

//////////////////// Localization/Languages stuff /////////////////

module engine::sys::framework::hdrlib;

import std::io;
import game::main;
import thirdparty::raylib5::rl;
import engine::filesystem::fs;
import std::collections;
import thirdparty::library::xml;
import engine::logging::log;

// in HDR10 only 10bits of color matter the rest are ignored
// so the extra 6bits will be ignored and always zero :(
// unless someone in the future has a 16bits HDR monitor and wants to 
// use larger values...
// NOTE(HM) you can have negative colors in HDR
bitstruct HMColor : long
{
	// HDR 16-bit color (because you can't have 10bits ones...)
    short r : 0..15;  // red value
    short g : 16..31; // green value
    short b : 32..47; // blue value
    short a : 48..63; // alpha will always be 0...255
}

macro bool HMColor.eql(&self, HMColor other) @operator(==)
{
    return ( self.r == other.r &&
             self.g == other.g &&
             self.b == other.b &&
             self.a == other.a );
}

macro bool HMColor.neql(&self, HMColor other) @operator(!=)
{
    return ( self.r != other.r ||
             self.g != other.g ||
             self.b != other.b ||
             self.a != other.a );
}

/*macro @hexToHDRColor($hexValue)
{
  var rgbColor = HDRColors.WHITE;
  rgbColor.r = (short)(($hexValue >> 16) & 0x400); // Extract the RR byte
  rgbColor.g = (short)(($hexValue >> 8) & 0x400);  // Extract the GG byte
  rgbColor.b = (short)(($hexValue) & 0x400);       // Extract the BB byte
  return rgbColor;
}*/

enum HDRColors :  (inline HMColor clr)
{
	TRANSPARENT  {{ 0, 0, 0, 0 }},
	// pure colors
	BLACK        {{ 0, 0, 0, 1024 }},         // Black
	GRAY         {{ 512, 512, 512, 1024 }},   // Gray
	WHITE        {{ 1024, 1024, 1024, 1024 }},   // White
	RED          {{ 1024, 0, 0, 1024 }},     // Red
	GREEN        {{ 0, 1024, 0, 1024 }},      // Green
	BLUE         {{ 0, 0, 1024, 1024 }},     // Blue
	///
	LIGHTGRAY    {{ 400, 400, 400, 1024 }},   // Light Gray
	DARKGRAY     {{ 130, 130, 130, 1024 }},   // Dark Gray
	YELLOW       {{ 253, 249, 0, 1024 }},     // Yellow
	GOLD         {{ 1024, 203, 0, 1024 }},     // Gold
	ORANGE       {{ 1024, 161, 0, 1024 }},     // Orange
	PINK         {{ 1024, 109, 194, 1024 }},   // Pink
	MAROON       {{ 190, 33, 55, 1024 }},     // Maroon
	LIME         {{ 0, 158, 47, 1024 }},      // Lime
	DARKGREEN    {{ 0, 117, 44, 1024 }},      // Dark Green
	SKYBLUE      {{ 102, 191, 1024, 1024 }},   // Sky Blue
	DARKBLUE     {{ 0, 82, 172, 1024 }},      // Dark Blue
	PURPLE       {{ 200, 122, 1024, 1024 }},   // Purple
	VIOLET       {{ 135, 60, 190, 1024 }},    // Violet
	DARKPURPLE   {{ 112, 31, 126, 1024 }},    // Dark Purple
	BEIGE        {{ 211, 176, 131, 1024 }},   // Beige
	BROWN        {{ 127, 106, 79, 1024 }},    // Brown
	DARKBROWN    {{ 76, 63, 47, 1024 }},      // Dark Brown
	MAGENTA      {{ 1024, 0, 1024, 1024 }},     // Magenta
}