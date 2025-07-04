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

module thirdparty::library::xml;

import std::core;
import std::io;
import std::ascii;

//const char[] TEXT_NODE_NAME = "#text";
const String TEXT_NODE_NAME = "#text";

typedef XmlReader = void;

enum ReaderState @local {
	BEGIN_READ_TAG,
	READ_HEADER,
	END_READ_TAG,
	READ_TAG_NAME,
	READ_TEXT_NODE,
	READ_CLOSING_TAG,
	READ_ATTRIBUTE_NAME,
	BEGIN_READ_ATTRIBUTE_VALUE,
	END_READ_ATTRIBUTE_VALUE,
	READ_COMMENT,
}

struct XmlReaderImpl @local {
	ReaderState state;
	usz readHead;
	usz writeHead;
	char[] buffer;
	Allocator allocator;
	XmlDoc* doc;
	XmlNodeList nodesBeingParsed;
	XmlAttribute* attributeBeingParsed;
}

fn XmlReader* new_reader(XmlDoc* doc, Allocator allocator = allocator::heap()) {
	XmlReaderImpl* reader = allocator::new(allocator, XmlReaderImpl);
	reader.doc = doc;
	//reader.buffer = allocator::new_array(allocator, char, 2048);
	reader.buffer = allocator::new_array(allocator, char, doc.contents_size);
	reader.allocator = allocator;
	reader.state = BEGIN_READ_TAG;
	return (XmlReader*)reader;
}

fn void XmlReader.free(&this) {
	XmlReaderImpl* self = (XmlReaderImpl*)this;
	self.attributeBeingParsed = null;
	self.doc = null;
	self.readHead = 0;
	self.writeHead = 0;
	self.nodesBeingParsed.free();
	allocator::free(self.allocator, self.buffer);
	allocator::free(self.allocator, self);
}

fn void XmlReader.read(&this, char[] slice) {
	XmlReaderImpl* self = (XmlReaderImpl*)this;
	self.readHead = 0;
	while (self.readHead < slice.len) {
		char c = self.readChar(slice)!!;
		switch (self.state) {
			case READ_HEADER:
				self.read_header(c);
			case BEGIN_READ_TAG:
				self.begin_read_tag(c);
			case END_READ_TAG:
				self.end_read_tag(c);
			case READ_TAG_NAME:
				self.read_tag_name(c);
			case READ_TEXT_NODE:
				self.read_text_node(c);
			case READ_CLOSING_TAG:
				self.read_closing_tag(c);
			case READ_ATTRIBUTE_NAME:
				self.read_attribute_name(c);
			case BEGIN_READ_ATTRIBUTE_VALUE:
				self.begin_read_attribute_value(c);
			case END_READ_ATTRIBUTE_VALUE:
				self.end_read_attribute_value(c);
			case READ_COMMENT:
				self.parse_comment(c);
		}
	}
}

// Private Section

fn char? XmlReaderImpl.readChar(&self, char[] slice) @local {
	usz readHead = self.readHead;
	if (readHead >= slice.len){
		return io::EOF?;
	}
	char c = slice[readHead];
	self.readHead = readHead + 1;
	return c;
}	

fn void XmlReaderImpl.writeChar(&self, char c) @local {
	usz writeHead = self.writeHead;
	if (writeHead >= self.buffer.len) {
		// TODO: Really need to properly handle the error here
		io::printf("%s\n", self.buffer);
	}
	self.buffer[writeHead] = c;
	self.writeHead = writeHead + 1;
}	

fn void XmlReaderImpl.push_node(&self, XmlNode* node) @local {
	self.nodesBeingParsed.push(node);
}

fn void XmlReaderImpl.pop_node(&self) @local {
	self.nodesBeingParsed.pop()!!;
}

fn XmlNode* XmlReaderImpl.peek_node(&self) @local {
	return self.nodesBeingParsed.last()!!;
}

fn void XmlReaderImpl.begin_read_tag(&self, char c) @local {
	if (c == '<') {
		self.state = ReaderState.END_READ_TAG;
	}
}

fn void XmlReaderImpl.end_read_tag(&self, char c) @local {
	if (c == '!') {
		self.state = ReaderState.READ_COMMENT;
	} else if (c == '/') {
		self.writeHead = 0;
		self.state = ReaderState.READ_CLOSING_TAG;
	} else if (c == '?') {
		self.state = READ_HEADER;
	} else {
		self.writeHead = 0;
		self.writeChar(c);
		XmlNode* child = self.create_node();
		if (self.doc.rootNode == null) {
			self.doc.rootNode = child;
		} else {
			XmlNode* nodeBeingParsed = self.peek_node();
			nodeBeingParsed.children.push(child);
		}
		self.push_node(child);
		self.state = ReaderState.READ_TAG_NAME;
	}
}

fn XmlNode* XmlReaderImpl.create_node(&self) @local {
	XmlNode* node = allocator::new(self.allocator, XmlNode);
	node.allocator = self.allocator;
	return node;
}

fn XmlAttribute* XmlReaderImpl.create_attribute(&self) @local {
	XmlAttribute* attribute = allocator::new(self.allocator, XmlAttribute);
	attribute.allocator = self.allocator;
	return attribute;
}

fn void XmlReaderImpl.read_tag_name(&self, char c) @local {
	if (c == '/' || c == '>' || /*c == ' '*/ascii::is_space(c)) {
		XmlNode* nodeBeingParsed = self.peek_node();
		nodeBeingParsed.name = self.copy_write_buffer();
		if (c == '>') {
			self.writeHead = 0;
			self.state = ReaderState.READ_TEXT_NODE;
		} else if (/*c == ' '*/ascii::is_space(c)) {
			self.writeHead = 0;
			self.attributeBeingParsed = self.create_attribute();
			self.state = ReaderState.READ_ATTRIBUTE_NAME;
		} else if (c == '/') {
			self.state = ReaderState.READ_CLOSING_TAG;
		}
	} else {
		self.writeChar(c);
	}
}

fn void XmlReaderImpl.read_closing_tag(&self, char c) @local {
	if (c == '>') {      
		XmlNode* node = self.peek_node(); 
		self.pop_node();
		self.writeHead = 0;
		self.state = ReaderState.READ_TEXT_NODE;
	}
}

fn void XmlReaderImpl.enterReadTextNodeState(&self) @local {
	self.writeHead = 0;
	self.state = ReaderState.READ_TEXT_NODE;
}

fn void XmlReaderImpl.read_attribute_name(&self, char c) @local {
	if (c == '/') {
		self.state = ReaderState.READ_CLOSING_TAG;
	} else if (c == '>') {
		self.enterReadTextNodeState();
	} else if (/*c == ' '*/ascii::is_space(c)) {
		// Skip space (NOTE(HM) and any other white space character...)
	} else if (c == '=') {
		self.attributeBeingParsed.name = self.copy_write_buffer();
		self.state = ReaderState.BEGIN_READ_ATTRIBUTE_VALUE;
		self.writeHead = 0;
	} else {
		self.writeChar(c);
	}
}

fn void XmlReaderImpl.begin_read_attribute_value(&self, char c) @local {
	if (/*c == ' '*/ascii::is_space(c)) {
		// Skip space (NOTE(HM) and any other white space character...)
	} else if (c == '"') {
		self.state = ReaderState.END_READ_ATTRIBUTE_VALUE;
	} else {
		io::printf("Encountere unknown character %s\n", c);
	}
}

fn String XmlReaderImpl.copy_write_buffer(&self) @local {
	usz strLength = self.writeHead;
	char[] strValue = allocator::new_array(self.allocator, char, strLength);
	strValue[..] = self.buffer[:strLength];
	return (String)strValue;
}

fn void XmlReaderImpl.end_read_attribute_value(&self, char c) @local {
	if (c == '"') {
		self.attributeBeingParsed.value = self.copy_write_buffer();
		XmlNode* nodeBeingParsed = self.peek_node();
		nodeBeingParsed.attributes.push(self.attributeBeingParsed);
		self.attributeBeingParsed = self.create_attribute();
		self.writeHead = 0;
		self.state = ReaderState.READ_ATTRIBUTE_NAME;
	} else {
		self.writeChar(c);
	}
}

fn void XmlReaderImpl.read_header(&self, char c) @local {
	if (c == '>') {
		self.state = ReaderState.BEGIN_READ_TAG;
	}
}

fn void XmlReaderImpl.read_text_node(&self, char c) @local {
	if (c == '<') {
        String textValue = self.copy_write_buffer();
        bool emptyText   = textValue.trim().len == 0;
		if (!emptyText && self.writeHead > 0) {
			XmlNode* textNode = self.create_node();
			textNode.name = string::format(self.allocator, "%s", TEXT_NODE_NAME);
			textNode.value = textValue.copy(self.allocator); //self.copy_write_buffer();
			XmlNode* nodeBeingParsed = self.peek_node();
			nodeBeingParsed.children.push(textNode);
		}
		self.writeHead = 0;
		self.state = ReaderState.END_READ_TAG;
	} else {
		self.writeChar(c);
	} 
}

fn void XmlReaderImpl.parse_comment(&self, char c) @local {
	self.writeChar(c);
	if (self.writeHead < 3) {
		return;
	}

	if (c != '>') {
		return;
	}

	char[] lastThreeChars = self.buffer[self.writeHead-3:3];
	if (lastThreeChars == "-->") {
		self.writeHead = 0;
		self.state = ReaderState.BEGIN_READ_TAG;
	}
}
