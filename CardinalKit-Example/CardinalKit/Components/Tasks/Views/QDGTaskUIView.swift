//
//  QDGTaskUIView.swift
//  CardinalKit_Example
//
//  Created by Gary Burnett on 8/14/22.
//  Copyright © 2022 CardinalKit. All rights reserved.
//

import SwiftUI
import CardinalKit

struct AddDeviceView: View {
    
    @ObservedObject var bleManager: BLEManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Searching for Bluetooth Devices").font(.title)
            
            List(bleManager.peripherals) { peripheral in
                HStack {
                    Text(peripheral.name)
                    Spacer()
                    Text(String(peripheral.rssi))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    bleManager.connect(peripheral: peripheral.corePeripheral)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            
        }.onAppear {
            print("Add Bluetooth Device Menu Appeared")
            self.bleManager.peripherals.removeAll()
            self.bleManager.startScanning()
        }.onDisappear {
            print("Add Bluetooth Device Menu Disappeared")
            self.bleManager.stopScanning()
        }.padding()
    }
}

struct ConnectedDeviceView: View {
    
    @ObservedObject var bleManager: BLEManager
    var peripheral: Peripheral
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(peripheral.name)
                Spacer()
            }
            HStack {
                if (peripheral.heartRate) {
                    Image(systemName: "suit.heart.fill")
                }
                if (peripheral.weight) {
                    Image(systemName: "scalemass.fill")
                }
                if (peripheral.bloodPressure) {
                    Image(systemName: "arrow.up.heart.fill")
                }
                Spacer()
                
                Text("\(peripheral.batteryLevel)%")
                
                if (peripheral.batteryLevel >= 0 && peripheral.batteryLevel < 20) {
                    Image(systemName: "battery.0")
                } else if peripheral.batteryLevel < 40 {
                    Image(systemName: "battery.25")
                } else {
                    Image(systemName: "battery.100")
                }
            }
            
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print("Click detected")
            //print(acceptableDeviceCBUUIDList)
            print(peripheral.services)
            if peripheral.bloodPressureCharacteristic != nil {
//                peripheral.corePeripheral.readValue(for: peripheral.bloodPressureCharacteristic!)
                peripheral.corePeripheral.setNotifyValue(true, for: peripheral.bloodPressureCharacteristic!)
            }
//            bleManager.discoverServices(peripheral: peripheral.corePeripheral)
        }
    }
}

struct QDGTaskUIView: View {
    
    @ObservedObject var bleManager = BLEManager()
    @State var presentAddDeviceMenu = false
    
    var body: some View {
        VStack(spacing: 10) {
            Image("CKLogo")
                .resizable()
                .scaledToFit()
                .padding(.leading, Metrics.PADDING_HORIZONTAL_MAIN*4)
                .padding(.trailing, Metrics.PADDING_HORIZONTAL_MAIN*4)
            
            Text("Welcome to the QDG Test!")
                .multilineTextAlignment(.leading)
                .font(.system(size: 18, weight: .bold, design: .default))
                .padding(.leading, Metrics.PADDING_HORIZONTAL_MAIN)
                .padding(.trailing, Metrics.PADDING_HORIZONTAL_MAIN)
            
            Text("We will now connect to the KeyDuo")
                .multilineTextAlignment(.leading)
                .font(.system(size: 18, weight: .regular, design: .default))
                .padding(.leading, Metrics.PADDING_HORIZONTAL_MAIN)
                .padding(.trailing, Metrics.PADDING_HORIZONTAL_MAIN)
            
            Spacer()
            
            Text("Bluetooth Devices")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer()
            
            List(bleManager.connectedPeripherals) { peripheral in
                ConnectedDeviceView(bleManager: bleManager, peripheral: peripheral)
            }
            
            Button(action: {
                presentAddDeviceMenu = true
            }) {
                HStack {
                    Spacer()
                    Text("Add Device")
                    Spacer()
                }
            }

            Spacer()
            
            Image("SBDLogoGrey")
                .resizable()
                .scaledToFit()
                .padding(.leading, Metrics.PADDING_HORIZONTAL_MAIN*4)
                .padding(.trailing, Metrics.PADDING_HORIZONTAL_MAIN*4)
        }.sheet(isPresented: $presentAddDeviceMenu, onDismiss: {presentAddDeviceMenu = false}, content: {
            AddDeviceView(bleManager: bleManager)
        })
        .onAppear {
            bleManager.refreshConnectedDevices()
        }.padding()
    }
}

struct QDGTaskUIView_Previews: PreviewProvider {
    static var previews: some View {
        QDGTaskUIView()
    }
}
