// $Id: SOPEXToolbarController.h,v 1.2 2004/03/10 18:38:06 znek Exp $

#ifndef __SOPEX_SOPEXToolbarController_H__
#define __SOPEX_SOPEXToolbarController_H__

#import <Foundation/Foundation.h>

@class NSString, NSArray, NSDictionary;
@class NSToolbar, NSWindow;

@interface SOPEXToolbarController : NSObject
{
    NSString     *toolbarID;
    NSDictionary *idToInfo;
    NSMutableDictionary *cachedItems;
    NSToolbar    *toolbar;

    id	       target;        /* non-retained ! */
}

- (id)initWithIdentifier:(NSString *)_id target:(id)_target;

/* operations */

- (void)applyOnWindow:(NSWindow *)_window;

@end

#endif /* __SOPEX_SOPEXToolbarController_H__ */
