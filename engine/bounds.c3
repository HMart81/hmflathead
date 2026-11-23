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

import std::io;
import std::math;
import engine::misc;
import engine::sys::cvar;
import engine::sys::ctype;
import thirdparty::raylib5::rl;

CVar db_showBounds = { "db_showBounds", CvFlag.BOOL, "1", "displays used bounding box's on screen for debug"};

fn void register_cvars() {
    cvar::@register(&db_showBounds);
}

struct HMBounds (Printable) @packed 
{
    Vec2f maxc;
    Vec2f minc;
}

fn sz? HMBounds.to_format(&self, Formatter* f) @dynamic 
{
    return f.printf(`HMBounds { .maxc = %s, .minc = %s, }`, self.maxc, self.minc);
}

<*
 @param [in] rect : "rectangle to get data from"
 @require rect != null
*>
fn HMBounds HMBounds.fromRect(&self, RLRectangle* rect) @inline {
    Vec2f size = rect.getSize();
    self.maxc  = rect.getPosition();
    self.minc  = self.maxc + misc::VEC_RIGHT * size.x + misc::VEC_DOWN * size.y;
    return *self;
}

fn RLRectangle HMBounds.toRect(&self) @inline {
	Vec2f size = (self.minc - self.maxc);
	return {
		.x = 0,
		.y = 0,
		.width = size.x,
		.height = size.y
	};
}

fn void HMBounds.debugDraw(self) {
	// Right now the bounds size are in pixels
	rl::drawCircle((int)self.maxc.x, (int)self.maxc.y, 2.0f, rl::SKYBLUE);
	rl::drawCircle((int)self.minc.x, (int)self.minc.y, 2.0f, rl::SKYBLUE);
	/*Vec2f size = self.bounds.minc - self.bounds.maxc;
	RLRectangle r = {rect.x, rect.y, size.x, size.y};
	rl::drawRectangleLinesEx(r, 1.0f, rl::YELLOW);*/
    Vec2f size = self.minc - self.maxc;
    rl::drawRectangleLinesEx(misc::makeRect(self.maxc, {size.x, size.y}), 2.5f, rl::YELLOW);
}

fn void HMBounds.set(&self, Vec2f minc, Vec2f maxc) @inline 
{
    self.maxc = maxc;
    self.minc = minc;
}

////
fn Vec2f HMBounds.get(&self, usz index ) @operator([]) 
{
	switch(index) 
    {
        case 0:
            return self.maxc;
        case 1:
            return self.minc;
        default:
            unreachable();
    }
}

fn Vec2f* HMBounds.get_ref(&self, usz index ) @operator(&[]) 
{
	switch(index) 
    {
        case 0:
            return &self.maxc;
        case 1:
            return &self.minc;
        default:
            unreachable();
    }
}

fn usz HMBounds.len(&self) @operator(len)
{
    return self.maxc.len + self.minc.len;
}

fn void HMBounds.set2(&self, usz i, Vec2f new_val) @operator([]=)
{
    return (*self)[i] = new_val;
}

fn HMBounds HMBounds.addV(self, Vec2f t) @operator(+)
{
	return (HMBounds) { self.maxc + t, self.minc + t };
}

fn HMBounds* HMBounds.peqV(&self, Vec2f t ) @operator(+=)
{
	self.maxc += t;
	self.minc += t;
	return self;
}

fn HMBounds HMBounds.mul(&self, Matrix3f* r ) @operator(*)
{
	HMBounds bounds;
	bounds.fromTransformedBounds(VEC2_ZERO, r );
	return bounds;
}

fn HMBounds* HMBounds.muleq(&self, Matrix3f* r ) @operator(*=)
{
	self.fromTransformedBounds(VEC2_ZERO, r );
	return self;
}

fn HMBounds HMBounds.addOther(&self, HMBounds* a ) @operator(+)
{
	HMBounds newBounds;
	newBounds = *self;
	newBounds.addBounds( a );
	return newBounds;
}

// fn HMBounds* HMBounds.peqB(&self, HMBounds* a) @operator(+=)
// {
	// HMBounds.addBounds( a );
	// return self;
// }

fn HMBounds HMBounds.minusB(&self, HMBounds* a) @operator(-)
{
	assert( self.minc.x - self.maxc.x > a.minc.x - a.maxc.x &&
				self.minc.y - self.maxc.y > a.minc.y - a.maxc.y);
	return (HMBounds) {(Vec2f){self.maxc.x + a.minc.x, self.maxc.y + a.minc.y},
					  (Vec2f){self.minc.x + a.maxc.x, self.minc.y + a.maxc.y}};
}

fn HMBounds* HMBounds.minusEq(&self, HMBounds* a) @operator(-=)
{
	assert(self.minc.x - self.maxc.x > a.minc.x - a.maxc.x &&
		   self.minc.y - self.maxc.y > a.minc.y - a.maxc.y);
	self.maxc += a.minc;
	self.minc += a.maxc;
	return self;
}
////

fn HMBounds HMBounds.addBB(self, HMBounds other) @operator_s(+)
{
    return {
        self.maxc + other.maxc,
        self.maxc + other.minc
    };
}

// <*
    // @param [in] other "other bounds to do subtraction with"
    // @require other != null
    // @ensure (return.maxc - return.minc).length() > 0
// *>
// fn HMBounds HMBounds.sub(self, HMBounds* other) @operator_s(-)
// {
    // return {
        // self.maxc - other.maxc,
        // self.maxc - other.minc
    // };
// }

<*
    @param [in] other : "other bounds to do somation with"
    @require other != null
*>
fn void HMBounds.pequals(&self, HMBounds* other) @operator(+=)
{
    self.maxc = self.maxc + other.maxc;
    self.minc = self.maxc + other.minc;
}

// <*
    // @param [in] other "other bounds to do subtraction with"
    // @require other != null
    // @ensure (self.maxc - self.minc).length() > 0
// *>
// fn void HMBounds.mequals(&self, HMBounds* other) @operator(-=)
// {
    // self.maxc = self.maxc - other.maxc;
    // self.minc = self.maxc - other.minc;
// }

fn void HMBounds.setRect(&self, RLRectangle rect) @inline 
{
    self.maxc = rect.pos;
    self.minc = self.maxc + misc::VEC_RIGHT * rect.w + misc::VEC_DOWN * rect.h;
}

<*
    @param [in] a : "other bounds to compare too"
    @require a != null
*>
fn bool HMBounds.compare(&self, HMBounds* a ) @operator(==)
{
    return (self.minc == a.minc && self.maxc == a.maxc);
}

<*
    @param [in] a : "other bounds to compare too"
    @require a != null
*>
fn bool HMBounds.less_than(&self, HMBounds* a ) @operator(<)
{
    return (self.minc.x < a.minc.x &&
			self.minc.y < a.minc.y &&
			self.maxc.x < a.maxc.x &&
			self.maxc.y < a.maxc.y
			);
}

fn void HMBounds.clear(&self) @inline 
{
	self.maxc.x = self.maxc.y = misc::INFINITY;
	self.minc.x = self.minc.y = -misc::INFINITY;
}

fn void HMBounds.zero(&self) @inline 
{
	self.maxc.x = self.maxc.y =
	self.minc.x = self.minc.y = 0.0f;
}

fn Vec2f HMBounds.getCenter(&self) @inline {
    return (Vec2f) {( self.minc.x + self.maxc.x ) * 0.5f, ( self.minc.y + self.maxc.y ) * 0.5f };
    //return (self.maxc + self.minc) * 0.5f;
}

fn float HMBounds.getVolume(&self) @inline {
    if(self.maxc.x >= self.minc.x || self.maxc.y >= self.minc.y) return 0.0f;
    
	return ( (self.minc.x - self.maxc.x ) * ( self.minc.y - self.maxc.y ) );
}

fn float HMBounds.getRadius(&self) @inline {
	float total, b0, b1;
	for (int i = 0; i < 2; i++ ) {
		b0 = (float)math::abs( self.maxc[i] );
		b1 = (float)math::abs( self.minc[i] );
		if ( b0 > b1 ) {
			total += b0 * b0;
		} else {
			total += b1 * b1;
		}
	}
	return math::sqrt( total );
}

fn float HMBounds.getRadiusUsingCenter(&self, Vec2f* center ) @inline {
	float total, b0, b1;
	for (int i = 0; i < 2; i++ ) {
		b0 = (float)math::abs( (*center)[i] - self.maxc[i] );
		b1 = (float)math::abs( self.minc[i] - (*center)[i] );
		if ( b0 > b1 ) {
			total += b0 * b0;
		} else {
			total += b1 * b1;
		}
	}
	return math::sqrt( total );
}

fn bool HMBounds.isCleared(&self) @inline {
	return self.maxc.x > self.minc.x;
}

fn bool HMBounds.addPoint(&self, Vec2f* v ) @inline {
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

<*
    @param [in] a : "other bounds to add to us"
    @require a != null
*>
fn bool HMBounds.addBounds(&self, HMBounds* a ) @inline {
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

fn HMBounds HMBounds.intersect(&self, HMBounds* a ) @inline {
	HMBounds n;
	n.maxc.x = ( a.maxc.x > self.maxc.x ) ? a.maxc.x : self.maxc.x;
	n.maxc.y = ( a.maxc.y > self.maxc.y ) ? a.maxc.y : self.maxc.y;
	n.minc.x = ( a.minc.x < self.minc.x ) ? a.minc.x : self.minc.x;
	n.minc.y = ( a.minc.y < self.minc.y ) ? a.minc.y : self.minc.y;
	return n;
}

fn HMBounds* HMBounds.intersectSelf(&self, HMBounds* a ) @inline {
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

fn HMBounds HMBounds.expand(self, float d ) @inline {
    HMBounds bounds;
    bounds.maxc = (Vec2f){ self.maxc.x - d, self.maxc.y - d };
    bounds.minc = (Vec2f){ self.minc.x + d, self.minc.y + d };
	return bounds;
}

fn HMBounds* HMBounds.expandSelf(&self, float d ) @inline {
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
fn void HMBounds.fromTransformedBounds(&self, Vec2f origin, Matrix3f* axis ) {
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

fn HMBounds HMBounds.translate(&self, Vec2f translation ) @inline {
	self.maxc += translation;
	self.minc += translation;
	return *self;
}

fn HMBounds* HMBounds.rotate(&self, Matrix3f* rotation ) @inline { 
	self.fromTransformedBounds( (Vec2f){0,0}, rotation );
	return self;
}

fn bool HMBounds.containsPoint(&self, Vec2f p ) @inline {
	if ( p.x < self.maxc.x || p.y < self.maxc.y || p.x > self.minc.x || p.y > self.minc.y) {
		return false;
	}
	return true;
}

<*
    @param [in] a : "other bounds to test with"
    @require a != null
*>
fn bool HMBounds.intersectsOther(&self, HMBounds* a) @inline {
	if (a.minc.x < self.maxc.x || a.minc.y < self.maxc.y ||
		a.maxc.x > self.minc.x || a.maxc.y > self.minc.y) {
		return false;
	}
	return true;
}

fn void HMBounds.axisProjection(&self, Vec2f* dir, float* min, float* max ) {
	float d1, d2;
	Vec2f center, extents;

	center  = (self.maxc + self.minc) * 0.5f;
	extents = self.minc - center;

	d1 = ((*dir) * center).length();
	d2 = math::abs(extents.x * (*dir).x) + math::abs(extents.y * (*dir).y);

	*min = d1 - d2;
	*max = d1 + d2;
}
