/*******************************************************************************
 * sorts/smears pixels
 */
public class PixelSorter implements Modifier {
  int threshold, smearFactor, smearIncrease;

  public PixelSorter() {
    threshold = 75;
    smearFactor = 5;
    smearIncrease = 1;
  }

  public PixelSorter(int threshold, int smearFactor, int smearIncrease) {
    this.threshold = threshold;
    this.smearFactor = smearFactor;
    this.smearIncrease = smearIncrease;
  }

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
  int glitchPercent, maxGlitches, maxGlitchSize, maxGlitchDistance;

  public BoxSwapper() {
    glitchPercent = 50;
    maxGlitches = 10;
    maxGlitchSize = 50;
    maxGlitchDistance = 25;
  }

  public BoxSwapper(int glitchPercent, int maxGlitches, 
  int maxGlitchSize, int maxGlitchDistance) {
    this.glitchPercent = glitchPercent;
    this.maxGlitches = maxGlitches;
    this.maxGlitchSize = maxGlitchSize;
    this.maxGlitchDistance = maxGlitchDistance;
  }

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
        if (block2X < 0) {
          block2X +=  blockWidth;
        } else if (block2X + blockWidth >= width) {
          block2X -= blockWidth;
        }
        if (block2Y < 0) {
          block2Y +=  blockHeight;
        } else if (block2Y + blockHeight >= height) {
          block2Y -= blockHeight;
        }

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
  int glitchPercent, maxCuts, maxCutLength;

  public JpegGlitcher() {
    glitchPercent = 20;
    maxCuts = 4;
    maxCutLength = 10;
  }

  public JpegGlitcher(int glitchPercent, int maxCuts, int maxCutLength) {
    this.glitchPercent = glitchPercent;
    this.maxCuts = maxCuts;
    this.maxCutLength = maxCutLength;
  }

  public Frames modify(Frames input) {
    println("Glitching frames (JPEG corruption)...");

    if (input.type == FramesType.SPLIT_RGB || input.type == FramesType.SPLIT_HSB) {
      glitchPercent /= 3;
    }

    // glitch a certain number of frames
    int glitchedFrames = round(input.count * glitchPercent / 100);
    for (int i = 0; i < glitchedFrames; i++) {
      int frameNumber = random.nextInt(input.count);
      byte[] frameBytes = fileH.frameToJpegBytes(input.getFrame(frameNumber));
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
      input.setFrame(frameNumber, fileH.jpegBytesToFrame(frameBytes));
      frameBytes = null;
      editableBytes = null;
    }
    return input;
  }
}


/*******************************************************************************
 * shuffles RGB subframes between adjacent frames
 */
public class RgbShuffler implements Modifier {
  int shufflePercent, maxShuffleDistance;

  public RgbShuffler() {
    shufflePercent = 40;
    maxShuffleDistance = 2;
  }

  public RgbShuffler(int shufflePercent, int maxShuffleDistance) {
    this.shufflePercent = shufflePercent;
    this.maxShuffleDistance = maxShuffleDistance;
  }

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

/*******************************************************************************
 * applies a slit-scan effect to a set of animated frames
 */
public class SlitScanner implements Modifier {
  boolean vertical, reverse;
  int stripsPerFrame;

  public SlitScanner() {
    vertical = false;
    reverse = false;
    stripsPerFrame = 1;
  }

  public SlitScanner(boolean vertical, boolean reverse, int stripsPerFrame) {
    this.vertical = vertical;
    this.reverse = reverse;
    this.stripsPerFrame = stripsPerFrame;
  }

  public Frames modify(Frames input) {
    println("Applying slit-scan effect...");

    int width = input.width;
    int height = input.height;
    int strips = stripsPerFrame * input.count;
    int[] divided;

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
    Frames output = new Frames(input.type, input.count, width, height);
    for (int i = 0; i < input.count; i++) {
      PImage frame = createImage(width, height, RGB);
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

