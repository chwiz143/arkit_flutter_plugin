//
//  ARSCNView+Gestures.h
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/10.
//

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ARSCNView (Gestures) <UIGestureRecognizerDelegate>

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;

@end

NS_ASSUME_NONNULL_END
