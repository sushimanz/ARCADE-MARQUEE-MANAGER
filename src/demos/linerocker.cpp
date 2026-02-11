#include "linerocker.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "utilities/demo_utilities.h"

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;

uint8_t colorPos2 = 0;
  
float line1pos[2] = {128,30};
float line1vel[2] = {0.1,0.1};
float line2pos[2] = {128, 34};
float line2vel[2] = {-0.1, -0.1};

  //Draws a line in a psychedelic sort of way.
void lineRocker(){
  uint16_t color = colorWheel(colorPos2);
  colorPos2 += 1;

  particleSim(line1pos, line1vel); //present in demo_utilities, can be used across different demos for physics-based creations
  particleSim(line2pos, line2vel);

  dma_display->drawLine((int)line1pos[0], (int)line1pos[1], (int)line2pos[0], (int)line2pos[1],color);

  delay(10);
}

