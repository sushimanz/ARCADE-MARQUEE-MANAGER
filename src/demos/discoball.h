#ifndef DISCOBALL_H
#define DISCOBALL_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

extern float ballPos[2];
extern float ballVel[2];

extern uint16_t myBLACK;

void discoBall();
void resetDiscoBall();

#endif