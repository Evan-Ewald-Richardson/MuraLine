class Plot {
        boolean loaded;
        boolean plotting;
        boolean paused;
        boolean isImage;
        int plotColor = previewColor;
        int penIndex;
        long lastCommandTime = 0;  // Track when last command was processed
        int disconnectedDelay = 100;  // Delay between commands when disconnected (milliseconds)
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
        
        // Store last position before pause
        protected float pausedX = Float.NaN;
        protected float pausedY = Float.NaN;
        
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
            paused = true;  // Start paused by default
            penIndex = 0;
            plotColor = whilePlottingColor;
            lastCommandTime = millis();  // Initialize the time
            
            // Clear any existing commands
            clearGcodeQueue();
            
            // Queue initial setup commands
            queueGcode("G90\n"); // Absolute positioning
            queueGcode("G21\n"); // Use millimeters
            queueGcode("G0 F" + speedValue + "\n"); // Set speed
            // queueGcode("M1 Y" + homeY + "\n"); // Home position
            
            // Generate all path GCODE commands
            generatePathGcode();
        }
        
        // Constants for bezier curve generation
        protected static final int G0_CURVE_SEGMENTS = 100;  // Number of segments for G0 curves
        protected static final float CURVE_HEIGHT_FACTOR = 0.3f;  // How much the curve bulges (0.0-1.0)
        
        // Class-level additions to Plot class
        protected class PathVector {
            float x, y;      // Position
            float dx, dy;    // Direction vector
            
            PathVector(float x, float y, float dx, float dy) {
                this.x = x;
                this.y = y;
                this.dx = dx;
                this.dy = dy;
                normalize();
            }
            
            void normalize() {
                float len = sqrt(dx*dx + dy*dy);
                if (len > 0.0001) {
                    dx /= len;
                    dy /= len;
                }
            }
        }
        
        // Generate a curved G0 move that aligns with entry/exit vectors
        protected void queueCurvedG0Move(PathVector start, PathVector end, int pathIndex, int lineIndex) {
            // Validate input coordinates
            if (Float.isNaN(start.x) || Float.isNaN(start.y) || 
                Float.isNaN(end.x) || Float.isNaN(end.y)) {
                println("Warning: Invalid coordinates detected in G0 move, skipping curve generation");
                if (!Float.isNaN(end.x) && !Float.isNaN(end.y)) {
                    queueGcode("G0 X" + end.x + " Y" + (-end.y) + "\n", pathIndex, lineIndex);
                }
                return;
            }
            
            // Calculate distance for scaling
            float dx = end.x - start.x;
            float dy = end.y - start.y;
            float dist = sqrt(dx*dx + dy*dy);
            
            // Skip if distance is too small
            if (dist < 0.01) {
                queueGcode("G0 X" + end.x + " Y" + (-end.y) + "\n", pathIndex, lineIndex);
                return;
            }
            
            // Calculate control points using entry/exit vectors
            float cp1x = start.x + start.dx * dist * CURVE_HEIGHT_FACTOR;
            float cp1y = start.y + start.dy * dist * CURVE_HEIGHT_FACTOR;
            
            float cp2x = end.x - end.dx * dist * CURVE_HEIGHT_FACTOR;
            float cp2y = end.y - end.dy * dist * CURVE_HEIGHT_FACTOR;
            
            // Queue the curve segments using cubic bezier
            for (int i = 0; i <= G0_CURVE_SEGMENTS; i++) {
                float t = (float)i / G0_CURVE_SEGMENTS;
                // Cubic bezier calculation
                float mt = 1 - t;
                float mt2 = mt * mt;
                float mt3 = mt2 * mt;
                float t2 = t * t;
                float t3 = t2 * t;
                
                float px = mt3 * start.x + 
                           3 * mt2 * t * cp1x + 
                           3 * mt * t2 * cp2x + 
                           t3 * end.x;
                           
                float py = mt3 * start.y + 
                           3 * mt2 * t * cp1y + 
                           3 * mt * t2 * cp2y + 
                           t3 * end.y;
                
                // Validate calculated points
                if (!Float.isNaN(px) && !Float.isNaN(py)) {
                    queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                }
            }
        }

        // Generate GCODE for all paths
        protected void generatePaths() {
            // Base class has no paths to generate
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
            queueGcode("G0 X" + homeX + " Y" + (-homeY) + "\n");
        }
        
        // Called at the end of path generation to cleanup/return home
        protected void generatePathCleanup() {
            queueGcode("G0 Z5\n"); // Pen up
            queueGcode("G0 X" + homeX + " Y" + (-homeY) + "\n");
        }
        
        public void plottingStopped() {
            plotting = false;
            paused = false;
            pausedX = Float.NaN;
            pausedY = Float.NaN;
            penIndex = 0;
            plotColor = previewColor;
            clearGcodeQueue();
            plotDone();
            goHome();
            // Only send motor off if connected
            if (com.myPort != null) {
                com.sendMotorOff();
            }
        }
        
        public void pause() {
            if (plotting) {
                paused = true;
                // Store current position
                pausedX = currentX;
                pausedY = currentY;
                // Lift pen when pausing
                sendImmediateCommand("G0 Z5\n");
            }
        }

        public void resume() {
            if (plotting && paused) {
                // First return to the paused position with pen up
                if (!Float.isNaN(pausedX) && !Float.isNaN(pausedY)) {
                    sendImmediateCommand("G90\n"); // Ensure absolute positioning
                    sendImmediateCommand("G0 Z5\n"); // Ensure pen is up
                    sendImmediateCommand(String.format("G0 X%.2f Y%.2f\n", pausedX, pausedY));
                }
                
                paused = false;
                // When resuming, process next command
                nextPlot(true);
            }
        }

        // Helper method to process commands in disconnected mode
        protected void processDisconnectedQueue(boolean preview) {
            // Schedule repeated calls to nextPlot to simulate machine responses
            Thread timer = new Thread(new Runnable() {
                public void run() {
                    while (plotting && !paused && hasMoreGcode()) {
                        try {
                            Thread.sleep(disconnectedDelay);
                            // Get next command and update UI in a thread-safe way
                            String cmd = getNextGcode();
                            if (cmd != null) {
                                print(cmd);
                                myTextarea.setText(" " + cmd);
                                lastCommandTime = millis();
                            }
                        } catch (InterruptedException e) {
                            break;
                        }
                    }
                    // If no more commands and still plotting, stop
                    if (!hasMoreGcode() && plotting) {
                        plottingStopped();
                    }
                }
            });
            timer.start();
        }

        public void nextPlot(boolean preview) {
            nextPlot(preview, false);  // Default to non-step mode
        }

        public void nextPlot(boolean preview, boolean isStepping) {
            // If paused and not stepping, don't process next command
            if (paused && !isStepping) {
                return;
            }
            
            // If there are commands in the queue, process them
            if (hasMoreGcode()) {
                String cmd = getNextGcode();
                if (cmd != null) {
                    // If connected, send to hardware
                    if (com.myPort != null) {
                        com.send(cmd);
                    } else {
                        // If disconnected, handle command
                        print(cmd);
                        myTextarea.setText(" " + cmd);
                        lastCommandTime = millis();
                        
                        // Only start continuous processing if not stepping
                        if (!isStepping) {
                            processDisconnectedQueue(preview);
                        }
                    }
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

        // Helper method to draw a cubic bezier curve in the UI
        protected void drawBezierCurve(float x1, float y1, float cp1x, float cp1y, 
                                      float cp2x, float cp2y, float x2, float y2) {
            noFill();
            beginShape();
            vertex(scaleX(x1), scaleY(y1));
            bezierVertex(scaleX(cp1x), scaleY(cp1y), 
                        scaleX(cp2x), scaleY(cp2y), 
                        scaleX(x2), scaleY(y2));
            endShape();
        }

        // Modified drawCurrentCommand to handle bezier curves
        protected void drawCurrentCommand() {
            if (currentCommand != null && plotting) {
                stroke(currentCommand.isPenUp ? rapidColor : penColor);
                strokeWeight(currentCommand.isPenUp ? 0.5 : 1);
                
                // If we have valid coordinates, draw the movement
                if (!Float.isNaN(currentCommand.x) && !Float.isNaN(currentCommand.y)) {
                    float lastX = currentX;
                    float lastY = currentY;
                    float targetX = currentCommand.x;
                    float targetY = currentCommand.y;
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

        public void sendImmediateCommand(String cmd) {
            // For immediate commands that should work even when paused
            if (com.myPort != null) {
                com.send(cmd);
            }
            // Always print the command and update UI
            print(cmd);
            myTextarea.setText(" " + cmd);
        }

        // Update position without affecting plot state
        public void updatePos(float x, float y) {
            currentX = x;
            currentY = -y;
        }
    }
