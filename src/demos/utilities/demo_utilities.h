#ifndef DEMO_UTILITIES_H
#define DEMO_UTILITIES_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../../definitions.h"

extern MatrixPanel_I2S_DMA *dma_display;

uint16_t colorWheel(uint8_t pos);
uint16_t whiteBlueWheel(uint8_t pos);
void particleSim(float pos[2], float vel[2]);

#endif