#include <Arduino.h>
#include <AccelStepper.h>

// #include <MacroGantry.h>
// #include <MicroGantry.h>


// Global Definitions
#define DEBUG 1
#define BAUD  9600

#define START 1
#define STOP 0
#define TRUE 1
#define FALSE 0

/*
  --------------- Geometric Constraints --------------- 

  Distances are defined in **centimetres**

  The "max" values are the absolute maximum dimensions of the canvas, not necessarily the usable dimensions.
  The usable dimensions are a calculated value with the "max" and "padding" values
*/ 
#define MAX_X 300
#define MAX_Y 300
// To be used for distance-from-wall offset
#define MAX_Z 3
// How far from the wall edge the spray can realistically reach
#define PADDING_X 10
#define PADDING_Y 30
#define PAINT_ACTUATION_PRESSURE 2 // how much pressure to press down on the paint can, determined by stepper distance 

/*
  --------------- Kinematic Definitions --------------- 
  Velocities are measured in **cm/s**
*/
#define MAX_LINEAR_PAINT_VELOCITY 100
#define MIN_LINEAR_PAINT_VELOCITY 10
#define MAX_LINEAR_MOVE_VELOCITY 200
#define MAX_LINEAR_ACCEL 50 // cm/s^2
// this is the calibration value for kinematics. This must be calculated with the system.
#define STEPS_CM 100

/*
  --------------- Pin Assignments ---------------
*/
#define A_STEP 2 
#define A_DIR 3
#define B_STEP 4
#define B_DIR 5

/*

  --------------- Global Variables ---------------

*/
// double stepA = 0;
// double stepB = 0;
double cartesianPosition[] = {0,0};
double stepPositionRequired[] = {0,0}; // stepper A and B required steps
bool newPosition = FALSE; // enable bit for position sequence control

AccelStepper stepperA(1, A_STEP, A_DIR); // (Typeof driver: with 2 pins, STEP, DIR)
AccelStepper stepperB(1, B_STEP, B_DIR); 

void setup()
{
  Serial.begin(BAUD);
  

  // something fancier if we have time
  /*MacroGantry(MAX_X, MAX_Y, PADDING_X, PADDING_Y, 
              MAX_LINEAR_PAINT_VELOCITY, MIN_LINEAR_PAINT_VELOCITY, MAX_LINEAR_MOVE_VELOCITY, MAX_LINEAR_ACCEL, 
              PAINT_ACTUATION_PRESSURE, stepperA, stepperB);*/
}

void loop()
{
  if(DEBUG)
    if(millis() % 500 == 0)
      Serial.println("Hello World");

  // move the motors
  stepperA.run(); // non-blocking, as opposed to runToPosition
  stepperB.run();
}

/*
  Calculates steps required for the position requested, sets the required length of cable to be unspooled.
  This uses conversion factor needs to be calculated through calibration.

  cm distance in the X and Y -> step distances in the X and Y
*/
void positionToSteps(double position[]])
{
  // Do some calculation shit with your grade 10 math
  
  
  // Convert to step position
  stepPositionRequired[0] = position[0]*STEPS_CM;
  stepPositionRequired[1] = position[1]*STEPS_CM;

  newPosition = TRUE;
}

// The functions below should be in MacroGantry.h

/*
    Linear motion from wherever it is to a new position
*/
void moveTo(double x, double y)
{
  double temp[] = {x, y};

  positionToSteps(temp);

  // set the target position, doesn't actually move the motors yet
  stepperA.moveTo(stepPositionRequired[0]);
  stepperB.moveTo(stepPositionRequired[1]);


}

/*
    Straight line motion from a start and end coordinate
*/
void moveLineBetween(double xStart, double yStart, double xEnd, double yEnd)
{

}

/*
    Circular arc motion between two points. A radius determines how "flat" the path is
*/
void moveArc(double xStart, double yStart, double xEnd, double yEnd, double radius)
{

}

/*
    Draws a shape from a pre-made list, specifying the centerpoint

    Square, circle, star, oval, diamond
*/
void drawShape(String input, double x, double y)
{

}

/*
    Returns the gantry back to origin
*/
void calibrate()
{

}

/*
    Sets the current position as the origin - use at your own risk!
*/
void calibrateCurrentPosition()
{

}
