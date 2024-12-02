#include <Arduino.h>
#include <AccelStepper.h>

#include <MacroGantry.h>
#include <MicroGantry.h>


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
  --------------- Kinematic Constraints --------------- 
  Velocities are measured in **cm/s**
*/
#define MAX_LINEAR_PAINT_VELOCITY 100
#define MIN_LINEAR_PAINT_VELOCITY 10
#define MAX_LINEAR_MOVE_VELOCITY 200
#define MAX_LINEAR_ACCEL 50 // cm/s^2




void setup()
{
  Serial.begin(BAUD);
  AccelStepper stepperA(1, A_STEP, A_DIR); // (Typeof driver: with 2 pins, STEP, DIR)
  AccelStepper stepperB(1, B_STEP, B_DIR); 

  MacroGantry(MAX_X, MAX_Y, PADDING_X, PADDING_Y, 
              MAX_LINEAR_PAINT_VELOCITY, MIN_LINEAR_PAINT_VELOCITY, MAX_LINEAR_MOVE_VELOCITY, MAX_LINEAR_ACCEL, 
              PAINT_ACTUATION_PRESSURE);

}

void loop()
{
  if(DEBUG)
    if(millis() % 500 == 0)
      Serial.println("Hello");
}

