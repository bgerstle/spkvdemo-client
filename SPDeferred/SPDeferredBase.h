//
//  SPDeferredBase.h
//  Project X
//
//  Created by Brian Gerstle on 3/29/13.
//  Copyright (c) 2013 Spotify. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SPDeferredState) {
    SPDeferredPending = 0,
    SPDeferredResolved,
    SPDeferredRejected,
    SPDeferredCancelled
};

///
/// @name Callback Types
///
@class SPPromise;
@protocol SPDeferredBase;
typedef void (^SPDeferredResolvedBlock) (id obj);
typedef void (^SPDeferredFailBlock) (NSError* error);
typedef void (^SPDeferredAlwaysBlock) (SPDeferredState state);

/*! @name SPDeferredDonePipeBlock
 *  @param obj An object which is either what the deferred was resolved with, the deferred itself, or a result from
 *         a previous pipe in the donePipe chain.
 *  @return Returns a non-NSError to continue the resolve/donePipe chain or an NSError to start the reject/failPipe chain.
 *  @warning Don't reject or resolve the deferred you're passing a done or fail pipe block to within the done/fail block,
 *           use the returned object conventions instead.
 */
typedef id (^SPDeferredDonePipeBlock) (id obj);

/*! @name SPDeferredDonePipeBlock
 *  @param error An error which is either what the deferred was rejected with or an error from a previous pipe in the
 *         failPipe chain.
 *  @return Returns a non-NSError to continue the resolve/donePipe chain or an NSError to start the reject/failPipe chain.
 *  @warning Don't reject or resolve the deferred you're passing a done or fail pipe block to within the done/fail block,
 *           use the returned object conventions instead.
 */
typedef id (^SPDeferredFailPipeBlock) (NSError* error);


@protocol SPDeferredBase <NSObject>

///
/// @name Properties
///

/** @brief Thread-safe, synchronous accessor for @property state
 */
@property (atomic, assign, readonly) SPDeferredState state;

/** @brief Thread-safe, synchronous convenience accessor for @property state
 * @return Returns YES if @property state is equal to @c SPDeferredResolved
 */
@property (atomic, assign, readonly) BOOL isResolved;

/** @brief Thread-safe, synchronous convenience accessor for @property state
 * @return Returns YES if @property state is equal to @c SPDeferredRejected
 */
@property (atomic, assign, readonly) BOOL isRejected;

/** @brief Thread-safe, synchronous convenience accessor for @property state
 * @return Returns YES if @property state is equal to @c SPDeferredCancelled
 */
@property (atomic, assign, readonly) BOOL isCancelled;

/// @note nonatomic, so only access within done or after resolved
@property (nonatomic, strong, readonly) id resolvedObj;

@property (atomic, strong, readonly) NSError* error;

/*! @name Callbacks
 *  These methods allow you to add completion blocks to the deferred which are triggered when a certain state is reached
 *  (i.e. state == SPDeferredResolved -> @fn -done:, state == SPDeferredRejected -> @fn -fail:). @fn -always: is called
 *  after any state change.  Of course, a deferred's internal state will only change once from pending -> resolved, 
 *  rejected, or cancelled.
 */

- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe
                   queue:(dispatch_queue_t)callbackQueue;

- (instancetype)failPipe:(SPDeferredFailPipeBlock)donePipe
                   queue:(dispatch_queue_t)callbackQueue;

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock queue:(dispatch_queue_t)callbackQueue;

- (instancetype)fail:(SPDeferredFailBlock)failBlock queue:(dispatch_queue_t)callbackQueue;

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock queue:(dispatch_queue_t)callbackQueue;

/// These are all dispatched to the main queue automatically

- (instancetype)donePipe:(SPDeferredDonePipeBlock)donePipe;

- (instancetype)failPipe:(SPDeferredFailPipeBlock)failPipe;

- (instancetype)done:(SPDeferredResolvedBlock)doneBlock;

- (instancetype)fail:(SPDeferredFailBlock)failBlock;

- (instancetype)always:(SPDeferredAlwaysBlock)alwaysBlock;

/** @brief If the receiver's @property state is @c SPDeferredPending, this sets the state to @c SPDeferredStateCancelled
 *        and calls any blocks added via @function -always:
 * @note If the receiver's @property state is not @c SPDeferredPending, nothing happens.
 */
- (void)cancel;

@end
