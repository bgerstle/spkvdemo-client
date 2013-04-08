//
//  SPPromise.h
//  Project X
//
//  Created by Brian Gerstle on 3/25/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDeferredBase.h"
#import "SPDeferred.h"

@interface SPPromise : NSObject
<SPDeferredBase>

- (id)initWithDeferred:(SPDeferred*)deferred;

@end
