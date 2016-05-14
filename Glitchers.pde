import java.io.*;

/*******************************************************************************
 * converts an image to ascii
 */
public class Asciifyer implements Modifier {
  int longestSide = 80;
  boolean drawBorder = false;
  boolean noResize = false;

  String font = "cmd"; // or c64
  String colors = "ansi"; // or gameboy
  // first color is used only as background unless this is false
  boolean dontUseFirst = true;
  // uses all combinations of colors on colors - overrides dontUseFirst
  boolean useAllCombos = false;


  // forces refreshing the caches, shouldn't be required except when debugging
  boolean refreshCaches = false;

  // reduces the bit-depth of colors that are matched
  // allows the lookup cache to work more efficiently
  // original bit depth is 8 per channel
  // users shouldn't need to mess with this
  int precisionBitReduction = 4;

  int baseSize, cWidth, cHeight;
  String fontName;
  int startChar = 33;
  int endChar = 126;
  // int startChar = 0x2591;
  // int endChar = 0x2593;
  color[] palette;

  Path cacheExportFolder = Paths.get(System.getProperty("user.home"), "Desktop", "cache");
  Path colorCachePath, lookupCachePath;
  PFont characterFont;
  int charsCount, combinationsCount;
  int width, height;
  int[][] colorMap;
  HashMap<Integer, Integer> lookupCache = new HashMap<Integer, Integer>();

  boolean loadCaches() {
    println("  attempting to load color cache...");
    try {
      File colorCacheFile = new File(colorCachePath.toString());
      ObjectInputStream colorCacheInput = new ObjectInputStream(new FileInputStream(colorCacheFile));
      colorMap = (int[][]) colorCacheInput.readObject();
      colorCacheInput.close();
    } 
    catch (Exception e) {
      return false;
      //e.printStackTrace();
    }
    try {
      File lookupCacheFile = new File(lookupCachePath.toString());
      ObjectInputStream lookupCacheInput = new ObjectInputStream(new FileInputStream(lookupCacheFile));
      lookupCache = (HashMap) lookupCacheInput.readObject();
      lookupCacheInput.close();
    } 
    catch (Exception e) {
      return false;
      //e.printStackTrace();
    }
    return true;
  }

  void generateCaches() {
    println("  saving color cache...");
    try {

      // create cache folder if it doesn't exist
      File cacheFolderTemp = new File(cacheExportFolder.toString());
      if (!cacheFolderTemp.exists()) {
        cacheFolderTemp.mkdirs();
      }

      // save existing color cache
      File colorCacheFile = new File(colorCachePath.toString());
      if (!colorCacheFile.exists()) {
        colorCacheFile.createNewFile();
      }
      ObjectOutputStream colorCache = new ObjectOutputStream(new FileOutputStream(colorCacheFile));
      colorCache.writeObject(colorMap);
      colorCache.close();

      // generate full lookup cache
      int incrementAmount = 1 << precisionBitReduction;
      for (int r = 0; r < 256; r += incrementAmount) {
        println("    " + r);
        for (int g = 0; g < 256; g += incrementAmount) {
          for (int b = 0; b < 256; b += incrementAmount) {
            color c = color(r, g, b);
            int match = getClosestColor(c);
            lookupCache.put(((r << 16) | (g << 8) | b), match);
          }
        }
      }
      // save it
      File lookupCacheFile = new File(lookupCachePath.toString());
      if (!lookupCacheFile.exists()) {
        lookupCacheFile.createNewFile();
      }
      ObjectOutputStream lookupCacheOutput = new ObjectOutputStream(new FileOutputStream(lookupCacheFile));
      lookupCacheOutput.writeObject(lookupCache);
      lookupCacheOutput.close();
    }
    catch (Exception e) { 
      e.printStackTrace();
    }
  }

  void createColorMap() {
    println("  color cache not found, generating new color map...");
    colorMap = new int[combinationsCount][3];

    PGraphics buffer = createGraphics(cWidth, cHeight);
    buffer.beginDraw();
    buffer.textFont(characterFont);
    buffer.textAlign(LEFT, TOP);
    buffer.noStroke();

    // for each combination of character, foreground color, and background color
    int iStart = (!useAllCombos && dontUseFirst) ? 1 : 0;
    int iEnd = palette.length * charsCount;
    if (useAllCombos) { 
      iEnd *= palette.length;
    }
    for (int i = iStart; i < iEnd; i++) {
      drawBlock(buffer, 0, 0, i);
      // get the image of the block
      PImage cT = buffer.get(0, 0, cWidth, cHeight);
      // now resize it to determine its average color
      cT.resize(1, 1);
      color c2 = cT.pixels[0];
      // add its details to the color map
      colorMap[i] = Utilities.roundTriplet(Utilities.xyzToLab(
        Utilities.rgbToXyz(c2 >> 16 & 0xFF, c2 >> 8 & 0xFF, c2 & 0xFF)));
    }

    buffer.endDraw();
    buffer = null;
  }

  void drawBlock(PGraphics buffer, int x, int y, int i) {
    char c = (char) (startChar + (i % charsCount));
    int bC = useAllCombos ? palette[i / (palette.length*charsCount)] : palette[0];
    int fI = useAllCombos ? ((i % (palette.length*charsCount)) / charsCount) : (i / charsCount);
    int fC = palette[fI];

    buffer.fill(bC);
    buffer.rect(x, y, cWidth, cHeight);
    buffer.fill(fC);
    buffer.text(c, x, y);
  }

  void drawBlockManual(PGraphics buffer, int x, int y, char c, int bC, int fC) {
    buffer.fill(bC);
    buffer.rect(x, y, cWidth, cHeight);
    buffer.fill(fC);
    buffer.text(c, x, y);
  }

  int getClosestColor(color c) {
    int[] c1Int = Utilities.roundTriplet(Utilities.xyzToLab(Utilities.rgbToXyz(
      c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF)));
    int best = 999999999;
    int bestI = 0;
    int distance;
    for (int i = useAllCombos ? 0 : (dontUseFirst ? charsCount : 0); i < combinationsCount; i++) {
      distance = Utilities.labDistance(c1Int, colorMap[i]);
      if (distance < best) {
        best = distance;
        bestI = i;
      }
    }
    return bestI;
  }

  public Frames modify(Frames input) {
    println("Asciifying frames... ");

    if (drawBorder) { 
      longestSide -= 2;
    }

    // set up palette
    if (colors == "ansi") {
      // http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
      palette = new color[] {
        color(0, 0, 0), // black
        color(85, 85, 85), // dark grey
        color(170, 170, 170), // grey
        color(255, 255, 255), // white
        color(170, 0, 0), // dark red
        color(255, 85, 85), // red
        color(255, 255, 85), // yellow
        color(0, 170, 0), // dark green
        color(85, 255, 85), // green
        color(0, 170, 170), // dark cyan
        color(85, 255, 255), // cyan
        color(0, 0, 170), // dark blue
        color(85, 85, 255), // blue
        color(170, 0, 170), // dark magenta
        color(255, 85, 255), // magenta
        color(170, 85, 0)     // brown
      };
    } else if (colors == "gameboy") {
      palette = new color[] {
        #9bbb0e, 
        #73a067, 
        #0f380e, 
        #356237
      };
    } else {
      println("  ERROR: invalid color set specified");
      return input;
    }

    // set up font and character dimensions
    if (font == "cmd") {
      baseSize = 4;
      cWidth = baseSize * 2;
      cHeight = baseSize * 3;
      fontName = "TerminalVector";
    } else if (font == "c64") {
      baseSize = 16;
      cWidth = baseSize;
      cHeight = baseSize;
      fontName = "C64 Pro Mono";
    } else {
      println("  ERROR: invalid font specified");
      return input;
    }

    // determine the output resolution
    int originalWidth = input.getFrame(0).width;
    int originalHeight = input.getFrame(0).height;
    int w, h;
    if (!noResize) {
      float scale = 0; 
      if (originalWidth > originalHeight) {
        scale = longestSide * 1.0 / originalWidth;
      } else {
        scale = longestSide * 1.0 / originalHeight;
      }
      w = floor(originalWidth * scale); 
      h = floor(originalHeight * scale * cWidth / cHeight);
    } else {
      w = originalWidth;
      h = originalHeight;
    }

    // set up the output frames array
    int width = (w + (drawBorder ? 2 : 0)) * cWidth;
    int height = (h + (drawBorder ? 2 : 0)) * cHeight;
    Frames output = new Frames(input.type, input.count, width, height);

    // set up the font
    characterFont = createFont(fontName, cHeight, false);

    // set up the color map and blocks palette
    charsCount = endChar + 1 - startChar;
    combinationsCount = charsCount * palette.length;
    if (useAllCombos) {
      combinationsCount *= palette.length;
    }
    println("  There are ~" + combinationsCount + " possible color shades.");

    // process the color and lookup caches
    String colorCacheFilename = "colorcache";
    String lookupCacheFilename = "lookupcache";

    String cacheFilenameSuffix = "-" + font + "-" + colors;
    if (useAllCombos) { 
      cacheFilenameSuffix += "-useall";
    } else if (!dontUseFirst) { 
      cacheFilenameSuffix += "-usefirst";
    }
    cacheFilenameSuffix += ".dat";

    colorCachePath = Paths.get(cacheExportFolder.toString(), colorCacheFilename + cacheFilenameSuffix);
    lookupCachePath = Paths.get(cacheExportFolder.toString(), lookupCacheFilename + cacheFilenameSuffix);
    if (refreshCaches || !loadCaches()) {
      createColorMap(); 
      generateCaches();
    }

    // iterate over frames
    for (int f = 0; f < input.count; f++) {
      PImage currentFrame = input.getFrame(f);
      if (!noResize) {
        currentFrame.resize(w, h);
      }
      PGraphics buffer = createGraphics(width, height);
      buffer.beginDraw();
      buffer.textFont(characterFont);
      buffer.textAlign(LEFT, TOP);
      buffer.noStroke();

      // iterate over pixels
      for (int j = 0; j < h; j++) {
        for (int i = 0; i < w; i++) {
          int cOriginal = currentFrame.pixels[j*w+i];
          if (alpha(cOriginal) == 255) {
            // reduce precision if desired
            if (precisionBitReduction > 0) {
              int r = (cOriginal >> 16) & 0xFF;
              int g = (cOriginal >> 8) & 0xFF;
              int b = cOriginal & 0xFF;
              r = (r >> precisionBitReduction) << precisionBitReduction;
              g = (g >> precisionBitReduction) << precisionBitReduction;
              b = (b >> precisionBitReduction) << precisionBitReduction;
              cOriginal = ((r << 16) | (g << 8) | b);
            }
            int paletteIndex = 0;
            // check the color-mapping cache first
            if (lookupCache.containsKey(cOriginal)) {
              paletteIndex = lookupCache.get(cOriginal);
            } else {
              //paletteIndex = getClosestColor(cOriginal);
              //lookupCache.put(cOriginal, paletteIndex);
            }
            drawBlock(buffer, (i + (drawBorder ? 1 : 0)) * cWidth, 
              (j + (drawBorder ? 1 : 0)) * cHeight, paletteIndex);
          }
        }
      }
      if (drawBorder) {
        int bC = palette[0];
        int fC = palette[3];
        // horizontal
        for (int x = 1; x <= w; x++) {
          char c = (char) 0x2550;
          drawBlockManual(buffer, x*cWidth, 0, c, bC, fC);
          drawBlockManual(buffer, x*cWidth, (h+1)*cHeight, c, bC, fC);
        }
        // vertical
        for (int y = 1; y <= h; y++) {
          char c = (char) 0x2551;
          drawBlockManual(buffer, 0, y*cHeight, c, bC, fC);
          drawBlockManual(buffer, (w+1)*cWidth, y*cHeight, c, bC, fC);
        }
        // corners
        drawBlockManual(buffer, 0, 0, (char) 0x2554, bC, fC);
        drawBlockManual(buffer, 0, (h+1)*cHeight, (char) 0x255A, bC, fC);
        drawBlockManual(buffer, (w+1)*cWidth, 0, (char) 0x2557, bC, fC);
        drawBlockManual(buffer, (w+1)*cWidth, (h+1)*cHeight, (char) 0x255D, bC, fC);
      }
      output.setFrame(f, buffer.get());
      buffer.endDraw();
      buffer = null;
      println("  INFO: processed frame " + f);
    }
    return output;
  }
}

/*******************************************************************************
 * palette-cycles a frame based on brightness
 */
public class PaletteCycler implements Modifier {
  String palette = "retro";
  int steps = 16;
  boolean reverse = false;
  boolean keepBlack = true;
  int brightnessAdjust = 0;

  // palette stops are 0 to 1000 instead of 0.0 to 1.0
  HashMap<String, int[][]> palettes = new HashMap<String, int[][]>() {
    {
  put("rainbow", new int[][] {
        {0, #ff0000}, 
        {150, #ff00ff}, 
        {330, #0000ff}, 
        {490, #00ffff}, 
        {670, #00ff00}, 
        {840, #ffff00},
        {1000, #ff0000}
        });
  put("retro", new int[][] {
        {0, #cdfc00}, 
        {67, #fdfc2a}, 
        {267, #f27535}, 
        {400, #ef2474}, 
        {533, #f724b1}, 
        {667, #2f44e2}, 
        {800, #24b2d6}, 
        {933, #befe2e}, 
        {1000, #cdfc00}
        });
      put("cga", new int[][] {
        {0, #23cdcd}, 
        {62, #23cdcd}, 
        {63, #55ffff}, 
        {187, #55ffff}, 
        {188, #23cdcd}, 
        {249, #23cdcd}, 
        {250, #000000}, 
        {499, #000000}, 
        {500, #cd23cd}, 
        {562, #cd23cd}, 
        {563, #ff55ff}, 
        {687, #ff55ff}, 
        {688, #cd23cd}, 
        {749, #cd23cd}, 
        {750, #000000}
        });
      put("strobe", new int[][] {
        {0, #ffffff}, 
        {400, #ffffff}, 
        {500, #000000}
        });
      put("red", new int[][] {
        {0, #000000}, 
        {375, #cc0000}, 
        {750, #000000}
        });
      put("green", new int[][] {
        {0, #000000}, 
        {375, #00cc00}, 
        {750, #000000}
        });
    }
  };

  int interpolate(float portion, int color1, int color2) {
    //colorMode(HSB);
    float r = red(color1) + portion * (red(color2)-red(color1));
    float g = green(color1) + portion * (green(color2)-green(color1)); 
    float b = blue(color1) + portion * (blue(color2)-blue(color1));
    color c = color(r, g, b);
    //colorMode(RGB);
    return c;
  }

  int getGradientColor(int[][] gradient, float portion) {
    portion *= 1000;
    for (int i = 0; i < gradient.length; i++) {
      // point is before the first gradient stop
      if (i == 0 && portion <= gradient[i][0]) {
        return gradient[i][1];
      }
      // point is after the first gradient stop
      else if (i == gradient.length-1 && portion >= gradient[i][0]) {
        return gradient[i][1];
      } else if (i < gradient.length-1 &&
        gradient[i][0] <= portion && portion <= gradient[i+1][0]) {
        float mapped = map(portion, gradient[i][0], gradient[i+1][0], 0, 1.0);
        return interpolate(mapped, gradient[i][1], gradient[i+1][1]);
      }
    }
    return 0;
  }

  int[] generateTrimmedPalette(int[][] selectedPalette, int count) {
    int[] trimmedPalette = new int[count];
    for (int i = 0; i < count; i++) {
      trimmedPalette[i] = getGradientColor(selectedPalette, i * 1.0 / count);
    }
    return trimmedPalette;
  }

  public Frames modify(Frames input) {
    println("Palette cycling frames...");
    if (steps < 2) {
      steps = 2;
      println("  NOTE: there cannot be fewer than 2 steps");
    }
    if (steps > 256) {
      steps = 256;
      println("  NOTE: there cannot be more than 256 steps");
    }

    int[] trimmedPalette = generateTrimmedPalette(palettes.get(palette), input.count);
    int interval = floor(256 * 1.0 / steps);

    // cycle each frame
    for (int i = 0; i < input.count; i++) {
      PImage frame = input.getFrame(i);
      for (int p = 0; p < input.width * input.height; p++) {
        // skip transparent pixels
        if (alpha(frame.pixels[p]) < 128) { 
          continue;
        }

        int grey = round(brightness(frame.pixels[p]));
        grey += brightnessAdjust;
        grey = constrain(grey, 0, 255);
        grey = grey - (grey % interval);

        // replace with a cycled color if it's not a black we're preserving
        if (!(keepBlack && grey == 0)) {
          if (reverse) { grey = (steps * interval) - grey; }
          int paletteIndex = (grey / interval) % trimmedPalette.length;
          paletteIndex = (paletteIndex + i) % trimmedPalette.length;
          frame.pixels[p] = trimmedPalette[paletteIndex];
        }
        // instead of keeping original color, always force black
        else {
          frame.pixels[p] = color(0);
        }
      }
      input.setFrame(i, frame);
    }

    return input;
  }
}

/*******************************************************************************
 * creates polar projection of image
 * https://processing.org/discourse/beta/num_1265541880.html
 */
public class Polarizer implements Modifier {
  int diameter = 600;
  boolean fill = true;
  boolean invert = false;
  float rotate = HALF_PI;

  public Frames modify(Frames input) {
    println("Polar-izing frames... ");

    int srcWidth = input.width;
    int srcHeight = input.height;
    int destWidth = diameter;
    int destHeight = diameter;    

    Frames output = new Frames(input.type, input.count, destWidth, destHeight);

    // create lookup table
    int[][][] pixelLookup = new int[output.width][output.height][2];
    for (int destX = -destWidth/2; destX < destWidth/2; destX++) {
      for (int destY = -destHeight/2; destY < destHeight/2; destY++) {
        // angle of this destination pixel from center
        float a = atan2(destY, destX);
        // adjust the angle to rotate the output
        a = (a+TWO_PI+rotate) % TWO_PI;

        // distance of this destination pixel from center
        float r = sqrt(destX*destX+destY*destY);

        // maximum distance of the ellipse at this angle
        float maxR = (destWidth/2*destHeight/2) / sqrt(
          pow(destWidth/2, 2)*pow(sin(a-rotate), 2)
          + pow(destHeight/2, 2)*pow(cos(a-rotate), 2)
          )-2;
        if (fill) { 
          maxR *= 1.42;
        }

        int srcX = int(map(a, 0, TWO_PI, 0, srcWidth-1));
        int srcY = int(map(r, 0, maxR, 0, srcHeight-1));
        if (invert) { 
          srcY = (srcHeight-1) - srcY;
        } else { 
          srcX = (srcWidth-1) - srcX;
        }
        pixelLookup[destX+destWidth/2][destY+destHeight/2] = new int[] {srcX, srcY};
      }
    }

    // polarize each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      PImage des = createImage(destWidth, destHeight, ARGB);

      for (int xO = 0; xO < output.width; xO++) {
        for (int yO = 0; yO < output.height; yO++) {
          int[] lookup = pixelLookup[xO][yO];
          des.set(xO, yO, src.get(lookup[0], lookup[1]));
        }
      }

      output.addFrame(des);
    }
    return output;
  }
}

/*******************************************************************************
 * creates polar spiral projection of image
 */
public class Spiralizer implements Modifier {
  int diameter = 600;
  boolean invert = false;
  int spiralTightness = 7;
  int antiAlias = 1;

  float e = 2.71828182845904523;

  int translateCoordinate(float num, int base) {
    int numInt = round(num * base);
    while (numInt < 0) { numInt += base; }
    return numInt % base;
  }

  public Frames modify(Frames input) {
    println("Spiralizing frames... ");

    Frames output = new Frames(input.type, input.count, diameter, diameter);

    int desWidth = output.width*antiAlias;
    int desHeight = output.height*antiAlias;
    int[][][] pixelLookup = new int[desWidth][desHeight][2];
    float verticalStretch = 1;
    verticalStretch = input.height * 1.0 / input.width;

    long startTime = System.currentTimeMillis();
    for (int desX = 0; desX < desWidth; desX++) {
      for (int desY = 0; desY < desHeight; desY++) {
  
        PVector pos = new PVector((desX*2-desWidth)*1.0/desWidth,(desY*2-desHeight)*1.0/desHeight);
        PVector a = new PVector(log(pos.x*pos.x+pos.y*pos.y) * 0.5, atan2(pos.y, pos.x)+PI);
        PVector b = new PVector(spiralTightness, -verticalStretch);
        PVector transformed = new PVector(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x);
        
        int srcX = translateCoordinate(-transformed.y/TWO_PI, input.width);
        int srcY = translateCoordinate(transformed.x/(TWO_PI*verticalStretch), input.height);

        if (invert) { 
          srcX = (input.width-1)-srcX;
          srcY = (input.height-1)-srcY;
        }

        pixelLookup[desX][desY] = new int[] {srcX, srcY};
      }
    }
    println("  INFO: transform lookup completed in " + (System.currentTimeMillis() - startTime) + "ms");

    // spiralize each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      PImage des = createImage(desWidth, desHeight, ARGB);

      for (int desX = 0; desX < desWidth; desX++) {
        for (int desY = 0; desY < desHeight; desY++) {
          int[] lookup = pixelLookup[desX][desY];
          des.set(desX, desY, src.get(lookup[0], lookup[1]));
        }
      }
      des.resize(output.width, output.height);

      output.addFrame(des);
    }
    return output;
  }
}

/*******************************************************************************
 * creates polar spiral projection of image
 */
public class SpiralizerOld implements Modifier {
  int diameter = 600;
  boolean invert = false;
  int spiralTightness = 10;
  float stretch = 1;

  float e = 2.71828182845904523;
  float pythag(float x, float y) {
    return sqrt(x*x+y*y);
  }

  float spiralR(float a) {
    float x = pow(e, a/spiralTightness)*cos(a);
    float y = pow(e, a/spiralTightness)*sin(a);
    return pythag(x, y);
  }

  public Frames modify(Frames input) {
    println("Spiralizing frames... ");

    int srcWidth = input.width;
    int srcHeight = input.height;
    int destWidth = diameter;
    int destHeight = diameter;    

    Frames output = new Frames(input.type, input.count, destWidth, destHeight);

    long startTime = System.currentTimeMillis();
    int[][][] pixelLookup = new int[output.width][output.height][2];


    for (int xO = 0; xO < output.width; xO++) {
      for (int yO = 0; yO < output.height; yO++) {
        int x = xO - output.width/2;
        int y = yO - output.height/2;
        float rP = pythag(x, y);
        float aP = (atan2(y, x) + TWO_PI) % TWO_PI;

        float a1 = aP;
        float a2;
        float r1 = 0;
        float r2 = 0;
        for (int i = 0; i < spiralTightness*1.5; i++) {
          a2 = a1 + TWO_PI;
          r1 = spiralR(a1);
          r2 = spiralR(a2);
          if (r1 <= rP && rP <= r2) {
            break;
          }
          a1 = a2;
        }

        int srcX = round(pow(log(a1), 1.2)*spiralTightness/stretch*PI*input.width % input.width);
        srcX = constrain(srcX, 0, input.width-1);
        int srcY = round(map(rP, r1, r2, 0, input.height));
        srcY = constrain(srcY, 0, input.height-1);

        if (invert) { 
          srcY = (input.height-1)-srcY;
        } else { 
          srcX = (input.width-1)-srcX;
        }

        pixelLookup[xO][yO] = new int[] {srcX, srcY};
      }
    }

    println("  INFO: transform lookup completed in " + (System.currentTimeMillis() - startTime) + "ms");

    // spiralize each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      PImage des = createImage(destWidth, destHeight, ARGB);

      for (int xO = 0; xO < output.width; xO++) {
        for (int yO = 0; yO < output.height; yO++) {
          int[] lookup = pixelLookup[xO][yO];
          des.set(xO, yO, src.get(lookup[0], lookup[1]));
        }
      }

      output.addFrame(des);
    }
    return output;
  }
}

/*******************************************************************************
 * applies a slit-scan effect to a set of animated frames
 */
public class SlitScanner implements Modifier {
  boolean vertical = false;
  boolean reverse = false;
  boolean useMask = false;
  int stripsPerFrame = 1;

  private PImage generateMask(int width, int height, float step, boolean reverse) {
    PGraphics buffer = createGraphics(width, height);
    buffer.noSmooth();
    buffer.beginDraw();
    buffer.ellipseMode(CENTER);
    buffer.noStroke();
    int largerDimension = max(width, height);
    int i = round(largerDimension * 1.5);
    while (i > 1) {
      // linear, repeating
      //float brightness = (i*1.0/step % 255);
      // sinusoidal
      float brightness = (cos((i*1.0/step % 255) * TWO_PI / 255) / 2 + 0.5) * 255;
      // triangle (ping-pong)
      //float brightness = 255 - abs((i*1.0/step) % (2*255) - 255);

      if (reverse) {
        brightness = 255 - brightness;
      }
      buffer.fill(brightness);
      buffer.ellipse(width/2, height/2, i, i);
      i--;
    }
    PImage output = buffer.get();
    //output.save("test.png");
    buffer.endDraw();
    return output;
  }

  public Frames modify(Frames input) {
    println("Applying slit-scan effect...");

    int width = input.width;
    int height = input.height;
    int strips = stripsPerFrame * input.count;
    int[] divided;

    Frames output = new Frames(input.type, input.count, width, height);

    // new way - use a mask
    if (useMask) {
      PImage mask = generateMask(width, height, 5, false);
      //PImage mask = loadImage("mask9.png");
      //mask.resize(width, height);

      for (int i = 0; i < input.count; i++) {
        output.addFrame(createImage(width, height, ARGB));
      }
      for (int pixel = 0; pixel < mask.pixels.length; pixel++) {
        color level = mask.pixels[pixel] & 0xFF;
        for (int frame = 0; frame < output.count; frame++) {
          output.data[frame].pixels[pixel] = input.data[(frame+(level/2)) % input.count].pixels[pixel];
        }
      }
    }

    // traditional method
    else {
      // vertical
      if (vertical) {
        if (strips > height) {
          strips = height;
        }
        divided = divideEvenly(height, strips);
      }
      // horizontal
      else {
        if (strips > width) {
          strips = width;
        }
        divided = divideEvenly(width, strips);
      }

      int eachLength = divided[0];
      int extraRemaining = divided[1];
      int extraMod = divided[2];
      for (int i = 0; i < input.count; i++) {
        PImage frame = createImage(width, height, ARGB);
        int current = 0;
        int amount = 0;
        int x = 0;
        int y = 0; 
        int w = 0;
        int h = 0;
        for (int j = 0; j < strips; j++) {
          amount = eachLength;
          /*if (extraRemaining > 0) {
           amount++;
           extraRemaining--;
           }*/
          if (extraRemaining > 0 && (j + 1) % extraMod == 0) {
            /*if (i == 0) {
             println("here is a wider one");
             }*/
            amount++;
          }
          if (!vertical && !reverse) {
            x = width - (current + amount);
            y = 0;
            w = amount;
            h = height;
          } else if (!vertical && reverse) {
            x = current;
            y = 0;
            w = amount;
            h = height;
          } else if (vertical && !reverse) {
            x = 0;
            y = height - (current + amount);
            w = width;
            h = amount;
          } else if (vertical && reverse) {
            x = 0;
            y = current;
            w = width;
            h = amount;
          }
          /*if (i == 0) {
           println(j, current, amount);
           }*/
          frame.copy(input.data[(i+j) % input.count], x, y, w, h, x, y, w, h);
          current += amount;
        }
        output.addFrame(frame);
      }
    }

    // return what we got
    return output;
  }

  /*******************************************************************************
   * returns how many of the count each part should have,
   * how many parts should have 1 extra,
   * and the distance between the parts with extra
   */
  private int[] divideEvenly(int count, int parts) {
    int[] result = new int[3];
    float divide = count * 1.0 / parts;
    result[0] = floor(divide);
    result[1] = count - (result[0] * parts);
    if (result[1] > 0) {
      result[2] = parts / result[1];
    } else {
      result[2] = 0;
    }
    //println(count, parts, result[0], result[1], result[2]);
    return result;
  }
}

/*******************************************************************************
 * sorts/smears pixels
 */
public class PixelSorter implements Modifier {
  int threshold = 75;
  int smearFactor = 5;
  int smearIncrease = 1;

  public Frames modify(Frames input) {
    println("Sorting pixels... ");
    color c1, c2;
    int width = input.width;
    int height = input.height;
    for (int i = 0; i < input.count; i++) {
      for (int x = 0; x < width; x++) {
        for (int y = 1; y < height; y++) {
          c1 = input.data[i].get(x, y-1);
          c2 = input.data[i].get(x, y);
          if (contrastThreshold(c1, c2, threshold)) {
            color c3 = color(
              (red(c1)*(smearFactor-1)+red(c2))/smearFactor, 
              (green(c1)*(smearFactor-1)+green(c2))/smearFactor, 
              (blue(c1)*(smearFactor-1)+blue(c2))/smearFactor);
            input.data[i].set(x, y, c3);
            //input.set(x, y, c1); // simple push
          }
        }
      }
      smearFactor += smearIncrease;
    }
    return input;
  }

  boolean contrastThreshold(color c1, color c2, int threshold) {
    float difference = 0;

    difference += abs(red(c1) - red(c2));
    difference += abs(green(c1) - green(c2));
    difference += abs(blue(c1) - blue(c2));

    difference /= 3;
    if (difference > threshold) {
      return true;
    }
    return false;
  }
}

/*******************************************************************************
 * moves random blocks of random frames around
 */
public class BoxSwapper implements Modifier {
  int glitchPercent = 50;
  int maxGlitches = 10;
  int maxGlitchSize = 50;
  int maxGlitchDistance = 25;

  public Frames modify(Frames input) {
    println("Glitching frames (block moving)... ");

    if (input.type == FramesType.SPLIT_RGB || input.type == FramesType.SPLIT_HSB) {
      glitchPercent /= 3;
    }
    int width = input.width;
    int height = input.height;

    // glitch a certain number of frames
    int glitchedFrames = round(input.count * glitchPercent / 100);
    for (int i = 0; i < glitchedFrames; i++) {
      int frameNumber = random.nextInt(input.count);

      // for this frame, do a random number of glitches
      for (int j = 0; j < random.nextInt (maxGlitches) + 1; j++) {
        // determine the size and positions of the blocks to swap
        int blockWidth = random.nextInt(maxGlitchSize) + 1;
        // prefer horizontal blocks
        int blockHeight = random.nextInt(maxGlitchSize / 4) + 1;

        int block1X = random.nextInt(width - blockWidth);
        int block1Y = random.nextInt(height - blockHeight);

        // are we offsetting past the block or behind it?
        int distance = random.nextInt(maxGlitchDistance);
        if (random.nextBoolean()) {
          distance += blockWidth;
        } else {
          distance *= -1;
        }
        int block2X = block1X + distance;

        // again, for Y
        distance = random.nextInt(maxGlitchDistance);
        if (random.nextBoolean()) {
          distance += blockHeight;
        } else {
          distance *= -1;
        }
        int block2Y = block1Y + distance;

        // make sure we're not going out of bounds
        block2X = (block2X + width) % width;
        block2Y = (block2Y + height) % height;

        // finally, do the swapping
        PImage frame = input.getFrame(frameNumber);
        PImage block1 = frame.get(block1X, block1Y, blockWidth, 
          blockHeight);
        PImage block2 = frame.get(block2X, block2Y, blockWidth, 
          blockHeight);
        frame.set(block1X, block1Y, block2);
        frame.set(block2X, block2Y, block1);
        input.setFrame(frameNumber, frame);
        frame = null;
        block1 = null;
        block2 = null;
      }
    }
    return input;
  }
}

/*******************************************************************************
 * does jpeg-corruption (the #notepad trick") glitching on random frames
 */
public class JpegGlitcher implements Modifier {
  int glitchPercent = 20;
  int maxCuts = 4;
  int maxCutLength = 10;

  public Frames modify(Frames input) {
    println("Glitching frames (JPEG corruption)...");

    if (input.type == FramesType.SPLIT_RGB || input.type == FramesType.SPLIT_HSB) {
      glitchPercent /= 3;
    }

    // glitch a certain number of frames
    int glitchedFrames = round(input.count * glitchPercent / 100);
    for (int i = 0; i < glitchedFrames; i++) {
      int frameNumber = random.nextInt(input.count);
      PImage glitchedFrame = glitchFrame(input.getFrame(frameNumber));
      if (glitchedFrame != null) { 
        input.setFrame(frameNumber, glitchedFrame);
      }
    }
    return input;
  }

  private PImage glitchFrame(PImage inputFrame) {

    // because some JPEG glitches can destroy the file, we allow a few attempts
    for (int attempts = 0; attempts < 3; attempts++) {

      byte[] frameBytes = fileH.frameToJpegBytes(inputFrame);

      // we can't cut from an array, so convert it first
      ArrayList<Byte> editableBytes = new ArrayList<Byte>();
      for (byte b : frameBytes) {
        editableBytes.add(b);
      }

      // do each glitch
      for (int j = 0; j < random.nextInt (maxCuts) + 1; j++) {
        // assume the header is over by 512 bytes in
        int cutStart = random.nextInt(editableBytes.size() -
          (512 + maxCutLength)) + 512;
        for (int k = 1; k < random.nextInt (maxCutLength) + 1; k++) {
          editableBytes.remove(cutStart);
        }
      }

      // convert back to byte array
      frameBytes = new byte[editableBytes.size()];
      int l = 0;
      for (byte b : editableBytes) {
        frameBytes[l++] = b;
      }

      // convert back to PImage
      PImage outputFrame = fileH.jpegBytesToFrame(frameBytes);
      if (outputFrame != null) {
        return outputFrame;
      } else {
        println("  NOTE: temporary frame was destroyed by JPEG glitch, " +
          "trying again...");
      }
    }
    return null;
  }
}


/*******************************************************************************
 * shuffles RGB subframes between adjacent frames
 */
public class RgbShuffler implements Modifier {
  int shufflePercent = 40;
  int maxShuffleDistance = 2;

  public Frames modify(Frames input) {
    println("Shuffling RGB frames...");
    int frameCount = input.count / 3;
    int shuffles = round(frameCount * shufflePercent / 100);
    for (int i = 0; i < shuffles; i++) {
      // get the numbers of the frames being swapped between, and the channel
      // being swapped
      int frameNumber = random.nextInt(frameCount);
      int skipAmount = random.nextInt(maxShuffleDistance) + 1;
      if (random.nextBoolean()) {
        skipAmount *= -1;
      }
      int swapFrameNumber = frameNumber + skipAmount;
      if (swapFrameNumber >= frameCount) {
        swapFrameNumber -= frameCount;
      } else if (swapFrameNumber < 0) {
        swapFrameNumber += frameCount;
      }
      int channel = random.nextInt(3);
      // now we can swap
      PImage temp = input.getFrame(frameNumber * 3 + channel);
      input.setFrame(frameNumber * 3 + channel, input.getFrame(swapFrameNumber * 3 + channel));
      input.setFrame(swapFrameNumber * 3 + channel, temp);
      temp = null;
    }
    return input;
  }
}