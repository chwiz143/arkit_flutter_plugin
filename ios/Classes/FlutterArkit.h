@import Flutter;
@import ARKit;
@import SceneKit;

#import "VideoRecorder.h"
#import "GeometryBuilder.h"

API_AVAILABLE(ios(11.3))
@interface FlutterArkitController : NSObject <FlutterPlatformView, VideoRecorderDelegate>

- (nonnull instancetype)initWithWithFrame:(CGRect)frame
                           viewIdentifier:(int64_t)viewId
                                arguments:(id _Nullable)args
                          binaryMessenger:(nonnull NSObject<FlutterBinaryMessenger>*)messenger;

- (nonnull UIView*)view;
- (BOOL)addNurieObject:(nonnull ARAnchor*) anchor node: (nonnull SCNNode*) node;
- (BOOL)checkMarkerNurie:(nonnull ARAnchor*) anchor node: (nonnull SCNNode*) node;
- (void)setNodeToObjectsParent: (nonnull SCNNode*) node;
- (void)updateEachFrame;
- (void)addVideoView:(NSString*) name videoView:(NSObject*) videoView;

@property (readonly, nonatomic, strong, nonnull) ARSCNView *sceneView;
@property (readonly, nonatomic, strong, nonnull) ARConfiguration *configuration;

@end

@interface FlutterArkitFactory : NSObject <FlutterPlatformViewFactory>
- (nonnull instancetype)initWithMessenger:(nonnull NSObject<FlutterBinaryMessenger>*)messenger;
@end

@interface NurieParams: NSObject

- (nonnull id) initWithName:(nonnull NSString*)name w:(float)w h:(float)h x:(float)x y:(float)y;

@property (readonly) NSString* _Nonnull name;
@property (readonly) float widthScale;
@property (readonly) float heightScale;
@property (readonly) float xOffset;
@property (readonly) float yOffset;

@property UIImage* _Nullable image;

@end

@interface TransformableNode : SCNNode

@property (class, nullable) TransformableNode* selectedNode;
@property BOOL hasControlPriority;

+ (TransformableNode* _Nullable) selectedNode;
+ (void) setSelectedNode: (TransformableNode* _Nullable) node;
+ (void) clearSelected;

+ (BOOL) pinch: (CGFloat) scale;
+ (BOOL) rotation: (CGFloat) rotation;
+ (BOOL) startRotate;


- (nonnull instancetype)initWithPlane:(nonnull ARHitTestResult*)plane node:(SCNNode*) node;

@property ARAnchor* _Nonnull anchor;

@end

@interface VideoNode : SCNNode

@property BOOL centralizeOnLostTarget;
@property float margin;
@property float duration;

@property SCNNode* _Nonnull originalParentNode;
@property SCNVector3 originalPosition;
@property SCNVector3 originalEulerAngles;
@property SCNVector3 originalScale;

+ (VideoNode* _Nonnull)nodeWithGeometry:(nullable SCNGeometry *)geometry arguments: (NSDictionary*)dict;

- (void) play;
- (void) pause;

- (void) saveCurrent;
- (BOOL) centralize:(BOOL)lostTarget sceneView:(SCNView*)sceneView fixedLayer:(SCNNode*) fixedMovieLayer;
- (VideoView*) getVideoView;
- (void) dispose;

@end
