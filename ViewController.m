//
//  ViewController.m
//  uavmun
//
//  Created by  sy2036 on 2017-10-17.
//  Copyright © 2017 vclab. All rights reserved.
//

#import "ViewController.h"
#import "ImageProcessing.h"
#import "UIImage+Additions.h"

#define WeakRef(__obj) __weak typeof(self) __obj = self
#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;

@interface ViewController ()<DJIVideoFeedListener, DJISDKManagerDelegate, DJICameraDelegate, DJIFlightControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ImageProcessingDelegate> {
    
    NSTimer *captureMissionTimer;
}

@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (assign, nonatomic) BOOL isRecording;
@property (atomic) CLLocationCoordinate2D aircraftLocation;
@property (atomic) double aircraftAltitude;
@property (atomic) DJIGPSSignalLevel gpsSignalLevel;
@property (atomic) double aircraftYaw;
@property (nonatomic) ImageProcessing *imageProcess;

@property (nonatomic, strong) UIImage *originalImage;

@property (weak, nonatomic) IBOutlet UIImageView *originalImageView;

@end

@implementation ViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self registerApp];
    
    self.imageProcess = [[ImageProcessing alloc] init];
    self.imageProcess.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    DJICamera *camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    [self resetVideoPreview];
    
    captureMissionTimer = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self rotateDroneWithJoystick];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Process Image
- (void)imageProcessAlgorithm {
    NSLog(@"aaaaa");
    [[self missionOperator] stopMissionWithCompletion:nil];
    [_imageProcess processImageWithCameraImage:[self imageWithView:_fpvPreviewView] andCurrentCoordinate:_aircraftLocation andAltitude:_aircraftAltitude];
}

- (IBAction)rotationTest:(id)sender {
    captureMissionTimer = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(imageProcessAlgorithm) userInfo:nil repeats:YES];
}

- (IBAction)startImageCapture:(id)sender {
    [self selectPhotoFromAblum];
}

- (IBAction)initialAircraftForMoving:(id)sender {
    
}

- (void)selectPhotoFromAblum {
    UIImagePickerController *picker = [[UIImagePickerController alloc]init];
    //设置图片源(相簿)
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    //设置代理
    picker.delegate = self;
    //设置可以编辑
    picker.allowsEditing = YES;
    //打开拾取器界面
    [self presentViewController:picker animated:YES completion:nil];
}

- (UIImage *)imageWithView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size,   view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}


- (void)setupVideoPreviewer {
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    DJIBaseProduct *product = [DJISDKManager product];
    if ([product.model isEqual:DJIAircraftModelNameA3] ||
        [product.model isEqual:DJIAircraftModelNameN3] ||
        [product.model isEqual:DJIAircraftModelNameMatrice600] ||
        [product.model isEqual:DJIAircraftModelNameMatrice600Pro]) {
        [[DJISDKManager videoFeeder].secondaryVideoFeed addListener:self withQueue:nil];
        
    } else {
        [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    }
    [[VideoPreviewer instance] start];
}

- (void)resetVideoPreview {
    [[VideoPreviewer instance] unSetView];
    DJIBaseProduct *product = [DJISDKManager product];
    if ([product.model isEqual:DJIAircraftModelNameA3] ||
        [product.model isEqual:DJIAircraftModelNameN3] ||
        [product.model isEqual:DJIAircraftModelNameMatrice600] ||
        [product.model isEqual:DJIAircraftModelNameMatrice600Pro]){
        [[DJISDKManager videoFeeder].secondaryVideoFeed removeListener:self];
    }else{
        [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
    }
}

#pragma mark -
#pragma mark UIImagePickerControllerDelegate methods
#pragma mark 取到了原图和飞机图
//完成选择图片
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    //加载图片
    NSData *imageData = UIImagePNGRepresentation(image);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:imageData forKey:@"originalImage"];
    NSLog(@"%f", image.size.width);
    //选择框消失
//    [_originalImageView setImage:_originalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
}
//取消选择图片
-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Custom Methods
- (DJICamera*)fetchCamera {
    
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]){
        return ((DJIHandheld *)[DJISDKManager product]).camera;
    }
    
    return nil;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)registerApp {
    //Please enter your App key in the "DJISDKAppKey" key in info.plist file.
    [DJISDKManager registerAppWithDelegate:self];
}

- (NSString *)formattingSeconds:(NSUInteger)seconds {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSString *formattedTimeString = [formatter stringFromDate:date];
    return formattedTimeString;
}

- (DJIFlightController *)fetchFlightController {
    if (![DJISDKManager product]) {
        return nil;
    }
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).flightController;
    }
    return nil;
}

#pragma mark - Rotate Drone With Waypoint Mission Methods

- (DJIWaypointMissionOperator *)missionOperator {
    return [[DJISDKManager missionControl] waypointMissionOperator];
}

- (void)rotateDroneWithWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    if (CLLocationCoordinate2DIsValid(self.aircraftLocation) && self.gpsSignalLevel != DJIGPSSignalLevel0 && self.gpsSignalLevel != DJIGPSSignalLevel1) {
        [self uploadWaypointMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
    }
    else {
        [self showAlertViewWithTitle:@"GPS signal weak" withMessage:@"Rotate drone failed"];
    }
}

- (void)initializeMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    DJIMutableWaypointMission *mission = [[DJIMutableWaypointMission alloc] init];
    mission.maxFlightSpeed = 15.0;
    mission.autoFlightSpeed = 4.0;
    
//    DJIWaypoint *wp1 = [[DJIWaypoint alloc] initWithCoordinate:self.aircraftLocation];
//    wp1.altitude = self.aircraftAltitude;
    
//    for (int i = 0; i < 8 ; i++) {
//
//        double rotateAngle = 45*i;
//
//        if (rotateAngle > 180) { //Filter the angle between -180 ~ 0, 0 ~ 180
//            rotateAngle = rotateAngle - 360;
//        }
//
//        DJIWaypointAction *action1 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeShootPhoto param:0];
//        DJIWaypointAction *action2 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeRotateAircraft param:rotateAngle];
//        [wp1 addAction:action1];
//        [wp1 addAction:action2];
//    }
    
    DJIWaypoint *wp2 = [[DJIWaypoint alloc] initWithCoordinate:self.aircraftLocation];
    wp2.altitude = self.aircraftAltitude + 1;
    
//    [mission addWaypoint:wp1];
    [mission addWaypoint:wp2];
    [mission setFinishedAction:DJIWaypointMissionFinishedNoAction]; //Change the default action of Go Home to None
    
    [[self missionOperator] loadMission:mission];
    
    weakSelf(target);
    
    [[self missionOperator] addListenerToUploadEvent:self withQueue:dispatch_get_main_queue() andBlock:^(DJIWaypointMissionUploadEvent * _Nonnull event) {
        
        weakReturn(target);
        if (event.currentState == DJIWaypointMissionStateUploading) {
            
            NSString *message = [NSString stringWithFormat:@"Uploaded Waypoint Index: %ld, Total Waypoints: %ld" ,event.progress.uploadedWaypointIndex + 1, event.progress.totalWaypointCount];
            
        } else if (event.currentState == DJIWaypointMissionStateReadyToExecute){
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Upload Mission Finished" message:nil preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *startMissionAction = [UIAlertAction actionWithTitle:@"Start Mission" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [target startWaypointMission];
            }];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:cancelAction];
            [alert addAction:startMissionAction];
            [target presentViewController:alert animated:YES completion:nil];
            
        }
        
    }];
    
    [[self missionOperator] addListenerToFinished:self withQueue:dispatch_get_main_queue() andBlock:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            [target showAlertViewWithTitle:@"Mission Execution Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
        }
        else {
            [target showAlertViewWithTitle:@"Mission Execution Finished" withMessage:nil];
            //  飞行完成后，回传新的坐标和高度值，以及图片。
            [self imageProcessAlgorithm];
//            [_imageProcess processImageWithCameraImage:[self imageWithView:_fpvPreviewView] andCurrentCoordinate:_aircraftLocation andAltitude:_aircraftAltitude];
        }
    }];
    
}

- (void)uploadWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    
    [self initializeMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
    
    weakSelf(target);
    
    [[self missionOperator] uploadMissionWithCompletion:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            NSLog(@"%@", [NSString stringWithFormat:@"Upload Mission Failed: %@", [NSString stringWithFormat:@"%@", error.description]]);
        }else
        {
            NSLog(@"Upload Mission Finished");
        }
    }];
}

- (void)startWaypointMission {
    weakSelf(target);
    //Start Mission
    [[self missionOperator] startMissionWithCompletion:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            [target showAlertViewWithTitle:@"Start Mission Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
        }
        else {
            [target showAlertViewWithTitle:@"Start Mission Success" withMessage:nil];
        }
    }];
}

#pragma mark DJISDKManagerDelegate Method
- (void)productConnected:(DJIBaseProduct *)product {
    if(product){
        DJICamera *camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
        }
        [self setupVideoPreviewer];
    }
    
    //If this demo is used in China, it's required to login to your DJI account to activate the application. Also you need to use DJI Go app to bind the aircraft to your DJI account. For more details, please check this demo's tutorial.
    [[DJISDKManager userAccountManager] logIntoDJIUserAccountWithAuthorizationRequired:NO withCompletion:^(DJIUserAccountState state, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Login failed: %@", error.description);
        }
    }];
    
    [self showAlertViewWithTitle:@"productConnected" withMessage:@""];
    
    DJIFlightController *flightController = [self fetchFlightController];
    if (flightController) {
        [flightController setDelegate:self];
        [flightController setYawControlMode:DJIVirtualStickYawControlModeAngle];
        [flightController setRollPitchCoordinateSystem:DJIVirtualStickFlightCoordinateSystemGround];
//        flightController.isVirtualStickAdvancedModeEnabled = YES;
        
        [flightController setVirtualStickModeEnabled:YES withCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Enable VirtualStickControlMode Failed");
            }
        }];
    }
    
}

- (void)productDisconnected {
    DJICamera *camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    [self resetVideoPreview];
}

#pragma mark DJISDKManagerDelegate Method

- (void)appRegisteredWithError:(NSError *)error {
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    } else {
        NSLog(@"registerAppSuccess");
        [DJISDKManager startConnectionToProduct];
    }
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

#pragma mark - DJICameraDelegate

- (void) camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState {
    self.isRecording = systemState.isRecording;
}

#pragma mark - DJIFlightControllerDelegate Method
- (void)flightController:(DJIFlightController *_Nonnull)fc didUpdateState:(DJIFlightControllerState *_Nonnull)state {
    self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation.coordinate.latitude, state.aircraftLocation.coordinate.longitude);
    self.gpsSignalLevel = state.GPSSignalLevel;
    self.aircraftAltitude = state.altitude;
    self.aircraftYaw = state.attitude.yaw;
}

#pragma mark - DJIVideoFeedListener
- (void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}

#pragma mark
#pragma mark - ImageProcessDelegate
- (void)imageProcessdSuccessWithTargetCoordiante:(CLLocationCoordinate2D)targetCoordiante andTargetAltitude:(double)targetAltitude {
    [self rotateDroneWithWaypointMissionWithCoordinate:targetCoordiante andTargetAltitude:targetAltitude];
}

@end
