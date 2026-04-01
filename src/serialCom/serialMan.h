#ifndef SERIALMAN_H
#define SERIALMAN_H

#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include "../definitions.h"

void handleSerialComm();
bool isInImageDisplayMode();
bool checkAndClearExitFlag();
void flushSerialInput(); 

static const uint8_t SERIAL_SYNC_BYTE = 0x42;
static const uint8_t SERIAL_EXIT_IMAGE_MODE_BYTE = 0x45;
static const size_t SERIAL_RX_CHUNK_SIZE = 2048; // Read larger chunks for faster throughput
static const unsigned long SERIAL_CHUNK_TIMEOUT_MS = 5; // Very short timeout to avoid blocking demo loop
static const size_t SERIAL_MIN_IMAGE_BUFFER = 512; // Only attempt image receive if this much data is queued



#endif