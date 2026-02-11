#include "demo.h"

//This is where you add your demo, or modify the playback and set of existing demos.

//The setup of the Demo struct is as follows:
//Demo(demo_name, time_in_ms, optional_reset_func, optional_exit_func)
//if you have no reset function, enter "nothing", if no exit condition, enter "noexitcond"

// std::vector<Demo> demos = {
//     Demo(startIEEE,      25000u,  nothing,        noexitcond),
//     Demo(startUB,        150000u, nothing,        UBexitCond),
//     Demo(discoBall,      18000u,  resetDiscoBall, noexitcond),
//     Demo(lineRocker,     20000u,  nothing,        noexitcond),
//     Demo(conway,         30000u,  resetConway,    noexitcond),
//     Demo(snake,          40000u,  resetSnake,     noexitcond),
//     Demo(paint_rollers,  20000u,  nothing,        noexitcond),
//     Demo(pong,           25000u,  resetPong,        noexitcond),
//     Demo(maze,           150000u, resetMaze,      mazeExitCond)
// };

std::vector<Demo> demos = {
    Demo(startIEEE,      10000u,  nothing,        noexitcond),
    Demo(startUB,        100000u, nothing,        UBexitCond),
    Demo(discoBall,      10000u,  resetDiscoBall, noexitcond),
    Demo(lineRocker,     10000u,  nothing,        noexitcond),
    Demo(conway,         10000u,  resetConway,    noexitcond),
    Demo(snake,          20000u,  resetSnake,     noexitcond),
    Demo(paint_rollers,  10000u,  nothing,        noexitcond),
    Demo(pong,           20000u,  resetPong,        noexitcond),
    Demo(maze,           150000u, resetMaze,      mazeExitCond)
};

// std::vector<Demo> demos = {
//     Demo(snake,          1000000u,     resetSnake,     noexitcond),
// };


void nothing() {
    // Do nothing. Should never be called
}

bool noexitcond() {
    return false;
}