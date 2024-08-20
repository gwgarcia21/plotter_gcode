import processing.pdf.*;

enum Colors {
  RED,
  GREEN,
  BLUE,
  ALL
}

enum Shapes {
  CIRCLES,
  HLINES,
  VLINES,
  HATCHING
}

enum Types {
  TILES,
  RASTER
}

PrintWriter gcode;
PImage mImg;
PGraphics mPg;

float mStrokeGap = 4;
float mNextCircle = 2.2;

int mTileSizeX = 1;
int mTileSizeY = 1;

/// USER SETTINGS
float mStrokeWeight = 0.1;
float mMinimumLineLength = 5;
int mHorizontalThreshold = 110;
int mVerticalThreshold = 80;
int mTileSize = 1;
int mLineGap = 3;
Colors mSelectedColor = Colors.ALL;
Shapes mSelectedShape = Shapes.HATCHING;
Types mSelectedType = Types.RASTER;
String mInputImg = "lenna.png";

void setup() {
  size(600, 800);
  mImg = loadImage(mInputImg);
  mPg = createGraphics(mImg.width, mImg.height);
  
  // Cria o arquivo de texto para escrita
  gcode = createWriter("meu_desenho.gcode");
  
  initDrawingSettings();
  
  switch (mSelectedType)
  {
    case TILES:
      drawTiles();
      break;
    case RASTER:
      drawRaster();
      break;
  }
  
  mPg.endDraw();
  endRecord();
  
  displayImages();
  
  mPg.save("meu_desenho.jpg");
  
  gcode.println("M05 S0");
  gcode.println("G1 F5000");
  gcode.println("G1 X0 Y0");
  
  // Fecha o arquivo
  gcode.close();
}

// Configurações iniciais para o desenho
void initDrawingSettings() {
  beginRecord(PDF, "minha_arte.pdf");
  noFill();
  strokeWeight(mStrokeWeight);
  mPg.beginDraw();
  mPg.background(255);
  mPg.noFill();
  mPg.stroke(0);
  mPg.strokeWeight(mStrokeWeight);
  gcode.println(";********** Plotter - gwgArts **********");
  gcode.println(";***** Input Image: " + mInputImg);
  gcode.println(";***** Stroke Weight: " + mStrokeWeight);
  gcode.println(";***** Minimum Line Length: " + mMinimumLineLength);
  gcode.println(";***** Horizontal Threshold: " + mHorizontalThreshold);
  gcode.println(";***** Vertical Threshold: " + mVerticalThreshold);
  gcode.println(";***** Tile Size: " + mTileSize);
  gcode.println(";***** Line Gap: " + mLineGap);
  gcode.println(";***** Selected Color: " + mSelectedColor);
  gcode.println(";***** Selected Shape: " + mSelectedShape);
  gcode.println(";***** Selected Type: " + mSelectedType);
  gcode.println("M05 S0");
  gcode.println("G90");
  gcode.println("G21");
  gcode.println("M4 S0");
}

// Desenha linhas horizontais e verticais
void drawRaster() {
  mImg.loadPixels();
  
  boolean alternate = false;
  mTileSizeX = mTileSize;
  mTileSizeY = mLineGap;
  // Desenha linhas horizontais
  for (int y = 0; y < mImg.height; y += mTileSizeY) {
    int startX = 0;
    boolean isDrawingX = false;
    
    if (!alternate) {
      // Percorre a linha da esquerda para a direita
      for (int x = 0; x < mImg.width; x += mTileSizeX) {
        ResultProcessTile result = processTile(x, y, startX, isDrawingX, true, mHorizontalThreshold, false);
        startX = result.start;
        isDrawingX = result.isDrawing;
      }
      // Último tile
      processTile(mImg.width-1, y, startX, isDrawingX, true, mHorizontalThreshold, true);
    }
    else {
      // Reinicia o startX para evitar desenhar linhas indesejadas
      startX = mImg.width - 1;
      isDrawingX = false;
      // Percorre a linha da direita para a esquerda
      for (int x = mImg.width - 1; x >= 0; x -= mTileSizeX) {
        ResultProcessTile result = processTile(x, y, startX, isDrawingX, true, mHorizontalThreshold, false);
        startX = result.start;
        isDrawingX = result.isDrawing;
      }
      // Último tile
      processTile(0, y, startX, isDrawingX, true, mHorizontalThreshold, true);
    }
    
    // Alterna para a próxima linha
    alternate = !alternate;
  }
  
  alternate = false;
  mTileSizeX = mLineGap;
  mTileSizeY = mTileSize;
  // Desenha linhas verticais
  for (int x = 0; x < mImg.width; x += mTileSizeX) {
    int startY = 0;
    boolean isDrawingY = false;
    
    if (!alternate) {
      // Percorre a coluna de cima para baixo
      for (int y = 0; y < mImg.height; y += mTileSizeY) {
        ResultProcessTile result = processTile(x, y, startY, isDrawingY, false, mVerticalThreshold, false);
        startY = result.start;
        isDrawingY = result.isDrawing;
      }
      // Último tile
      processTile(x, mImg.height-1, startY, isDrawingY, false, mVerticalThreshold, true);
    }
    else {
      // Reinicia o startY para evitar desenhar linhas indesejadas
      startY = mImg.height - 1;
      isDrawingY = false;
      // Percorre a coluna de baixo para cima
      for (int y = mImg.height - 1; y >= 0; y -= mTileSizeY) {
        ResultProcessTile result = processTile(x, y, startY, isDrawingY, false, mVerticalThreshold, false);
        startY = result.start;
        isDrawingY = result.isDrawing;
      }
      processTile(x, 0, startY, isDrawingY, false, mVerticalThreshold, true);
    }
    // Alterna para a próxima linha
    alternate = !alternate;
  }
}

class ResultProcessTile {
  int start = 0;
  boolean isDrawing = false;
}

// Função auxiliar para processar cada tile
ResultProcessTile processTile(int x, int y, int start, boolean isDrawing, boolean isHorizontal, int threshold, boolean lastTile) {
  int avgColor = calculateAverageColor(x, y);
  
  if (!isDrawing) {
    if (avgColor < threshold) {
      start = isHorizontal ? x : y;
      isDrawing = true;
    }
  }
  else {
    if (avgColor >= threshold || lastTile) {
      if (isHorizontal) {
        if (start < x) {
          drawLines(x, y, start, y);
        }
        else {
          drawLines(start, y, x, y);
        }
      } 
      else {
        if (start < y) {
          drawLines(x, y, x, start);
        }
        else {
          drawLines(x, start, x, y);
        }
      }
      isDrawing = false;
    }
  }
  
  ResultProcessTile result = new ResultProcessTile();
  result.start = start;
  result.isDrawing = isDrawing;
  return result; // Retorna o start e o isDrawing
}

// Desenha linhas horizontais na tela e no pdf
void drawLines(float startX, float startY, float endX, float endY) {
    if (startX == endX && startY == endY)
      return;
    float lineLength = (startX - endX) + (startY - endY);
    if (mMinimumLineLength > lineLength)
      return;
    mPg.line(startX, startY, endX, endY);
    line(startX, startY, endX, endY);
    float startXmm = pxToMm(startX);
    float startYmm = pxToMm(startY);
    float endXmm = pxToMm(endX);
    float endYmm = pxToMm(endY);
    gcode.println("G1 X" + nf(startXmm, 0, 2).replace(',', '.') + " Y-" + nf(startYmm, 0, 2).replace(',', '.') + " S0 F5000");
    gcode.println("G1 X" + nf(endXmm, 0, 2).replace(',', '.') + " Y-" + nf(endYmm, 0, 2).replace(',', '.') + " S555 F2550");
}

float pxToMm(float px) {
  float dpi = 96;
  return (px * 25.4) / dpi;
}

// Calcula a média de cor em um tile
int calculateAverageColor(int startX, int startY) {
  int sumColor = 0;
  int countPixels = 0;
  
  for (int ty = 0; ty < mTileSizeY; ty++) {
    for (int tx = 0; tx < mTileSizeX; tx++) {
      int currentX = startX + tx;
      int currentY = startY + ty;
      if (currentX < mImg.width && currentY < mImg.height) {
        int index = currentX + currentY * mImg.width;
        color c = mImg.pixels[index];
        switch (mSelectedColor) {
          case RED:
            sumColor += (int)red(c);
            break;
          case GREEN:
            sumColor += (int)green(c);
            break;
          case BLUE:
            sumColor += (int)blue(c);
            break;
          case ALL:
            sumColor += (int)((red(c) + blue(c) + green(c)) / 3);
            break;    
        }
        
        countPixels++;
      }
    }
  }
  
  return sumColor / countPixels;
}
//****************************************************


// Desenha os tiles baseados na média de cor
void drawTiles() {
  mImg.loadPixels();
  for (int y = 0; y < mImg.height; y += mTileSizeY) {
    for (int x = 0; x < mImg.width; x += mTileSizeX) {
      int avgColor = calculateAverageColor(x, y);
      switch (mSelectedShape) {
        case CIRCLES:
          drawCirclesInTile(x, y, avgColor);
          break;
        case HLINES:
          drawHorizontalLinesInTile(x, y);
          break;
        case VLINES:
          drawVerticalLinesInTile(x, y);
          break;
        case HATCHING:
          if (avgColor < 50) {
            break;
          }
          drawHorizontalLinesInTile(x, y);
          if (avgColor > 150) {
            drawVerticalLinesInTile(x, y);
          }
          break;
      }
    }
  }
}



// Desenha linhas horizontais dentro de um tile
void drawHorizontalLinesInTile(int x, int y) {
  float lineDistance = mStrokeWeight + mStrokeGap;
  int maxLines = (int)(mTileSizeY / lineDistance);
  println(maxLines);
  for (int i = 0; i < maxLines; i++) {
    drawHorizontalLinesInImages(x, y+lineDistance*i, mTileSizeX);
  }
}

// Desenha linhas verticais dentro de um tile
void drawVerticalLinesInTile(int x, int y) {
  float lineDistance = mStrokeWeight + mStrokeGap;
  int maxLines = (int)(mTileSizeX / lineDistance);
  println(maxLines);
  for (int i = 0; i < maxLines; i++) {
    drawVerticalLinesInImages(x+lineDistance*i, y, mTileSizeY);
  }
}

// Desenha linhas horizontais na tela e no pdf
void drawHorizontalLinesInImages(float x, float y, float lineSize) {
    mPg.line(x, y, x+lineSize, y);
    line(x, y, x+lineSize, y);
    gcode.println("X: " + nf(x, 0, 2) + "Y: " + nf(y, 0, 2) + "T: " + nf(lineSize, 0, 2));
}

// Desenha linhas verticais na tela e no pdf
void drawVerticalLinesInImages(float x, float y, float lineSize) {
    mPg.line(x, y, x, y+lineSize);
    line(x, y, x, y+lineSize);
}

// Desenha círculos dentro de um tile com base na média de cor
void drawCirclesInTile(int x, int y, int avgColor) {
  int maxScaleFactor = mTileSizeX / 2;
  int scaleFactor = (int)map(avgColor, 0, 255, 0, maxScaleFactor);

  for (int i = scaleFactor; i < maxScaleFactor; i--) {
    if (i == 0) break;
    float circleSize = mTileSizeX - mNextCircle * i;
    drawCirclesInImages(x + mTileSizeX / 2, y + mTileSizeY / 2, circleSize);
  }
}

// Desenha círculos na tela e no pdf
void drawCirclesInImages(float x, float y, float circleSize) {
    mPg.circle(x, y, circleSize);
    circle(x, y, circleSize);
}

// Exibe a imagem original e a nova imagem gerada
void displayImages() {
  image(mImg, 0, 0);
  image(mPg, 0, mImg.height);
}
