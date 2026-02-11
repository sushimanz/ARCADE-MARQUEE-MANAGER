#ifndef CONWAY_H
#define CONWAY_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

extern uint8_t con_buf[256][64];
extern uint8_t con_cur[256][64];

void conway();
int conway_count(int x, int y);
void resetConway();

#endif