#ifndef LINEROCKER_H
#define LINEROCKER_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"


void lineRocker();
void lineRockerUpdater(float pos[2], float vel[2]);

#endif