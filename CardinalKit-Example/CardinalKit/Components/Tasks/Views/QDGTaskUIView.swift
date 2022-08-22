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
                    bleManager.connect(peripheral: peripheral.corePeripheral) // connect the device
                    presentationMode.wrappedValue.dismiss() // dismiss this view
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

// Display the list of connected devices
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print("User clicked device: \(peripheral.name)")
            print(peripheral.services)
            if peripheral.HE_Charactersitic != nil {
                peripheral.corePeripheral.setNotifyValue(true, for: peripheral.HE_Charactersitic!)
            }
        }
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
        }.sheet(isPresented: $presentAddDeviceMenu,
                onDismiss: {
                    presentAddDeviceMenu = false
                    print("REFRESHING BLUETOOTH DEVICES")
                    bleManager.refreshConnectedDevices()
                },
                content: {
                    AddDeviceView(bleManager: bleManager)
                })
        .onAppear {
            print("REFRESHING BLUETOOTH DEVICES")
            bleManager.refreshConnectedDevices()
        }.padding()
    }
}

struct QDGTaskUIView_Previews: PreviewProvider {
    static var previews: some View {
        QDGTaskUIView()
    }
}
