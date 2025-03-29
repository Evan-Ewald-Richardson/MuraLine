public class GCodeCommand {
    String command;
    int pathIndex;  // Which path this command belongs to
    int lineIndex;  // Which line within the path this command represents
    int queueIndex; // Which GCode command this is within the queue
    float x = Float.NaN;  // Target X position for this command
    float y = Float.NaN;  // Target Y position for this command
    boolean isPenUp = false; // Whether this is a pen up command
    String commandType;
    boolean isExecuted = false;
    
    GCodeCommand(String cmd, int pathIdx, int lineIdx, int queueIndex) {
        command = cmd;
        pathIndex = pathIdx;
        this.lineIndex = lineIdx;
        this.queueIndex = queueIndex;
        
        if (cmd != null) {
            String trimmedCmd = cmd.trim();
            
            // Determine the command type based on the prefix or content
            if (trimmedCmd.startsWith("G0")) {
                commandType = "TRAVEL_MOVE";
            } else if (trimmedCmd.startsWith("G1")) {
                commandType = "PAINT_MOVE";
                isPenUp = true;
            } else if (trimmedCmd.startsWith("M280")) {
                commandType = "SERVO_CONTROL";
            } else {
                commandType = "OTHER";
            }
            
            // Parse X, Y and S values from the command string
            String[] parts = trimmedCmd.split(" ");
            for (String part : parts) {
                if (part.startsWith("X")) {
                    try {
                        x = Float.parseFloat(part.substring(1));
                    } catch (NumberFormatException e) {
                        // Handle parsing error if needed
                    }
                } else if (part.startsWith("Y")) {
                    try {
                        y = Float.parseFloat(part.substring(1));
                    } catch (NumberFormatException e) {
                        // Handle parsing error if needed
                    }
                } else if (part.startsWith("S")) {
                    int sValue = Integer.parseInt(part.substring(1).trim());
                    isPenUp = (sValue == servoUpValue) ? true : (sValue == servoDownValue) ? false : isPenUp;
                }
            }
        }
    }
}
