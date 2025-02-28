REM ***************************************************************
REM		echo - to print text
REM		@echo off - disables text printing
REM 	start - run a file with its default application
REM 		/d - directory where to look for the file
REM		REM - comment out lines of code
REM		mkdir/rmdir - create/remove directories
REM 	del - delete files (on window) 
REM 	rm  - delete files (unix)
REM 	copy - copy any files
REM 	xcopy - same as above but with extra options
REM 		/m specifies that only updated files will be copied, 
REM 		/e specifies that all subdirectories in the listed directory will be copied
REM 		/y keeps the confirmation message appearing every time a file is overwritten.
REM 	for/in/do - lets you specify files
REM 		@ECHO OFF 
REM			REM This is the location of the files that you want to sort
REM			cd c:\source
REM			REM This moves any files with a .doc or .txt extension from c:\source to c:\text
REM			REM %%f is a variable
REM			FOR %%f IN (*.doc *.txt) DO XCOPY c:\source\"%%f" c:\text /m /y
REM			REM This moves any files with a .jpg, .png, or .bmp extension from c:\source to c:\images
REM			FOR %%f IN (*.jpg *.png *.bmp) DO XCOPY C:\source\"%%f" c:\images /m /y
REM 	title -  edit cmd window title
REM 	COLOR bf - You can change the color of the output where b is the background and f is the foreground 
REM 			   color, both a hexadecimal number. Following colors are possible:
REM 							-------------------------------------------------
REM 							* Number *      Color      * Number *   Color   *
REM 							-------------------------------------------------
REM 							*   0	*    black         *    8   * dark grey *
REM 							*   1	*   dark blue      *    9   *   blue    *
REM 							*   2	*   dark green     *    a   *   green   *
REM 							*   3	*   dark turquoise *    b   * turquoise *
REM 							*   4	*   dark red       *    c   *    red    *
REM 							*   5	*   dark magenta   *    d   *  magenta  *
REM 							*   6	*   dark yellow    *    e   *  yellow   *
REM 							*   7	*   light grey     *    f   *   white   *
REM 							-------------------------------------------------
REM
REM **************************************************************************************************************



@echo off
REM start /d "D:\Downloads\cmder_mini" Cmder.exe /start w:\Projects_C3\test_dev
REM set path=w:\Projects_C3\test_dev;%path%
start /d "w:\Projects_C3\test_dev" editLauncher.bat
exit /B 0