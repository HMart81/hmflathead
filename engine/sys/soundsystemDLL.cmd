@echo off
setlocal enabledelayedexpansion enableextensions
:: c3c dynamic-lib .\engine\misc.c3 .\engine\logger.c3 .\engine\sys\sndsys.c3 .\engine\thirdparty\raylib55.c3i .\game\main.c3 .\engine\assets_api.c3 .\engine\filesys.c3
::
set engine_path=.\engine\
::set EMPTY=""
set C3_LIBS=/ 
.\engine\sys\backends.c3/
.\engine\sys\
set C3I_LIBS=
set FINAL_CMD=
::
:: cd into engine folder and handle files
cd %engine_path%
if exist *.c3i (
    for %%x in (.\*.c3) do set C3_LIBS=!C3_LIBS! %%x
    set C3_LIBS=%C3_LIBS:~1%
    for %%y in (.\*.c3i) do set C3I_LIBS=!C3I_LIBS! %%y
    set C3I_LIBS=%C3I_LIBS:~1%
    set FINAL_CMD=%FINAL_CMD% %C3_LIBS% %C3I_LIBS%
) else (
    for %%x in (.\*.c3) do set C3_LIBS=!C3_LIBS! %%x
    set C3_LIBS=%C3_LIBS:~1%
    set FINAL_CMD=%FINAL_CMD% %C3_LIBS%
)

set /A index=0
for /D %%x in (.\*) do (
    call :search_function %%x , %index%
    set index=%index% + 1
)
::echo Final cmd: %FINAL_CMD%
::if %C3_LIBS% NEQ %EMPTY% (set C3_LIBS=%EMPTY%)
::if %C3I_LIBS% NEQ %EMPTY% (set C3I_LIBS=%EMPTY%)
:: cd into thirdparty
::cd\thirdparty
::call :search_function .\
:: now cd into sys folder
::cd ..\sys
::call :search_function .\
:: now cd into framework
::cd .\framework
::call :search_function .\
:: now cd into xml
::cd .\xml
::for %%x in (.\*.c3) do set C3_LIBS=!C3_LIBS! %%x
::set C3_LIBS=%C3_LIBS:~1%
::set FINAL_CMD=%FINAL_CMD% %C3_LIBS%
::now cd to game folder
cd ..\game
set LIST=
for %%x in (.\*.c3) do set LIST=!LIST! %%x
set LIST=%LIST:~1%
set FINAL_CMD=%FINAL_CMD% %LIST%
::
::
c3c dynamic-lib %FINAL_CMD%

:: this is the function too search within folders
:search_function
if exist *.c3i (
    for %%x in (%~1*.c3) do set C3_LIBS=!LISTA%i%! %%x
    set LISTA%i%=%LISTA%i%:~1%
    for %%y in (%~1*.c3i) do set LISTB%i%=!LISTB%i%! %%y
    set LISTB%i%=%LISTB%i%:~1%
    set FINAL_CMD=%FINAL_CMD% %LISTA%i%% %LISTB%i%%
) else (
    set X= %L%%i%
    for %%x in (%~1*.c3) do set X=!X! %%x
    set X=%X:~1%
    set FINAL_CMD=%FINAL_CMD% %X%
    echo %X%
    echo %FINAL_CMD%
    goto stop
)
echo func run
EXIT /B %ERRORLEVEL%
:: end of search_function

:stop
pause 
