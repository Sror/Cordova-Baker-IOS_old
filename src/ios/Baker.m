#import "Baker.h"
#import "IssueController.h"
#import "Constants.h"
#import "BakerAPI.h"
#import "IssuesManager.h"
#import "ShelfController.h"

NSString * const kBakerEventsType[] = {
    @"BakerApplicationReady",
    @"BakerIssueDeleted",
    @"BakerIssueAdded",
    @"BakerIssueStateChanged",
    @"BakerIssueDownloadProgress",
    @"BakerIssueCoverReady",
    @"BakerRefreshStateChanged",
};

@implementation Baker

@synthesize notificationMessage;
@synthesize shelfController;
@synthesize eventHandlerCallbackId;

- (void)setup: (CDVInvokedUrlCommand*)command
{
    #ifdef BAKER_NEWSSTAND
    NSLog(@"====== Baker Newsstand Mode enabled  ======");
    [BakerAPI generateUUIDOnce];
    // Let the device know we want to handle Newsstand push notifications
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeNewsstandContentAvailability |UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];

    #ifdef DEBUG
    // For debug only... so that you can download multiple issues per day during development
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NKDontThrottleNewsstandContentNotifications"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    #endif

   #endif

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createNotificationChecker:)
               name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
    

    self.shelfController = [[[ShelfController alloc] init] autorelease];

    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerApplicationStart" object:self];
}

+ (NSArray *)eventsType
{
    static NSArray *events;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        events = [NSArray arrayWithObjects:kBakerEventsType count:7];
    });
    
    return events;
}
- (void)startEventHandler:(CDVInvokedUrlCommand*)command
{
    self.eventHandlerCallbackId = command.callbackId;
    
    for (NSString *eventName in [Baker eventsType]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleReceiveEvent:)
                                                     name:eventName
                                                   object:nil];
    }

}

- (void)handleReceiveEvent:(NSNotification *)notification {
    if (!self.eventHandlerCallbackId) {
        return;
    }
    
    CDVPluginResult* result = nil;
    // NSLog(@"[Baker Event] received event %@", [notification name]);
    if ([[notification name] isEqualToString:@"BakerApplicationReady"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerIssueStateChanged"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerIssueDownloadProgress"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerIssueCoverReady"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerRefreshStateChanged"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerIssueAdded"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else if ([[notification name] isEqualToString:@"BakerIssueDeleted"]) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[notification name],@"eventType", [notification object], @"data", nil]];
    } else {
        
    }

    
    if (result) {
        [result setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:result callbackId:self.eventHandlerCallbackId];
    }
    
}

- (void)stopEventHandler:(CDVInvokedUrlCommand*)command
{
    // callback one last time to clear the callback function on JS side
    if (self.eventHandlerCallbackId) {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"clear"];
        [result setKeepCallbackAsBool:NO];
        [self.commandDelegate sendPluginResult:result callbackId:self.eventHandlerCallbackId];
    }
    self.eventHandlerCallbackId = nil;
    for (NSString *eventName in [Baker eventsType]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:eventName
                                                   object:nil];
    }
}

- (void)restore: (CDVInvokedUrlCommand*)command
{
    [[PurchasesManager sharedInstance] restore];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)refresh: (CDVInvokedUrlCommand*)command
{
    [self.shelfController handleRefresh:nil];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getBooks: (CDVInvokedUrlCommand*)command
{
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (BakerIssue *issue in [self.shelfController issues]) {
        [data addObject:[Baker issueToDictionnary:issue]];
    }

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:data];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)purchase: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString* bookId = [command.arguments objectAtIndex:0];
    IssueController *currentBook = [self getIssueControllerById:bookId];
    
    if (currentBook) {
        [currentBook buy];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ERROR"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)download: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString* bookId = [command.arguments objectAtIndex:0];
    IssueController *currentBook = [self getIssueControllerById:bookId];
    if (currentBook) {
        [currentBook download];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } else {
        pluginResult= [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ERROR"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)archive: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString* bookId = [command.arguments objectAtIndex:0];
    IssueController *currentBook = [self getIssueControllerById:bookId];
    if (currentBook) {
        [currentBook archive];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ERROR"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getBookInfos: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString* bookId = [command.arguments objectAtIndex:0];

    IssueController *currentBook = [self getIssueControllerById:bookId];
    if (currentBook) {
        NSDictionary *bookDatas = [self getBookJson:currentBook.issue];

        if (bookDatas) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:bookDatas];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ERROR"];
        }
        
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"ERROR"];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSDictionary *) getBookJson:(BakerIssue *)issue
{
    NSString *bookJSONPath = [issue.path stringByAppendingPathComponent:@"book.json"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:bookJSONPath]) {
        return nil;
    } 
    NSError* error = nil;
    NSData* bookJSON = [NSData dataWithContentsOfFile:bookJSONPath options:0 error:&error];
    if (error) {
        NSLog(@"[BakerBook] ERROR reading 'book.json': %@", error.localizedDescription);
        return nil;
    } 

    NSDictionary* bookData = [NSJSONSerialization JSONObjectWithData:bookJSON
                                                         options:0
                                                           error:&error];
    if (error) {
        NSLog(@"[BakerBook] ERROR parsing 'book.json': %@", error.localizedDescription);
        return nil;
    }

    return bookData;
}


- (IssueController *) getIssueControllerById:(NSString *)bookId
{
    IssueController *currentBook = nil;
    for (IssueController *issueController in [self.shelfController issueViewControllers]) {
        if ([issueController.issue.ID isEqualToString:bookId]) {
            currentBook = issueController;
            break;
        }
    }
    return currentBook;
}

+ (NSDictionary *)issueToDictionnary:(BakerIssue *)issue
{
    NSString *coverPath = issue.coverPath;
    if (![[NSFileManager defaultManager] fileExistsAtPath:coverPath]) {
        coverPath = nil;
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:issue.ID,@"ID",issue.title,@"title",issue.info,@"info",issue.date,@"date", issue.getStatus, @"status", [issue.url absoluteString], @"url", issue.path, @"path", issue.productID, @"productID", issue.price, @"price",[issue.coverURL absoluteString], @"coverURL", coverPath, @"coverPath", nil];
}


- (void)applicationWillHandleNewsstandNotificationOfContent:(NSString *)contentName
{
    NSLog(@"will handle newsstand notifications");
    #ifdef BAKER_NEWSSTAND
    IssuesManager *issuesManager = [IssuesManager sharedInstance];
    PurchasesManager *purchasesManager = [PurchasesManager sharedInstance];
    __block BakerIssue *targetIssue = nil;

    [issuesManager refresh:^(BOOL status) {
        if (contentName) {
            for (BakerIssue *issue in issuesManager.issues) {
                if ([issue.ID isEqualToString:contentName]) {
                    targetIssue = issue;
                    break;
                }
            }
        } else {
            targetIssue = [issuesManager.issues objectAtIndex:0];
        }

        [purchasesManager retrievePurchasesFor:[issuesManager productIDs] withCallback:^(NSDictionary *_purchases) {

            NSString *targetStatus = [targetIssue getStatus];
            NSLog(@"[AppDelegate] Push Notification - Target status: %@", targetStatus);

            if ([targetStatus isEqualToString:@"remote"] || [targetStatus isEqualToString:@"purchased"]) {
                [targetIssue download];
            } else if ([targetStatus isEqualToString:@"purchasable"] || [targetStatus isEqualToString:@"unpriced"]) {
                NSLog(@"[AppDelegate] Push Notification - You are not entitled to download issue '%@', issue not purchased yet", targetIssue.ID);
            } else if (![targetStatus isEqualToString:@"remote"]) {
                NSLog(@"[AppDelegate] Push Notification - Issue '%@' in download or already downloaded", targetIssue.ID);
            }
        }];
    }];
    #endif
}

- (void)createNotificationChecker:(NSNotification *)notification
{
    NSLog(@"create notification checker");
    // Check if the app is runnig in response to a notification
        NSDictionary *launchOptions = [notification userInfo] ;
    NSDictionary *payload = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (payload) {
        NSDictionary *aps = [payload objectForKey:@"aps"];
        if (aps && [aps objectForKey:@"content-available"]) {

            __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
            }];

            // Credit where credit is due. This semaphore solution found here:
            // http://stackoverflow.com/a/4326754/2998
            dispatch_semaphore_t sema = NULL;
            sema = dispatch_semaphore_create(0);

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self applicationWillHandleNewsstandNotificationOfContent:[payload objectForKey:@"content-name"]];
                [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
                backgroundTask = UIBackgroundTaskInvalid;
                dispatch_semaphore_signal(sema);
            });

            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            dispatch_release(sema);
        }
    }
}

#ifdef BAKER_NEWSSTAND
- (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    NSString *apnsToken = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    apnsToken = [apnsToken stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSLog(@"[AppDelegate] My token (as NSData) is: %@", deviceToken);
    NSLog(@"[AppDelegate] My token (as NSString) is: %@", apnsToken);

    [[NSUserDefaults standardUserDefaults] setObject:apnsToken forKey:@"apns_token"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    BakerAPI *api = [BakerAPI sharedInstance];
    [api postAPNSToken:apnsToken];
}
#endif

- (void)didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    NSLog(@"[AppDelegate] Push Notification - Device Token, review: %@", error);
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    #ifdef BAKER_NEWSSTAND
    NSDictionary *aps = [userInfo objectForKey:@"aps"];
    if (aps && [aps objectForKey:@"content-available"]) {
        [self applicationWillHandleNewsstandNotificationOfContent:[userInfo objectForKey:@"content-name"]];
    }
    #endif
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

  #ifdef BAKER_NEWSSTAND
  // Opening the application means all new items can be considered as "seen".
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
  #endif


}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

  #ifdef BAKER_NEWSSTAND
  // Everything that happened while the application was opened can be considered as "seen"
  [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
  #endif

}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"applicationWillResignActiveNotification" object:nil];
}

@end
