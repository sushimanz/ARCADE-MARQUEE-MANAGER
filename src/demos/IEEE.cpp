#include "IEEE.h"
#include "utilities/demo_utilities.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>

extern MatrixPanel_I2S_DMA *dma_display;

uint8_t textstart = (uint8_t)PANEL_TOTAL_X;
uint8_t borderx = (uint8_t)(PANEL_TOTAL_X/2);
uint16_t color;
uint8_t colorPos1 = 0;
int changeNum = 0;
int randNum = 1;

void startIEEE(){
  
  uint16_t WBcolor = whiteBlueWheel(colorPos1);
  colorPos1 += randNum;
  if(changeNum>(randNum*6)){
    randNum=random(1,10);
    changeNum=0;
  }
  changeNum++;
  IEEE(textstart,borderx, WBcolor);
  textstart +=abs(randNum/4)+1;
  borderx -= 3;
  delay(50+randNum);
}

//Writes "IEEE" in an interesting fading pattern, with a great deal of randomness.
void IEEE(int textstart, int borderx, uint16_t color){

  dma_display->setTextSize(7);     // size 1 == 8 pixels high
  dma_display->setTextWrap(false);

  dma_display->setTextColor(color);
  dma_display->setCursor(textstart, 8);
  dma_display->print("IEEE");
  dma_display->setCursor(textstart+1, 8);
  dma_display->print("IEEE");
  dma_display->setCursor(textstart-PANEL_TOTAL_X, 8);
  dma_display->print("IEEE");
  dma_display->setCursor(textstart-PANEL_TOTAL_X-1, 8);
  dma_display->print("IEEE");

  dma_display->fillRect(borderx, 0, PANEL_TOTAL_X/2, 8, color);
  dma_display->fillRect(borderx+PANEL_TOTAL_X, 0, PANEL_TOTAL_X/2, 8, color);
  dma_display->fillRect(borderx, 57, PANEL_TOTAL_X/2, 7, color);
  dma_display->fillRect(borderx+PANEL_TOTAL_X, 57, PANEL_TOTAL_X/2, 7, color);
}

