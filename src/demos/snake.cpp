#include "snake.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include <deque>
#include <list>

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;

static std::list<Snake> snakes;


void init_snake(){
    Snake newSnake;
    newSnake.color = dma_display->color565(random(15,255), random(15,255), random(15,255));
    struct Coord startPos;
    startPos.x = (uint16_t)random(0, PANEL_TOTAL_X-1);
    startPos.y = (uint16_t)random(0, PANEL_RES_Y-1);
    newSnake.xy_seg_pos.push_front(startPos);

    bool food_ok = false;
    while(!food_ok){
        food_ok = true;
        newSnake.food_pos.x = random(0,PANEL_TOTAL_X-1);
        newSnake.food_pos.y = random(0,PANEL_RES_Y-1);
        for(auto& snakex : snakes){
            for(auto& seg : snakex.xy_seg_pos){
                if((seg.x == newSnake.food_pos.x) && (seg.y == newSnake.food_pos.y)){
                    food_ok = false;
                    break;
                }
            }
            if(((snakex.food_pos.x != newSnake.food_pos.x) || (snakex.food_pos.y != newSnake.food_pos.y)) // make sure not checking own food
            && ((snakex.food_pos.x == newSnake.food_pos.x) && (snakex.food_pos.y == newSnake.food_pos.y))){ // if food is in the way
                food_ok = false;
                break;
            }
        }
    }
    
    newSnake.death = false; // if true, begin the "cycle of death"
    snakes.push_back(newSnake);
}

bool snake_move_checker(struct Snake &snake, uint8_t cond);

void snake(){

    if(snakes.size() < 10){
        init_snake();
    }else{
        if(random(0,100) == 0){
            init_snake();
        }
    }

    if(snakes.size() != 0){
        for(auto it = snakes.begin(); it != snakes.end();){

            struct Snake &snake = *it;

            uint16_t headsegx = snake.xy_seg_pos.front().x;
            uint16_t headsegy = snake.xy_seg_pos.front().y;

            int dx = (snake.food_pos.x - headsegx + PANEL_TOTAL_X) % PANEL_TOTAL_X;
            int dy = (snake.food_pos.y - headsegy + PANEL_RES_Y) % PANEL_RES_Y;

            uint16_t newseg[2] = {headsegx, headsegy};
            std::vector<uint8_t> dirs;

            if (!snake.death) {
                if (dx != 0) { // preferred X direction
                    if (dx < PANEL_TOTAL_X / 2) {
                        dirs.push_back(3);
                    } else {
                        dirs.push_back(2);
                    }
                }

                if (dy != 0) { // preferred Y direction
                    if (dy < PANEL_RES_Y / 2) {
                        dirs.push_back(0);
                    } else {
                        dirs.push_back(1);
                    }
                }

                // backup directions
                dirs.push_back(0);
                dirs.push_back(1);
                dirs.push_back(2);
                dirs.push_back(3);
            }

            bool moved = false;
            for (uint8_t d : dirs) {
                if (snake_move_checker(snake, d)) {
                    switch (d){
                    case 0: // Up
                        newseg[1] = (headsegy + 1) % PANEL_RES_Y;
                        break;
                    case 1: // Down
                        newseg[1] = (headsegy + PANEL_RES_Y - 1) % PANEL_RES_Y;
                        break;
                    case 2: // Left
                        newseg[0] = (headsegx + PANEL_TOTAL_X - 1) % PANEL_TOTAL_X;
                        break;
                    case 3: // Right
                        newseg[0] = (headsegx + 1) % PANEL_TOTAL_X;
                        break;
                    }
                    moved = true;
                    break;
                }
            }

            if(!moved && !snake.death){ // No possible move, death is upon us
                snake.death = true;
                dma_display->drawPixel(snake.food_pos.x, snake.food_pos.y, myBLACK); // Remove food on death
                snake.food_pos.x = PANEL_TOTAL_X + 5; // Move food out of bounds
                snake.food_pos.y = PANEL_RES_Y + 5;
            }
            if(snake.death){
                uint16_t deathSpeed = 2;
                for(uint16_t i = 0; i < deathSpeed; i++){
                    struct Coord &head = snake.xy_seg_pos.front();
                    snake.xy_seg_pos.pop_front();
                    dma_display->drawPixel(head.x, head.y, myBLACK);
                    if(snake.xy_seg_pos.size() == 0){
                        break;
                    }
                }
            }
            if(snake.xy_seg_pos.size() <= 0){ // Death animation has completed
                it = snakes.erase(it);
                continue;
            }
            
            if(!snake.death){ //Update snake if not dead
                snake.xy_seg_pos.push_front({newseg[0], newseg[1]});
                dma_display->drawPixel(newseg[0], newseg[1], snake.color);
                if((newseg[0] == snake.food_pos.x) && (newseg[1] == snake.food_pos.y)){ // food eaten
                    snake.food_pos.x = random(0, PANEL_TOTAL_X-1);
                    snake.food_pos.y = random(0, PANEL_RES_Y-1);
                }else{ // food not eaten
                    struct Coord &tail = snake.xy_seg_pos.back();
                    snake.xy_seg_pos.pop_back();
                    dma_display->drawPixel(tail.x, tail.y, myBLACK);

                }
                dma_display->drawPixel(snake.food_pos.x, snake.food_pos.y, snake.color);
            }
            ++it;
        }
    }
    delay(20);
}

bool snake_move_checker(struct Snake &snake, uint8_t cond){
    uint16_t headsegx = snake.xy_seg_pos.front().x;
    uint16_t headsegy = snake.xy_seg_pos.front().y;
    uint16_t ckX;
    uint16_t ckY;
    switch(cond){
    case 0: // Up
        ckX = headsegx;
        ckY = (headsegy + 1) % PANEL_RES_Y;
        break;
    case 1: // Down
        ckX = headsegx;
        ckY = (headsegy + PANEL_RES_Y - 1) % PANEL_RES_Y;
        break;
    case 2: // Left
        ckX = (headsegx + PANEL_TOTAL_X - 1) % PANEL_TOTAL_X;
        ckY = headsegy;
        break;
    case 3: // Right
        ckX = (headsegx + 1) % PANEL_TOTAL_X;
        ckY = headsegy;
        break;
    }

    for(auto& snakex : snakes){
        for(auto& seg : snakex.xy_seg_pos){
            if((seg.x == ckX) && (seg.y == ckY)){
                return false;
            }
        }
        if(((snakex.food_pos.x != snake.food_pos.x) || (snakex.food_pos.y != snake.food_pos.y)) // make sure not checking own food
        && ((snakex.food_pos.x == ckX) && (snakex.food_pos.y == ckY))){ // if food is in the way
            return false;
        }
        
    }
    return true;
}

void resetSnake(){
    snakes.clear();
    dma_display->fillScreen(myBLACK);
}