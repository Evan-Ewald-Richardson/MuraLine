G21 ; Set units to millimeters
G90 ; Set absolute positioning

G1 F16000 ; Set federate (speed) ;mm/min ish

 
G1 X0 Y0

; Vertical Line
G1 Z8
G1 X0 Y400
G1 Z0

G1 X100 Y200

; Vertical Double Curve
G1 Z8
G3 X100 Y100 I10 J-50
G2 X100 Y0 I-10 J-50
G1 Z0

G1 X225 Y75

; Circle
G1 Z8
G3 I75 J0
G1 Z0

G1 X300 Y175

; Rectangle
G1 Z8
G1 X450 Y175
G1 X450 Y375
G1 X350 Y375
G1 X400 Y325
G1 X350 Y175
G1 Z0

G1 X250 Y300

; Horizontal Double Curve
G1 Z8
G3 X150 Y300 I-50 J5
G2 X50 Y300 I-50 J-5
G1 Z0

G1 X50 Y450

; Horizontal Line
G1 Z8
G1 X450 Y450
G1 Z0

G1 X300 Y350

; Dot Tests
G1 Z8
G4 1000
G1 Z0

G1 X300 Y250
G1 Z8
G4 2500
G1 Z0

G1 X0 Y0





