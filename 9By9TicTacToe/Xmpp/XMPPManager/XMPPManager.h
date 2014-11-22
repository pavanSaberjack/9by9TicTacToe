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

@class User;
typedef NS_ENUM(NSInteger, GroupsType) {
    GroupsTypeGlobal,
    GroupsTypeContextual,
    GroupsTypeNone
};

typedef NS_ENUM(NSInteger, CelebFeedType) {
    CelebFeedTypeGlobal,
    CelebFeedTypeContextual
};

typedef NS_ENUM(NSInteger, PresenceType) {
    PresenceTypeJoined,
    PresenceTypeLeft
};

typedef NS_ENUM(NSInteger, NodeType) {
    NodeTypeGlobal,
    NodeTypeContextual,
    NodeTypeAdminNode,
    NodeTypeResultNode
};

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
extern NSString *const XMPPManagerUserDidJoinRoomNotification;
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

@property (nonatomic, strong) User *currentUserObject;

+ (XMPPManager *)sharedInstance;

- (NSManagedObjectContext *)managedObjectContext_roster;
- (NSManagedObjectContext *)managedObjectContext_capabilities;

- (BOOL)connect;
- (void)disconnect;
- (void)goOnline;
- (void)goOffline;

/*
- (void)createChatRoomForGroup:(Group *)group ofType:(GroupsType)type;
- (void)leaveCurrentXmppRoom;

- (void)sendRoomPresenceForHistory;
- (NSArray *)getChatRoomMessagesForRoom:(XMPPRoom *)chatRoom;
- (void)handleOutGoingMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room;
- (void)handleIncomingMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room;

// Normal message methods
- (void)sendNormalMessageFromUser:(User *)fromUser toUser:(User *)toUser withText:(NSString *)text;
- (void)sendCommentMessageFromUser:(User *)fromUser toUser:(User *)toUser withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment;
- (void)sendAnswerMessageFromUser:(User *)fromUser toUser:(User *)toUser withQustion:(Question *)question andAnswer:(Answer *)answer;

// Groups chat methods
- (void)sendNormalGroupMessageFromUser:(User *)fromUser withText:(NSString *)text ofType:(GroupsType)type;
- (void)sendNormalMessageFromUser:(User *)fromUser toGroup:(Group *)group withText:(NSString *)text ofType:(GroupsType)type;

- (void)sendCommentGroupMessageFromUser:(User *)fromUser withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment ofType:(GroupsType)type;
- (void)sendCommentMessageFromUser:(User *)fromUser toGroup:(Group *)group withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment ofType:(GroupsType)type;


- (void)sendAnswerGroupMessageFromUser:(User *)fromUser withQustion:(Question *)question andAnswer:(Answer *)answer ofType:(GroupsType)type;
- (void)sendAnswerMessageFromUser:(User *)fromUser toGroup:(Group *)group withQustion:(Question *)question andAnswer:(Answer *)answer ofType:(GroupsType)type;

- (void)sendPresenceMessageFromUser:(User *)fromUser toGroup:(Group *)group ofType:(GroupsType)type forPresenceType:(PresenceType)presenceType;
- (void)sendPresenceMessageFromUser:(User *)fromUser ofType:(GroupsType)type forPresenceType:(PresenceType)presenceType;

- (void)sendPresenceMessageFromUser:(User *)fromUser toUser:(User *)toUser forPresenceType:(PresenceType)presenceType;

/////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma Pubsub methods
// Only Celebs will can use this nodes for publishing there feeds
- (void)createPubsubWithName:(NSString *)nodeName;
- (void)deletePubsubWithName:(NSString *)nodeName;

// Normal users will subscribe to the nodes of celebs
- (void)subscribeToPubsubWithNodeName:(NSString *)nodeName;
- (void)unsubscribeToPubsubWithNodeName:(NSString *)nodeName;

// Message methods
- (void)sendShowSelectionFromUser:(User *)fromUser toNode:(NSString *)node withPresence:(PresenceType)type forNode:(NSString *)forNode;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withMessageStr:(NSString *)messageStr;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withComment:(Comment *)comment andSubcomment:(CommentDetail *)subComment;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withQuestion:(Question *)question withAnswer:(Answer *)answer;
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withComment:(Comment *)comment andSubcomment:(CommentDetail *)subComment andLocationDict:(NSDictionary *)dictionary;
- (void)getPreviousItemsForNode:(NSString *)node;
 */
@end
