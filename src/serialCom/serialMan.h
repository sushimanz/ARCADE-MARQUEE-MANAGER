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
static const uint8_t SERIAL_ACK_START_BYTE = 'S';
static const uint8_t SERIAL_ACK_DONE_BYTE = 'D';
static const uint8_t SERIAL_ACK_FAIL_BYTE = 'F';
static const size_t SERIAL_RX_CHUNK_SIZE = 2048; // Read larger chunks for faster throughput
static const unsigned long SERIAL_INITIAL_CHUNK_TIMEOUT_MS = 400; // Allow startup delay before first payload bytes.
static const unsigned long SERIAL_INTERBYTE_TIMEOUT_MS = 250; // Abort only if byte stream stalls this long.
static const size_t SERIAL_MIN_IMAGE_BUFFER = 512; // Only attempt image receive if this much data is queued
static const bool SERIAL_DISABLE_AFTER_ONE_TRANSFER_TEST = false; // Test mode: after first successful transfer is exited, disable serial handling.
static const bool SERIAL_RECEIVE_ONLY_NO_DRAW_TEST = false; // Test mode: receive full image payload but skip all pixel writes.



#endif