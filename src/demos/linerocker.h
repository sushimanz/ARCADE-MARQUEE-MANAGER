#ifndef LINEROCKER_H
#define LINEROCKER_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

extern float line1pos[2];
extern float line1vel[2];
extern float line2pos[2];
extern float line2vel[2];

void lineRocker();
void lineRockerUpdater(float pos[2], float vel[2]);

#endif