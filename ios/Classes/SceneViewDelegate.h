@import ARKit;
@import Flutter;
#import "FlutterArkit.h"

@interface SceneViewDelegate: NSObject<ARSCNViewDelegate>
- (instancetype)initWithChannel:(FlutterMethodChannel*) channel controller:(FlutterArkitController*) controller;
@end
