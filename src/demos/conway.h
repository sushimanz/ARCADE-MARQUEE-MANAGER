#ifndef CONWAY_H
#define CONWAY_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

void conway();
int conway_count(int x, int y);
void resetConway();

#endif