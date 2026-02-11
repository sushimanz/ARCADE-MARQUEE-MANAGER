#ifndef PONG_H
#define PONG_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "utilities/demo_utilities.h"
#include "../definitions.h"

#define PADDLE_WIDTH 2
#define PADDLE_HEIGHT 8
#define PADDLE_SPEED 1.8
#define BALL_SIZE 2

struct Paddle {
    float y_pos;
    int8_t dir;
};

struct Ball {
    float x_pos;
    float y_pos;
    float x_vel;
    float y_vel;
};

void pong();
void resetPong();

#endif 