import java.awt.Image;
import java.awt.image.BufferedImage;
import java.awt.Toolkit;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;

import processing.core.PApplet;
import processing.core.PImage;
import gifAnimation.*;

public class FileHandler {

  PApplet parent;
  boolean inProgress = false;

  public FileHandler(PApplet parent) {
    this.parent = parent;
  }

  /*******************************************************************************
   * loads a regular image into a Frames object
   */
  public Frames loadImage(String filename) {
    // check if we're loading an animated GIF
    if (filename.substring(filename.length() - 4, filename.length()).equals(".gif")) {
      return loadGifToFrames(filename);
    } else {
      PImage frame = parent.loadImage(filename);
      return new Frames(FramesType.RGB, new PImage[] { 
        frame
      }
      );
    }
  }

  /*******************************************************************************
   * loads an animated GIF into a Frames object
   */
  public Frames loadGifToFrames(String filename) {
    Gif gif;
    try {
      gif = new Gif(parent, filename);
    }
    catch (Exception e) {
      println("Error: Couldn't open input file!");
      return null;
    }
    println("Loading GIF into frames...");
    return new Frames(FramesType.RGB, gif.getPImages());
  }

  /*******************************************************************************
   * converts a PImage into a JPEG byte array
   */
  public byte[] frameToJpegBytes(PImage input) {
    try {
      // copy RGB data from the PImage into a new BufferedImage
      BufferedImage img = new BufferedImage(input.width, input.height, 2);
      img.setRGB(0, 0, input.width, input.height, input.pixels, 0, input.width);

      // save the BufferedImage into a JPEG-encoded byte array 
      ByteArrayOutputStream output = new ByteArrayOutputStream();
      ImageIO.write(img, "jpeg", output);
      return output.toByteArray();
    }
    catch (Exception e) {
      println("failed to convert PImage to JPEG");
      return null;
    }
  }

  /*******************************************************************************
   * converts a JPEG byte array into PImage
   */
  public PImage jpegBytesToFrame(byte[] input) {
    try {
      // get raw RGB data from the JPEG
      BufferedImage frame = ImageIO.read(new ByteArrayInputStream(input));
      int[] rgbData = frame.getRGB(0, 0, frame.getWidth(), frame.getHeight(),
          null, 0, frame.getWidth());

      // copy that to a PImage
      PImage output = new PImage(frame.getWidth(), frame.getHeight(), ARGB);
      System.arraycopy(rgbData, 0, output.pixels, 0, rgbData.length);
      return output;
    }
    catch (Exception e) {
      println("failed to convert JPEG to PImage");
      return null;
    }
  }
}
