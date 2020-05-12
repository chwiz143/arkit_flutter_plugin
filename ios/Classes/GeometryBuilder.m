#import "GeometryBuilder.h"
#import "ArkitPlugin.h"
#import "Color.h"
#import "DecodableUtils.h"

@implementation GeometryBuilder

+ (SCNGeometry *) createGeometry:(NSDictionary *) geometryArguments withDevice: (NSObject*) device {
    SEL selector = NULL;
    if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitSphere"]) {
        selector = @selector(getSphere:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitPlane"]) {
        selector = @selector(getPlane:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitText"]) {
        selector = @selector(getText:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitBox"]) {
        selector = @selector(getBox:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitLine"]) {
        selector = @selector(getLine:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitCylinder"]) {
        selector = @selector(getCylinder:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitCone"]) {
        selector = @selector(getCone:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitPyramid"]) {
        selector = @selector(getPyramid:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitTube"]) {
        selector = @selector(getTube:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitTorus"]) {
        selector = @selector(getTorus:);
    } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitCapsule"]) {
        selector = @selector(getCapsule:);
    // } else if ([geometryArguments[@"dartType"] isEqualToString:@"ARKitFace"]) {
    //     selector = @selector(getFace:withDeivce:);
    }
    
    if (selector == nil)
        return nil;
    
    IMP imp = [self methodForSelector:selector];
    SCNGeometry* (*func)(id, SEL, NSDictionary*, id) = (void *)imp;
    SCNGeometry *geometry = func(self, selector, geometryArguments, device);
    
    if (geometry != nil) {
        geometry.materials = [self getMaterials: geometryArguments[@"materials"]];
    }
    return geometry;
}

+ (NSArray<SCNMaterial*>*) getMaterials: (NSArray*) materialsString {
    if (materialsString == nil || [materialsString count] == 0)
        return nil;
    NSMutableArray *materials = [NSMutableArray arrayWithCapacity:[materialsString count]];
    for (NSDictionary* material in materialsString) {
        [materials addObject:[self getMaterial:material]];
    }
    return materials;
}


+ (SCNMaterial*) getMaterial: (NSDictionary*) materialString {
    SCNMaterial* material = [SCNMaterial material];
    for(NSString* property in @[@"diffuse", @"ambient", @"specular", @"emission", @"transparent", @"reflective", @"multiply" , @"normal", @"displacement", @"ambientOcclusion", @"selfIllumination", @"metalness", @"roughness"]) {
        [self applyMaterialProperty:property withPropertyDictionary:materialString and:material];
    }
    
    material.shininess = [materialString[@"shininess"] doubleValue];
    material.transparency = [materialString[@"transparency"] doubleValue];
    material.lightingModelName = [self getLightingMode: [materialString[@"lightingModelName"] integerValue]];
    material.fillMode = [materialString[@"fillMode"] integerValue];
    material.cullMode = [materialString[@"cullMode"] integerValue];
    material.transparencyMode = [materialString[@"transparencyMode"] integerValue];
    material.locksAmbientWithDiffuse = [materialString[@"locksAmbientWithDiffuse"] boolValue];
    material.writesToDepthBuffer =[materialString[@"writesToDepthBuffer"] boolValue];
    material.colorBufferWriteMask = [self getColorMask:[materialString[@"colorBufferWriteMask"] integerValue]];
    material.blendMode = [materialString[@"blendMode"] integerValue];
    material.doubleSided = [materialString[@"doubleSided"] boolValue];
    
    return material;
}

+ (void) applyMaterialProperty: (NSString*) propertyName withPropertyDictionary: (NSDictionary*) dict and:(SCNMaterial *) material {
    NSDictionary* propertyString = dict[propertyName];
    if (propertyString != nil) {
        SCNMaterialProperty *property = [material valueForKey: propertyName];
        property.contents = [self getMaterialProperty:propertyString];
    }
}

+ (id) getMaterialProperty: (NSDictionary*) propertyString {
    if (propertyString[@"image"] != nil) {
        UIImage* img = [UIImage imageNamed:propertyString[@"image"]];
        
        if(img == nil) {
            NSString* asset_path = propertyString[@"image"];
            NSString* path = [[NSBundle mainBundle] pathForResource:[[ArkitPlugin registrar] lookupKeyForAsset:asset_path] ofType:nil];
            img = [UIImage imageNamed: path];
        }
        
        return img;
    } else if (propertyString[@"color"] != nil) {
        NSNumber* color = propertyString[@"color"];
        return [UIColor fromRGB: [color integerValue]];
    } else if (propertyString[@"url"] != nil) {
        return propertyString[@"url"];
    } else if (propertyString[@"videoProperty"] != nil) {
        NSDictionary* videoProperty = propertyString[@"videoProperty"];
        NSLog(@"####### videoProperty=%@", videoProperty);

        VideoView* videoView = [[VideoView alloc] initWithProperties: videoProperty];

        return videoView;
    }
    
    return nil;
}

//Videoループ処理
//現在は動画の最初に戻しているが、それを途中でできるのか。。。
+ (void) playerItemDidReachEnd:(NSNotification *)notification {
    NSLog(@"####### playerItemDidReachEnd=%@", [notification object]);
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

+ (SCNLightingModel) getLightingMode:(NSInteger) mode {
    switch (mode) {
        case 0:
            return SCNLightingModelPhong;
        case 1:
            return SCNLightingModelBlinn;
        case 2:
            return SCNLightingModelLambert;
        case 3:
            return SCNLightingModelConstant;
        default:
            return SCNLightingModelPhysicallyBased;
    }
}

+ (SCNColorMask) getColorMask:(NSInteger) mode {
    switch (mode) {
        case 0:
            return SCNColorMaskNone;
        case 1:
            return SCNColorMaskRed;
        case 2:
            return SCNColorMaskGreen;
        case 3:
            return SCNColorMaskBlue;
        case 4:
            return SCNColorMaskAlpha;
        default:
            return SCNColorMaskAll;
    }
}

+ (SCNSphere *) getSphere:(NSDictionary *) geometryArguments {
    NSNumber* radius = geometryArguments[@"radius"];
    return [SCNSphere sphereWithRadius:[radius doubleValue]];
}

+ (SCNPlane *) getPlane:(NSDictionary *) geometryArguments {
    float width = [geometryArguments[@"width"] floatValue];
    float height = [geometryArguments[@"height"] floatValue];
    int widthSegmentCount = [geometryArguments[@"widthSegmentCount"] intValue];
    int heightSegmentCount = [geometryArguments[@"heightSegmentCount"] intValue];
    
    SCNPlane* plane = [SCNPlane planeWithWidth:width height:height];
    plane.widthSegmentCount = widthSegmentCount;
    plane.heightSegmentCount = heightSegmentCount;
    return plane;
}

+ (SCNText *) getText:(NSDictionary *) geometryArguments {
    float extrusionDepth = [geometryArguments[@"extrusionDepth"] floatValue];
    return [SCNText textWithString:geometryArguments[@"text"] extrusionDepth:extrusionDepth];
}

+ (SCNBox *) getBox:(NSDictionary *) geometryArguments {
    NSNumber* width = geometryArguments[@"width"];
    NSNumber* height = geometryArguments[@"height"];
    NSNumber* length = geometryArguments[@"length"];
    NSNumber* chamferRadius = geometryArguments[@"chamferRadius"];
    return [SCNBox boxWithWidth:[width floatValue] height:[height floatValue] length:[length floatValue] chamferRadius:[chamferRadius floatValue]];
}

+ (SCNGeometry *) getLine:(NSDictionary *) geometryArguments {
    SCNVector3 fromVector =  [DecodableUtils parseVector3:geometryArguments[@"fromVector"]];
    SCNVector3 toVector = [DecodableUtils parseVector3:geometryArguments[@"toVector"]];
    SCNVector3 vertices[] = {fromVector, toVector};
    SCNGeometrySource *source =  [SCNGeometrySource geometrySourceWithVertices: vertices
                                                                         count: 2];
    int indexes[] = { 0, 1 };
    NSData *dataIndexes = [NSData dataWithBytes:indexes length:sizeof(indexes)];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:dataIndexes
                                                                primitiveType:SCNGeometryPrimitiveTypeLine
                                                                primitiveCount:1
                                                                bytesPerIndex:sizeof(int)];
    return [SCNGeometry geometryWithSources: @[source] elements: @[element]];
}

+ (SCNCylinder *) getCylinder:(NSDictionary *) geometryArguments {
    NSNumber* radius = geometryArguments[@"radius"];
    NSNumber* height = geometryArguments[@"height"];
    return [SCNCylinder cylinderWithRadius:[radius floatValue] height:[height floatValue]];
}

+ (SCNCone *) getCone:(NSDictionary *) geometryArguments {
    NSNumber* topRadius = geometryArguments[@"topRadius"];
    NSNumber* bottomRadius = geometryArguments[@"bottomRadius"];
    NSNumber* height = geometryArguments[@"height"];
    return [SCNCone coneWithTopRadius:[topRadius floatValue] bottomRadius:[bottomRadius floatValue] height:[height floatValue]];
}

+ (SCNPyramid *) getPyramid:(NSDictionary *) geometryArguments {
    NSNumber* width = geometryArguments[@"width"];
    NSNumber* height = geometryArguments[@"height"];
    NSNumber* length = geometryArguments[@"length"];
    return [SCNPyramid pyramidWithWidth:[width floatValue] height:[height floatValue] length:[length floatValue]];
}

+ (SCNTube *) getTube:(NSDictionary *) geometryArguments {
    NSNumber* innerRadius = geometryArguments[@"innerRadius"];
    NSNumber* outerRadius = geometryArguments[@"outerRadius"];
    NSNumber* height = geometryArguments[@"height"];
    return [SCNTube tubeWithInnerRadius:[innerRadius floatValue] outerRadius:[outerRadius floatValue] height:[height floatValue]];
}

+ (SCNTorus *) getTorus:(NSDictionary *) geometryArguments {
    NSNumber* ringRadius = geometryArguments[@"ringRadius"];
    NSNumber* pipeRadius = geometryArguments[@"pipeRadius"];
    return [SCNTorus torusWithRingRadius:[ringRadius floatValue] pipeRadius:[pipeRadius floatValue]];
}

+ (SCNCapsule *) getCapsule:(NSDictionary *) geometryArguments {
    NSNumber* capRadius = geometryArguments[@"capRadius"];
    NSNumber* height = geometryArguments[@"height"];
    return [SCNCapsule capsuleWithCapRadius:[capRadius floatValue] height:[height floatValue]];
}

// + (ARSCNFaceGeometry *) getFace:(NSDictionary *) geometryArguments withDeivce:(id) device{
//     return [ARSCNFaceGeometry faceGeometryWithDevice:device];
// }

@end

@interface VideoView()
@property CIContext* context;
@property id<MTLComputePipelineState> pipelineState;
@property id<MTLLibrary> library;
@property AVPlayer* player;
@property AVPlayerItemVideoOutput* output;
@property id<MTLCommandQueue> commandQueue;
@property MTKView* bufferMtkView;
@property CGColorSpaceRef colorSpace;
@property MTLSize threadsPerThreadgroup;
@property MTLSize threadgroupsPerGrid;
@property CGFloat keyingR;
@property CGFloat keyingG;
@property CGFloat keyingB;
@property float keyingThreshold;
@property float keyingSlope;
@property int mode;
@end

@implementation VideoView

- (instancetype)initWithProperties:(NSDictionary *)videoProperties {
    NSURL *videoURL = [[NSURL alloc] initFileURLWithPath: videoProperties[@"videoPath"]];
    bool isLoop = [videoProperties[@"isLoop"] boolValue];
    NSNumber* tempColor = videoProperties[@"chromaKeyColor"];
    UIColor* keyingColor = [UIColor fromRGB: [tempColor integerValue]];
    [keyingColor getRed:&_keyingR green:&_keyingG blue:&_keyingB alpha:nil];
    _keyingThreshold = (videoProperties[@"keyingThreshold"] != nil) ?
                       [videoProperties[@"keyingThreshold"] floatValue] : 0.8;
    _keyingSlope = (videoProperties[@"keyingThreshold"] != nil) ?
                       [videoProperties[@"keyingSlope"] floatValue] : 0.2;
    _mode = ([videoProperties[@"enableChromaKey"] boolValue]) ? 1 : ([videoProperties[@"enableHalfMask"] boolValue]) ? 2 : 0;

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL: videoURL options: nil];
    AVAssetTrack *videoTrack = [videoAsset tracksWithMediaType:AVMediaTypeVideo][0];
    CGRect frame = CGRectMake(0, 0, videoTrack.naturalSize.width, videoTrack.naturalSize.height);
    self = [super initWithFrame:frame device:device];
    if (self) {
        _colorSpace = CGColorSpaceCreateDeviceRGB();
        _context = [CIContext contextWithMTLDevice:device];
        NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
        _output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];


        self.framebufferOnly = false;
        [self setOpaque:false];
        self.backgroundColor = UIColor.clearColor;
        
        _commandQueue = [device newCommandQueue];
        NSBundle* bundle = [NSBundle bundleForClass:[self class]];
        _library = [device newDefaultLibraryWithBundle:bundle error:nil];
        _pipelineState = [device newComputePipelineStateWithFunction:[_library newFunctionWithName:@"ChromaKeyFilter"] error:nil];
        _threadsPerThreadgroup = MTLSizeMake(16, 16, 1);
        
        _bufferMtkView = [[MTKView alloc] initWithFrame:frame device:device];
        _bufferMtkView.translatesAutoresizingMaskIntoConstraints = false;
        _bufferMtkView.framebufferOnly = false;
        [_bufferMtkView setHidden:true];
        [self addSubview:_bufferMtkView];
        
        _threadgroupsPerGrid = MTLSizeMake(
                                           (int)ceilf((float)frame.size.width)/(float)_threadsPerThreadgroup.width,
                                           (int)ceilf((float)frame.size.height)/(float)_threadsPerThreadgroup.height,
                                           1);
        
        AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithURL: videoURL];
        _player = [[AVPlayer alloc] initWithPlayerItem: playerItem];
        
        //TODO 動画ループ処理
        if (isLoop){
           _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
           [[NSNotificationCenter defaultCenter] addObserver:self
                                                    selector:@selector(playerItemDidReachEnd:)
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:[_player currentItem]];
        }
        [_player.currentItem addOutput:_output];
        
        _width = videoTrack.naturalSize.width;
        _height = videoTrack.naturalSize.height;
        
        self.drawableSize = self.bounds.size;
        _bufferMtkView.drawableSize = _bufferMtkView.bounds.size;
    }
    return self;
}

- (void) play {
    NSLog(@"videoView play");
    [_player play];
}

- (void) pause {
    NSLog(@"videoView pause");
    [_player pause];
}

- (void)drawRect:(CGRect)rect {
    self.drawableSize = self.bounds.size;
    _bufferMtkView.drawableSize = _bufferMtkView.bounds.size;

    id <MTLDevice> device = self.device;
    id <CAMetalDrawable> drawable = self.currentDrawable;
    id <CAMetalDrawable> tempDrawable = _bufferMtkView.currentDrawable;
    
    CMTime time = _player.currentTime;
    CVPixelBufferRef pixelBuffer = [_output copyPixelBufferForItemTime:time itemTimeForDisplay:nil];
    CIImage* image = [[CIImage alloc]initWithCVPixelBuffer:pixelBuffer];
    
    if (drawable == nil || tempDrawable == nil || image == nil) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    [_context render:image toMTLTexture:tempDrawable.texture commandBuffer:nil bounds:self.bounds colorSpace:_colorSpace];
    self.colorPixelFormat = tempDrawable.texture.pixelFormat;

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:_pipelineState];
    [commandEncoder setTexture:tempDrawable.texture atIndex:0];
    [commandEncoder setTexture:drawable.texture atIndex:1];

    float factors[] = {_keyingR, _keyingG, _keyingB, _keyingThreshold, _keyingSlope, _mode};
    for (int i = 0; i < sizeof(factors); i ++) {
        float factor = factors[i];
        id<MTLBuffer> buffer = [device newBufferWithBytes:&factor length:16 options:MTLResourceStorageModeShared];
        [commandEncoder setBuffer:buffer offset:0 atIndex:i];
    }

    [commandEncoder dispatchThreadgroups:_threadgroupsPerGrid threadsPerThreadgroup:_threadsPerThreadgroup];
    [commandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void) playerItemDidReachEnd:(NSNotification *)notification {
    NSLog(@"####### playerItemDidReachEnd=%@", [notification object]);
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
}

@end
