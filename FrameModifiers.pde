/*******************************************************************************
 * resizes frames without filtering
 */
public class PixelScaler implements Modifier {
  int scale = 2;

  public Frames modify(Frames input) {
    println("Scaling frames...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(input.type, input.count, width*scale, height*scale);
    PGraphics buffer = createGraphics(width*scale, height*scale);

    // scale each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      buffer.beginDraw();
      buffer.noStroke();
      for (int x = 0; x < src.width; x++) {
        for (int y = 0; y < src.width; y++) {
          buffer.fill(src.get(x,y));
          buffer.rect(x*scale, y*scale, scale, scale);
        }
      }
      output.addFrame(buffer.get());
      buffer.endDraw();
    }
    input = null;
    return output;
  }
}

/*******************************************************************************
 * duplicates one frame into many
 */
public class FrameDuplicator implements Modifier {
  int count = 5;

  public Frames modify(Frames input) {
    println("Duplicating frame...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(input.type, count, width, height);
    PImage frame = input.getFrame(0);
    for (int i = 0; i < count; i++) {
      output.addFrame(frame.get());
    }
    frame = null;
    return output;
  }
}

/*******************************************************************************
 * doubles an image, side by side
 */
public class Doubler implements Modifier {

  public Frames modify(Frames input) {
    println("Doubling frames... ");

    int width = input.width;
    int height = input.height;

    Frames output = new Frames(input.type, input.count, width*2, height);
    PGraphics buffer = createGraphics(width*2, height);

    // mirror each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      buffer.beginDraw();
      buffer.image(src, 0, 0);
      buffer.image(src, width, 0);
      output.addFrame(buffer.get());
      buffer.endDraw();
    }
    return output;
  }
}

/*******************************************************************************
 * mirrors an image side by side
 */
public class Mirrorer implements Modifier {
  boolean reverse = false;

  public Frames modify(Frames input) {
    println("Mirroring frames... ");

    int width = input.width;
    int height = input.height;

    Frames output = new Frames(input.type, input.count, width*2, height);
    PGraphics buffer = createGraphics(width*2, height);

    // mirror each frame
    for (int i = 0; i < input.count; i++) {
      PImage src = input.data[i];
      buffer.beginDraw();
      if (reverse) {
        buffer.image(src, width, 0);
        buffer.scale(-1, 1);
        buffer.image(src, -width, 0);
      } else {
        buffer.image(src, 0, 0);
        buffer.scale(-1, 1);
        buffer.image(src, -width*2, 0);
      }
      output.addFrame(buffer.get());
      buffer.endDraw();
    }
    return output;
  }
}

/*******************************************************************************
 * converts an array of frames 1RGB,2RGB...
 * into a new array of frames 1R,1G,1B,2R,2G,2B...
 */
public class RgbSplitter implements Modifier {
  public Frames modify(Frames input) {
    println("Splitting frames to RGB...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(FramesType.SPLIT_RGB, input.count * 3, width, height);

    for (int i = 0; i < input.count; i++) {
      // we're only using one channel, so we'll save some space here
      PImage red = new PImage(width, height, ALPHA); 
      PImage green = new PImage(width, height, ALPHA);
      PImage blue = new PImage(width, height, ALPHA);

      PImage frame = input.getFrame(i);
      for (int j = 0; j < width * height; j++) {
        int pixel = frame.pixels[j];
        red.pixels[j] = pixel >> 16 & 0xFF;
        green.pixels[j] = pixel >> 8 & 0xFF;
        blue.pixels[j] = pixel & 0xFF;
      }
      output.addFrame(red);
      output.addFrame(green);
      output.addFrame(blue);
    }
    return output;
  }
}

/*******************************************************************************
 * converts an array of frames 1R,1G,1B,2R,2G,2B...
 * into a new array of frames 1RGB,2RGB...
 */
public class RgbMerger implements Modifier {
  public Frames modify(Frames input) {
    println("Merging RGB frames...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(FramesType.RGB, input.count / 3, width, height);

    for (int i = 0; i < input.count; i += 3) {
      PImage redFrame = input.getFrame(i);
      PImage greenFrame = input.getFrame(i+1);
      PImage blueFrame = input.getFrame(i+2);
      PImage newFrame = new PImage(width, height);

      for (int j = 0; j < width * height; j++) {
        int pixel = (redFrame.pixels[j] << 16 |
          greenFrame.pixels[j] << 8 |
          blueFrame.pixels[j]);
        newFrame.pixels[j] = pixel;
      }
      output.addFrame(newFrame);
    }
    return output;
  }
}

/*******************************************************************************
 * converts an array of frames 1RGB,2RGB...
 * into a new array of frames 1H,1S,1B,2H,2S,2B...
 */
public class HsbSplitter implements Modifier {
  public Frames modify(Frames input) {
    println("Splitting frames to HSB...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(FramesType.SPLIT_HSB, input.count * 3, width, height);

    for (int i = 0; i < input.count; i++) {
      // we're only using one channel, so we'll save some space here
      PImage hFrame = new PImage(width, height, ALPHA); 
      PImage sFrame = new PImage(width, height, ALPHA);
      PImage bFrame = new PImage(width, height, ALPHA);

      PImage frame = input.getFrame(i);
      for (int j = 0; j < width * height; j++) {
        int pixel = frame.pixels[j];
        hFrame.pixels[j] = round(hue(pixel));
        sFrame.pixels[j] = round(saturation(pixel));
        bFrame.pixels[j] = round(brightness(pixel));
      }
      output.addFrame(hFrame);
      output.addFrame(sFrame);
      output.addFrame(bFrame);
    }
    return output;
  }
}

/*******************************************************************************
 * converts an array of frames 1H,1S,1B,2H,2S,2B...
 * into a new array of frames 1RGB,2RGB...
 */
public class HsbMerger implements Modifier {
  public Frames modify(Frames input) {
    println("Merging HSB frames...");
    int width = input.width;
    int height = input.height;
    Frames output = new Frames(FramesType.RGB, input.count / 3, width, height);

    colorMode(HSB);
    for (int i = 0; i < input.count; i += 3) {
      PImage hFrame = input.getFrame(i);
      PImage sFrame = input.getFrame(i+1);
      PImage bFrame = input.getFrame(i+2);
      PImage newFrame = new PImage(width, height);

      for (int j = 0; j < width * height; j++) {
        int pixel = color(hFrame.pixels[j], sFrame.pixels[j], bFrame.pixels[j]);
        newFrame.pixels[j] = pixel;
      }
      output.addFrame(newFrame);
    }
    colorMode(RGB);
    return output;
  }
}

