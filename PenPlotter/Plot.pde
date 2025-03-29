class Plot {
        boolean loaded;
        boolean plotting;
        boolean paused;
        boolean isImage;
        int plotColor = previewColor;
        int penIndex;
        long lastCommandTime = 0;  // Track when last command was processed
        int disconnectedDelay = 5;  // Delay between commands when disconnected (milliseconds)
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

            PathVector averageDirection(PathVector other, int weight) {
                float avgDx = (this.dx + other.dx * weight) / (1 + weight);
                float avgDy = (this.dy + other.dy * weight) / (1 + weight);
                return new PathVector(this.x, this.y, avgDx, avgDy);
            }
        }

        protected int calculateCurveSegments(float distance) {
            // Logarithmic scaling of segments based on distance
            int segments = (int)(Math.log1p(distance) * segmentDensityFactor);
            
            // Clamp segments between MIN and MAX
            return Math.max(MIN_CURVE_SEGMENTS, 
                Math.min(MAX_CURVE_SEGMENTS, segments));
        }

        protected PathVector adjustVectorToWorkArea(PathVector vector, float workAreaMinX, float workAreaMaxX, float workAreaMinY, float workAreaMaxY) {
            // Check if the current vector points outside the work area
            float projectedX = vector.x + vector.dx * MIN_CURVE_RADIUS;
            float projectedY = vector.y + vector.dy * MIN_CURVE_RADIUS;
            
            // Adjust direction if projection goes outside work area
            if (projectedX < workAreaMinX || projectedX > workAreaMaxX ||
                projectedY < workAreaMinY || projectedY > workAreaMaxY) {
                // Rotate vector slightly inwards
                float inwardRotation = PI / 6;  // 30-degree rotation
                float newDx = vector.dx * cos(inwardRotation) - vector.dy * sin(inwardRotation);
                float newDy = vector.dx * sin(inwardRotation) + vector.dy * cos(inwardRotation);
                
                return new PathVector(vector.x, vector.y, newDx, newDy);
            }
            
            return vector;
        }
        
        // // Generate a curved G0 move that aligns with entry/exit vectors
        // protected void queueCurvedG0Move(PathVector start, PathVector end, int pathIndex, int lineIndex, List<PathVector> previousPoints, float linearDistance) {
        //     // Validate input coordinates
        //     if (Float.isNaN(start.x) || Float.isNaN(start.y) || 
        //         Float.isNaN(end.x) || Float.isNaN(end.y)) {
        //         println("Warning: Invalid coordinates detected in G0 move, skipping curve generation");
        //         if (!Float.isNaN(end.x) && !Float.isNaN(end.y)) {
        //             queueGcode("G0 X" + end.x + " Y" + (-end.y) + "\n", pathIndex, lineIndex);
        //         }
        //         return;
        //     }
            
        //     // Calculate distance for scaling
        //     float dx = end.x - start.x;
        //     float dy = end.y - start.y;
        //     float dist = max(sqrt(dx*dx + dy*dy), MIN_CURVE_RADIUS);
            
        //     // Properly initialize tangent vectors with directional components
        //     PathVector startTangent = new PathVector(start.x, start.y, start.dx, start.dy);
        //     PathVector endTangent = new PathVector(end.x, end.y, end.dx, end.dy);
            
        //     if (previousPoints != null && !previousPoints.isEmpty()) {
        //         // Use average of last few points to stabilize direction vector
        //         int weight = Math.min(3, previousPoints.size());
        //         for (int i = 0; i < weight; i++) {
        //             startTangent = startTangent.averageDirection(previousPoints.get(previousPoints.size() - 1 - i), weight);
        //         }
        //     }
            
        //     // Normalize tangent vectors
        //     startTangent.normalize();
        //     endTangent.normalize();
            
        //     // Adjust vectors to stay within work area
        //     startTangent = adjustVectorToWorkArea(startTangent, workAreaMinX, workAreaMaxX, workAreaMinY, workAreaMaxY);
        //     endTangent = adjustVectorToWorkArea(endTangent, workAreaMinX, workAreaMaxX, workAreaMinY, workAreaMaxY);
            
        //     // Calculate linear segment lengths (clamped to not exceed half the total distance)
        //     float maxLinearLength = dist / 2.0f;
        //     float actualLinearDistance = min(linearDistance, maxLinearLength);
            
        //     // Create linear entry end point
        //     PathVector linearEntryEnd = new PathVector(
        //         start.x + startTangent.dx * actualLinearDistance,
        //         start.y + startTangent.dy * actualLinearDistance,
        //         startTangent.dx,
        //         startTangent.dy
        //     );
            
        //     // Create linear exit start point
        //     float endSegmentDist = actualLinearDistance;
            
        //     // Check if the linear distance would take us beyond the start point
        //     if (endSegmentDist >= dist) {
        //         endSegmentDist = dist / 2; // Limit to half the total distance
        //     }
            
        //     PathVector linearExitStart = new PathVector(
        //         end.x - endTangent.dx * endSegmentDist,
        //         end.y - endTangent.dy * endSegmentDist,
        //         endTangent.dx,
        //         endTangent.dy
        //     );
            
        //     // Validate and constrain points to work area
        //     linearEntryEnd.x = constrain(linearEntryEnd.x, workAreaMinX, workAreaMaxX);
        //     linearEntryEnd.y = constrain(linearEntryEnd.y, workAreaMinY, workAreaMaxY);
        //     linearExitStart.x = constrain(linearExitStart.x, workAreaMinX, workAreaMaxX);
        //     linearExitStart.y = constrain(linearExitStart.y, workAreaMinY, workAreaMaxY);
            
        //     // Calculate segments for each part based on distance
        //     // Linear entry segment points
        //     float entryDist = sqrt(
        //         (linearEntryEnd.x - start.x) * (linearEntryEnd.x - start.x) +
        //         (linearEntryEnd.y - start.y) * (linearEntryEnd.y - start.y)
        //     );
        //     int entrySegments = calculateCurveSegments(entryDist);
            
        //     // Generate points for linear entry with consistent density
        //     for (int i = 0; i <= entrySegments; i++) {
        //         float t = (float)i / entrySegments;
        //         float px = start.x + (linearEntryEnd.x - start.x) * t;
        //         float py = start.y + (linearEntryEnd.y - start.y) * t;
                
        //         if (!Float.isNaN(px) && !Float.isNaN(py)) {
        //             queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
        //         }
        //     }
            
        //     // Recalculate the distance between the transition points
        //     float curvedDx = linearExitStart.x - linearEntryEnd.x;
        //     float curvedDy = linearExitStart.y - linearEntryEnd.y;
        //     float curvedDist = max(sqrt(curvedDx*curvedDx + curvedDy*curvedDy), MIN_CURVE_RADIUS);
            
        //     // Calculate number of segments based on curved distance
        //     int curveSegments = calculateCurveSegments(curvedDist);
            
        //     // Calculate control points to ensure tangent continuity with the linear segments
        //     float curveFactor = Math.min(1.0f, curvedDist * 0.1f);  // Adaptive curve factor
            
        //     // Control point 1 continues in the same direction as the entry tangent
        //     float cp1x = linearEntryEnd.x + startTangent.dx * curvedDist * curveFactor;
        //     float cp1y = linearEntryEnd.y + startTangent.dy * curvedDist * curveFactor;
            
        //     // Control point 2 comes from the direction of the exit tangent
        //     float cp2x = linearExitStart.x - endTangent.dx * curvedDist * curveFactor;
        //     float cp2y = linearExitStart.y - endTangent.dy * curvedDist * curveFactor;

        //     // Clamp control points to work area
        //     cp1x = constrain(cp1x, workAreaMinX, workAreaMaxX);
        //     cp1y = constrain(cp1y, workAreaMinY, workAreaMaxY);
        //     cp2x = constrain(cp2x, workAreaMinX, workAreaMaxX);
        //     cp2y = constrain(cp2y, workAreaMinY, workAreaMaxY);
            
        //     // Queue the curve segments using cubic bezier
        //     // Note: We start at 1 since the last point of the entry segment is already queued
        //     for (int i = 1; i <= curveSegments; i++) {
        //         float t = (float)i / curveSegments;
        //         // Cubic bezier calculation
        //         float mt = 1 - t;
        //         float mt2 = mt * mt;
        //         float mt3 = mt2 * mt;
        //         float t2 = t * t;
        //         float t3 = t2 * t;
                
        //         float px = mt3 * linearEntryEnd.x + 
        //                 3 * mt2 * t * cp1x + 
        //                 3 * mt * t2 * cp2x + 
        //                 t3 * linearExitStart.x;
                        
        //         float py = mt3 * linearEntryEnd.y + 
        //                 3 * mt2 * t * cp1y + 
        //                 3 * mt * t2 * cp2y + 
        //                 t3 * linearExitStart.y;
                
        //         // Validate and queue calculated points
        //         if (!Float.isNaN(px) && !Float.isNaN(py)) {
        //             queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
        //         }
        //     }
            
        //     // Linear exit segment points
        //     float exitDist = sqrt(
        //         (end.x - linearExitStart.x) * (end.x - linearExitStart.x) +
        //         (end.y - linearExitStart.y) * (end.y - linearExitStart.y)
        //     );
        //     int exitSegments = calculateCurveSegments(exitDist);
            
        //     // Generate points for linear exit with consistent density
        //     // Start from 1 since the last point of the curve is already queued
        //     for (int i = 1; i <= exitSegments; i++) {
        //         float t = (float)i / exitSegments;
        //         float px = linearExitStart.x + (end.x - linearExitStart.x) * t;
        //         float py = linearExitStart.y + (end.y - linearExitStart.y) * t;
                
        //         if (!Float.isNaN(px) && !Float.isNaN(py)) {
        //             queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
        //         }
        //     }
        // }

        protected void queueCurvedG0MoveWithServo(
            PathVector start, 
            PathVector end, 
            int pathIndex, 
            int lineIndex, 
            List<PathVector> previousPoints, 
            float linearDistance,
            float preActuationDistance,
            boolean isPenDown,
            int servoValue
        ) {
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
            float totalMoveDistance = sqrt(dx*dx + dy*dy);
            float dist = max(totalMoveDistance, MIN_CURVE_RADIUS);
            
            // Properly initialize tangent vectors with directional components
            PathVector startTangent = new PathVector(start.x, start.y, start.dx, start.dy);
            PathVector endTangent = new PathVector(end.x, end.y, end.dx, end.dy);
            
            if (previousPoints != null && !previousPoints.isEmpty()) {
                // Use average of last few points to stabilize direction vector
                int weight = Math.min(3, previousPoints.size());
                for (int i = 0; i < weight; i++) {
                    startTangent = startTangent.averageDirection(previousPoints.get(previousPoints.size() - 1 - i), weight);
                }
            }
            
            // Normalize tangent vectors
            startTangent.normalize();
            endTangent.normalize();
            
            // Adjust vectors to stay within work area
            startTangent = adjustVectorToWorkArea(startTangent, workAreaMinX, workAreaMaxX, workAreaMinY, workAreaMaxY);
            endTangent = adjustVectorToWorkArea(endTangent, workAreaMinX, workAreaMaxX, workAreaMinY, workAreaMaxY);
            
            // Calculate linear segment lengths (clamped to not exceed half the total distance)
            float maxLinearLength = dist / 2.0f;
            float actualLinearDistance = min(linearDistance, maxLinearLength);
            
            // Create linear entry end point
            PathVector linearEntryEnd = new PathVector(
                start.x + startTangent.dx * actualLinearDistance,
                start.y + startTangent.dy * actualLinearDistance,
                startTangent.dx,
                startTangent.dy
            );
            
            // Create linear exit start point
            float endSegmentDist = actualLinearDistance;
            
            // Check if the linear distance would take us beyond the start point
            if (endSegmentDist >= dist) {
                endSegmentDist = dist / 2; // Limit to half the total distance
            }
            
            PathVector linearExitStart = new PathVector(
                end.x - endTangent.dx * endSegmentDist,
                end.y - endTangent.dy * endSegmentDist,
                endTangent.dx,
                endTangent.dy
            );
            
            // Validate and constrain points to work area
            linearEntryEnd.x = constrain(linearEntryEnd.x, workAreaMinX, workAreaMaxX);
            linearEntryEnd.y = constrain(linearEntryEnd.y, workAreaMinY, workAreaMaxY);
            linearExitStart.x = constrain(linearExitStart.x, workAreaMinX, workAreaMaxX);
            linearExitStart.y = constrain(linearExitStart.y, workAreaMinY, workAreaMaxY);
            
            // Calculate the actual path segments and their lengths for proper pre-actuation
            
            // 1. Linear entry segment
            float entryDist = sqrt(
                (linearEntryEnd.x - start.x) * (linearEntryEnd.x - start.x) +
                (linearEntryEnd.y - start.y) * (linearEntryEnd.y - start.y)
            );
            int entrySegments = calculateCurveSegments(entryDist);
            
            // 2. Curved segment
            float curvedDx = linearExitStart.x - linearEntryEnd.x;
            float curvedDy = linearExitStart.y - linearEntryEnd.y;
            float curvedDist = max(sqrt(curvedDx*curvedDx + curvedDy*curvedDy), MIN_CURVE_RADIUS);
            int curveSegments = calculateCurveSegments(curvedDist);
            
            // 3. Linear exit segment
            float exitDist = sqrt(
                (end.x - linearExitStart.x) * (end.x - linearExitStart.x) +
                (end.y - linearExitStart.y) * (end.y - linearExitStart.y)
            );
            int exitSegments = calculateCurveSegments(exitDist);
            
            // Total path length for the entire move
            float totalPathLength = entryDist + curvedDist + exitDist;
            
            // Variables for tracking pen command injection
            boolean isPenCommandInjected = false;
            
            // ------------------------------------------------------------
            // Generate linear entry segment (no pen command injection here)
            // ------------------------------------------------------------
            
            for (int i = 0; i <= entrySegments; i++) {
                float t = (float)i / entrySegments;
                float px = start.x + (linearEntryEnd.x - start.x) * t;
                float py = start.y + (linearEntryEnd.y - start.y) * t;
                
                if (!Float.isNaN(px) && !Float.isNaN(py)) {
                    queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                }
            }
            
            // ------------------------------------------------------------
            // Generate curved segment (possibly with pen command injection if exit segment is too short)
            // ------------------------------------------------------------
            
            // Calculate control points to ensure tangent continuity with the linear segments
            float curveFactor = Math.min(1.0f, curvedDist * 0.1f);  // Adaptive curve factor
            
            // Control point 1 continues in the same direction as the entry tangent
            float cp1x = linearEntryEnd.x + startTangent.dx * curvedDist * curveFactor;
            float cp1y = linearEntryEnd.y + startTangent.dy * curvedDist * curveFactor;
            
            // Control point 2 comes from the direction of the exit tangent
            float cp2x = linearExitStart.x - endTangent.dx * curvedDist * curveFactor;
            float cp2y = linearExitStart.y - endTangent.dy * curvedDist * curveFactor;

            // Clamp control points to work area
            cp1x = constrain(cp1x, workAreaMinX, workAreaMaxX);
            cp1y = constrain(cp1y, workAreaMinY, workAreaMaxY);
            cp2x = constrain(cp2x, workAreaMinX, workAreaMaxX);
            cp2y = constrain(cp2y, workAreaMinY, workAreaMaxY);
            
            // Check if exit segment is too short for pre-actuation
            boolean useExitSegmentForPenDown = (exitDist >= preActuationDistance);
            
            // If exit segment is too short, we need to handle pre-actuation in curve segment
            if (isPenDown && draw && !useExitSegmentForPenDown) {
                float remainingDistNeeded = preActuationDistance - exitDist;
                
                // Calculate how far into the curve from the end we need to place the command
                float curvePreActPoint = curvedDist - remainingDistNeeded;
                
                // Only inject in curve if we need to (curve is long enough)
                if (curvePreActPoint > 0 && curvePreActPoint < curvedDist) {
                    float preActRatio = curvePreActPoint / curvedDist;
                    int preActSegment = Math.round(preActRatio * curveSegments);
                    
                    for (int i = 1; i <= curveSegments; i++) {
                        float t = (float)i / curveSegments;
                        
                        // Cubic bezier calculation
                        float mt = 1 - t;
                        float mt2 = mt * mt;
                        float mt3 = mt2 * mt;
                        float t2 = t * t;
                        float t3 = t2 * t;
                        
                        float px = mt3 * linearEntryEnd.x + 
                                3 * mt2 * t * cp1x + 
                                3 * mt * t2 * cp2x + 
                                t3 * linearExitStart.x;
                                
                        float py = mt3 * linearEntryEnd.y + 
                                3 * mt2 * t * cp1y + 
                                3 * mt * t2 * cp2y + 
                                t3 * linearExitStart.y;
                        
                        // Inject pen command at the right point in the curve
                        if (i == preActSegment && !isPenCommandInjected) {
                            if (!Float.isNaN(px) && !Float.isNaN(py)) {
                                queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                            }
                            
                            // Inject pen down command
                            queueGcode("M280 P0 S" + servoValue + "\n");
                            isPenCommandInjected = true;
                        }
                        else if (!Float.isNaN(px) && !Float.isNaN(py)) {
                            queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                        }
                    }
                } else {
                    // Curve is too short as well, just generate curve points
                    for (int i = 1; i <= curveSegments; i++) {
                        float t = (float)i / curveSegments;
                        
                        // Cubic bezier calculation
                        float mt = 1 - t;
                        float mt2 = mt * mt;
                        float mt3 = mt2 * mt;
                        float t2 = t * t;
                        float t3 = t2 * t;
                        
                        float px = mt3 * linearEntryEnd.x + 
                                3 * mt2 * t * cp1x + 
                                3 * mt * t2 * cp2x + 
                                t3 * linearExitStart.x;
                                
                        float py = mt3 * linearEntryEnd.y + 
                                3 * mt2 * t * cp1y + 
                                3 * mt * t2 * cp2y + 
                                t3 * linearExitStart.y;
                        
                        if (!Float.isNaN(px) && !Float.isNaN(py)) {
                            queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                        }
                    }
                }
            } else {
                // Generate normal curve points without pen command 
                // (exit segment will handle pen down)
                for (int i = 1; i <= curveSegments; i++) {
                    float t = (float)i / curveSegments;
                    
                    // Cubic bezier calculation
                    float mt = 1 - t;
                    float mt2 = mt * mt;
                    float mt3 = mt2 * mt;
                    float t2 = t * t;
                    float t3 = t2 * t;
                    
                    float px = mt3 * linearEntryEnd.x + 
                            3 * mt2 * t * cp1x + 
                            3 * mt * t2 * cp2x + 
                            t3 * linearExitStart.x;
                            
                    float py = mt3 * linearEntryEnd.y + 
                            3 * mt2 * t * cp1y + 
                            3 * mt * t2 * cp2y + 
                            t3 * linearExitStart.y;
                    
                    if (!Float.isNaN(px) && !Float.isNaN(py)) {
                        queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                    }
                }
            }
            
            // ------------------------------------------------------------
            // Generate linear exit segment with pen command injection if not already injected
            // ------------------------------------------------------------
            
            // If the exit segment is long enough for pre-actuation and pen command wasn't injected before
            if (isPenDown && draw && !isPenCommandInjected && exitDist >= preActuationDistance) {
                // Calculate the pre-actuation point within the exit segment
                float preActDistance = preActuationDistance;
                float preActRatio = 1.0f - (preActDistance / exitDist);
                int preActSegment = Math.max(0, Math.round(preActRatio * exitSegments));
                
                for (int i = 1; i <= exitSegments; i++) {
                    float t = (float)i / exitSegments;
                    float px = linearExitStart.x + (end.x - linearExitStart.x) * t;
                    float py = linearExitStart.y + (end.y - linearExitStart.y) * t;
                    
                    // Inject pen command at pre-actuation point
                    if (i == preActSegment && !isPenCommandInjected) {
                        if (!Float.isNaN(px) && !Float.isNaN(py)) {
                            queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                        }
                        
                        // Inject pen down command
                        queueGcode("M280 P0 S" + servoValue + "\n");
                        isPenCommandInjected = true;
                    }
                    else if (!Float.isNaN(px) && !Float.isNaN(py)) {
                        queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                    }
                }
            } else {
                // Generate normal exit segment points
                for (int i = 1; i <= exitSegments; i++) {
                    float t = (float)i / exitSegments;
                    float px = linearExitStart.x + (end.x - linearExitStart.x) * t;
                    float py = linearExitStart.y + (end.y - linearExitStart.y) * t;
                    
                    if (!Float.isNaN(px) && !Float.isNaN(py)) {
                        queueGcode("G0 X" + px + " Y" + (-py) + "\n", pathIndex, lineIndex);
                    }
                }
            }
            
            // If we still haven't injected the pen command (path too short), do it at the end
            if (isPenDown && draw && !isPenCommandInjected) {
                queueGcode("M280 P0 S" + servoValue + "\n");
            }
        }

        protected List<PathVector> previousPathVectors = new ArrayList<>();

        protected void addPreviousPathVector(PathVector vector) {
            previousPathVectors.add(vector);
            
            // Keep only last 5 points
            if (previousPathVectors.size() > 5) {
                previousPathVectors.remove(0);
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
            if (draw) {
                queueGcode("M280 P0 S"+servoUpValue+"\n"); // Pen up
            }
            queueGcode("G0 X" + homeX + " Y" + (-homeY) + "\n");
        }
        
        // Called at the end of path generation to cleanup/return home
        protected void generatePathCleanup() {
            if (draw) {
                queueGcode("M280 P0 S"+servoUpValue+"\n"); // Pen up
            }
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
                com.sendPenUp();
            }
        }

        public void resume() {
            if (plotting && paused) {
                // First return to the paused position with pen up
                if (!Float.isNaN(pausedX) && !Float.isNaN(pausedY)) {
                    sendImmediateCommand("G90\n"); // Ensure absolute positioning
                    com.sendPenUp();
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
        protected void drawBezierCurve(float x1, float y1, float cp1x, float cp1y, float cp2x, float cp2y, float x2, float y2) {
            noFill();
            beginShape();
            vertex(scaleX(x1), scaleY(y1));
            bezierVertex(scaleX(cp1x), scaleY(cp1y), scaleX(cp2x), scaleY(cp2y), scaleX(x2), scaleY(y2));
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
