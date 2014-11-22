//
//  XMPPManager.m
//  9By9TicTacToe
//
//  Created by Pavan Itagi on 13/11/14.
//  Copyright (c) 2014 Pavan Itagi. All rights reserved.
//


#import "XMPPManager.h"
#import "GCDAsyncSocket.h"
#import "XMPP.h"
#import "XMPPReconnect.h"
#import "XMPPRosterCoreDataStorage.h"
#import "XMPPRosterMemoryStorage.h"
#import "XMPPRoomMemoryStorage.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPMUC.h"
#import "Reachability.h"
#import "XMPPLogging.h"
#import "XMPPPubSub.h"

//#import "ZingMessageFactory.h"

//#import "ToastMessageView.h"

// core date
//#import "Message.h"
//#import "User.h"
//#import "Group.h"
//#import "PubsubMessages.h"
//#import "PubsubNode.h"

#import <CFNetwork/CFNetwork.h>

// Notifications
NSString *const XMPPManagerDidConnectNotification = @"XMPPManagerDidConnectNotification";
NSString *const XMPPManagerDidFailedToConnectNotification = @"XMPPManagerDidFailedToConnectNotification";
NSString *const XMPPManagerDidDisconnectNotification = @"XMPPManagerDidDisconnectNotification";
NSString *const XMPPManagerDidSendMessageNotification = @"XMPPManagerDidSendMessageNotification";
NSString *const XMPPManagerDidRecieveMessageNotification = @"XMPPManagerDidRecieveMessageNotification";
NSString *const XMPPManagerDidRecievePresenceNotification = @"XMPPManagerDidRecievePresenceNotification";

// Chat room notifications
NSString *const XMPPManagerRoomDidCreateNotification = @"XMPPManagerRoomDidCreateNotification";
NSString *const XMPPManagerRoomDidJoinNotification = @"XMPPManagerRoomDidJoinNotification";
NSString *const XMPPManagerRoomDidLeaveNotification = @"XMPPManagerRoomDidLeaveNotification";
NSString *const XMPPManagerRoomDidRecieveMessageNotification = @"XMPPManagerRoomDidRecieveMessageNotification";
NSString *const XMPPManagerRoomDidSentMessageNotification = @"XMPPManagerRoomDidSentMessageNotification";
NSString *const XMPPManagerRoomDidInsertMessageNotification = @"XMPPManagerRoomDidInsertMessageNotification";
NSString *const XMPPManagerUserDidJoinRoomNotification = @"XMPPManagerUserDidJoinRoomNotification";
NSString *const XMPPManagerUserDidLeaveRoomNotification = @"XMPPManagerUserDidLeaveRoomNotification";

// Pubsub related notifications
NSString *const XMPPManagerPubsubDidCreateNotification = @"XMPPManagerPubsubDidCreateNotification";
NSString *const XMPPManagerPubsubDidSubscribeNotification = @"XMPPManagerPubsubDidSubscribeNotification";
NSString *const XMPPManagerPubsubDidUnSubscribeNotification = @"XMPPManagerPubsubDidUnSubscribeNotification";
NSString *const XMPPManagerPubsubDidPublishNotification = @"XMPPManagerPubsubDidPublishNotification";
NSString *const XMPPManagerPubsubDidRecieveMessageNotification = @"XMPPManagerPubsubDidRecieveMessageNotification";
NSString *const XMPPManagerPubsubDidDeleteNotification = @"XMPPManagerPubsubDidDeleteNotification";
NSString *const XMPPManagerPubsubDidRetrivePreviousItemsNotification = @"XMPPManagerPubsubDidRetrivePreviousItemsNotification";

NSString *const TestResultNode = @"result_node";

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_INFO;
#endif

#define XMPP_HOST       @"dev.chat.nextspotapp.com" //development server
#define XMPP_HOST_NAME @"nextspot"

#define XMPP_PORT 5222

CGFloat const ToastHeight = 64.0f;

//static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE;
static const int xmppLogLevel = XMPP_LOG_LEVEL_INFO; // | XMPP_LOG_FLAG_TRACE;

static dispatch_queue_t xmppQueue;

NSString *const kXMPPmyJID = @"kXMPPmyJID";
NSString *const kXMPPmyPassword = @"kXMPPmyPassword";

@interface XMPPManager()<XMPPRoomDelegate, XMPPPubSubDelegate>
{
    BOOL allowSelfSignedCertificates;
	BOOL allowSSLHostNameMismatch;
    
    BOOL isXmppConnected;
    
    NSString * password;
    
    
}
@property (strong) XMPPJID      *jid;
@property (strong) NSString     *password;
@property (strong) Reachability *rechability;


@property (nonatomic, strong) XMPPStream *xmppStream;
@property (nonatomic, strong) XMPPReconnect *xmppReconnect;
@property (nonatomic, strong) XMPPRoster *xmppRoster;

@property (nonatomic, strong) XMPPRoomCoreDataStorage *storage;

@property (nonatomic, strong) NSMutableArray *chatRoomsArray;
@property (nonatomic, strong) XMPPRoom *currentXMPPRoom;
//@property (nonatomic, strong) Group *currentGroupObject;

@property (nonatomic, strong) XMPPPubSub *currentPubsub;
@property (nonatomic, strong) NSMutableArray *subscribedPubsubNodeArray;
@property (nonatomic, strong) NSMutableArray *publisherPubsubNodeArray;

@end

@implementation XMPPManager

+ (XMPPManager *)sharedInstance
{
    static id XMPPManager = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        XMPPManager = [[[self class] alloc] init];
        
//#ifdef DEBUG
//        [DDLog addLogger:[DDTTYLogger sharedInstance]];
//#endif
    });
    return XMPPManager;
}

- (id)init
{
    if (self = [super init]) {
        //
//        xmppQueue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        xmppQueue = dispatch_queue_create("myqueue", NULL);
        
        [self setupStream];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(XMPPMessageDidInserted:) name:XMPPManagerRoomDidInsertMessageNotification object:nil];
    }
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:XMPPManagerRoomDidInsertMessageNotification object:nil];
    [self teardownStream];
    xmppQueue = nil;
}

-(void) teardownStream
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    [self.xmppStream removeDelegate:self];
    
    [self.xmppRoster removeDelegate:self];
    [self.xmppReconnect deactivate];
    [self.xmppRoster deactivate];
    [self.xmppStream disconnect];
    
    self.xmppReconnect = nil;
    self.xmppRoster = nil;
    self.xmppStream = nil;
    self.jid = nil;
    self.rechability = nil;
    _chatRoomsArray = nil;
}

- (XMPPRoomCoreDataStorage *)storage
{
    if (_storage == nil)
    {
        _storage = [[XMPPRoomCoreDataStorage alloc] initWithDatabaseFilename:@"test.sqlite" storeOptions:nil];
    }
    
    return _storage;
}

- (NSMutableArray *)chatRoomsArray
{
    if (_chatRoomsArray == nil) {
        _chatRoomsArray = [NSMutableArray array];
    }
    
    return _chatRoomsArray;
}



- (NSMutableArray *)subscribedPubsubNodeArray
{
    if (_subscribedPubsubNodeArray == nil)
    {
        _subscribedPubsubNodeArray = [NSMutableArray array];
    }
    
    return _subscribedPubsubNodeArray;
}

- (NSMutableArray *)publisherPubsubNodeArray
{
    if (_publisherPubsubNodeArray == nil)
    {
        _publisherPubsubNodeArray = [NSMutableArray array];
    }
    
    return _publisherPubsubNodeArray;
}

- (XMPPPubSub *)currentPubsub
{
    if (_currentPubsub == nil)
    {
        XMPPJID *serviceJid = [XMPPJID jidWithString:@"pubsub.54.84.126.215"];
        XMPPPubSub *pubsub = [[XMPPPubSub alloc] initWithServiceJID:serviceJid dispatchQueue:xmppQueue];
        [pubsub activate:self.xmppStream];
        [pubsub addDelegate:self delegateQueue:xmppQueue];
        
        _currentPubsub = pubsub;
    }
    
    return _currentPubsub;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setupStream
{
	NSAssert(_xmppStream == nil, @"Method setupStream invoked multiple times");
	_xmppStream = [[XMPPStream alloc] init];
	_xmppStream.keepAliveInterval = 32.0f;
    
#if !TARGET_IPHONE_SIMULATOR
	{
		_xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
	
	_xmppReconnect = [[XMPPReconnect alloc] init];
    _xmppReconnect.autoReconnect = YES;
    
	_xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:[[XMPPRosterMemoryStorage alloc] init]
                                              dispatchQueue:xmppQueue];
	
	_xmppRoster.autoFetchRoster = YES;
	_xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
	[_xmppReconnect         activate:_xmppStream];
	[_xmppRoster            activate:_xmppStream];
    
	// Add ourself as a delegate to anything we may be interested in
    
	[_xmppStream addDelegate:self delegateQueue:xmppQueue];
	[_xmppRoster addDelegate:self delegateQueue:xmppQueue];
    
	// You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = NO;
}

-(void) setupStreamWithJid:(NSString*)jid password:(NSString*)pwd
{
    self.password = pwd;
    XMPPJID *xmppJid = [XMPPJID jidWithString:[NSString stringWithFormat:@"%@@%@",jid,XMPP_HOST_NAME]];
    self.jid = xmppJid;
    
    self.xmppStream = [[XMPPStream alloc] init];
    self.xmppStream.keepAliveInterval = 32.0;
    self.xmppReconnect = [[XMPPReconnect alloc] init];
    self.xmppReconnect.autoReconnect = YES;
    
    self.xmppRoster = [[XMPPRoster alloc] initWithRosterStorage:[[XMPPRosterMemoryStorage alloc] init]
                                                  dispatchQueue:xmppQueue];
    self.xmppRoster.autoFetchRoster = YES;
    self.xmppRoster.autoAcceptKnownPresenceSubscriptionRequests = YES;
    
    self.xmppStream.hostName = XMPP_HOST;
    self.xmppStream.hostPort = XMPP_PORT;
    
    [self.xmppReconnect activate:self.xmppStream];
    [self.xmppRoster activate:self.xmppStream];
    
    [self.xmppStream addDelegate:self delegateQueue:xmppQueue];
    [self.xmppRoster addDelegate:self delegateQueue:xmppQueue];
    
    [self.xmppStream setMyJID:self.jid];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    self.rechability = [Reachability reachabilityWithHostName:XMPP_HOST];
    [self.rechability startNotifier];
    
}

- (BOOL)connect
{
	if (![self.xmppStream isDisconnected]) {
		return YES;
	}
    
    
    NSString *myJID = @"asdf";//[[[SessionManager sharedInstance] currentSession] jabberId];
	NSString *myPassword = @"adsf"; //[[[SessionManager sharedInstance] currentSession] jabberPassword];
    
	//
	// If you don't want to use the Settings view to set the JID,
	// uncomment the section below to hard code a JID and password.
	//
	// myJID = @"user@gmail.com/xmppframework";
	// myPassword = @"";
	
	if (myJID == nil || myPassword == nil) {
		return NO;
	}
    
	[self.xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
	password = myPassword;
    
	NSError *error = nil;
	if (![self.xmppStream connectWithTimeout:XMPPStreamTimeoutNone error:&error])
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting"
		                                                    message:@"See console for error details."
		                                                   delegate:nil
		                                          cancelButtonTitle:@"Ok"
		                                          otherButtonTitles:nil];
		[alertView show];
        
		DDLogError(@"Error connecting: %@", error);
        
		return NO;
	}
    
	return NO;
}

- (void)disconnect
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
	[self goOffline];
    [self.xmppStream removeDelegate:self];
    [self.xmppReconnect deactivate];
    [self.xmppRoster deactivate];
	[self.xmppStream disconnect];
    [self.chatRoomsArray removeAllObjects];
    
    _chatRoomsArray = nil;
    self.xmppReconnect = nil;
    self.xmppRoster = nil;
    self.xmppStream = nil;
    self.jid = nil;
    
    self.rechability = nil;
}

- (void)goOnline
{
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
    NSString *domain = [self.xmppStream.myJID domain];
    
    //Google set their presence priority to 24, so we do the same to be compatible.
    
    if([domain isEqualToString:@"54.84.126.215"])
    {
        NSXMLElement *priority = [NSXMLElement elementWithName:@"priority" stringValue:@"24"];
        [presence addChild:priority];
    }
	
	[[self xmppStream] sendElement:presence];
}

- (void)goOffline
{
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
	
	[[self xmppStream] sendElement:presence];
}

- (void)sendSampleMessageForRoom:(XMPPRoom *)sender
{
    NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
    [body setStringValue:@"hello"];
    
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:@"groupchat"];
    [message addAttributeWithName:@"to" stringValue:[sender.roomJID full]];
    [message addChild:body];
    
    [self.xmppStream sendElement:message];

}

- (void)reachabilityChanged:(id)sender
{
    
}

- (void)leaveCurrentXmppRoom
{
    [self.currentXMPPRoom leaveRoom];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Pubsub methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)createPubsubWithName:(NSString *)nodeName
{
//    [self.currentPubsub createNode:nodeName withOptions:@{@"pubsub#notify_delete": @"1"}];
    [self.currentPubsub createNode:nodeName withOptions:@{@"pubsub#publish_model": @"open", @"pubsub#notify_delete": @"1"}];
}

- (void)deletePubsubWithName:(NSString *)nodeName
{
    if ([nodeName isEqualToString:@""]) return;
    [self.currentPubsub deleteNode:nodeName];
}

- (void)subscribeToPubsubWithNodeName:(NSString *)nodeName
{
    NSString *str = [self.currentPubsub retrieveSubscriptionsForNode:nodeName];
    if (str == nil)
    {
        [self.currentPubsub subscribeToNode:nodeName];
    }
}

- (void)unsubscribeToPubsubWithNodeName:(NSString *)nodeName
{
    [self.currentPubsub unsubscribeFromNode:nodeName];
}

/*
- (void)sendNodeDeletionFromUser:(User *)fromUser forNode:(NSString *)forNode toNode:(NSString *)node
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getDeletionEntryElemetToPuslishFromUser:fromUser forNode:forNode]];
}

- (void)sendShowSelectionFromUser:(User *)fromUser toNode:(NSString *)node withPresence:(PresenceType)type forNode:(NSString *)forNode
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getPresenceEntryElemetToPuslishFromUser:fromUser forNode:forNode forPresenceType:type]];
}

- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withMessageStr:(NSString *)messageStr
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getNormalEntryElemetToPuslishFromUser:fromUser withMessageStr:messageStr]];
}
 */
/*
- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withComment:(Comment *)comment andSubcomment:(CommentDetail *)subComment
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getNormalEntryElemetToPuslishFromUser:fromUser withComment:comment andSubcomment:subComment]];
}

- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withComment:(Comment *)comment andSubcomment:(CommentDetail *)subComment andLocationDict:(NSDictionary *)dictionary
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getCommentEntryElemetToPuslishFromUser:fromUser withComment:comment andSubcomment:subComment withLocationDictionary:dictionary]];
}

- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withQuestion:(Question *)question withAnswer:(Answer *)answer
{
    [self.currentPubsub publishToNode:node entry:[ZingMessageFactory getNormalEntryElemetToPuslishFromUser:fromUser withQuestion:question withAnswer:answer]];
}
*/

/*
- (void)handleSubscriptionForNode:(NSString *)node withResult:(BOOL)result
{
    
    if (result)
    {
        if (![self.subscribedPubsubNodeArray containsObject:node])
        {
            [self.subscribedPubsubNodeArray addObject:node];
        }
        
        [self getPreviousItemsForNode:node];
    }
    else
    {
        // check if the error is item not found
    }
    
    [[DataManager sharedInstance] pubsubNodeSubscribedWithName:node withResult:result withSuccess:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidSubscribeNotification object:node];
    } andFailure:^(NSError *error) {
        // Need to figure out
    }];
}
 */

- (void)getPreviousItemsForNode:(NSString *)node
{
    [self.currentPubsub retrivePreviousItemsForNode:node];
}

/*
// NOTE: messsge object should be NSDictionary not XMPPMessage
- (void)handleMessagesForNode:(NSString *)node forMessages:(NSArray *)messages withSuccess:(DMSuccessBlock)success andFailure:(DMFailureBlock)failure
{
    NSManagedObjectContext *context = [[DataManager sharedInstance] createWriteContext];
    [context performBlock:^{
        for (NSDictionary *dictionary in messages)
        {
            // If my message then dont do anything
            NSString *senderStr = [dictionary[@"sender"] lowercaseString];
            NSString *resultNode = [[[SessionManager sharedInstance] currentSettings] currentShowResultNode];
            
            if ([senderStr isEqualToString:[[self.xmppStream.myJID bare] lowercaseString]] && ![node isEqualToString:resultNode])
            {
                continue;
            }
            
            User *currentUser = [[DataManager sharedInstance] getCurrentLoggedUserObjectInContext:context];
            NSString *adminNodeName = [[[SessionManager sharedInstance] currentSettings] adminPubsubNodeName];
            if ([node isEqualToString:adminNodeName])
            {
                // Check if the sender is there in my top list or followed celeb list
                NSArray *filterArray = [[currentUser.subscribedPubsubNodes allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", dictionary[@"node"]]];
                if ([filterArray count] == 0)
                {
                    continue;
                }
            }
            
            NSArray *filteredArray = [[currentUser.followedCelebs allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"userId == %@", dictionary[@"celebrity_id"]]];
            BOOL isSenderFollwed = [filteredArray count] > 0? YES: NO;
            
            if ([dictionary[@"type"] isEqualToString:@"delete"])
            {
                PubsubNode *nodeToDelete = [PubsubNode MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", dictionary[@"node"]] inContext:context];
                if (nodeToDelete != nil)
                {
                    [context deleteObject:nodeToDelete];
                }
            }
            else
            {
                PubsubMessages *messageObj = [PubsubMessages MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"itemId == %@ && toPubsubNode.nodeName == %@", dictionary[@"itemId"], node] inContext:context];
                if (messageObj != nil)
                {
                    continue;
                }
                
                messageObj = [PubsubMessages MR_createInContext:context];
                PubsubNode *nodeObj = [PubsubNode MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", node] inContext:context];
                messageObj.toPubsubNode = nodeObj;
                messageObj.timeStamp = dictionary[@"timestamp"];
                messageObj.itemId = dictionary[@"itemId"];
                messageObj.senderName = nodeObj.publisher.name;
                
                if ([dictionary[@"type"] isEqualToString:@"message"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebMessage);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebMessage);
                    
                    messageObj.messageText = dictionary[@"message"];
                }
                else if ([dictionary[@"type"] isEqualToString:@"comment"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebComment);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebComment);
                    
                    messageObj.commentStr = dictionary[@"comment"];
                    messageObj.commentDetailStr = dictionary[@"subcomment"];
                }
                else if ([dictionary[@"type"] isEqualToString:@"question"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebQuestion);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebQuestion);
                    
                    messageObj.questionStr = dictionary[@"question"];
                    messageObj.answerStr = dictionary[@"answer"];
                }
                else if ([dictionary[@"type"] isEqualToString:@"presence"])
                {
                    messageObj.type = @(PubsubMessageTypePresence);
                    messageObj.messageText = dictionary[@"message"];
                }
                else if ([dictionary[@"type"] isEqualToString:@"result_comment"])
                {
                    messageObj.type = @(PubsubMessageTypeResultComment);
                    messageObj.latitude = dictionary[@"latitude"];
                    messageObj.longitude = dictionary[@"longitude"];
                }
            }
        }
        
        [[DataManager sharedInstance] saveAllWithContext:context success:^{
            success();
        } failure:^(NSError *error) {
            failure(error);
        }];
    }];
}

// NOTE: messsge object should be NSDictionary not XMPPMessage
- (void)handleIncomingMessagesForNode:(NSString *)node forMessage:(NSDictionary *)messageDict withSuccess:(DMSuccessBlock)success andFailure:(DMFailureBlock)failure
{
    
    NSManagedObjectContext *context = [[DataManager sharedInstance] createWriteContext];
    [context performBlock:^{

        User *currentUser = [[DataManager sharedInstance] getCurrentLoggedUserObjectInContext:context];
        NSArray *filteredArray = [[currentUser.followedCelebs allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"userId == %@", messageDict[@"celebrity_id"]]];
        BOOL isSenderFollwed = [filteredArray count] > 0? YES: NO;
        
        if ([messageDict[@"type"] isEqualToString:@"delete"])
        {
            PubsubNode *nodeToDelete = [PubsubNode MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", messageDict[@"node"]] inContext:context];
            if (nodeToDelete != nil)
            {
                [context deleteObject:nodeToDelete];
            }
        }
        else
        {
            PubsubMessages *messageObj = [PubsubMessages MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"itemId == %@ && toPubsubNode.nodeName == %@", messageDict[@"itemId"], node] inContext:context];
            if (messageObj == nil)
            {
                messageObj = [PubsubMessages MR_createInContext:context];
                PubsubNode *nodeObj = [PubsubNode MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", node] inContext:context];
                messageObj.toPubsubNode = nodeObj;
                messageObj.timeStamp = messageDict[@"timestamp"];
                messageObj.itemId = messageDict[@"itemId"];
                messageObj.senderName = nodeObj.publisher.name;
                
                if ([messageDict[@"type"] isEqualToString:@"message"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebMessage);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebMessage);
                    
                    messageObj.messageText = messageDict[@"message"];
                }
                else if ([messageDict[@"type"] isEqualToString:@"comment"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebComment);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebComment);
                    
                    messageObj.commentStr = messageDict[@"comment"];
                    messageObj.commentDetailStr = messageDict[@"subcomment"];
                }
                else if ([messageDict[@"type"] isEqualToString:@"question"])
                {
                    if (isSenderFollwed)
                        messageObj.type = @(PubsubMessageTypeFollwedCelebQuestion);
                    else
                        messageObj.type = @(PubsubMessageTypeUnfollwedCelebQuestion);
                    
                    messageObj.questionStr = messageDict[@"question"];
                    messageObj.answerStr = messageDict[@"answer"];
                }
                else if ([messageDict[@"type"] isEqualToString:@"presence"])
                {
                    
                    messageObj.type = @(PubsubMessageTypePresence);
                    messageObj.messageText = messageDict[@"message"];
                    
                    [[XMPPManager sharedInstance] subscribeToPubsubWithNodeName:messageDict[@"node"]];
                }
                else if ([messageDict[@"type"] isEqualToString:@"result_comment"])
                {
                    messageObj.type = @(PubsubMessageTypeResultComment);
                    messageObj.commentStr = messageDict[@"comment"];
                    messageObj.commentDetailStr = messageDict[@"subcomment"];
                    messageObj.latitude = messageDict[@"latitude"];
                    messageObj.longitude = messageDict[@"longitude"];
                    messageObj.commentId = messageDict[@"commentId"];
                }
            }
        }
        
        [[DataManager sharedInstance] saveAllWithContext:context success:^{
            success();
        } failure:^(NSError *error) {
            failure(error);
        }];
    }];
}
 */

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)modifyAffiliationForNode:(NSString *)node
{
    /*
     <iq type='set'
        from='hamlet@denmark.lit/elsinore'
        to='pubsub.shakespeare.lit'
        id='ent2'>
     <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
        <affiliations node='princely_musings'>
            <affiliation jid='bard@shakespeare.lit' affiliation='publisher'/>
        </affiliations>
     </pubsub>
     </iq>
     */
    
    NSString *adminJid = @"asdf"; //[[[SessionManager sharedInstance] currentSettings] adminUserJabberId];
    
    XMPPIQ *aff = [XMPPIQ iqWithType:@"set"];
    [aff addAttributeWithName:@"to" stringValue:[self.currentPubsub.serviceJID bare]];
    [aff addAttributeWithName:@"from" stringValue:[self.xmppStream.myJID bare]];
    
    NSXMLElement *pubsub = [NSXMLElement elementWithName:@"pubsub" xmlns:@"http://jabber.org/protocol/pubsub#owner"];
    NSXMLElement *affiliation = [NSXMLElement elementWithName:@"affiliation"];
    [affiliation addAttributeWithName:@"jid" stringValue:adminJid];
    [affiliation addAttributeWithName:@"affiliation" stringValue:@"owner"];
    
    NSXMLElement *affiliations = [NSXMLElement elementWithName:@"affiliations"];
    [affiliations addAttributeWithName:@"node" stringValue:@"aff_test"];
    [affiliations addChild:affiliation];
    
    [pubsub addChild:affiliations];
    [aff addChild:pubsub];
    
    [self.xmppStream sendElement:aff];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPPubSubDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)xmppPubSub:(XMPPPubSub *)sender didCreateNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self.publisherPubsubNodeArray addObject:node];
    
    [self modifyAffiliationForNode:node];
    
//    [[DataManager sharedInstance] pubsubNodeCreatedWithName:node withSuccess:^{
//        
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidCreateNotification object:node];
//    } andFailure:^(NSError *error) {
//        // Need to figure out
//    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotCreateNode:(NSString *)node withError:(XMPPIQ *)iq
{
    
}

- (void)xmppPubSub:(XMPPPubSub *)sender didSubscribeToNode:(NSString *)node withResult:(XMPPIQ *)iq
{
//    [self handleSubscriptionForNode:node withResult:YES];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotSubscribeToNode:(NSString *)node withError:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
    /*
     
     <iq xmlns="jabber:client" id="0C63DA7D-B428-4EC6-A9DF-D5379E42BBE3" to="normaluser_v_3_jid@54.84.126.215/tigase-2160" from="pubsub.54.84.126.215" type="error">
        <pubsub xmlns="http://jabber.org/protocol/pubsub">
            <subscribe node="asdfsdaf" jid="normaluser_v_3_jid@54.84.126.215/tigase-2160">
            </subscribe>
        </pubsub>
        <error type="cancel" code="404">
            <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">
            </item-not-found>
        </error>
     </iq>
     */
    
    NSString *currentResultNode = @"asdf"; //[[[SessionManager sharedInstance] currentSettings] currentShowResultNode];
    NSXMLElement *error = [iq elementForName:@"error"];
    if (error != nil) {
        NSXMLElement *notFoundElement = [error elementForName:@"item-not-found"];
        if (notFoundElement != nil && [node isEqualToString:currentResultNode])
        {
            // node not found
            // check if the current node ur subscribing for a show is wat u required
            [self createPubsubWithName:node];
        }
        else
        {
//            [self handleSubscriptionForNode:node withResult:NO];
        }
    }
    else
    {
//        [self handleSubscriptionForNode:node withResult:NO];
    }
}

- (void)xmppPubSub:(XMPPPubSub *)sender didUnsubscribeFromNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self.subscribedPubsubNodeArray removeObject:node];
    
//    [[DataManager sharedInstance] pubsubNodeUnsubscribeWithName:node withSuccess:^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidUnSubscribeNotification object:node];
//    } andFailure:^(NSError *error) {
//        // Need to figure out
//    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotUnsubscribeFromNode:(NSString *)node withError:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
//    [[DataManager sharedInstance] pubsubNodeUnsubscribeWithName:node withSuccess:^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidUnSubscribeNotification object:node];
//    } andFailure:^(NSError *error) {
//        // Need to figure out
//    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didDeleteNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self.publisherPubsubNodeArray removeObject:node];
    
//    User *currentLoggedUser = [[DataManager sharedInstance] getCurrentLoggedUserObject];
//    NSString *adminNodeName = [[[SessionManager sharedInstance] currentSettings] adminPubsubNodeName];
//    [self sendNodeDeletionFromUser:currentLoggedUser forNode:node toNode:adminNodeName];
//    
//    [[DataManager sharedInstance] pubsubNodeDeletedWithName:node withSuccess:^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidDeleteNotification object:node];
//    } andFailure:^(NSError *error) {
//        // Need to figure out
//    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotDeleteNode:(NSString *)node withError:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
}

- (void)xmppPubSub:(XMPPPubSub *)sender didReceiveMessage:(XMPPMessage *)message
{
    /*
     <message xmlns="jabber:client" from="pubsub.54.84.126.215" id="24" to="normaluser_v_3_jid@54.84.126.215">
        <event xmlns="http://jabber.org/protocol/pubsub#event">
            <items node="test_1">
                <item id="2tzg01589wltaprnly4">
                    <body>{"message":"hello","sender":"normaluser_v_3_jid@54.84.126.215","timestamp":421770771.666362,"type":"message"}</body>
                </item>
            </items>
        </event>
     </message>
     
     
        <message xmlns="jabber:client" from="pubsub.54.84.126.215" id="179" to="normaluser_v_3_jid@54.84.126.215">
            <event xmlns="http://jabber.org/protocol/pubsub#event">
                <items node="admin_test">
                    <item id="3do0bz2iyyas3hwd2xm">
    <body>{"node":"admin_test","sender":"Celeb11_v_3_jid@54.84.126.215","type":"delete","timestamp":422455312.79822,"celebrity_id":442}</body>
                </item>
            </items>
            </event>
        </message>
     */
    
    /*
    NSXMLElement *event = [message elementForName:@"event"];
    NSXMLElement *items = [event elementForName:@"items"];
    NSXMLElement *body = nil;
    NSXMLElement *itemElement = nil;
    
    NSArray *itemArray = [items elementsForName:@"item"];
    for (NSXMLElement *item in itemArray)
    {
        if ([item elementForName:@"body"] != nil)
        {
            body = [item elementForName:@"body"];
            itemElement = item;
        }
    }
    
    // if there are some other types of messages than the custom messages - dont do anything
    if (body == nil)
    {
        return;
    }
    
    NSString *nodeName = [[items attributeForName:@"node"] stringValue];
    NSDictionary *dictionary = [ZingMessageFactory getDictionaryForString:[body stringValue]];
    
    // If the sender is the current user then no need to save
    NSString *senderStr = [dictionary[@"sender"] lowercaseString];
    NSString *resultNode = [[[SessionManager sharedInstance] currentSettings] currentShowResultNode];
    if ([senderStr isEqualToString:[[self.xmppStream.myJID bare] lowercaseString]] && ![resultNode isEqualToString:nodeName])
    {
        return;
    }
    
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    [newDict setObject:[[itemElement attributeForName:@"id"] stringValue] forKey:@"itemId"];
    
    NSString *currentShowGlobalId = [[[SessionManager sharedInstance] currentSettings] showGlobalId];
    NSString *adminNodeName = [[[SessionManager sharedInstance] currentSettings] adminPubsubNodeName];
    if ([nodeName isEqualToString:adminNodeName])
    {
        if (newDict[@"showGlobalId"] != nil)
        {
            if (![newDict[@"showGlobalId"] isEqualToString:currentShowGlobalId])
            {
                return;
            }
        }
        
        // Check if the sender is there in my top list or followed celeb list
        User *currentUser = [[DataManager sharedInstance] getCurrentLoggedUserObject];
        
        // check if the node is already subscribed for followed celeb joined now
        NSArray *filterArray = [[currentUser.followedCelebs allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"userId == %@", newDict[@"celebrity_id"]]];
        
        if ([filterArray count] == 0)
        {
            // user is not there in followed list so dont do anything
            return;
        }
        else
        {
//            filterArray = [[currentUser.subscribedPubsubNodes allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"nodeName == %@", newDict[@"node"]]];
//            if ([filterArray count] == 0)
//            {
//                return;
//            }
        }
    }
    
//    [self handleIncomingMessagesForNode:nodeName forMessage:newDict withSuccess:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidRecieveMessageNotification object:sender];
//        });
//    } andFailure:^(NSError *error) {
//        ///////////
//    }];
     */
}

- (void)xmppPubSub:(XMPPPubSub *)sender didPublishToNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidPublishNotification object:node];
    });
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotPublishToNode:(NSString *)node withError:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
}

- (void)xmppPubSub:(XMPPPubSub *)sender didRetrieveSubscriptions:(XMPPIQ *)iq forNode:(NSString *)node
{
    /*
     <iq xmlns="jabber:client" id="1DF9E549-57D5-435A-98C6-9AE7DE3D5705" to="normaluser_v_3_jid@54.84.126.215/tigase-1370" from="pubsub.54.84.126.215" type="result">
        <pubsub xmlns="http://jabber.org/protocol/pubsub">
            <subscriptions node="Celeb13_pubsub_g_node">
                <subscription jid="celeb13_v_3_jid@54.84.126.215" subscription="subscribed" subid="5rnywn8bxgy7q632mio"/>
            </subscriptions>
        </pubsub>
     </iq>
     */
    
    NSArray *array = [[[iq elementForName:@"pubsub"] elementForName:@"subscriptions"] elementsForName:@"subscription"];
    
    BOOL isSubscribed = NO;
    for (NSXMLElement *subscriptionElement in array)
    {
        NSString *jid = [[subscriptionElement attributeForName:@"jid"] stringValue];
        NSString *currrentUserJid = [self.xmppStream.myJID bare];
        if ([jid isEqualToString:currrentUserJid])
        {
            NSString *subscription = [[subscriptionElement attributeForName:@"subscription"] stringValue];
            if ([subscription isEqualToString:@"subscribed"])
            {
                isSubscribed = YES;
                break;
            }
        }
    }
    
    if (!isSubscribed) {
        // call for subscri
        [sender subscribeToNode:node];
    }
    else
    {
//        [self handleSubscriptionForNode:node withResult:YES];
    }
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotRetrieveSubscriptions:(XMPPIQ *)iq forNode:(NSString *)node
{
    [sender subscribeToNode:node];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didReceivePreviousItemsForNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    NSMutableArray *messageArray = [NSMutableArray array];
    
    NSXMLElement *pubsub = [iq elementForName:@"pubsub"];
    NSXMLElement *items = [pubsub elementForName:@"items"];
    NSArray *itemArr = [items elementsForName:@"item"];
    for (NSXMLElement *item in itemArr)
    {
        NSXMLElement *body = [item elementForName:@"body"];
//        NSString *currentShowGlobalId = [[[SessionManager sharedInstance] currentSettings] showGlobalId];
//        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[ZingMessageFactory getDictionaryForString:[body stringValue]]];
//        
//        NSString *adminNodeName = [[[SessionManager sharedInstance] currentSettings] adminPubsubNodeName];
//        if ([node isEqualToString:adminNodeName])
//        {
//            if (dict[@"showGlobalId"] != nil)
//            {
//                if ([dict[@"showGlobalId"] isEqualToString:currentShowGlobalId])
//                {
//                    [dict setObject:[[item attributeForName:@"id"] stringValue] forKey:@"itemId"];
//                    [messageArray addObject:dict];
//                }
//            }
//        }
//        else
//        {
//            [dict setObject:[[item attributeForName:@"id"] stringValue] forKey:@"itemId"];
//            [messageArray addObject:dict];
//        }
    }
    
//    [self handleMessagesForNode:node forMessages:messageArray withSuccess:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidRetrivePreviousItemsNotification object:node];
//        });
//    } andFailure:^(NSError *error) {
//        ////
//    }];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotReceivePreviousItemsForNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Messaging methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Normal message methods
//- (void)sendNormalMessageFromUser:(User *)fromUser toUser:(User *)toUser withText:(NSString *)text
//{
//    [self.xmppRoster subscribePresenceToUser:[XMPPJID jidWithString:toUser.jabberId]];
//    
//    dispatch_async(xmppQueue, ^{
//        XMPPUserMemoryStorageObject *user = [((XMPPRosterMemoryStorage *)self.xmppRoster.xmppRosterStorage) userForJID:[XMPPJID jidWithString:toUser.jabberId]];
//        
//        if (!user.isOnline)
//        {
//            // send notifications;
//            NSString *messageStr = [NSString stringWithFormat:@"%@: %@", fromUser.name, text];
//            NSDictionary *paramDict = @{@"alert_message": messageStr,
//                                        @"to_send_list": @[toUser.userId],
//                                        @"data": @{@"type": @(zNotificationTypeOneToOneChat),
//                                                   @"user_id": fromUser.userId}};
//            
//            [[DataManager sharedInstance] callAPIToSendNotifacationsWithParams:paramDict success:^{
//                // Do wat ever
//            } failure:^(NSError *error) {
//                // do wat ever
//            }];
//        }
//    });
//   
//    [self.xmppStream sendElement:[ZingMessageFactory getNormalMessageFromUser:fromUser
//                                                                       toUser:toUser
//                                                                     withText:text]];
//}

/*
- (void)sendCommentMessageFromUser:(User *)fromUser toUser:(User *)toUser withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment
{
    [self.xmppStream sendElement:[ZingMessageFactory getCommentMessageFromUser:fromUser
                                                                        toUser:toUser
                                                                   withComment:comment
                                                                 andSubComment:subComment]];
}

- (void)sendAnswerMessageFromUser:(User *)fromUser toUser:(User *)toUser withQustion:(Question *)question andAnswer:(Answer *)answer;
{
    [self.xmppStream sendElement:[ZingMessageFactory getAnswerMessageFromUser:fromUser
                                                                       toUser:toUser
                                                                  withQustion:question
                                                                    andAnswer:answer]];
}

// Groups chat methods
- (Group *)getCurrentGroupObjectForType:(GroupsType)type
{
    if (self.currentXMPPRoom == nil)
    {
        return nil;
    }
    
    NSPredicate *predicate = nil;
    if (type == GroupsTypeGlobal)
    {
        predicate = [NSPredicate predicateWithFormat:@"xmppGroupName == %@", [self.currentXMPPRoom.roomJID full]];
    }
    else
    {
        predicate = [NSPredicate predicateWithFormat:@"contextualXmppGroupName == %@", [self.currentXMPPRoom.roomJID full]];
    }
    
    return [Group MR_findFirstWithPredicate:predicate inContext:[[DataManager sharedInstance] mainContext]];
}
 */

//- (void)sendNormalMessageFromUser:(User *)fromUser toGroup:(Group *)group withText:(NSString *)text ofType:(GroupsType)type
//{
    /* Commented: Group chat notifications not implemented currently due to no proper flow discussion
    XMPPRoomMemoryStorage *storage = self.currentXMPPRoom.xmppRoomStorage;
    NSArray * members = [storage occupants];
    
    NSMutableArray *allMembersArray = [NSMutableArray arrayWithArray:[group.members allObjects]];
    [allMembersArray addObjectsFromArray:[group.owners allObjects]];
    
    NSMutableArray *userIdArray = [NSMutableArray array];
    for (User *user in allMembersArray)
    {
        [userIdArray addObject:user.userId];
    }
    
    for (XMPPRoomOccupantMemoryStorageObject *user in members)
    {
        NSArray *filteredArray = [allMembersArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", [user.presence.to bare]]];
        if (filteredArray > 0) {
            //
            User *member = filteredArray[0];
            DLog(@"found");
            [userIdArray removeObject:member.userId];
        }
        DLog(@"asdf %@", [user.jid full]);
    }
    
    NSDictionary *paramDict = @{@"alert_message": text,
                                @"to_send_list": userIdArray,
                                @"data": @{@"type": @(zNotificationTypeGroupChat),
                                           @"group_id": ([group.isContextualGroup boolValue])?group.contextualGroupId: group.groupId}};
    
    [[DataManager sharedInstance] callAPIToSendNotifacationsWithParams:paramDict success:^{
        //
    } failure:^(NSError *error) {
        //
    }];
     */
    
//    [self.xmppStream sendElement:[ZingMessageFactory getNormalMessageFromUser:fromUser
//                                                                      toGroup:group
//                                                                     withText:text
//                                                                       ofType:type]];
//}


- (void)sendNormalGroupMessageFromUser:(User *)fromUser withText:(NSString *)text ofType:(GroupsType)type
{
//    Group *groupObj = [self getCurrentGroupObjectForType:type];
//    if (groupObj != nil)
//    {
//        [self sendNormalMessageFromUser:fromUser
//                                toGroup:groupObj
//                               withText:text
//                                 ofType:type];
//    }
}

/*
- (void)sendCommentMessageFromUser:(User *)fromUser toGroup:(Group *)group withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment ofType:(GroupsType)type
{
    [self.xmppStream sendElement:[ZingMessageFactory getCommentMessageFromUser:fromUser
                                                                       toGroup:group
                                                                   withComment:comment
                                                                 andSubComment:subComment
                                                                        ofType:type]];
}

- (void)sendCommentGroupMessageFromUser:(User *)fromUser withComment:(Comment *)comment andSubComment:(CommentDetail *)subComment ofType:(GroupsType)type
{
    Group *groupObj = [self getCurrentGroupObjectForType:type];
    if (groupObj != nil)
    {
        [self sendCommentMessageFromUser:fromUser
                                 toGroup:groupObj
                             withComment:comment
                           andSubComment:subComment
                                  ofType:type];
    }
}

- (void)sendAnswerMessageFromUser:(User *)fromUser toGroup:(Group *)group withQustion:(Question *)question andAnswer:(Answer *)answer ofType:(GroupsType)type
{
    [self.xmppStream sendElement:[ZingMessageFactory getAnswerMessageFromUser:fromUser
                                                                      toGroup:group
                                                                  withQustion:question
                                                                    andAnswer:answer
                                                                       ofType:type]];
}

- (void)sendAnswerGroupMessageFromUser:(User *)fromUser withQustion:(Question *)question andAnswer:(Answer *)answer ofType:(GroupsType)type
{
    Group *groupObj = [self getCurrentGroupObjectForType:type];
    if (groupObj != nil)
    {
        [self sendAnswerMessageFromUser:fromUser
                                toGroup:groupObj
                            withQustion:question
                              andAnswer:answer
                                 ofType:type];
    }
}

- (void)sendPresenceMessageFromUser:(User *)fromUser toGroup:(Group *)group ofType:(GroupsType)type forPresenceType:(PresenceType)presenceType
{
    [self.xmppStream sendElement:[ZingMessageFactory getPresenceMessageFromUser:fromUser
                                                                        toGroup:group
                                                                         ofType:type
                                                                forPresenceType:presenceType]];
}

- (void)sendPresenceMessageFromUser:(User *)fromUser ofType:(GroupsType)type forPresenceType:(PresenceType)presenceType
{
    Group *groupObj = [self getCurrentGroupObjectForType:type];
    if (groupObj != nil)
    {
        [self sendPresenceMessageFromUser:fromUser
                                  toGroup:groupObj
                                   ofType:type
                          forPresenceType:presenceType];
    }
}

- (void)sendPresenceMessageFromUser:(User *)fromUser toUser:(User *)toUser forPresenceType:(PresenceType)presenceType
{    
    [self.xmppStream sendElement:[ZingMessageFactory getPresenceMessageFromUser:fromUser
                                                                        toUser:toUser
                                                                forPresenceType:presenceType]];
}
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	if (allowSelfSignedCertificates)
	{
		[settings setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	if (allowSSLHostNameMismatch)
	{
		[settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
	}
	else
	{
		NSString *expectedCertName = [self.xmppStream.myJID domain];
        
		if (expectedCertName)
		{
			[settings setObject:expectedCertName forKey:(NSString *)kCFStreamSSLPeerName];
		}
	}
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	isXmppConnected = YES;
	
	NSError *error = nil;
	
	if (![[self xmppStream] authenticateWithPassword:password error:&error])
	{
		DDLogError(@"Error authenticating: %@", error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerDidConnectNotification object:nil];
    });
    
	[self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerDidFailedToConnectNotification object:nil];
    });
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message
{
    // check for type of message if one to one chat message or group message
//    if ([message isChatMessage])
//    {
//        NSManagedObjectContext *context = [[DataManager sharedInstance] mainContext];
//        NSString *fromJabberId = [[[message fromStr] componentsSeparatedByString:@"/"] firstObject];
//        User *fromUser = [User MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", fromJabberId] inContext:context];
//        
//        [context performBlock:^{
//            Message *messageObj = [Message MR_createInContext:context];
//            
//            messageObj.userFrom = fromUser;
//            NSString *toJabberId = [[[message toStr] componentsSeparatedByString:@"/"] firstObject];
//            User *toUser = [User MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", toJabberId] inContext:context];
//            messageObj.userTo = toUser;
//            
//            NSXMLElement *body = [message elementForName:@"body"];
//            NSDictionary *dictionary = [ZingMessageFactory getDictionaryForString:[body stringValue]];
//            
//            messageObj.timeStamp = dictionary[@"timestamp"];
//            
//            if ([dictionary[@"type"] isEqualToString:@"normal"])
//            {
//                if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//                {
//                    messageObj.type = @(MessageTypeOutgoingNormal);
//                }
//                else
//                {
//                    messageObj.type = @(MessageTypeIncomingNormal);
//                }
//                
//                messageObj.messageText = dictionary[@"messagedata"];
//            }
//            else if ([dictionary[@"type"] isEqualToString:@"comment"])
//            {
//                if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//                {
//                    messageObj.type = @(MessageTypeOutgoingComment);
//                }
//                else
//                {
//                    messageObj.type = @(MessageTypeIncomingComment);
//                }
//                
//                NSString *comment = dictionary[@"comment"];
//                NSString *commentDetail = dictionary[@"subcomment"];
//                messageObj.messageText = [NSString stringWithFormat:@"%@, %@", comment, commentDetail];
//            }
//            else if ([dictionary[@"type"] isEqualToString:@"question"])
//            {
//                if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//                {
//                    messageObj.type = @(MessageTypeOutgoingAnswer);
//                }
//                else
//                {
//                    messageObj.type = @(MessageTypeIncomingAnswer);
//                }
//                
//                NSString *question = dictionary[@"question"];
//                NSString *answer = dictionary[@"answer"];
//                messageObj.messageText = [NSString stringWithFormat:@"%@, %@", question, answer];
//            }
//            else if ([dictionary[@"type"] isEqualToString:@"presence"])
//            {
//                messageObj.type = @(MessageTypePresence);
//                messageObj.messageText = dictionary[@"message"];
//            }
//            
//            [[DataManager sharedInstance] saveAllWithContext:context success:^{
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    // A simple example of inbound message handling.
//                    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerDidSendMessageNotification object:message];
//                });
//            } failure:^(NSError *error) {
//                //
//            }];
//        }];
//    }
//    else if ([[[message attributeForName:@"type"] stringValue] isEqualToString:@"groupchat"])
//    {
//        NSString *toStr = [message toStr];
//        for (int i = 0; i < [self.chatRoomsArray count]; i++)
//        {
//            XMPPRoom *room = self.chatRoomsArray[i];
//            if ([[room.roomJID full] isEqualToString:toStr])
//            {
//                [self.storage handleOutgoingMessage:message room:room];
//                break;
//            }
//        }
//    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
//    // check for type of message if one to one chat message or group message
//    if ([message isChatMessage])
//    {
//        NSString *fromJabberId = [[[message fromStr] componentsSeparatedByString:@"/"] firstObject];
//        User *fromUser = [User MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", fromJabberId] inContext:[[DataManager sharedInstance] mainContext]];
//        
//        if (fromUser == nil)
//        {
//            NSString *paramStr = [NSString stringWithFormat:@"jabber_id=%@",message.fromStr];
//            typeof(self) __weak weakself = self;
//            [[DataManager sharedInstance] callApiToGetUserDetailWithParams:@{@"value": paramStr} success:^(id responseObject) {
//                //
//                User *user = responseObject;
//                [weakself handleOneToOneMessage:message fromUser:user];
//            } failure:^(NSError *error) {
//                //
//            }];
//        }
//        else
//        {
//            [self handleOneToOneMessage:message fromUser:fromUser];
//        }
//    }
//    else
//    {
//        // check if the message is from chat room
//    }
}

- (void)handleToastMessage:(XMPPMessage *)message
{
//    NSDictionary *messageDict = [ZingMessageFactory getDictionaryForString:message.body];
//    if ([messageDict[@"type"] isEqualToString:@"normal"])
//    {
//        User *userObj = [User MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", message.fromStr] inContext:[[DataManager sharedInstance] mainContext]];
//        if (userObj == nil) // This condition should not happen as this will be checked while displaying the toast
//        {
//            // get the userobj
//            NSString *paramStr = [NSString stringWithFormat:@"jabber_id=%@",message.fromStr];
//            typeof(self) __weak weakself = self;
//            [[DataManager sharedInstance] callApiToGetUserDetailWithParams:@{@"value": paramStr} success:^(id responseObject) {
//                //
//                User *user = responseObject;
//                ToastMessageView *toast = [[ToastMessageView alloc] initWithFrame:CGRectMake(0.0, -ToastHeight, 320, ToastHeight)];
//                toast.currentUser = user;
//                [toast.messageLabel setText:[NSString stringWithFormat:@"%@: %@", user.name, messageDict[@"messagedata"]]];
//                [[[UIApplication sharedApplication] keyWindow] addSubview:toast];
//                
//                [UIView animateWithDuration:0.2 animations:^{
//                    [toast setFrame:CGRectMake(0.0, 0.0, 320, ToastHeight)];
//                } completion:^(BOOL finished) {
//                    if (finished) {
//                        [weakself performSelector:@selector(removeToast:) withObject:toast afterDelay:3.0];
//                    }
//                }];
//            } failure:^(NSError *error) {
//                //
//            }];
//        }
//        else if (![self.currentUserObject.userId isEqualToNumber:userObj.userId])
//        {
//            ToastMessageView *toast = [[ToastMessageView alloc] initWithFrame:CGRectMake(0.0, -ToastHeight, 320, ToastHeight)];
//            toast.currentUser = userObj;
//            [toast.messageLabel setText:[NSString stringWithFormat:@"%@: %@", userObj.name, messageDict[@"messagedata"]]];
//            [[[UIApplication sharedApplication] keyWindow] addSubview:toast];
//            
//            [UIView animateWithDuration:0.2 animations:^{
//                [toast setFrame:CGRectMake(0.0, 0.0, 320, ToastHeight)];
//            } completion:^(BOOL finished) {
//                if (finished) {
//                    [self performSelector:@selector(removeToast:) withObject:toast afterDelay:3.0];
//                }
//            }];
//        }
//    }
}

- (void)handleOneToOneMessage:(XMPPMessage *)message fromUser:(User *)fromUser
{
//    NSManagedObjectContext *context = [[DataManager sharedInstance] mainContext];
//    [context performBlock:^{
//        Message *messageObj = [Message MR_createInContext:context];
//        messageObj.userFrom = fromUser;
//        NSString *toJabberId = [[[message toStr] componentsSeparatedByString:@"/"] firstObject];
//        User *toUser = [User MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"jabberId == %@", toJabberId] inContext:context];
//        messageObj.userTo = toUser;
//        
//        NSXMLElement *body = [message elementForName:@"body"];
//        NSDictionary *dictionary = [ZingMessageFactory getDictionaryForString:[body stringValue]];
//        
//        messageObj.timeStamp = dictionary[@"timestamp"];
//        
//        if ([dictionary[@"type"] isEqualToString:@"normal"])
//        {
//            if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//            {
//                messageObj.type = @(MessageTypeOutgoingNormal);
//            }
//            else
//            {
//                messageObj.type = @(MessageTypeIncomingNormal);
//            }
//            messageObj.messageText = dictionary[@"messagedata"];
//        }
//        else if ([dictionary[@"type"] isEqualToString:@"comment"])
//        {
//            if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//            {
//                messageObj.type = @(MessageTypeOutgoingComment);
//            }
//            else
//            {
//                messageObj.type = @(MessageTypeIncomingComment);
//            }
//            
//            NSString *comment = dictionary[@"comment"];
//            NSString *commentDetail = dictionary[@"subcomment"];
//            messageObj.messageText = [NSString stringWithFormat:@"%@, %@", comment, commentDetail];
//        }
//        else if ([dictionary[@"type"] isEqualToString:@"question"])
//        {
//            if ([fromUser.userId isEqualToNumber:@([[SessionManager sharedInstance].currentSession.userId doubleValue])])
//            {
//                messageObj.type = @(MessageTypeOutgoingAnswer);
//            }
//            else
//            {
//                messageObj.type = @(MessageTypeIncomingAnswer);
//            }
//            
//            NSString *question = dictionary[@"question"];
//            NSString *answer = dictionary[@"answer"];
//            messageObj.messageText = [NSString stringWithFormat:@"%@, %@", question, answer];
//        }
//        else if ([dictionary[@"type"] isEqualToString:@"presence"])
//        {
//            messageObj.type = @(MessageTypePresence);
//            messageObj.messageText = dictionary[@"message"];
//        }
//        
//        [[DataManager sharedInstance] saveAllWithContext:context success:^{
//            dispatch_async(dispatch_get_main_queue(), ^{
//                // A simple example of inbound message handling.
//                [self handleToastMessage:message];
//                
//                [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerDidRecieveMessageNotification object:message];
//            });
//        } failure:^(NSError *error) {
//            //
//        }];
//    }];
}

- (void)removeToast:(UIView *)sender
{
    [UIView animateWithDuration:0.2 animations:^{
        [sender setFrame:CGRectMake(0.0, -ToastHeight, 320.0, ToastHeight)];
    } completion:^(BOOL finished) {
        if (finished) {
            [sender removeFromSuperview];
        }
    }];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [presence fromStr]);
    
    NSXMLElement *x = [presence elementForName:@"x" xmlns:@"http://jabber.org/protocol/muc"];
    for (NSXMLElement *status in [x elementsForName:@"status"])
    {
        switch ([status attributeIntValueForName:@"code"])
        {
            case 201: break;
        }
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerDidDisconnectNotification object:nil];
    });
    
	if (!isXmppConnected)
	{
		DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPRosterDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoster:(XMPPRoster *)sender didReceiveBuddyRequest:(XMPPPresence *)presence
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	XMPPUserCoreDataStorageObject *user = nil; // [self.xmppRosterStorage userForJID:[presence from]
//	                                                         xmppStream:self.xmppStream
//	                                               managedObjectContext:[self managedObjectContext_roster]];
	
	NSString *displayName = [user displayName];
	NSString *jidStrBare = [presence fromStr];
	NSString *body = nil;
	
	if (![displayName isEqualToString:jidStrBare])
	{
		body = [NSString stringWithFormat:@"Buddy request from %@ <%@>", displayName, jidStrBare];
	}
	else
	{
		body = [NSString stringWithFormat:@"Buddy request from %@", displayName];
	}
	
	
	if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:displayName
		                                                    message:body
		                                                   delegate:nil
		                                          cancelButtonTitle:@"Not implemented"
		                                          otherButtonTitles:nil];
		[alertView show];
	}
	else
	{
		// We are not active, so use a local notification instead
		UILocalNotification *localNotification = [[UILocalNotification alloc] init];
		localNotification.alertAction = @"Not implemented";
		localNotification.alertBody = body;
		
		[[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
	}
	
}

- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender
{
    
}

- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    [sender acceptPresenceSubscriptionRequestFrom:presence.from andAddToRoster:YES];
}

- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender
{
    XMPPPresence *available = [XMPPPresence presence];
    [[[XMPPManager sharedInstance] xmppStream] sendElement:available];
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item
{
    NSDictionary *attribs = item.attributesAsDictionary;
    if([attribs objectForKey:@"ask"] == nil &&
       ([[attribs objectForKey:@"subscription"] isEqualToString:@"from"] ||
        [[attribs objectForKey:@"subscription"] isEqualToString:@"none"] )
       ) {
        [sender subscribePresenceToUser:[XMPPJID jidWithString:attribs[@"jid"]]];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - XMPPRoomDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppRoomDidDestroy:(XMPPRoom *)sender
{
    
}

- (void)xmppRoomDidLeave:(XMPPRoom *)sender
{
    [sender removeDelegate:self delegateQueue:xmppQueue];
    self.currentXMPPRoom = nil;
    if ([self.chatRoomsArray count] > 0)
    {
        [self.chatRoomsArray removeObject:sender];
    }
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerRoomDidLeaveNotification object:sender];
//    });
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    [self.chatRoomsArray addObject:sender];
    self.currentXMPPRoom = sender;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerRoomDidJoinNotification object:sender];
    });
}

- (void)xmppRoomDidCreate:(XMPPRoom *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    [sender fetchConfigurationForm];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerRoomDidCreateNotification object:sender];
    });
}

- (void)xmppRoom:(XMPPRoom *)sender didFetchConfigurationForm:(NSXMLElement *)configForm
{
//    NSXMLElement *newConfig = [configForm copy];
//    NSArray* fields = [newConfig elementsForName:@"field"];
//    
//    BOOL isfound = NO;
//    for (NSXMLElement *field in fields) {
//        NSString *var = [field attributeStringValueForName:@"var"];
//        if ([var isEqualToString:@"muc#roomconfig_persistentroom"]) {
//            [field removeChildAtIndex:0];
//            [field addChild:[NSXMLElement elementWithName:@"value" stringValue:@"1"]];
//        }
//        else if ([var isEqualToString:@"muc#roomconfig_roomowners"])
//        {
//            isfound = YES;
//            
//            [field removeChildAtIndex:0];
//            [field addChild:[NSXMLElement elementWithName:@"value" stringValue:[self.xmppStream.myJID bare]]];
//            NSString *adminJid = [[[SessionManager sharedInstance] currentSettings] adminUserJabberId];
//            if (adminJid != nil) {
//                [field addChild:[NSXMLElement elementWithName:@"value" stringValue:adminJid]];
//            }
//        }
//    }
//    
//    if (!isfound)
//    {
//        NSXMLElement *field = [NSXMLElement elementWithName:@"field"];
//        [field addAttributeWithName:@"var" stringValue:@"muc#roomconfig_roomowners"];
//        
//        [field addChild:[NSXMLElement elementWithName:@"value" stringValue:[self.xmppStream.myJID bare]]];
//        NSString *adminJid = [[[SessionManager sharedInstance] currentSettings] adminUserJabberId];
//        if (adminJid != nil) {
//            [field addChild:[NSXMLElement elementWithName:@"value" stringValue:adminJid]];
//        }
//        
//        [newConfig addChild:field];
//    }
//    
//    [sender configureRoomUsingOptions:newConfig];
}

- (void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromOccupant:(XMPPJID *)occupantJID
{
//    NSXMLElement *body = [message elementForName:@"body"];
//    NSDictionary *dict = [ZingMessageFactory getDictionaryForString:[body stringValue]];
//    if (dict != nil)
//    {
//        [self handleIncomingMessage:message forRoom:sender];
//    }
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidJoin:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence
{
//    DLog(@"%@ %@", [[occupantJID full] componentsSeparatedByString:@"/"][1], [presence type]);
//    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSDictionary *dictionary = @{@"XMPPRoom": sender,
//                                     @"occupantJID": occupantJID,
//                                     @"presence": presence};
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerUserDidJoinRoomNotification object:dictionary];
//    });
    
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidLeave:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence
{
//    DLog(@"%@ %@", [[occupantJID full] componentsSeparatedByString:@"/"][1], [presence type]);
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSDictionary *dictionary = @{@"XMPPRoom": sender,
//                                     @"occupantJID": occupantJID,
//                                     @"presence": presence};
//        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerUserDidLeaveRoomNotification object:dictionary];
//    });
}

- (void)xmppRoom:(XMPPRoom *)sender didConfigure:(XMPPIQ *)iqResult
{
//    DLog(@"xmppRoom  didConfigure");
}

- (void)xmppRoom:(XMPPRoom *)sender didNotConfigure:(XMPPIQ *)iqResult
{
//    DLog(@"xmppRoom  didNotConfigure");
}

#pragma mark - XMPPRoomRelated methods
//- (void)createChatRoomForGroup:(Group *)group ofType:(GroupsType)type
//{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        NSManagedObjectContext *context = self.storage.mainThreadManagedObjectContext;
//        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:self.storage.messageEntityName];
//        
//        if (type == GroupsTypeContextual) {
//            [request setPredicate:[NSPredicate predicateWithFormat:@"roomJIDStr == %@", group.contextualXmppGroupName]];
//        }
//        else
//        {
//            [request setPredicate:[NSPredicate predicateWithFormat:@"roomJIDStr == %@", group.xmppGroupName]];
//        }
//        
//        NSError *err = nil;
//        NSArray *messages = [context executeFetchRequest:request error:&err];
//        
//        [messages enumerateObjectsUsingBlock:^(XMPPRoomMessageCoreDataStorageObject *obj, NSUInteger idx, BOOL *stop) {
//            [context deleteObject:obj];
//        }];
//        
//        if (![context save:&err]) {
//            NSLog(@"eror");
//        }
//    });
//    
//    NSString *userName = [[[SessionManager sharedInstance] currentSession] username];
//    
//    XMPPRoomMemoryStorage *roomMemoryStorage = [[XMPPRoomMemoryStorage alloc] init];
//    // <history maxstanzas='100'/>
//    NSXMLElement *history = [NSXMLElement elementWithName:@"history"];
//    [history addAttributeWithName:@"maxstanzas" stringValue:@"100"];
//    
//    NSString *groupName = group.xmppGroupName;
//    if (type == GroupsTypeContextual)
//    {
//        groupName = group.contextualXmppGroupName;
//    }
//    
//    XMPPRoom *xmppRoom = [[XMPPRoom alloc] initWithRoomStorage:roomMemoryStorage jid:[XMPPJID jidWithString:groupName] dispatchQueue:xmppQueue];
//    [xmppRoom activate:[self xmppStream]];
//    [xmppRoom addDelegate:self delegateQueue:xmppQueue];
//    [xmppRoom joinRoomUsingNickname:userName history:nil password:nil];
//}

- (NSArray *)getChatRoomMessagesForRoom:(XMPPRoom *)chatRoom
{
    NSManagedObjectContext *context = self.storage.mainThreadManagedObjectContext;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:self.storage.messageEntityName];
    [request setPredicate:[NSPredicate predicateWithFormat:@"roomJIDStr == %@", [chatRoom.roomJID full]]];
    [request setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"customTimeStamp" ascending:YES]]];
    request.returnsDistinctResults = YES;
    NSError *err = nil;
    NSArray *messages = [context executeFetchRequest:request error:&err];
    return messages;
}

- (void)clearAllMessages
{
    
}

- (void)handleOutGoingMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room
{
    [self.storage handleOutgoingMessage:message room:room];
}

- (void)handleIncomingMessage:(XMPPMessage *)message forRoom:(XMPPRoom *)room
{
    [self.storage handleIncomingMessage:message room:room];
}

- (void)XMPPMessageDidInserted:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerRoomDidRecieveMessageNotification object:nil];
    });
}
@end
