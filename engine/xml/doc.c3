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

import std::io;
import std::collections;
import std::core::mem::alloc;

alias XmlAttributeList = List{XmlAttribute*};
alias XmlNodeList      = List{XmlNode*};

faultdef ATTRIBUTE_NOT_FOUND;

struct XmlAttribute 
{
	String name;
	String value;
}

struct XmlNode 
{
	String name;
	String value;
	XmlAttributeList attributes;
	XmlNodeList children;
}

struct XmlDoc 
{
	XmlNode* rootNode;
    usz contents_size;
}

fn XmlDoc*? read_file(File file) {
	usz contents_size = file.seek(0, Seek.END)!;
	file.seek(0, Seek.SET)!; // return to the start
	//char[] buff = allocator::new_array(allocator, char, 2048);
	char[] buff = alloc::new_array(mem, char, contents_size);
	defer alloc::free(mem, buff);

	XmlDoc* doc   = mem::new(XmlDoc);
    doc.contents_size = contents_size;

	XmlReader* reader = new_reader(doc);
	defer reader.free();

	while (!file.eof()) {
		usz? bytesRead = file.read(buff);
		if (catch f = bytesRead) {
			return f~;
		}
		char[] data = buff[0:bytesRead];
		reader.read(data);
	}

	return doc;
}

fn void XmlDoc.free(&self) {
	self.rootNode.free();
	alloc::free(mem, self);
}

fn void XmlNode.free(&node) {
	// NOTE(Zee): Does it make sense for the node to free its own children?
	foreach(child : node.children) {
		child.free();
	}

	foreach(attribute : node.attributes) {
		attribute.free();
	}

	node.children.free();
	node.attributes.free();
	node.name.free(mem);
	node.value.free(mem);

	// TODO: Free Name and Value
	alloc::free(mem, node);
}

fn void XmlAttribute.free(&self) {
	self.name.free(mem);
	self.value.free(mem);
	// TODO: Free Name and Value;
	alloc::free(mem, self);
}

fn void XmlDoc.find_nodes_by_tag_name(&self, char[] type, XmlNodeList* cache) {
	XmlNode* node = self.rootNode;
	node.find_nodes_by_tag_name(type, cache);
}

fn void XmlNode.find_nodes_by_tag_name(&self, char[] type, XmlNodeList* cache) {
	if (self.name == type) {
		cache.push(self);
	}

	for (usz i = 0; i < self.children.size; i++) {
		XmlNode* childNode = self.children[i];
		childNode.find_nodes_by_tag_name(type, cache);
	}
}

fn XmlNode XmlDoc.get_node(&self, String name) {
    XmlNodeList cache;
    self.find_nodes_by_tag_name(name, &cache);
    
    foreach (node : cache) {
		if(node.name == name) return *node;
	}
    
    return {};
}

fn XmlNode* XmlNode.findNextChild(&self, String name) {
    foreach (child : self.children) {
		if(child.name == name) return child;
	}
    
    return null;
}

fn bool XmlNode.hasAttributes(&self) => (self.attributes.size) ? true : false;

fn XmlAttribute* XmlNode.getAttribute(&self, String name) 
{
	foreach(atrb : self.attributes) {
		if (atrb.name == name) {
			return atrb;
		}
	}
	return null;
}

fn char[]? XmlNode.get_attrib_value(&self, char[] name) @deprecated("Use XmlNode.getAttribute instead")
{
	for (usz i = 0; i < self.attributes.size; i++) {
		XmlAttribute* attribute = self.attributes[i];
		if (attribute.name == name) {
			return attribute.value;
		}
	}
	return ATTRIBUTE_NOT_FOUND~;
}


fn void XmlDoc.print_as_tree(&doc, OutStream stream) {
	doc.rootNode.print_as_tree(stream, 0, 0, 0);
}

fn String XmlNode.getText(&self)
{
    String result;
    usz child_count = self.children.len();
    while(child_count > 0 && self.children[child_count - 1].name == "#text") {
        result = result.tconcat(self.children[child_count - 1].value);
        child_count--;
    }
    
    return result;
}

fn void XmlNode.print_as_tree(&node, OutStream stream, int depth, usz childIndex, usz childCount) {

	for (int i = 0; i < depth - 1; i++) {
		io::fprintf(stream, "%c", '│')!!;
	}

	if (childCount > 0) {
		if(childIndex == childCount - 1) {
			io::fprintf(stream, "%c", '└')!!;
		} else {
			io::fprintf(stream, "%c", '├')!!;
		}
	}

	io::fprintf(stream, "%s:%s", node.name, node.attributes.size)!!;
	for (usz i = 0; i < node.attributes.size; i++) {
		XmlAttribute* attribute = node.attributes[i];
		io::fprintf(stream, ", %s=\"%s\"", attribute.name, attribute.value)!!;
	}

	if (node.value.len > 0) {
		String v = (String)node.value;
		String trimmed = v.trim();
		if (trimmed.len > 0) {
			io::fprintf(stream, " \"%s\"", trimmed)!!;
		}
	}

	io::fprint(stream, "\n")!!;

	depth = depth + 1;
	for (usz i = 0; i < node.children.size; i++) {
		XmlNode* child = node.children[i];
		child.print_as_tree(stream, depth, i, node.children.size);
	}
}
