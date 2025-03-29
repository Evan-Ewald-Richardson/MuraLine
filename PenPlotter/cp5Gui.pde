DropdownList connectDropList;
DropdownList filterDropList;
Textlabel myTextarea;
int leftMargin = 10;
int posY = 10;
int ySpace = 36;

Slider pixelSizeSlider;
Slider speedSlider;
Slider scaleSlider;
Slider penSlider;

Slider t1Slider;
Slider t2Slider;
Slider t3Slider;
Slider t4Slider;

PImage penUpImg;
PImage penDownImg;
PImage loadImg;
PImage clearImg;
PImage pauseImg;
PImage plotImg;
PImage stepImg;
PImage nodrawImg;
PImage drawImg;

MyButton loadButton;
MyButton plotButton;
MyButton stepButton;
MyButton pauseButton;
MyButton penUpButton;
MyButton noDrawButton;

Textfield terminalInput;
Textarea chatHistory;


String[] filters = {"Stipple"};

public void reinitializeUI() {
  if (cp5 != null) {
    // Remove all controllers.
    ArrayList controllers = new ArrayList(cp5.getAll());
    for (Object c : controllers) {
      cp5.remove(c);
    }
    cp5.dispose();
  }
  // Create a new instance and re-add your UI.
  cp5 = new ControlP5(this);
  createcp5GUI();  // This should rebuild all of your UI elements (including createTerminalUI())
}

void createTerminalUI() {
    // Define margin and dimension variables
    int rightMargin = 10;  // Right margin from the edge of the window
    int bottomMargin = 40; // Bottom margin from the edge of the window
    int spacing = 10;      // Spacing between components

    int terminalHeight = 40;
    int chatHistoryHeight = 400;

    // Define widths for the terminal input and the submit button
    int terminalInputWidth = 300;
    int submitButtonWidth = 70;

    // Calculate the total block width (terminal input + spacing + submit button)
    int blockWidth = terminalInputWidth + spacing + submitButtonWidth;

    // Position the block so that its right edge is aligned with the right margin.
    int blockX = width - rightMargin - blockWidth;
    int terminalX = blockX;
    int submitButtonX = terminalX + terminalInputWidth + spacing;

    // Define chat history width (adjust as needed) and calculate its x position.
    int chatHistoryWidth = blockWidth;
    int chatHistoryX = width - rightMargin - chatHistoryWidth;

    // Calculate y positions relative to the bottom of the window.
    int terminalY = height - bottomMargin - terminalHeight;
    int chatHistoryY = terminalY - spacing - chatHistoryHeight;

    // Create chat history area (multi-line text display)
    chatHistory = cp5.addTextarea("chatHistory")
                    .setPosition(chatHistoryX, chatHistoryY)
                    .setSize(chatHistoryWidth, chatHistoryHeight)
                    .setFont(createFont("", 12))
                    .setLineHeight(14)
                    .setColor(color(30, 39, 46)) //rgb(30, 39, 46)
                    .setColorBackground(color(191, 255, 254)) //rgb(191, 255, 254)
                    .setColorForeground(color(200));

    // Create terminal input text field
    terminalInput = cp5.addTextfield("terminalInput")
                        .setPosition(terminalX, terminalY)
                        .setSize(terminalInputWidth, terminalHeight)
                        // Disable autoClear so we can control when it clears.
                        .setAutoClear(false)
                        // Attach onEnter callback to call Submit()
                        .onEnter(new CallbackListener() {
                            public void controlEvent(CallbackEvent event) {
                                Submit();
                            }
                        });

    // Create a Submit button (bang) that sends the terminal input.
    cp5.addBang("Submit")
        .setPosition(submitButtonX, terminalY)
        .setSize(submitButtonWidth, terminalHeight);
}

/**
 * This function is automatically called when the Submit button is pressed
 * or when the Enter key is pressed in the terminal input field.
 * It retrieves the text from the terminal input, prints it, appends it
 * to the chat history, and then clears the input.
 */
void Submit() {
    // Retrieve text from the terminal input field.
    String msg = cp5.get(Textfield.class, "terminalInput").getText();
    String ans = com.sendTerminalCommand(msg);
    
    if (ans != null) {
        System.out.println(ans);
        Textarea ta = cp5.get(Textarea.class, "chatHistory");
        ta.setText(ta.getText() + msg + "\n");
    }   

    // Clear the text field so it behaves consistently.
    terminalInput.setText("");
}

public Rectangle getChatHistoryBounds() {
    if (chatHistory == null) {
        return new Rectangle(0, 0, 0, 0);
    }
    // chatHistory.getPosition() returns a float array.
    float[] posArray = chatHistory.getPosition();
    int posX = (int) posArray[0];
    int posY = (int) posArray[1];
    int w = chatHistory.getWidth();
    int h = chatHistory.getHeight();
    return new Rectangle(posX, posY, w, h);
}

class MyButton extends Button {
    public PImage img;
    public int colorScheme;  // New field for color selection

    MyButton(ControlP5 cp5, String theName) {
    super(cp5, theName);
    }

    public void setImg(PImage img) {
    this.img = img;
    }

    // Setter that returns this for chaining
    public MyButton setColorScheme(int scheme) {
    this.colorScheme = scheme;
    return this;
    }
}

public MyButton addButton(String name, String label, int x, int y, int colorScheme) {
    PImage img = loadImage("icons/" + name + ".png");
    MyButton b = new MyButton(cp5, name);
    b.setPosition(x, y)
     .setSize(menuWidth, 30)
     .setCaptionLabel(label)
     .setView(new myView()); // Our custom view
    
    b.setImg(img);
    b.setColorScheme(colorScheme);  // Pass the extra parameter here.
    b.getCaptionLabel().setFont(createFont("", 10));
    return b;
}

public Slider addSlider(int x, int y, String name, String label, float min, float max, float value)
{
    Slider s = cp5.addSlider(name)
            .setCaptionLabel(label)
            .setPosition(x, y)
            .setSize(menuWidth, 17)
            .setRange(min, max)
            .setColorBackground(buttonUpColor)
            .setColorActive(buttonHoverColor)
            .setColorForeground(buttonHoverColor)
            .setColorCaptionLabel(buttonTextColor)
            .setColorValue(buttonTextColor)
            .setScrollSensitivity(1)
            .setValue(value)
            ;
    controlP5.Label l = s.getCaptionLabel();
    l.getStyle().marginTop = 0;
    l.getStyle().marginLeft = -(int)textWidth(label);
    return s;
}


class myView implements ControllerView<Button> {

    public void display(PGraphics theApplet, Button theButton) {
    // Retrieve the color scheme from the button (default to 1 if not set)
    int cs = 1;
    if (theButton instanceof MyButton) {
      cs = ((MyButton) theButton).colorScheme;
    }
    
    // Choose colors based on the scheme
    if (cs == 1) {
      buttonPressColor = buttonPressColor1;
      buttonHoverColor = buttonHoverColor1;
      buttonUpColor = buttonUpColor1;
    } else if (cs == 2) {
      buttonPressColor = buttonPressColor2;
      buttonHoverColor = buttonHoverColor2;
      buttonUpColor = buttonUpColor2;
    } else if (cs == 3) {
      buttonPressColor = buttonPressColor3;
      buttonHoverColor = buttonHoverColor3;
      buttonUpColor = buttonUpColor3;
    } else if (cs == 4) {
      buttonPressColor = buttonPressColor4;
      buttonHoverColor = buttonHoverColor4;
      buttonUpColor = buttonUpColor4;
    }

    theApplet.pushMatrix();
    if (theButton.isInside()) {
      if (theButton.isPressed()) { 
        theApplet.fill(buttonPressColor);
      } else { 
        theApplet.fill(buttonHoverColor);
      }
    } else {
      theApplet.fill(buttonUpColor);
    }

    stroke(buttonBorderColor);
    strokeWeight(0.5f);
    theApplet.rect(0, 0, theButton.getWidth(), theButton.getHeight(), 8);

    // Center the caption label.
    int x = theButton.getWidth() / 2 - theButton.getCaptionLabel().getWidth() / 2 - 10;
    int y = theButton.getHeight() / 2 - theButton.getCaptionLabel().getHeight() / 2;
    theApplet.translate(x, y);
    theButton.getCaptionLabel().setColor(buttonTextColor);
    theButton.getCaptionLabel().draw(theApplet);
    theApplet.translate(-x, -y);
    
    PImage img = ((MyButton) theButton).img;
    if (img != null) {
      if ("".equals(theButton.getCaptionLabel().getText()))
        theApplet.image(img, theButton.getWidth() / 2 - 16, -3, 32, 32);
      else
        theApplet.image(img, theButton.getWidth() - 34, 0, 32, 32);
    }
    theApplet.popMatrix();
  }
}


public void createcp5GUI()
{
    posY = 10;
    cp5 = new ControlP5(this);
    //  cp5.addFrameRate().setInterval(10).setPosition(0,height - 10).setColorValue(color(0));
    penUpImg= loadImage("icons/penUp.png");
    penDownImg= loadImage("icons/penDown.png");
    loadImg= loadImage("icons/load.png");
    clearImg= loadImage("icons/clear.png");
    pauseImg = loadImage("icons/pause.png");
    plotImg = loadImage("icons/plot.png");
    stepImg = loadImage("icons/right.png");
    nodrawImg = loadImage("icons/nodraw.png");
    drawImg = loadImage("icons/draw.png");

    connectDropList = cp5.addDropdownList("dropListConnect")
            .setPosition(leftMargin, posY)
            .setCaptionLabel("Disconnected")
            .onEnter(toFront)
            .onLeave(close)
            .setBackgroundColor(buttonUpColor)
            .setColorBackground(buttonUpColor)
            .setColorForeground(buttonHoverColor)
            .setColorActive(buttonHoverColor)
            .setColorCaptionLabel(buttonTextColor)
            .setColorValue(buttonTextColor)
            .setItemHeight(20)
            .setBarHeight(20)
            .setSize(menuWidth,(com.comPorts.size()+1)*20)
            .setOpen(false)
            .addItems(com.comPorts)
    ;

    filterDropList = cp5.addDropdownList("filterDropList")
            .setPosition(imageX+20, imageY+imageHeight+20)
            .setCaptionLabel("Stipple")
            .onEnter(toFront)
            .onLeave(close)
            .setBackgroundColor(buttonUpColor)
            .setColorBackground(buttonUpColor)
            .setColorForeground(buttonHoverColor)
            .setColorActive(buttonHoverColor)
            .setColorCaptionLabel(buttonTextColor)
            .setColorValue(buttonTextColor)
            .setItemHeight(20)
            .setBarHeight(20)
            .setSize(menuWidth, 20 * 5)
            .setOpen(false)
            .addItems(filters)
    ;

    myTextarea = cp5.addTextlabel("txt")
            .setPosition(leftMargin, posY+=20)
            .setSize(menuWidth, 30)
            .setFont(createFont("", 10))
            .setLineHeight(14)
            .setColor(textColor)
            .setColorBackground(gridColor)
            .setColorForeground(textColor)
    ;

    addButton("setHome", "Set Home", leftMargin, posY += ySpace / 2, 1);
    addButton("up", "", leftMargin+36, posY+=ySpace+4, 2).onPress(press).onRelease(release).setSize(30, 24);
    addButton("left", "", leftMargin+16, posY+=30, 2).onPress(press).onRelease(release).setSize(30, 24);
    addButton("right", "", leftMargin+56, posY, 2).onPress(press).onRelease(release).setSize(30, 24);
    addButton("down", "", leftMargin+36, posY+=30, 2).onPress(press).onRelease(release).setSize(30, 24);


    loadButton = addButton("load", "Load", leftMargin, posY+=ySpace, 3);
    plotButton = addButton("plot", "Plot", leftMargin, posY+=ySpace, 3);
    pauseButton = addButton("pause", "Pause", leftMargin, posY+=ySpace, 3);
    stepButton = addButton("step", "Step", leftMargin, posY+=ySpace, 3);
    addButton("dorotate", "Rotate", leftMargin, posY+=ySpace, 3);
    addButton("mirrorX","Flip X",leftMargin,posY+=ySpace, 3);
    addButton("mirrorY","Flip Y",leftMargin,posY+=ySpace, 3);


    scaleSlider = addSlider(leftMargin,posY += ySpace+10,"scale", "SCALE", 0.1f, 10, userScale);

    speedSlider = addSlider(leftMargin,posY += ySpace/2,"speedChanged", "SPEED", 100, 60000, 2000);
    speedSlider.onRelease(speedrelease)
            .onReleaseOutside(speedrelease);

    pixelSizeSlider = addSlider(imageX+20,imageY+imageHeight+60,"pixelSlider", "PIXEL SIZE", 2, 16, pixelSize);

    penSlider = addSlider(imageX+20,imageY+imageHeight+60+ySpace/2,"penWidth", "PEN WIDTH", 0.1f, 5, 0.5f);
    penSlider.onRelease(penrelease)
            .onReleaseOutside(penrelease);
    t1Slider = addSlider(imageX+20,imageY+imageHeight+60+ySpace/2,"t1", "T1 \\", 0, 255, 192).onRelease(thresholdrelease).onReleaseOutside(thresholdrelease);
    t2Slider = addSlider(imageX+20,imageY+imageHeight+60+2*ySpace/2,"t2", "T2 /", 0, 255, 128).onRelease(thresholdrelease).onReleaseOutside(thresholdrelease);
    t3Slider = addSlider(imageX+20,imageY+imageHeight+60+3*ySpace/2,"t3", "T3 |", 0, 255, 64).onRelease(thresholdrelease).onReleaseOutside(thresholdrelease);
    t4Slider = addSlider(imageX+20,imageY+imageHeight+60+4*ySpace/2,"t4", "T4 -", 0, 255, 32).onRelease(thresholdrelease).onReleaseOutside(thresholdrelease);

    penUpButton = addButton("penUp", "Pen Up", leftMargin, posY+=ySpace, 4);
    noDrawButton = addButton("nodraw", "No Draw", leftMargin, posY+=ySpace, 4);

    addButton("goHome", "Go Home", leftMargin, posY+=ySpace, 4);
    addButton("off", "Motors Off", leftMargin, posY+=ySpace, 4);
    

    stipplePlot.init();

    hideImageControls();
    showPenDown();

    createTerminalUI();

}

public void hideImageControls()
{

    filterDropList.setVisible(false);
    pixelSizeSlider.setVisible(false);
    t1Slider.setVisible(false);
    t2Slider.setVisible(false);
    t3Slider.setVisible(false);
    t4Slider.setVisible(false);
    penSlider.setVisible(false);

    stipplePlot.hideControls();

}

CallbackListener toFront = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        theEvent.getController().bringToFront();
        ((DropdownList)theEvent.getController()).open();
    }
};

CallbackListener close = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        ((DropdownList)theEvent.getController()).close();
    }
};

CallbackListener press = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        Button b = (Button)theEvent.getController();
        if (b.getName().equals("left"))
            jog(true, -1, 0);
        else if (b.getName().equals("right"))
            jog(true, 1, 0);
        else if (b.getName().equals("up"))
            jog(true, 0, -1);
        else if (b.getName().equals("down"))
            jog(true, 0, 1);
    }
};

CallbackListener release = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        Button b = (Button)theEvent.getController();
        if (b.getName().equals("left"))
            jog(false, 0, 0);
        else if (b.getName().equals("right"))
            jog(false, 0, 0);
        else if (b.getName().equals("up"))
            jog(false, 0, 0);
        else if (b.getName().equals("down"))
            jog(false, 0, 0);
    }
};

CallbackListener speedrelease = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        setSpeed((int)speedSlider.getValue());
    }
};

CallbackListener thresholdrelease = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        currentPlot.calculate();
    }
};

CallbackListener penrelease = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
        setPenWidth(penSlider.getValue());
    }
};


public void controlEvent(ControlEvent theEvent) {

    if (theEvent.isController()) {
        //println("event from controller : "+theEvent.getController().getValue()+" from "+theEvent.getController());

        if (("" + theEvent.getController()).contains("dropListConnect"))
        {
            Map m = connectDropList.getItem((int)theEvent.getController().getValue());
            println(m.get("name"));
            com.connect((String) m.get("name"));
        }
        else if (("" + theEvent.getController()).contains("filterDropList"))
        {
            imageMode = (int)theEvent.getController().getValue();
            println("Image Mode = " + imageMode);

            if(imageMode == STIPPLE)
            {
                currentPlot = stipplePlot;
                currentPlot.load();
            }

            hideImageControls();
            currentPlot.showControls();
            currentPlot.reset();
            currentPlot.calculate();
        }
    }
}


public void setHome()
{
    com.sendHome();
}

public void plotDone()
{
    plotButton.setCaptionLabel("Plot");
    plotButton.setImg(plotImg);
    stepButton.setCaptionLabel("Step");
    stepButton.setImg(stepImg);
    pauseButton.setCaptionLabel("Pause");
    pauseButton.setImg(pauseImg);
}

public void fileLoaded() {
    loadButton.setCaptionLabel("Clear");
    loadButton.setImg(clearImg);
}

public void load(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();

    if (b.getCaptionLabel().getText().startsWith("Load"))
    {
        loadVectorFile();
    } else
    {
        hideImageControls();
        currentPlot.clear();

        goHome();
        b.setCaptionLabel("Load");
        ((MyButton)b).setImg(loadImg);
    }
}

public void plot(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();
    if (b.getCaptionLabel().getText().contains("Abort")) {
        currentPlot.reset();
        plotButton.setCaptionLabel("Plot");
        ((MyButton)plotButton).setImg(plotImg);
        pauseButton.setCaptionLabel("Pause");
        ((MyButton)pauseButton).setImg(pauseImg);
    } else {
        if (currentPlot.isLoaded() && !currentPlot.isPlotting()) {
            currentPlot.plot();
            if(currentPlot.isPlotting()) {
                plotButton.setCaptionLabel("Abort");
                ((MyButton)plotButton).setImg(pauseImg);
                stepButton.setCaptionLabel("Step");
                ((MyButton)stepButton).setImg(stepImg);
                pauseButton.setCaptionLabel("Play");
                ((MyButton)pauseButton).setImg(plotImg);
            }
        }
    }
}

public void step(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();
    if (currentPlot.isPlotting()) {
        currentPlot.nextPlot(true, true);
    }
}

public void pause(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();
    if (currentPlot.isPlotting()) {
        if (b.getCaptionLabel().getText().equals("Pause")) {
            currentPlot.pause();
            b.setCaptionLabel("Play");
            ((MyButton)b).setImg(plotImg);
        } else {
            currentPlot.resume();
            b.setCaptionLabel("Pause");
            ((MyButton)b).setImg(pauseImg);
        }
    }
}

public void dorotate()
{
    currentPlot.rotate();
}

public void mirrorX()
{
    flipX *= -1;
    updateScale();
    currentPlot.flipX();
}
public void mirrorY()
{
    flipY *= -1;
    updateScale();
    currentPlot.flipY();
}
public void showPenUp()
{
    penUpButton.setCaptionLabel("Pen Up");
    penUpButton.setImg(penDownImg);
}

public void showPenDown()
{
    penUpButton.setCaptionLabel("Pen Down");
    penUpButton.setImg(penUpImg);
}

public void penUp(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();

    if (b.getCaptionLabel().getText().indexOf("Up") > 0)
    {
        com.sendPenUp();
        showPenDown();
    } else
    {
        com.sendPenDown();
        showPenUp();
    }
}

public void nodraw(ControlEvent theEvent)
{
    Button b = (Button) theEvent.getController();
    if(b.getCaptionLabel().getText().indexOf("No") >=0)
    {
        noDrawButton.setCaptionLabel("Draw");
        noDrawButton.setImg(drawImg);
        draw = false;
    }
    else
    {
        noDrawButton.setCaptionLabel("No Draw");
        noDrawButton.setImg(nodrawImg);
        draw = true;
    }
}

public void goHome()
{
    currentPlot.sendImmediateCommand("G90\n");
    com.sendPenUp();
    showPenDown();
    currentPlot.sendImmediateCommand("G0 X" + homeX + " Y" + (-homeY) + "\n");
    setHome();
}

public void off()
{
    currentPlot.sendImmediateCommand("M18\n"); // Motors off
}


public void speedChanged(int speed)
{
    int s = (speed/10)*10;
    if (s != speed)
        speedSlider.setValue(s);
}

public void penWidth(float width)
{
    int w = (int)(width*10);
    float f = ((float)w)/10;
    if (f != width)
        penSlider.setValue(f);
}

public void pixelSlider(int size)
{
    setPixelSize(size);
}

public void scale(float scale)
{
    setuserScale(scale);
}

public void jog(boolean jog, int x, int y)
{
    if (jog) {
        currentPlot.sendImmediateCommand("G91\n"); // Relative positioning
        jogX = x;
        jogY = y;
    } else
    {
        currentPlot.sendImmediateCommand("G90\n"); // Absolute positioning
        jogX = 0;
        jogY = 0;
    }
}
