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

    @Override
    protected void generatePaths() {
        if (penPaths == null || penPaths.isEmpty()) return;
        
        // Track the last position and vector between paths
        PathVector lastPos = new PathVector(homeX, homeY, 0, -1); // Default upward vector at home
        
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
            queueGcode("G0 Z5\n", i, 0);
            
            // Generate curved move using approach vector and entry vector
            queueCurvedG0Move(approachVec, entryVec, i, 0);
            
            // Pen down for drawing
            queueGcode("G0 Z0\n", i, 0);
            
            // Draw the path
            for (int j = 1; j < path.size(); j++) {
                float x = path.getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y = path.getPoint(j).y * scaleY + homeY + offY;
                
                if (!Float.isNaN(x) && !Float.isNaN(y)) {
                    queueGcode("G1 X" + x + " Y" + (-y) + "\n", i, j);
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
            RG.setPolygonizerLength(0.01f);
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

                for (int j = 0; j < pointPath.length; j++) {
                    path.addPoint(pointPath[j].x, pointPath[j].y);
                }
                remainingPaths.add(path);
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
