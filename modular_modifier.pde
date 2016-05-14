import java.util.Random;
import java.nio.file.Path;
import java.nio.file.Paths;

/*******************************************************************************
 * user settings here
 */
int fps = 30;
String inputFilename = "example-input.gif";
Path framesFolder = Paths.get(System.getProperty("user.home"), "Desktop", "frames");

// glitch sequence goes here
Modifier[] modifiers = new Modifier[] {

  // non-exhaustive examples below

  //new Asciifyer() {{ longestSide = 80; useAllCombos = false; drawBorder = true; font="cmd"; colors = "ansi"; }},
  //new Spiralizer() {{ diameter = 800; spiralTightness = 5; stretch = 1.5; }},
  //new Doubler(),
  //new Mirrorer() {{ reverse = false; }},
  //new FrameDuplicator() {{ count = 16; }},
  //new PaletteCycler() {{ palette = "retro"; steps = 16; reverse = true; keepBlack = true; brightnessAdjust = 0; }},
  //new SlitScanner() {{ vertical = true; reverse = false; stripsPerFrame = 8; }}, 
  //new SlitScanner() {{ useMask = true; stripsPerFrame = 1; }},
  //new Polarizer() {{ diameter = 800; fill = true; }},  
  //new JpegGlitcher() {{ glitchPercent = 100; maxCuts = 10; maxCutLength = 10; }},
  //new PixelSorter() {{ threshold = 40; smearFactor = 1; smearIncrease = 2; }},
  //new BoxSwapper() {{ glitchPercent = 100; maxGlitches = 1000; maxGlitchSize = 50; maxGlitchDistance = 25; }}, 
  //new RgbShuffler() {{ shufflePercent = 100; maxShuffleDistance = 2; }},
  //new RgbSplitter(), 
  //new RgbMerger(),
  //new HsbSplitter(),
  //new HsbMerger(),
};

/*******************************************************************************
 * some variables used by the script
 */
Random random = new Random(); // RNG

boolean saved = false;
FileHandler fileH;
Frames frames;
int delay = round(1000.0 / fps); // GIF delay
int currentFrame = 0; // to control output
PImage alphaBg;
int checkerboardSize = 50;

/*******************************************************************************
 * setup
 */
void settings() {
  size(500, 500);
}

void setup() {
  println(framesFolder);
  // all processing
  fileH = new FileHandler(this);

  // load the input
  frames = fileH.loadImage(inputFilename);
  if (frames != null) {

    // set some things for the display
    frameRate(fps);

    // glitching happens here
    for (int i = 0; i < modifiers.length; i++) {
      long timerStart = System.currentTimeMillis();
      frames = modifiers[i].modify(frames);
      long timerEnd = System.currentTimeMillis();
      println("  completed in " + (timerEnd - timerStart) + "ms");
      modifiers[i] = null;
      System.gc();
    }
    surface.setSize(frames.width, frames.height);

    // generate checkerboard background for images with alpha
    PGraphics buffer = createGraphics(frames.width, frames.height);
    buffer.beginDraw();
    buffer.background(128);
    buffer.noStroke();
    buffer.fill(96);
    for (int x = 0; x < frames.width; x += checkerboardSize) {
      for (int y = 0; y < frames.height; y += checkerboardSize) {
        if ((x+y)%(checkerboardSize*2) == 0) {
          buffer.rect(x, y, checkerboardSize, checkerboardSize);
        }
      }
    }
    alphaBg = buffer.get();
    buffer.endDraw();

    println("\nPress any key to save output frames.");
  } else {
    exit();
  }
}

/*******************************************************************************
 * drawing
 */
void draw() {
  image(alphaBg, 0, 0);
  image(frames.getFrame(currentFrame), 0, 0);
  currentFrame++;
  if (currentFrame >= frames.count) {
    currentFrame = 0;
  }
}

// save the result if desired
void keyPressed() {
  if (!saved) {
    for (int i = 0; i < frames.count; i++) {
      String fileName = String.format("%04d.png", i+1);
      String filePath = Paths.get(framesFolder.toString(), fileName).toString();
      frames.getFrame(i).save(filePath);
      println("Saved frame " + (i+1) + "/" + frames.count);
    }
    saved = true;
    println("Output saved.");
  }
}
