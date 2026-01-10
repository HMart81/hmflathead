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

module engine::sys::framework::backends::bkend @if($feature(BACKEND_RAYLIB));

import std::io, std::os::win32;
import engine::misc;
import engine::filesystem::fs;
import engine::logging::log;
import game::assets::sprite;
import game::main;
import thirdparty::raylib5::rl;

faultdef WINDOW_CREATION_FAILED, 
         FAILED_TO_GET_WINDOW_HANDLE;

// Backend interface
interface IBackend {
    fn void	initialize() @optional;
    fn WindowHandle? createWindow(String title, int width, int height, RLConfigFlag flags);
    fn void setMainMonitor(uint monitor) @optional;
    fn int  getMonitorPhysicalWidth(uint monitor) @optional;
    fn int  getMonitorPhysicalHeight(uint monitor) @optional;
    fn Vec2f getMonitorPosition(uint monitor) @optional;
    fn int getMonitorRefreshRate(uint monitor) @optional;
    fn bool isWindowFocused() @optional;
    fn void setTargetFPS(uint fps) @optional;
    fn void setBackGroundColor(RLColor color) @optional;
    fn void setWindowIcon(HMSprite icon) @optional;
    fn void	shutdown();
}

//const BACKEND_NONE   = 0;
//const BACKEND_RAYLIB = 1;
//const BACKEND_RGFW   = 2;

alias WindowHandle @if(!env::WIN32) = void*; // on non-Windows
alias WindowHandle @if(env::WIN32) = Win32_HWND; // on Windows

struct BackendRender (IBackend) 
{
    WindowHandle window; // right now is just a place for a window handle
}

// Custom window flag manipulation this is done BEFORE window creation
// to do flag changes AFTER window creation, 
// use raylib functions setWindowState() and clearWindowState() directly
fn void setWindowFlag(RLConfigFlag* windowFlags, RLConfigFlag flag) @inline
{
    (*windowFlags) |= flag;
}

fn void clearWindowFlag(RLConfigFlag* windowFlags, RLConfigFlag flag) @inline
{
    (*windowFlags) &= ~flag;
}
//

<*
    @param [&in] rd : "BackendRender context"
*>
macro @renderLoop(BackendRender* rd; @body) {
    while (!rl::windowShouldClose()) {
        //rl::@drawing() {
            // Clear screen
            //rl::clearBackground(rd.bgColor);
            @body;
        //};
    }
}

fn void BackendRender.setTargetFPS(&self, uint fps) @dynamic
{
    rl::setTargetFPS((int)fps);
}

fn void BackendRender.setMainMonitor(&self, uint monitor_index) @dynamic
{
    rl::setWindowMonitor((int)monitor_index);
}

fn int BackendRender.getMonitorPhysicalWidth(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorPhysicalWidth((int)monitor_index);
}

fn int BackendRender.getMonitorPhysicalHeight(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorPhysicalHeight((int)monitor_index);
}

fn Vec2f BackendRender.getMonitorPosition(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorPosition((int)monitor_index);
}

fn int BackendRender.getMonitorRefreshRate(&self, uint monitor_index) @dynamic
{
    return rl::getMonitorRefreshRate((int)monitor_index);
}

fn bool BackendRender.isWindowFocused(&self) @dynamic
{
    return rl::isWindowFocused();
}

fn void BackendRender.setBackGroundColor(&self, RLColor color) @dynamic @inline
{
    rl::clearBackground(color);
}

fn void BackendRender.setWindowIcon(&self, HMSprite icon) @dynamic
{
    RLTexture2D* texture = icon.getTexture();
    if(texture == null) return;

    RLImage img = rl::loadImageFromTexture(*texture);
    rl::setWindowIcon(img);
    rl::unloadImage(img);
}

/*fn void BackendRender.initialize(&self) @dynamic
{
    setWindowFlag(rl::FLAG_WINDOW_HIGHDPI);
    setWindowFlag(rl::FLAG_VSYNC_HINT); // try enabling V-Sync
    setWindowFlag(rl::FLAG_MSAA_4X_HINT); // try enabling MSAA 4X
}*/

fn WindowHandle? BackendRender.createWindow(&self, String title, int width, int height, RLConfigFlag flags) @dynamic
{
    if(flags) rl::setConfigFlags(flags);

    rl::initWindow(width, height, title.zstr_tcopy());
    if(!rl::isWindowReady()) return WINDOW_CREATION_FAILED?;

    self.window = rl::getWindowHandle();
    if(self.window) { return self.window; } else { return FAILED_TO_GET_WINDOW_HANDLE?; }
}

fn void BackendRender.shutdown(&self) @dynamic
{
    rl::closeWindow();
    if(self.window != null) self.window = null;
}

module engine::sys::framework::backends::bkend @if($feature(BACKEND_RGFW));

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

struct BackendRender (IBackend) 
{
    WindowHandle window;
}


fn void BackendRender.initialize(&self) @dynamic
{
    rgfw::init();
}

fn void BackendRender.createWindow(&self, String title, int width, int height) @dynamic
{
    self.window = rgfw::createWindow(title.zstr_tcopy(), rgfw::Rect(100, 100, width, height), (long)0);
}

macro BackendRender.renderLoop(BackendRender* rd; @body) {
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

fn void BackendRender.shutdown() @dynamic
{
    rgfw::window_close(self.window);
    // or perhaps self.window.close();
}

fn void BackendRender.pollEvents() @dynamic @inline
{
    while (rgfw::window_checkEvent(self.window)) {
        if (self.window.event.type == rgfw::quit) break;
    }
}

fn void BackendRender.swapBuffers() @dynamic
{
    rgfw::window_swapBuffers(self.window);
    // or perhaps self.window.swapBuffers();
}