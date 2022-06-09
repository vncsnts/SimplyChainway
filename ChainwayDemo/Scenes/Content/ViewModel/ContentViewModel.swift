//
//  ContentViewModel.swift
//  ChainwayDemo (iOS)
//
//  Created by Vince Carlo Santos on 6/8/22.
//

import Foundation
import SwiftUI

class ContentViewModel: NSObject, ObservableObject {
    let chainwayService = ChainwayService()
    @Published var presentDevices = true
    @Published var connectedDeviceName = ""
    @Published var stringHandheldsFound = [String]()
    @Published var stringTagsFound = [String]()
    @Published var stringBarcodesFound = [String]()
    
    func connectToChainwayService() {
        chainwayService.delegate = self
        chainwayService.configureBLE()
    }
    
    func connectToDevice (handheldName: String) {
        chainwayService.connectToDevice(withName: handheldName)
    }
    
    func setToBarcodeMode() {
        chainwayService.setReadMode(isBarcode: true)
    }
    
    func setToRFMode() {
        chainwayService.setReadMode(isBarcode: false)
    }
}

extension ContentViewModel: ChainwayServiceDelegate {
    func didReceiveRFTags(tags: [String]) {
        stringTagsFound = tags
    }
    
    func didReceiveBarcode(barcode: String) {
        stringBarcodesFound.append(barcode)
    }
    
    func didConnectToDevice(deviceName: String) {
        connectedDeviceName = deviceName
        presentDevices = false
    }
    
    func didReceiveDevices(devices: [String]) {
        stringHandheldsFound = devices
    }
}
