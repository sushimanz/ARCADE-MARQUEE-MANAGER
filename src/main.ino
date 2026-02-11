/*  TODO:
*   Demo transitions
*
*   DEMOS TO ADD:
*   - Bar Sorter
*   - Double Pendulum
*   - Boids
*   - Bad Apple
*   - Breakout
*   - Digital Clock (with seconds)
*   - Audio Visualizer
*/

//lib includes
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include <Adafruit_GFX.h>

#include "demos/utilities/demo_utilities.h"
#include "demos/utilities/demo.h"
#include "definitions.h"

MatrixPanel_I2S_DMA *dma_display = nullptr;

uint16_t myBLACK = dma_display->color565(0, 0, 0);
uint16_t myWHITE = dma_display->color565(255, 255, 255);

static uint8_t bag[20];   // adjust if more than 20 demos
static uint8_t bagSize = 0;
static uint8_t currentDemo = 0;
static unsigned long demoStartTime = 0;

void refillBag() {
    bagSize = demos.size();
    for (uint8_t i = 0; i < bagSize; i++) {
        bag[i] = i;
    }
}

// "Bag randomizer", the same which is used in Tetris.
// Ensures that all demos are shown once before any is repeated.
uint8_t drawFromBag() {
    if (bagSize == 0) {
        refillBag();
    }

    uint8_t index = random(0, bagSize);
    uint8_t demoID = bag[index];

    bag[index] = bag[bagSize - 1];
    bagSize--;

    return demoID;
}



void setup() {
  // Module configuration
  HUB75_I2S_CFG mxconfig(
    PANEL_RES_X,   // single-panel width
    PANEL_RES_Y,   // single-panel height
    PANEL_CHAIN    // # of panels chained 
  );

  mxconfig.gpio.e = 32;
  mxconfig.clkphase = false;
  mxconfig.driver = HUB75_I2S_CFG::FM6124;

  // Display Setup
  dma_display = new MatrixPanel_I2S_DMA(mxconfig);
  dma_display->begin();
  dma_display->setBrightness8(255); //0-255
  dma_display->clearScreen();
  dma_display->fillScreen(myBLACK);

  refillBag();
  currentDemo = drawFromBag();
  demoStartTime = millis();

  demos[currentDemo].resetFunc();
}

void loop() {
  demos[currentDemo].runFunc();
  dma_display->flipDMABuffer();

  if(millis() - demoStartTime >= demos[currentDemo].duration || demos[currentDemo].exitCond()) {
    if(bagSize == 0) {
      refillBag();
    }
    currentDemo = drawFromBag();
    demoStartTime = millis();
    demos[currentDemo].resetFunc();
  }
}
