#include "demo_utilities.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>

extern MatrixPanel_I2S_DMA *dma_display;

// Reference for colorWheel: https://gist.github.com/davidegironi/3144efdc6d67e5df55438cc3cba613c8
uint16_t colorWheel(uint8_t pos) {
  if(pos < 85) {
    return dma_display->color565(pos * 3, 255 - pos * 3, 0);
  } else if(pos < 170) {
    pos -= 85;
    return dma_display->color565(255 - pos * 3, 0, pos * 3);
  } else {
    pos -= 170;
    return dma_display->color565(0, pos * 3, 255 - pos * 3);
  }
}

uint16_t whiteBlueWheel(uint8_t pos) {
  if(pos < 128){
    uint8_t fade = 255 - (pos * 2);
    return dma_display->color565(fade,fade, 255);
  }else{
    uint8_t rise = (pos-128)*2;
    return dma_display->color565(rise, rise, 255);
  }
}

void particleSim(float pos[2], float vel[2]){
  pos[0] += vel[0];
  pos[1] += vel[1];
  
  // Edge-bounce
  if (pos[0] <= 0) {
    vel[0] = -0.8*vel[0];
    pos[0] = 0;
  }
  if(pos[0] >= (PANEL_TOTAL_X-1)){
    vel[0] = -1.2*vel[0];
    pos[0] = PANEL_TOTAL_X-1;
  }
  if (pos[1] <= 0) {
    vel[1] = -1.2*vel[1];
    pos[1] = 0;
  }
  if(pos[1] >= (PANEL_RES_Y-1)){
    vel[1] = -0.8*vel[1];
    pos[1] = PANEL_RES_Y-1;
  }
  
  // random drift
  if (random(20) == 1) {
      vel[0] += (float)random(-200, 200) / 1000.0;
      vel[1] += (float)random(-200, 200) / 1000.0;
  }
  
  // speed-limit
  float speed = sqrt(vel[0]*vel[0] + vel[1]*vel[1]);
  if (speed > 3.0) {
      vel[0] = (vel[0] / speed) * 3.0;
      vel[1] = (vel[1] / speed) * 3.0;
  }
}