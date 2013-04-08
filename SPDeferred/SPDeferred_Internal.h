//
//  SPObjCDeferred_Internal.h
//  Project X
//
//  Created by Brian Gerstle on 3/22/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPDeferred.h"
#import "SPDeferredCallback.h"

@interface SPDeferred ()

/// primitive accessors for deferred state, bypasses synchrnonization
- (BOOL)primitiveIsResolved;
- (BOOL)primitiveIsCancelled;
- (BOOL)primitiveIsRejected;
- (SPDeferredState)primitiveState;

/// internal callback for when the deferred was cancelled, make sure to call super
- (void)wasCancelled;

@end