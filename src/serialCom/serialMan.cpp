
#include <Arduino.h>
#include "serialMan.h"

extern MatrixPanel_I2S_DMA *dma_display;

// Image display state
static bool isDisplayingImage = false;
static bool justExitedImageMode = false;
static bool serialCommDisabled = false;
static bool disableSerialOnNextExit = false;
static const size_t SERIAL_GARBAGE_DRAIN_BUDGET = 512;

static bool sendAckByte(uint8_t ack, uint8_t repeatCount) {
    bool wroteAny = false;
    for (uint8_t i = 0; i < repeatCount; i++) {
        size_t written = Serial.write(ack);
        if (written == 1) {
            wroteAny = true;
        }
    }
    // Ensure tiny ACK bytes are pushed out before we continue processing.
    Serial.flush();
    return wroteAny;
}

void flushSerialInput() {
    // One-pass non-blocking drain: just clear what's currently available.
    // Don't loop or yield - that can alter FreeRTOS scheduler state.
    while (Serial.available() > 0) {
        Serial.read();
    }
}

static void flushSerialInputBudget(size_t maxBytes) {
    size_t drained = 0;
    while (Serial.available() > 0 && drained < maxBytes) {
        Serial.read();
        drained++;
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

    if (!waitForSerialData(SERIAL_INITIAL_CHUNK_TIMEOUT_MS)) {
        return false;
    }

    unsigned long lastByteMs = millis();

    while (receivedBytes < expectedBytes) {
        if (Serial.available() == 0) {
            if (millis() - lastByteMs > SERIAL_INTERBYTE_TIMEOUT_MS) {
                return false;
            }
            continue;
        }

        unsigned long remainingBytes = expectedBytes - receivedBytes;
        size_t toRead = Serial.available();
        if (toRead > SERIAL_RX_CHUNK_SIZE) {
            toRead = SERIAL_RX_CHUNK_SIZE;
        }
        if ((unsigned long)toRead > remainingBytes) {
            toRead = (size_t)remainingBytes;
        }

        int got = Serial.readBytes((char*)rxBuffer, toRead);
        if (got <= 0) {
            return false;
        }

        lastByteMs = millis();
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
            if (!SERIAL_RECEIVE_ONLY_NO_DRAW_TEST) {
                dma_display->drawPixelRGB888(x, y, r, g, value);
            }
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
    if (serialCommDisabled) {
        return;
    }

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
        if (SERIAL_DISABLE_AFTER_ONE_TRANSFER_TEST && disableSerialOnNextExit) {
            serialCommDisabled = true;
            disableSerialOnNextExit = false;
        }
        return;
    }

    if (syncByte != SERIAL_SYNC_BYTE) {
        // Not a control byte. Drain in bounded chunks so demos keep running smoothly.
        flushSerialInputBudget(SERIAL_GARBAGE_DRAIN_BUDGET);

        return;
    }

    Serial.read(); // Consume the sync byte.
    // Send START ACK twice to improve host-side first-byte capture reliability.
    sendAckByte(SERIAL_ACK_START_BYTE, 2);
    if (!receiveAndDrawImage()) {
        isDisplayingImage = false;
        sendAckByte(SERIAL_ACK_FAIL_BYTE, 1);
        // Failed transfer: clear residual payload immediately for a clean retry.
        flushSerialInput();
        return;
    }

    // Hold image indefinitely until a new image or explicit exit byte arrives.
    sendAckByte(SERIAL_ACK_DONE_BYTE, 1);
    isDisplayingImage = true;
    justExitedImageMode = false;
    if (SERIAL_DISABLE_AFTER_ONE_TRANSFER_TEST) {
        disableSerialOnNextExit = true;
    }
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