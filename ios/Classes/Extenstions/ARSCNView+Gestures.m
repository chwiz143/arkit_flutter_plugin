//
//  ARSCNView+Gestures.m
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/10.
//

#import "ARSCNView+Gestures.h"

@implementation ARSCNView (Gestures)

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end
