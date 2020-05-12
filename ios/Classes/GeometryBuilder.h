@import SceneKit;
@import ARKit;
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface GeometryBuilder : NSObject

+ (SCNGeometry *) createGeometry:(NSDictionary *) geometryArguments withDevice: (NSObject*) device;

@end

@interface VideoView: MTKView

- (void) play;
- (void) pause;
- (instancetype)initWithProperties:(NSDictionary*)videoProperties;
@property CGFloat width;
@property CGFloat height;

@end


NS_ASSUME_NONNULL_END
