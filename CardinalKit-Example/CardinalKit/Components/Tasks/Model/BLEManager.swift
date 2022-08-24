//
//  BLEManager.swift
//  CardinalKit_Example
//
//  Created by Gary Burnett on 8/14/22.
//  Copyright © 2022 CardinalKit. All rights reserved.
//

import Foundation
import CoreBluetooth

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int // Received Signal Strength Indicator (RSSI)
    let corePeripheral: CBPeripheral // Object from CoreBluetooth 
    var HE_Service = false // Does this peripheral hold an HE Service?
    var services: [CBService:[CBCharacteristic]] = [:]
    var batteryLevel: Int = 0
    var HE_Charactersitic: CBCharacteristic? = nil // HE characteristic object
}

let ServiceNameToCBUUID = [
    "HE_Service" : CBUUID(string: "b7779a75-f00a-05b4-147b-abf02f0d9b16"),
]

let acceptableDeviceCBUUIDList = [
    ServiceNameToCBUUID["HE_Service"]!
]

class BLEManager: NSObject, CBCentralManagerDelegate, ObservableObject, CBPeripheralDelegate {
    
    var myCentral: CBCentralManager!
    var bloodPressurePeripheral: CBPeripheral!
    
    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    @Published var connectedPeripherals = [Peripheral]()
    @Published var stateText: String = "Waiting for initialisation"
    
    // Blood Pressure Specific Published Data
    @Published var systolicPressure: Float = 0.0
    @Published var diastolicPressure: Float = 0.0
    @Published var heartRate: Float = 0.0
    @Published var weight: Float = 0.0
    @Published var pressureUnits: String = "mmHg"
    @Published var dataGatheringComplete = false
    
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
            // 3. rssi ??
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
        
        // find the relevant peripheral in the list
//        let index = findPeripheralIndex(peripheral: peripheral)
    
//        // update peripheral properties (just for housekpeeing, not functionality)
//        connectedPeripherals[index].services[service] = characteristics
//        if service.uuid == ServiceNameToCBUUID["HE_Service"] { //"HE_Service"
//
//            print("Found an HE Service")
//            connectedPeripherals[index].HE_Service = true
//
//        }
        
        for characteristic in characteristics {
            
            print("Characteristic found with UUID: \(characteristic.uuid)")
            
            if characteristic.uuid == CBUUID(string: "B7779A75-F00A-05B4-147B-ABF02F0D9B16") { //
                
                print("Characteristic Properties")
                print("Value: \(String(describing: characteristic.value))")
                print("Descriptors: \(String(describing: characteristic.descriptors))")
                print("isNotifying: \(String(describing: characteristic.isNotifying))")
                
                print("Subscribing to this characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
//                connectedPeripherals[index].HE_Charactersitic = characteristic
                
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
        
        print("Updated value function triggered for characteristic \(characteristic.uuid)")
        
        if characteristic.uuid == CBUUID(string: "B7779A75-F00A-05B4-147B-ABF02F0D9B16") {
            
            print("New value for HE_Char")
            
//            let index = findPeripheralIndex(peripheral: peripheral)
            
//            print("Reading HE Sensor data from peripheral \(index)")
            print("Value: \(String(describing: characteristic.value))")
            
//            getHESensorData(from: characteristic)
        } else {
            print("Wrong characteristic")
        }
        
//        print(characteristic.value ?? "No value")
    }
    
    // Helper function
    // Unpacks the data from the byte array sent over from the peripheral
    // Stores it in class variables
    func getHESensorData(from characteristic: CBCharacteristic) {
        
        print("Getting HE Sensor Data")
        
        guard let characteristicData = characteristic.value else { return }
        
        // converts the characteristic data into a byte array
        let byteArray = [UInt8](characteristicData)
        
        var ismmHg = true
        var supportsPulse = true
        
        // firstly, extract core data about the metrics from the flags byte
        if byteArray[0] & 0x01 == 0 {
            print("Units are mmHg")
            self.pressureUnits = "mmHg"
        } else {
            print("Units are kPa")
            self.pressureUnits = "kPa"
            ismmHg = false
        }
        
        if byteArray[0] & (0x01 << 1) == 0 {
            print("Time stamp flag not present")
        } else {
            print("Time stamp flag present")
        }
        
        if byteArray[0] & (0x01 << 2) == 0 {
            print("Pulse rate flag not present")
            supportsPulse = false
        } else {
            print("Pulse rate flag present")
        }
        
        if byteArray[0] & (0x01 << 3) == 0 {
            print("User ID flag not present")
        } else {
            print("User ID flag present")
        }
        
        if byteArray[0] & (0x01 << 4) == 0 {
            print("Measurement status not present")
        } else {
            print("Measurement status present")
        }
        
        if ismmHg {
            print("We've got mmHg")
            self.systolicPressure = Float(byteArray[1])
            self.diastolicPressure = Float(byteArray[3])
            
            print("Systolic: \(systolicPressure)")
            print("Diastolic: \(diastolicPressure)")
        } else {
            print("We've got kPA")
        }
        
        if supportsPulse {
            print("Reading pulse data")
            self.heartRate = Float(byteArray[5])
            print("Heart rate: \(self.heartRate)")
            print(Float(byteArray[4]))
            print(Float(byteArray[5]))
            print(Float(byteArray[6]))
            print(Float(byteArray[7]))
            print(Float(byteArray[8]))
            print(Float(byteArray[9]))
            print(Float(byteArray[10]))
        }
        dataGatheringComplete = true
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
