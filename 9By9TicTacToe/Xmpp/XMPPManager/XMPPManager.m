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
        
#ifdef DEBUG
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
#endif
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
    
    
    NSString *myJID = @"yourJid";
	NSString *myPassword = @"yourJpwd";
    
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

- (void)sendNodeDeletionFromUser:(User *)fromUser forNode:(NSString *)forNode toNode:(NSString *)node
{
    [self.currentPubsub publishToNode:node entry:nil];
}

- (void)sendShowSelectionFromUser:(User *)fromUser toNode:(NSString *)node withPresence:(PresenceType)type forNode:(NSString *)forNode
{
    [self.currentPubsub publishToNode:node entry:nil];
}

- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node withMessageStr:(NSString *)messageStr
{
    [self.currentPubsub publishToNode:node entry:nil];
}

- (void)sendMessageToPubsubFromUser:(User *)fromUser toNode:(NSString *)node
{
    [self.currentPubsub publishToNode:node entry:nil];
}

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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidSubscribeNotification object:node];
}

- (void)getPreviousItemsForNode:(NSString *)node
{
    [self.currentPubsub retrivePreviousItemsForNode:node];
}

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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidCreateNotification object:node];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotCreateNode:(NSString *)node withError:(XMPPIQ *)iq
{
    
}

- (void)xmppPubSub:(XMPPPubSub *)sender didSubscribeToNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self handleSubscriptionForNode:node withResult:YES];
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
            [self handleSubscriptionForNode:node withResult:NO];
        }
    }
    else
    {
        [self handleSubscriptionForNode:node withResult:NO];
    }
}

- (void)xmppPubSub:(XMPPPubSub *)sender didUnsubscribeFromNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self.subscribedPubsubNodeArray removeObject:node];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidUnSubscribeNotification object:node];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotUnsubscribeFromNode:(NSString *)node withError:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidUnSubscribeNotification object:node];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didDeleteNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    [self.publisherPubsubNodeArray removeObject:node];
    [self sendNodeDeletionFromUser:nil forNode:node toNode:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidDeleteNotification object:node];
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
    
    NSString *nodeName = nil;
    NSDictionary *dictionary = nil;
    
    // If the sender is the current user then no need to save
    NSString *senderStr = [dictionary[@"sender"] lowercaseString];
    NSString *resultNode = nil;
    if ([senderStr isEqualToString:[[self.xmppStream.myJID bare] lowercaseString]] && ![resultNode isEqualToString:nodeName])
    {
        return;
    }
    
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    [newDict setObject:[[itemElement attributeForName:@"id"] stringValue] forKey:@"itemId"];
    
    NSString *currentShowGlobalId = nil;
    NSString *adminNodeName = nil;
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
        User *currentUser = nil;
        
        // check if the node is already subscribed for followed celeb joined now
        NSArray *filterArray = nil;
        
        if ([filterArray count] == 0)
        {
            // user is not there in followed list so dont do anything
            return;
        }
        else
        {
            filterArray = nil;
            if ([filterArray count] == 0)
            {
                return;
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidRecieveMessageNotification object:sender];
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
        [self handleSubscriptionForNode:node withResult:YES];
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
        NSString *currentShowGlobalId = nil;
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:nil];
        
        NSString *adminNodeName = nil;
        if ([node isEqualToString:adminNodeName])
        {
            if (dict[@"showGlobalId"] != nil)
            {
                if ([dict[@"showGlobalId"] isEqualToString:currentShowGlobalId])
                {
                    [dict setObject:[[item attributeForName:@"id"] stringValue] forKey:@"itemId"];
                    [messageArray addObject:dict];
                }
            }
        }
        else
        {
            [dict setObject:[[item attributeForName:@"id"] stringValue] forKey:@"itemId"];
            [messageArray addObject:dict];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XMPPManagerPubsubDidRetrivePreviousItemsNotification object:node];
}

- (void)xmppPubSub:(XMPPPubSub *)sender didNotReceivePreviousItemsForNode:(NSString *)node withResult:(XMPPIQ *)iq
{
    // TODO: Need to check if fail notifications needed
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Messaging methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
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
@end
