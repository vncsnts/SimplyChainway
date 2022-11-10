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
    
    public func connectToDevice(withName deviceName: String) {
        if let foundDeviceWithName = foundDevices.first(where: {$0.nameStr == deviceName}) {
            rfidBLEManager.connect(foundDeviceWithName.peripheral, macAddress: foundDeviceWithName.addressStr)
        }
    }
    
    public func setReadMode(isBarcode: Bool) {
        isBarcodeMode = isBarcode
    }
}

extension ChainwayService: FatScaleBluetoothManager {
    public func receiveData(withBLEmodel model: BLEModel!, result: String!) {
        if let foundModel = model {
            if !foundDevices.contains(where: {$0.nameStr == foundModel.nameStr}) && foundModel.nameStr != nil {
                foundDevices.append(foundModel)
                if !foundDevices.isEmpty {
                    delegate?.didReceiveDevices(devices: foundDevices.map({$0.nameStr}))
                }
            }
        }
    }
    
    public func connectPeripheralSuccess(_ nameStr: String!) {
        connectedDeviceName = nameStr
        delegate?.didConnectToDevice(deviceName: connectedDeviceName)
    }
    
    public func disConnectPeripheral() {
        print("disconnected to BLE Device")
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
        }
    }

    public func receiveData(withBLEDataSource dataSource: NSMutableArray!, allCount: Int, countArr: NSMutableArray!, dataSource1: NSMutableArray!, countArr1: NSMutableArray!, dataSource2: NSMutableArray!, countArr2: NSMutableArray!) {
        if let tagsAsStringArray = dataSource as? [String] {
            delegate?.didReceiveRFTags(tags: tagsAsStringArray)
        }
    }
}

public protocol ChainwayServiceDelegate: AnyObject {
    func didReceiveDevices(devices: [String]) //The Delegate for the array of the updates received BLE Devices
    func didConnectToDevice(deviceName: String)
    func didReceiveRFTags(tags: [String])
    func didReceiveBarcode(barcode: String)
}

extension ChainwayServiceDelegate {
    func didReceiveDevices(devices: [String]) {}
    func didConnectToDevice(deviceName: String) {}
    func didReceiveRFTags(tags: [String]) {}
    func didReceiveBarcode(barcode: String) {}
}

public enum CharacterSupport {
    case acsii
    case utf8
    case gb2312
}
