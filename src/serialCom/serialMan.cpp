
#include <Arduino.h>
#include "serialMan.h"

extern MatrixPanel_I2S_DMA *dma_display;

// Image display state
static bool isDisplayingImage = false;
static bool justExitedImageMode = false;

static void flushSerialInput() {
    // One-pass non-blocking drain: just clear what's currently available.
    // Don't loop or yield - that can alter FreeRTOS scheduler state.
    while (Serial.available() > 0) {
        Serial.read();
    }
}

static bool waitForSerialData(unsigned long timeoutMs) {
    unsigned long waitStart = millis();
    while (Serial.available() == 0) {
        if (millis() - waitStart > timeoutMs) {
            return false;
        }
    }
    return true;
}

static bool receiveAndDrawImage() {
    int totalWidth = PANEL_TOTAL_X;
    int totalHeight = PANEL_RES_Y;
    unsigned long expectedBytes = (unsigned long)totalWidth * totalHeight * 3;

    unsigned long receivedBytes = 0;
    unsigned long pixelIndex = 0;
    uint8_t component = 0;
    uint8_t r = 0;
    uint8_t g = 0;
    uint8_t rxBuffer[SERIAL_RX_CHUNK_SIZE];

    while (receivedBytes < expectedBytes) {
        if (!waitForSerialData(SERIAL_CHUNK_TIMEOUT_MS)) {
            return false;
        }

        size_t toRead = Serial.available();
        if (toRead > SERIAL_RX_CHUNK_SIZE) {
            toRead = SERIAL_RX_CHUNK_SIZE;
        }

        int got = Serial.readBytes((char*)rxBuffer, toRead);
        if (got <= 0) {
            return false;
        }

        receivedBytes += (unsigned long)got;

        for (int i = 0; i < got; i++) {
            uint8_t value = rxBuffer[i];

            if (component == 0) {
                r = value;
                component = 1;
                continue;
            }

            if (component == 1) {
                g = value;
                component = 2;
                continue;
            }

            int x = (int)(pixelIndex % totalWidth);
            int y = (int)(pixelIndex / totalWidth);
            dma_display->drawPixelRGB888(x, y, r, g, value);
            pixelIndex++;
            component = 0;
        }
    }

    unsigned long expectedPixels = (unsigned long)totalWidth * totalHeight;
    if (pixelIndex != expectedPixels) {
        return false;
    }

    if (component != 0) {
        return false;
    }

    return true;
}


void handleSerialComm(){
    // Serial communication
    if (Serial.available() <= 0) {
        return;
    }

    int syncByte = Serial.peek();
    if (syncByte == SERIAL_EXIT_IMAGE_MODE_BYTE) {
        // Explicitly exit image mode and return to demos.
        Serial.read();
        isDisplayingImage = false;
        justExitedImageMode = true;
        flushSerialInput();
        return;
    }

    if (syncByte != SERIAL_SYNC_BYTE) {
        // Not a control byte. Drain garbage quickly so stale payload bytes don't throttle demo speed.
        flushSerialInput();

        return;
    }

    // Sync byte detected. Guard against long waits:
    // Only attempt image receive if we have substantial data queued OR we're already displaying an image.
    // This prevents stray sync bytes from blocking the demo loop.
    if (!isDisplayingImage && Serial.available() < SERIAL_MIN_IMAGE_BUFFER) {
        // Stray sync with insufficient data; skip to avoid timeout.
        return;
    }

    Serial.read(); // Consume the sync byte.
    if (!receiveAndDrawImage()) {
        isDisplayingImage = false;
        flushSerialInput(); // Flush remaining data from a failed transfer.
        return;
    }

    //dma_display->flipDMABuffer();
    // Hold image indefinitely until a new image or explicit exit byte arrives.
    isDisplayingImage = true;
    justExitedImageMode = false;
}

bool isInImageDisplayMode() {
    return isDisplayingImage;
}

bool checkAndClearExitFlag() {
    if (justExitedImageMode) {
        justExitedImageMode = false;
        return true;
    }
    return false;
}