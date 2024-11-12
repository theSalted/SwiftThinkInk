// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftIO
import MadBoard

start()
while true {
    update()
    sleep(ms: 10)
}

func start() {
    print("main")
    let spi = SPI(Id.SPI0)
    let csPin = DigitalOut(Id.D9)
    let dcPin = DigitalOut(Id.D10)

    let display = IL0373(spi: spi, csPin: csPin, dcPin: dcPin, width: 128, height: 296)

    display.clearDisplay()

    // Prepare image data (black and color buffers)
    let imageSize = (128 * 296) / 8
    let blackImage = [UInt8](repeating: 0x00, count: imageSize) // Example black image data
    let colorImage = [UInt8](repeating: 0xFF, count: imageSize) // Example color image data

    display.writeBlackRam(blackImage)
    display.writeColorRam(colorImage)
    display.refreshDisplay()

    // When done, power off the display
    display.powerOff()
}

func update() {
    let spi = SPI(Id.SPI0)
    let csPin = DigitalOut(Id.D9)
    let dcPin = DigitalOut(Id.D10)

    let display = IL0373(spi: spi, csPin: csPin, dcPin: dcPin, width: 128, height: 296)

    display.clearDisplay()

    // Prepare image data (black and color buffers)
    let imageSize = (128 * 296) / 8
    let blackImage = [UInt8](repeating: 0x00, count: imageSize) // Example black image data
    let colorImage = [UInt8](repeating: 0xFF, count: imageSize) // Example color image data

    display.writeBlackRam(blackImage)
    display.writeColorRam(colorImage)
    display.refreshDisplay()

    // When done, power off the display
    display.powerOff()
    print("Hello")
    
}