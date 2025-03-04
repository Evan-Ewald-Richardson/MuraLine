 class Com {
    processing.serial.Serial myPort;  //the Serial port object
    String val;
    String lastCmd;
    ArrayList<String> buf = new ArrayList<String>();

    ArrayList<String> comPorts = new ArrayList<String>();
    long baudRate = 115200;
    int lastPort;
    int okCount = 0;
    boolean initSent;

    // inQueue variables for buffering on MCU
    int inQueue = 0;
    final int MAX_IN_QUEUE = 8;

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
            lastPort = port;
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
        send("G0 Y" + y + "\n");
        updatePos(currentX, currentY + y);
    }

    public void moveDeltaA(float a) {
        send("G350" + " P1" + "S" + a + "\n");
    }

    public void moveDeltaB(float b) {
        send("G350" + " P2" + "S" + b + "\n");
    }

    public void sendMoveG0(float x, float y) {
        send("G0 X" + x + " Y" + y + "\n");
        updatePos(x, y);
    }

    public void sendMoveG1(float x, float y) {
        send("G1 X" + x + " Y" + y + "\n");
        updatePos(x, y);
    }

    public void sendG2(float x, float y, float i, float j) {
        send("G2 X" + x + " Y" + y + " I" + i + " J" + j + "\n");
        updatePos(x, y);
    }
    
    public void sendG2(float x, float y, float r) {
        send("G2 X" + x + " Y" + y + " R" + r+"\n");
        updatePos(x, y);
    }

    public void sendG3(float x, float y, float i, float j) {
        send("G3 X" + x + " Y" + y + " I" + i + " J" + j + "\n");
        updatePos(x, y);
    }
    
    public void sendG3(float x, float y, float r) {
        send("G3 X" + x + " Y" + y + " R" + r+"\n");
        updatePos(x, y);
    }

    public void sendSpeed(int speed) {
        send("G0 F" + speed + "\n");
    }

    public void sendHome() {
        send("M1 Y" + homeY + "\n");
        updatePos(homeX, homeY);
    }

    public void sendSpeed() {
        send("G0 F" + speedValue + "\n");
    }

    public void sendPenWidth() {
        send("M4 E" + penWidth + "\n");
    }

    public void sendSpecs() {
        send("M4 X" + machineWidth + " E" + penWidth + " S" + stepsPerRev + " P" + mmPerRev + "\n");
    }
    
    public void sendPenUp() {
     if (useSolenoid == true) {
       send("G4 P"+servoDwell+"\n");//pause
       if (solenoidUP == 1) {
          send("M107"+"\n");
       } else {
         send("M106"+"\n");
       }
       send("G4 P"+servoDwell+"\n");//pause
     } else {
      send("G4 P"+servoDwell+"\n");//pause
      send("M340 P3 S"+servoUpValue+"\n");
      send("G4 P"+servoDwell+"\n");
     }
     showPenDown();
    }
    

    public void sendPenDown() {
    if (useSolenoid == true) {
         send("G4 P"+servoDwell+"\n");//pause
         if (solenoidUP == 1) {
            send("M106"+"\n");
         } else {
           send("M107"+"\n");
         }
         send("G4 P"+servoDwell+"\n");//pause
       } else {
        send("G4 P"+servoDwell+"\n");
        send("M340 P3 S"+servoDownValue+"\n");
        send("G4 P"+servoDwell+"\n");
      }
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

    public void sendPixel(float da, float db, int pixelSize, int shade, int pixelDir) {
        send("M3 X" + da + " Y" + db + " P" + pixelSize + " S" + shade + " E" + pixelDir + "\n");
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
            // print("Q "+msg);
            buf.add(msg);
        }
    }

    public void nextMsg() {
        if (buf.size() > 0) {
            String msg = buf.get(0);
           // print("sending "+msg);
            oksend(msg);
            buf.remove(0);
        } else {

            if (currentPlot.isPlotting())
                currentPlot.nextPlot(true);

        }
    }

    // public void send(String msg) {

    //     if (okCount == 0)
    //         oksend(msg);
    //     else
    //         queue(msg);
    // }

    // Updated send method to handle buffering on the MCU
    public void send(String msg) {
        if (myPort == null) return; // not connected
        buf.add(msg);
        tryToSend();
    }

    private void tryToSend() {
        while (inQueue < MAX_IN_QUEUE && !buf.isEmpty()) {
            String nextCmd = buf.remove(0);
            oksend(nextCmd);
            inQueue++;
        }
    }

    // public void oksend(String msg) {
    //     print(msg);

    //     if (myPort != null) {
    //         myPort.write(msg);
    //         lastCmd = msg;
    //         okCount--;
    //         myTextarea.setText(" " + msg);
    //     }
    // }

    // public void serialEvent() {

     
    //     if (myPort == null || myPort.available() <= 0) return;


    //     val = myPort.readStringUntil('\n');
    //     if (val != null) {
    //         val = trim(val);
    //         if (!val.contains("wait"))
    //             println(val);
                
    //         if (val.contains("wait") || val.contains("echo"))
    //         {
    //             okCount = 0;
    //             if(!initSent)
    //               initArduino();
    //             else
    //               nextMsg();
    //         }          
    //         else if(val.contains("Resend") && lastCmd != null)
    //         {
    //           okCount=0;
    //           oksend(lastCmd);
    //         }            
    //         else if (val.contains("ok")) {
    //             okCount=0;
    //             nextMsg();
    //         }
    //     }
    // }
    
    public void oksend(String msg) {
        print(msg);
        if (myPort != null) {
            myPort.write(msg);
            lastCmd = msg;
            myTextarea.setText(" " + msg);
        }
    }

    public void serialEvent() {
        if (myPort == null || myPort.available() <= 0) return;
        
        val = myPort.readStringUntil('\n');
        if (val == null) return;
        
        val = trim(val);
        println(val);
        
        if (val.contains("wait") || val.contains("echo")) {
            // Reset queue count if firmware signals wait/echo
            inQueue = 0;
            if (!initSent)
                initArduino();
            else
                tryToSend();
        }
        else if (val.contains("Resend") && lastCmd != null) {
            // Resend last command and reset in-flight counter
            inQueue = 0;
            oksend(lastCmd);
            inQueue++;
        }
        else if (val.contains("ok")) {
            // A command was processed: decrement inQueue and try sending more
            if (inQueue > 0) inQueue--;
            tryToSend();
            
            // If all commands have been acknowledged and plotting is in progress, continue plotting
            if (buf.isEmpty() && inQueue == 0 && currentPlot.isPlotting()) {
                currentPlot.nextPlot(true);
                tryToSend();
            }
        }
    }

    public void export(File file){}
}
