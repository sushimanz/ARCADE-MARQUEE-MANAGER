#include "maze.h"
#include <stack>
#include <queue>
#include <array>

uint8_t mazeGrid[PANEL_TOTAL_X][PANEL_RES_Y];
// 0 = path
// 1 = wall
// 2 = unfilled

std::stack<Point> mazeStack;

uint8_t colorPos4 = 0;

void mazeDFS(bool solving);

// Solves the maze using DFS
void maze(){
    mazeDFS(true);
    uint16_t cur_color = colorWheel(colorPos4);
    colorPos4 += 1;
    dma_display->drawRect(0, 0, PANEL_TOTAL_X, 2, cur_color);
    dma_display->drawRect(0, 0, 2, PANEL_RES_Y, cur_color);
    dma_display->fillRect(0, PANEL_RES_Y-3, PANEL_TOTAL_X, 3, cur_color);
    dma_display->fillRect(PANEL_TOTAL_X-3, 0, 3, PANEL_RES_Y, cur_color);
    delay(3);
}

// Constructs a new maze using DFS algorithm
void resetMaze() {
    for(int x = 0; x < MAZE_TOT_X; x++) {
        for(int y = 0; y < MAZE_TOT_Y; y++) {
            if(x%2==0 && y%2==0){
                mazeGrid[x][y] = 2; // unfilled
            }else{
                mazeGrid[x][y] = 1; // wall
            }
            
        }
    }

    // DFS Maze Generation
    Point start = {random(0, MAZE_TOT_X/2)*2, random(0, MAZE_TOT_Y/2)*2};
    mazeGrid[start.x][start.y] = 0; // mark start point as path
    
    mazeStack.push(start);

    while(!mazeStack.empty()) {
        mazeDFS(false);
    }


    for(int x = 0; x < MAZE_TOT_X; x++) {
        for(int y = 0; y < MAZE_TOT_Y; y++) {
            if(mazeGrid[x][y] == 1) {
                dma_display->drawPixel(x+2, y+2, myBLACK); // wall
            } else {
                dma_display->drawPixel(x+2, y+2, myWHITE); // path
            }
        }
    }

    mazeStack.push(Point{0, 0}); // push start point for solving
    mazeGrid[0][0] = 3;
}

bool mazeExitCond(){
    if((mazeStack.top().x == MAZE_TOT_X-1 && mazeStack.top().y == MAZE_TOT_Y-1) || mazeStack.empty()){
        delay(1000);
        while(!mazeStack.empty()) mazeStack.pop(); // clear stack
        return true;
    }
    return false;
}

void mazeDFS(bool solving){ // if not solving then generating
    std::array<Point, 4> directions;
    if(solving){
        directions = {{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}}; // u d l r
    }else{
        directions = {{{0, -2}, {0, 2}, {-2, 0}, {2, 0}}};
    }

    Point current = mazeStack.top();
    if(!solving && mazeGrid[current.x][current.y] == 2) {
        mazeGrid[current.x][current.y] = 0; // mark as path
    }
    if(solving && mazeGrid[current.x][current.y] == 0) {
        mazeGrid[current.x][current.y] = 3; // mark as part of solution path
        dma_display->drawPixel(current.x+2, current.y+2, colorWheel(colorPos4));
    }

    uint8_t checkedDirections = 0b0000; // udlr, 1 = checked
    bool solved = false;

    // shuffle directions
    std::array<uint8_t,4> order = {0,1,2,3};
    for(int i = 3; i > 0; i--){
        int j = random(0, i+1);
        std::swap(order[i], order[j]);
    }

    for(auto randInt : order){
        if(checkedDirections & (1 << randInt)) continue;

        Point neighbor = {directions[randInt].x + current.x, directions[randInt].y + current.y};

        // check bounds
        if(neighbor.x < 0 || neighbor.x >= MAZE_TOT_X || neighbor.y < 0 || neighbor.y >= MAZE_TOT_Y){
            checkedDirections |= (1 << randInt);
            continue;
        }

        if(solving){
            if(mazeGrid[neighbor.x][neighbor.y] == 1 || mazeGrid[neighbor.x][neighbor.y] == 3){ // wall or already part of solution
                checkedDirections |= (1 << randInt);
            }else{ // valid path
                mazeStack.push(neighbor);
                dma_display->drawPixel(neighbor.x+2, neighbor.y+2, dma_display->color565(255, 0, 0));
                solved = true;
                break;
            }
        }else{ // generating
            if(mazeGrid[neighbor.x][neighbor.y] == 0){ // already carved
                checkedDirections |= (1 << randInt);
            }else{ // carve path
                mazeGrid[neighbor.x][neighbor.y] = 0;
                mazeGrid[(current.x + neighbor.x)/2][(current.y + neighbor.y)/2] = 0; // remove wall between current and neighbor
                mazeStack.push(neighbor);
                solved = true;
                break;
            }
        }
    }

    if(!solved){ // all directions checked or no valid move, backtrack
        if(solving){
            dma_display->drawPixel(current.x+2, current.y+2, myWHITE);
        }
        mazeStack.pop();
    }
}