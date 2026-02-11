#include "conway.h"
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>

extern MatrixPanel_I2S_DMA *dma_display;
extern uint16_t myBLACK;
extern uint16_t myWHITE;

static uint8_t con_buf[PANEL_TOTAL_X][PANEL_RES_Y];
static uint8_t con_cur[PANEL_TOTAL_X][PANEL_RES_Y];

void conway(){
  for(uint16_t x = 0; x < PANEL_TOTAL_X; x++){
    for(uint16_t y = 0; y < PANEL_RES_Y; y++){
      uint16_t count = conway_count(x, y);
      uint16_t cur = con_cur[x][y];
      if(cur==0 && count==3){
        con_buf[x][y]=1;
      }else{
        con_buf[x][y]=0;
      }
      if(cur==1){
        if(count==2 || count==3){
          con_buf[x][y]=1;
        }else{
          con_buf[x][y]=0;
        }
      }
      if(cur==1){
        dma_display->writePixel(x, y, myWHITE);
      }else{
        dma_display->writePixel(x, y, myBLACK);
      }
    }
  }
  memcpy(&con_cur[0][0], &con_buf[0][0], sizeof(con_buf));

  delay(80);
}


// count the # of neighbors
int conway_count(int x, int y){
  int count = 0;

  int xm1;
  if(x==0){
    xm1 = PANEL_TOTAL_X-1;
  }else{
    xm1 = x-1;
  }
  int ym1;
  if(y==0){
    ym1 = PANEL_RES_Y-1;
  }else{
    ym1 = y-1;
  }
  int xp1;
  if(x==PANEL_TOTAL_X-1){
    xp1 = 0;
  }else{
    xp1 = x+1;
  }
  int yp1;
  if(y==PANEL_RES_Y-1){
    yp1 = 0;
  }else{
    yp1 = y+1;
  }
  count+=(con_cur[xm1][ym1]);
  count+=(con_cur[x][ym1]);
  count+=(con_cur[xp1][ym1]);

  count+=(con_cur[xm1][y]);
  count+=(con_cur[xp1][y]);

  count+=(con_cur[xm1][yp1]);
  count+=(con_cur[x][yp1]);
  count+=(con_cur[xp1][yp1]);
  return count;
}

void resetConway(){
  memset(con_buf, 0, sizeof(con_buf));
  memset(con_cur, 0, sizeof(con_cur));
  for(int x = 0; x < PANEL_TOTAL_X; x++){
    for(int y = 0; y < PANEL_RES_Y; y++){
      con_cur[x][y] = random()%2;
    }
  }
}
