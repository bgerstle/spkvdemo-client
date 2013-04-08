//
//  SPObjCDeferred.h
//  Project X
//
//  Created by Brian Gerstle on 3/22/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPDeferredBase.h"

#define $sp_decl_wself \
__weak __typeof(self) weakSelf = self;

/** @class SPDeferred
  * @note This class is thread-safe via an internal, per-instance dispatch queue.
  */
@class SPPromise;
@interface SPDeferred : NSObject
<SPDeferredBase>

///
/// @name Actions
///

/** @brief If the receiver's @property state is @c SPDeferredPending, this sets the state to @c SPDeferredStateResolved,
  * and calls any blocks added via @function -done: and @function -always:
  * @note If the receiver's @property state is not @c SPDeferredPending, nothing happens.
  */
- (void)resolve;

- (void)resolveWith:(id)result;

/** @param error The @class NSError object passed to blocks added via @function -fail:
  * @brief If the receiver's @property state is @c SPDeferredPending, this sets the state to @c SPDeferredStateRejected
  *        and calls any blocks added via @function -fail: (with @param error as the argument) and @function -always:
  * @note If the receiver's @property state is not @c SPDeferredPending, nothing happens.
  */
- (void)reject:(NSError*)error;

/** @brief Joins an array of @class SPDeferred objects into a single deferred while will be:
 *            - Resolved after all of the objects in @param deferreds are resolved
 *            - Rejected after the first object in @param deferreds is rejected
 *            - Cancelled after the first objectin @param deferreds is cancelled
 * @return Returns a new @c SPPromise which can be used to add more done/fail/always callbacks to the receiver, but not
 *         to resolve, reject, or cancel it.
 * @see SPPromise
 */
+ (SPPromise*)join:(NSArray*)deferreds;

///
/// @name Promise
///

/** @return Instantiates an instance of @c SPPromise which can be used to add more done/fail/always callbacks to the 
  * receiver, but not resolve, reject, or cancel it.
  * @see SPPromise
  */
- (SPPromise*)promise;

@end