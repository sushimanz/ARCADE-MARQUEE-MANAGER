#ifndef UB_H
#define UB_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

extern uint16_t myBLACK;
extern uint16_t myWHITE;
extern MatrixPanel_I2S_DMA *dma_display;

void UB(uint8_t colorPos);
void startUB();
bool UBexitCond();

#endif