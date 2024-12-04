// #include <AccelStepper.h>

//     // define the pins
// byte stepPinX = 12;
// byte  dirPinX = 11;

// byte stepPinY = 8;
// byte  dirPinY = 7;

// // byte stepPinZ = 10;
// // byte  dirPinZ = 9;

//     // create an AccelStepper instance for each axis
// AccelStepper xSlide(AccelStepper::DRIVER, 12, 11);
// AccelStepper ySlide(AccelStepper::DRIVER, 8, 7);
// // AccelStepper vSlide(AccelStepper::DRIVER, 10, 9);

//     // variables for keeping track of the axis movements
// long xSlideCount;
// long xSlideInc;
// char xSlideDir;

// long ySlideCount;
// long ySlideInc;
// char ySlideDir;

// // long vSlideCount;
// // long vSlideInc;
// // char vSlideDir;

//     // variables for managing the use of AccelStepper
// long accelStepCount = 0;
// long accelStepsToGo;
// long curStepsToGo;
// long masterCount;
// long numSteps;
//             // for simplicity I am hard-wiring these values
// float stepSpeed = 400;
// float accelRate = 1000;

// char masterAxis;


//     // Movement Data
//         // these data simulate what would be sent from my PC for each move
//         // masterAxis, numSteps, xSlideInc, ySlideInc, vSlideInc
// int moves[2][5] = {
//             {88,        -500,       -576,       -894,   16000},
//             {88,         500,        576,        894,  -16000}
// };
//         // NOTE 88 is the ascii code for 'X' (to avoid the need for a struct)
// byte numMoves = 2;
// byte moveCount = 0;

//     // marker to load new data after every move is finished
// bool startReqd;

// //====================

// void setup() {

//     Serial.begin(115200);
//     Serial.println("Starting");

//         // set the modes for the step and direction pins
//     for (byte n = 7; n <=12; n++) {
//         pinMode(n, OUTPUT);
//     }
//         // set up the acceleration parameters
//     xSlide.setMaxSpeed(stepSpeed);
//     xSlide.setAcceleration(accelRate);

//     ySlide.setMaxSpeed(stepSpeed);
//     ySlide.setAcceleration(accelRate);

//     // vSlide.setMaxSpeed(stepSpeed);
//     // vSlide.setAcceleration(accelRate);

//         // get things moving
//     startReqd = true;

// }

// //===============

// void loop() {

//     if (startReqd == true) {
//         setStartPosition(); //to simulate new values sent from PC
//     }
//     else {
//             // if there is a movement in progress
//         if (curStepsToGo != 0) {
//                 // call the function for the master axis
//             if (masterAxis == 'X') {
//                 xSlideDrive();
//             }
//             else /*if (masterAxis == 'Y')*/ {
//                 ySlideDrive();
//             }
//             // else {
//             //     vSlideDrive();
//             // }
//         }
//             // if the movement is finished prepare the next move
//         else {
//             startReqd = true;
//         }
//     }
//         // if all the moves are finished ...
//     if (moveCount > numMoves) {
//         while (true);
//     }

// }

// //===============

// void setStartPosition() {

//         // put the move data in the appropriate variables
//     masterAxis = (char) moves[moveCount][0];
//     numSteps = moves[moveCount][1];
//     xSlideInc = moves[moveCount][2];
//     ySlideInc = moves[moveCount][3];
//     // vSlideInc = moves[moveCount][4];

//     //~ Serial.print("masterAxis "); Serial.println(masterAxis);
//     //~ Serial.print("numSteps "); Serial.println(numSteps);
//     //~ Serial.print("xSlideInc "); Serial.println(xSlideInc);
//     //~ Serial.print("ySlideInc "); Serial.println(ySlideInc);
//     //~ Serial.print("vSlideInc "); Serial.println(vSlideInc);
//     //~ Serial.println();

//         // figure out the direction for each axis
//     xSlideDir = 'R';
//     ySlideDir = 'R';
//     // vSlideDir = 'R';
//     digitalWrite(dirPinX, HIGH);
//     digitalWrite(dirPinY, HIGH);
//     // digitalWrite(dirPinZ, HIGH);

//     if (xSlideInc < 0) {
//         xSlideDir = 'F';
//         xSlideInc = -xSlideInc;
//         digitalWrite(dirPinX, LOW);
//     }
//     if (ySlideInc < 0) {
//         ySlideDir = 'F';
//         ySlideInc = -ySlideInc;
//         digitalWrite(dirPinY, LOW);
//     }
//     // if (vSlideInc < 0) {
//     //     vSlideDir = 'F';
//     //     vSlideInc = -vSlideInc;
//     //     digitalWrite(dirPinZ, LOW);
//     // }

//         // set up the variables to keep track of axis movements
//             // masterCount accumulates the increments for the master axis
//     masterCount = 0;
//     xSlideCount = xSlideInc;
//     ySlideCount = ySlideInc;
//     // vSlideCount = vSlideInc;


//     setMasterStart();
//     delay(100);
//     moveCount ++;
//     Serial.print("Count "); Serial.println(moveCount);
//     startReqd = false;
//     delay(1000); // just so you can see the move has ended
// }

// //==============

// void setMasterStart() {
//         // set the move() distance for the master axis

//     if (masterAxis == 'X') {
//         xSlide.move(numSteps);
//         curStepsToGo = xSlide.distanceToGo();
//         //~ Serial.print("curStepsToGo "); Serial.println(curStepsToGo);
//     }
//     else /*if (masterAxis == 'l')*/ {
//         ySlide.move(numSteps);
//         curStepsToGo = ySlide.distanceToGo();
//     }
//     // else {
//     //     vSlide.move(numSteps);
//     //     curStepsToGo = vSlide.distanceToGo();
//     // }
// }


// //===============

// void xSlideDrive() {
//         // there is a version of this for each axis
//     curStepsToGo = xSlide.distanceToGo();
//         // check if the stepsToGo has changed
//     if (accelStepsToGo != curStepsToGo) {
//         masterCount += xSlideInc;
//         accelStepsToGo = curStepsToGo;
//     }
//         // calls for the two "slaved" axes
//     ySlideStep();
//     // vSlideStep();

//     xSlide.run();

// }

// //===============

// void ySlideDrive() {
//     curStepsToGo = ySlide.distanceToGo();
//     if (accelStepsToGo != curStepsToGo) {
//         masterCount += ySlideInc;
//         accelStepsToGo = curStepsToGo;
//     }

//     xSlideStep();
//     // vSlideStep();

//     ySlide.run();

// }

// //===============

// // void vSlideDrive() {
// //     curStepsToGo = vSlide.distanceToGo();
// //     if (accelStepsToGo != curStepsToGo) {
// //         masterCount += vSlideInc;
// //         accelStepsToGo = curStepsToGo;
// //     }

// //     ySlideStep();
// //     xSlideStep();

// //     vSlide.run();

// // }

// //=================

// void xSlideStep() {
//         // there is a version of this for each axis
//     if (xSlideInc > 0) {
//             // if the master count exceeds the slave count make a step
//         if (xSlideCount < masterCount) {
//             digitalWrite(stepPinX, HIGH);
//             digitalWrite(stepPinX, LOW);
//                 // then increment the slave count ready for the next move
//             xSlideCount += xSlideInc;
//         }
//     }
// }

// //=================

// void ySlideStep() {
//     if (ySlideInc > 0) {
//         if (ySlideCount < masterCount) {
//             digitalWrite(stepPinY, HIGH);
//             digitalWrite(stepPinY, LOW);
//             ySlideCount += ySlideInc;
//         }
//     }
// }

// //=================

// // void vSlideStep() {
// //     if (xSlideInc > 0) {
// //         if (vSlideCount < masterCount) {
// //             digitalWrite(stepPinZ, HIGH);
// //             digitalWrite(stepPinZ, LOW);
// //             vSlideCount += vSlideInc;
// //         }
// //     }
// // }

#include <AccelStepper.h>

// Define the stepper motor and the pins that is connected to
AccelStepper stepper1(1, 2, 3);  // (Typeof driver: with 2 pins, STEP, DIR)
AccelStepper stepper2(1, 4, 5);

int stepSpeed = 2400;
int stepAccel = 4000;
int distance = 16000;

void setup() {

  stepper1.setMaxSpeed(stepSpeed);  // Set maximum speed value for the stepper
  stepper2.setMaxSpeed(stepSpeed);

  stepper1.setAcceleration(stepAccel);  // Set acceleration value for the stepper
  stepper2.setAcceleration(stepAccel);

  stepper1.setCurrentPosition(0);  // Set the current position to 0 steps
  stepper2.setCurrentPosition(0);

  digitalWrite(13, HIGH);
  digitalWrite(21, HIGH);

}

void loop() {

  stepper1.moveTo(distance);  // Set desired move: 800 steps (in quater-step resolution that's one rotation)
  stepper2.moveTo(distance);

  stepper1.runToPosition();  // Moves the motor to target position w/ acceleration/ deceleration and it blocks until is in position
  stepper2.runToPosition();

  delay(500);
  stepper1.moveTo(0);
  stepper2.moveTo(0);

  stepper1.runToPosition();
  stepper2.runToPosition();

  delay(500);
  // Move back to position 0, using run() which is non-blocking - both motors will move at the same time

  //while (stepper1.currentPosition() != 0) {
  // stepper1.run();  // Move or step the motor implementing accelerations and decelerations to achieve the target position. Non-blocking function
  //
  //
}
