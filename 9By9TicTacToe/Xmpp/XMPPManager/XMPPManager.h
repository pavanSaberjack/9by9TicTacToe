//
//  XMPPManager.h
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 13/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "XMPPFramework.h"

typedef NS_ENUM(NSInteger, PresenceType) {
    PresenceTypeJoined,
    PresenceTypeLeft
};

@class User;

extern NSString *const XMPPManagerDidConnectNotification;
extern NSString *const XMPPManagerDidFailedToConnectNotification;
extern NSString *const XMPPManagerDidDisconnectNotification;
extern NSString *const XMPPManagerRoomDidCreateNotification;
extern NSString *const XMPPManagerDidSendMessageNotification;
extern NSString *const XMPPManagerDidRecieveMessageNotification;
extern NSString *const XMPPManagerDidRecievePresenceNotification;
extern NSString *const XMPPManagerRoomDidJoinNotification;
extern NSString *const XMPPManagerRoomDidRecieveMessageNotification;
extern NSString *const XMPPManagerRoomDidSentMessageNotification;
extern NSString *const XMPPManagerRoomDidLeaveNotification;
extern NSString *const XMPPManagerUserDidLeaveRoomNotification;

// Pubsub notifications
extern NSString *const XMPPManagerPubsubDidCreateNotification;
extern NSString *const XMPPManagerPubsubDidSubscribeNotification;
extern NSString *const XMPPManagerPubsubDidUnSubscribeNotification;
extern NSString *const XMPPManagerPubsubDidPublishNotification;
extern NSString *const XMPPManagerPubsubDidRecieveMessageNotification;
extern NSString *const XMPPManagerPubsubDidDeleteNotification;
extern NSString *const XMPPManagerPubsubDidRetrivePreviousItemsNotification;

@interface XMPPManager : NSObject <XMPPRosterDelegate>

@property (nonatomic, strong, readonly) XMPPStream *xmppStream;
@property (nonatomic, strong, readonly) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong, readonly) XMPPRoster *xmppRoster;

+ (XMPPManager *)sharedInstance;

- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

- (BOOL)connect;
- (void)disconnect;
- (void)goOnline;
- (void)goOffline;

/////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Pubsub methods
- (void)createPubsubWithName:(NSString *)nodeName;
- (void)deletePubsubWithName:(NSString *)nodeName;
- (void)subscribeToPubsubWithNodeName:(NSString *)nodeName;
- (void)unsubscribeToPubsubWithNodeName:(NSString *)nodeName;

- (void)senSelectionFromUser:(User *)fromUser toNode:(NSString *)node withPresence:(PresenceType)type forNode:(NSString *)forNode;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withMessageStr:(NSString *)messageStr;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node;
- (void)getPreviousItemsForNode:(NSString *)node;
@end
