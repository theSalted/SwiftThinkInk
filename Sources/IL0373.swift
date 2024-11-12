//=== IL0373.swift ---------------------------------------------------------===//
//
// Swift driver for IL0373-based ePaper displays
//
// See https://madmachine.io for more information
//
//===----------------------------------------------------------------------===//

import SwiftIO
import MadBoard

/// This is the driver for the IL0373 ePaper display.
final public class IL0373 {

    // MARK: - Properties

    private let spi: SPI
    private let csPin: DigitalOut
    private let dcPin: DigitalOut
    private let resetPin: DigitalOut?
    private let busyPin: DigitalIn?

    private var width: Int
    private var height: Int
    private var rotation: Int
    private var swapRams: Bool
    private var border: Bool?
    private var colorBitsInverted: Bool
    private var blackBitsInverted: Bool
    private var refreshDisplayCommand: UInt8
    private var writeBlackRamCommand: UInt8
    private var writeColorRamCommand: UInt8

    private var startSequence: [(command: UInt8, data: [UInt8])]
    private let stopSequence: [(command: UInt8, data: [UInt8])] = [
        (0x50, [0x17]),    // CDI setting
        (0x82, [0x00]),    // VCM DC to -0.10 V
        (0x02, [])         // Power off
    ]

    // MARK: - Initialization

    /// Initialize the IL0373 display driver.
    ///
    /// - Parameters:
    ///   - spi: The SPI interface connected to the display.
    ///   - csPin: The Chip Select digital output pin.
    ///   - dcPin: The Data/Command control pin.
    ///   - resetPin: **OPTIONAL** The Reset control pin.
    ///   - busyPin: **OPTIONAL** The Busy status input pin.
    ///   - width: Display width in pixels.
    ///   - height: Display height in pixels.
    ///   - rotation: **OPTIONAL** Display rotation (0, 90, 180, 270 degrees), default is 0.
    ///   - swapRams: **OPTIONAL** Swap color and black RAMs if `true`, default is `false`.
    ///   - border: **OPTIONAL** Set border color; `true` for black, `false` for white, `nil` to leave unchanged.
    public init(spi: SPI, csPin: DigitalOut, dcPin: DigitalOut, resetPin: DigitalOut? = nil, busyPin: DigitalIn? = nil,
                width: Int, height: Int, rotation: Int = 0,
                swapRams: Bool = false, border: Bool? = false) {

        self.spi = spi
        self.csPin = csPin
        self.dcPin = dcPin
        self.resetPin = resetPin
        self.busyPin = busyPin

        self.width = width
        self.height = height
        self.rotation = rotation % 360
        self.swapRams = swapRams
        self.border = border
        self.refreshDisplayCommand = 0x12

        // Determine bit inversion and RAM commands based on swapRams
        if swapRams {
            self.colorBitsInverted = false
            self.blackBitsInverted = true
            self.writeColorRamCommand = 0x10
            self.writeBlackRamCommand = 0x13
        } else {
            self.colorBitsInverted = true
            self.blackBitsInverted = false
            self.writeBlackRamCommand = 0x10
            self.writeColorRamCommand = 0x13
        }

        // Initialize start sequence
        self.startSequence = []
        initializeStartSequence()

        // Initialize the display
        initializeDisplay()
    }

    // MARK: - Display Initialization

    private func initializeStartSequence() {
        // Base start sequence
        self.startSequence = [
            (0x01, [0x03, 0x00, 0x2B, 0x2B, 0x09]), // Power setting
            (0x06, [0x17, 0x17, 0x17]),             // Booster soft start
            (0x04, []),                             // Power on and wait
            (0x00, [0x0F]),                         // Panel setting
            (0x50, [0x37]),                         // CDI setting
            (0x30, [0x29]),                         // PLL setting
            (0x61, [UInt8(width & 0xFF), UInt8((height >> 8) & 0xFF), UInt8(height & 0xFF)]), // Resolution
            (0x82, [0x12])                          // VCM DC setting
        ]

        // Adjust border settings if necessary
        if let border = self.border {
            let panelSettingIndex = 3
            if border {
                // Set border to black
                self.startSequence[panelSettingIndex].data[0] |= 0b10 << 6
            } else {
                // Set border to white
                self.startSequence[panelSettingIndex].data[0] |= 0b01 << 6
            }
        } else {
            // Leave border unchanged
            let panelSettingIndex = 3
            self.startSequence[panelSettingIndex].data[0] |= 0b11 << 6
        }
    }

    private func initializeDisplay() {
        // Reset the display
        reset()

        // Send the start sequence to initialize the display
        for command in startSequence {
            sendCommand(command.command, data: command.data)
            if command.command == 0x04 {
                // Wait for power on if necessary
                waitUntilIdle()
            }
        }

        // Wait for the display to be ready
        waitUntilIdle()
    }

    // MARK: - Display Control Methods

    /// Reset the display hardware.
    public func reset() {
        if let resetPin = resetPin {
            resetPin.write(false)
            SwiftIO.sleep(ms: 200)
            resetPin.write(true)
            SwiftIO.sleep(ms: 200)
        } else {
            // Send software reset command if resetPin is not available
            sendCommand(0x12) // Software reset command
            SwiftIO.sleep(ms: 200)
        }
    }

    /// Wait until the display is not busy.
    public func waitUntilIdle() {
        if let busyPin = busyPin {
            while busyPin.read() == true {
                SwiftIO.sleep(ms: 100)
            }
        } else {
            // Use a fixed delay if busyPin is not available
            SwiftIO.sleep(ms: 2000) // Adjust delay as necessary
        }
    }

    /// Send a command with optional data to the display.
    ///
    /// - Parameters:
    ///   - command: The command byte to send.
    ///   - data: An array of data bytes to send after the command.
    private func sendCommand(_ command: UInt8, data: [UInt8] = []) {
        csPin.write(false)
        dcPin.write(false) // Command mode
        spi.write([command])
        if !data.isEmpty {
            dcPin.write(true) // Data mode
            spi.write(data)
        }
        csPin.write(true)
    }

    /// Refresh the display to update the contents.
    public func refreshDisplay() {
        sendCommand(refreshDisplayCommand)
        waitUntilIdle()
    }

    /// Send image data to the black RAM.
    ///
    /// - Parameter imageData: The image data array.
    public func writeBlackRam(_ imageData: [UInt8]) {
        sendCommand(writeBlackRamCommand)
        dcPin.write(true)
        csPin.write(false)
        spi.write(imageData)
        csPin.write(true)
    }

    /// Send image data to the color RAM.
    ///
    /// - Parameter imageData: The image data array.
    public func writeColorRam(_ imageData: [UInt8]) {
        sendCommand(writeColorRamCommand)
        dcPin.write(true)
        csPin.write(false)
        spi.write(imageData)
        csPin.write(true)
    }

    /// Clear the display.
    public func clearDisplay() {
        let bufferSize = (width * height) / 8
        let blackByte: UInt8 = blackBitsInverted ? 0xFF : 0x00
        let colorByte: UInt8 = colorBitsInverted ? 0xFF : 0x00

        let blackBuffer = [UInt8](repeating: blackByte, count: bufferSize)
        let colorBuffer = [UInt8](repeating: colorByte, count: bufferSize)

        writeBlackRam(blackBuffer)
        writeColorRam(colorBuffer)
        refreshDisplay()
    }

    /// Send the stop sequence to the display.
    public func powerOff() {
        for command in stopSequence {
            sendCommand(command.command, data: command.data)
        }
    }

    // MARK: - Additional Methods (Optional)

    /// Write image data to the display.
    ///
    /// - Parameters:
    ///   - blackImage: The black channel image data.
    ///   - colorImage: The color channel image data.
    public func display(blackImage: [UInt8], colorImage: [UInt8]) {
        writeBlackRam(blackImage)
        writeColorRam(colorImage)
        refreshDisplay()
    }

    /// Sleep mode to save power.
    public func sleep() {
        sendCommand(0x02) // Power off
        waitUntilIdle()
        sendCommand(0x07, data: [0xA5]) // Deep sleep
    }
}