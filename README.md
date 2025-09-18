**hmflathead is a simple 2D game engine made using Raylib and C3 language.**

`hmflathead` IS NOT in a finished state nor a complete 2D game engine, **not really recomended for use**. 

`hmflathead` Is my first, from scratch, custom game engine ever, so expect some questionable design choices, but I did take inspiration from other engines/frameworks, so it is not entirely arbitrary.

`hmflathead` is intended for **education**; it can be used to create simple 2D games but probably many things will have to be implemented by you **there's no dedicated tools**.

<br>

**WARNING: This readme may be out of date in some things, as the code is constantly being worked on. I do try to keep it updated the best I can. Also unfortunatly the game code, is not in a compilable/runnable state, because I add to remove the game data.**

# features

 ## Engine
 - Rendering, sound and input using Raylib functions, theres a input action system inspired by HPL1 engine from FG.
 - Real time Physics provided by Box2D
 - Supports some command line arguments (cvars)
    + developer (enables developer mode, for now only turns on/off some code lines)
    + r_mode (sets screen resolution index)
    + r_showFPS
    + r_unlockFps
    + r_max_fps
    + s_noaudio (disables all game audio)
    + r_noSplashPic (disables the small splash image shown before game start)
    + r_fullscreen (screen mode 0 = window, 1 = borderless, 2 = dedicated, -1 = ini file setting)
    + ui_debugDraw (show debug visualization for gui development) **not fully implemented**
    + ui_editGui (enable ingame gui editing) **not fully implemented**
    + fs_base ( sets name for default base folder, for the game data, right now is called `base`)
    + fs_mod_name (sets the name of the mod for the engine)
    + fs_mod_base (sets the base folder for a modification for the engine to use)
    + more...
 - **Complex Immediate-mode gui system, using raygui or microui** mostly recomended for tools.
 - XML file reading (using a third party C3 simple xml parser).
 - Ability for reading svg files (some data only) from Inkscape, no writting ability for now.
 - Simple INI file reading and writting.
 - A simple Tokanizer to make it easy to parse custom files.
 - Very simple Boids system (simulates schools of birds, fix, etc).
 - Support for Wren (OOP) scripting language, Mujs javascript and LUA scripting.
 ## Game
 - Ability to create simple game menus using **Basic Custom Retained-Mode GUI system**
 - Imports into RAM fonts, textures, sounds and music put inside the game base folder, at game loading time.
 - A entity system based on engines like idTech4 and Source Engine (no entity component system).
 - Human readable material files definition, using xml syntax, (still much work in progress)

## compiling

`hmflathead` is written in C3 programming language, so you need the C3 compiler to use this;  go to (https://c3-lang.org/) and setup it for your OS of choice.
             To make things easy to compile, make the c3c.exe compiler globally accessible to all users, by putting it in the OS path.
             
## building

   - For debug exe in a console write 
`make debug`

   - For release exe in a console write 
`make release`

Open **makefile** in the main folder to see how the project is set up. I recommend reading about Makefile syntax and rules before
changing things inside.  
There's also a very simple and basic C3 language highlight for Notepad++ in there as well (maybe out of date for more modern C3 versions).

  
## license

# hmflathead GPL Source Code
Copyright (C) 2025 Hilario Martins.
