#ifndef PLASMA_H
#define PLASMA_H
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"
#include <array>
#include "utilities/demo_utilities.h"

void plasma();
void resetPlasma();

#endif

//NOTE: THIS FUNCTION DOES NOT WORK; IT IS FAR TOO SLOW AT A STAGGERING O(n^4). DON'T INCLUDE IN DEMO LIST FOR NOW