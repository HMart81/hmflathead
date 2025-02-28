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

module game::logic::timer;

// region C3 imports
import std::io;
// import std::ascii;
// import std::io::file;
// import std::collections::list;
// import std::collections::tuple;
// end

// region custom imports
import raylib5::rl;
import engine::misc;
import game::serialize::svs; // save system
// end

struct Timer (SaveSystemInterface) {
	float lifetime;
}

fn void Timer.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Timer.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn bool Timer.initialized(&self) @inline => self.lifetime > 0;

fn void Timer.init(&self, float lifetime) @inline {
	self.lifetime = lifetime;
}

fn void Timer.update(&self) @inline {
	if(self.lifetime > 0) self.lifetime -= rl::getFrameTime();
}

<*
 * @return "Returns true if it has finished, false otherwise"
 *>
fn bool Timer.isDone(&self) @inline {
	return self.lifetime <= 0;
}

<*
 * @return "Returns true if it has NOT finished, false otherwise"
 *>
fn bool Timer.alive(&self) @inline {
	return (self.isDone()) ? false : true;
}
