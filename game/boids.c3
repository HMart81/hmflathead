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

module game::effects::boid @if($defined(BOIDS_ENABLE));

// region modules
import std::core::mem::allocator; // arena allocator
import std::collections::list;
import std::io;
import std::math;
import std::sort;
import std::time;
import game::main;
import engine::misc;
import game::assets::sprt;
import game::serialize::svs; // save system
import thirdparty::raylib5::rl;
// end_region

const float VISUAL_RANGE                = 100;
const float COHERENCE_FACTOR            = 0.005;
const float OVERCROWDING_FACTOR         = 0.05;
const int   OVERCROWDING_HIGH_THRESHOLD = 200;
const int   OVERCROWDING_LOW_THRESHOLD  = 100;
const float MATCHING_FACTOR             = 0.05;
const float AVOID_FACTOR                = 0.05;
const float MIN_DISTANCE                = 20;
const float MAX_SPEED                   = 200;
const float TURN_FACTOR                 = 1;
const int   MARGIN                      = 50;

struct Boid (SaveSystemInterface) {
	//inline Sprite sprt; TODO make voids extend sprite
	
    int id;
    Vec2f position;
    Vec2f velocity;
    int neighbours;
    bool overcrowded;
}

fn void Boid.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void Boid.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn float Boid.distance_to(self, Boid* boid) @inline {
    float dx = self.position.x - boid.position.x;
    float dy = self.position.y - boid.position.y;
    return math::sqrt((dx*dx)+(dy*dy));
}

/*
ArenaAllocator arena;
const usz ARENA_SIZE = 256 * 1024;
char* data = malloc(ARENA_SIZE)
arena.init(data[:ARENA_SIZE]);
defer {
  allocator::free(&allocator::LIBC_ALLOCATOR, arg);
  allocator::destroy_temp_allocators();
  free(data);
}
*/
struct BoidManager (SaveSystemInterface) {
    List{Boid} boids;
	ArenaAllocator mem_arena;
	char* arena_bytes;
    random::SimpleRandom rand;
    int max_boids;
    int next_id;
	bool paused;
	bool boids_visible;
    bool fade_lines;
}

fn void BoidManager.save(&self, SaveFile* file) @dynamic {
// todo
}

fn void BoidManager.reload(&self, SaveFile* file) @dynamic {
// todo
}

fn void BoidManager.init(&self) {
    self.max_boids   = 1000;
	int mem_count    = 256 * 1024;
	self.arena_bytes = mem::malloc(mem_count);
	// init the memory arena
	self.mem_arena.init(self.arena_bytes[:mem_count]);
    self.boids.init(&self.mem_arena, self.max_boids);
    random::seed_entropy(&self.rand);
}

fn void BoidManager.release(&self) {
	free(self.arena_bytes);
	if(self.boids.len()) self.boids.free();
}

fn void BoidManager.handle_key_events(&self, int screen_width,  int screen_height) {
    // add boid!
    if (rl::isKeyDown(rl::KEY_KP_ADD) && self.boids.len() < self.max_boids) {
        Boid boid;
        boid.position.x = random::next_float(&self.rand) * screen_width;
        boid.position.y = random::next_float(&self.rand) * screen_height;
        boid.velocity.x = (random::next_float(&self.rand) - 0.5) * MAX_SPEED;
        boid.velocity.y = (random::next_float(&self.rand) - 0.5) * MAX_SPEED;
        boid.id = self.next_id += 1;
        self.boids.push(boid);
        self.boids_visible = true;
    }
    
    // kill boid! die!!!!!!!!!!
    if (rl::isKeyDown(rl::KEY_KP_SUBTRACT) && self.boids.len() > 0) {
        (void)self.boids.pop();
        if(self.boids.len() == 0) self.boids_visible = false;
    }
    
    if (rl::isKeyDown(rl::KEY_SPACE)) {
       if(!self.fade_lines) {
           self.fade_lines = true;
       } else {
           self.fade_lines = false;
       }
    }
}

fn void BoidManager.move_boids(&self, int screen_width,  int screen_height, float dt) {
    // move boids!
    foreach (&boid : self.boids) 
	{
        boid.neighbours = 0;
        float avg_x, avg_y;
        float avg_dx, avg_dy;
        float avoid_dx, avoid_dy;
        foreach (i, &other_boid : self.boids) {
            if (boid.id == other_boid.id) { continue; }
            if (boid.distance_to(other_boid) <= VISUAL_RANGE) {
                avg_x += other_boid.position.x;
                avg_y += other_boid.position.y;
                avg_dx += other_boid.velocity.x;
                avg_dy += other_boid.velocity.y;
                boid.neighbours += 1;
            }

            if (boid.distance_to(other_boid) < MIN_DISTANCE) {
                avoid_dx += boid.position.x - other_boid.position.x;
                avoid_dy += boid.position.y - other_boid.position.y;
            }
        }

        if (boid.neighbours > OVERCROWDING_HIGH_THRESHOLD) {
            boid.overcrowded = true;
        } else if (boid.neighbours < OVERCROWDING_LOW_THRESHOLD) {
            boid.overcrowded = false;
        }

        if (boid.neighbours > 0) {
            avg_x /= boid.neighbours;
            avg_y /= boid.neighbours;

            if (boid.overcrowded) {
                // escape flock if it's too big.
                boid.velocity.x -= (avg_x - boid.position.x) * OVERCROWDING_FACTOR;
                boid.velocity.y -= (avg_y - boid.position.y) * OVERCROWDING_FACTOR;
            } else {
                // move toward the center of flock.
                boid.velocity.x += (avg_x - boid.position.x) * COHERENCE_FACTOR;
                boid.velocity.y += (avg_y - boid.position.y) * COHERENCE_FACTOR;

                // match velocity of neighbours.
                avg_dx /= boid.neighbours;
                avg_dy /= boid.neighbours;
                boid.velocity.x += (avg_dx - boid.velocity.x) * MATCHING_FACTOR;
                boid.velocity.y += (avg_dy - boid.velocity.y) * MATCHING_FACTOR;
            }
        }

        // avoid getting too close to others.
        boid.velocity.x += avoid_dx * AVOID_FACTOR;
        boid.velocity.y += avoid_dy * AVOID_FACTOR;

        // abide by the speed limit like good law abiding boids.
        float speed = math::sqrt((boid.velocity.x*boid.velocity.x)+(boid.velocity.y*boid.velocity.y));
        if (speed > MAX_SPEED) {
            boid.velocity.x = (boid.velocity.x / speed) * MAX_SPEED;
            boid.velocity.y = (boid.velocity.y / speed) * MAX_SPEED;
        }

        // keep within screen bounds.
        if (boid.position.x < MARGIN) { boid.velocity.x += TURN_FACTOR; }
        if (boid.position.y < MARGIN) { boid.velocity.y += TURN_FACTOR; }
        if (boid.position.x > ((float)screen_width - MARGIN)) { boid.velocity.x -= TURN_FACTOR; }
        if (boid.position.y > ((float)screen_height - MARGIN)) { boid.velocity.y -= TURN_FACTOR; }

        // bounce off edge of screen.
        if (boid.position.x < 0) {
            boid.position.x = -boid.position.x;
            boid.velocity.x = -boid.velocity.x;
        }
        if (boid.position.x > screen_width) {
            boid.position.x = screen_width - (boid.position.x - screen_width);
            boid.velocity.x = -boid.velocity.x;
        }
        if (boid.position.y < 0) {
            boid.position.y = -boid.position.y;
            boid.velocity.y = -boid.velocity.y;
        }
        if (boid.position.y > screen_height) {
            boid.position.y = screen_height - (boid.position.y - screen_height);
            boid.velocity.y = -boid.velocity.y;
        }

        // apply velocity.
        boid.position.x += dt * boid.velocity.x;
        boid.position.y += dt * boid.velocity.y;
    }
}

fn void BoidManager.update(&self, int screen_width,  int screen_height, float dt) {
	if(self.paused || self.boids_visible == false) return;
	
	mem::@scoped(&self.mem_arena) 
	{
        self.handle_key_events(screen_width,  screen_height,);
        self.move_boids(screen_width,  screen_height, dt);
        self.draw();
	};
}

fn void BoidManager.draw_fade_lines(&self, int lines) {
    foreach (boid : self.boids) {
        foreach (other_boid : self.boids) {
            if (boid.id == other_boid.id) { continue; }
            float distance = boid.distance_to(&other_boid);
            if (distance <= VISUAL_RANGE) {
                float opacity = (VISUAL_RANGE - distance) / VISUAL_RANGE;
                rl::drawLineEx(boid.position.toVector2(), other_boid.position.toVector2(), 1, {102, 191, 255, (char)(255*opacity)});
                lines++;
            }
        }
    }
}

fn void BoidManager.draw(&self) {
    int lines;
    if(self.fade_lines) self.draw_fade_lines(lines);
    
    foreach (boid : self.boids) {
        rl::Color color;
        switch {
        case boid.overcrowded:
            color = rl::RED;
        case boid.neighbours == 0:
            color = rl::BLACK;
        case boid.neighbours > 0:
            color = rl::BLUE;
        }

        rl::drawLineEx(boid.position.toVector2(), boid.position.add(boid.velocity.div_n(10)).toVector2(), 4, color);
        rl::drawCircleV(boid.position.toVector2(), 4, color);
        lines++;
    }

    DString msg;
    msg.appendf("Boids = [\n\tn=%d\n\tlines=%d\n]\n", self.boids.len(), lines);
    rl::drawText(msg.zstr_view(), 20, 20, 20, rl::RAYWHITE);
}

fn void BoidManager.pause(&self) @inline {
	self.paused = true;
}

fn void BoidManager.resume(&self) @inline {
	self.paused = false;
}

fn Vec2f Vec2f.add(self, Vec2f v) @local @inline { return {self.x+v.x, self.y+v.y}; }

fn Vec2f Vec2f.div_n(self, float n) @local @inline { return {self.x/n, self.y/n}; }
