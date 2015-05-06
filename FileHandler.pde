import java.awt.Image;
import java.awt.image.BufferedImage;
import java.awt.Toolkit;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;

import processing.core.PApplet;
import processing.core.PImage;
import gifAnimation.*;

public class FileHandler {

  PApplet parent;
  GifMaker gifExport;
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
   * converts a JPEG byte array into PImage
   * http://processing.org/discourse/beta/num_1234546778.html
   */
  public PImage jpegBytesToFrame(byte[] input) {
    Image awtImage;
    Toolkit toolkit = Toolkit.getDefaultToolkit();
    awtImage = toolkit.createImage(input);
    return loadImageMT(awtImage);
  }

  /*******************************************************************************
   * converts a PImage into a JPEG byte array
   * partially from http://wiki.processing.org/index.php/Save_as_JPEG
   * (by Yonas Sandbæk) 
   */
  public byte[] frameToJpegBytes(PImage srcimg) {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    BufferedImage img = new BufferedImage(srcimg.width, srcimg.height, 2);
    img = (BufferedImage) createImage(srcimg.width, srcimg.height);
    for (int i = 0; i < srcimg.width; i++)
      for (int j = 0; j < srcimg.height; j++)
        img.setRGB(i, j, srcimg.pixels[j * srcimg.width + i]);
    try {
      /* this is all from Java 6
       JPEGImageEncoder encoder = JPEGCodec.createJPEGEncoder(out);
       JPEGEncodeParam encpar = encoder.getDefaultJPEGEncodeParam(img);
       encpar.setQuality(1, false);
       encoder.setJPEGEncodeParam(encpar);
       encoder.encode(img);
       */
      ImageIO.write(img, "jpeg", out);
    }
    // why is an IOException thrown here?
    catch (Exception e) {
      System.out.println(e);
    }
    return out.toByteArray();
  }
}
