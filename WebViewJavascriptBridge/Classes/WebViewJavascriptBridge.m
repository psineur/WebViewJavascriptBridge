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
    js = [NSMutableString stringWithFormat:@";(function() {\n"
          "if (window.%@) { return; };\n"
          "var _readyMessageIframe,\n"
          "     _sendMessageQueue = [],\n"
          "     _receiveMessageQueue = [],\n"
          "     _MESSAGE_SEPERATOR = '%@',\n"
          "     _CUSTOM_PROTOCOL_SCHEME = '%@',\n"
          "     _QUEUE_HAS_MESSAGE = '%@';\n"
          "\n"
          "function _createQueueReadyIframe(doc) {\n"
          "     _readyMessageIframe = doc.createElement('iframe');\n"
          "     _readyMessageIframe.style.display = 'none';\n"
          "     doc.documentElement.appendChild(_readyMessageIframe);\n"
          "}\n"
          "\n"
          "function _sendMessage(message) {\n"
          "     _sendMessageQueue.push(message);\n"
          "     _readyMessageIframe.src = _CUSTOM_PROTOCOL_SCHEME + '://' + _QUEUE_HAS_MESSAGE;\n"
          "};\n"
          "\n"
          "function _fetchQueue() {\n"
          "     var messageQueueString = _sendMessageQueue.join(_MESSAGE_SEPERATOR);\n"
          "     _sendMessageQueue = [];\n"
          "     return messageQueueString;\n"
          "};\n"
          "\n"
          "function _setMessageHandler(messageHandler) {\n"
          "     if (%@._messageHandler) { return alert('WebViewJavascriptBridge.setMessageHandler called twice'); }\n"
          "     %@._messageHandler = messageHandler;\n"
          "     var receivedMessages = _receiveMessageQueue;\n"
          "     _receiveMessageQueue = null;\n"
          "     for (var i=0; i<receivedMessages.length; i++) {\n"
          "         messageHandler(receivedMessages[i]);\n"
          "     }\n"
          "};\n"
          "\n"
          "function _handleMessageFromObjC(message) {\n"
          "     if (_receiveMessageQueue) { _receiveMessageQueue.push(message); }\n"
          "     else { %@._messageHandler(message); }\n"
          "};\n"
          "\n"
          "window.%@ = {\n"
          "     setMessageHandler: _setMessageHandler,\n"
          "     %@: _sendMessage,\n"
          "     _fetchQueue: _fetchQueue,\n"
          "     _handleMessageFromObjC: _handleMessageFromObjC\n"
          "};\n"
          "\n"
          "(function() {\n"
          "     var doc = document;\n"
          "     _createQueueReadyIframe(doc);\n"
          "     var readyEvent = doc.createEvent('Events');\n"
          "     readyEvent.initEvent('WebViewJavascriptBridgeReady');\n"
          "     doc.dispatchEvent(readyEvent);\n"
          "})();\n"
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
