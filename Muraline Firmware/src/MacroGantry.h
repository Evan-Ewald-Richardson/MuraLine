#pragma once

#include <Arduino.h>
#include <Kinematics.h>

#include <ManualControl.h>
#include <ShapeInput.h>
#include <ArcInput.h>

#define A_STEP 2 
#define A_DIR 3
#define B_STEP 4
#define B_DIR 5

class MacroGantry
{
    private:

    public:
        /*
            Constructor for the MacroGantry

            All values are integers
        */
        MacroGantry(int maxX, int maxY, int padX, int padY, 
                    int maxPaintSpeed, int minPaintSpeed, int maxMoveSpeed, int maxAccel,
                    int paintPressure);

        /*
            Linear motion from wherever it is to a new position
        */
        void moveTo(double x, double y);

        /*
            Straight line motion from a start and end coordinate
        */
        void moveLineBetween(int xStart, int yStart, int xEnd, int yEnd);

        /*
            Circular arc motion between two points. A radius determines how "flat" the path is
        */
        void moveArc(int xStart, int yStart, int xEnd, int yEnd, int radius);

        /*
            Draws a shape from a pre-made list, specifying the centerpoint

            Square, circle, star, oval, diamond
        */
        void drawShape(String input, int x, int y);

        /*
            Returns the gantry back to origin
        */
        void calibrate();

        /*
            Sets the current position as the origin - use at your own risk!
        */
        void calibrateCurrentPosition();

        
};  