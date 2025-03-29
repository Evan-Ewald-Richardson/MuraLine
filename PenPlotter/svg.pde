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

    public void drawPlottedLine() {
        if (svgPathIndex < 0) {
            return;
        }
        float cx = homeX;
        float cy = homeY;

        for (int i = 0; i < penPaths.size(); i++) {
            for (int j = 0; j < penPaths.get(i).size() - 1; j++) {
                if (i > svgPathIndex || (i == svgPathIndex && j > svgLineIndex)) return;
                float x1 = penPaths.get(i).getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y1 = penPaths.get(i).getPoint(j).y * scaleY + homeY + offY;
                float x2 = penPaths.get(i).getPoint(j + 1).x * scaleX + machineWidth / 2 + offX;
                float y2 = penPaths.get(i).getPoint(j + 1).y * scaleY + homeY + offY;

                if (j == 0) {
                    // pen up
                    stroke(rapidColor);
                    sline(cx, cy, x1, y1);
                    cx = x1;
                    cy = y1;
                }

                stroke(penColor);
                sline(cx, cy, x2, y2);
                cx = x2;
                cy = y2;

                if (i == svgPathIndex && j == svgLineIndex)
                    return;
            }
        }
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
        
        // Clear previous path vectors at the start of path generation
        previousPathVectors.clear();
        
        // Track the last position and vector between paths
        PathVector lastPos = new PathVector(homeX, homeY, 0, -1); // Default upward vector at home
        
        // Add initial home position to previous vectors
        addPreviousPathVector(lastPos);
        
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
            
            // Pen up before curved move
            if (draw) {
                queueGcode("M280 P0 S"+servoUpValue+"\n");
                // queueGcode("G0 Z" + servoUpValue + "\n");
            }
            
            // Generate curved move using approach vector, entry vector, and previous path vectors
            queueCurvedG0Move(approachVec, entryVec, i, 0, previousPathVectors);
            
            // Add approach and entry vectors to previous path vectors
            addPreviousPathVector(approachVec);
            addPreviousPathVector(entryVec);
            
            // Pen down for drawing
            if (draw) {
                queueGcode("M280 P0 S"+servoDownValue+"\n");
                // queueGcode("G0 Z" + servoDownValue + "\n");
            }
            
            // Draw the path and track vector points
            for (int j = 1; j < path.size(); j++) {
                float x = path.getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y = path.getPoint(j).y * scaleY + homeY + offY;
                
                if (!Float.isNaN(x) && !Float.isNaN(y)) {
                    // Create a vector for each point in the path
                    if (j > 1) {
                        float prevX = path.getPoint(j-1).x * scaleX + machineWidth / 2 + offX;
                        float prevY = path.getPoint(j-1).y * scaleY + homeY + offY;
                        
                        PathVector pointVector = new PathVector(
                            x, y, 
                            x - prevX, 
                            y - prevY
                        );
                        
                        // Add to previous path vectors
                        addPreviousPathVector(pointVector);
                    }
                    
                    queueGcode("G0 X" + x + " Y" + (-y) + "\n", i, j);
                }
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
        // Draw completed and remaining paths
        lastX = -offX;
        lastY = -offY;
        strokeWeight(0.1f);
        noFill();
        
        float prevEndX = homeX;
        float prevEndY = homeY;
        
        for (int i = 0; i < penPaths.size(); i++) {
            Path p = penPaths.get(i);
            
            // Draw G0 move to path start
            stroke(rapidColor);
            float startX = p.first().x * scaleX + homeX + offX;
            float startY = p.first().y * scaleY + homeY + offY;
            
            // Draw curved G0 move from previous end point to current start point
            float dx = startX - prevEndX;
            float dy = startY - prevEndY;
            float dist = sqrt(dx*dx + dy*dy);
            
            if (dist > 0.01) {
                float mpx = (prevEndX + startX) / 2;
                float mpy = (prevEndY + startY) / 2;
                
                // Calculate perpendicular vector
                float perpX = -dy / dist;
                float perpY = dx / dist;
                
                // Control points
                float cp1x = prevEndX + dx/3 + perpX * dist * CURVE_HEIGHT_FACTOR;
                float cp1y = prevEndY + dy/3 + perpY * dist * CURVE_HEIGHT_FACTOR;
                float cp2x = prevEndX + dx*2/3 + perpX * dist * CURVE_HEIGHT_FACTOR;
                float cp2y = prevEndY + dy*2/3 + perpY * dist * CURVE_HEIGHT_FACTOR;
                
                drawBezierCurve(prevEndX, prevEndY, cp1x, cp1y, cp2x, cp2y, startX, startY);
            } else {
                sline(prevEndX, prevEndY, startX, startY);
            }
            
            // Draw the actual path
            stroke(i < svgPathIndex || (i == svgPathIndex && currentCommand != null) ? penColor : plotColor);
            beginShape();
            for (int j = 0; j < p.size(); j++) {
                if (i == svgPathIndex && j == svgLineIndex && currentCommand != null) {
                    // Stop drawing at current line for current path
                    break;
                }
                vertex(scaleX(p.getPoint(j).x * scaleX + homeX + offX), 
                       scaleY(p.getPoint(j).y * scaleY + homeY + offY));
            }
            endShape();
            
            // Update previous end point for next curve
            prevEndX = p.last().x * scaleX + homeX + offX;
            prevEndY = p.last().y * scaleY + homeY + offY;
        }
        
        // Draw final return to home
        stroke(rapidColor);
        float dx = homeX - prevEndX;
        float dy = homeY - prevEndY;
        float dist = sqrt(dx*dx + dy*dy);
        
        if (dist > 0.01) {
            float mpx = (prevEndX + homeX) / 2;
            float mpy = (prevEndY + homeY) / 2;
            
            // Calculate perpendicular vector
            float perpX = -dy / dist;
            float perpY = dx / dist;
            
            // Control points
            float cp1x = prevEndX + dx/3 + perpX * dist * CURVE_HEIGHT_FACTOR;
            float cp1y = prevEndY + dy/3 + perpY * dist * CURVE_HEIGHT_FACTOR;
            float cp2x = prevEndX + dx*2/3 + perpX * dist * CURVE_HEIGHT_FACTOR;
            float cp2y = prevEndY + dy*2/3 + perpY * dist * CURVE_HEIGHT_FACTOR;
            
            drawBezierCurve(prevEndX, prevEndY, cp1x, cp1y, cp2x, cp2y, homeX, homeY);
        } else {
            sline(prevEndX, prevEndY, homeX, homeY);
        }
        
        // Draw current command movement
        super.drawCurrentCommand();
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
        System.out.println("total Path length " + total);
    }

    public void optimize(RShape shape) {
        RPoint[][] pointPaths = shape.getPointsInPaths();
        penPaths = new ArrayList<Path>();
        ArrayList<Path> remainingPaths = new ArrayList<Path>();

        for (RPoint[] pointPath : pointPaths) {
            if (pointPath != null) {
                Path path = new Path();

                ArrayList<Path> segments = segmentPathAtAngles(pointPath);
                remainingPaths.addAll(segments);
            }
        }

        println("Original number of paths " + remainingPaths.size());

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
            println("number of optimized paths " + penPaths.size());

            println("number of points " + totalPoints(penPaths));
            removeShort(shortestSegment);
            println("number of opt points " + totalPoints(penPaths));
        }
        totalPathLength();
    }

    private ArrayList<Path> segmentPathAtAngles(RPoint[] pointPath) {
        ArrayList<Path> segments = new ArrayList<Path>();

        if (pointPath.length < 3) {
            // If the path is too short, just add it as is.
            Path path = new Path();
            for (RPoint point : pointPath) {
                path.addPoint(point.x, point.y);
            }
            segments.add(path);
            return segments;
        }

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
                    if (currentSegmentLength >= MIN_BULK_LENGTH && currentSegment.size() >= MIN_BULK_POINTS) {
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
        if (currentSegment.size() > 0 &&
            currentSegmentLength >= MIN_BULK_LENGTH &&
            currentSegment.size() >= MIN_BULK_POINTS) {
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
