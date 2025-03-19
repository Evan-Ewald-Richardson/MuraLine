class Com {
    processing.serial.Serial myPort;  //the Serial port object
    String val;
    String lastCmd;
    ArrayList<String> buf = new ArrayList<String>();

    ArrayList<String> comPorts = new ArrayList<String>();
    long baudRate = 250000;
    int okCount = 0;
    boolean initSent;


    public String sendTerminalCommand(String command) {
        if (command.length() == 0) {    
            return null;
        }
        else {
            if (myPort != null) {
                myPort.write(command + "\n");
                okCount++;
                return "Sent: " + command;
            }
            else {
                return "Not Connected: " + command;
            } 
        }
    }

    public void listPorts() {
        //  initialize your serial port and set the baud rate to 9600

        comPorts.add("Disconnected");

        for (int i = 0; i < processing.serial.Serial.list().length; i++) {
            String name = processing.serial.Serial.list()[i];
            int dot = name.indexOf('.');
            if (dot >= 0)
                name = name.substring(dot + 1);
            if (!name.contains("luetooth")) {
                comPorts.add(name);
                println(name);
            }
        }
    }

    public void disconnect() {
        clearQueue();
        if (myPort != null)
            myPort.stop();
        myPort = null;


        //  myTextarea.setVisible(false);
    }

    public void connect(int port) {
        clearQueue();
        try {
            myPort = new processing.serial.Serial(applet, processing.serial.Serial.list()[port], (int) baudRate);
            println("connected");
            myPort.write("\n");
        } catch (Exception exp) {
            exp.printStackTrace();
            println(exp);
        }
    }

    public void connect(String name) {
        for (int i = 0; i < processing.serial.Serial.list().length; i++) {
            if (processing.serial.Serial.list()[i].contains(name)) {
                connect(i);
                return;
            }
        }
        disconnect();
    }

    public void sendMotorOff() {
        motorsOn = false;
        send("M84\n");
    }

    public void moveDeltaX(float x) {
        send("G0 X" + x + "\n");
        updatePos(currentX + x, currentY);
    }

    public void moveDeltaY(float y) {
        send("G0 Y" + (-y) + "\n");
        updatePos(currentX, currentY + y);
    }

    public void sendMoveG0(float x, float y) {
        send("G0 X" + x + " Y" + (-y) + "\n");
        updatePos(x, y);
    }

    public void sendMoveG1(float x, float y) {
        send("G1 X" + x + " Y" + (-y) + "\n");
        updatePos(x, y);
    }

    public void sendG2(float x, float y, float i, float j) {
        send("G2 X" + x + " Y" + (-y) + " I" + i + " J" + j + "\n");
        updatePos(x, y);
    }
    
    public void sendG2(float x, float y, float r) {
        send("G2 X" + x + " Y" + (-y) + " R" + r+"\n");
        updatePos(x, y);
    }

    public void sendG3(float x, float y, float i, float j) {
        send("G3 X" + x + " Y" + (-y) + " I" + i + " J" + j + "\n");
        updatePos(x, y);
    }
    
    public void sendG3(float x, float y, float r) {
        send("G3 X" + x + " Y" + (-y) + " R" + r+"\n");
        updatePos(x, y);
    }

    public void sendSpeed(int speed) {
        send("G0 F" + speed + "\n");
    }

    public void sendHome() {
        send("G92 X" + homeX + " Y" + (-homeY) + "\n");
        updatePos(homeX, homeY);
    }

    public void sendSpeed() {
        send("G0 F" + speedValue + "\n");
    }

// M665: Set POLARGRAPH settings
// Parameters:
//    S[segments]  - Segments-per-second - NOT PARAMETERISED YET
//    L[left]      - Work area minimum X
//    R[right]     - Work area maximum X
//    T[top]       - Work area maximum Y
//    B[bottom]    - Work area minimum Y
//    H[length]    - Maximum belt length

    public void sendSpecs() {
        // send(
        //     "M665"
        //     + " S" + "5"
        //     + " L0" 
        //     + " R" + machineWidth 
        //     + " T0" 
        //     + " B" + (-machineHeight)
        //     + " H" + Math.sqrt((machineWidth * machineWidth) + (machineHeight * machineHeight)) 
        //     + "\n"
        // );
    }
    
    public void sendPenUp() {
        send("G4 P"+servoDwell+"\n");//pause
        send("M280 P0 S"+servoUpValue+"\n");
        send("G4 P"+servoDwell+"\n");

        showPenDown();
    }
    

    public void sendPenDown() {
        send("G4 P"+servoDwell+"\n");
        send("M280 P0 S"+servoDownValue+"\n");
        send("G4 P"+servoDwell+"\n");
        showPenUp();
    }

    public void sendAbsolute() {
        send("G90\n");
    }
    

    public void sendRelative() {
        send("G91\n");
    }
    
    public void sendMM()
    {
      send("G21\n");
    }

    public void initArduino() {
        initSent = true;
        sendSpecs();
        sendHome();
        sendSpeed();

    }

    public void clearQueue() {
        buf.clear();
        okCount = 0;
        lastCmd = null;
        initSent = false;
    }

    public void queue(String msg) {
        if (myPort != null) {
            buf.add(msg);
        }
    }

    public void nextMsg() {
        if (buf.size() > 0) {
            String msg = buf.get(0);
            oksend(msg);
            buf.remove(0);
        } else if (currentPlot.isPlotting()) {
            currentPlot.nextPlot(true);
        }
    }

    public void send(String msg) {
        if (myPort != null) {
            if (okCount == 0)
                oksend(msg);
            else
                queue(msg);
        }
    }

    public void oksend(String msg) {
        print(msg);
        if (myPort != null) {
            myPort.write(msg);
            lastCmd = msg;
            okCount++;
            myTextarea.setText(" " + msg);
        }
    }

    public void serialEvent() {
        if (myPort == null || myPort.available() <= 0) return;

        val = myPort.readStringUntil('\n');
        if (val != null) {
            val = trim(val);
            println("Received: " + val); // Better logging
            
            if (val.contains("wait") || val.contains("echo")) {
            }          
            else if(val.contains("Resend") && lastCmd != null) {
                println("Resending command: " + lastCmd);
                myPort.write(lastCmd);
            }            
            else if (val.contains("ok")) {
                okCount--; // CHANGE: Decrement instead of setting to 0
                println("Command acknowledged. Remaining commands: " + okCount);
                nextMsg();
            }
        }
    }
    
}
