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

module std::core::string;

import engine::misc;
import engine::logging::log;

// NOTE(HM)
// Valid extensions used by the application anything else 
// should throw a warning.
constdef FileExtension : inline String @constinit
{
	PNG  = ".png",
	JPG  = ".jpg",
	TGA  = ".tga",
	DDS  = ".dds",
	BMP  = ".bmp",
	MP3  = ".mp3",
	VS   = ".vs" ,
	FS   = ".fs" ,
	WAV  = ".wav",
	OGG  = ".ogg",
	FNT  = ".fnt",
	EXE  = ".exe",
    TXT  = ".txt",
	ZIP  = ".zip",
    ZIP7 = ".7zip",
    MPG  = ".mpg", // mpeg videos
    INI  = ".ini",
	BKP  = ".bkp",
	DEF  = ".def"
}

//////////////////////////////////////////////////////////////////////////
// #region String custom extension
/////////////////////////////////////////////////////////////////////////
/*
example on how to use the string splitter

module string;

import std::io;

fn void main() {
    String s = ";string;to;split;";
    Splitter splitter = s.splitter(";");
    while (try split = splitter.next()) {
        io::printf("(%s)", split);
    }
    io::printn("");
    
    output: ()(string)(to)(split)()
}
*/

macro ZString stringTozstring(x) => x.zstr_copy(mem);
macro ZString stringTotempzstring(x) => x.zstr_tcopy();
macro String zstringTostring(x) => x.zstr_view();
macro String zstringTotempstring(x) => string::tformat(x);
macro String numbToStr(n) => string::new_format("%s", n);

macro bool String.is_empty(self) => (self.len == 0) ? true : false;


// NOTE(HM) helper-function that returns true if the character c is a directory separator
//     on the current platform
macro bool isDirSeparator( c )
{
    if ( c == '/' ) {
        return true;
    }
    $switch:
        $case env::WIN32:
            if ( c == '\\' ) {
                return true;
            }
        $case env::AROS:
            if ( c == ':' ) {
                return true;
            }
    $endswitch
    
    return false;
}

fn ZString String.cpy_zpeace(self, int start, int len) @MyInline
{
    int i = self.len;
    if ( i == 0 || len <= 0 || start >= i ) {
        return "";
    }

    if ( start + len >= i ) {
        len = i - start;
    }
    String result = (String)self[start..len]; //string::tformat("%s", self[:(start + len)]);
    return result.zstr_tcopy();
}

fn String String.strip_known_extension(self)
{
    bool known_extension = false;
    String needle;
    foreach(String ext : FileExtension::values) {
        if(self.ends_with(ext)) {
            known_extension = true;
            needle = ext;
            break;
        }
    }
    
    if(known_extension) {
        return self.strip_end(needle);
    } else {
        log::warning(FILE,  "Cannot strip extension %s of string %s is unkown!", needle, self);
        return self; // do nothing
    }
}

fn String String.strip_extension(self)
{
    if(!self.contains(".")) {
		log::warning(FILE, "Trying to remove extension from '%s' but it has none", self);
		return self;
	}
    //assert(self.count(".") == 1);
    if(self.count(".") > 1) {
      log::warning(FILE, "String %s has malformed or more than one extension!.", self);
    }

    if(try idx = self.index_of_char('.')) {
        if (idx == self.len) return self;
        return self.strip_end(self[idx..]);
    } else {
        log::warning(FILE, "Cannot strip extension of string %s failed to get '.' index position.", self);
        return self; // do nothing
    }
}

macro String[] cut_by_newline(str)
{
    $switch:
        $case env::POSIX:
            return str.tsplit("\r\n");
        $case env::WIN32:
            return str.tsplit("\n");
    $endswitch
}

macro String[] cut_by_spaces(str) => str.tsplit(" ");

macro void String.remove_spaces(&self) 
{
    //*self = self.treplace(" ", ""); // remove all spaces
    // trim any white space at start and end leave only the middle if any
    *self = self.trim();
    // //
    // // see if we still have spaces else do nothing
    if(self.has_spaces()) 
    {
        char* buffer = mem::malloc((self.len + 1) * char::size);
		defer mem::free(buffer);

        usz count;
        foreach(ch : self)
		{
        	if(ch != ' ') {
				buffer[count] = ch;
				count += 1;
			}
		}
        *self = ((String)buffer[:count]).tcopy();
    }
}

<*
	Extracts the name of a file including extension
	@ensure return != ""
*>
fn String String.extractFileBaseByCopy(self) 
{

    //back up until a \ or the start
    int pos = self.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(self[ pos - 1 ]) ) {
        pos--;
    }
    return self[pos..];
}

fn void String.extractFileBaseByRef(&self) 
{ // using self you are passing by value use &self to pass by ref

    //back up until a \ or the start
    String copy = *self;
    int pos = copy.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(copy[ pos - 1 ]) ) {
        pos--;
    }

    int start = pos;
    (*self) = string::tformat("%s", copy[start..]);
}

fn String String.extractFileBase(&self) 
{

    //back up until a \ or the start
    String copy = self.tcopy();
    int pos = copy.len - 1;
    while( ( pos > 0 ) && !isDirSeparator(copy[ pos - 1 ]) ) {
        pos--;
    }

    int start = pos;
    return (String)copy[start..];
}


fn int String.count_spaces(&self) @inline 
{
    int count = 0;

    foreach(ch : self) {
        if (ch == ' ') count++;
    }

    return count;
}

fn bool String.has_spaces(&self) @inline 
{
    if(self.count_spaces() > 0) return true;
    
    // else
    return false;
}

fn String String.strip_start(self, String prefix) @inline => self.strip_prefix(prefix);
fn String String.strip_end(self, String suffix) @inline => self.strip_suffix(suffix);
// #endregion String custom extensions