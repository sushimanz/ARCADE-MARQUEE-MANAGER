#ifndef DEMO_H
#define DEMO_H

#include <stdint.h>

//Place your demo's .h file in here!!
#include "../linerocker.h"
#include "../discoball.h"
#include "../conway.h"
#include "../UB.h"
#include "../IEEE.h"
#include "../snake.h"
#include "../paintrollers.h"
#include "../plasma.h"
#include "../pong.h"
#include "../maze.h"

#include "../../definitions.h"
#include <vector>


struct Demo {
    void (*runFunc)();
    uint32_t duration;
    void (*resetFunc)();
    bool (*exitCond)();

    Demo(void (*run)(), uint32_t dur, void (*reset)(), bool (*exit)())
        : runFunc(run), duration(dur), resetFunc(reset), exitCond(exit) {}
};


extern std::vector<Demo> demos;

void nothing();
bool noexitcond();

#endif