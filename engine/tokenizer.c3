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

module engine::tokanizer::tok;

// based on a basic C tokanizer, C3 can do it like this or using slices or the splitter object.

// region imports
import libc;
import std::io, std::ascii;
// end_region

fn void advance(CChar** str, int count)  @inline
{
	if(count <= 0) return;
	
	str += count;
}

fn bool isEndOfLine(CChar c)  @inline
{
	return ((c == '\n') || (c == '\r'));
}

fn bool isWhiteSpace(CChar c)  @inline
{
	return ((c == ' ') || (c == '\t') || isEndOfLine(c));
}

<*
    You can convert a CChar c to an integer safely:
    if the char code falls withing the normal ASCII table values.
    
 @require ascii::is_alnum(c) : "Expected a number or symbol"
 @require c >= 0 && c <= 127 : "Expected valid ASCII value from 0 to 127"
*>
fn int charToInt(CChar c)  @inline
{
	return  c - '0';
}

// When parsing a string for tokens, you can skip a separator and or white space, 
// only by testing if the character (token) is inferior to ' ' (space).
// Is like advance but stops at first space character
// NOTE(HM) 
// String is a char[] SLICE ( a struct with a pointer and a len)
// not a array like C, that is just a pointer to the start of a contiguous peace of memory.
fn CChar returnNextToken(String str, int curr_index)  @inline
{
	return *(str.ptr + curr_index + 1);
}

<*
 @param [&in] str : "the string to peak at, passed by pointer"
 @param cur_index : "where the cursor is currently in the string"
 @ensure return != null : "expect a character pointer got a null pointer"
*>
fn CChar* peakAtNextToken(String* str, int cur_index)  @inline
{
	return (CChar*)((*str).ptr + cur_index + 1);
}

<*
* DOC - go back a char
 @param [&in] str : "the string to peak at, passed by pointer"
 @param curr_index : "where we currently are in the string"
 @ensure return != null : "expect a character pointer got a null pointer"
*>
fn CChar* peakAtPreviousToken(String* str, int curr_index)  @inline
{
	return (CChar*)((*str).ptr + curr_index - 1);
}

<*
 @param token : "the character to look for"
 @param [&in] str : "the string to look at"
 @param cur_index : "where we currently are in the string"
*>
fn bool expectToken(CChar token, String* str, int cur_index)  @inline
{
	if (*peakAtNextToken(str, cur_index) == token) {
		return true;
	} else {
		return false;
	}
}

fn int count_spaces(String str)  @inline
{
	int result;
    foreach(c : str) { if(ascii::is_space_m(c)) result++; }
    return result;
}

<* 
    Removes all spaces from a string
    @param [inout] str : "string to remove spaces from"
*>
fn void remove_all_spaces(String* str)  @inline
{
    int spaces_count = count_spaces(*str);
    if(spaces_count <= 0) return;
    
    int new_len      = (str.len - spaces_count) + 1;
	CChar* buffer    = (CChar*)mem::calloc(new_len);
    
    usz i;
    usz j;
    do {
        if ((*str)[j] == ' ') {
            j++;
            continue;
        }
        else {
            buffer[i++] = (*str)[j];
        }
        j++;
    } while (j < str.len);
    
    (*str) = "";
    DString _str = dstring::new_with_capacity(mem, new_len);
	for(int a = 0; a < new_len; a++) {
        _str.append_char(buffer[a]);
    }
    (*str) = _str.str_view().tcopy();
}


<*
    Eats all the spaces starting at current char untill a non space character is found
    @param [&inout] cursor : "the current position in the string, passed by pointer"
*>
fn void eat_spaces_starting_from(CChar** cursor) @inline
{
	while (true)
	{
		if (isWhiteSpace(**cursor)) {
			advance(cursor, 1);
        } else {
			break;
        } 
	}
}
