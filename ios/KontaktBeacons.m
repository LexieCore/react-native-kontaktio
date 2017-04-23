#import "KontaktBeacons.h"

#if __has_include("RCTConvert.h")
  #import "RCTConvert.h"
#else
  #import <React/RCTConvert.h>
#endif

//#if __has_include("RCTLog.h")
//  #import "RCTLog.h"
//#else
//  #import <React/RCTLog.h>
//#endif

#import <KontaktSDK/KontaktSDK.h>

@interface KontaktBeacons() <KTKBeaconManagerDelegate, KTKDevicesManagerDelegate>

@property (strong, nonatomic) KTKBeaconManager *beaconManager;
@property (strong, nonatomic) KTKDevicesManager *devicesManager;

@property (assign, nonatomic) BOOL dropEmptyRanges;
@property (assign, nonatomic) NSTimeInterval discoveryInterval;
@property (assign, nonatomic) BOOL connectNearbyBeacons;
@property (assign, nonatomic) NSTimeInterval invalidationAge;  // Default: 10


@end


@implementation KontaktBeacons
{
    bool hasListeners;
}

RCT_EXPORT_MODULE()


#pragma mark Initialization

- (instancetype)init
{
    if (self = [super init]) {

        [Kontakt removeCaches];
        [Kontakt setAPIKey:@"default-kontaktio-api-key"];

        // init of beaconManager has to happen here.

        // BeaconManager for monitoring and ranging
        self.beaconManager = [[KTKBeaconManager alloc] initWithDelegate:self];

        // DevicesManager for kontaktio specific fields like uniqueId
        self.devicesManager = [[KTKDevicesManager alloc] initWithDelegate:self];

        // Default values
        self.dropEmptyRanges = YES;
        self.connectNearbyBeacons = NO;
    }

    return self;
}

#pragma mark

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"authorizationStatusDidChange",
        @"monitoringDidFailForRegion",
        @"didStartMonitoringForRegion",
        @"EventReminder",
        @"didEnterRegion",
        @"didExitRegion",
        @"didRangeBeacons",
        @"rangingDidFailForRegion",
        @"didDiscoverDevices",
    ];
}

- (NSDictionary *)constantsToExport
{
    return @{ @"DEFAULT_API_KEY": @"default-kontaktio-api-key" };
}


// Will be called when this module's first listener is added.
-(void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}

- (void)calendarEventReminderReceived:(NSNotification *)notification
{
    NSString *eventName = notification.userInfo[@"name"];
    if (hasListeners) { // Only send events if anyone is listening
        [self sendEventWithName:@"EventReminder" body:@{@"name": eventName}];
    }
}


RCT_EXPORT_METHOD(test)
{
    NSLog(@"This is the first test method of the Kontakt.io package!");
}

// Promise
RCT_REMAP_METHOD(findEvents,
                 findEvents_resolver:(RCTPromiseResolveBlock)resolve
                 findEvents_rejecter:(RCTPromiseRejectBlock)reject)
{
    NSArray *events = @[@"one", @"two", @"three"];
    if (events) {
        resolve(events);
    } else {
        NSError *error;
        reject(@"no_events", @"There were no events", error);
    }
}


// ---------
// HELPER METHODS
// ---------

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
                                 minor:(NSInteger) minor
{
    NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    unsigned short mj = (unsigned short) major;
    unsigned short mi = (unsigned short) minor;

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:beaconUUID major:mj
                                                                           minor:mi
                                                                      identifier:identifier];

    beaconRegion.notifyEntryStateOnDisplay = YES;

    return beaconRegion;
}

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
{
    NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    unsigned short mj = (unsigned short) major;

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:beaconUUID
                                                                           major:mj
                                                                      identifier:identifier];

    beaconRegion.notifyEntryStateOnDisplay = YES;

    return beaconRegion;
}

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                   uuid: (NSString *) uuid
{
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:proximityUUID
                                                                        identifier:identifier];
    beaconRegion.notifyEntryStateOnDisplay = YES;

    NSLog(@"beacon region created!");
    return beaconRegion;
}


-(KTKBeaconRegion *) convertDictToBeaconRegion: (NSDictionary *) dict
{
    if (dict[@"minor"] == nil) {
        if (dict[@"major"] == nil) {
            return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                       uuid:[RCTConvert NSString:dict[@"uuid"]]];
        } else {
            return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                       uuid:[RCTConvert NSString:dict[@"uuid"]]
                                      major:[RCTConvert NSInteger:dict[@"major"]]];
        }
    } else {
        return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                   uuid:[RCTConvert NSString:dict[@"uuid"]]
                                  major:[RCTConvert NSInteger:dict[@"major"]]
                                  minor:[RCTConvert NSInteger:dict[@"minor"]]];
    }
}

-(NSString *)stringForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:    return @"unknown";
        case CLProximityFar:        return @"far";
        case CLProximityNear:       return @"near";
        case CLProximityImmediate:  return @"immediate";
        default:                    return @"";
    }
}

// TODO: Test it
-(NSNumber *)numberForTxPowerLevel:(KTKDeviceTransmissionPower)transmissionPower {
    switch (transmissionPower) {
        case KTKDeviceTransmissionPowerInvalid:    return @-1;
        case KTKDeviceTransmissionPower0:        return @0;
        case KTKDeviceTransmissionPower1:       return @1;
        case KTKDeviceTransmissionPower2:       return @2;
        case KTKDeviceTransmissionPower3:       return @3;
        case KTKDeviceTransmissionPower4:       return @4;
        case KTKDeviceTransmissionPower5:       return @5;
        case KTKDeviceTransmissionPower6:       return @6;
        case KTKDeviceTransmissionPower7:       return @7;
        default:                    return @-1;
    }
}

-(NSString *)stringForModel:(KTKDeviceModel)model {
    switch(model) {
        case KTKDeviceModelInvalid: return @"Invalid";
        case KTKDeviceModelUnknown: return @"Unknown";
        case KTKDeviceModelSmartBeacon: return @"SmartBeacon";
        case KTKDeviceModelUSBBeacon: return @"USBBeacon";
        case KTKDeviceModelSensorBeacon: return @"SensorBeacon";
        case KTKDeviceModelCloudBeacon: return @"CloudBeacon";
        case KTKDeviceModelCardBeacon: return @"CardBeacon";
        case KTKDeviceModelProBeacon: return @"ProBeacon";
    }
}

// ---------
// EXPOSED METHODS
// ---------

RCT_EXPORT_METHOD(init:(NSString *)apiKey
                 init_resolver:(RCTPromiseResolveBlock)resolve
                 init_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (apiKey != nil) {
            [Kontakt removeCaches];
            [Kontakt setAPIKey:[RCTConvert NSString:apiKey]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Could not init beacon manager" }];
        reject(@"not_init", @"Could not init beacon manager", error);
    }

//    @try {
//        switch ([KTKBeaconManager locationAuthorizationStatus]) {
//            case kCLAuthorizationStatusNotDetermined:
//                [self.beaconManager requestLocationAlwaysAuthorization];
//                break;
//
//            case kCLAuthorizationStatusDenied:
//            case kCLAuthorizationStatusRestricted:
//                // No access to Location Services
//                break;
//
//            case kCLAuthorizationStatusAuthorizedWhenInUse:
//                // For most iBeacon-based app this type of
//                // permission is not adequate
//                break;
//
//            case kCLAuthorizationStatusAuthorizedAlways:
//                break;
//        }
//        NSLog(@"current status: %d", [KTKBeaconManager locationAuthorizationStatus]);
//        resolve(@"Beacon module initialized");
//    } @catch (NSException *exception) {
//        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Could not init beacon manager" }];
//        reject(@"not_init", @"Could not init beacon manager", error);
//    }

}

RCT_EXPORT_METHOD(configure:(NSDictionary *)dict
                  configure_resolver:(RCTPromiseResolveBlock)resolve
                  configure_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (dict[@"dropEmptyRanges"] != nil) {
            self.dropEmptyRanges = [RCTConvert BOOL:dict[@"dropEmptyRanges"]];
        }
        if (dict[@"connectNearbyBeacons"] != nil) {
            self.connectNearbyBeacons = [RCTConvert BOOL:dict[@"connectNearbyBeacons"]];
        }
        if (dict[@"invalidationAge"] != nil) {
            self.invalidationAge = [RCTConvert NSTimeInterval:dict[@"invalidationAge"]];
            self.devicesManager.invalidationAge = self.invalidationAge;
        }
        // TODO: add other stuff to configure?!

        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in configure" }];
        reject(@"Error: configure", @"Could not configure beacon manager", error);
    }
}

// DISCOVERY

RCT_EXPORT_METHOD(startScanning:(NSDictionary *)dict
                  startScanning_resolver:(RCTPromiseResolveBlock)resolve
                  startScanning_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (dict == nil || dict[@"interval"] == nil) {
            [self.devicesManager startDevicesDiscovery];
        } else {
            self.discoveryInterval = [RCTConvert NSTimeInterval:dict[@"interval"]];
            NSLog(@"else case: interval from dict: %@, interval from variable: %@", dict[@"interval"], @(self.discoveryInterval));
            [self.devicesManager startDevicesDiscoveryWithInterval:self.discoveryInterval];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in startScanning" }];
        reject(@"Error: startScanning", @"Could not startScanning", error);
    }
}


RCT_REMAP_METHOD(stopScanning,
                  stopScanning_resolver:(RCTPromiseResolveBlock)resolve
                  stopScanning_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.devicesManager stopDevicesDiscovery];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in stopScanning" }];
        reject(@"Error: stopScanning", @"Could not stopScanning", error);
    }
}

RCT_REMAP_METHOD(restartScanning,
                 restartScanning_resolver:(RCTPromiseResolveBlock)resolve
                 restartScanning_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.devicesManager restartDeviceDiscoveryWithCompletion:^(NSError *error) {
            NSLog(@"ERROR in restartScanning: %@", error.localizedDescription);
            if (error != nil) {
                [NSException raise:@"Cannot restart scanning" format:@"error in restartDeviceDiscoveryWithCompletion"];
            }
        }];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in restartScanning" }];
        reject(@"Error: restartScanning", @"Could not restartScanning", error);
    }
}

// is discovering
RCT_REMAP_METHOD(isScanning,
                 isScanning_resolver:(RCTPromiseResolveBlock)resolve
                 isScanning_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        BOOL isDiscovering = [self.devicesManager isDiscovering];
        resolve(@(isDiscovering));
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in isScanning" }];
        reject(@"Error: isScanning", @"Could not isScanning", error);
    }
}


// RANGING & MONITORING

RCT_EXPORT_METHOD(startRangingBeaconsInRegion:(NSDictionary *)dict
                  startRangingBeaconsInRegion_resolver:(RCTPromiseResolveBlock)resolve
                  startRangingBeaconsInRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([KTKBeaconManager isRangingAvailable]) {
            [self.beaconManager startRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in startRangingBeaconsInRegion" }];
        reject(@"Error: startRangingBeaconsInRegion", @"Could not startRangingBeaconsInRegion", error);
    }
}

RCT_EXPORT_METHOD(stopRangingBeaconsInRegion:(NSDictionary *)dict
                  stopRangingBeaconsInRegion_resolver:(RCTPromiseResolveBlock)resolve
                  stopRangingBeaconsInRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in stopRangingBeaconsInRegion" }];
        reject(@"Error: stopRangingBeaconsInRegion", @"Could not stopRangingBeaconsInRegion", error);
    }
}

RCT_REMAP_METHOD(stopRangingBeaconsInAllRegions,
                 stopRangingBeaconsInAllRegions_resolver:(RCTPromiseResolveBlock)resolve
                 stopRangingBeaconsInAllRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopRangingBeaconsInAllRegions];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in stopRangingBeaconsInAllRegions" }];
        reject(@"Error: stopRangingBeaconsInAllRegions", @"Could not stopRangingBeaconsInAllRegions", error);
    }
}

RCT_EXPORT_METHOD(startMonitoringForRegion:(NSDictionary *)dict
                 startMonitoringForRegion_resolver:(RCTPromiseResolveBlock)resolve
                 startMonitoringForRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([KTKBeaconManager isMonitoringAvailable]) {
            [self.beaconManager startMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {

        // Create error
//        NSString *domain = @"com.artirigo.kontakt.errors";
//        NSString *desc = NSLocalizedString(@"Error: startMonitoringForRegion", @"");
//        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
//        NSError *error = [NSError errorWithDomain:domain code:-101 userInfo:userInfo];

        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in startMonitoringForRegion" }];
        reject(@"Error: startMonitoringForRegion", @"Could not startMonitoringForRegion", error);
    }
}

RCT_EXPORT_METHOD(stopMonitoringForRegion:(NSDictionary *)dict
                  stopMonitoringForRegion_resolver:(RCTPromiseResolveBlock)resolve
                  stopMonitoringForRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in stopMonitoringForRegion" }];
        reject(@"Error: stopMonitoringForRegion", @"Could not stopMonitoringForRegion", error);
    }
}

RCT_REMAP_METHOD(stopMonitoringForAllRegions,
                 stopMonitoringForAllRegions_resolver:(RCTPromiseResolveBlock)resolve
                 stopMonitoringForAllRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopMonitoringForAllRegions];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in stopMonitoringForAllRegions" }];
        reject(@"Error: stopMonitoringForAllRegions", @"Could not stopMonitoringForAllRegions", error);
    }
}

// TODO: Test
RCT_REMAP_METHOD(getAuthorizationStatus,
                 getAuthorizationStatus_resolver:(RCTPromiseResolveBlock)resolve
                 getAuthorizationStatus_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        CLAuthorizationStatus status = [KTKBeaconManager locationAuthorizationStatus];
//        CLAuthorizationStatus status = self.beaconManager.locationAuthorizationStatus;
        resolve([self nameForAuthorizationStatus:status]);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in getAuthorizationStatus" }];
        reject(@"Error: getAuthorizationStatus", @"Could not getAuthorizationStatus", error);
    }
}

// TODO: Test
RCT_REMAP_METHOD(requestAlwaysAuthorization,
                 requestAlwaysAuthorization_resolver:(RCTPromiseResolveBlock)resolve
                 requestAlwaysAuthorization_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([self.beaconManager respondsToSelector:@selector(requestLocationAlwaysAuthorization)]) {
            [self.beaconManager requestLocationAlwaysAuthorization];
        } else {
            [NSException raise:@"Cannot request LocationAlwaysAuthorization" format:@"requestAlwaysAuthorization does not respond to selector"];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in requestAlwaysAuthorization" }];
        reject(@"Error: requestAlwaysAuthorization", @"Could not requestAlwaysAuthorization", error);
    }
}

// TODO: Test
RCT_REMAP_METHOD(requestWhenInUseAuthorization,
                 requestWhenInUseAuthorization_resolver:(RCTPromiseResolveBlock)resolve
                 requestWhenInUseAuthorization_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([self.beaconManager respondsToSelector:@selector(requestLocationWhenInUseAuthorization)]) {
            [self.beaconManager requestLocationWhenInUseAuthorization];
        } else {
            [NSException raise:@"Cannot request LocationWhenInUseAuthorization" format:@"requestLocationWhenInUseAuthorization does not respond to selector"];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in requestAlwaysAuthorization" }];
        reject(@"Error: requestAlwaysAuthorization", @"Could not requestAlwaysAuthorization", error);
    }
}

// TODO: Test
RCT_REMAP_METHOD(getRangedRegions,
                 getRangedRegions_resolver:(RCTPromiseResolveBlock)resolve
                 getRangedRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        NSSet<__kindof KTKBeaconRegion*>* regions = [self.beaconManager rangedRegions];

        NSMutableArray *regionArray = [[NSMutableArray alloc] init];

        for (KTKBeaconRegion *region in regions) {
            [regionArray addObject:@{
                                     @"identifier": region.identifier,
                                     @"uuid": [region.proximityUUID UUIDString],
                                     }];
        }
        resolve(regionArray);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in getRangedRegions" }];
        reject(@"Error: getRangedRegions", @"Could not getRangedRegions", error);
    }
}

// TODO: Test
RCT_REMAP_METHOD(getMonitoredRegions,
                 getMonitoredRegions_resolver:(RCTPromiseResolveBlock)resolve
                 getMonitoredRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        NSSet<__kindof KTKBeaconRegion*>* regions = [self.beaconManager monitoredRegions];

        NSMutableArray *regionArray = [[NSMutableArray alloc] init];

        for (KTKBeaconRegion *region in regions) {
            [regionArray addObject:@{
                                     @"identifier": region.identifier,
                                     @"uuid": [region.proximityUUID UUIDString],
                                     }];
        }
        resolve(regionArray);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.artirigo.kontakt" code:0 userInfo:@{ @"message": @"Error in getMonitoredRegions" }];
        reject(@"Error: getMonitoredRegions", @"Could not getMonitoredRegions", error);
    }
}

// ---------
// LISTENERS
// ---------

-(NSString *)nameForAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:    return @"authorizedAlways";
        case kCLAuthorizationStatusAuthorizedWhenInUse: return @"authorizedWhenInUse";
        case kCLAuthorizationStatusDenied:              return @"denied";
        case kCLAuthorizationStatusNotDetermined:       return @"notDetermined";
        case kCLAuthorizationStatusRestricted:          return @"restricted";
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didChangeLocationAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways) {
        // When status changes to kCLAuthorizationStatusAuthorizedAlways
        // e.g. after calling [self.beaconManager requestLocationAlwaysAuthorization]
        // we can start region monitoring from here
        NSLog(@"you have always authorization!");

        NSString *statusName = [self nameForAuthorizationStatus:status];
        if (hasListeners) {
            [self sendEventWithName:@"authorizationStatusDidChange" body:@{@"status": statusName}];
        }
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didStartMonitoringForRegion:(__kindof KTKBeaconRegion *)region {
    // Do something when monitoring for a particular
    // region is successfully initiated
    NSLog(@"Beacons: didStartMonitoringForRegion");

    NSDictionary *beaconRegion = @{
                             @"identifier": region.identifier,
                             @"uuid": [region.proximityUUID UUIDString],
                             };
    if (hasListeners) {
        [self sendEventWithName:@"didStartMonitoringForRegion" body:@{@"region": beaconRegion}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager monitoringDidFailForRegion:(__kindof KTKBeaconRegion *)region withError:(NSError *)error {
    // Handle monitoring failing to start for your region
    NSLog(@"Beacons: monitoringDidFailForRegion");

    NSDictionary *beaconRegion = @{
                             @"identifier": region.identifier,
                             @"uuid": [region.proximityUUID UUIDString],
                             };
    if (hasListeners) {
        [self sendEventWithName:@"monitoringDidFailForRegion" body:@{@"region": beaconRegion, @"error": error.localizedDescription}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didEnterRegion:(__kindof KTKBeaconRegion *)region {
    // Decide what to do when a user enters a range of your region; usually used
    // for triggering a local notification and/or starting a beacon ranging
    NSLog(@"Beacons: didEnterRegion");

    NSDictionary *beaconRegion = @{
                             @"identifier": region.identifier,
                             @"uuid": [region.proximityUUID UUIDString],
                             };
    if (hasListeners) {
        [self sendEventWithName:@"didEnterRegion" body:@{@"region": beaconRegion}];
    }
    [manager startRangingBeaconsInRegion:region];
}

- (void)beaconManager:(KTKBeaconManager *)manager didExitRegion:(__kindof KTKBeaconRegion *)region {
    // Decide what to do when a user exits a range of your region; usually used
    // for triggering a local notification and stoping a beacon ranging
    NSLog(@"Beacons: didExitRegion");

    NSDictionary *beaconRegion = @{
                             @"identifier": region.identifier,
                             @"uuid": [region.proximityUUID UUIDString],
                             };
    if (hasListeners) {
        [self sendEventWithName:@"didExitRegion" body:@{@"region": beaconRegion}];
    }
    [manager stopRangingBeaconsInRegion:region];
}

- (void)beaconManager:(KTKBeaconManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(__kindof KTKBeaconRegion *)region {

    if (self.dropEmptyRanges && beacons.count == 0) {
        NSLog(@"Beacons: no beacons ranged");
        return;
    }

    NSLog(@"Beacons: didRangeBeacons");

    NSMutableArray *beaconArray = [[NSMutableArray alloc] init];

    for (CLBeacon *beacon in beacons) {
        [beaconArray addObject:@{
                                 @"uuid": [beacon.proximityUUID UUIDString],
                                 @"major": beacon.major,
                                 @"minor": beacon.minor,

                                 @"rssi": [NSNumber numberWithLong:beacon.rssi],
                                 @"proximity": [self stringForProximity: beacon.proximity],
                                 @"accuracy": [NSNumber numberWithDouble: beacon.accuracy]
                                 }];
    }

    NSDictionary *event = @{
                            @"region": @{
                                    @"identifier": region.identifier,
                                    @"uuid": [region.proximityUUID UUIDString],
                                    },
                            @"beacons": beaconArray
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didRangeBeacons" body:event];
    }
//    [self.bridge.eventDispatcher sendDeviceEventWithName:@"beaconsDidRange" body:event];
}

- (void)beaconManager:(KTKBeaconManager *)manager rangingBeaconsDidFailForRegion:(__kindof KTKBeaconRegion *)region withError:(NSError *)error {
    // Handle ranging failing to start for your region
    NSLog(@"Beacons: rangingDidFailForRegion");

    NSDictionary *beaconRegion = @{
                                   @"identifier": region.identifier,
                                   @"uuid": [region.proximityUUID UUIDString],
                                   };
    if (hasListeners) {
        [self sendEventWithName:@"rangingDidFailForRegion" body:@{@"region": beaconRegion, @"error": error.localizedDescription}];
    }
}

- (void)devicesManager:(KTKDevicesManager *)manager didDiscoverDevices:(NSArray<KTKNearbyDevice *> *)devices {
    NSLog(@"Beacons: didDiscoverDevices, devices.count: %lu", (unsigned long)devices.count);

    // TODO: Test dropEmptyRanges and fix it!
    if (self.dropEmptyRanges && devices.count == 0) {
        NSLog(@"Devices: no devices nearby");
        return;
    }

    NSMutableArray *deviceArray = [[NSMutableArray alloc] init];
    NSString *errorMessage = @"NO_ERROR";

    for (KTKNearbyDevice *device in devices) {

        // Investigate for future version
        if (1 == 2) {
            if (self.connectNearbyBeacons) {
                NSLog(@"entered else case");
                // Connect to nearby devices is necessary in iOS to get major, minor and UUID
                KTKDeviceConnection *connection = [[KTKDeviceConnection alloc] initWithNearbyDevice:device];

                // Does not work with firmware 3.1: Read configuration was cancelled (Legacy Firmware)
                // Beacons with 4.1 firmware (e.g. d0JF) throw: Request failed: forbidden (403)
                // After entering correct API key in configuration I get: Request failed: internal server error (500)
                [connection readConfigurationWithCompletion:^(KTKDeviceConfiguration* configuration, NSError* error) {
                    //                NSLog(@"in read configuration: beacon with uniqueId %@, error: %@", device.uniqueID, error.localizedDescription);
                    if (error == nil) {
                        NSLog(@"in read CONFIGuration uniqueId: %@, uniqueId from config: %@, uuid: %@, minor: %@", device.uniqueID, configuration.uniqueID, [configuration.proximityUUID UUIDString], configuration.minor);
                    } else {
                        NSLog(@"in read configuration: beacon with uniqueId %@, error: %@", device.uniqueID, error.localizedDescription);
                        //                    [NSException raise:@"Error in readConfigurationWithCompletion" format:@"%@", error.localizedDescription];
                    }
                }];
            } else {
                //
            }
        }


        [deviceArray addObject:@{
                                 @"name": device.name,
                                 @"uniqueId": device.uniqueID,
                                 @"firmwareVersion": device.firmwareVersion,
                                 @"batteryLevel": [NSNumber numberWithLong:device.batteryLevel],
                                 @"batteryPowered": @(device.batteryPowered),
                                 @"hasConfigurationProfile": @(device.hasConfigurationProfile),
                                 @"transmissionPower": [self numberForTxPowerLevel:device.transmissionPower],
                                 @"shuffled": @(device.shuffled),
                                 @"locked": @(device.locked),
                                 @"model": [self stringForModel:device.model],
                                 @"rssi": device.RSSI,
//                                 @"distance": KTKCalculateDistanceFrom(device.transmissionPower, device.RSSI)
                                 @"updatedAt": @(device.updatedAt),
                                 // TODO: Add other fields from KTKNearbyDevice
                                 }];
    }

    NSDictionary *event = @{
                            @"beacons": deviceArray,
                            @"error": errorMessage,
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didDiscoverDevices" body:event];
    }
}

- (void)devicesManagerDidFailToStartDiscovery:(KTKDevicesManager *)manager withError:(NSError *)error {
    NSLog(@"Beacons: devicesManagerDidFailToStartDiscovery");
    if (hasListeners) {
        [self sendEventWithName:@"devicesManagerDidFailToStartDiscovery" body:@{ @"error": @"Could not start discovery of beacons" }];
    }
}

@end