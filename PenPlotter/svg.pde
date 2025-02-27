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
        
        // Process each SVG path
        for (int i = 0; i < penPaths.size(); i++) {
            Path path = penPaths.get(i);
            
            // For each path, first move to its start with pen up
            float x1 = path.getPoint(0).x * scaleX + machineWidth / 2 + offX;
            float y1 = path.getPoint(0).y * scaleY + homeY + offY;
            
            queueGcode("G0 Z5\n", i, 0); // Pen up
            queueGcode("G0 X" + x1 + " Y" + y1 + "\n", i, 0); // Move to start
            queueGcode("G0 Z0\n", i, 0); // Pen down
            
            // Then draw the path
            for (int j = 1; j < path.size(); j++) {
                float x2 = path.getPoint(j).x * scaleX + machineWidth / 2 + offX;
                float y2 = path.getPoint(j).y * scaleY + homeY + offY;
                queueGcode("G1 X" + x2 + " Y" + y2 + "\n", i, j);
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

        for (int i = 0; i < penPaths.size(); i++) {
            Path p = penPaths.get(i);

            stroke(rapidColor);
            if (i == 0)
                sline(homeX, homeY, p.first().x * scaleX + homeX + offX, p.first().y * scaleY + homeY + offY);
            else
                sline(lastX * scaleX + homeX + offX, lastY * scaleY + homeY + offY, p.first().x * scaleX + homeX + offX, p.first().y * scaleY + homeY + offY);

            stroke(i < svgPathIndex || (i == svgPathIndex && currentCommand != null) ? penColor : plotColor);
            beginShape();
            for (int j = 0; j < p.size(); j++) {
                if (i == svgPathIndex && j == svgLineIndex && currentCommand != null) {
                    // Stop drawing at current line for current path
                    break;
                }
                vertex(scaleX(p.getPoint(j).x * scaleX + homeX + offX), scaleY(p.getPoint(j).y * scaleY + homeY + offY));
            }
            endShape();
            lastX = p.last().x;
            lastY = p.last().y;
        }

        stroke(rapidColor);
        sline(lastX * scaleX + homeX + offX, lastY * scaleY + homeY + offY, homeX, homeY);

        // Draw current command movement
        super.drawCurrentCommand();
    }

    public void load(String filename) {
        File file = new File(filename);
        if (file.exists()) {
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
