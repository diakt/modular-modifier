import java.util.Random;
import java.nio.file.Path;
import java.nio.file.Paths;

/*******************************************************************************
 * user settings here
 */
int fps = 15;
String inputFilename = "example-input.gif";
Path framesFolder = Paths.get(System.getProperty("user.home"), "Desktop", "frames");

// glitch sequence goes here
Modifier[] modifiers = new Modifier[] {
  new SlitScanner(true, false, 4), 
  new HsbSplitter(), 
  new BoxSwapper(), 
  new HsbMerger(), 
  new JpegGlitcher(), 


  //new PixelSorter(40, 1, 2),
  //new SlitScanner(true, false, 2)
  //new FrameDuplicator(20),

  /*new HsbSplitter(), 
   //new BoxSwapper(100, 1000, 50, 25), 
   new RgbShuffler(100, 1), 
   new JpegGlitcher(),
   new HsbMerger()*/

  /*new FrameDuplicator(),
   new BoxSwapper(), 
   new RgbSplitter(), 
   new BoxSwapper(), 
   new RgbShuffler(), 
   new RgbMerger(),
   new JpegGlitcher()*/
};

/*******************************************************************************
 * some variables used by the script
 */
Random random = new Random(); // RNG

boolean saved = false;
FileHandler fileH;
Frames displayFrames; // the finished frames that will be displayed
int delay = round(1000.0 / fps); // GIF delay
int currentFrame = 0; // to control output

/*******************************************************************************
 * setup
 */
void setup() {
  println(framesFolder);
  // all processing
  fileH = new FileHandler(this);

  // load the input
  displayFrames = fileH.loadImage(inputFilename);
  if (displayFrames != null) {

    // set some things for the display
    frameRate(fps);
    size(displayFrames.width, displayFrames.height);

    // glitching happens here
    for (int i = 0; i < modifiers.length; i++) {
      displayFrames = modifiers[i].modify(displayFrames);
      if (i > 0) {
        modifiers[i - 1] = null;
      }
    }

    println("\nPress any key to save output frames.");
  } else {
    exit();
  }
}

/*******************************************************************************
 * drawing
 */
void draw() {
  image(displayFrames.getFrame(currentFrame), 0, 0);
  currentFrame++;
  if (currentFrame >= displayFrames.count) {
    currentFrame = 0;
  }
}

// save the result if desired
void keyPressed() {
  if (!saved) {
    for (int i = 0; i < displayFrames.count; i++) {
      String fileName = String.format("%04d.png", i+1);
      String filePath = Paths.get(framesFolder.toString(), fileName).toString();
      displayFrames.getFrame(i).save(filePath);
      println("Saved frame " + (i+1));
    }
    saved = true;
    println("Output saved.");
  }
}
