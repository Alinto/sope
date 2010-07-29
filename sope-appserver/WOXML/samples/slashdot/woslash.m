
#import <Foundation/Foundation.h>
#import <NGObjWeb/NGObjWeb.h>
#import <WOXML/WOXMLDecoder.h>
#import <DOM/DOMSaxBuilder.h>
#import <DOM/DOMXMLOutputter.h>

static void test(void) {
  WOHTTPConnection *http;
  WORequest  *request;
  WOResponse *response;
  NSData     *content;

  http = [[WOHTTPConnection alloc] initWithHost:@"slashdot.org" onPort:80];
  AUTORELEASE(http);

  request = [[WORequest alloc] initWithMethod:@"GET"
                               uri:@"/slashdot.xml"
                               httpVersion:@"HTTP/1.0"
                               headers:nil
                               content:nil
                               userInfo:nil];
  AUTORELEASE(request);

  if (![http sendRequest:request]) {
    NSLog(@"couldn't send HTTP request");
    return;
  }

  if ((response = [http readResponse]) == nil) {
    NSLog(@"couldn't read HTTP response");
    return;
  }
  
  content = [response content];

  /* WOXMLDecoder */
  if ([content length] > 0) {
    WOXMLDecoder *decoder;
    id result;
    
    decoder = [WOXMLDecoder xmlDecoderWithMapping:@"file://slashdot.xmlmodel"];
    result  = [decoder decodeRootObjectFromData:content];
    
    NSLog(@"./:\n %@", result);
  }

#if 0
  /* DOM */
  {
    id doc;
    id builder, outputter;
    builder   = [[[DOMSaxBuilder   alloc] init] autorelease];
    outputter = [[[DOMXMLOutputter alloc] init] autorelease];
  
    doc = [builder buildFromData:content];
    NSLog(@"parsed: %@", doc);
  
    [outputter outputDocument:doc to:nil];
  }
#endif
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  pool = [[NSAutoreleasePool alloc] init];
  test();
  RELEASE(pool);
  exit(0);
  return 0;
}
