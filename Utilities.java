public class Utilities {

  // http://www.easyrgb.com/index.php?X=MATH&H=02
  static float[] rgbToXyz(int r, int g, int b) {
    double var_R = ( r * 1.0 / 255.0 );
    double var_G = ( g * 1.0 / 255.0 );
    double var_B = ( b * 1.0 / 255.0 );

    if (var_R > 0.04045) {
      var_R = Math.pow(((var_R + 0.055) / 1.055), 2.4);
    } else { 
      var_R = var_R / 12.92;
    }
    if (var_G > 0.04045) {
      var_G = Math.pow(((var_G + 0.055) / 1.055 ), 2.4);
    } else {
      var_G = var_G / 12.92;
    }
    if (var_B > 0.04045) {
      var_B = Math.pow(((var_B + 0.055) / 1.055 ), 2.4);
    } else {
      var_B = var_B / 12.92;
    }

    var_R *= 100;
    var_G *= 100;
    var_B *= 100;

    // Observer = 2°, Illuminant = D65
    double x = var_R * 0.4124 + var_G * 0.3576 + var_B * 0.1805;
    double y = var_R * 0.2126 + var_G * 0.7152 + var_B * 0.0722;
    double z = var_R * 0.0193 + var_G * 0.1192 + var_B * 0.9505;
    return new float[] {
      (float)x, (float)y, (float)z
    };
  }

  // http://www.easyrgb.com/index.php?X=MATH&H=07
  static float[] xyzToLab(float[] xyz) {
    // Observer = 2°, Illuminant = D65
    double ref_X =  95.047;
    double ref_Y = 100.000;
    double ref_Z = 108.883;

    double var_X = xyz[0] / ref_X;
    double var_Y = xyz[1] / ref_Y;
    double var_Z = xyz[2] / ref_Z;

    if (var_X > 0.008856) { 
      var_X = Math.pow(var_X, 1.0/3.0);
    } else { 
      var_X = (7.787 * var_X) + (16.0 / 116.0);
    }
    if (var_Y > 0.008856) { 
      var_Y = Math.pow(var_Y, 1.0/3.0);
    } else { 
      var_Y = (7.787 * var_Y) + (16.0 / 116.0);
    }
    if (var_Z > 0.008856) { 
      var_Z = Math.pow(var_Z, 1.0/3.0);
    } else { 
      var_Z = (7.787 * var_Z) + (16.0 / 116.0);
    }

    double l = (116.0 * var_Y) - 16;
    double a = 500.0 * (var_X - var_Y);
    double b = 200.0 * (var_Y - var_Z);
    return new float[] {
      (float)l, (float)a, (float)b
    };
  }

  static int labDistance(int[] c1, int[] c2) {
    return intSqrt(square(c1[0] - c2[0]) + square(c1[1] - c2[1]) + square(c1[2] - c2[2]));
  }

  static int[] roundTriplet(float[] abc) {
    return new int[] { 
      Math.round(abc[0]), Math.round(abc[1]), Math.round(abc[2])
      };
    }

    static int square(int x) 
    {
      return x * x;
    }

  // http://www.codecodex.com/wiki/Calculate_an_integer_square_root#C.23
  static int intSqrt(int num)
  {
    if (0 == num) { 
      return 0;
    }
    int n = (num / 2) + 1;       // Initial estimate, never low  
    int n1 = (n + (num / n)) / 2;
    while (n1 < n)
    {
      n = n1;
      n1 = (n + (num / n)) / 2;
    }
    return n;
  }
}