#include "UB.h"
#include "utilities/demo_utilities.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;
extern uint16_t myWHITE;

static uint8_t currText = 0;
static int scrollPos = PANEL_TOTAL_X+1;  // Start off-screen to the right
static uint8_t colorPos = 0;
static uint8_t danceOffset = 0;
static bool endcond = false;
static uint8_t danceAmplitude = 6;    // pixels (increase to make the characters bounce higher)

void startUB(){
  UB(colorPos);
  colorPos += 1;
  delay(20);
}

//Draws some text about UB with interesting color stuff going on, and the letters are pretty bouncy.
void UB(uint8_t colorPos){
  const char* textSet[] = { //UPDATE COUNT BELOW WHENEVER THIS IS UPDATED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    "State University at Buffalo // 2025 Arcade Machine",
    "I LOVE IEEE!!! I LOVE UB!!!",
    "C++ might be the best thing... ever...",
    "Display codebase written by Enzo Mclauchlin",
    "Cabinet designed by Ronny Cole, ____, and ____", //I dont remember peoples last names, and also first names. Apologies, -Enzo
    "Project lead by Fabien Habiyambere",
    "Shoutouts to Austin and Eric the GOATs!",
    "Batocera setup and PC configuration by Ryan Eason and Enzo Mclauchlin",
    "I LOVE BRIDGING HARDWARE AND SOFTWARE!!",
    "Take CSE 241, and take it with Ryan St. Pierre because he is awesome :)",
    "~~~ MICROCONTROLLERS ARE ABSOLUTELY TUBULAR ~~"
  };


  for(uint16_t x = 0; x < PANEL_TOTAL_X; x++){
    for(uint16_t y = 0; y < PANEL_RES_Y; y++){
      if(x % 2 == 0 && y%2 ==0){
        dma_display->writePixel(x, y, myBLACK);
      }
      if(x % 2 == 1 && y%2 ==1){
        dma_display->writePixel(x, y, myBLACK);
      }
    }
  }
  dma_display->setTextSize(5);
  dma_display->setTextWrap(false);
  const char* ubStr = textSet[currText];
  uint8_t charInd = 0;
  int charPos = scrollPos;

  while(charInd<strlen(ubStr)){
    char curChar = ubStr[charInd];
    int danceY = 15 + (int)(sin((danceOffset + charInd*2) *0.2)*sin(danceOffset*0.05)*20); // Sine wave for smooth up/down motion
    uint16_t color = colorWheel(colorPos+charInd);
    dma_display->setTextColor(color);
    
    dma_display->setCursor(charPos, danceY);
    dma_display->print(curChar);


    charPos += 32; //adequate character spacing
    charInd++;
  }

  scrollPos -=3;
  if(scrollPos <= -((int)strlen(ubStr)*32+40)){
    endcond = true;
  }

  danceOffset += 1;
}

bool UBexitCond() {
    if (endcond) {
        // Reset for next time
        scrollPos = (uint16_t)(PANEL_TOTAL_X + 1);
        danceOffset = 0;
        endcond = false;
        if(currText < 11) { //NUMERICALLY DEFINED TO AVOID GLOBAL NAMESPACE POLLUTION, UPDATE WHENEVER LIST UPDATED!!!!!!!!!!!!!!!!!!!!!!!!!!
            currText++;
        } else {
            currText = 0;
        }
        return true;
    }
    return false;
  }