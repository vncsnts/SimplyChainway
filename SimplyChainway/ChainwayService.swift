//
//  ChainwayService.swift
//  ChainwayDemo (iOS)
//
//  Created by Vince Carlo Santos on 6/8/22.
//

import Foundation

@objcMembers
public class ChainwayService: NSObject {
    public static let shared = ChainwayService()
    public var characterSupported = CharacterSupport.acsii
    private var rfidBLEManager: RFIDBlutoothManager!
    public weak var delegate: ChainwayServiceDelegate?
    private var foundDevices = [BLEModel]()
    private var connectedDeviceName = ""
    private var isBarcodeMode = false
    
    public override init() {
        rfidBLEManager = RFIDBlutoothManager.share()
    }

    public func configureBLE() {
        rfidBLEManager.setFatScaleBluetoothDelegate(self)
        rfidBLEManager.bleDoScan()
    }
    
    public func stopScanningDevices() {
        rfidBLEManager.closeBleAndDisconnect()
    }
    
    public func connectToDevice(withName deviceName: String) {
        if let foundDeviceWithName = foundDevices.first(where: {$0.nameStr == deviceName}) {
            rfidBLEManager.connect(foundDeviceWithName.peripheral, macAddress: foundDeviceWithName.addressStr)
        }
    }
    
    public func setReadMode(isBarcode: Bool) {
        isBarcodeMode = isBarcode
    }
    
    public func setReadPower(intPower: Int) {
        let intString = intPower.description
        rfidBLEManager.setLaunchPowerWithstatus("1", antenna: "1", readStr: intString, writeStr: intString)
    }
    
    public func getBatteryLevel() {
        rfidBLEManager.getBatteryLevel()
    }
    
    public func disconnectDevice() {
        rfidBLEManager.closeBleAndDisconnect()
    }
}

extension ChainwayService: FatScaleBluetoothManager {
    public func receiveData(withBLEmodel model: BLEModel!, result: String!) {
        if let foundModel = model {
            if !foundDevices.contains(where: {$0.nameStr == foundModel.nameStr}) && foundModel.nameStr != nil && foundModel.peripheral != nil && foundModel.nameStr.hasPrefix("D5") {
                foundDevices.append(foundModel)
                delegate?.didReceiveDevice(device: foundModel.peripheral)
            }
        }
    }
    
    public func connectPeripheralSuccess(_ nameStr: String!) {
        rfidBLEManager.isStreamRealTimeTags = true
        rfidBLEManager.isSupportRssi = true
        rfidBLEManager.tagTypeStr = "0"
        rfidBLEManager.isReadNewLabEPC = true
        rfidBLEManager.isReadNewLabEPCANDTID = false
        rfidBLEManager.isReadNewLabEPCANDTIDANDUSER = false
        rfidBLEManager.setEpcTidUserWithAddressStr("0", length: "0", epcStr: "0")
        connectedDeviceName = nameStr
        delegate?.didConnectToDevice(deviceName: connectedDeviceName)
    }
    
    public func disConnectPeripheral() {
        delegate?.didDisconnectToDevice(deviceName: connectedDeviceName)
    }
    
    public func didFailPeripheral() {
        delegate?.didFailWithDevice(deviceName: connectedDeviceName)
    }
    
    public func receiveMessageWithtype(_ typeStr: String!, dataStr: String!) {
        if typeStr == "e6" {
            if !isBarcodeMode {
                if rfidBLEManager.isgetLab {
                    // On Key OFF
                    rfidBLEManager.isgetLab = false
                    rfidBLEManager.stopcontinuitySaveLabel()
                } else {
                    //On Key ON
                    rfidBLEManager.continuitySaveLabel(withCount: "0")
                    rfidBLEManager.isgetLab = true
                }
            } else {
                rfidBLEManager.start2DScan()
            }
        } else if typeStr == "e55" {
            delegate?.didReceiveBarcode(barcode: dataStr)
        } else if typeStr == "e5" {
            if let batteryInt = Int(dataStr) {
                delegate?.didReceiveBatteryLevel(batteryLevel: batteryInt)
            }
        }
    }

    public func receiveData(withBLEDataSource dataSource: NSMutableArray!, allCount: Int, countArr: NSMutableArray!, dataSource1: NSMutableArray!, countArr1: NSMutableArray!, dataSource2: NSMutableArray!, countArr2: NSMutableArray!) {
        //Ignored and not needed as its returning array type
    }
    
    public func didScanRF(_ epcWithRssiPostfix: String!) {
        if var epcRssi = epcWithRssiPostfix {
            let rssiString = String(epcRssi.suffix(4))
            if let rawDecimalIntRssi = Int(rssiString, radix: 16) {
                let rssi = (65535 - rawDecimalIntRssi) / 10
                epcRssi.removeLast(4)
                delegate?.didReceiveRF(epc: epcRssi, rssi: rssi)
            }
            
        }
    }
}

public protocol ChainwayServiceDelegate: AnyObject {
    func didReceiveDevice(device: CBPeripheral)
    func didConnectToDevice(deviceName: String)
    func didDisconnectToDevice(deviceName: String)
    func didFailWithDevice(deviceName: String)
    func didReceiveBatteryLevel(batteryLevel: Int)
    func didReceiveRF(epc: String, rssi: Int)
    func didReceiveBarcode(barcode: String)
}

extension ChainwayServiceDelegate {
    func didReceiveDevice(device: CBPeripheral) {}
    func didConnectToDevice(deviceName: String) {}
    func didDisconnectToDevice(deviceName: String) {}
    func didFailWithDevice(deviceName: String) {}
    func didReceiveBatteryLevel(batteryLevel: Int) {}
    func didReceiveRF(epc: String, rssi: Int) {}
    func didReceiveBarcode(barcode: String) {}
}

public enum CharacterSupport {
    case acsii
    case utf8
    case gb2312
}
