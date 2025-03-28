######## LICENSE ################################
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
##########################################################################################

################################# MAKE LANGUAGE DOC #####################################
#
# Simple assignment :=
# A simple assignment expression is evaluated only once, at the very first occurrence (when is defined). 
# For example, if CC := ${GCC} ${FLAGS} during the first encounter is evaluated to gcc -W 
# then each time ${CC} occurs, it will be replaced with gcc -W.
#
# Recursive assignment =
# A Recursive assignment expression is evaluated everytime the variable is encountered in the code. 
# For example, a statement like CC = ${GCC} {FLAGS} will be evaluated only 
# when an action like ${CC} file.c is executed. 
# However, if the variable GCC is reassigned, GCC = c++, 
# then from now on ${CC} will be converted to, c++ -W, after the reassignment.
#
#######################################################################################################
#                       !!WARNING!! 
# make will not work with space based "tab" it requires real tab
# Wildcards require unix style forward slash's '/'.
# Also do not use wildcards directly on the rules itself,
# always use them through a variable, aparantly they don't always work as expected when used on a rule.
# Make sure there's no space after all '\' in ENGINE_CHILD_SOURCES :=
#######################################################################################################
#########################################################################################

$(info $(SHELL))

## Project name (exe name)
APPLICATION_RELEASE_NAME := main
APPLICATION_DEBUG_NAME := dmain
##

## Build directory
BUILD_DIR := build
BUILD_PATH := ${CURDIR}/$(BUILD_DIR)
##

## Third party libraries
RAYLIB := raylib55\lib\raylibdll.lib
BOX2D := box2d\box2d.lib
RAYGUI := raygui\raygui.obj
LIBRARY_ROOT_PATH := .\thirdparty\include\libs\\
LINKER_SEARCH_PATHS := -L $(LIBRARY_ROOT_PATH)
LINKED_LIBRARIES := -l $(RAYLIB) -l $(BOX2D) -l kernel32.lib -z $(RAYGUI)
##

## Windows stuff
MSVC_SDK_PATH := windows\kit\8.1\Lib\winv6.3\um\x64
FULL_MSVC_SDK_PATH := $(LIBRARY_ROOT_PATH)$(MSVC_SDK_PATH)
KERNEL32_LIB := $(MSVC_SDK_PATH)\kernel32.lib
USER32_LIB := $(MSVC_SDK_PATH)\user32.lib
##


############################## Source code  #####################################
ENGINE_FOLDER := engine/
GAME_FOLDER   := game/
ENGINE_ROOT_SOURCES := $(wildcard $(ENGINE_FOLDER)*.c3 $(ENGINE_FOLDER)*.c3i)
GAME_ROOT_SOURCES := $(wildcard $(GAME_FOLDER)*.c3)
ENGINE_CHILD_SOURCES := \
	$(ENGINE_FOLDER)$(wildcard containers/*.c3 containers/*.c3i) \
	$(ENGINE_FOLDER)$(wildcard thirdparty/*.c3 thirdparty/*.c3i) \
	$(ENGINE_FOLDER)$(wildcard xml/*.c3 xml/*.c3i)
#################################################################################

OBJS_TO_CLEAN := $(wildcard $(BUILD_PATH)/temp/*.obj)
LIBS_TO_CLEAN := $(wildcard $(BUILD_PATH)/*.lib)
PDBS_TO_CLEAN := $(wildcard $(BUILD_PATH)/*.pdb)
EXES_TO_CLEAN := $(wildcard $(BUILD_PATH)/*.exe)

# arguments to set at game start
GAME_ARGUMENTS := +developer +g_log +r_mode 9

# in c3 you need to use $feature(_DEBUG) to check for this defines, C3 $define doesn't work for this...
DEBUG_DEFINES   := -D _DEBUG -D _PROFILE
#-D _PROFILE
# current release defines aren't really usefull... 
RELEASE_DEFINES := -D _RELEASE

# compiler to use, right now there's only one, c3c
CC := c3c.exe

# common compiler flags/options
CFLAGS := --target windows-x64 --threads 8 --output-dir $(BUILD_PATH)

# release
comand_release_compile := $(CC) -O3 $(CFLAGS) $(RELEASE_DEFINES) $(LINKER_SEARCH_PATHS) $(LINKED_LIBRARIES) -o $(APPLICATION_RELEASE_NAME) compile $(GAME_ROOT_SOURCES) $(ENGINE_ROOT_SOURCES) $(ENGINE_CHILD_SOURCES)
# debug
comand_debug_compile := $(CC) -O0 $(CFLAGS) $(DEBUG_DEFINES) $(LINKER_SEARCH_PATHS) $(LINKED_LIBRARIES) -o $(APPLICATION_DEBUG_NAME) compile $(GAME_ROOT_SOURCES) $(ENGINE_ROOT_SOURCES) $(ENGINE_CHILD_SOURCES)
#
comand_release_run := cd ${CURDIR}/build/ & start $(APPLICATION_RELEASE_NAME).exe $(GAME_ARGUMENTS)
comand_debug_run := cd ${CURDIR}/build/ & start $(APPLICATION_DEBUG_NAME).exe $(GAME_ARGUMENTS)

################################### LOGGING #########################################################
# uncoment one of them in case you need error log, warning or just info log, 
# to see what comand was run.

#$(error   $(comand_release_compile) )
#$(error   $(comand_debug_compile) )
#$(warning cmd is $(comand_release_compile) )
#$(warning cmd is $(comand_debug_compile) )
#$(info    cmd is $(comand_release_compile) )
#$(info    cmd is $(comand_debug_compile) )
#####################################################################################################

################################### NOTE ############################################################
#######  rules work like this:
# 
#     target (exe, dll, lib, etc) : depends on this files (if they change recompile)
#	  		and calls this cmd
######
# the "all" rule is required to force rules "buildtype(name)" to be the only rules that run
# when calling "make" with no parameters in the console, otherwise make will run the rules automatically 
# from top to bottom and so, run clean rule first and it will break everything, if there's nothing to clean 
# at clean time, if that happens make will error out and stop, and no other rules will be done.
# Right now you need to explicitly run the clean rule in the console by doing "make clean".
####################################################################################################

#################################### RULES ###################################################

# rule run when inputing "make" alone in the console
all: release($(APPLICATION_RELEASE_NAME)) debug($(APPLICATION_DEBUG_NAME))

clean: func_clean

func_clean:
	cmd /c clean.sh
 
# main rule to make the executable
release($(APPLICATION_RELEASE_NAME)) : $(GAME_ROOT_SOURCES) $(ENGINE_ROOT_SOURCES) $(ENGINE_CHILD_SOURCES)
	$(info   work_dir ${CURDIR} )
	$(comand_release_compile)
	$(comand_release_run)

debug($(APPLICATION_DEBUG_NAME)) : $(GAME_ROOT_SOURCES) $(ENGINE_ROOT_SOURCES) $(ENGINE_CHILD_SOURCES)
	$(info   work_dir ${CURDIR} )
	$(comand_debug_compile)
	$(comand_debug_run)

################################## END RULES ################################################
