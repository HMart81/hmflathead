**hmflathead is a simple 2D game engine made using Raylib and C3 language.**

`hmflathead` IS NOT in a finished state nor a complete 2D game engine, **not really recomended for use** for now. 

`hmflathead` Is my first, from scratch, custom game engine ever, so expect some questionable design choices, but I did take inspiration from other engines/frameworks, so it is not entirely arbitrary.

`hmflathead` is intended for **education**; it can be used to create simple 2D games but most things will have to be implemented by you **there's no dedicated tools**.

<br>

**WARNING: The game code is not entirely in a compilable/runnable state, because I add to remove the game data.**

# features

 ## Engine
 - Rendering, sound and input using Raylib functions, theres a input action system inspired by HPL1 engine from FG.
 - Supports some command line arguments (cvars)
    + developer (enables developer mode, for now only turns on/off some code lines)
    + r_mode (sets screen resolution index)
    + r_showFPS
    + r_noSplashPic (disables the small splash image at game start)
    + r_fullscreen (screen mode 0 = window, 1 = borderless, 2 = dedicated, -1 = ini file setting)
    + ui_debugDraw (show debug visualization for gui development) **not fully implemented**
    + fs_base ( sets name for default base folder, for the game data, right now is called `base`)
    + more...
 - **Complex Immediate-mode gui system, using raygui** mostly recomended for tools.
 - XML file reading (using a third party C3 simple xml parser).
 - Very basic INI file parsing.
 - A simple Tokanizer to make it easy to parse custom files.
 - Very simple Boids system (simulates schools of birds, fix, etc).
 - Support for both Wren (OOP) scripting language and Mujs javascript.
 ## Game
 - Ability to create simple game menus using **Basic Custom Retained-Mode GUI system**
 - Import fonts, textures, sounds and music inside the game base folder, at game loading time.
 - Entity System inspired by engines like idTech4 and Source Engine (no component system).
 - Material files definition and data base, using xml syntax (still WIP)

## compiling

`hmflathead` is written using the C3 programming language, so you need the C3 compiler;  go to (https://c3-lang.org/) and setup it for your OS of choice.
             To make things easy to compile, make the c3c.exe compiler globally accessible to all users, by putting it in the OS path.
             
## building

   - For debug exe in a console write 
`make debug(dmain)`

   - For release exe in a console write 
`make release(main)`

Open **makefile** in the main folder to see how the project is set up. I recommend reading about Makefile syntax and rules before
changing things inside.  
There's also a very simple and basic C3 language highlight for Notepad++ in there as well (maybe out of date for more modern C3 versions).

  
## license

# hmflathead GPL Source Code
Copyright (C) 2025 Hilario Martins.
