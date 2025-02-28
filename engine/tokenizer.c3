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

// region imports
import libc;
import std::io, std::ascii;
// end_region

fn void advance(CChar** str, int count)  @inline
{
	if(count <= 0) return;
	
	str += count;
}

fn bool isEndofLine(CChar c)  @inline
{
	bool result = ((c == '\n') || (c == '\r'));
	return result;
}

fn bool isWhiteSpace(CChar c)  @inline
{
	bool result = ((c == ' ') || (c == '\t') || isEndofLine(c));
	return result;
}

// You can convert a CChar c to an integer as follow:
// if the char falls withing the normal ASCII table values
fn int charToInt(CChar c)  @inline
{
	return  c - '0';
}

// When parsing a string for tokens, you can skip a separator and or white space, 
// only by testing if the character (token) is inferior to ' ' (space).
// Is like advance but stops at first space character
// NOTE(HM) 
// String is a char[] that is a SLICE struct (a pointer and a len)
// not a C array that is just a pointer.
fn CChar returnNextToken(String str, int cur_index)  @inline
{
	return *(str.ptr + cur_index + 1);
}

<*
* @param in str "the string to peak at, passed by pointer"
* @param cur_index "where we currently are in the string"
* @require str != null
* @ensure return != null
*>
fn CChar* peakAtNextToken(String* str, int cur_index)  @inline
{
	return (CChar*)((*str).ptr + cur_index + 1);
}

<*
* DOC - go back a char
* @param in str "the string to peak at, passed by pointer"
* @param cur_index "where we currently are in the string"
* @require str != null
* @ensure return != null
*>
fn CChar* peakAtPreviousToken(String* str, int cur_index)  @inline
{
	return (CChar*)((*str).ptr + cur_index - 1);
}

<*
* @param token "the character to look for"
* @param in str "the string to look at"
* @param cur_index "where we currently are in the string"
* @require str != null
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
    foreach(c : str) { if(c == ' ') result++; }
    return result;
}

<* 
* Removes all spaces from a string
* @param str "string to remove spaces from"
*>
fn void remove_all_spaces(String* str)  @inline
{
    int spaces_count = count_spaces(*str);
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
    DString _str = dstring::new_with_capacity(new_len);
	for(int a = 0; a < new_len; a++) {
        _str.append_char(buffer[a]);
    }
    (*str) = _str.str_view();
}

/*

/// <summary>
/// Eats all the spaces starting at index untill a non space character is found
/// </summary>
// fn void eat_spaces_starting_from(uint index, String* str) @inline
// {
	// while (str.len())
	// {
		// if (isWhiteSpace(str[index])) 
			// advance(str, 1); 
		// else 
			// break;
		
	// }
// }

// Eats all the spaces at the start of a string if any
fn String eat_starting_spaces(String* str) @inline
{
	return *str = str.strip("\t\n\r ");
}

/// <summary>
/// Eats all the spaces at the end of a string if any
/// @Untested
fn void eat_spaces_at_end(String* str) @inline
{
	str.strip_end("\t\n\r ");
}

/// <summary>
/// Eats all characters untill a space is found
/// </summary>
/// <param name="str"></param>
/// <returns></returns>
/// @Untested
fn void eat_until_space(String* str) @inline 
{
	// first split the string by the space
	String[] s = str.split(" ");
	// then return only reminder
	*str = s[1].copy();
}

// @untested
// fn void unEscapeQuotes(char* arg) 
// {
	// char* last = NULL;

	// while (*arg) {
		// if (*arg == '"' && *last == '\\') {
			// char* c_curr = arg;
			// char* c_last = last;

			// while (*c_curr) {
				// *c_last = *c_curr;
				// c_last = c_curr;
				// c_curr++;
			// }
			// *c_last = '\0';
		// }
		// last = arg;
		// arg++;
	// }
// }

// fn bool expect_b(char** word, char token) @inline
// {
	// bool result = false;

	// // look at the next token
	// advance(word, 1);
	// if (**word == token) result = true; else result = false;
	// // return to the original token
	// goBack(word, 1);

	// return result;
// }

// fn void gotoNextLine(char* src) 
// {
	// while (isEndofLine(*src) == false)
	// {
		// advance(&src, 1);
	// }
	// // Advance the new line character
	// advance(&src, 1);
// }

/////////////////
// *Example*
// char* reminder;
// const char* text = "namespace this shoud be the rest.";

// tString result = hm::Cut_By_Spaces(text, &reminder);
// hplFree(reminder);
/////////////////

/// <summary>
/// Cuts a string by the first space it finds and returns 
/// both the cut and the reminder of the text, as new strings
/// Reminder has to be freed using hplFree (or just free()), delete is not supported.
/// </summary>
/// <param name="text"></param>
/// <param name="reminder"></param>
/// <returns></returns>
fn String[] divide_by_spaces(String* str)
{
	String[] result;
	
	int index = 0;
	while(true) 
	{
		String[] temp = str.tsplit(" ");
		if(temp.len == 1) {
			result[index] = temp[0];
			 break;
		}
		result[index] = temp[0];
		result[++index] = temp[1];
		index++;
	}
	return result;
}

// Don't forget to Clear the Array...
fn float[4] array4fFromText(String* text)
{
	if (text.len)
	{
		String needle = " ,\t\n\0";

		String[] s = text.tsplit(needle);

		if (s.len != 4) return {0.f,0.f,0.f,0.f};

		float[4] result;
		for(int i = 0; i < 4; i++) 
		{
			float value = 0.f;
			if(try value = s[i].to_float()) {
				 continue;
			} else {
				result[i] = value;
			}
		}
		return result;
	}

	return {0.f,0.f,0.f,0.f};
}

enum Token_type : short
{
	// simple tokens
	TOKEN_UNKNOWN,
	TOKEN_PLUS,
	TOKEN_MINUS,
	TOKEN_EQUALS,
	TOKEN_QUOTE,
	TOKEN_OPENPAREN,
	TOKEN_CLOSEPAREN,
	TOKEN_COMMA,
	TOKEN_COLON,
	TOKEN_SEMICOLON,
	TOKEN_ASTERISK,
	TOKEN_OPENBRACKET,
	TOKEN_CLOSEBRACKET,
	TOKEN_OPENBRACE,
	TOKEN_CLOSEBRACE,
	TOKEN_ENDOFSTREAM,
	// complex tokens
	TOKEN_STRING,
	TOKEN_IDENTIFIER,
	TOKEN_NUMERIC
}

struct Tokenizer
{
	CChar* at;
}

struct Token 
{
	Token_type type;
	uint len;
	CChar* text;
}

fn void Token.init(self, Token_type atype, int alen, String* str) @inline 
{
	self.type = atype;
	self.len  = alen;
	self.text = (CChar*)&(*str)[0];
}

fn void Token.deinit(self) @inline 
{
	self.type = TOKEN_UNKNOWN;
	self.len  = 0;
	self.text = null;
}

macro bool Token.equals(self, char* other)
{
	char* it = other;
	for (uint i = 0; i < self.len(); ++i, ++it)
	{
		if ((*it == 0) ||
			(*(self.text + i) != *it))
		{
			return false;
		}
	}

	bool result = (*it == 0);
	return result;
}
macro bool Token.equalsOther(Token other) 
{
	if ((self.type == other.type) &&
		(self.len == other.len) &&
		(self.text == other.text)) {
		return true;
	}
	return false;
}
macro Token.advance(self, uint count)
{
	if (self.len >= count) {
		// advance/shrink buffer characters by count
		// and remove count from the buffer count
		self.text += count;
		self.len -= count;
	} else {
		// advance/shrink to the end of the buffer
		self.text += self.len;
		self.len = 0;
	}
}

/// <summary>
/// Skips the current line on a multiline string
/// </summary>
/// <param name="tokenizer"></param>
/// <returns></returns>
fn void Token.gotoNextLine(self, Tokenizer* tokenizer) @inline
{
	while (!isEndofLine(*tokenizer.at))
	{
		self.advance(1);
	}
	// Advance the new line character as well
	self.advance(1);
}

/// <summary>
/// Skips all spaces from start of given adress/string, until it finds a non space character.
/// It also skips C/C++ style comments.
/// </summary>
/// <param name="tokenizer"></param>
/// <returns></returns>
fn void eatSpaces(Tokenizer* tokenizer) 
{
	while(true)
	{
		if (isWhiteSpace(tokenizer.at[0]))
		{
			advance(&tokenizer.at, 1);
		}
		// C style comments
		else if (tokenizer.at[0] == '/' &&
			tokenizer.at[1] == '/')
		{
			advance(&tokenizer.at, 2);
			while (tokenizer.at[0] &&
				!isEndofLine(tokenizer.at[0]))
			{
				advance(&tokenizer.at, 1);
			}
		}
		// C++ style comments
		else if (tokenizer.at[0] == '/' &&
			tokenizer.at[1] == '*')
		{
			advance(&tokenizer.at, 2);
			while (tokenizer.at[0] &&
				!(tokenizer.at[0] == '*' &&
					tokenizer.at[1] == '/'))
			{
				advance(&tokenizer.at, 1);
			}
			if (tokenizer.at[0] == '*')
			{
				advance(&tokenizer.at, 2);
			}
		}
		else
		{
			break;
		}
	}
}

/// <summary>
/// Gets and sets the token type 
/// </summary>
/// <param name="tokenizer"></param>
/// <returns></returns>
fn Token getToken(Tokenizer* tokenizer)
{
	String buffer = ((ZString)tokenizer.at).str_view();
	buffer = eat_starting_spaces(&buffer);

	Token token;
	token.len = 1;
	token.text = tokenizer.at;
	ichar c = tokenizer.at[0];
	// from here on tokenizer at, is set to one char, in front, 
	// of the current token that will be returned!!!
	advance(&tokenizer.at, 1);

	switch (c)
	{
	case '\0': token.type = Token_EndOfStream; 
	case '+':  token.type = Token_Plus;        
	case '-':  token.type = Token_Minus; 	
	case '=':  token.type = Token_Equals; 	
	case '(':  token.type = Token_OpenParen; 
	case ')':  token.type = Token_CloseParen; 
	case ',':  token.type = Token_Comma; 	
	case ':':  token.type = Token_Colon; 	
	case ';':  token.type = Token_SemiColon; 
	case '*':  token.type = Token_Asterisk; 
	case '[':  token.type = Token_OpenBracket; 
	case ']':  token.type = Token_CloseBracket;
	case '{':  token.type = Token_OpenBrace; 
	case '}':  token.type = Token_CloseBrace; 

	case '"': // "text" like String
	{
		//Advance(&tokenizer.at, 1);
		token.type = Token_String;
		token.text = tokenizer.at;

		// this is only used to get the CURRENT token len
		// and will NOT change what token is returned.
		if(0) 
		{
			while (tokenizer.at[0] &&
				tokenizer.at[0] != '"')
			{
				//if (tokenizer.at[0] == '\\' && // skip path dash's
				//	tokenizer.at[1])
				//{
				//	advance(&tokenizer.at, 1);
				//}
				advance(&tokenizer.at, 1);
			}

			token.len = tokenizer.at - token.text;
			// if (tokenizer.at[0] == '"')
			// {
				// advance(&tokenizer.at, 1);
			// }
		}
		
		for(;;)
		{
			if (*tokenizer.at == '"')
			{
				// is this correct?  TODO @TEST
				// Perhaps I shouldn't go back one but just break here?
				_return(&tokenizer.at, 1); 
				break;
			}

			advance(&tokenizer.at, 1);
		}

		token.len = tokenizer.at - token.text;
	}
	default:
		if (libc::isalpha(c))
		{
			token.type = Token_Identifier;

			// this is only used to get the CURRENT token len
			// and will NOT change what token is returned.
			while (libc::isalpha(tokenizer.at[0]) ||
				libc::isdigit(tokenizer.at[0]) ||
				tokenizer.at[0] == '_')
			{
				advance(&tokenizer.at, 1);
			}

			token.len = tokenizer.at - token.text;
		}
		else if (libc::isdigit(c))
		{
			token.type = Token_Numeric;

			// this is only used to get the CURRENT token len
			// and will NOT change what token is returned.
			while (libc::isdigit(tokenizer.at[0]) ||
				tokenizer.at[0] == '.') // floating point numbers...
			{
				advance(&tokenizer.at, 1);
			}

			token.len = tokenizer.at - token.text;

			// skip spaces...
			if (libc::isspace(*tokenizer.at)) {
				advance(&tokenizer.at, 1);
			}
		}
		else
		{
			token.type = Token_Unknown;
		}
		break;
	}

	return token;
}

///**********************************************************
// End Text parsing code
///**********************************************************
