#include "paintrollers.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include <vector>
#include <list>
#include <cstdint>

#define ROLLER_TEXT "IEEE"

extern uint16_t myWHITE;




static std::vector<uint32_t> colors = {
    0xE63946, // Soft Red
    0xA8DADC, // Pale Cyan
    0x457B9D, // Steel Blue
    0x1D3557, // Deep Navy
    0xF4A261, // Soft Orange
    0x2A9D8F, // Teal Green
    0xE9C46A, // Muted Yellow
    0x9C6644, // Soft Brown
    0xB56576, // Rose
    0x6D597A  // Dusty Purple
};

extern MatrixPanel_I2S_DMA *dma_display;

struct Coord {
    int16_t x;
    int16_t y;
};

struct roller {
    struct Coord pos;
    uint16_t color;
    uint8_t direction; // 0: down, 1: up, 2: left, 3: right
};
static std::list<roller> rollers;

void paint_rollers(){
    dma_display->setTextWrap(false);
    dma_display->setTextSize(2);
    if(rollers.size() < 5){
        roller newRoller;
        int randomcolor = random(0, colors.size());
        newRoller.color = dma_display->color565((colors[randomcolor] >> 16) & 0xFF, (colors[randomcolor] >> 8) & 0xFF, colors[randomcolor] & 0xFF);
        newRoller.direction = random(0,4);
        switch(newRoller.direction){
        case 0: // Down
            newRoller.pos.x = random(0, PANEL_TOTAL_X);
            newRoller.pos.y = -25;
            break;
        case 1: // Up
            newRoller.pos.x = random(0, PANEL_TOTAL_X);
            newRoller.pos.y = PANEL_RES_Y+25;
            break;
        case 2: // Left
            newRoller.pos.x = PANEL_TOTAL_X;
            newRoller.pos.y = random(0, PANEL_RES_Y);
            break;
        case 3: // Right
            newRoller.pos.x = -25;
            newRoller.pos.y = random(0, PANEL_RES_Y);
            break;
        }
        rollers.push_back(newRoller);
    }
    if(rollers.size() != 0){
        for(auto it = rollers.begin(); it != rollers.end();){

            struct roller &roller = *it;

            switch(roller.direction){
            case 0: // Down
                roller.pos.y = (roller.pos.y + 1);
                
                dma_display->drawLine(roller.pos.x+3, roller.pos.y+14, roller.pos.x + 40, roller.pos.y+14, roller.color);
                dma_display->setTextColor(roller.color);
                dma_display->setCursor(roller.pos.x, roller.pos.y);
                dma_display->print(ROLLER_TEXT);
                dma_display->setTextColor(myWHITE);
                dma_display->setCursor(roller.pos.x, roller.pos.y+1);
                dma_display->print(ROLLER_TEXT);

                if(roller.pos.y - 20 > PANEL_RES_Y){
                    it = rollers.erase(it);
                    continue;
                }
                break;
            case 1: // Up
                roller.pos.y = (roller.pos.y - 1);
                
                dma_display->drawLine(roller.pos.x+3, roller.pos.y-1, roller.pos.x + 40, roller.pos.y-1, roller.color);
                dma_display->setTextColor(roller.color);
                dma_display->setCursor(roller.pos.x, roller.pos.y);
                dma_display->print(ROLLER_TEXT);
                dma_display->setTextColor(myWHITE);
                dma_display->setCursor(roller.pos.x, roller.pos.y-1);
                dma_display->print(ROLLER_TEXT);

                if(roller.pos.y + 20 < 0){
                    it = rollers.erase(it);
                    continue;
                }
                break;
            case 2: // Left
                roller.pos.x = (roller.pos.x - 1);

                dma_display->setTextColor(roller.color);
                dma_display->setCursor(roller.pos.x, roller.pos.y);
                dma_display->print(ROLLER_TEXT);
                dma_display->setTextColor(myWHITE);
                dma_display->setCursor(roller.pos.x-1, roller.pos.y);
                dma_display->print(ROLLER_TEXT);

                if(roller.pos.x + 45 < 0){
                    it = rollers.erase(it);
                    continue;
                }
                break;
            case 3: // Right
                roller.pos.x = (roller.pos.x + 1);
                
                dma_display->setTextColor(roller.color);
                dma_display->setCursor(roller.pos.x, roller.pos.y);
                dma_display->print(ROLLER_TEXT);
                dma_display->setTextColor(myWHITE);
                dma_display->setCursor(roller.pos.x+1, roller.pos.y);
                dma_display->print(ROLLER_TEXT);

                if(roller.pos.x - 20 > PANEL_TOTAL_X){
                    it = rollers.erase(it);
                    continue;
                }
                break;
            }
            ++it;
        }
    }

    delay(15);
}