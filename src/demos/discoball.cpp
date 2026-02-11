#include "discoball.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "utilities/demo_utilities.h"

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;

static float ballPos[2] = {30,30};
static float ballVel[2] = {1.4,1.4};
static uint16_t colorPos = 0;

//A bouncing, strobing ball.
void discoBall(){
  uint16_t color = colorWheel(colorPos);
  colorPos += 1;

  bool bounceFlag = true;
  if(ballPos[0] <= 3){
    ballVel[0] = -0.95 * ballVel[0];
    ballPos[0] = 3;
  }else if(ballPos[0] >= (PANEL_TOTAL_X - 4)){
    ballVel[0] = -0.95 * ballVel[0];
    ballPos[0] = PANEL_TOTAL_X - 4;
  }else if(ballPos[1] <= 3){
    ballVel[1] = -0.95 * ballVel[1];
    ballPos[1] = 3;
  }else if(ballPos[1] >= (PANEL_RES_Y - 4)){
    ballVel[1] = -0.95 * ballVel[1];
    ballPos[1] = PANEL_RES_Y - 4;
  }else{
    //update velocity
    ballVel[0] *= 0.99999;
    ballVel[1] += 0.1;

    bounceFlag=false;
  }
  //update position
    ballPos[0] = ballPos[0] + ballVel[0];
    ballPos[1] = ballPos[1] + ballVel[1];
  //random chance of wild bounce
  if(bounceFlag && random(70) == 67){ //Random chance of ball bouncing into oblivion, to keep things interesting. Fills the screen with black if condition met as well.
    ballVel[0] = 1.7*(ballVel[0]+1);
    ballVel[1] = 3*(ballVel[1]+4);
    dma_display->fillScreen(myBLACK);
  }
  dma_display->fillCircle((int)ballPos[0],(int)ballPos[1],3,color);
  colorPos += 1;
  delay(15);
}

void resetDiscoBall(){
  dma_display->fillScreen(myBLACK);
  ballPos[0] = PANEL_TOTAL_X *2 / 3;
}