// WebViewJavascriptBridge.m
// WebViewJavascriptBridge
//
// Copyright (c) 2011 Marcus Westin
// Copyright (c) 2011 Stepan Generalov
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#import <Foundation/Foundation.h>

@protocol WebViewJavascriptBridgeDelegate <NSObject>

- (void) handleMessage:(NSString*) message fromWebView: (UIWebView *)theWebView;

@end

@interface WebViewJavascriptBridge : NSObject <UIWebViewDelegate> {
    id <WebViewJavascriptBridgeDelegate> _delegate;
    NSMutableArray *_startupMessageQueue;
    
    NSString *_jsObjectName;
    NSString *_jsObjectMethodName;
}

/** Delegate to receive messages from javascript. */
@property (readwrite, assign) id <WebViewJavascriptBridgeDelegate> delegate;

/** Name of object in javascript, that javascript can use to send messages.
 * Default is "WebViewJavascriptBridge".
 * In order to integrate properly - set this property before receiving webViewDidFinishLoad: 
 * from webView.
 */
@property(readwrite, copy) NSString *jsObjectName;

/** Name of method in javascript, that javascript can use to send messages.
 * Default is "sendMessage".
 * In order to integrate properly - set this property before receiving webViewDidFinishLoad: 
 * from webView.
 */
@property(readwrite, copy) NSString *jsObjectMethodName;

/** Creates & returns new autoreleased javascript Bridge with no delegate set. */
+ (id) javascriptBridge;

/** Sends message to given webView. You need to integrate javascript bridge into 
 * this view before by calling WebViewJavascriptBridge#webViewDidFinishLoad: with that view. 
 *
 * You can call this method before calling webViewDidFinishLoad: , than all messages
 * will be accumulated in _startupMessageQueue & sended to webView, provided by first
 * webViewDidFinishLoad: call.
 */
- (void) sendMessage:(NSString*) message toWebView:(UIWebView *) theWebView;

@end
