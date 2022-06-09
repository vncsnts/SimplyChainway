//
//  ContentView.swift
//  Shared
//
//  Created by Vince Carlo Santos on 6/8/22.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        TabView {
            rfidTab
                .tabItem {
                    Label("RFID", systemImage: "barcode.viewfinder")
                }
            barcodeTab
                .tabItem {
                    Label("Barcode", systemImage: "barcode")
                }
        }
        .onAppear {
            viewModel.connectToChainwayService()
        }
        .popover(isPresented: $viewModel.presentDevices, content: {
            List {
                Section {
                    ForEach((0..<viewModel.stringHandheldsFound.count), id: \.self) { handheldsFoundStringIndex in
                        Text(viewModel.stringHandheldsFound[handheldsFoundStringIndex])
                            .onTapGesture {
                                viewModel.connectToDevice(handheldName: viewModel.stringHandheldsFound[handheldsFoundStringIndex])
                            }
                    }
                } header: {
                    Text("Found BLE Devices")
                }
            }
        })
    }
    
    var rfidTab: some View {
        List {
            if !viewModel.connectedDeviceName.isEmpty {
                Section {
                    ForEach((0..<viewModel.stringTagsFound.count), id: \.self) { tagsFoundStringIndex in
                        Text(viewModel.stringTagsFound[tagsFoundStringIndex])
                    }
                } header: {
                    Text("RFID Tags")
                }
            }
        }
        .onAppear(perform: {
            viewModel.setToRFMode()
        })
        .listStyle(.plain)
        .refreshable {
            viewModel.stringTagsFound.removeAll()
        }
    }
    
    var barcodeTab: some View {
        List {
            if !viewModel.connectedDeviceName.isEmpty {
                Section {
                    ForEach((0..<viewModel.stringBarcodesFound.count), id: \.self) { barcodesFoundStringIndex in
                        Text(viewModel.stringBarcodesFound[barcodesFoundStringIndex])
                    }
                } header: {
                    Text("Barcode Reads")
                }
            }
        }
        .onAppear(perform: {
            viewModel.setToBarcodeMode()
        })
        .listStyle(.plain)
        .refreshable {
            viewModel.stringBarcodesFound.removeAll()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
