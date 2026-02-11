#include "plasma.h"
using std::array;

//NOTE: THIS FUNCTION DOES NOT WORK; IT IS FAR TOO SLOW AT A STAGGERING O(n^4). DON'T INCLUDE IN DEMO LIST FOR NOW

extern MatrixPanel_I2S_DMA *dma_display;

static uint8_t colorOffset = 0;

static uint16_t pxX[PANEL_TOTAL_X];
static uint16_t pxY[PANEL_RES_Y];

struct PlasmaParticle {
  float pos[2];
  float vel[2];
};

array<PlasmaParticle, 10> particles; // change size to adjust number of particles

void resetPlasma() {
  for (int i = 0; i < particles.size(); i++) {
    particles[i].pos[0] = random(0, PANEL_TOTAL_X);
    particles[i].pos[1] = random(0, PANEL_RES_Y);
    particles[i].vel[0] = (float)random(-100, 100) / 100.0;
    particles[i].vel[1] = (float)random(-100, 100) / 100.0;
  }

  for(int x=0; x<PANEL_TOTAL_X; x++) pxX[x] = x;
  for(int y=0; y<PANEL_RES_Y; y++) pxY[y] = y;
}

void plasma(){
    // Move and draw particles
    for (int i = 0; i < particles.size(); i++) {
        particleSim(particles[i].pos, particles[i].vel);
    }

    for(int x = 0; x < PANEL_TOTAL_X; x++) {
      for(int y = 0; y < PANEL_RES_Y; y++) {
        // write each pixel's color in accordance with all particle distances
        int colorValue = 0;
        for (int i = 0; i < particles.size(); i++) {
          int dx = (int)particles[i].pos[0] - pxX[x];
          int dy = (int)particles[i].pos[1] - pxY[y];
          int dist2 = sqrt(dx*dx + dy*dy)+1; // +1 to avoid div by 0
          colorValue += (100 / dist2) % 256;
        }
        // Map colorValue to a color
        uint16_t color = colorWheel(colorValue+colorOffset);
        dma_display->drawPixel(x, y, color);
      }
    }
    colorOffset+= sin( millis() / 1000.0 ) * 2 + sin( millis() / 500.0 ); // psychedelic color cycling
}