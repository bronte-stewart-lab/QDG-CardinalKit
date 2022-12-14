//
//  BLEManager.swift
//  CardinalKit_Example
//
//  Created by Gary Burnett on 8/14/22.
//  Copyright © 2022 CardinalKit. All rights reserved.
//

import NIO
import Foundation
import CoreBluetooth

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int // Received Signal Strength Indicator (RSSI)
    let corePeripheral: CBPeripheral // Object from CoreBluetooth
    var services: [CBService:[CBCharacteristic]] = [:]
    var QDG_Charactersitic: CBCharacteristic? = nil // HE characteristic object
}

let ServiceNameToCBUUID = [
    "QDG_Service" : CBUUID(string: "b7779a75-f00a-05b4-147b-abf02f0d9b16"),
]

let acceptableDeviceCBUUIDList = [
    ServiceNameToCBUUID["QDG_Service"]!
]

class BLEManager: NSObject, CBCentralManagerDelegate, ObservableObject, CBPeripheralDelegate {
    
    var myCentral: CBCentralManager!
    var QDGPeripheral: CBPeripheral!
    
    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    @Published var connectedPeripherals = [Peripheral]()
    @Published var stateText: String = "Waiting for initialization"
    
    // Identify when the CoreBluetooth Central Manager changes state; probably representing a change in client Bluetooth settings
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .unknown:
            stateText = "unknown"
        case .resetting:
            stateText = "resetting"
        case .unsupported:
            stateText = "unsupported"
        case .unauthorized:
            stateText = "unauthorized"
        case .poweredOff:
            stateText = "poweredOff"
            isSwitchedOn = false
        case .poweredOn:
            stateText = "poweredOn"
            isSwitchedOn = true
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: CBATTRequest){
        print("Received Write")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
        
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            peripheralName = name
        } else {
            peripheralName = "Bluetooth Device"
        }
        
        // see if we have already detected this device; if we have, we need not list it again
        var alreadyDetected = false
        for alreadyDetectedPeriph in peripherals {
            if alreadyDetectedPeriph.corePeripheral.identifier == peripheral.identifier {
                alreadyDetected = true
                break
            }
        }
        if !alreadyDetected {
            let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, corePeripheral: peripheral)
            peripherals.append(newPeripheral)
        }
    }
    
    func startScanning() {
        print("Starting Scan")
        myCentral.scanForPeripherals(withServices: acceptableDeviceCBUUIDList, options: nil)
    }
    
    func stopScanning() {
        print("Stopping Scan")
        myCentral.stopScan()
    }
    
    func connect(peripheral: CBPeripheral) {
        print("Attempting Connection")
        myCentral.connect(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Yay! Connected!")
        peripheral.delegate = self
        discoverServices(peripheral: peripheral)
    }
    
    // We keep the list of connected BT devices in: connectedPeripherals
    // This function refreshes that list by
    // 1. Querying CoreBluetooth for which devices we are connected to and put it into detectedPeripherals
    // 2. Going through the current version of connectPeripherals and seeing which devices we are still connected to
    // 3. Going through
    func refreshConnectedDevices() {
        
        print("Refreshing BT devices")
        
        // Call out to CoreBluetooth and see which peripherals we are connected to right now
        let detectedPeripherals = myCentral.retrieveConnectedPeripherals(withServices: acceptableDeviceCBUUIDList)
        
        print("Newly detected peripherals")
        print(detectedPeripherals)
        
        // A list for each peripheral we are connected to after the refresh
        var newConnectectedPeripherals: [Peripheral] = []
        
        // For each BT device in our current list
        // We check if its identifier matches one in our newly detected list
        // If yes, we put it in our new list
        // Otherwise, we ignore it
        for peripheral in connectedPeripherals {
            print("We have a previously connected peripheral with id: \(peripheral.id)")
            var stillConnected = false
            for detectedPeriph in detectedPeripherals {
                if peripheral.corePeripheral.identifier == detectedPeriph.identifier {
                    stillConnected = true
                    break
                }
            }
            print("We are NOT still connected to this peripheral")
            if stillConnected {
                print("We ARE still connected to this peripheral")
                newConnectectedPeripherals.append(peripheral)
            }
        }
        
        // Clear the old list and replace it with our new list
        connectedPeripherals.removeAll()
        connectedPeripherals = newConnectectedPeripherals
        
        // Now go through each of the new devices
        for detectedPeriph in detectedPeripherals {
            
            print("We have a newly detected peripheral")
            
            var alreadyConnected = false
            
            // If this new device is already in our list, then we move on
            for peripheral in connectedPeripherals {
                if peripheral.corePeripheral.identifier == detectedPeriph.identifier {
                    print("This is already connected")
                    alreadyConnected = true
                    break
                }
            }
            
            // Otherwise, we add it to our list which keeps track of
            // 1. id - based on the order it was added to the list (note: this is unreliable)
            // 2. name of the device (or "Unknown Device")
            // 3. rssi
            // 4. corePeripheral - the actual peripheral object 
            if !alreadyConnected {
                let newConnectedPeripheral = Peripheral(id: connectedPeripherals.count, name: detectedPeriph.name ?? "Unknown Device", rssi: -1, corePeripheral: detectedPeriph)
                newConnectedPeripheral.corePeripheral.delegate = self
                connectedPeripherals.append(newConnectedPeripheral)
                
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Lost connection to peripheral")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Hmm, failed to connect")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        print("Discovering services")
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            
            print("Found service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        print("Discovering characteristics for service: \(service.uuid)")
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            
            // Print UUID
            print("Characteristic found with UUID: \(characteristic.uuid)")
            
            // Print capabilities for read and notify
            if characteristic.properties.contains(.read) {
              print("\(characteristic.uuid): properties contains .read")
            }
            if characteristic.properties.contains(.notify) {
              print("\(characteristic.uuid): properties contains .notify")
            }
            
            if characteristic.uuid == CBUUID(string: "b7779a75-f00a-05b4-147b-abf02f0d9b16") { //
                
                print("Subscribing to this characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    // This gets called as soon as we change setNotifyValue to be true for this characteristic
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("Unable to update notification state for \(characteristic.uuid)")
            print(error as Any)
        } else {
            print("Successfully updated the notification state for \(characteristic.uuid)")
        }
    }
    
    // Helper function (can probably eliminate this in the future)
    func findPeripheralIndex(peripheral: CBPeripheral) -> Int {
        for index in 0..<connectedPeripherals.count {
            if connectedPeripherals[index].corePeripheral.identifier == peripheral.identifier {
                return index
            }
        }
        return -1
    }
    
    // What to do when we get an updated value for our characteristic
    // Hopefully this triggers every time a new value is WRITTEN and not only when the value changes
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        print("Peripheral set a value for the characteristic \(characteristic.uuid)")
        
        switch characteristic.uuid {
          case ServiceNameToCBUUID["QDG_Service"]:
            print(characteristic.value ?? "no value")
            getQDGData(from: characteristic)
          default:
            print("Unhandled Characteristic UUID: \(characteristic.uuid)")
        }
    }
    
    func getQDGData(from characteristic: CBCharacteristic) {
        
        print("Parsing Message Header")
        
        if let data = characteristic.value {
            
            print("Inside if statement")
            
            // Convert the characteristic data to a ByteBuffer
            let all_bytes = ByteBuffer(bytes: data)
            
            print("Printing bytes")
            print(all_bytes)

            // Extract the message header information
            guard let msg_size: UInt16 = all_bytes.getInteger(at: 0, as: UInt16.self),
                  let protocol_id: UInt8 = all_bytes.getInteger(at: 16, as: UInt8.self),
                  let message_id: UInt8 = all_bytes.getInteger(at: 24, as: UInt8.self),
                  let sequence_number: UInt16 = all_bytes.getInteger(at: 32, as: UInt16.self),
                  let reserved: UInt8 = all_bytes.getInteger(at: 48, as: UInt8.self) else { return }
            
            print("Got header information")
            
            print(msg_size)
            print(protocol_id)
            print(message_id)
            print(sequence_number)
            print(reserved)
            
            print("Printed header information")
            
        }
    }
    
    func discoverServices(peripheral: CBPeripheral) {
        print("Attempting to discover services")
        peripheral.discoverServices(nil)
    }
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
}
