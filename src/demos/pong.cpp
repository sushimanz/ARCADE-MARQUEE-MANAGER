#include "pong.h"

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;
extern uint16_t myWHITE;

static uint16_t pongScore[2] = {0,0};

static Paddle left_paddle = {PANEL_RES_Y / 2 - PADDLE_HEIGHT / 2, 1};
static Paddle right_paddle = {PANEL_RES_Y / 2 - PADDLE_HEIGHT / 2, -1};

static Ball ball = {PANEL_TOTAL_X / 2, PANEL_RES_Y / 2, 1, 1};

void pongScoreDisplayer(){
    dma_display->setTextWrap(false);
    dma_display->setTextSize(5);
    dma_display->setTextColor(myWHITE);
    dma_display->setCursor(20, 3);
    dma_display->print(pongScore[0]);
    dma_display->setCursor(PANEL_TOTAL_X - 40, 3);
    dma_display->print(pongScore[1]);
    delay(500);
    dma_display->setTextColor(myBLACK);
    dma_display->setCursor(20, 3);
    dma_display->print(pongScore[0]);
    dma_display->setCursor(PANEL_TOTAL_X - 40, 3);
    dma_display->print(pongScore[1]);
}

void resetPong(){
    dma_display->fillScreen(myBLACK);
}

void pong(){
    Paddle paddles[2] = {left_paddle, right_paddle};

    dma_display->fillRect(ball.x_pos, ball.y_pos, BALL_SIZE, BALL_SIZE, myBLACK); // Erase ball
    ball.x_pos += ball.x_vel;
    ball.y_pos += ball.y_vel;

    // Ball collision condtitions
    if (ball.y_pos < 0) { // Top collision
        ball.y_vel = -ball.y_vel;
        ball.y_pos = 0;
    }else if (ball.y_pos > PANEL_RES_Y - BALL_SIZE) { // Bottom collision
        ball.y_vel = -ball.y_vel;
        ball.y_pos = PANEL_RES_Y - BALL_SIZE;
    }else if (ball.x_pos < PADDLE_WIDTH) { // Ball collision with left paddle
        if (ball.y_pos + BALL_SIZE >= left_paddle.y_pos && ball.y_pos <= left_paddle.y_pos + PADDLE_HEIGHT) {
            
            ball.x_vel = random(70, 130)/100.0; // Slight speed change
            ball.y_vel = random(70, 130)/100.0;

            ball.x_pos = PADDLE_WIDTH;
        } else { // Right player scores
            ball.x_pos = PANEL_TOTAL_X / 2.0;
            ball.y_pos = PANEL_RES_Y / 2;
            ball.x_vel = -1;
            ball.y_vel = 1;

            pongScore[1]++;
            pongScoreDisplayer();
        }
    }else if (ball.x_pos > PANEL_TOTAL_X - PADDLE_WIDTH - BALL_SIZE) { // Ball collision with right paddle
        if (ball.y_pos + BALL_SIZE >= right_paddle.y_pos && ball.y_pos <= right_paddle.y_pos + PADDLE_HEIGHT) {
            
            ball.x_vel = -random(70, 130)/100.0;
            ball.y_vel = random(70, 130)/100.0;

            ball.x_pos = PANEL_TOTAL_X - PADDLE_WIDTH - BALL_SIZE;
        } else { // Left player scores
            ball.x_pos = PANEL_TOTAL_X / 2.0;
            ball.y_pos = PANEL_RES_Y / 2.0;
            ball.x_vel = 1;
            ball.y_vel = -1;

            pongScore[0]++;
            pongScoreDisplayer();
        }
    }else{ // No collision
        ball.x_pos = ball.x_pos + ball.x_vel;
        ball.y_pos = ball.y_pos + ball.y_vel;
    }
    dma_display->fillRect((int)ball.x_pos, (int)ball.y_pos, BALL_SIZE, BALL_SIZE, myWHITE); // Redraw ball



    dma_display->fillRect(0, (int)left_paddle.y_pos, PADDLE_WIDTH, PADDLE_HEIGHT, myBLACK); // left paddle erase
    dma_display->fillRect(PANEL_TOTAL_X - PADDLE_WIDTH, (int)right_paddle.y_pos, PADDLE_WIDTH, PADDLE_HEIGHT, myBLACK); // right paddle erase
    for(int i = 0; i < 2; i++){ // Update paddle positions
        if(i*(ball.x_vel / abs(ball.x_vel)) > 0 || (i-1)*(ball.x_vel / abs(ball.x_vel)) > 0){ // Move right paddle in direction of ball if ball moving right, left paddle if ball moving left
            if(paddles[i].dir == 1){
                if(paddles[i].y_pos + PADDLE_HEIGHT / 2 < ball.y_pos + BALL_SIZE / 2){
                    paddles[i].dir = 1;
                }else{
                    paddles[i].dir = -1;
                }
            }else{
                if(paddles[i].y_pos + PADDLE_HEIGHT / 2 > ball.y_pos + BALL_SIZE / 2){
                    paddles[i].dir = -1;
                }else{
                    paddles[i].dir = 1;
                }
            }
            paddles[i].y_pos += paddles[i].dir * PADDLE_SPEED; // Move paddle
        }else{
            paddles[i].y_pos += paddles[i].dir * PADDLE_SPEED;
            if(random(0, 15) == 0){ // Randomly change direction
                paddles[i].dir = -paddles[i].dir;
            }
        }
        if(paddles[i].y_pos < 0){ // Top boundary check
                paddles[i].y_pos = 0;
        }else if(paddles[i].y_pos > PANEL_RES_Y - PADDLE_HEIGHT){ // Bottom boundary
            paddles[i].y_pos = PANEL_RES_Y - PADDLE_HEIGHT;
        }
    }

    left_paddle = paddles[0];
    right_paddle = paddles[1];
    
    dma_display->fillRect(0, (int)left_paddle.y_pos, PADDLE_WIDTH, PADDLE_HEIGHT, myWHITE); // left paddle redraw
    dma_display->fillRect(PANEL_TOTAL_X - PADDLE_WIDTH, (int)right_paddle.y_pos, PADDLE_WIDTH, PADDLE_HEIGHT, myWHITE); // right paddle redraw

    delay(20);
}