//
//  SPPromise_Internal.h
//  Project X
//
//  Created by Brian Gerstle on 4/2/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import "SPPromise.h"
@class SPDeferred;
@interface SPPromise ()
{
@private
    SPDeferred* _deferred;
}
@end
