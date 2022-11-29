//
//  RFIDBlutoothManager.m
//  RFID_ios
//
//  Created by chainway on 2018/4/26.
//  Copyright © 2018年 chainway. All rights reserved.
//

#import "RFIDBlutoothManager.h"
#import "AppHelper.h"


#define kFatscaleTimeOut 5.0

#define serviceUUID  @"6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define writeUUID  @"6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define receiveUUID  @"6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
//#define serviceUUID  @"6e400001-b5a3-f393-e0a9-e50e24dcca9e"
//#define writeUUID  @"6e400002-b5a3-f393-e0a9-e50e24dcca9e"
//#define receiveUUID  @"6e400003-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_NAME_UUID  @"00001800-0000-1000-8000-00805f9b34fb"
#define BLE_NAME_CHARACTE   @"00002a00-0000-1000-8000-00805f9b34fb"

#define macAddressStr @"macAddress"
#define BLE_SEND_MAX_LEN 20

#define UpdateBLE_SEND_MAX_LEN 20

@interface RFIDBlutoothManager () <CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) NSTimer *bleScanTimer;
@property (nonatomic, strong) CBPeripheral *peripheral;

@property (nonatomic, strong) NSMutableArray *peripheralArray;
@property (nonatomic, weak) id<PeripheralAddDelegate> addDelegate;
@property (nonatomic, weak) id<FatScaleBluetoothManager> managerDelegate;

@property (nonatomic, copy) NSString *connectPeripheralCharUUID;

@property (nonatomic, strong) NSMutableArray *BLEServerDatasArray;

@property (nonatomic, strong) CBCharacteristic *myCharacteristic;
@property (nonatomic, strong) NSTimer *connectTime;//计算蓝牙连接是否超时的定时器
@property (nonatomic, strong) NSTimer *sendGetTagRequestTime;//定时发送获取标签命令
@property (nonatomic, strong) NSMutableArray *dataList;
@property (nonatomic, strong) NSMutableString *dataStr;
@property (nonatomic, assign) NSInteger dataCount;
@property (nonatomic, copy) NSString *temStr;
@property (nonatomic, assign) BOOL isInfo;
@property (nonatomic, assign) BOOL isName;
@property (nonatomic, assign) BOOL isFirstSendGetTAGCmd;
/** isHeader */
@property (assign,nonatomic) BOOL isHeader;

@end

@implementation RFIDBlutoothManager


+ (instancetype)shareManager
{
    static RFIDBlutoothManager *shareManager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shareManager = [[self alloc] init];
    });
    return shareManager;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self centralManager];
        self.dataCount=0;
        self.isInfo=NO;
        self.isSupportRssi=NO;
        self.isStreamRealTimeTags=NO;
        self.isBLE40=NO;
        self.isName=NO;
        self.isHeader = NO;
        self.isSetGen2Data = NO;
        self.isGetGen2Data = NO;
        self.dataList=[[NSMutableArray alloc]init];
        self.dataSource=[[NSMutableArray alloc]init];
        self.dataSource1 = [NSMutableArray array];
        self.dataSource2 = [NSMutableArray array];
        self.isFirstSendGetTAGCmd=YES;
        _tagStr=[[NSMutableString alloc]init];
        _allCount=0;
        self.isgetLab=NO;
        self.countArr=[[NSMutableArray alloc]init];
        self.countArr1 = [NSMutableArray array];
        self.countArr2 = [NSMutableArray array];
        
        
    }
    return self;
}

#pragma mark - Public methods
- (void)bleDoScan
{
    self.bleScanTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(startBleScan) userInfo:nil repeats:YES];
}

- (void)connectPeripheral:(CBPeripheral *)peripheral macAddress:(NSString *)macAddress
{
    NSArray *aa=[macAddress componentsSeparatedByString:@":"];
    NSMutableString *str=[[NSMutableString alloc]init];
    for (NSInteger i=0; i<aa.count; i++) {
        [str appendFormat:@"%@",aa[i]];
    }
    
    NSString *strr=[NSString stringWithFormat:@"%@",str];
    
    [[NSUserDefaults standardUserDefaults] setObject:strr forKey:macAddressStr];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.peripheral = peripheral;
    
    [self.centralManager connectPeripheral:peripheral options:nil];
}
- (void)cancelConnectBLE
{
    [self.centralManager cancelPeripheralConnection:self.peripheral];
}
- (void)setFatScaleBluetoothDelegate:(id<FatScaleBluetoothManager>)delegate
{
    self.managerDelegate = delegate;
}

- (void)setPeripheralAddDelegate:(id<PeripheralAddDelegate>)delegate
{
    self.addDelegate = delegate;
}



- (Byte )getBye8:(Byte[])data
{
    Byte byte8 = data[2] + data[3] + data[4] + data[5] +data[6];
    byte8 = (unsigned char) ( byte8 & 0x00ff);
    return byte8;
}

//获取固件版本号
-(void)getFirmwareVersion2
{
    NSData *data = [BluetoothUtil getFirmwareVersion];
    [self sendDataToBle:data];
}
//获取电池电量
-(void)getBatteryLevel
{
    self.isGetBattery = YES;
    NSData *data=[BluetoothUtil getBatteryLevel];
    [self sendDataToBle:data];
    
}
//获取设备当前温度
-(void)getServiceTemperature
{
    self.isTemperature = YES;
    NSData *data=[BluetoothUtil getServiceTemperature];
    [self sendDataToBle:data];
}
//开启2D扫描
-(void)start2DScan
{
    self.isCodeLab = YES;
    NSData *data=[BluetoothUtil start2DScan];
    [self sendDataToBle:data];
    
}

//获取硬件版本号
-(void)getHardwareVersion
{
    self.isGetVerson = YES;
    NSData *data=[BluetoothUtil getHardwareVersion];
    [self sendDataToBle:data];
    
}
//获取固件版本号
-(void)getFirmwareVersion
{
    self.isGetVerson = YES;
    NSData *data = [BluetoothUtil getFirmwareVersion];
    [self sendDataToBle:data];
}
//获取设备ID
-(void)getServiceID
{
    NSData *data = [BluetoothUtil getServiceID];
    [self sendDataToBle:data];
}
//软件复位
-(void)softwareReset
{
    NSData *data = [BluetoothUtil softwareReset];
    [self sendDataToBle:data];
}
//开启蜂鸣器
-(void)setOpenBuzzer
{
    self.isOpenBuzzer = YES;
    NSData *data = [BluetoothUtil openBuzzer];
    [self sendDataToBle:data];
}
//关闭蜂鸣器
-(void)setCloseBuzzer
{
    self.isCloseBuzzer  = YES;
    NSData *data = [BluetoothUtil closeBuzzer];
    [self sendDataToBle:data];
}


//设置标签读取格式
-(void)setEpcTidUserWithAddressStr:(NSString *)addressStr length:(NSString *)lengthStr epcStr:(NSString *)epcStr
{
    self.isSetTag = YES;
    NSData *data = [BluetoothUtil setEpcTidUserWithAddressStr:addressStr length:lengthStr EPCStr:epcStr];
    [self sendDataToBle:data];
}
//获取标签读取格式
-(void)getEpcTidUser
{
    self.isGetTag = YES;
    NSData *data = [BluetoothUtil getEpcTidUser];
    [self sendDataToBle:data];
}



//设置发射功率
-(void)setLaunchPowerWithstatus:(NSString *)status antenna:(NSString *)antenna readStr:(NSString *)readStr writeStr:(NSString *)writeStr
{
    self.isSetEmissionPower = YES;
    NSData *data = [BluetoothUtil setLaunchPowerWithstatus:status antenna:antenna readStr:readStr writeStr:writeStr];
    [self sendDataToBle:data];
    
}
//获取当前发射功率
-(void)getLaunchPower
{
    self.isGetEmissionPower = YES;
    NSData *data = [BluetoothUtil getLaunchPower];
    [self sendDataToBle:data];
    
}
//跳频设置
-(void)detailChancelSettingWithstring:(NSString *)str
{
    NSData *data = [BluetoothUtil detailChancelSettingWithstring:str];
    [self sendDataToBle:data];
}
//获取当前跳频设置状态
-(void)getdetailChancelStatus
{
    NSData *data = [BluetoothUtil getdetailChancelStatus];
    [self sendDataToBle:data];
}

//区域设置
-(void)setRegionWithsaveStr:(NSString *)saveStr regionStr:(NSString *)regionStr
{
    NSData *data = [BluetoothUtil setRegionWithsaveStr:saveStr regionStr:regionStr];
    [self sendDataToBle:data];
}
//获取区域设置
-(void)getRegion
{
    NSData *data = [BluetoothUtil getRegion];
    [self sendDataToBle:data];
}

//单次盘存标签
-(void)singleSaveLabel
{
    self.isSingleSaveLable  = YES;
    NSData *data = [BluetoothUtil singleSaveLabel];
    [self sendDataToBle:data];
}
//********************************************
- (void)handleTimer
{
    if(self.isFirstSendGetTAGCmd){
        //如果开始盘底后，马上停止。 那么直接退回定时器
        self.isFirstSendGetTAGCmd=NO;
        for(int k=0;k<300;k++){
            if(self.isgetLab == NO){
                [self.sendGetTagRequestTime invalidate];
                self.sendGetTagRequestTime=nil;
                NSLog(@"退出获取标签定时器!");
                return;
            }
            usleep(1000);
        }
    }
    
    if (self.connectDevice ==YES && self.isgetLab==YES) {
        NSLog(@"获取标签定时器!");
        [self getLabMessage];
    }else{
        [self.sendGetTagRequestTime invalidate];
        self.sendGetTagRequestTime=nil;
        NSLog(@"退出获取标签定时器!");
    }
}
//连续盘存标签
-(void)continuitySaveLabelWithCount:(NSString *)count
{
    //获取蓝牙版本
    //[self getFirmwareVersion];
    
    NSData *data = [BluetoothUtil continuitySaveLabelWithCount:count];
    [self sendDataToBle:data];
    
    if (self.sendGetTagRequestTime == nil){
        self.isFirstSendGetTAGCmd=YES;
        if(self.isBLE40 == YES){
            self.sendGetTagRequestTime = [NSTimer scheduledTimerWithTimeInterval:0.08 target:self selector:@selector(handleTimer) userInfo:nil repeats:YES];
        }else{
            self.sendGetTagRequestTime = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(handleTimer) userInfo:nil repeats:YES];
        }
    }
    
}

//停止连续盘存标签
-(void)StopcontinuitySaveLabel
{
    NSData *data = [BluetoothUtil StopcontinuitySaveLabel];
    [self sendDataToBle:data];
}
//读标签数据区
-(void)readLabelMessageWithPassword:(NSString *)password MMBstr:(NSString *)MMBstr MSAstr:(NSString *)MSAstr MDLstr:(NSString *)MDLstr MDdata:(NSString *)MDdata MBstr:(NSString *)MBstr SAstr:(NSString *)SAstr DLstr:(NSString *)DLstr isfilter:(BOOL)isfilter
{
    NSData *data = [BluetoothUtil readLabelMessageWithPassword:password MMBstr:MMBstr MSAstr:MSAstr MDLstr:MDLstr MDdata:MDdata MBstr:MBstr SAstr:SAstr DLstr:DLstr isfilter:isfilter];
    NSLog(@"data===%@",data);
    for (int i = 0; i < [data length]; i += BLE_SEND_MAX_LEN) {
        // 预加 最大包长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + BLE_SEND_MAX_LEN) < [data length]) {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, BLE_SEND_MAX_LEN];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            NSLog(@"%@",subData);
            [self sendDataToBle:subData];
            //根据接收模块的处理能力做相应延时
            usleep(80 * 1000);
        }
        else {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            [self sendDataToBle:subData];
            usleep(80 * 1000);
        }
    }
}
//写标签数据区
-(void)writeLabelMessageWithPassword:(NSString *)password MMBstr:(NSString *)MMBstr MSAstr:(NSString *)MSAstr MDLstr:(NSString *)MDLstr MDdata:(NSString *)MDdata MBstr:(NSString *)MBstr SAstr:(NSString *)SAstr DLstr:(NSString *)DLstr writeData:(NSString *)writeData isfilter:(BOOL)isfilter
{
    NSData *data = [BluetoothUtil writeLabelMessageWithPassword:password MMBstr:MMBstr MSAstr:MSAstr MDLstr:MDLstr MDdata:MDdata MBstr:MBstr SAstr:SAstr DLstr:DLstr writeData:writeData isfilter:isfilter];
    
    for (int i = 0; i < [data length]; i += BLE_SEND_MAX_LEN) {
        // 预加 最大包长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + BLE_SEND_MAX_LEN) < [data length]) {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, BLE_SEND_MAX_LEN];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            NSLog(@"subData==%@",subData);
            [self sendDataToBle:subData];
            //根据接收模块的处理能力做相应延时
            usleep(80 * 1000);
        }
        else {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            NSLog(@"subData==%@",subData);
            [self sendDataToBle:subData];
            usleep(80 * 1000);
        }
    }
}
//Lock标签
-(void)lockLabelWithPassword:(NSString *)password MMBstr:(NSString *)MMBstr MSAstr:(NSString *)MSAstr MDLstr:(NSString *)MDLstr MDdata:(NSString *)MDdata ldStr:(NSString *)ldStr isfilter:(BOOL)isfilter
{
    NSData *data=[BluetoothUtil lockLabelWithPassword:password MMBstr:MMBstr MSAstr:MSAstr MDLstr:MDLstr MDdata:MDdata ldStr:ldStr isfilter:isfilter];
    NSLog(@"data===%@",data);
    for (int i = 0; i < [data length]; i += BLE_SEND_MAX_LEN) {
        // 预加 最大包长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + BLE_SEND_MAX_LEN) < [data length]) {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, BLE_SEND_MAX_LEN];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            NSLog(@"%@",subData);
            [self sendDataToBle:subData];
            //根据接收模块的处理能力做相应延时
            usleep(80 * 1000);
        }
        else {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            [self sendDataToBle:subData];
            usleep(80 * 1000);
        }
    }
}//
//kill标签。
-(void)killLabelWithPassword:(NSString *)password MMBstr:(NSString *)MMBstr MSAstr:(NSString *)MSAstr MDLstr:(NSString *)MDLstr MDdata:(NSString *)MDdata isfilter:(BOOL)isfilter
{
    NSData *data = [BluetoothUtil killLabelWithPassword:password MMBstr:MMBstr MSAstr:MSAstr MDLstr:MDLstr MDdata:MDdata isfilter:isfilter];
    NSLog(@"data===%@",data);
    for (int i = 0; i < [data length]; i += BLE_SEND_MAX_LEN) {
        // 预加 最大包长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + BLE_SEND_MAX_LEN) < [data length]) {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, BLE_SEND_MAX_LEN];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            NSLog(@"%@",subData);
            [self sendDataToBle:subData];
            //根据接收模块的处理能力做相应延时
            usleep(80 * 1000);
        }
        else {
            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i", i, (int)([data length] - i)];
            NSData *subData = [data subdataWithRange:NSRangeFromString(rangeStr)];
            [self sendDataToBle:subData];
            usleep(80 * 1000);
        }
    }
}
//获取标签数据
-(void)getLabMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSData *data = [BluetoothUtil getLabMessage];
        [self sendDataToBle:data];
    });
}



#pragma mark - Private Methods
- (void)startBleScan
{
    if (self.centralManager.state == CBCentralManagerStatePoweredOff)
    {
        self.connectDevice = NO;
        if ([self.managerDelegate respondsToSelector:@selector(connectBluetoothFailWithMessage:)])
        {
            [self.managerDelegate connectBluetoothFailWithMessage:[self centralManagerStateDescribe:CBCentralManagerStatePoweredOff]];
        }
        return;
    }
    if (_connectTime == nil)
    {
        //创建连接制定设备的定时器
        _connectTime = [NSTimer scheduledTimerWithTimeInterval:kFatscaleTimeOut target:self selector:@selector(connectTimeroutEvent) userInfo:nil repeats:NO];
    }
    self.uuidDataList=[[NSMutableArray alloc]init];
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @ YES}];
}
- (void)connectTimeroutEvent
{
    
    [_connectTime invalidate];
    _connectTime = nil;
    [self stopBleScan];
    [self.centralManager stopScan];
    [self.managerDelegate receiveDataWithBLEmodel:nil result:@"1"];
    
}

- (void)stopBleScan
{
    [self.bleScanTimer invalidate];
}

- (void)closeBleAndDisconnect
{
    [self stopBleScan];
    [self.centralManager stopScan];
    if (self.peripheral) {
        [self.centralManager cancelPeripheralConnection:self.peripheral];
    }
}
//Nordic_UART_CW HotWaterBottle
- (void)sendDataToBle:(NSData *)data
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.peripheral writeValue:data forCharacteristic:self.myCharacteristic type:CBCharacteristicWriteWithoutResponse];
    });
}


#pragma maek - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn)
    {
        if ([self.managerDelegate respondsToSelector:@selector(connectBluetoothFailWithMessage:)])
        {
            if (central.state == CBCentralManagerStatePoweredOff)
            {
                self.connectDevice = NO;
                [self.managerDelegate connectBluetoothFailWithMessage:[self centralManagerStateDescribe:CBCentralManagerStatePoweredOff]];
            }
        }
        
    }
    
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            NSLog(@"CBCentralManagerStatePoweredOn");
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"蓝牙断开：CBCentralManagerStatePoweredOff");
            break;
        default:
            break;
    }
}

#pragma mark - 扫描到设备
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *,id> *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSData *manufacturerData = [advertisementData valueForKeyPath:CBAdvertisementDataManufacturerDataKey];
    
    if (advertisementData.description.length > 0)
    {
        NSLog(@"/-------广播数据advertisementData:%@--------",advertisementData.description);
        NSLog(@"-------外设peripheral:%@--------/",peripheral.description);
        NSLog(@"peripheral.services==%@",peripheral.identifier.UUIDString);
        NSLog(@"RSSI==%@",RSSI);
    }
    
    NSString *bindString = @"";
    NSString *str = @"";
    if (manufacturerData.length>=8) {
        NSData *subData = [manufacturerData subdataWithRange:NSMakeRange(manufacturerData.length-8, 8)];
        bindString = subData.description;
        str = [self getVisiableIDUUID:bindString];
        NSLog(@" GG == %@ == GG",str);
        
    }
    
    NSString *typeStr=@"1";
    for (NSString *uuidStr in self.uuidDataList) {
        if ([peripheral.identifier.UUIDString isEqualToString:uuidStr]) {
            typeStr=@"2";
        }
    }
    if ([typeStr isEqualToString:@"1"]) {
        [self.uuidDataList addObject:peripheral.identifier.UUIDString];
        
        BLEModel *model=[BLEModel new];
        model.nameStr=peripheral.name;
        model.rssStr=[NSString stringWithFormat:@"%@",RSSI];
        model.addressStr=str;
        model.peripheral=peripheral;
        [self.managerDelegate receiveDataWithBLEmodel:model result:@"0"];
    }
    
    
}
//连接外设成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    self.connectDevice = YES;
    NSLog(@"-- 成功连接外设 --：%@",peripheral.name);
    NSLog(@"Did connect to peripheral: %@",peripheral);
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
    [self.centralManager stopScan];
    [self stopBleScan];
    
    [self.managerDelegate connectPeripheralSuccess:peripheral.name];
    
}

//断开外设连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.connectDevice = NO;
    // LogRed(@"蓝牙已断开");
    [self.managerDelegate disConnectPeripheral];
    
}

//连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    // LogRed(@"-- 连接失败 --");
    self.connectDevice = NO;
    [self.managerDelegate didFailPeripheral];
}

#pragma mark - CBPeripheralDelegate
//发现服务时调用的方法
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"%s", __func__);
    NSLog(@"error：%@", error);
    NSLog(@"-==----includeServices = %@",peripheral.services);
    for (CBService *service in peripheral.services) {
        [peripheral  discoverCharacteristics:nil forService:service];
        
    }
}

//发现服务的特征值后回调的方法
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *c in service.characteristics) {
        [peripheral discoverDescriptorsForCharacteristic:c];
    }
    
    if ([service.UUID.UUIDString isEqualToString:serviceUUID]) {
        for (CBCharacteristic *characteristic in service.characteristics) {
            
            if ([characteristic.UUID.UUIDString isEqualToString:writeUUID]) {
                
                if (characteristic) {
                    self.myCharacteristic  = characteristic;
                }
            }
            if ([characteristic.UUID.UUIDString isEqualToString:receiveUUID]) {
                
                if (characteristic) {
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }
            }
        }
    }
    if ([service.UUID.UUIDString isEqualToString:BLE_NAME_UUID]) {
        NSLog(@"-----=====find BLE NAME UUID Service");
        for (CBCharacteristic *characteristic in service.characteristics) {
            if ([characteristic.UUID.UUIDString isEqualToString:BLE_NAME_CHARACTE]) {
                if (characteristic) {
                    //[peripheral setValue:@"" forKey:BLE_NAME_CHARACTE];
                }
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    // NSLog(@"didUpdateNotificationStateForCharacteristic: %@",characteristic.value);
}

//*******************解析按键*************************
const NSInteger dataKeyBuffLen=9;
Byte dataKey[9];
NSInteger dataIndex=0;
- (void) getKeyData:(Byte*) data {
    //A5 5A 00 09 E6 04 EB0D0A
    int flag = 0;
    int keyCode = 0;
    int checkCode = 0;//校验码
    for (int k = 0; k < dataKeyBuffLen; k++) {
        int temp = (data[k] & 0xff);
        switch (flag) {
            case 0:
                if(temp == 0xC8){
                    flag = 1;
                }else if(temp == 0xA5){
                    flag = 111;
                }
                break;
            case 111:
                flag = (temp == 0x5A) ? 2 : 0;
                break;
            case 1:
                flag = (temp == 0x8C) ? 2 : 0;
                break;
            case 2:
                flag = (temp == 0x00) ? 3 : 0;
                break;
            case 3:
                flag = (temp == 0x09) ? 4 : 0;
                break;
            case 4:
                flag = (temp == 0xE6) ? 5 : 0;
                break;
            case 5:
                flag = (temp == 0x01 || temp == 0x02 || temp == 0x03 || temp == 0x04) ? 6 : 0;
                keyCode = data[k];
                break;
            case 6:
                checkCode = checkCode ^ 0x00;
                checkCode = checkCode ^ 0x09;
                checkCode = checkCode ^ 0xE6;
                checkCode = checkCode ^ keyCode;
                flag = (temp == checkCode) ? 7 : 0;
                break;
            case 7:
                flag = (temp == 0x0D) ? 8 : 0;
                break;
            case 8:
                flag = (temp == 0x0A) ? 9 : 0;
                break;
        }
        if (flag == 9)
            break;
    }
    if (flag == 9) {
        NSLog(@"按下扫描按键");
        [self.managerDelegate receiveMessageWithtype:@"e6" dataStr:@""];
    }
    
}


-(void) parseKeyDown:(NSData *) data{
    Byte *tempBytes = (Byte *)data.bytes;
    for (int k = 0; k < data.length; k++) {
        dataKey[dataIndex++]=tempBytes[k];
        if(dataIndex>=dataKeyBuffLen){
            dataIndex=dataKeyBuffLen-1;
            if(dataKey[0]== 0xC8 && dataKey[1]==0x8c && dataKey[4]==0xE6 && dataKey[dataKeyBuffLen-2]==0x0D  && dataKey[dataKeyBuffLen-1]==0x0A){
                [self getKeyData:dataKey];
            }else if(dataKey[0]== 0xA5 && dataKey[1]==0x5A && dataKey[4]==0xE6 && dataKey[dataKeyBuffLen-2]==0x0D  && dataKey[dataKeyBuffLen-1]==0x0A){
                [self getKeyData:dataKey];
            }
            for(int s=0;s<dataKeyBuffLen-1;s++){
                dataKey[s]=dataKey[s+1];
            }
        }
        
    }
}
//******************************************************

//特征值更新时回调的方法
#pragma mark - 接收数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"----====>>>>>>>>characteristic.value==%@",characteristic.value);
    NSString *dataStr=[AppHelper dataToHex:characteristic.value];
    //解析按键
    [self parseKeyDown:characteristic.value];
    
    NSString *typeStr;
    if (dataStr.length>10) {
        typeStr=[dataStr substringWithRange:NSMakeRange(8, 2)];
    } else {
        typeStr=@"10000";
    }
    
    
    if (self.singleLableStr.length>0) {
        //单次盘点n标签
        [self.singleLableStr appendString:dataStr];
        if (dataStr.length<40) {
            //NSLog(@"self.singleLableStr===%@",self.singleLableStr);
            //  天线号 1 个字节,信号值 2 个字节,1个字节校验码,2个字节 RSSI
            //       数据长度（2字节）  cmd      pc(2字节)              epc                     rssi(2字节)   ant((2字节))     crc(1字节)
            //c8 8c    00 19          81      34 00     39 31 31 31 32 32 32 32 33 33 33 34     fe b7      01               eb          0d 0a
            //                                34 00     39 31 31 31 32 32 32 32 33 33 33 34     fe 54      01
            NSData *rawData=[AppHelper hexToNSData:self.singleLableStr];
            NSData *tagTempData = [self parseDataWithOriginalStr:rawData cmd:0x81];
            
            //  NSLog(@"singleLableStr= %@",self.singleLableStr);
            //  NSLog(@"data= %@",[AppHelper dataToHex:tagTempData]);
            //  NSLog(@"rawData.length= %d",(int)rawData.length);
            //  NSLog(@"data.length= %d",(int)tagTempData.length);
            [self parseSingleLabel:tagTempData];
            self.singleLableStr=[[NSMutableString alloc]init];
            self.isSingleSaveLable = NO;
        }
    }
    
    if (self.readStr.length>0) {
        //读标签
        [self.readStr appendString:dataStr];
        if (dataStr.length<40) {
            NSString *aa=[NSString stringWithFormat:@"%@",self.readStr];
            NSString *valueStr=[aa substringWithRange:NSMakeRange(18, aa.length-18-6)];
            [self.managerDelegate receiveMessageWithtype:@"85" dataStr:valueStr];
            self.readStr=[[NSMutableString alloc]init];
        }
    }
    
    if (self.rcodeStr.length>0) {
        NSLog(@"扫描二维码=%@",dataStr);
        
        [self.rcodeStr appendString:dataStr];
        NSData *rawData=[AppHelper hexToNSData:self.rcodeStr];
        NSData *parsedData = [self parseDataWithOriginalStr:rawData cmd:0xE5];
        
        if (parsedData && parsedData.length > 0) {
            //NSLog(@"扫描二维码111111111111111 len=%d",parsedData.length);
            //NSLog(@"扫描二维码=%@",[AppHelper dataToHex:parsedData]);
            Byte *bytes = (Byte *)parsedData.bytes;
            if (bytes[0] == 0x02) {
                NSString *barcode = [[NSString alloc]initWithData:parsedData encoding:NSASCIIStringEncoding];
                NSLog(@"扫描二维码222=%@",barcode);
                self.isCodeLab=NO;
                self.rcodeStr=[[NSMutableString alloc]init];
                [self.managerDelegate receiveMessageWithtype:@"e55" dataStr:barcode];
            }
        }
    }
    
    if (self.isgetLab==NO) {
        //不是获取标签的
        if ([typeStr isEqualToString:@"01"]) {
            //获取硬件版本号
            if (self.isGetVerson) {
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 6)];
                [self.managerDelegate receiveMessageWithtype:@"01" dataStr:strr];
                self.isGetVerson = NO;
            }
            
        } else if ([typeStr isEqualToString:@"03"]) {
            if (self.isGetVerson) {
                //获取固件版本号
                NSString *str1=[dataStr substringWithRange:NSMakeRange(10, 2)];
                NSString *str2=[dataStr substringWithRange:NSMakeRange(12, 2)];
                NSString *str3=[dataStr substringWithRange:NSMakeRange(14, 2)];
                NSString *strr=[NSString stringWithFormat:@"V%ld.%ld%ld",(long)str1.integerValue,(long)str2.integerValue,(long)str3.integerValue];
                [self.managerDelegate receiveMessageWithtype:@"03" dataStr:strr];
                self.isGetVerson = NO;
            }
            
        } else if ([typeStr isEqualToString:@"c9"]) {
            //获取升级固件版本号
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 6)];
            [self.managerDelegate receiveMessageWithtype:@"c9" dataStr:strr];
        } else if ([typeStr isEqualToString:@"05"]) {
            //获取设备ID
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 8)];
            NSLog(@"strr==%@",strr);
        } else if ([typeStr isEqualToString:@"11"]) {
            if (self.isSetEmissionPower) {
                //设置发射功率
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    [self.managerDelegate receiveMessageWithtype:@"11" dataStr:@"Set power successfully"];
                }
                else
                {
                    [self.managerDelegate receiveMessageWithtype:@"11" dataStr:@"Power setting fails"];
                }
                self.isSetEmissionPower = NO;
            }
            
        } else if ([typeStr isEqualToString:@"13"]) {
            if (self.isGetEmissionPower) {
                //获取当前发射功率
                NSInteger a=[BluetoothUtil getzhengshuWith:[dataStr substringWithRange:NSMakeRange(14, 1)]];
                NSInteger b=[BluetoothUtil getzhengshuWith:[dataStr substringWithRange:NSMakeRange(15, 1)]];
                NSInteger c=[BluetoothUtil getzhengshuWith:[dataStr substringWithRange:NSMakeRange(16, 1)]];
                NSInteger d=[BluetoothUtil getzhengshuWith:[dataStr substringWithRange:NSMakeRange(17, 1)]];
                NSInteger count=(a*16*16*16+b*16*16+c*16+d)/100;
                [self.managerDelegate receiveMessageWithtype:@"13" dataStr:[NSString stringWithFormat:@"%ld",count]];
                self.isGetEmissionPower = YES;
            }
            
            
        } else if ([typeStr isEqualToString:@"15"]) {
            //跳频设置
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                NSLog(@"跳频设置成功");
                [self.managerDelegate receiveMessageWithtype:@"15" dataStr:@"Set the frequency point successfully"];
            }
            else
            {
                NSLog(@"跳频设置失败");
                [self.managerDelegate receiveMessageWithtype:@"15" dataStr:@"Failed to set frequency point"];
            }
        } else if ([typeStr isEqualToString:@"2d"]) {
            if (self.isRegion) {
                // 区域设置
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    NSLog(@"区域设置成功");
                    
                    [self.managerDelegate receiveMessageWithtype:@"2d" dataStr:@"Set frequency successfully"];
                }
                else
                {
                    [self.managerDelegate receiveMessageWithtype:@"2d" dataStr:@"Failed to set frequency"];
                }
                self.isRegion = NO;
            }
            
        } else if ([typeStr isEqualToString:@"2f"]) {
            //获取区域设置
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                NSLog(@"区域设置成功");
                NSString *valueStr=[dataStr substringWithRange:NSMakeRange(12, 2)];
                NSString *messageStr;
                if ([valueStr isEqualToString:@"01"]) {
                    messageStr=@"0";
                }
                else if ([valueStr isEqualToString:@"02"])
                {
                    messageStr=@"1";
                }
                else if ([valueStr isEqualToString:@"04"])
                {
                    messageStr=@"2";
                }
                else if ([valueStr isEqualToString:@"08"])
                {
                    messageStr=@"3";
                }
                else if ([valueStr isEqualToString:@"16"])
                {
                    messageStr=@"4";
                }
                else if ([valueStr isEqualToString:@"32"])
                {
                    messageStr=@"5";
                }
                [self.managerDelegate receiveMessageWithtype:@"2f" dataStr:messageStr];
            }
            else
            {
                [self.managerDelegate receiveMessageWithtype:@"2f" dataStr:@"读取频率失败"];
            }
            
        } else if ([typeStr isEqualToString:@"8d"]) {
            //停止连续盘存标签
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                NSLog(@"停止连续盘存标签成功");
                self.isgetLab=NO;
                _tagStr=[[NSMutableString alloc]init];
            }
        } else if ([typeStr isEqualToString:@"85"]) {
            //读标签
            if (dataStr.length<40) {
                if (dataStr.length > 24) {
                    NSString *strr=[dataStr substringWithRange:NSMakeRange(18, dataStr.length-18-6)];
                    [self.managerDelegate receiveMessageWithtype:@"85" dataStr:strr];
                }
            }
            else
            {
                if (dataStr.length==40) {
                    NSString *aa=[dataStr substringWithRange:NSMakeRange(dataStr.length-4, 4)];
                    if ([aa isEqualToString:@"0d0a"]) {
                        NSString *strr=[dataStr substringWithRange:NSMakeRange(18, dataStr.length-18-6)];
                        [self.managerDelegate receiveMessageWithtype:@"85" dataStr:strr];
                    }
                    else
                    {
                        self.readStr=[[NSMutableString alloc]init];
                        [self.readStr appendString:dataStr];
                    }
                }
            }
            
        } else if ([typeStr isEqualToString:@"87"]) {
            //写标签
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                [self.managerDelegate receiveMessageWithtype:@"87" dataStr:@"Successful tag writing"];
            }
            else
            {
                [self.managerDelegate receiveMessageWithtype:@"87" dataStr:@"Failed to write tag"];
            }
        } else if ([typeStr isEqualToString:@"89"]) {
            //lock标签
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                [self.managerDelegate receiveMessageWithtype:@"89" dataStr:@"Lock label successful"];
            }
            else
            {
                [self.managerDelegate receiveMessageWithtype:@"89" dataStr:@"Lock label failed"];
            }
        } else if ([typeStr isEqualToString:@"8b"]) {
            //销毁
            NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
            if ([strr isEqualToString:@"01"]) {
                [self.managerDelegate receiveMessageWithtype:@"8b" dataStr:@"Destruction of success"];
            }
            else
            {
                [self.managerDelegate receiveMessageWithtype:@"8b" dataStr:@"Destruction of failure"];
            }
        } else if ([typeStr isEqualToString:@"81"]) {
            if (self.isSingleSaveLable) {
                //单次盘存标签
                self.singleLableStr=[[NSMutableString alloc]init];
                [self.singleLableStr appendString:dataStr];
            }
        } else if ([typeStr isEqualToString:@"71"]) {
            if (self.isSetTag) {
                //设置标签读取格式
                self.isSetTag = NO;
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    [self.managerDelegate receiveMessageWithtype:@"71" dataStr:@"Successful setup"];
                }
            }
        } else if ([typeStr isEqualToString:@"73"]) {
            if (self.isGetTag) {
                //获取标签读取格式
                self.isGetTag = NO;
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    NSString *epcstr=[dataStr substringWithRange:NSMakeRange(13, 1)];
                    NSString *addreStr=[BluetoothUtil becomeNumberWith:[dataStr substringWithRange:NSMakeRange(14, 2)]];
                    NSString *addreLenStr=[BluetoothUtil becomeNumberWith:[dataStr substringWithRange:NSMakeRange(16, 2)]];
                    NSString *allStr=[NSString stringWithFormat:@"%@ %@ %@",epcstr,addreStr,addreLenStr];
                    [self.managerDelegate receiveMessageWithtype:@"73" dataStr:allStr];
                }
            }
        } else if ([typeStr isEqualToString:@"e5"]) {
            //开启蜂鸣器
            if (self.isOpenBuzzer) {
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    [self.managerDelegate receiveMessageWithtype:@"e50" dataStr:@"Buzzer turned on successfully"];
                }
                self.isOpenBuzzer = NO;
            }
            
            if (self.isCloseBuzzer) {
                NSString *strr=[dataStr substringWithRange:NSMakeRange(10, 2)];
                if ([strr isEqualToString:@"01"]) {
                    [self.managerDelegate receiveMessageWithtype:@"e51" dataStr:@"Buzzer closed successfully"];
                }
                self.isCloseBuzzer = NO;
            }
            
            
            if (self.isGetBattery) {
                //获取电池电量
                NSString *battyStr=[dataStr substringWithRange:NSMakeRange(12, 2)];
                NSInteger n = strtoul([battyStr UTF8String], 0, 16);//16进制数据转10进制的NSInteger
                //NSLog(@"battyStr===%@",battyStr);
                NSString *batStr=[NSString stringWithFormat:@"%ld",n];
                [self.managerDelegate receiveMessageWithtype:@"e5" dataStr:batStr];
                self.isGetBattery = NO;
                return;
            }
            
            if (self.isCodeLab) {
                NSLog(@"扫描二维码=%@",dataStr);
                NSData *rawData=[AppHelper hexToNSData:dataStr];
                NSData *parsedData = [self parseDataWithOriginalStr:rawData cmd:0xE5];
                
                if (parsedData && parsedData.length > 0) {
                    //NSLog(@"扫描二维码111111111111111 len=%d",parsedData.length);
                    //NSLog(@"扫描二维码=%@",[AppHelper dataToHex:parsedData]);
                    Byte *bytes = (Byte *)parsedData.bytes;
                    if (bytes[0] == 0x02) {
                        NSString *barcode = [[NSString alloc]initWithData:parsedData encoding:NSASCIIStringEncoding];
                        NSLog(@"扫描二维码222=%@",barcode);
                        self.isCodeLab=NO;
                        self.rcodeStr=[[NSMutableString alloc]init];
                        [self.managerDelegate receiveMessageWithtype:@"e55" dataStr:barcode];
                    }
                }else {
                    self.rcodeStr=[[NSMutableString alloc]init];
                    [self.rcodeStr appendString:dataStr];
                }
            }
        } else if ([typeStr isEqualToString:@"35"]) {//获取设备温度
            if (self.isTemperature) {
                NSString *battyStr=[dataStr substringWithRange:NSMakeRange(12, 4)];
                NSInteger n = strtoul([battyStr UTF8String], 0, 16);//16进制数据转10进制的NSInteger
                NSString *temStr = [NSString stringWithFormat:@"%ld",n/100];
                [self.managerDelegate receiveMessageWithtype:@"35" dataStr:temStr];
                self.isTemperature = NO;
            }
            
        }  else if ([typeStr isEqualToString:@"21"]) {
            //  setGen2
            [self parseSetGen2DataWithData:[NSData dataWithBytes:characteristic.value.bytes length:characteristic.value.length]];
        } else if ([typeStr isEqualToString:@"23"]) {
            //  getGen2
            [self parseGetGen2DataWithData:[NSData dataWithBytes:characteristic.value.bytes length:characteristic.value.length]];
        } else if ([typeStr.uppercaseString isEqualToString:@"6F"]) {
            //  setFilter
            [self parseFilterDataWithData:[NSData dataWithBytes:characteristic.value.bytes length:characteristic.value.length]];
        } else if ([typeStr isEqualToString:@"53"]) {
            //  setRFLink
            [self parseSetRFLinkWithData:[NSData dataWithBytes:characteristic.value.bytes length:characteristic.value.length]];
        } else if ([typeStr isEqualToString:@"55"]) {
            //  getRFLink
            [self parseGetRFLinkWithData:[NSData dataWithBytes:characteristic.value.bytes length:characteristic.value.length]];
        }
    } else {
        
        //拿到标签列表
        if (dataStr) {
            self.tagStr = (NSMutableString *)[self.tagStr stringByAppendingString:dataStr];
            if (!self.tagData) {
                self.tagData = [[NSMutableData alloc]initWithData:characteristic.value];
                //todo  NSLog(@" 新数据 self.tagData = %@ ", characteristic.value);
            } else {
                //todo NSLog(@" 旧数据 self.tagData = %@ ", self.tagData);
                //todo NSLog(@" 新数据 self.tagData = %@ ", characteristic.value);
                [self.tagData appendData:characteristic.value];
            }
        }
        
        //       数据长度（2字节）  cmd      pc(2字节)              epc                     rssi(2字节)   ant((2字节))     crc(1字节)
        //c8 8c    00 19          e1      34 00     39 31 31 31 32 32 32 32 33 33 33 34     fe b7      01               eb          0d 0a
        if (self.tagData.length > 0) {
            Byte *tagDataBytes = (Byte *)self.tagData.bytes;
            Byte tempBytes[1024];
            int index=0;
            for(int s=0;s<self.tagData.length;s++){
                tempBytes[index] = tagDataBytes[s];
                index++;
                if (!self.isHeader) {
                    if((tempBytes[0]&0xFF) != 0xC8){
                        index=0;
                    } else if(index==2 && (tempBytes[1]&0xFF) != 0x8C){
                        tempBytes[0]=tempBytes[1];
                        index=1;
                    }else{
                        if(index==5){
                            if ((tempBytes[4]&0xFF) == 0xE1) {
                                self.isHeader = YES;
                            } else {
                                //命令字不对，删除h第一个字节数据
                                s=s-3;
                                index=0;
                            }
                        }
                    }
                } else if ((tempBytes[index - 2] & 0xFF) == 0x0D && (tempBytes[index - 1] & 0xff) == 0x0A) {
                    NSData * tempNSData=[NSData dataWithBytes:tempBytes length:index];
                    //  开始解析数据
                    ////todo  NSLog(@"获取到的正常数据为：%@",[AppHelper dataToHex:tempNSData]);
                    NSData *tagTempData = [self parseDataWithOriginalStr:tempNSData cmd:0xE1];
                    if(tagTempData.length==0){
                        NSLog(@"解析失败...");
                        //解析失败继续拼接数据帧，先不清空数据
                    }else{
                        NSLog(@"解析成功...");
                        if (self.isSupportRssi) {
                            [self parseReadTagDataEPC_TID_USERWithData:tagTempData];
                        } else {
                            [self parseReadTag_EPCWithDataStr:tagTempData];
                        }
                        //  解析完成，清空头，再开始下一个数据的读取
                        self.isHeader = NO;
                        index=0;
                    }
                    
                } else if (index>250){
                    //累计500个字节还没有正确数据，直接清空缓存buff
                    index=0;
                    self.isHeader = NO;
                }
            }
            
            if (index<=0) {
                self.tagData = [NSMutableData data];
            }else{
                //保存e未解析的h数据，和目前数据进行拼接
                self.tagData = [NSMutableData data];
                NSData * tempD=[NSData dataWithBytes:tempBytes length:index];
                [self.tagData appendData:tempD];
                NSLog(@" 保存旧数据 self.tagData = %@ ", self.tagData);
            }
            
        }
        
    }
    
}

- (void)parseReadTag_EPCWithDataStr:(NSData *)data {
    //NSLog(@"--===去除头尾前的数据帧： data = %@",dataStr);
    //NSData *data = [self parseDataWithOriginalStr:dataStr cmd:0xE1];
    //NSLog(@"--===去除头尾后的数据帧： data = %@",data);
    NSMutableArray *arr = [self parseReadTag_EPCWithData:data];
    if (arr && arr.count) {
        NSLog(@"epcDataArr = %@",arr);
        [self.managerDelegate receiveDataWithBLEDataSource:arr allCount:self.allCount countArr:self.countArr dataSource1:self.dataSource1 countArr1:self.countArr1 dataSource2:self.dataSource2 countArr2:self.countArr2];
    }
}

- (NSMutableArray *)parseReadTag_EPCWithData:(NSData *)data {
    if (data.length < 5) {
        return [NSMutableArray array];
    }
    
    //  //[0]-[1]:表示剩余标签个数  [2]:表示标签个数  [3]:标签长度  [4]:标签数据开始
    Byte *dataBytes = (Byte *)data.bytes;
    int count = dataBytes[2]; // // 标签个数
    int epcLengthIndex = 3;  // 数据长度索引
    int beginIndex = 4;  //  标签数据开始索引
    for (NSInteger i = 0; i < count; i ++) {
        int tagLen = dataBytes[epcLengthIndex] & 0xff;  //标签长度
        epcLengthIndex = beginIndex+tagLen; //标签数据结束索引
        if (beginIndex+tagLen > data.length) {
            //会发生溢出，所以返回
            break;
        }
        //获取EPC
        Byte epcDataByte[tagLen];
        [data getBytes:epcDataByte range:NSMakeRange(beginIndex, tagLen)];
        NSData *epcData = [NSData dataWithBytes:epcDataByte length:tagLen];
        NSString *epcHex=[AppHelper dataToHex:epcData];
        BOOL isHave = NO;
        for (NSInteger j = 0 ; j < self.dataSource.count; j ++) {
            NSString *oldEpcData = self.dataSource[j];
            if ([oldEpcData isEqualToString:epcHex]) {
                isHave = YES;
                self.allCount ++;
                NSString *countStr=self.countArr[j];
                [self.countArr replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                break;
            }
        }
        if (!self.dataSource || self.dataSource.count == 0 || !isHave) {
            [self.dataSource addObject:epcHex];
            [self.countArr addObject:@"1"];
        }
        beginIndex = epcLengthIndex + 1;
    }
    return self.dataSource;
}

- (void)parseReadTagDataEPC_TID_USERWithData:(NSData *)tempData {
    //NSLog(@"originalEPCTIDUSERData = %@",data);
    //NSData * tempData = [self parseDataWithOriginalStr:data cmd:0xE1];//
    //NSLog(@"去除头尾后的EPCTIDUSERDataData = %@",tempData);
    if (tempData.length < 5) {
        //标签数据长度小于5则直接返回，此为无效数据。
        return;
    }
    //[0]-[1]:表示剩余标签个数  [2]:表示标签个数  [3]:标签长度  [4]:标签数据开始
    
    Byte *dataBytes = (Byte *)[tempData bytes];
    
    int count = dataBytes[2] & 0xFF;// 标签个数
    int epc_lenIndex = 3;// epc长度索引
    int epc_startIndex = 4; // 截取epc数据的起始索引
    int epc_endIndex = 0;// 截取epc数据的结束索引
    for (NSInteger k = 0; k < count; k ++) {
        epc_startIndex = epc_lenIndex + 1;
        epc_endIndex = epc_startIndex + (dataBytes[epc_lenIndex] & 0xFF);// epc的起始索引加长度得到结束索引
        if (epc_endIndex > tempData.length) {
            break;
        } else {
            Byte epcBuff[epc_endIndex - epc_startIndex];
            [tempData getBytes:epcBuff range:NSMakeRange(epc_startIndex, epc_endIndex - epc_startIndex)];
            NSData *epcDataBuff = [NSData dataWithBytes:epcBuff length:epc_endIndex - epc_startIndex];
            [self parserUhfTagBuff_EPC_TID_USER:epcDataBuff];
        }
        epc_lenIndex = epc_endIndex;
        if (epc_endIndex >= tempData.length) {
            break;
        }
    }
}

- (void)parserUhfTagBuff_EPC_TID_USER:(NSData *)tagsBuff {
    if (tagsBuff.length < 3) {
        return;
    }
    
    NSString * allData= [AppHelper dataToHex:tagsBuff];//整个数据
    NSInteger length = tagsBuff.length;
    NSString * epcLenHex=[allData substringWithRange:NSMakeRange(0, 2)];
    int epclen = (((int)[AppHelper getHexToDecimal:(epcLenHex)])>>3) *2;
    int uiiLen = epclen + 2;
    int tidLen=12;
    int rssiLen=2;
    int antLen=1;
    // Byte pcBuff[2];
    // [tagsBuff getBytes:pcBuff range:NSMakeRange(0, 2)];
    // NSData *pcData = [NSData dataWithBytes:pcBuff length:2];
    // int epclen = ((pcBuff[0] & 0xFF)>> 3)*2;//(pc >> 3) * 2;
    //34 00     39 31 31 31 32 32 32 32 33 33 33 34     fe b7      01
    self.tagTypeStr = @"0";
    if (length >= uiiLen + 2 && epclen>0) {
        Boolean isEPCAndTid = (length == (uiiLen + rssiLen + tidLen) ||  length ==  (uiiLen + rssiLen + tidLen + antLen) ? YES:NO);//只有epc 和 tid
        Boolean isEPCAndTidUser = (length > (uiiLen + rssiLen + tidLen + antLen) ? YES:NO);//epc + tid + user
        BOOL isHave = NO;
        
        
        if(isEPCAndTidUser == YES){
            //*************** EPC  and tid  user **************
            self.tagTypeStr = @"2";
            NSInteger userAndRssiLen= allData.length-(uiiLen*2+tidLen*2);
            userAndRssiLen= (userAndRssiLen%2!=0)? userAndRssiLen-1: userAndRssiLen;//有可能数据包含一个字节的天线号，所以这里做特殊处理
            NSString * newUserAndRssiData= [allData substringWithRange:NSMakeRange(uiiLen*2+tidLen*2,userAndRssiLen)];
            NSString * newUserData= [newUserAndRssiData substringWithRange:NSMakeRange(0,newUserAndRssiData.length - rssiLen*2)];
            isHave = NO;
            for (NSInteger j = 0 ; j < self.dataSource2.count; j ++) {
                NSString *oldUserAndRssiData = self.dataSource2[j];
                NSString *oldUser= [oldUserAndRssiData substringWithRange:NSMakeRange(0,oldUserAndRssiData.length-rssiLen*2)];
                
                if ([newUserData isEqualToString:oldUser]) {
                    [self.dataSource2 replaceObjectAtIndex:j withObject:newUserAndRssiData];
                    isHave = YES;
                    self.allCount ++;
                    NSString *countStr=self.countArr2[j];
                    [self.countArr2 replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                    break;
                }
            }
            if (!self.dataSource2 || self.dataSource2.count == 0 || !isHave) {
                [self.dataSource2 addObject:newUserAndRssiData];
                [self.countArr2 addObject:@"1"];
                NSString * EpcData= [allData substringWithRange:NSMakeRange(4, epclen*2)];
                [self.countArr addObject:@"1"];
                [self.dataSource addObject:EpcData];
                NSString * TidData= [allData substringWithRange:NSMakeRange(uiiLen*2,tidLen*2 )];
                [self.countArr1 addObject:@"1"];
                [self.dataSource1 addObject:TidData];
            }
        }else if(isEPCAndTid == YES){
            //*************** EPC  and tid   **************
            self.tagTypeStr = @"1";
            isHave = NO;
            NSString * newTidData= [allData substringWithRange:NSMakeRange(uiiLen*2,tidLen*2 )];
            NSString * tidAndRssiData= [allData substringWithRange:NSMakeRange(uiiLen*2, tidLen*2+rssiLen*2)];
            for (NSInteger jTid = 0 ; jTid < self.dataSource1.count; jTid ++) {
                NSString *oldTid = self.dataSource1[jTid];
                oldTid= [oldTid substringWithRange:NSMakeRange(0,oldTid.length-rssiLen*2)];
                if ([oldTid isEqualToString:newTidData]) {
                    [self.dataSource1 replaceObjectAtIndex:jTid withObject:tidAndRssiData];
                    isHave = YES;
                    self.allCount ++;
                    NSString *countStr=self.countArr1[jTid];
                    [self.countArr1 replaceObjectAtIndex:jTid withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                    break;
                }
            }
            if (!self.dataSource1 || self.dataSource1.count == 0 || !isHave) {
                [self.dataSource1 addObject:tidAndRssiData];
                [self.countArr1 addObject:@"1"];
                NSString * EpcData= [allData substringWithRange:NSMakeRange(4, epclen*2)];
                [self.countArr addObject:@"1"];
                [self.dataSource addObject:EpcData];
            }
        }else{
            //*************** EPC    **************
            NSString * newEpcData= [allData substringWithRange:NSMakeRange(4, epclen*2)];
            NSString * epcAndRssiData= [allData substringWithRange:NSMakeRange(4, epclen*2+rssiLen*2)];
            if (_isStreamRealTimeTags == YES) {
                [self.managerDelegate didScanRF:epcAndRssiData];
            } else {
                for (NSInteger j = 0 ; j < self.dataSource.count; j ++) {
                    NSString * oldEPC = self.dataSource[j];
                    oldEPC= [oldEPC substringWithRange:NSMakeRange(0,oldEPC.length-rssiLen*2 )];
                    if ([oldEPC isEqualToString:newEpcData]) {
                        isHave = YES;
                        self.allCount ++;
                        NSString *countStr=self.countArr[j];
                        [self.countArr replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        break;
                    }
                }
                if (!self.dataSource || self.dataSource.count == 0 || !isHave) {
                    [self.dataSource addObject:epcAndRssiData];
                    [self.countArr addObject:@"1"];
                }
            }
        }
        
        if (_isStreamRealTimeTags == NO) {
            [self.managerDelegate receiveDataWithBLEDataSource:self.dataSource allCount:self.allCount countArr:self.countArr dataSource1:self.dataSource1 countArr1:self.countArr1 dataSource2:self.dataSource2 countArr2:self.countArr2];
        }
    }
}

- (NSData *)parseDataWithOriginalStr:(NSData *)originalStr cmd:(int)cmd{
    const int R_START = 0;//开始
    const int R_5A = 1;
    const int R_LEN_H = 2;//数据长度高位
    const int R_LEN_L = 3;//数据长度低位
    const int R_CMD = 4;//命令字节
    const int R_DATA = 5;//数据
    const int R_XOR = 6;//校验位
    const int R_END_0D = 7;//结束贞
    const int R_END_0A = 8;//结束贞
    int Head1 = 0xC8;//A5;
    int Head2 = 0x8C;//@"8C";
    int Tail1 = 0x0D;//@"0D";
    //NSString *Tail2 = @"0A";//0x0A;
    int Tail2 = 0x0A;
    
    int rxsta = R_START;
    int rlen = 0;//数据长度
    int ridx = 0; //数据
    int rxor = 0; //校验字节
    int rcmd = 0; //命令字节
    int rflag = 0;//是否正确的完成了数据解析
    //NSString *dataStr = [NSString string];
    Byte rbuf[2048];
    Byte *originalByte = (Byte *)originalStr.bytes;
    for (int i = 0; i < originalStr.length; i ++) {
        
        int tmpdata = originalByte[i] & 0xff;
        switch (rxsta) {
            case R_START:
                //从头开始解析C8， 下一步开始解析5
                if (tmpdata == Head1) {
                    rxsta = R_5A;
                } else {
                    rxsta = R_START;
                }
                rxor = 0;
                ridx = 0;
                rlen = 0;
                rflag = 0;
                break;
            case R_5A:
                //解析5A，下一步解析数据长度
                if (tmpdata == Head2) {
                    rxsta = R_LEN_H;
                } else {
                    rxsta = R_START;
                }
                break;
            case R_LEN_H:
                //解析数据长度高字节，下一步解析数据长度低字节
                rxor = rxor ^ tmpdata;
                rlen = tmpdata * 256;
                rxsta = R_LEN_L;
                break;
            case R_LEN_L:
                //解析数据长度低字节，下一步解析命令
                rxor = rxor ^ tmpdata;
                rlen = rlen + tmpdata;
                if ((rlen < 8) || (rlen > 2048)) {
                    rxsta = R_START;
                } else {
                    rlen = rlen - 8;
                    rxsta = R_CMD;
                }
                break;
            case R_CMD:
                //解析数据长度低字节，下一步解析标签数据
                rxor = rxor ^ tmpdata;
                rcmd = tmpdata;
                if (rlen > 0) {
                    rxsta = R_DATA;
                } else {
                    rxsta = R_XOR;
                }
                break;
            case R_DATA:
                //解析标签数据，下一步解析校验码
                if (rlen == 0) {
                    rxsta = R_START;
                    break;
                }
                if (ridx < rlen) {
                    rxor = rxor ^ tmpdata;
                    //开始存标签数据
                    rbuf[ridx++] = (Byte)tmpdata;
                    if (ridx >= rlen) {
                        rxsta = R_XOR;
                    }
                }
                break;
            case R_XOR: {
                //解析校验码，下一步解析尾部0
                if (rxor == tmpdata) {
                    rxsta = R_END_0D;
                } else {
                    rxsta = R_START;
                }
            }
                break;
            case R_END_0D:
                //解析尾部0D，下一步解析尾部0A
                if (tmpdata == Tail1) {
                    rxsta = R_END_0A;
                } else {
                    rxsta = R_START;
                }
                break;
            case R_END_0A:
                //解析尾部0A， ,解析成功则解析完成
                rxsta = R_START;
                if (tmpdata == Tail2) {
                    rflag = 1;
                }
                break;
            default:
                rxor = 0;
                ridx = 0;
                rlen = 0;
                rflag = 0;
                break;
        }
        if (rflag == 1) {
            break;
        }
    }
    
    if (rflag == 1) {
        if (rcmd != cmd) {
            //命令不对
            return [NSData data];
        }
        //解析成功，只返回标签数据（去掉头尾）
        return [NSData dataWithBytes:rbuf length:ridx];
    } else {
        //解析失败
        return [NSData data];
    }
}


#pragma mark 写数据后回调
- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic  error:(NSError *)error {
    
    if (error) {
        
        NSLog(@"Error writing characteristic value: %@",
              
              [error localizedDescription]);
        
        return;
        
    }
    
    NSLog(@"写入%@成功",characteristic);
    
}
-(void)notifyCharacteristic:(CBPeripheral *)peripheral
             characteristic:(CBCharacteristic *)characteristic{
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
    
}
-(void)cancelNotifyCharacteristic:(CBPeripheral *)peripheral
                   characteristic:(CBCharacteristic *)characteristic{
    
    [peripheral setNotifyValue:NO forCharacteristic:characteristic];
}


- (NSString *)getVisiableIDUUID:(NSString *)peripheralIDUUID
{
    if (!peripheralIDUUID.length) {
        return @"";
    }
    peripheralIDUUID = [peripheralIDUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
    peripheralIDUUID = [peripheralIDUUID stringByReplacingOccurrencesOfString:@"<" withString:@""];
    peripheralIDUUID = [peripheralIDUUID stringByReplacingOccurrencesOfString:@">" withString:@""];
    peripheralIDUUID = [peripheralIDUUID stringByReplacingOccurrencesOfString:@" " withString:@""];
    peripheralIDUUID = [peripheralIDUUID substringFromIndex:peripheralIDUUID.length - 12];
    peripheralIDUUID = [peripheralIDUUID uppercaseString];
    NSData *bytes = [peripheralIDUUID dataUsingEncoding:NSUTF8StringEncoding];
    Byte * myByte = (Byte *)[bytes bytes];
    
    
    NSMutableString *result = [[NSMutableString alloc] initWithString:@""];
    for (int i = 5; i >= 0; i--) {
        [result appendString:[NSString stringWithFormat:@"%@",[[NSString alloc] initWithBytes:&myByte[i*2] length:2 encoding:NSUTF8StringEncoding] ]];
    }
    
    for (int i = 1; i < 6; i++) {
        [result insertString:@":" atIndex:3*i-1 ];
    }
    
    return result;
}


#pragma mark - Setter and Getter

- (CBCentralManager *)centralManager
{
    if (!_centralManager ) {
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return _centralManager;
}

- (NSMutableArray *)peripheralArray
{
    if (!_peripheralArray) {
        _peripheralArray = [[NSMutableArray alloc] init];
    }
    return _peripheralArray;
}

- (CBCharacteristic *)myCharacteristic
{
    if (_myCharacteristic == nil) {
        _myCharacteristic = [CBCharacteristic new];
    }
    return _myCharacteristic;
}

- (NSString *)centralManagerStateDescribe:(CBCentralManagerState )state
{
    NSString *descStr = @"";
    switch (state) {
        case CBCentralManagerStateUnknown:
            
            break;
        case CBCentralManagerStatePoweredOff:
            descStr = @"请打开蓝牙";
            break;
        default:
            break;
    }
    return descStr;
}

- (void)setGen2WithTarget:(char)Target action:(char)Action t:(char)T qq:(char)Q_Q startQ:(char)StartQ minQ:(char)MinQ maxQ:(char)MaxQ dd:(char)D_D cc:(char)C_C pp:(char)P_P sel:(char)Sel session:(char)Session gg:(char)G_G lf:(char)LF {
    self.isSetGen2Data = YES;
    NSData *byteData = [self setGen2DataWithTarget:Target action:Action t:T qq:Q_Q startQ:StartQ minQ:MinQ maxQ:MaxQ dd:D_D cc:C_C pp:P_P sel:Sel session:Session gg:G_G lf:LF];
    [self sendDataToBle:byteData];
}

- (NSData *)setGen2DataWithTarget:(char)Target action:(char)Action t:(char)T qq:(char)Q_Q startQ:(char)StartQ minQ:(char)MinQ maxQ:(char)MaxQ dd:(char)D_D cc:(char)C_C pp:(char)P_P sel:(char)Sel session:(char)Session gg:(char)G_G lf:(char)LF {
    Byte sbuf[4];
    sbuf[0] = (((Target & 0x07) << 5) | ((Action & 0x07) << 2) | ((T & 0x01) << 1) | ((Q_Q & 0x01) << 0));
    sbuf[1] = (((StartQ & 0x0f) << 4) | ((MinQ & 0x0f) << 0));
    sbuf[2] = (((MaxQ & 0x0f) << 4) | ((D_D & 0x01) << 3) | ((C_C & 0x03) << 1) | ((P_P & 0x01) << 0));
    sbuf[3] = (((Sel & 0x03) << 6) | ((Session & 0x03) << 4) | ((G_G & 0x01) << 3) | ((LF & 0x07) << 0));
    //return sbuf;
    NSData *sbufData = [NSData dataWithBytes:sbuf length:4];
    return [self makeSendDataWithCmd:0x20 dataBuf:sbufData];
}

- (NSData *)makeSendDataWithCmd:(int)cmd dataBuf:(NSData*)databuf {
    Byte outSendbuf[databuf.length + 8];
    int idx = 0;
    int crcValue = 0;
    outSendbuf[idx++] =  0xC8;
    outSendbuf[idx++] =  0x8C;
    outSendbuf[idx++] =  ((8 + databuf.length) / 256);
    outSendbuf[idx++] =  ((8 + databuf.length) % 256);
    outSendbuf[idx++] =  cmd;
    for (int k = 0; k < databuf.length; k++) {
        Byte *dataBufBytes = (Byte *)[databuf bytes];
        outSendbuf[idx++] = dataBufBytes[k];
    }
    for (int i = 2; i < idx; i++) {
        crcValue ^= outSendbuf[i];
    }
    outSendbuf[idx++] = crcValue;
    outSendbuf[idx++] = 0x0D;
    outSendbuf[idx++] = 0x0A;
    return [NSData dataWithBytes:outSendbuf length:databuf.length + 8];
}

- (void)getGen2SendData {
    self.isGetGen2Data = YES;
    Byte sbuf[0];
    NSData *bytesData = [self makeSendDataWithCmd:0x22 dataBuf:[NSData dataWithBytes:sbuf length:0]];
    [self sendDataToBle:bytesData];
}

- (void)parseGetGen2DataWithData:(NSData *)data {
    NSData *parsedData = [self parseDataWithOriginalStr:data cmd:0x23];
    if (parsedData && parsedData.length >= 4) {
        Byte buff[14];
        Byte *rbuf = (Byte *)[parsedData bytes];
        buff[0] = ((rbuf[0] & 0xe0) >> 5);
        buff[1] = ((rbuf[0] & 0x1c) >> 2);
        buff[2] = ((rbuf[0] & 0x02) >> 1);
        buff[3] = ((rbuf[0] & 0x01) >> 0);
        buff[4] = ((rbuf[1] & 0xf0) >> 4);
        buff[5] = (rbuf[1] & 0x0f);
        buff[6] = ((rbuf[2] & 0xf0) >> 4);
        buff[7] = ((rbuf[2] & 0x08) >> 3);
        buff[8] = ((rbuf[2] & 0x06) >> 1);
        buff[9] = (rbuf[2] & 0x01);
        buff[10] = ((rbuf[3] & 0xc0) >> 6);
        buff[11] = ((rbuf[3] & 0x30) >> 4);
        buff[12] = ((rbuf[3] & 0x08) >> 3);
        buff[13] = (rbuf[3] & 0x07);
        parsedData = [NSData dataWithBytes:buff length:14];
    }
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(receiveGetGen2WithData:)]) {
        [self.managerDelegate receiveGetGen2WithData:parsedData];
    }
}

- (void)parseSetGen2DataWithData:(NSData *)data {
    BOOL parseResult = NO;
    NSData *parsedData = [self parseDataWithOriginalStr:data cmd:0x21];
    if (parsedData && parsedData.length > 0) {
        Byte *bytes = (Byte *)parsedData.bytes;
        if (bytes[0] == 0x01) {
            parseResult = YES;
        }
    }
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(receiveSetGen2WithResult:)]) {
        [self.managerDelegate receiveSetGen2WithResult:parseResult];
    }
}


//----------------------------------------设置Filter--------------------------------------------------------------------------------------
- (void)setFilterWithBank:(int)bank ptr:(int)ptr cnt:(int)cnt data:(NSString *)data {
    if (data && data.length > 0) {
        if (data.length % 2 != 0) {
            data = [data stringByAppendingString:@"0"];
        }
    } else {
        data = @"00";
    }
    
    //NSData *fDataStr = [data dataUsingEncoding:NSUTF8StringEncoding];
    NSData *fDataStr = [BluetoothUtil hexToBytes:data];
    Byte *fData = (Byte *)[fDataStr bytes];
    const char saveflag = 0;
    Byte sbuf[1024] = {0};
    int index = 0;
    int i = 0;
    sbuf[index++] = saveflag;
    sbuf[index++] = bank;
    sbuf[index++] = (Byte)(ptr / 256);
    sbuf[index++] = (Byte)(ptr % 256);
    sbuf[index++] = (Byte)(cnt / 256);
    sbuf[index++] = (Byte)(cnt % 256);
    for (i = 0; i < (cnt / 8); i++) {
        sbuf[index++] = fData[i];
    }
    if ((cnt % 8) > 0)
        sbuf[index++] = fData[i];
    //int len=index;
    //[fDataStr getBytes:sbuf length:index];
    NSData *sendData = [NSData dataWithBytes:sbuf length:index];
    //NSData *sendData = [NSData dataWithBytes:sbuf length:index];
    NSData *ssssdata = [self makeSendDataWithCmd:0x6E dataBuf:sendData];
    [self sendDataToBle:ssssdata];
}


- (void)parseFilterDataWithData:(NSData *)data {
    BOOL parseResult = NO;
    NSData *parseData = [self parseDataWithOriginalStr:data cmd:0x6F];
    if (parseData && parseData.length > 0) {
        Byte *bytes = (Byte *)parseData.bytes;
        if (bytes[0] == 0x01) {
            parseResult = YES;
        }
    }
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(receiveSetFilterWithResult:)]) {
        [self.managerDelegate receiveSetFilterWithResult:parseResult];
    }
}

- (void)setRFLinkWithMode:(int)mode {
    Byte saveFlag = 1;
    Byte sbuf[3] = {0};
    sbuf[0] = 0x00;
    sbuf[1] = saveFlag;
    sbuf[2] = (Byte)mode;
    NSData *rfLinkSetData = [NSData dataWithBytes:sbuf length:3];
    NSData *sendRFLinkData = [self makeSendDataWithCmd:0x52 dataBuf:rfLinkSetData];
    [self sendDataToBle:sendRFLinkData];
}

- (void)parseSetRFLinkWithData:(NSData *)data {
    BOOL parseResult = NO;
    NSData *parseData = [self parseDataWithOriginalStr:data cmd:0x53];
    if (parseData && parseData.length > 0) {
        Byte *parseBytes = (Byte *)[parseData bytes];
        if (parseBytes[0] == 0x01) {
            parseResult = YES;
        }
    }
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(receiveSetRFLinkWithResult:)]) {
        [self.managerDelegate receiveSetRFLinkWithResult:parseResult];
    }
}

- (void)getRFLinkSendData {
    Byte sbuf[2] = {0};
    sbuf[0] = 0x00;
    sbuf[1] = 0x00;
    NSData *sendData = [NSData dataWithBytes:sbuf length:2];
    NSData *sendToBleData = [self makeSendDataWithCmd:0x54 dataBuf:sendData];
    [self sendDataToBle:sendToBleData];
}

- (void)parseGetRFLinkWithData:(NSData *)data {
    int resultData = 0;
    NSData *parseData = [self parseDataWithOriginalStr:data cmd:0x55];
    if (parseData && parseData.length >= 3) {
        Byte *bytes = (Byte *)[parseData bytes];
        if (bytes[0] == 0x01) {
            resultData = bytes[2] & 0xff;
        }
    } else {
        resultData = -1;
    }
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(receiveGetRFLinkWithData:)]) {
        [self.managerDelegate receiveGetRFLinkWithData:resultData];
    }
}

- (void)dealloc
{
    [_connectTime invalidate];
    _connectTime = nil;
}

//清除缓存标签
- (void)clearCacheTag
{
    self.dataSource=[[NSMutableArray alloc]init];
    self.dataSource1 = [NSMutableArray array];
    self.dataSource2 = [NSMutableArray array];
    _allCount=0;
    self.countArr=[[NSMutableArray alloc]init];
    self.countArr1 = [NSMutableArray array];
    self.countArr2 = [NSMutableArray array];
}
//解析单次盘点
-(void) parseSingleLabel:(NSData *)tagTempData {
    
    if(tagTempData && tagTempData.length>=4){
        Byte *originalByte = (Byte *)tagTempData.bytes;
        NSString *hexData=[AppHelper dataToHex:tagTempData];
        int epcLen=((originalByte[0] & 0xff)>>3)*2;
        int pcLen=2;
        int tidLen=12;
        int rssiLen=2;
        int antLen=1;
        NSInteger userLen= tagTempData.length-pcLen-epcLen-tidLen-rssiLen-antLen;
        userLen= (userLen%2!=0)? userLen-1: userLen;//有可能数据包含一个字节的天线号，所以这里做特殊处理
        
        if(self.isSupportRssi==YES){
            if(tagTempData.length>pcLen+epcLen+rssiLen+antLen+tidLen){
                //************EPC+TID+USER *************************
                self.tagTypeStr = @"2";
                NSString *realEPCStr = [hexData substringWithRange:NSMakeRange(4, epcLen * 2)];
                NSString *TidStr = [hexData substringWithRange:NSMakeRange(4 + epcLen * 2, tidLen * 2)];
                NSString *userAndRSSIStr = [hexData substringWithRange:NSMakeRange(4 + epcLen * 2+ tidLen * 2,userLen*2+rssiLen*2)];
                NSString *newUserData= [userAndRSSIStr substringWithRange:NSMakeRange(0,userAndRSSIStr.length - rssiLen*2)];
                BOOL isHave = NO;
                for (NSInteger j = 0 ; j < self.dataSource2.count; j ++) {
                    NSString *oldUserAndRssiData = self.dataSource2[j];
                    NSString *oldUser= [oldUserAndRssiData substringWithRange:NSMakeRange(0,oldUserAndRssiData.length-rssiLen*2)];
                    if ([newUserData isEqualToString:oldUser]) {
                        [self.dataSource2 replaceObjectAtIndex:j withObject:userAndRSSIStr];
                        isHave = YES;
                        self.allCount ++;
                        NSString *countStr=self.countArr2[j];
                        [self.countArr2 replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        [self.countArr1 replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        [self.countArr replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        break;
                    }
                }
                if (!self.dataSource2 || self.dataSource2.count == 0 || !isHave) {
                    [self.dataSource2 addObject:userAndRSSIStr];
                    [self.countArr2 addObject:@"1"];
                    [self.dataSource addObject:realEPCStr];
                    [self.countArr addObject:@"1"];
                    [self.dataSource1 addObject:TidStr];
                    [self.countArr1 addObject:@"1"];
                }
            }else if(tagTempData.length>pcLen+epcLen+rssiLen+antLen){
                //************EPC+TID *************************
                BOOL isHave = NO;
                self.tagTypeStr = @"1";
                NSString *realEPCStr = [hexData substringWithRange:NSMakeRange(4, epcLen * 2)];
                NSString * newTidData= [hexData substringWithRange:NSMakeRange(4 + epcLen * 2,tidLen*2 )];
                NSString * tidAndRssiData= [hexData substringWithRange:NSMakeRange(4 + epcLen * 2, tidLen*2+rssiLen*2)];
                for (NSInteger jTid = 0 ; jTid < self.dataSource1.count; jTid ++) {
                    NSString *oldTid = self.dataSource1[jTid];
                    oldTid= [oldTid substringWithRange:NSMakeRange(0,oldTid.length-rssiLen*2)];
                    if ([oldTid isEqualToString:newTidData]) {
                        [self.dataSource1 replaceObjectAtIndex:jTid withObject:tidAndRssiData];
                        isHave = YES;
                        self.allCount ++;
                        NSString *countStr=self.countArr1[jTid];
                        [self.countArr1 replaceObjectAtIndex:jTid withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        [self.countArr replaceObjectAtIndex:jTid withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        break;
                    }
                }
                if (!self.dataSource1 || self.dataSource1.count == 0 || !isHave) {
                    [self.dataSource1 addObject:tidAndRssiData];
                    [self.countArr1 addObject:@"1"];
                    [self.dataSource addObject:realEPCStr];
                    [self.countArr addObject:@"1"];
                }
            }else{
                //************EPC *************************
                self.tagTypeStr = @"0";
                NSString *realEPCStr = [hexData substringWithRange:NSMakeRange(4, epcLen * 2)];
                NSString *realEPCAndRssi = [hexData substringWithRange:NSMakeRange(4, epcLen * 2+rssiLen*2)];
                BOOL isHave = NO;
                for (NSInteger j = 0 ; j < self.dataSource.count; j ++) {
                    NSString * oldEPC = self.dataSource[j];
                    oldEPC= [oldEPC substringWithRange:NSMakeRange(0,oldEPC.length-rssiLen*2 )];
                    
                    if ([oldEPC isEqualToString:realEPCStr]) {
                        [self.dataSource replaceObjectAtIndex:j withObject:realEPCAndRssi];
                        isHave = YES;
                        self.allCount ++;
                        NSString *countStr=self.countArr[j];
                        [self.countArr replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                        break;
                    }
                }
                if (!self.dataSource || self.dataSource.count == 0 || !isHave) {
                    [self.dataSource addObject:realEPCAndRssi];
                    [self.countArr addObject:@"1"];
                }
            }
        }else{
            //************EPC *************************
            self.tagTypeStr = @"0";
            NSString *realEPCStr = [hexData substringWithRange:NSMakeRange(4, epcLen * 2)];
            BOOL isHave = NO;
            for (NSInteger j = 0 ; j < self.dataSource.count; j ++) {
                NSString * oldEPC = self.dataSource[j];
                if ([oldEPC isEqualToString:realEPCStr]) {
                    isHave = YES;
                    self.allCount ++;
                    NSString *countStr=self.countArr[j];
                    [self.countArr replaceObjectAtIndex:j withObject:[NSString stringWithFormat:@"%ld",countStr.integerValue + 1]];
                    break;
                }
            }
            if (!self.dataSource || self.dataSource.count == 0 || !isHave) {
                [self.dataSource addObject:realEPCStr];
                [self.countArr addObject:@"1"];
            }
            
        }
        
        [self.managerDelegate receiveDataWithBLEDataSource:self.dataSource allCount:self.allCount countArr:self.countArr dataSource1:self.dataSource1 countArr1:self.countArr1 dataSource2:self.dataSource2 countArr2:self.countArr2];
    }
    
}


@end
