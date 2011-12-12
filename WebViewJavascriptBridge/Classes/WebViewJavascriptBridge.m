#import "WebViewJavascriptBridge.h"

@interface WebViewJavascriptBridge ()

@property (readwrite,retain) NSMutableArray* startupMessageQueue;

- (void) _flushMessageQueueFromWebView: (UIWebView *) theWebView;
- (void) _doSendMessage:(NSString*)message toWebView:(UIWebView *) theWebView;

@end

@implementation WebViewJavascriptBridge

@synthesize delegate = _delegate;
@synthesize startupMessageQueue = _startupMessageQueue;
@synthesize jsObjectName = _jsObjectName;
@synthesize jsObjectMethodName = _jsObjectMethodName;

static NSString* MESSAGE_SEPERATOR = @"__wvjb_sep__";
static NSString* CUSTOM_PROTOCOL_SCHEME = @"webviewjavascriptbridge";
static NSString* QUEUE_HAS_MESSAGE = @"queuehasmessage";

+ (id) javascriptBridge
{
    return [[[self alloc] init] autorelease];
}

- (id) init
{
    if ( (self = [super init]) )
    {
        self.startupMessageQueue = [[NSMutableArray new] autorelease];
        self.jsObjectName = @"WebViewJavascriptBridge";
        self.jsObjectMethodName = @"sendMessage";
    }
    
    return self;
}

- (void) dealloc
{
    self.delegate = nil;
    self.startupMessageQueue = nil;
    
    [super dealloc];
}

- (void)sendMessage:(NSString *)message toWebView: (UIWebView *) theWebView {
    if (self.startupMessageQueue) { [self.startupMessageQueue addObject:message]; }
    else { [self _doSendMessage:message toWebView: theWebView]; }
}

- (void)_doSendMessage:(NSString *)message toWebView: (UIWebView *) aWebView {
	message = [message stringByReplacingOccurrencesOfString:@"\\n" withString:@"\\\\n"];
	message = [message stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
	message = [message stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    [aWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"WebViewJavascriptBridge._handleMessageFromObjC('%@');", message]];
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView {
    NSMutableString* js = nil;
    js = [NSMutableString stringWithFormat:@";(function() {"
          "if (window.%@) { return; };"
          "var _readyMessageIframe,"
          "     _sendMessageQueue = [],"
          "     _receiveMessageQueue = [],"
          "     _MESSAGE_SEPERATOR = '%@',"
          "     _CUSTOM_PROTOCOL_SCHEME = '%@',"
          "     _QUEUE_HAS_MESSAGE = '%@';"
          ""
          "function _createQueueReadyIframe(doc) {"
          "     _readyMessageIframe = doc.createElement('iframe');"
          "     _readyMessageIframe.style.display = 'none';"
          "     doc.documentElement.appendChild(_readyMessageIframe);"
          "}"
          ""
          "function _sendMessage(message) {"
          "     _sendMessageQueue.push(message);"
          "     _readyMessageIframe.src = _CUSTOM_PROTOCOL_SCHEME + '://' + _QUEUE_HAS_MESSAGE;"
          "};"
          ""
          "function _fetchQueue() {"
          "     var messageQueueString = _sendMessageQueue.join(_MESSAGE_SEPERATOR);"
          "     _sendMessageQueue = [];"
          "     return messageQueueString;"
          "};"
          ""
          "function _setMessageHandler(messageHandler) {"
          "     if (%@._messageHandler) { return alert('WebViewJavascriptBridge.setMessageHandler called twice'); }"
          "     %@._messageHandler = messageHandler;"
          "     var receivedMessages = _receiveMessageQueue;"
          "     _receiveMessageQueue = null;"
          "     for (var i=0; i<receivedMessages.length; i++) {"
          "         messageHandler(receivedMessages[i]);"
          "     }"
          "};"
          ""
          "function _handleMessageFromObjC(message) {"
          "     if (_receiveMessageQueue) { _receiveMessageQueue.push(message); }"
          "     else { %@._messageHandler(message); }"
          "};"
          ""
          "window.%@ = {"
          "     setMessageHandler: _setMessageHandler,"
          "     %@: _sendMessage,"
          "     _fetchQueue: _fetchQueue,"
          "     _handleMessageFromObjC: _handleMessageFromObjC"
          "};"
          ""
          "(function() {"
          "     var doc = document;"
          "     _createQueueReadyIframe(doc);"
          "     var readyEvent = doc.createEvent('Events');"
          "     readyEvent.initEvent('WebViewJavascriptBridgeReady');"
          "     doc.dispatchEvent(readyEvent);"
          "})();"
          "})();",
          self.jsObjectName,
          MESSAGE_SEPERATOR,
          CUSTOM_PROTOCOL_SCHEME,
          QUEUE_HAS_MESSAGE,
          self.jsObjectName,
          self.jsObjectName,
          self.jsObjectName,
          self.jsObjectName,
          self.jsObjectMethodName ];
        
    [theWebView stringByEvaluatingJavaScriptFromString:js];
    
    for (id message in self.startupMessageQueue) {
        [self _doSendMessage:message toWebView: theWebView];
    }
    self.startupMessageQueue = nil;
}


- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    if (![[url scheme] isEqualToString:CUSTOM_PROTOCOL_SCHEME]) { return YES; }

    if ([[url host] isEqualToString:QUEUE_HAS_MESSAGE]) {
        [self _flushMessageQueueFromWebView: theWebView];
    } else {
        NSLog(@"WARNING: Received unknown WebViewJavascriptBridge command %@://%@", CUSTOM_PROTOCOL_SCHEME, [url path]);
    }
    
    return NO;
}


- (void) _flushMessageQueueFromWebView: (UIWebView *) theWebView {
    NSString* messageQueueString = [theWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@._fetchQueue();", self.jsObjectName]];
    NSArray* messages = [messageQueueString componentsSeparatedByString:MESSAGE_SEPERATOR];
    for (id message in messages) {
        [self.delegate handleMessage:message fromWebView: theWebView];
    }
}

@end
