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

module game::lowlevel::bounds;

import std::math;
import engine::misc;
import game::low_level::cvar;
import thirdparty::raylib5::rl;

const float	INFINITY = 1e30f;

Cvar db_showBounds = { "db_showBounds", CvarType.BOOLEAN, "1", "displays used bounding box's on screen for debug"};

fn void register_cvars() {
    cvar::@register(&db_showBounds);
}

struct Bounds {
    Vec2f maxc;
    Vec2f minc;
}

<*
* @param [in] rect "rectangle to get data from"
* @require rect != null
*>
fn Bounds Bounds.fromRect(&self, Rectangle* rect) @inline {
    Vec2f size = rect.getSize().arr;
    self.maxc  = rect.getPosition().arr;
    self.minc  = self.maxc + misc::VEC_RIGHT * size.x + misc::VEC_DOWN * size.y;
    return *self;
}

fn void Bounds.debugDraw(self) {
    Vec2f size = self.minc - self.maxc;
    rl::drawRectangleLinesEx(misc::makeRect(self.maxc, {size.x, size.y}), 2.5f, rl::YELLOW);
}

fn void Bounds.set(&self, Vec2f minc, Vec2f maxc) @inline {
    self.maxc = maxc;
    self.minc = minc;
}

fn void Bounds.setRect(&self, Rectangle rect) @inline {
    Vec2f origin = rect.getPosition().arr;
    float w, h;
    w = rect.getSize().x;
    h = rect.getSize().y;
    self.maxc = origin;
    self.minc = self.maxc + misc::VEC_RIGHT * w + misc::VEC_DOWN * h;
}

fn bool Bounds.compare(&self, Bounds* a ) @inline {
    return (self.minc == a.minc && self.maxc == a.maxc);
}

fn void Bounds.clear(&self) @inline {
	self.maxc.x = self.maxc.y = INFINITY;
	self.minc.x = self.minc.y = -INFINITY;
}

fn void Bounds.zero(&self) @inline {
	self.maxc.x = self.maxc.y =
	self.minc.x = self.minc.y = 0.0f;
}

fn Vec2f Bounds.getCenter(&self) @inline {
    return (Vec2f) {( self.minc.x + self.maxc.x ) * 0.5f, ( self.minc.y + self.maxc.y ) * 0.5f };
    //return (self.maxc + self.minc) * 0.5f;
}

fn float Bounds.getVolume(&self) @inline {
    if(self.maxc.x >= self.minc.x || self.maxc.y >= self.minc.y) return 0.0f;
    
	return ( (self.minc.x - self.maxc.x ) * ( self.minc.y - self.maxc.y ) );
}

fn bool Bounds.isCleared(&self) @inline {
	return self.maxc.x > self.minc.x;
}

fn bool Bounds.addPoint(&self, Vec2f* v ) @inline {
	bool expanded = false;
	if ( v.x < self.maxc.x) {
		self.maxc.x = v.x;
		expanded = true;
	}
	if ( v.x > self.minc.x) {
		self.minc.x = v.x;
		expanded = true;
	}
	if ( v.y < self.maxc.y ) {
		self.maxc.y = v.y;
		expanded = true;
	}
	if ( v.y > self.minc.y) {
		self.minc.y = v.y;
		expanded = true;
	}
	return expanded;
}

fn bool Bounds.addBounds(&self, Bounds* a ) @inline {
	bool expanded = false;
	if ( a.maxc.x < self.maxc.x ) {
		self.maxc.x = a.maxc.x;
		expanded = true;
	}
	if ( a.maxc.y < self.maxc.y ) {
		self.maxc.y = a.maxc.y;
		expanded = true;
	}
	if ( a.minc.x > self.minc.x ) {
		self.minc.x = a.minc.x;
		expanded = true;
	}
	if ( a.minc.y > self.minc.y ) {
		self.minc.y = a.minc.y;
		expanded = true;
	}
	return expanded;
}

fn Bounds Bounds.intersect(&self, Bounds* a ) @inline {
	Bounds n;
	n.maxc.x = ( a.maxc.x > self.maxc.x ) ? a.maxc.x : self.maxc.x;
	n.maxc.y = ( a.maxc.y > self.maxc.y ) ? a.maxc.y : self.maxc.y;
	n.minc.x = ( a.minc.x < self.minc.x ) ? a.minc.x : self.minc.x;
	n.minc.y = ( a.minc.y < self.minc.y ) ? a.minc.y : self.minc.y;
	return n;
}

fn Bounds* Bounds.intersectSelf(&self, Bounds* a ) @inline {
	if ( a.maxc.x > self.maxc.x ) {
		self.maxc.x = a.maxc.x;
	}
	if ( a.maxc.y > self.maxc.y ) {
		self.maxc.y = a.maxc.y;
	}
	if ( a.minc.x < self.minc.x ) {
		self.minc.x = a.minc.x;
	}
	if ( a.minc.y < self.minc.y ) {
		self.minc.y = a.minc.y;
	}
	return self;
}

fn Bounds Bounds.expand(self, float d ) @inline {
    Bounds bounds;
    bounds.maxc = (Vec2f){ self.maxc.x - d, self.maxc.y - d };
    bounds.minc = (Vec2f){ self.minc.x + d, self.minc.y + d };
	return bounds;
}

fn Bounds* Bounds.expandSelf(&self, float d ) @inline {
	self.maxc.x -= d;
	self.maxc.y -= d;
	self.minc.x += d;
	self.minc.y += d;
	return self;
}

/*
* Row Major*
|sx ry tx|   |m00 m01 m02|
|rx sy ty| = |m10 m11 m12|
| 0  0  1|   |m20 m21 m22|
*/
fn void Bounds.fromTransformedBounds(&self, Vec2f origin, Matrix3f* axis ) {
	Vec2f center, extents, rotatedExtents;

	center  = (self.maxc + self.minc) * 0.5f;
	extents = self.minc - center;
    
    rotatedExtents.x = math::abs( extents.x * axis.m00 ) +
					   math::abs( extents.y * axis.m10 );
    rotatedExtents.y = math::abs( extents.x * axis.m01 ) +
					   math::abs( extents.y * axis.m11 );

	//center = origin + center * axis;
    center = (origin + (axis.multiply(center)));
	self.maxc = center - rotatedExtents;
	self.minc = center + rotatedExtents;
}

/*
   transpose
|m00 m01 m02|   |m00 m10 m20|
|m10 m11 m12| = |m01 m11 m21|
|m20 m21 m22|   |m02 m12 m22|
*/

fn Bounds Bounds.translate(&self, Vec2f translation ) @inline {
	self.maxc += translation;
	self.minc += translation;
	return *self;
}

fn Bounds* Bounds.rotate(&self, Matrix3f* rotation ) @inline { 
	self.fromTransformedBounds( (Vec2f){0,0}, rotation );
	return self;
}

fn bool Bounds.containsPoint(&self, Vec2f p ) @inline {
	if ( p.x < self.maxc.x || p.y < self.maxc.y || p.x > self.minc.x || p.y > self.minc.y) {
		return false;
	}
	return true;
}

fn bool Bounds.intersectsOther(&self, Bounds* a) @inline {
	if (a.minc.x < self.maxc.x || a.minc.y < self.maxc.y ||
		a.maxc.x > self.minc.x || a.maxc.y > self.minc.y) {
		return false;
	}
	return true;
}
