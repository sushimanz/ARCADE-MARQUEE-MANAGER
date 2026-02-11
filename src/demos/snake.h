#ifndef SNAKE_H
#define SNAKE_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"
#include <list>
#include <deque>
#include <array>

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;

struct Coord {
    uint16_t x;
    uint16_t y;
};

struct Snake {
    std::deque<struct Coord> xy_seg_pos; // segment positions
    uint16_t color;
    struct Coord food_pos;
    bool death = false;
};

void snake();
void resetSnake();

#endif