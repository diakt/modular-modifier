import processing.core.PImage;

public class Frames {
  FramesType type;
  int count;
  int width, height;
  PImage[] data;
  int index = -1;

  public Frames(FramesType type, PImage[] data) {
    this.type = type;
    this.data = data;
    this.count = data.length;
    this.width = data[0].width;
    this.height = data[0].height;
  }

  public Frames(FramesType type, int count, int width, int height) {
    this.type = type;
    this.count = count;
    this.width = width;
    this.height = height;
    data = new PImage[count];
    index = 0;
  }

  public void addFrame(PImage frame) {
    if (index == -1) {
      System.out.println("Error: Frame set isn't modifiable!");
      return;
    }
    data[index] = frame;
    index++;
  }

  public void setFrame(int index, PImage frame) {
    data[index] = frame;
  }

  public PImage getFrame(int index) {
    return data[index];
  }
}

