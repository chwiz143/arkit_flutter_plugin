#import "FlutterArkit.h"
#import "Color.h"
#import "GeometryBuilder.h"
#import "SceneViewDelegate.h"
#import "CodableUtils.h"
#import "DecodableUtils.h"
#import <SceneKit/ModelIO.h>
#import "ArkitPlugin.h"
#import "ARSCNView+Gestures.h"
#import "VideoRecorder.h"

@interface FlutterArkitFactory()
@property NSObject<FlutterBinaryMessenger>* messenger;
@end

@implementation FlutterArkitFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
  self = [super init];
  if (self) {
    self.messenger = messenger;
  }
  return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  FlutterArkitController* arkitController =
      [[FlutterArkitController alloc] initWithWithFrame:frame
                                         viewIdentifier:viewId
                                              arguments:args
                                        binaryMessenger:self.messenger];
  return arkitController;
}

@end

@interface FlutterArkitController()
@property ARPlaneDetection planeDetection;
@property int64_t viewId;
@property FlutterMethodChannel* channel;
@property (strong) SceneViewDelegate* delegate;
@property (readwrite) ARConfiguration *configuration;
@property BOOL forceUserTapOnCenter;
@property (strong, nonatomic) CIContext* ciContext;

@property SCNNode* objectsParent;

@property int viewWidth;
@property int viewHeight;

@property BOOL nurieFindingMode;
@property NSMutableDictionary* nurieParams;
@property NSDate* markerGazeStartTime;
@property NurieParams* targetNurieMarker;

@property NSMutableSet* referenceObjects;

@property VideoRecorder* videoRecorder;

@property ARHitTestResult* lastTappedPlane;


@end

@implementation FlutterArkitController

static const NSString* REFERENCE_CHILD_NODE = @"REFERENCE_CHILD_NODE";

static NSMutableSet *g_mSet = NULL;

float prevMarkerCorners[] = {0,0,0,0,0,0,0,0};
const float markerGazingDuration = 250.0 / 1000.0;
const int thresholdMarkerCorners = 5;

- (instancetype)initWithWithFrame:(CGRect)frame
                   viewIdentifier:(int64_t)viewId
                        arguments:(id _Nullable)args
                  binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if ([super init]) {
        _viewId = viewId;
        _sceneView = [[ARSCNView alloc] initWithFrame:frame];

        _videoRecorder = [[VideoRecorder alloc] initWithView:_sceneView];
        _videoRecorder.delegate = self;

        NSString* channelName = [NSString stringWithFormat:@"arkit", viewId];
        NSLog(@"####### channelName=%@", channelName);
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        __weak __typeof__(self) weakSelf = self;
        [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            [weakSelf onMethodCall:call result:result];
        }];
        self.delegate = [[SceneViewDelegate alloc] initWithChannel: _channel controller:self];
        _sceneView.delegate = self.delegate;

        _objectsParent = [[SCNNode alloc] init];
        _objectsParent.name = @"objectsParent";
        [_sceneView.scene.rootNode addChildNode:_objectsParent];
        
        [self setupLifeCycle];
    }
    return self;
}

- (void) setupLifeCycle {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)applicationWillEnterForeground {
    NSLog(@"applicationWillEnterForeground");
}

- (void)applicationDidBecomeActive {
    NSLog(@"applicationDidBecomeActive");
}

- (void)applicationWillResignActive {
    NSLog(@"applicationWillResignActive");
    [_videoRecorder stopRecord];
}

- (void)applicationDidEnterBackground {
    NSLog(@"applicationDidEnterBackground");
    [_videoRecorder stopRecord];
}

- (void)applicationWillTerminate {
    NSLog(@"applicationWillTerminate");
    [_videoRecorder stopRecord];
}

- (UIView*)view {
  return _sceneView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"onMethodCall %@ - %@", call.method, call.arguments);
//   if ([[call method] isEqualToString:@"init"]) {
//     [self init:call result:result];
  if ([[call method] isEqualToString:@"addARKitNode"]) {
    [self onAddNode:call result:result];
  } else if ([[call method] isEqualToString:@"removeARKitNode"]) {
    [self onRemoveNode:call result:result];
  } else if ([[call method] isEqualToString:@"getNodeBoundingBox"]) {
    [self onGetNodeBoundingBox:call result:result];
  } else if ([[call method] isEqualToString:@"positionChanged"]) {
    [self updatePosition:call andResult:result];
  } else if ([[call method] isEqualToString:@"rotationChanged"]) {
    [self updateRotation:call andResult:result];
  } else if ([[call method] isEqualToString:@"eulerAnglesChanged"]) {
    [self updateEulerAngles:call andResult:result];
  } else if ([[call method] isEqualToString:@"scaleChanged"]) {
    [self updateScale:call andResult:result];
  } else if ([[call method] isEqualToString:@"isHiddenChanged"]) {
    [self updateIsHidden:call andResult:result];
  } else if ([[call method] isEqualToString:@"isPlayChanged"]) {
    [self updateIsPlay:call andResult:result];
  } else if ([[call method] isEqualToString:@"updateSingleProperty"]) {
    [self updateSingleProperty:call andResult:result];
  } else if ([[call method] isEqualToString:@"updateMaterials"]) {
    [self updateMaterials:call andResult:result];
//   } else if ([[call method] isEqualToString:@"updateFaceGeometry"]) {
//     [self updateFaceGeometry:call andResult:result];
  } else if ([[call method] isEqualToString:@"getLightEstimate"]) {
    [self onGetLightEstimate:call andResult:result];
  } else if ([[call method] isEqualToString:@"projectPoint"]) {
    [self onProjectPoint:call andResult:result];
  } else if ([[call method] isEqualToString:@"cameraProjectionMatrix"]) {
    [self onCameraProjectionMatrix:call andResult:result];
  } else if ([[call method] isEqualToString:@"startAnimation"]) {
    [self onStartAnimation:call andResult:result];
  } else if ([[call method] isEqualToString:@"stopAnimation"]) {
    [self onStopAnimation:call andResult:result];
  } else if ([[call method] isEqualToString:@"dispose"]) {
    [self.sceneView.session pause];
    NSLog(@"ARKit is dispose");
  } else if ([[call method] isEqualToString:@"initStartWorldTrackingSessionWithImage"]) {
    [self initStartWorldTrackingSessionWithImage:call result:result];
  } else if ([[call method] isEqualToString:@"addImageRunWithConfigAndImage"]) {
    [self addImageRunWithConfigAndImage:call result:result];
  } else if ([[call method] isEqualToString:@"startWorldTrackingSessionWithImage"]) {
    [self startWorldTrackingSessionWithImage:call result:result];
  } else if ([call.method isEqualToString:@"screenCapture"]) {
      [self screenCapture: call andResult: result];
  } else if ([call.method isEqualToString:@"toggleScreenRecord"]) {
      [self toggleScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"startScreenRecord"]) {
      [self startScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"stopScreenRecord"]) {
      [self stopScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"addNurie"]) {
      [self addNurie: call result: result];
  } else if ([call.method isEqualToString:@"findNurieMarker"]) {
      [self findNurieMarker: call result: result];
  } else if ([call.method isEqualToString:@"applyNurieTexture"]) {
      [self applyNurieTexture: call result: result];
  } else if ([call.method isEqualToString:@"addTransformableNode"]) {
      [self addTransformableNode: call result: result];
  } else if ([call.method isEqualToString:@"addReferenceObject"]) {
      [self addReferenceObject:call result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

// - (void)init:(FlutterMethodCall*)call result:(FlutterResult)result {
//     NSNumber* showStatistics = call.arguments[@"showStatistics"];
//     self.sceneView.showsStatistics = [showStatistics boolValue];
  
//     NSNumber* autoenablesDefaultLighting = call.arguments[@"autoenablesDefaultLighting"];
//     self.sceneView.autoenablesDefaultLighting = [autoenablesDefaultLighting boolValue];
    
//     NSNumber* forceUserTapOnCenter = call.arguments[@"forceUserTapOnCenter"];
//     self.forceUserTapOnCenter = [forceUserTapOnCenter boolValue];
  
//     NSNumber* requestedPlaneDetection = call.arguments[@"planeDetection"];
//     self.planeDetection = [self getPlaneFromNumber:[requestedPlaneDetection intValue]];
    
//     if ([call.arguments[@"enableTapRecognizer"] boolValue]) {
//         UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
//         [self.sceneView addGestureRecognizer:tapGestureRecognizer];
//     }
    
//     if ([call.arguments[@"enablePinchRecognizer"] boolValue]) {
//         UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchFrom:)];
//         [self.sceneView addGestureRecognizer:pinchGestureRecognizer];
//     }
    
//     if ([call.arguments[@"enablePanRecognizer"] boolValue]) {
//         UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
//         [self.sceneView addGestureRecognizer:panGestureRecognizer];
//     }
    
//     self.sceneView.debugOptions = [self getDebugOptions:call.arguments];
    
//     _configuration = [self buildConfiguration: call.arguments];

//     [self.sceneView.session runWithConfiguration:[self configuration]];
//     result(nil);
// }

- (void)initStartWorldTrackingSessionWithImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    _viewWidth = _sceneView.bounds.size.width;
    _viewHeight = _sceneView.bounds.size.height;
    NSNumber* showStatistics = call.arguments[@"showStatistics"];
    self.sceneView.showsStatistics = [showStatistics boolValue];
  
    NSNumber* autoenablesDefaultLighting = call.arguments[@"autoenablesDefaultLighting"];
    self.sceneView.autoenablesDefaultLighting = [autoenablesDefaultLighting boolValue];
    
    NSNumber* forceUserTapOnCenter = call.arguments[@"forceUserTapOnCenter"];
    self.forceUserTapOnCenter = [forceUserTapOnCenter boolValue];
  
    NSNumber* requestedPlaneDetection = call.arguments[@"planeDetection"];
    self.planeDetection = [self getPlaneFromNumber:[requestedPlaneDetection intValue]];
    
    if ([call.arguments[@"enableTapRecognizer"] boolValue]) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        [self.sceneView addGestureRecognizer:tapGestureRecognizer];
    }
    
    if ([call.arguments[@"enablePinchRecognizer"] boolValue]) {
        UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchFrom:)];
        [self.sceneView addGestureRecognizer:pinchGestureRecognizer];
        [pinchGestureRecognizer setDelegate:self.sceneView];
    }
    
    if ([call.arguments[@"enablePanRecognizer"] boolValue]) {
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
        [self.sceneView addGestureRecognizer:panGestureRecognizer];
        [panGestureRecognizer setDelegate:self.sceneView];
    }
    
    UIRotationGestureRecognizer *rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotationFrom:)];
    [self.sceneView addGestureRecognizer:rotationGestureRecognizer];
    [rotationGestureRecognizer setDelegate:self.sceneView];
    
    self.sceneView.debugOptions = [self getDebugOptions:call.arguments];
    
    _configuration = [self buildConfiguration: call.arguments];

    // [self.sceneView.session runWithConfiguration:[self configuration]];
    g_mSet = [[NSMutableSet alloc ]init];
    _nurieParams = [NSMutableDictionary dictionary];
    _referenceObjects = [NSMutableSet set];

    result(nil);
}

- (void)addImageRunWithConfigAndImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber* imageLengthNSNumber = call.arguments[@"imageLength"];
    double imageLength = [imageLengthNSNumber doubleValue];
    NSData* imageData = [((FlutterStandardTypedData*) call.arguments[@"imageBytes"]) data];
    NSString* imageNameNSString = call.arguments[@"imageName"];
    NSNumber* markerSizeMeterNSNumber = call.arguments[@"markerSizeMeter"];
    double markerSizeMeter = [markerSizeMeterNSNumber doubleValue];
    // NSLog(@"####### addImageRunWithConfigAndImage: imageLength=%@ imageName=%@ markerSizeMeter=%@", imageLength, imageNameNSString, markerSizeMeter);

    //   'imageBytes': bytes,
    //   'imageLength': lengthInBytes,
    //   'imageName': imageName,
    //   'markerSizeMeter': markerSizeMeter,

    UIImage* uiimage = [[UIImage alloc] initWithData:imageData];
    CGImageRef cgImage = [uiimage CGImage];
    
    ARReferenceImage *image = [[ARReferenceImage alloc] initWithCGImage:cgImage orientation:kCGImagePropertyOrientationUp physicalWidth:markerSizeMeter];
    
    image.name = imageNameNSString;
    [g_mSet addObject:image];

    result(nil);
}

- (void)addNurie:(FlutterMethodCall*)call result:(FlutterResult)result {
    UIImage* uiimage;
    if ([self isFileExists: call.arguments[@"filePath"]]) {
        uiimage = [[UIImage alloc] initWithContentsOfFile:call.arguments[@"filePath"]];
    } else {
        NSData* imageData = [((FlutterStandardTypedData*) call.arguments[@"imageBytes"]) data];
        uiimage = [[UIImage alloc] initWithData:imageData];
    }
    NSString* imageName = call.arguments[@"imageName"];
    NSNumber* markerSizeMeterNSNumber = call.arguments[@"markerSizeMeter"];
    double markerSizeMeter = [markerSizeMeterNSNumber doubleValue];
    NSNumber* widthScale = (call.arguments[@"widthScale"] != nil) ? call.arguments[@"widthScale"]: [NSNumber numberWithFloat:1.0f];
    NSNumber* heightScale = (call.arguments[@"heightScale"] != nil) ? call.arguments[@"heightScale"]: [NSNumber numberWithFloat:1.0f];
    NSNumber* xOffset = (call.arguments[@"xOffset"] != nil) ? call.arguments[@"xOffset"]: [NSNumber numberWithFloat:0.0f];
    NSNumber* yOffset = (call.arguments[@"yOffset"] != nil) ? call.arguments[@"yOffset"]: [NSNumber numberWithFloat:0.0f];
    
    _nurieParams[imageName] = [[NurieParams alloc] initWithName:imageName w:widthScale.floatValue h:heightScale.floatValue x:xOffset.floatValue y:yOffset.floatValue];

    CGImageRef cgImage = [uiimage CGImage];
    
    ARReferenceImage *image = [[ARReferenceImage alloc] initWithCGImage:cgImage orientation:kCGImagePropertyOrientationUp physicalWidth:markerSizeMeter];
    
    image.name = imageName;
    [g_mSet addObject:image];

    result(nil);
}

- (void) addReferenceObject:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([self isFileExists: call.arguments[@"path"]]) {
        NSURL* url = [NSURL fileURLWithPath:call.arguments[@"path"]];
        ARReferenceObject* object = [[ARReferenceObject alloc] initWithArchiveURL:url error:nil];
        if (call.arguments[@"name"] != nil) {
            object.name = call.arguments[@"name"];
        }
        [_referenceObjects addObject:object];
    }
    result(nil);
}

- (BOOL) isFileExists: (NSString*) path {
    if (path != nil) {
        NSFileManager* filemanager = [NSFileManager defaultManager];
        return [filemanager fileExistsAtPath: path];
    }
    return false;
}

- (SCNVector3) getScreenPoint:(SCNNode*) camera pose:(SCNNode*)pose x:(float)x z:(float)z {
    SCNVector3 t = SCNVector3Make(x, 0, z);
    return [_sceneView projectPoint: [pose convertPosition:t toNode:nil]];
}

- (UIImage*) affine:(UIImage*)input ul:(SCNVector3)ul ur:(SCNVector3)ur bl:(SCNVector3)bl br:(SCNVector3)br {
    CIImage *inCIImage = [[CIImage alloc] initWithCGImage:input.CGImage];
    CIFilter *perspective = [CIFilter filterWithName:@"CIPerspectiveCorrection"];
    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat height = input.size.height;
    [perspective setValue:[CIVector vectorWithX:ul.x * scale Y:height - ul.y * scale] forKey:@"inputTopLeft"];
    [perspective setValue:[CIVector vectorWithX:ur.x * scale Y:height - ur.y * scale] forKey:@"inputTopRight"];
    [perspective setValue:[CIVector vectorWithX:bl.x * scale Y:height - bl.y * scale] forKey:@"inputBottomLeft"];
    [perspective setValue:[CIVector vectorWithX:br.x * scale Y:height - br.y * scale] forKey:@"inputBottomRight"];
    [perspective setValue:inCIImage forKey:kCIInputImageKey];
    CIImage *outCIImage = perspective.outputImage;
    if (_ciContext == nil) {
        _ciContext = [CIContext context];
    }
    CGImageRef outCGImage = [_ciContext createCGImage:outCIImage fromRect:outCIImage.extent];
    UIImage *ret = [UIImage imageWithCGImage:outCGImage scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(outCGImage);
    return ret;
}

- (void)startWorldTrackingSessionWithImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber* runOpts = call.arguments[@"runOpts"];
    NSLog(@"####### startWorldTrackingSessionWithImage: runOpts=%@", runOpts);

    // ARWorldTrackingConfigurationのみ
    ARWorldTrackingConfiguration* configuration = _configuration;
    configuration.detectionImages = g_mSet;
    configuration.detectionObjects = _referenceObjects;
    
    [self.sceneView.session runWithConfiguration:[self configuration] options:runOpts];
}

- (ARConfiguration*) buildConfiguration: (NSDictionary*)params {
    int configurationType = [params[@"configuration"] intValue];
    ARConfiguration* _configuration;
    
    if (configurationType == 0) {
        if (ARWorldTrackingConfiguration.isSupported) {
            ARWorldTrackingConfiguration* worldTrackingConfiguration = [ARWorldTrackingConfiguration new];
            worldTrackingConfiguration.planeDetection = self.planeDetection;
            // NSString* detectionImages = params[@"detectionImagesGroupName"];
            // if ([detectionImages isKindOfClass:[NSString class]]) {
            //     worldTrackingConfiguration.detectionImages = [ARReferenceImage referenceImagesInGroupNamed:detectionImages bundle:nil];
            // }
            NSNumber* autoFocusEnabled = params[@"autoFocusEnabled"];
            worldTrackingConfiguration.autoFocusEnabled = [autoFocusEnabled boolValue];

            NSNumber* maximumNumberOfTrackedImages = params[@"maximumNumberOfTrackedImages"];
            worldTrackingConfiguration.maximumNumberOfTrackedImages = [maximumNumberOfTrackedImages intValue];

            _configuration = worldTrackingConfiguration;
        }
    // } else if (configurationType == 1) {
    //     if (ARFaceTrackingConfiguration.isSupported) {
    //         ARFaceTrackingConfiguration* faceTrackingConfiguration = [ARFaceTrackingConfiguration new];
    //         _configuration = faceTrackingConfiguration;
    //     }
    // } else if (configurationType == 2) {
    //     if (ARImageTrackingConfiguration.isSupported) {
    //         ARImageTrackingConfiguration* imageTrackingConfiguration = [ARImageTrackingConfiguration new];
    //         NSString* trackingImages = params[@"trackingImagesGroupName"];
    //         if ([trackingImages isKindOfClass:[NSString class]]) {
    //             imageTrackingConfiguration.trackingImages = [ARReferenceImage referenceImagesInGroupNamed:trackingImages bundle:nil];
    //         }
    //         _configuration = imageTrackingConfiguration;
    //     }
    }
    NSNumber* worldAlignment = params[@"worldAlignment"];
    _configuration.worldAlignment = [self getWorldAlignmentFromNumber:[worldAlignment intValue]];

    NSNumber* lightEstimationEnabled = params[@"lightEstimationEnabled"];
    _configuration.lightEstimationEnabled = [lightEstimationEnabled boolValue];

    return _configuration;
}

- (void)onAddNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary* geometryArguments = call.arguments[@"geometry"];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:geometryArguments withDevice: _sceneView.device];
    [self addNodeToSceneWithGeometry:geometry andCall:call andResult:result];
}

- (void)onRemoveNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [_objectsParent childNodeWithName:nodeName recursively:YES];
    [node removeFromParentNode];
    result(nil);
}

- (void)onGetNodeBoundingBox:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary* geometryArguments = call.arguments[@"geometry"];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:geometryArguments withDevice: _sceneView.device];
    SCNNode* node = [self getNodeWithGeometry:geometry fromDict:call.arguments];
    SCNVector3 minVector, maxVector;
    [node getBoundingBoxMin:&minVector max:&maxVector];
    
    result(@[[CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(minVector)],
             [CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(maxVector)]]
           );
}

#pragma mark - Lazy loads

-(ARConfiguration *)configuration {
    return _configuration;
}

#pragma mark - Scene tap event
- (void) handleTapFrom: (UITapGestureRecognizer *)recognizer
{
    [self debugNodeTree:nil level:0];
    [TransformableNode setSelectedNode:nil];
    
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    ARSCNView* sceneView = (ARSCNView *)recognizer.view;
    CGPoint touchLocation = self.forceUserTapOnCenter
        ? self.sceneView.center
        : [recognizer locationInView:sceneView];
    NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
    if ([hitResults count] != 0) {
        for(SCNHitTestResult *n in hitResults) {
            SCNNode *node = [self getParentIfReferenceChild: n.node];
            if (node.name != nil) {
                [_channel invokeMethod: @"onNodeTap" arguments: node.name];
                
                SCNNode* transformableNode = nil;
                if ([node isKindOfClass:[TransformableNode class]]) {
                    transformableNode = node;
                } else if ([node.parentNode isKindOfClass:[TransformableNode class]]) {
                    transformableNode = node.parentNode;
                }
                if (transformableNode != nil) {
                    [TransformableNode setSelectedNode:transformableNode];
                }
                
                return; // consume event here
            }
        }
    }
    [TransformableNode clearSelected];

    NSArray<ARHitTestResult *> *arHitResults = [sceneView hitTest:touchLocation types: 0
//                                                + ARHitTestResultTypeFeaturePoint
//                                                + ARHitTestResultTypeEstimatedHorizontalPlane
//                                                + ARHitTestResultTypeEstimatedVerticalPlane
//                                                + ARHitTestResultTypeExistingPlane
                                                + ARHitTestResultTypeExistingPlaneUsingExtent
                                                + ARHitTestResultTypeExistingPlaneUsingGeometry
                                                ];
    ARHitTestResult* tapped = nil;
    if ([arHitResults count] != 0) {
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[arHitResults count]];
        for (ARHitTestResult* r in arHitResults) {
            [results addObject:[self getDictFromHitResult:r]];
            if (tapped == nil) {
                tapped = r;
            }
        }
        [_channel invokeMethod: @"onPlaneTap" arguments: results];
    }
    _lastTappedPlane = tapped;
}

- (void) handlePinchFrom: (UIPinchGestureRecognizer *) recognizer
{
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        CGFloat scale = recognizer.scale;
        
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[hitResults count]];
        if ([TransformableNode pinch:scale]) {
            TransformableNode *node = [TransformableNode selectedNode];
            [results addObject:@{@"name" : node.name, @"scale" : @(scale)}];
        } else {
            for (SCNHitTestResult* r in hitResults) {
                SCNNode *node = [self getParentIfReferenceChild: r.node];
                if (node.name != nil) {
                    [results addObject:@{@"name" : node.name, @"scale" : @(scale)}];
                    break;
                }
            }
        }

        if ([results count] != 0) {
            [_channel invokeMethod: @"onNodePinch" arguments: results];
        }
        recognizer.scale = 1;
    }
}

- (void) handlePanFrom: (UIPanGestureRecognizer *) recognizer
{
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        TransformableNode* target;
        for (SCNHitTestResult* r in hitResults) {
            SCNNode* node = [self getParentIfReferenceChild: r.node];
            if ([node isKindOfClass:[TransformableNode class]]) {
                target = (TransformableNode*)node;
                break;
            } else if ([node.parentNode isKindOfClass:[TransformableNode class]]) {
                target = (TransformableNode*)node.parentNode;
                break;
            }
        }
        if (target != nil) {
            [TransformableNode setSelectedNode:target];
            target.hasControlPriority = true;
        }
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        CGPoint translation = [recognizer translationInView:sceneView];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[hitResults count]];
        TransformableNode* selected = TransformableNode.selectedNode;
        if (selected != nil && selected.hasControlPriority) {
            [results addObject:@{@"name" : selected.childNodes.firstObject.name, @"x" : @(translation.x), @"y":@(translation.y)}];
            NSArray<ARHitTestResult *> *arHitResults = [sceneView hitTest:touchLocation types: 0
                                                        + ARHitTestResultTypeExistingPlaneUsingExtent
                                                        + ARHitTestResultTypeExistingPlaneUsingGeometry
                                                        ];
            if ([arHitResults count] != 0) {
                for (ARHitTestResult* r in arHitResults) {
                    simd_float4 pos = r.worldTransform.columns[3];
                    selected.position = SCNVector3Make(pos.x, pos.y, pos.z);
                    break;
                }
            }
        } else {
            for (SCNHitTestResult* r in hitResults) {
                SCNNode *node = [self getParentIfReferenceChild: r.node];
                if (node.name != nil) {
                    [results addObject:@{@"name" : node.name, @"x" : @(translation.x), @"y":@(translation.y)}];
                    break;
                }
            }
        }
        if ([results count] != 0) {
            [_channel invokeMethod: @"onNodePan" arguments: results];
        }
    } else {
        [TransformableNode selectedNode].hasControlPriority = false;
    }
}

- (void) handleRotationFrom: (UIRotationGestureRecognizer *) recognizer
{
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [TransformableNode startRotate];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        float rotation = [recognizer rotation];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[hitResults count]];
        if ([TransformableNode rotation: rotation]) {
            TransformableNode* node = [TransformableNode selectedNode];
            [results addObject:@{@"name" : node.name, @"rotation" : @(rotation)}];
        } else {
            for (SCNHitTestResult* r in hitResults) {
                SCNNode *node = [self getParentIfReferenceChild: r.node];
                if (node.name != nil) {
                    [results addObject:@{@"name" : node.name, @"rotation" : @(rotation)}];
                    break;
                }
            }
        }
        if ([results count] != 0) {
            [_channel invokeMethod: @"onNodeRotate" arguments: results];
        }
    }
}

#pragma mark - Parameters
- (void) updatePosition:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    node.position = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateRotation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    node.rotation = [DecodableUtils parseVector4:call.arguments];
    result(nil);
}

- (void) updateEulerAngles:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    node.eulerAngles = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateScale:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    node.scale = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateIsHidden:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];

    if ([call.arguments[@"isHidden"] boolValue]) {
        node.hidden = YES;
    } else {
        node.hidden = NO;
    }

    NSLog(@"node.isHidden:%d",node.isHidden);
    
    result(nil);
}

- (void) updateIsPlay:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];

    NSLog(@"###### node.geometry.contents=%@", node.geometry.firstMaterial.diffuse.contents );
    if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[SKScene class]]){
        SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
        for (SKVideoNode *videoNode in scene.children){
            if ([call.arguments[@"isPlay"] boolValue]){
                videoNode.play;
            }else{
                videoNode.pause;
            }
        }
    }
    if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[VideoView class]]){
        VideoView *videoView = node.geometry.firstMaterial.diffuse.contents;
        if ([call.arguments[@"isPlay"] boolValue]) {
            [videoView play];
        } else {
            [videoView pause];
        }
    }
    
    result(nil);
}

- (void) updateSingleProperty:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    
    NSString* keyProperty = call.arguments[@"keyProperty"];
    id object = [node valueForKey:keyProperty];
    
    [object setValue:call.arguments[@"propertyValue"] forKey:call.arguments[@"propertyName"]];
    result(nil);
}

- (void) updateMaterials:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [_objectsParent childNodeWithName:name recursively:YES];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:call.arguments withDevice: _sceneView.device];
    node.geometry = geometry;
    result(nil);
}

// - (void) updateFaceGeometry:(FlutterMethodCall*)call andResult:(FlutterResult)result{
//     NSString* name = call.arguments[@"name"];
//     SCNNode* node = [self.sceneView.scene.rootNode childNodeWithName:name recursively:YES];
//     ARSCNFaceGeometry* geometry = (ARSCNFaceGeometry*)node.geometry;
//     ARFaceAnchor* faceAnchor = [self findAnchor:call.arguments[@"fromAnchorId"] inArray:self.sceneView.session.currentFrame.anchors];
    
//     [geometry updateFromFaceGeometry:faceAnchor.geometry];
    
//     result(nil);
// }

// -(ARFaceAnchor*)findAnchor:(NSString*)searchUUID inArray:(NSArray<ARAnchor *>*)array{
//     for (ARAnchor* obj in array){
//         if([[obj.identifier UUIDString] isEqualToString:searchUUID])
//             return (ARFaceAnchor*)obj;
//     }
//     return NULL;
// }

- (void) onGetLightEstimate:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    ARFrame* frame = self.sceneView.session.currentFrame;
    if (frame != nil && frame.lightEstimate != nil) {
        NSDictionary* res = @{
                              @"ambientIntensity": @(frame.lightEstimate.ambientIntensity),
                              @"ambientColorTemperature": @(frame.lightEstimate.ambientColorTemperature)
                              };
        result(res);
    }
    result(nil);
}

- (void) onProjectPoint:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    SCNVector3 point =  [DecodableUtils parseVector3:call.arguments[@"point"]];
    SCNVector3 projectedPoint = [_sceneView projectPoint:point];
    NSString* coded = [CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(projectedPoint)];
    result(coded);
}

- (void) onCameraProjectionMatrix:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* coded = [CodableUtils convertSimdFloat4x4ToString:_sceneView.session.currentFrame.camera.projectionMatrix];
    result(coded);
}

- (void) onStartAnimation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* key = call.arguments[@"key"];
    NSString* sceneName = call.arguments[@"sceneName"];
    NSString* animationIdentifier = call.arguments[@"animationIdentifier"];
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [_objectsParent childNodeWithName:nodeName recursively:YES];
    float repeatCount = [call.arguments[@"repeatCount"] floatValue];
    if (repeatCount < 0) {
        repeatCount = HUGE_VALF;
    } else {
        repeatCount ++;
    }

    NSURL* sceneURL = [[NSURL alloc] initFileURLWithPath: sceneName];
    SCNSceneSource* sceneSource = [SCNSceneSource sceneSourceWithURL:sceneURL options:nil];

    CAAnimation* animationObject = [sceneSource entryWithIdentifier:animationIdentifier withClass:[CAAnimation self]];
    animationObject.repeatCount = repeatCount;
    animationObject.fadeInDuration = 1;
    animationObject.fadeOutDuration = 0.5;
    [node addAnimation:animationObject forKey:key];
    
    result(nil);
}

- (void) onStopAnimation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* key = call.arguments[@"key"];
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [_objectsParent childNodeWithName:nodeName recursively:YES];
    [node removeAnimationForKey:key blendOutDuration:0.5];
    result(nil);
}


- (void) screenCapture:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    UIImage *image = [_sceneView snapshot];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(onCaptureImageSaved:didFinishSavingWithError:contextInfo:), nil);
    result(nil);
}

- (void) toggleScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    NSString* path = call.arguments[@"path"];
    NSNumber* useAudio = call.arguments[@"useAudio"];
    if (path != nil) {
        [_videoRecorder toggleRecord: path useAudio:[useAudio intValue]];
    }
    result(nil);
}

- (void)startScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    NSString* path = call.arguments[@"path"];
    NSNumber* useAudio = call.arguments[@"useAudio"];
    if (path != nil) {
        [_videoRecorder startRecord: path useAudio:[useAudio intValue]];
    }
    result(nil);
}

- (void)stopScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    [_videoRecorder stopRecord];
    result(nil);
}

- (void) onCaptureImageSaved: (UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSLog(@"capture image save failure %@", error);
    } else {
        NSLog(@"capture image saved");
    }
}


- (BOOL)addNurieObject:(ARAnchor *)anchor node:(SCNNode *)node {
    if ([anchor isMemberOfClass:[ARImageAnchor class]]) {
        ARImageAnchor *image = (ARImageAnchor*)anchor;
        NSString* imageName = image.referenceImage.name;
        if ([_nurieParams.allKeys containsObject:imageName]) {
            return true;
        }
    }
    return false;
}

- (void) setNodeToObjectsParent:(SCNNode *)node {
    [node removeFromParentNode];
    [_objectsParent addChildNode:node];
}

- (BOOL)checkMarkerNurie:(ARAnchor*) anchor node:(SCNNode *)node {
    if (_nurieFindingMode && [anchor isMemberOfClass:[ARImageAnchor class]]) {
        ARImageAnchor *image = (ARImageAnchor*)anchor;
        NSString* imageName = image.referenceImage.name;
        if ((_targetNurieMarker == nil || [_targetNurieMarker.name isEqualToString:imageName]) && [_nurieParams.allKeys containsObject:imageName]) {
            NurieParams* nurie = _nurieParams[imageName];
            SCNNode* cameraNode = _sceneView.pointOfView;
            
            float halfTextureWidth = image.referenceImage.physicalSize.width * nurie.widthScale / 2;
            float halfTextureHeight = image.referenceImage.physicalSize.height * nurie.heightScale / 2;
            float moveX = image.referenceImage.physicalSize.width * nurie.xOffset;
            float moveY = -image.referenceImage.physicalSize.height * nurie.yOffset;
            
            SCNVector3 ul = [self getScreenPoint:cameraNode pose:node x:-halfTextureWidth + moveX z:-halfTextureHeight + moveY];
            SCNVector3 ur = [self getScreenPoint:cameraNode pose:node x:halfTextureWidth + moveX z:-halfTextureHeight + moveY];
            SCNVector3 bl = [self getScreenPoint:cameraNode pose:node x:-halfTextureWidth + moveX z:halfTextureHeight + moveY];
            SCNVector3 br = [self getScreenPoint:cameraNode pose:node x:halfTextureWidth + moveX z:halfTextureHeight + moveY];
            SCNVector3 arr[] = {ul, ur, bl, br};

            if ([self validMarkerCorners:_viewWidth height:_viewHeight corners:arr]) {
                @autoreleasepool {
                    nurie.image = nil;
                    UIImage* input = [_sceneView snapshot];
                    UIImage *uiImage = [self affine:input ul:ul ur:ur bl:bl br:br];
                    nurie.image = uiImage;
                    [_objectsParent setHidden:false];
                    [self startFindingNurieMarker:false];
                    NSLog(@"**** captured");
                }
            }
            return true;
        }
    }
    return false;
}

- (BOOL) validMarkerCorners:(int)width height:(int)height corners:(SCNVector3[])corners {
    BOOL succeed = true;
    for(int i = 0; i < 4; i++) {
        SCNVector3 corner = corners[i];
        float prevX = prevMarkerCorners[i * 2];
        float prevY = prevMarkerCorners[i * 2 + 1];
        if (succeed && corner.x < 0 || corner.x > width || corner.y < 0 || corner.y > height ||
            abs(corner.x - prevX) > thresholdMarkerCorners || abs(corner.y - prevY) > thresholdMarkerCorners) {
            succeed = false;
            _markerGazeStartTime = 0;
        }
    
        prevMarkerCorners[i * 2] = corner.x;
        prevMarkerCorners[i * 2 + 1] = corner.y;
    }
    if (succeed) {
        if (_markerGazeStartTime == 0) {
            _markerGazeStartTime = [NSDate now];
            [_objectsParent setHidden:true];
        } else if ([_markerGazeStartTime timeIntervalSinceNow] <= -markerGazingDuration) {
            _markerGazeStartTime = 0;
            return true;
        } else {
        }
    } else {
        [_objectsParent setHidden:false];
    }
    return false;
}

- (void) applyNurieTexture:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* nurieStr = call.arguments[@"nurie"];
    NSString* nodeName = call.arguments[@"nodeName"];
    if (nurieStr != nil) {
        NurieParams* nurieParam = _nurieParams[nurieStr];
        SCNNode* node = [_objectsParent childNodeWithName:nodeName recursively:YES];
        if (nurieParam != nil && nurieParam.image != nil && node != nil) {
            UIImage* texture = nurieParam.image;
            [self setTexture:node texture:texture];
        }
    }
    result(nil);
}

- (void) setTexture:(SCNNode*)node texture:(UIImage*)texture {
    for (SCNMaterial* mat in node.geometry.materials) {
        [mat.diffuse setContents: texture];
    }
    for (SCNNode* childNode in node.childNodes){
        [self setTexture:childNode texture:texture];
    }
}

- (void) findNurieMarker:(FlutterMethodCall*)call result:(FlutterResult)result {
    BOOL isStart = call.arguments[@"isStart"];
    NSString* name = call.arguments[@"nurie"];
    if (name != nil) {
        _targetNurieMarker = [_nurieParams objectForKey:name];
    } else {
        _targetNurieMarker = nil;
    }
    [self startFindingNurieMarker:isStart];
    result(nil);
}

- (void) startFindingNurieMarker:(BOOL)isStart {
    if (_nurieFindingMode != isStart) {
        _nurieFindingMode = isStart;
        [_channel invokeMethod: @"nurieMarkerModeChanged" arguments: @{@"isStart" : @(isStart)}];
    }
}

- (void) addTransformableNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    // need plane detection
    if (_lastTappedPlane == nil) return;
    NSString* transformName = call.arguments[@"transformName"];
    NSDictionary* params = call.arguments[@"node"];
    if (transformName == nil || params == nil) return;
    SCNGeometry* geometry = [GeometryBuilder createGeometry:params[@"geometry"] withDevice: _sceneView.device];
    SCNNode* childNode = [self getNodeWithGeometry:geometry fromDict:params];
    TransformableNode* transformableNode = [[TransformableNode alloc] initWithPlane:_lastTappedPlane node:childNode];
    transformableNode.name = transformName;
    [_objectsParent addChildNode:transformableNode];
}

#pragma mark - Utils
-(ARPlaneDetection) getPlaneFromNumber: (int) number {
  if (number == 1) {
    return ARPlaneDetectionHorizontal;
  } else if (number == 2) {
    return ARPlaneDetectionVertical;
  } else if (number == 3) {
      return ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
  }
  return ARPlaneDetectionNone;
}

-(ARWorldAlignment) getWorldAlignmentFromNumber: (int) number {
    if (number == 0) {
        return ARWorldAlignmentGravity;
    } else if (number == 1) {
        return ARWorldAlignmentGravityAndHeading;
    }
    return ARWorldAlignmentCamera;
}

- (SCNNode *) getNodeWithGeometry:(SCNGeometry *)geometry fromDict:(NSDictionary *)dict {
    SCNNode* node;
    NSLog(@"**** getNodeWithGeometry");
    if ([dict[@"dartType"] isEqualToString:@"ARKitNode"]) {
        node = [SCNNode nodeWithGeometry:geometry];
    } else if ([dict[@"dartType"] isEqualToString:@"ARKitReferenceNode"]) {
        NSString* localPath = dict[@"object3DFileName"];
        NSURL* referenceURL = [[NSURL alloc] initFileURLWithPath: localPath];
        node = [SCNNode node];
        SCNScene *scene = [SCNScene sceneWithURL: referenceURL options: nil error: nil];
        for (SCNNode* childNode in scene.rootNode.childNodes){
            [self renameReferenceNodes:childNode];
            [node addChildNode:childNode];
        }
    } else if([dict[@"dartType"] isEqualToString:@"ARKitObjectNode"]){
        node = [SCNNode nodeWithGeometry:geometry];
        NSURL *localPath = [[NSURL alloc] initFileURLWithPath: dict[@"localPath"]];
        SCNScene *scene = [SCNScene sceneWithURL: localPath options: nil error: nil];
        for (id childNode in scene.rootNode.childNodes){
            [node addChildNode:childNode];
        }
    } else if([dict[@"dartType"] isEqualToString:@"ARKitVideoNode"]){
        //TODO VideoNode作成
        node = [SCNNode nodeWithGeometry:geometry];
    } else {
        return nil;
    }
    node.position = [DecodableUtils parseVector3:dict[@"position"]];
    
    if (dict[@"scale"] != nil) {
        node.scale = [DecodableUtils parseVector3:dict[@"scale"]];
    }
    if (dict[@"rotation"] != nil) {
        node.rotation = [DecodableUtils parseVector4:dict[@"rotation"]];
    }
    if (dict[@"eulerAngles"] != nil) {
        node.eulerAngles = [DecodableUtils parseVector3:dict[@"eulerAngles"]];
    }
    if (dict[@"name"] != nil) {
        node.name = dict[@"name"];
    }
    if (dict[@"physicsBody"] != nil) {
        NSDictionary *physics = dict[@"physicsBody"];
        node.physicsBody = [self getPhysicsBodyFromDict:physics];
    }
    if (dict[@"light"] != nil) {
        NSDictionary *light = dict[@"light"];
        node.light = [self getLightFromDict: light];
    }
    if (dict[@"isHidden"] != nil) {
        if ([dict[@"isHidden"] boolValue]) {
            node.hidden = YES;
        } else {
            node.hidden = NO;
        }
    }
    if (dict[@"isPlay"] != nil){
        //TODO
        // SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
        // for (SKVideoNode *videoNode in scene.children){
        //     if ([dict[@"isPlay"] boolValue]){
        //         NSLog(@"###### videoPlay=%@", videoNode );
        //         videoNode.play;
        //     }else{
        //         videoNode.pause;
        //     }
        // }
        if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[SKScene class]]){
            SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
            for (SKVideoNode *videoNode in scene.children){
                if ([dict[@"isPlay"] boolValue]){
                    videoNode.play;
                }else{
                    videoNode.pause;
                }
            }
        }
        if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[VideoView class]]){
            VideoView *videoView = node.geometry.firstMaterial.diffuse.contents;
            if ([dict[@"isPlay"] boolValue]) {
                [videoView play];
            } else {
                [videoView pause];
            }
        }
    }
    
    NSNumber* renderingOrder = dict[@"renderingOrder"];
    node.renderingOrder = [renderingOrder integerValue];
    
    return node;
}

- (SCNPhysicsBody *) getPhysicsBodyFromDict:(NSDictionary *)dict {
    NSNumber* type = dict[@"type"];
    
    SCNPhysicsShape* shape;
    if (dict[@"shape"] != nil) {
        NSDictionary* shapeDict = dict[@"shape"];
        if (shapeDict[@"geometry"] != nil) {
            shape = [SCNPhysicsShape shapeWithGeometry:[GeometryBuilder createGeometry:shapeDict[@"geometry"] withDevice:_sceneView.device] options:nil];
        }
    }
    
    SCNPhysicsBody* physicsBody = [SCNPhysicsBody bodyWithType:[type intValue] shape:shape];
    if (dict[@"categoryBitMask"] != nil) {
        NSNumber* mask = dict[@"categoryBitMask"];
        physicsBody.categoryBitMask = [mask unsignedIntegerValue];
    }
    
    return physicsBody;
}

- (SCNLight *) getLightFromDict:(NSDictionary *)dict {
    SCNLight* light = [SCNLight light];
    if (dict[@"type"] != nil) {
        SCNLightType lightType;
        int type = [dict[@"type"] intValue];
        switch (type) {
            case 0:
                lightType = SCNLightTypeAmbient;
                break;
            case 1:
                lightType = SCNLightTypeOmni;
                break;
            case 2:
                lightType =SCNLightTypeDirectional;
                break;
            case 3:
                lightType =SCNLightTypeSpot;
                break;
            case 4:
                lightType =SCNLightTypeIES;
                break;
            case 5:
                lightType =SCNLightTypeProbe;
                break;
            default:
                break;
        }
        light.type = lightType;
    }
    if (dict[@"temperature"] != nil) {
        NSNumber* temperature = dict[@"temperature"];
        light.temperature = [temperature floatValue];
    }
    if (dict[@"intensity"] != nil) {
        NSNumber* intensity = dict[@"intensity"];
        light.intensity = [intensity floatValue];
    }
    if (dict[@"spotInnerAngle"] != nil) {
        NSNumber* spotInnerAngle = dict[@"spotInnerAngle"];
        light.spotInnerAngle = [spotInnerAngle floatValue];
    }
    if (dict[@"spotOuterAngle"] != nil) {
        NSNumber* spotOuterAngle = dict[@"spotOuterAngle"];
        light.spotOuterAngle = [spotOuterAngle floatValue];
    }
    if (dict[@"color"] != nil) {
        NSNumber* color = dict[@"color"];
        light.color = [UIColor fromRGB: [color integerValue]];
    }
    return light;
}

- (void) addNodeToSceneWithGeometry:(SCNGeometry*)geometry andCall: (FlutterMethodCall*)call andResult:(FlutterResult)result{
    SCNNode* node = [self getNodeWithGeometry:geometry fromDict:call.arguments];
    if (call.arguments[@"parentNodeName"] != nil) {
        SCNNode *parentNode = [_objectsParent childNodeWithName:call.arguments[@"parentNodeName"] recursively:YES];
        [parentNode addChildNode:node];
    } else {
        [_objectsParent addChildNode:node];
    }
    result(nil);
}

- (SCNDebugOptions) getDebugOptions:(NSDictionary*)arguments{
    SCNDebugOptions debugOptions = SCNDebugOptionNone;
    if ([arguments[@"showFeaturePoints"] boolValue]) {
        debugOptions += ARSCNDebugOptionShowFeaturePoints;
    }
    if ([arguments[@"showWorldOrigin"] boolValue]) {
        debugOptions += ARSCNDebugOptionShowWorldOrigin;
    }
    return debugOptions;
}

- (NSDictionary*) getDictFromHitResult: (ARHitTestResult*) result {
    NSMutableDictionary* dict = [@{
             @"type": @(result.type),
             @"distance": @(result.distance),
             @"localTransform": [CodableUtils convertSimdFloat4x4ToString:result.localTransform],
             @"worldTransform": [CodableUtils convertSimdFloat4x4ToString:result.worldTransform]
             } mutableCopy];
    if (result.anchor != nil) {
        [dict setValue:[CodableUtils convertARAnchorToDictionary:result.anchor] forKey:@"anchor"];
    }
    return dict;
}

-(void) renameReferenceNodes:(SCNNode*) node {
    node.name = REFERENCE_CHILD_NODE;
    for(SCNNode* child in node.childNodes) {
        [self renameReferenceNodes:child];
    }
}

- (nullable SCNNode*) getParentIfReferenceChild:(SCNNode*) node {
    SCNNode* ret = node;
    if (ret.name == REFERENCE_CHILD_NODE) {
        ret = [self getParentIfReferenceChild:ret.parentNode];
    }
    return ret;
}

- (void) debugNodeTree:(nullable SCNNode*)node level:(int)level{
    if (node == nil) node = _sceneView.scene.rootNode;
    for(SCNNode* child in node.childNodes) {
        NSString* name = child.name;
        if (name == nil) name = @"null";
        SCNVector3 pos = child.position;
        SCNVector3 scl = child.scale;
        NSLog(@"**** [%d] %@ - pos:[%f, %f, %f] scale:[%f, %f, %f] %@", level, name,
              pos.x, pos.y, pos.z,
              scl.x, scl.y, scl.z,
              [child class]);
        [self debugNodeTree:child level:level + 1];
    }
}

- (void) recStateChanged:(BOOL)isRecording {
    [_channel invokeMethod: @"onRecStatusChanged" arguments: @{@"isRecording": @(isRecording)}];
}

@end

@implementation NurieParams

- (id) initWithName:(NSString *)name w:(float)w h:(float)h x:(float)x y:(float)y {
    if (self = [super init]) {
        _name = name;
        _widthScale = w;
        _heightScale = h;
        _xOffset = x;
        _yOffset = y;
    }
    return self;
}

@end

static TransformableNode* selectedNode = nil;
static SCNNode* selectedIcon = nil;
static const CGFloat TRANSFORMABLE_NODE_MIN_SCALE = 0.5;
static const CGFloat TRANSFORMABLE_NODE_MAX_SCALE = 2.0;

@interface TransformableNode()
@property CGFloat rotateStartDegree;
@end

@implementation TransformableNode

- (nonnull instancetype)initWithPlane:(nonnull ARHitTestResult*)plane node:(SCNNode *)node{
    if (self = [super init]) {
        _anchor = plane.anchor;
        simd_float4 pos = plane.worldTransform.columns[3];
        self.position = SCNVector3Make(pos.x, pos.y, pos.z);
        [self addChildNode:node];
    }
    return self;

}

+ (TransformableNode*) selectedNode {
    return selectedNode;
}

+ (void) createSelectedIcon {
    SCNGeometry* geometry = [SCNCylinder cylinderWithRadius:0.03f height:0.003f];
    SCNMaterial* material = [SCNMaterial material];
    SCNMaterialProperty* property = [material valueForKey:@"diffuse"];
    property.contents = UIColor.redColor;
    [geometry setFirstMaterial: material];
    selectedIcon = [SCNNode nodeWithGeometry:geometry];
    [selectedIcon setName:@"SELECTED_ICON"];
}

+ (void) setSelectedNode: (TransformableNode*) node {
    if (selectedNode == node) return; // do nothing
    if (selectedIcon == nil) {
        [TransformableNode createSelectedIcon];
    }
    
    if (selectedIcon.parentNode != nil) {
        [selectedIcon removeFromParentNode];
    }
    if (node != nil) {
        [node addChildNode:selectedIcon];
    }
    
    selectedNode = node;
}

+ (void) clearSelected {
    if (selectedIcon != nil && selectedIcon.parentNode != nil) {
        [selectedIcon removeFromParentNode];
    }
    selectedNode = nil;
}

+ (BOOL) pinch: (CGFloat) scale {
    if (selectedNode != nil) {
        CGFloat destScaleX = selectedNode.scale.x * scale;
        if (destScaleX < TRANSFORMABLE_NODE_MIN_SCALE) {
            [selectedNode setScale:SCNVector3Make(TRANSFORMABLE_NODE_MIN_SCALE, TRANSFORMABLE_NODE_MIN_SCALE, TRANSFORMABLE_NODE_MIN_SCALE)];
        } else if (destScaleX > TRANSFORMABLE_NODE_MAX_SCALE) {
            [selectedNode setScale:SCNVector3Make(TRANSFORMABLE_NODE_MAX_SCALE, TRANSFORMABLE_NODE_MAX_SCALE, TRANSFORMABLE_NODE_MAX_SCALE)];
        } else {
            [selectedNode setScale:SCNVector3Make(selectedNode.scale.x * scale, selectedNode.scale.y * scale, selectedNode.scale.z * scale)];
        }
        return true;
    }
    return false;
}

+ (BOOL) rotation: (CGFloat) rotation {
    if (selectedNode != nil) {
        selectedNode.eulerAngles = SCNVector3Make(0, selectedNode.rotateStartDegree -rotation, 0);
        return true;
    }
    return false;
}

+ (BOOL) startRotate {
    if (selectedNode != nil) {
        selectedNode.rotateStartDegree = selectedNode.eulerAngles.y;
        return true;
    }
    return false;
}

@end
