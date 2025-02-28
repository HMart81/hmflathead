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

/*
===============================================================================

	Dynamic Array module
	Does not allocate memory until the first item is added.

	NOTE: // Inspired by PhillipTrudeau code while making the Silent Hill 2 editor
===============================================================================
*/

module hm::dyarray(<Type>);

import std::io, std::core::mem;

struct DyArray (Printable)
{
	int count;
	int capacity;
	Type* data;
}

fn bool array_invariants(arr) @inline @local {
	return (arr.count >= 0 && arr.count <= arr.capacity && !arr.data == !arr.capacity) ? true : false;
}

macro Type* DyArray.get(&self, usz index) @operator([])
{
	assert(index >= 0 && index < self.count && self.count <= self.capacity && self.data);
	return &(self.data + index);
}

macro int DyArray.count(self) @operator(len) => self.count;

fn void DyArray.amortize(&self, int new_count) 
{
	assert(array_invariants(self) == true);
	if (new_count > self.capacity)
	{
		if (self.capacity < 16) self.capacity = 16;
		while (new_count > self.capacity) self.capacity = self.capacity * 3 / 2;
		self.data = mem::alloc_array_aligned(Type, self.capacity);
		assert(self.data != null); // Yucky!!!
	}
}

fn void DyArray.reserve(&self, int new_capacity) 
{
	assert(array_invariants(self) == true);
	assert(new_capacity >= 0);
	self.amortize(new_capacity);
}

fn void DyArray.resize(&self, int new_count, Type value = {}) {
	assert(array_invariants(self) == true);
	self.amortize(new_count);
	for (usz i = self.count; self.count < new_count; i++) self.data[i] = value;
	self.count = new_count;
}

fn DyArray DyArray.copy(&self) {
	assert(array_invariants(self) == true);
	DyArray result;
	if (self.count) {
		result.amortize(self.count);
		mem::copy(result.data, self.data, self.count * Type.sizeof);
	}
	result.count = self.count;
	return result;
}

fn DyArray DyArray.move(&self) {
	assert(array_invariants(self) == true);
	DyArray result;
	if (self.count) {
		result.amortize(self.count);
		mem::move(result.data, self.data, self.count * Type.sizeof);
	}
	result.count = self.count;
	self = {};
	return result;
}

fn Type* DyArray.push(&self, Type value = {}) {
	assert(array_invariants(self) == true);
	self.amortize(self.count + 1);
	self.count++;
	self.data[self.count - 1] = value;
	return &self.data[self.count - 1];
}

fn Type DyArray.pop(&self) {
	assert(array_invariants(self) == true && self.count > 0);
	self.count -= 1;
	return *self.data[self.count];
}

fn Type* DyArray.insert(&self, int index, Type value = {}) {
	assert(array_invariants(self) == true && index < self.count);
	self.amortize(self.count + 1);
	mem::move(self.data[index + 1], self.data[index], (self.count - index - 1) * Type.sizeof);
	self.count++;
	self.data[index] = value;
	return &self.data[index];
}

fn void DyArray.remove(&self, int index) {
	assert(array_invariants(self) == true && index < self.count);
	self.data[index] = self.data[self.count - 1];
	self.count -= 1;
}

fn void DyArray.remove_ordered(&self, int index, int how_many = 1) {
	assert(array_invariants(self) == true && index < self.count);
	mem::move(self.data[index], self.data[index + 1], (self.count - index - 1) * Type.sizeof);
	self.count -= how_many;
}

fn void DyArray.clear(&self) {
	assert(array_invariants(self) == true);
	self.count = 0;
}

fn void DyArray.release(&self) {
	assert(array_invariants(self) == true);
	if (self.data) {
		mem::free(self.data);
	}
	self.data     = null;
	self.count    = 0;
	self.capacity = 0;
}

fn Type* DyArray.begin(&self) {
	assert(array_invariants(self) == true);
	return self.data;
}

fn Type* DyArray.end(&self) {
	assert(array_invariants(self) == true);
	return (self.data + self.count);
}
