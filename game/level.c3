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

// unfinished code, this is a work in progress
// this file is part of the game level system, which handles loading and saving levels/maps
module game::level::lvl;

// #region imports
import std::io;
import std::collections::list;
import game::main; // for file logging or console logging
import engine::misc;
import game::serialize::svs;
import engine::sys::cvar;
import engine::logging::lgr;
import engine::filesystem::fs;
import engine::sys::reader::svg;
import game::actors::ent, game::actors::ent::pl;
// #endregion

const int OLD_MAP_VERSION	    = 0;
const int CURRENT_MAP_VERSION	= 1;

alias EntityList = List{Entity*};
alias HMDict @local = StringTuple;

struct MapEntity 
{
	HMDict kv;
}

fn MapEntity* MapEntity.parse(&self, Path src, bool worldSpawn = false, int version = CURRENT_MAP_VERSION ) {
    @todo("Implement MapEntity parsing");
}

fn bool	MapEntity.write(&self, File* fp, int entityNum ) {
    @todo();
}

struct Level 
{
    String name;
    String path;

    EntityList entities;
}