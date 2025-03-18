/*******************************************************************************************
*
*   LayoutName v1.0.0 - Tool Description
*
*   LICENSE: Propietary License
*
*   Copyright (c) 2022 raylib technologies. All Rights Reserved.
*
*   Unauthorized copying of this file, via any medium is strictly prohibited
*   This project is proprietary and confidential unless the owner allows
*   usage in any other form by expresely written permission.
*
**********************************************************************************************/

#include "raylib.h"

#define RAYGUI_IMPLEMENTATION
#include "raygui.h"

//----------------------------------------------------------------------------------
// Controls Functions Declaration
//----------------------------------------------------------------------------------


//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
int main()
{
    // Initialization
    //---------------------------------------------------------------------------------------
    int screenWidth = 800;
    int screenHeight = 450;

    InitWindow(screenWidth, screenHeight, "layout_name");

    // layout_name: controls initialization
    //----------------------------------------------------------------------------------
    // Define controls variables
    bool consoleBodyActive = true;            // WindowBox: consoleBody
    bool line1EditMode = false;
    char line1Text[128] = "SAMPLE TEXT";            // TextBox: line1
    bool line2EditMode = false;
    char line2Text[128] = "SAMPLE TEXT";            // TextBox: line2
    bool line3EditMode = false;
    char line3Text[128] = "SAMPLE TEXT";            // TextBox: line3
    bool line4EditMode = false;
    char line4Text[128] = "SAMPLE TEXT";            // TextBox: line4
    bool line5EditMode = false;
    char line5Text[128] = "SAMPLE TEXT";            // TextBox: line5
    bool line6EditMode = false;
    char line6Text[128] = "SAMPLE TEXT";            // TextBox: line6
    bool line7EditMode = false;
    char line7Text[128] = "SAMPLE TEXT";            // TextBox: line7
    bool line8EditMode = false;
    char line8Text[128] = "SAMPLE TEXT";            // TextBox: line8
    bool line9EditMode = false;
    char line9Text[128] = "SAMPLE TEXT";            // TextBox: line9
    bool line10EditMode = false;
    char line10Text[128] = "SAMPLE TEXT";            // TextBox: line10
    bool line11EditMode = false;
    char line11Text[128] = "SAMPLE TEXT";            // TextBox: line11
    bool line12EditMode = false;
    char line12Text[128] = "SAMPLE TEXT";            // TextBox: line12

    // Define controls rectangles
    Rectangle layoutRecs[14] = {
        (Rectangle){ 0, 0, 360, 360 },    // WindowBox: consoleBody
        (Rectangle){ 24, 48, 312, 24 },    // TextBox: line1
        (Rectangle){ 24, 72, 312, 24 },    // TextBox: line2
        (Rectangle){ 24, 96, 312, 24 },    // TextBox: line3
        (Rectangle){ 24, 120, 312, 24 },    // TextBox: line4
        (Rectangle){ 24, 144, 312, 24 },    // TextBox: line5
        (Rectangle){ 24, 168, 312, 24 },    // TextBox: line6
        (Rectangle){ 24, 192, 312, 24 },    // TextBox: line7
        (Rectangle){ 24, 216, 312, 24 },    // TextBox: line8
        (Rectangle){ 24, 240, 312, 24 },    // TextBox: line9
        (Rectangle){ 24, 264, 312, 24 },    // TextBox: line10
        (Rectangle){ 24, 288, 312, 24 },    // TextBox: line11
        (Rectangle){ 24, 312, 312, 24 },    // TextBox: line12
        (Rectangle){ 24, 48, 312, 288 },    // GroupBox: GroupBox015
    };
    //----------------------------------------------------------------------------------

    SetTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!WindowShouldClose())    // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Implement required update logic
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        BeginDrawing();

            ClearBackground(GetColor(GuiGetStyle(DEFAULT, BACKGROUND_COLOR))); 

            // raygui: controls drawing
            //----------------------------------------------------------------------------------
            // Draw controls
            if (consoleBodyActive)
            {
                consoleBodyActive = !GuiWindowBox(layoutRecs[0], "Init Console");
                if (GuiTextBox(layoutRecs[1], line1Text, 128, line1EditMode)) line1EditMode = !line1EditMode;
                if (GuiTextBox(layoutRecs[2], line2Text, 128, line2EditMode)) line2EditMode = !line2EditMode;
                if (GuiTextBox(layoutRecs[3], line3Text, 128, line3EditMode)) line3EditMode = !line3EditMode;
                if (GuiTextBox(layoutRecs[4], line4Text, 128, line4EditMode)) line4EditMode = !line4EditMode;
                if (GuiTextBox(layoutRecs[5], line5Text, 128, line5EditMode)) line5EditMode = !line5EditMode;
                if (GuiTextBox(layoutRecs[6], line6Text, 128, line6EditMode)) line6EditMode = !line6EditMode;
                if (GuiTextBox(layoutRecs[7], line7Text, 128, line7EditMode)) line7EditMode = !line7EditMode;
                if (GuiTextBox(layoutRecs[8], line8Text, 128, line8EditMode)) line8EditMode = !line8EditMode;
                if (GuiTextBox(layoutRecs[9], line9Text, 128, line9EditMode)) line9EditMode = !line9EditMode;
                if (GuiTextBox(layoutRecs[10], line10Text, 128, line10EditMode)) line10EditMode = !line10EditMode;
                if (GuiTextBox(layoutRecs[11], line11Text, 128, line11EditMode)) line11EditMode = !line11EditMode;
                if (GuiTextBox(layoutRecs[12], line12Text, 128, line12EditMode)) line12EditMode = !line12EditMode;
            }
            GuiGroupBox(layoutRecs[13], "DATA");
            //----------------------------------------------------------------------------------

        EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    CloseWindow();        // Close window and OpenGL context
    //--------------------------------------------------------------------------------------

    return 0;
}

//------------------------------------------------------------------------------------
// Controls Functions Definitions (local)
//------------------------------------------------------------------------------------

