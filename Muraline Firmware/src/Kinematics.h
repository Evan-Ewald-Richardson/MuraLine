#pragma once

#include <Arduino.h>
#include <AccelStepper.h>

class Kinematics
{
    private:

    public:

        /*
            Kinematics constructor. This module handles the translation layer between cartesian corodinates in cm and cm/s

            Give the kinematics engine a position, and it will move the motors accordingly
        */
        Kinematics();
}