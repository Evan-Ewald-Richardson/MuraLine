class SvgPlot extends Plot {
    RShape sh = null;

    int svgPathIndex = -1;        // curent path that is plotting
    int svgLineIndex = -1;        // current line within path that is plotting

    public String toString()
    {
        return "type:SVG";
    }

    public void clear() {
        sh = null;
        super.clear();
    }

    public void reset() {
        svgPathIndex = -1;
        svgLineIndex = -1;
        super.reset();
    }

    String progress()
    {
        if( svgPathIndex > 0)
            return svgPathIndex+"/"+penPaths.size();
        else
            return "0/"+penPaths.size();
    }

    protected void generatePaths() {
        if (penPaths == null || penPaths.isEmpty()) return;

        optimize(sh);
        
        // Clear previous path vectors at the start of path generation
        previousPathVectors.clear();
        
        // Track the last position and vector between paths
        PathVector lastPos = new PathVector(homeX, homeY, 0, -1); // Default upward vector at home
        
        // Add initial home position to previous vectors
        addPreviousPathVector(lastPos);
        
        // For the first path, pen will already be up, so no need for initial pen-up command
        boolean isFirstPath = true;
        
        // Process each SVG path
        for (int i = 0; i < penPaths.size(); i++) {
            Path path = penPaths.get(i);
            if (path == null || path.size() < 2) continue;
            
            // Get the first two points to determine entry direction
            float startX = path.getPoint(0).x * scaleX + machineWidth / 2 + offX;
            float startY = path.getPoint(0).y * scaleY + homeY + offY;
            float entryX = path.getPoint(1).x * scaleX + machineWidth / 2 + offX;
            float entryY = path.getPoint(1).y * scaleY + homeY + offY;
            
            // Create vector pointing from start to next point (represents path direction)
            float pathDirX = entryX - startX;
            float pathDirY = entryY - startY;
            
            // Calculate proper approach vector
            // First, calculate the vector from lastPos to startPoint
            float approachDirX = startX - lastPos.x;
            float approachDirY = startY - lastPos.y;
            float approachDist = sqrt(approachDirX * approachDirX + approachDirY * approachDirY);
            
            // Normalize
            if (approachDist > 0.0001) {
                approachDirX /= approachDist;
                approachDirY /= approachDist;
            }
            
            // Create the approach vector - position is lastPos, direction is toward start point
            PathVector approachVec = new PathVector(lastPos.x, lastPos.y, approachDirX, approachDirY);
            
            // Create the entry vector - position is path start, direction is toward second point
            PathVector entryVec = new PathVector(startX, startY, pathDirX, pathDirY);
            
            // Only for first path do we need initial pen-up - all others will have pen-up from previous path
            if (isFirstPath && draw) {
                queueGcode("M280 P0 S"+servoUpValue+"\n");
                isFirstPath = false;
            }
            
            // Generate curved approach move with pen-down command injected at the right distance
            queueCurvedG0MoveWithServo(
                approachVec, 
                entryVec, 
                i, 
                0, 
                previousPathVectors, 
                100.0f,          // Distance for approach curve
                preActuationDistanceDown,  // Pre-actuation distance 
                true,            // Pen down is true (we're approaching to draw)
                servoDownValue   // Servo value for pen down
            );
            
            // Add approach and entry vectors to previous path vectors
            addPreviousPathVector(approachVec);
            addPreviousPathVector(entryVec);
            
            // First, calculate the total path length
            float totalPathLength = 0.0f;
            for (int j = 1; j < path.size(); j++) {
                float x1 = path.getPoint(j-1).x * scaleX + machineWidth / 2 + offX;
                float y1 = path.getPoint(j-1).y * scaleY + homeY + offY;
                float x2 = path.getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y2 = path.getPoint(j).y * scaleY + homeY + offY;
                
                float segmentLength = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
                totalPathLength += segmentLength;
            }
            
            // Now draw the path with pen-up command at the appropriate pre-actuation distance
            float cumulativeLength = 0.0f;
            boolean penUpCommandIssued = false;
            
            // FIXED: Pre-calculate the point to issue pen-up command
            float penUpDistance = totalPathLength - preActuationDistanceUp;
            
            for (int j = 1; j < path.size(); j++) {
                float prevX = path.getPoint(j-1).x * scaleX + machineWidth / 2 + offX;
                float prevY = path.getPoint(j-1).y * scaleY + homeY + offY;
                float x = path.getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y = path.getPoint(j).y * scaleY + homeY + offY;
                
                if (!Float.isNaN(x) && !Float.isNaN(y)) {
                    // Create a vector for each point in the path
                    if (j > 1) {
                        PathVector pointVector = new PathVector(
                            x, y, 
                            x - prevX, 
                            y - prevY
                        );
                        
                        // Add to previous path vectors
                        addPreviousPathVector(pointVector);
                    }
                    
                    // Calculate current segment length
                    float segmentLength = sqrt(pow(x - prevX, 2) + pow(y - prevY, 2));
                    
                    // FIXED: Simplified logic for pen-up command
                    // Check if we should issue pen-up command in this segment
                    if (draw && !penUpCommandIssued && 
                        cumulativeLength <= penUpDistance && 
                        (cumulativeLength + segmentLength) >= penUpDistance) {
                        
                        // Calculate the exact point along this segment to issue pen-up
                        float distanceIntoSegment = penUpDistance - cumulativeLength;
                        float ratio = distanceIntoSegment / segmentLength;
                        
                        // Ensure ratio is within bounds to avoid precision errors
                        ratio = constrain(ratio, 0.0f, 1.0f);
                        
                        // Calculate coordinates for pen-up point
                        float penUpX = prevX + (x - prevX) * ratio;
                        float penUpY = prevY + (y - prevY) * ratio;
                        
                        // Queue G1 move to pen-up point
                        queueGcode("G1 X" + penUpX + " Y" + (-penUpY) + "\n", i, j);
                        
                        // Issue pen-up command
                        queueGcode("M280 P0 S"+servoUpValue+"\n");
                        penUpCommandIssued = true;
                        
                        // Continue to the endpoint of this segment
                        queueGcode("G1 X" + x + " Y" + (-y) + "\n", i, j);
                    } else {
                        // Normal drawing point
                        queueGcode("G1 X" + x + " Y" + (-y) + "\n", i, j);
                    }
                    
                    // Update cumulative length
                    cumulativeLength += segmentLength;
                }
            }
            
            // FIXED: We shouldn't need this anymore, but add as a failsafe
            // If we've gone through all points and still haven't issued pen-up
            if (!penUpCommandIssued && draw) {
                queueGcode("M280 P0 S"+servoUpValue+"\n");
            }
            
            // Calculate exit vector for next path
            if (path.size() >= 2) {
                int last = path.size() - 1;
                int secondLast = path.size() - 2;
                
                float exitX = path.getPoint(last).x * scaleX + machineWidth / 2 + offX;
                float exitY = path.getPoint(last).y * scaleY + homeY + offY;
                float beforeX = path.getPoint(secondLast).x * scaleX + machineWidth / 2 + offX;
                float beforeY = path.getPoint(secondLast).y * scaleY + homeY + offY;
                
                // Update last position with exit vector for next path
                lastPos = new PathVector(
                    exitX,
                    exitY,
                    exitX - beforeX,
                    exitY - beforeY
                );
                
                // Add exit vector to previous path vectors
                addPreviousPathVector(lastPos);
            }
        }
    }

    @Override
    protected void updateIndices(int pathIdx, int lineIdx) {
        svgPathIndex = pathIdx;
        svgLineIndex = lineIdx;
    }

    @Override
    public void plot() {
        if (sh != null) {
            svgPathIndex = 0;
            svgLineIndex = 0;
            super.plot();
        }
    }

    public void rotate() {
        if (penPaths == null) return;

        for (Path p : penPaths) {
            for (int j = 0; j < p.size(); j++) {
                float x = p.getPoint(j).x;
                float y = p.getPoint(j).y;

                p.getPoint(j).x = -y;
                p.getPoint(j).y = x;
            }
        }
    }

    @Override
    public void draw() {
        // Start at the home position
        float curX = homeX;
        float curY = homeY;
        
        // Set basic drawing parameters
        strokeWeight(0.1f);
        noFill();
        
        // Iterate over the stored GCode commands
        for (GCodeCommand cmd : gcodeQueueCopy) {
            strokeWeight((isPlotting() && (cmd.queueIndex > currentQueueIndex)) ? 0.1f : 0.5f);
            switch(cmd.commandType) {
                case "TRAVEL_MOVE":
                    // Set the travel move color
                    stroke(travelColor);
                    // If valid coordinates exist, draw a line from current to target
                    if (!Float.isNaN(cmd.x) && !Float.isNaN(cmd.y)) {
                        float targetX = cmd.x;
                        float targetY = -cmd.y;
                        sline(curX, curY, targetX, targetY);
                        curX = targetX;
                        curY = targetY;
                    }
                    break;
                    
                case "PAINT_MOVE":
                    // Set the paint move color
                    stroke(paintColor);
                    if (!Float.isNaN(cmd.x) && !Float.isNaN(cmd.y)) {
                        float targetX = cmd.x;
                        float targetY = -cmd.y;
                        sline(curX, curY, targetX, targetY);
                        curX = targetX;
                        curY = targetY;
                    }
                    break;
                    
                case "SERVO_CONTROL":
                    fill(cmd.isPenUp ? servoUpCircleColor : servoDownCircleColor);
                    float dotX = scaleX(curX);
                    float dotY = scaleY(curY);

                    ellipse(dotX, dotY, svgScale*userScale*10*zoomScale, svgScale*userScale*10*zoomScale);
                    noFill();

                    break;
                    
                case "OTHER":
                    // Do not draw anything for OTHER command types
                    break;
            }
        }
        
        // Optionally, draw the current command movement if needed
        // super.drawCurrentCommand();
    }

    public void load(String filename) {
        File file = new File(filename);
        if (file.exists()) {
            // RG.setPolygonizer(RG.ADAPTATIVE);
            RG.setPolygonizer(RG.UNIFORMLENGTH);
            RG.setPolygonizerLength(polygonizerLength);
            sh = RG.loadShape(filename);

            println("loaded " + filename);
            optimize(sh);
            loaded = true;
        } else
            println("Failed to load file " + filename);
    }

    public void totalPathLength() {
        long total = 0;
        float lx = homeX;
        float ly = homeY;
        for (Path path : penPaths) {
            for (int j = 0; j < path.size(); j++) {
                RPoint p = path.getPoint(j);
                total += dist(lx, ly, p.x, p.y);
                lx = p.x;
                ly = p.y;
            }
        }
    }

    public void optimize(RShape shape) {
        RPoint[][] pointPaths = shape.getPointsInPaths();
        penPaths = new ArrayList<Path>();
        ArrayList<Path> remainingPaths = new ArrayList<Path>();

        for (RPoint[] pointPath : pointPaths) {
            if (pointPath != null) {
                Path path = new Path();

                ArrayList<Path> segments = segmentPathAtAngles(pointPath);
                
                if (segments.size() >= 1) {
                    remainingPaths.addAll(segments);
                }
            }
        }

        if (remainingPaths.size() != 0) {
            Path path = nearestPath(homeX, homeY, remainingPaths);
            penPaths.add(path);

            int numPaths = remainingPaths.size();
            for (int i = 0; i < numPaths; i++) {
                RPoint last = path.last();
                path = nearestPath(last.x, last.y, remainingPaths);
                penPaths.add(path);
            }

            if (shortestSegment > 0) {
                remainingPaths = penPaths;
                penPaths = new ArrayList<Path>();

                mergePaths(shortestSegment, remainingPaths);
                removeShort(shortestSegment);
            }
            totalPathLength();
        }
    }

    private ArrayList<Path> segmentPathAtAngles(RPoint[] pointPath) {
        ArrayList<Path> segments = new ArrayList<Path>();

        // if (pointPath.length < 3) {
        //     // If the path is too short, just add it as is.
        //     Path path = new Path();
        //     for (RPoint point : pointPath) {
        //         path.addPoint(point.x, point.y);
        //     }
        //     segments.add(path);
        //     return segments;
        // }

        // Start the bulk segment with the first two points.
        Path currentSegment = new Path();
        currentSegment.addPoint(pointPath[0].x, pointPath[0].y);
        currentSegment.addPoint(pointPath[1].x, pointPath[1].y);
        
        // Track the total length of the current bulk segment.
        float currentSegmentLength = sqrt((pointPath[1].x - pointPath[0].x) * (pointPath[1].x - pointPath[0].x) +
                                        (pointPath[1].y - pointPath[0].y) * (pointPath[1].y - pointPath[0].y));

        // Calculate the initial direction vector.
        float prevDirX = pointPath[1].x - pointPath[0].x;
        float prevDirY = pointPath[1].y - pointPath[0].y;
        float prevLength = sqrt(prevDirX * prevDirX + prevDirY * prevDirY);
        if (prevLength > 0) {
            prevDirX /= prevLength;
            prevDirY /= prevLength;
        }

        // Process the remaining points.
        for (int i = 2; i < pointPath.length; i++) {
            // Compute the current vector.
            float currDirX = pointPath[i].x - pointPath[i-1].x;
            float currDirY = pointPath[i].y - pointPath[i-1].y;
            float currLength = sqrt(currDirX * currDirX + currDirY * currDirY);
            
            // The increment in bulk length is the distance between points.
            float segmentIncrement = currLength;
            
            if (currLength > 0) {
                currDirX /= currLength;
                currDirY /= currLength;
                
                // Compute the angle between the previous and current directions.
                float dotProduct = prevDirX * currDirX + prevDirY * currDirY;
                dotProduct = constrain(dotProduct, -1, 1); // avoid floating-point issues
                float angle = acos(dotProduct);
                
                if (angle > angleThreshold) {
                    // At a significant angle break, check if the current bulk segment is substantial.
                    // if (currentSegmentLength >= MIN_BULK_LENGTH && currentSegment.size() >= MIN_BULK_POINTS) {
                    //     segments.add(currentSegment);
                    // }
                    if (currentSegment.size() >= MIN_BULK_POINTS) {
                        segments.add(currentSegment);
                    }
                    // Otherwise, discard this bulk group.
                    
                    // Start a new bulk segment beginning from the last point.
                    currentSegment = new Path();
                    currentSegment.addPoint(pointPath[i-1].x, pointPath[i-1].y);
                    currentSegmentLength = 0; // reset the length counter for the new group
                }
                
                // Add the current point to the bulk segment and update the total length.
                currentSegment.addPoint(pointPath[i].x, pointPath[i].y);
                currentSegmentLength += segmentIncrement;
                
                // Update the previous direction.
                prevDirX = currDirX;
                prevDirY = currDirY;
            } else {
                // In the case of a zero-length movement, just add the point.
                currentSegment.addPoint(pointPath[i].x, pointPath[i].y);
            }
        }
        
        // After processing all points, check the final bulk segment.
        // if (currentSegmentLength >= MIN_BULK_LENGTH && currentSegment.size() >= MIN_BULK_POINTS) {
        //     segments.add(currentSegment);
        // }
        if (currentSegment.size() >= MIN_BULK_POINTS) {
            segments.add(currentSegment);
        }
        
        return segments;
    }

    public void removeShort(float len) {
        for (Path optimizedPath : penPaths) optimizedPath.removeShort(len);
    }

    public int totalPoints(ArrayList<Path> list) {
        int total = 0;
        for (Path aList : list) {
            total += aList.size();
        }
        return total;
    }

    public void mergePaths(float len, ArrayList<Path> remainingPaths) {
        Path cur = remainingPaths.get(0);
        penPaths.add(cur);

        for (int i = 1; i < remainingPaths.size(); i++) {
            Path p = remainingPaths.get(i);
            if (dist(cur.last().x, cur.last().y, p.first().x, p.first().y) < len) {
                cur.merge(p);
            } else {
                penPaths.add(p);
                cur = p;
            }
        }
    }

    public Path nearestPath(float x, float y, ArrayList<Path> remainingPaths) {
        boolean reverse = false;
        double min = Double.MAX_VALUE;
        int index = 0;
        for (int i = remainingPaths.size() - 1; i >= 0; i--) {
            Path path = remainingPaths.get(i);
            RPoint first = path.first();
            float sx = first.x;
            float sy = first.y;

            double ds = (x - sx) * (x - sx) + (y - sy) * (y - sy);
            if (ds > min) continue;

            RPoint last = path.last();
            sx = last.x;
            sy = last.y;

            double de = (x - sx) * (x - sx) + (y - sy) * (y - sy);
            double d = ds + de;
            if (d < min) {
                reverse = de < ds;
                min = d;
                index = i;
            }
        }

        Path p = remainingPaths.remove(index);
        if (reverse)
            p.reverse();
        return p;
    }
}
