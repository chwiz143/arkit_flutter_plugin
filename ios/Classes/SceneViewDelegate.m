#import "SceneViewDelegate.h"
#import "CodableUtils.h"

@interface SceneViewDelegate()
@property FlutterMethodChannel* channel;
@property FlutterArkitController* controller;
@end


@implementation SceneViewDelegate

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel controller:(FlutterArkitController *)controller {
  self = [super init];
  if (self) {
    self.channel = channel;
      self.controller = controller;
  }
  return self;
}

/*
 // Override to create and configure nodes for anchors added to the view's session.
 - (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor {
 SCNNode *node = [SCNNode new];
 
 // Add geometry to the node...
 
 return node;
 }
 */

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
  [_channel invokeMethod: @"onError" arguments: error.localizedDescription];
  // Present an error message to the user
  
}

- (void)sessionWasInterrupted:(ARSession *)session {
  // Inform the user that the session has been interrupted, for example, by presenting an overlay
  [_channel invokeMethod: @"onSessionWasInterrupted" arguments: nil];
}

- (void)sessionInterruptionEnded:(ARSession *)session {
  // Reset tracking and/or remove existing anchors if consistent tracking is required
  [_channel invokeMethod: @"onSessionInterruptionEnded" arguments: nil];
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if (node.name == nil) {
      node.name = [NSUUID UUID].UUIDString;
    }
    [_controller setNodeToObjectsParent:node];
    
    NSLog(@"**** didAddNodeForAnchor \n%@ \n%@", node, anchor);
    if (![_controller addNurieObject:anchor node: node]) {
        NSDictionary* params = [self prepareParamsForAnchorEventwithNode:node andAnchor:anchor];
        [_channel invokeMethod: @"didAddNodeForAnchor" arguments: params];
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
  NSDictionary* params = [self prepareParamsForAnchorEventwithNode:node andAnchor:anchor];
  if (![_controller checkMarkerNurie:anchor node: node]) {
      [_channel invokeMethod: @"didUpdateNodeForAnchor" arguments: params];
  }
}

#pragma mark - Helpers

- (NSDictionary<NSString*, NSString*>*) prepareParamsForAnchorEventwithNode: (SCNNode*) node andAnchor: (ARAnchor*) anchor {
  NSMutableDictionary<NSString*, NSString*>* params = [@{@"node_name": node.name} mutableCopy];
  [params addEntriesFromDictionary:[CodableUtils convertARAnchorToDictionary:anchor]];
  return params;
}

@end
