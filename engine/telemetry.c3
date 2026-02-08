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

module engine::telemetry::telem;

import std::io;
import engine::misc;
import thirdparty::raylib5::rl;

const TRACY_ENABLE_ZONE @if($feature(TRACY_ENABLE)) = 1;


/////////////////////////////////////////////////////////////////////
////////////////// region PROFILING /////////////////////////////////
/////////////////////////////////////////////////////////////////////
// todo make this into a internal module?
<*
  @require rl::isWindowReady() == true : "right now window most be initialized for Profiling to work"
*>
macro @profile_zone(String name, $x = ON; @body()) @builtin {
$if $feature(_PROFILE):
    $if $x == ON:
        var start_time = rl::getTime(); // in seconds
        defer
        {
            var current_time = rl::getTime();
            var value        = math::abs(start_time - current_time);
            String report    = string::tformat("Prof Zone-> [%s]\n{\n Func: %s\n Time: %s %s\n}", name, $$FUNC, value, ((float)value >= 1.0f) ? "sec" : "ms");
            io::printfn(report);
            /*@pool() {
                String time_type = "ms";
                if((float)value >= 1.0f) {
                    time_type = "sec";
                }
                io::printfn("Profile Zone -> [%s]\n{\n Func: %s\n Time: %s %s\n}", name, $$FUNC, value, time_type);
            };*/
        }
    $endif
$endif
    @body();
}

// deprected functions
<*
  @require rl::isWindowReady() == true : "right now window most be initialized for Profiling to work"
*>
macro float @start_profile_zone() @builtin @deprecated("Use @profile_zone macro instead") {
    return 0.0f;
/*
$if $feature(PROFILE):
    var ms = (float)rl::getTime() * 1000.0f;
    return ms;
$else
    return 0.0f;
$endif
*/
}

<*
 @require rl::isWindowReady() == true : "right now window most be initialized for Profiling to work"
*>
macro @end_profile_zone(#start_time) @builtin @deprecated("Use @profile_zone macro instead") {
/*
$if $feature(PROFILE):
        var ms    = (float)rl::getTime() * 1000.0f;
        var value = math::abs(math::ceil(#start_time /*in ms*/ - ms));
        bool print_sec = false;
        if(value >= 1000.0f) {
            value = value / 1000.0f;
            print_sec = true;
        }
        //game::gpGame.gameView.pushDebugText("Performance zone:\n [%s] = %s %s", name, value, (print_sec) ? "sec" : "ms");
        io::printfn("Performance zone:\n [%s] = %s %s", $$FUNC, value, (print_sec) ? "sec" : "ms");
$endif
*/
}
// end_region PROFILING //////////////////////////////////////////////////////////////////////////////////////////////////////////////
