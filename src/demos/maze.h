#ifndef MAZE_H
#define MAZE_H

#define MAZE_TOT_X (PANEL_TOTAL_X-5)
#define MAZE_TOT_Y (PANEL_RES_Y-5)

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "utilities/demo_utilities.h"
#include "../definitions.h"

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;
extern uint16_t myWHITE;

struct Point {
    int x;
    int y;
};

void maze();
void resetMaze();
bool mazeExitCond();

#endif