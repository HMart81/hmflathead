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
/* UNFINISHED BACKEND INTERFACE */

module sys::framework::backends::bkend @if($feature(BACKEND_RAYLIB));

import std::io;
import engine::misc;
import engine::filesystem::fs;
import engine::logging::log;
import game::assets::sprt;
import game::main;
import thirdparty::raylib5::rl;

// Backend interface
interface IBackend {
    fn void	initialize() @optional;
    fn void	createWindow(String title, int width, int height);
    fn void setMainMonitor(uint monitor) @optional;
    fn void setTargetFPS(uint fps) @optional;
    fn void setBackGroundColor(Color color) @optional;
    fn void setWindowIcon(Sprite icon) @optional;
    fn void setWindowFlag(uint flag) @optional;
    fn void clearWindowFlag(uint flag) @optional;
    fn void setWindowFlags(int flags) @optional;
    fn void	shutdown();
}

//const BACKEND_NONE   = 0;
//const BACKEND_RAYLIB = 1;
//const BACKEND_RGFW   = 2;

alias WindowHandle = void*;

struct Render (IBackend) 
{
    WindowHandle window;
    uint windowFlags;
    Color bgColor; // background color
}

<*
    @param [&in] rd : "Render context"
*>
macro renderLoop(Render* rd; @body) {
    while (!rl::windowShouldClose()) {
        rl::@drawing() {
            // Clear screen
            rl::clearBackground(rd.bgColor);
            @body;
        };
    }
}

fn void Render.setWindowFlag(&self, uint flag) @dynamic @inline
{
    self.windowFlags |= flag;
}

fn void Render.clearWindowFlag(&self, uint flag) @dynamic @inline
{
    self.windowFlags &= ~flag;
}

fn void Render.setTargetFPS(&self, uint fps) @dynamic
{
    rl::setTargetFPS((int)fps);
}

fn void Render.setMainMonitor(&self, uint monitor_index) @dynamic
{
    rl::setWindowMonitor((int)monitor_index);
}

fn void Render.setBackGroundColor(&self, Color color) @dynamic @inline
{
    self.bgColor = color;
}

fn void Render.initialize(&self) @dynamic
{
    self.setWindowFlag(rl::FLAG_WINDOW_HIGHDPI);
    self.setWindowFlag(rl::FLAG_VSYNC_HINT); // try enabling V-Sync
    self.setWindowFlag(rl::FLAG_MSAA_4X_HINT); // try enabling MSAA 4X
    // set/apply the final window flags
    rl::setConfigFlags(self.windowFlags);
}

fn void Render.createWindow(&self, String title, int width, int height) @dynamic
{
    rl::initWindow(width, height, title.zstr_tcopy());
    self.windowFlags = 0; // reset flags after window creation
}

fn void Render.shutdown() @dynamic
{
    rl::closeWindow();
}

module sys::framework::backends::bkend @if($feature(BACKEND_RGFW));

import std::io;
import game::main;
import engine::misc;
import engine::logging::log;
import engine::filesystem::fs;
import thirdparty::rgfw17::rgfw;

/*
int main() {
	RGFW_window* win = RGFW_createWindow("name", RGFW_RECT(100, 100, 500, 500), (u64)0);

	RGFW_window_setIcon(win, icon, RGFW_AREA(3, 3), 4);

	while (RGFW_window_shouldClose(win) == RGFW_FALSE) {
		while (RGFW_window_checkEvent(win)) {
		    if (win->event.type == RGFW_quit || RGFW_isPressed(win, RGFW_escape))
			    break;
        }

		RGFW_window_swapBuffers(win);

		glClearColor(1, 1, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
	}

	RGFW_window_close(win);
}
*/

// Backend interface
interface IBackend {
    fn void	initialize() @optional;
    fn void	createWindow(String title, int width, int height);
    fn void setWindowIcon(Sprite icon) @optional;
    fn void setGLHint(int hint, int value) @optional;
    fn void	shutdown();
    fn void	pollEvents();
    fn void	swapBuffers();
}

alias WindowHandle = RGFW_window*;

struct Render (IBackend) 
{
    WindowHandle window;
}


fn void Render.initialize(&self) @dynamic
{
    rgfw::init();
}

fn void Render.createWindow(&self, String title, int width, int height) @dynamic
{
    self.window = rgfw::createWindow(title.zstr_tcopy(), rgfw::Rect(100, 100, width, height), (long)0);
}

macro Render.renderLoop(Render* rd; @body) {
    while (rgfw::window_shouldClose(rd.window) == rgfw::FALSE) {
        // Clear screen
        // todo
        //gl::clearColor(1, 1, 1, 1);
        //gl::clear(GL_COLOR_BUFFER_BIT);
        rd.pollEvents();
        @body;
        rd.swapBuffers();
    }
}

fn void Render.shutdown() @dynamic
{
    rgfw::window_close(self.window);
    // or perhaps self.window.close();
}

fn void Render.pollEvents() @dynamic @inline
{
    while (rgfw::window_checkEvent(self.window)) {
        if (self.window.event.type == rgfw::quit) break;
    }
}

fn void Render.swapBuffers() @dynamic
{
    rgfw::window_swapBuffers(self.window);
    // or perhaps self.window.swapBuffers();
}