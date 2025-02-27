class Plot {
        boolean loaded;
        boolean plotting;
        boolean isImage;
        int plotColor = previewColor;
        int penIndex;
        ArrayList<Path> penPaths = new ArrayList<Path>();
        PGraphics preview = null;
        
        // Command with metadata for UI updates
        protected class GCodeCommand {
            String command;
            int pathIndex;  // Which path this command belongs to
            int lineIndex;  // Which line within the path this command represents
            float x = Float.NaN;  // Target X position for this command
            float y = Float.NaN;  // Target Y position for this command
            boolean isPenUp = false; // Whether this is a pen up command
            
            GCodeCommand(String cmd, int pathIdx) {
                this(cmd, pathIdx, -1);
            }
            
            GCodeCommand(String cmd, int pathIdx, int lineIdx) {
                command = cmd;
                pathIndex = pathIdx;
                lineIndex = lineIdx;
                
                // Parse X, Y coordinates from the command
                if (cmd != null) {
                    String[] parts = cmd.split(" ");
                    for (String part : parts) {
                        if (part.startsWith("X")) {
                            x = Float.parseFloat(part.substring(1));
                        } else if (part.startsWith("Y")) {
                            y = Float.parseFloat(part.substring(1));
                        } else if (part.startsWith("Z")) {
                            float z = Float.parseFloat(part.substring(1));
                            isPenUp = z > 0;
                        }
                    }
                }
            }
        }
        
        ArrayList<GCodeCommand> gcodeQueue = new ArrayList<GCodeCommand>();
        protected GCodeCommand currentCommand = null; // Track current command being executed
        
        String progress()
        {
          return penIndex+"/"+penPaths.size();
        }
        
        // Add GCODE command to the internal queue
        protected void queueGcode(String cmd) {
            queueGcode(cmd, penIndex, -1);
        }
        
        // Add GCODE command with path index to the internal queue
        protected void queueGcode(String cmd, int pathIdx) {
            queueGcode(cmd, pathIdx, -1);
        }
        
        // Add GCODE command with path and line indices to the internal queue
        protected void queueGcode(String cmd, int pathIdx, int lineIdx) {
            gcodeQueue.add(new GCodeCommand(cmd, pathIdx, lineIdx));
        }
        
        // Clear the GCODE queue
        protected void clearGcodeQueue() {
            gcodeQueue.clear();
        }
        
        // Get next GCODE command from queue
        protected String getNextGcode() {
            if (gcodeQueue.isEmpty()) {
                return null;
            }
            currentCommand = gcodeQueue.remove(0);
            penIndex = currentCommand.pathIndex; // Update general UI state
            updateIndices(currentCommand.pathIndex, currentCommand.lineIndex); // Let derived classes update their indices
            
            // Update UI position if command has coordinates
            if (!Float.isNaN(currentCommand.x) && !Float.isNaN(currentCommand.y)) {
                updatePos(currentCommand.x, currentCommand.y);
            }
            
            return currentCommand.command;
        }
        
        // Override in derived classes to update specific indices
        protected void updateIndices(int pathIdx, int lineIdx) {
            // Base class does nothing
        }
        
        // Check if queue has more commands
        protected boolean hasMoreGcode() {
            return !gcodeQueue.isEmpty();
        }
        
        void init(){}
        void showControls() {}
        void hideControls() {}

        boolean isLoaded()
        {
            return loaded;
        }
        boolean isPlotting()
        {
            return plotting;
        }
        boolean isImage()
        {
            return isImage;
        }

        public void clear() {
            oimg = null;
            simage = null;
            penPaths.clear();
            loaded = false;
            preview = null;
            reset();
        }

        public void reset() {
            plotColor = previewColor;
            plotting = false;
            penIndex = 0;
            plotDone();
            com.clearQueue();
        }
        
        void rotate() {}
        void flipX() {}
        void flipY() {}
        void calculate() {}
        void crop(int cropLeft, int cropTop, int cropRight, int cropBottom){}

        public void plot() {
          plotting = true;
          penIndex = 0;
          plotColor = whilePlottingColor;
          
          // Clear any existing commands
          clearGcodeQueue();
          
          // Queue initial setup commands
          queueGcode("G90\n"); // Absolute positioning
          queueGcode("G21\n"); // Use millimeters
          queueGcode("G0 F" + speedValue + "\n"); // Set speed
          queueGcode("M4 X" + machineWidth + " E" + penWidth + " S" + stepsPerRev + " P" + mmPerRev + "\n"); // Machine specs
          queueGcode("M1 Y" + homeY + "\n"); // Home position
          
          // Time the GCODE generation process
          long startTime = System.currentTimeMillis();
          
          // Generate all path GCODE commands
          generatePathGcode();
          
          // Calculate and log the time taken
          long endTime = System.currentTimeMillis();
          long duration = endTime - startTime;
          println("GCODE Queue Generation: " + duration + "ms for " + gcodeQueue.size() + " commands");
          
          // Start sending commands
          nextPlot(true);
        }
        
        // Generate GCODE for all paths
        protected void generatePathGcode() {
            // Base implementation handles setup, lets derived classes generate paths,
            // then handles cleanup
            generatePathSetup();
            generatePaths();
            generatePathCleanup();
        }
        
        // Called at the start of path generation to set up initial state
        protected void generatePathSetup() {
            queueGcode("G0 Z5\n"); // Pen up
            queueGcode("G0 X" + homeX + " Y" + homeY + "\n");
        }
        
        // Override this in derived classes to generate specific path commands
        protected void generatePaths() {
            // Base class has no paths to generate
        }
        
        // Called at the end of path generation to cleanup/return home
        protected void generatePathCleanup() {
            queueGcode("G0 Z5\n"); // Pen up
            queueGcode("G0 X" + homeX + " Y" + homeY + "\n");
        }
        
        public void plottingStopped() {
          plotting = false;
          penIndex = 0;
          plotColor = previewColor;
          clearGcodeQueue(); // Clear any remaining commands
          plotDone();
          goHome();
          com.sendMotorOff();
      }
        
        void nextPlot(boolean preview) {
            // If there are commands in the queue, send them
            if (hasMoreGcode()) {
                String cmd = getNextGcode();
                if (cmd != null) {
                    com.send(cmd);
                }
                return;
            }
            
            // If no more commands and still plotting, stop
            if (plotting) {
                plottingStopped();
            }
        }
        void load() {}
        void load(String fileName) {}

        // Draw the current command state
        protected void drawCurrentCommand() {
            if (currentCommand != null && plotting) {
                // Draw line from last position to current target
                stroke(currentCommand.isPenUp ? rapidColor : penColor);
                strokeWeight(currentCommand.isPenUp ? 0.5 : 1);
                
                // If we have valid coordinates, draw the movement line
                if (!Float.isNaN(currentCommand.x) && !Float.isNaN(currentCommand.y)) {
                    float lastX = currentX;
                    float lastY = currentY;
                    float targetX = currentCommand.x;
                    float targetY = currentCommand.y;
                    
                    sline(lastX, lastY, targetX, targetY);
                }
            }
        }
        
        // Base draw method - derived classes should override this
        public void draw() {
            // Draw preview if available
            if (preview != null) {
                image(preview, scaleX(offX + homeX), scaleY(offY + homeY), preview.width * zoomScale, preview.height * zoomScale);
            }
            
            // Draw current command state
            if (plotting) {
                drawCurrentCommand();
            }
        }
    }
