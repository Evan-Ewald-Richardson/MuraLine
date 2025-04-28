import os

def generate_gcode(feed_rate, Z_actuation, X_max, Y_max):
    test_GCode = f"""
    G21 ; Set units to millimeters
    G90 ; Set absolute positioning
    G1 F{feed_rate} ; Set federate (mm/min)

    G1 X{X_max * 0 / 450} Y{Y_max * 0 / 450}

    ; Vertical Line
    G1 Z{Z_actuation}
    G1 X{X_max * 0 / 450} Y{Y_max * 400 / 450}
    G1 Z0

    G1 X{X_max * 100 / 450} Y{Y_max * 200 / 450}

    ; Vertical Double Curve
    G1 Z{Z_actuation}
    G3 X{X_max * 100 / 450} Y{Y_max * 100 / 450} I10 J-50
    G2 X{X_max * 100 / 450} Y{Y_max * 0 / 450} I-10 J-50
    G1 Z0

    G1 X{X_max * 225 / 450} Y{Y_max * 75 / 450}

    ; Circle
    G1 Z{Z_actuation}
    G3 I75 J0
    G1 Z0

    G1 X{X_max * 300 / 450} Y{Y_max * 175 / 450}

    ; Rectangle
    G1 Z{Z_actuation}
    G1 X{X_max * 450 / 450} Y{Y_max * 175 / 450}
    G1 X{X_max * 450 / 450} Y{Y_max * 375 / 450}
    G1 X{X_max * 350 / 450} Y{Y_max * 375 / 450}
    G1 X{X_max * 400 / 450} Y{Y_max * 325 / 450}
    G1 X{X_max * 350 / 450} Y{Y_max * 175 / 450}
    G1 Z0

    G1 X{X_max * 250 / 450} Y{Y_max * 300 / 450}

    ; Horizontal Double Curve
    G1 Z{Z_actuation}
    G3 X{X_max * 150 / 450} Y{Y_max * 300 / 450} I-50 J5
    G2 X{X_max * 50 / 450} Y{Y_max * 300 / 450} I-50 J-5
    G1 Z0

    G1 X{X_max * 50 / 450} Y{Y_max * 450 / 450}

    ; Horizontal Line
    G1 Z{Z_actuation}
    G1 X{X_max * 450 / 450} Y{Y_max * 450 / 450}
    G1 Z0

    G1 X{X_max * 300 / 450} Y{Y_max * 350 / 450}

    ; Dot Tests
    G1 Z{Z_actuation}
    G4 1000
    G1 Z0

    G1 X{X_max * 300 / 450} Y{Y_max * 250 / 450}
    G1 Z{Z_actuation}
    G4 2500
    G1 Z0

    G1 X{X_max * 0 / 450} Y{Y_max * 0 / 450}
    """
    current_dir = os.getcwd()
    file_name = f"test_gcode_{feed_rate}_{Z_actuation}_{X_max}_{Y_max}.gcode"
    file_name = os.path.join(current_dir, file_name)

    try:
        with open(file_name, "w") as file:
            file.write(test_GCode)
    except:
        return "Error: GCode file could not be written, check if the file is open in another program"

    return f"GCode file saved as {file_name}"

if __name__ == "__main__":
    feed_rate = int(input("Enter feed rate (mm/min): "))
    Z_actuation = float(input("Enter Z actuation height: "))
    X_max = int(input("Enter maximum X value (450): ") or 450)
    Y_max = int(input("Enter maximum Y value (450): ") or 450)
    
    print(generate_gcode(feed_rate, Z_actuation, X_max, Y_max))
