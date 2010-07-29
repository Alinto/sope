/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "WETableView.h"
#include "WETableView+Grouping.h"
#include "WETableViewState.h"
#include "WETableViewColorConfig.h"
#include "WETableViewIconConfig.h"
#include "WETableViewLabelConfig.h"

#include "common.h"
#include <NGObjWeb/NGObjWeb.h>
#include <EOControl/EOSortOrdering.h>
#include "WEContextConditional.h"

@interface WETableView(JavaScriptAdditions)

- (void)_appendGroupCollapseScript:(WOResponse *)_resp
                         inContext:(WOContext *)_ctx;
- (void)jsButton:(WOResponse *)_resp ctx:(WOContext *)_ctx
  name:(NSString *)_name button:(NSString *)_button;

- (void)appendJavaScript:(WOResponse *)_resp inContext:(WOContext *)_ctx;
- (void)_appendTableContentAsScript:(WOResponse *)_resp
  inContext:(WOContext *)_ctx;

- (void)_appendScriptLink:(WOResponse *)_response name:(NSString *)_name;
- (void)_appendScriptImgName:(WOResponse *)_response name:(NSString *)_name;

@end

#include <NGObjWeb/WEClientCapabilities.h>

@implementation WETableView

static NSNumber *YesNumber = nil;
static NSNumber *NoNumber  = nil;
static Class    StrClass   = Nil;
static BOOL ShowNavigationAlways   = YES;
static BOOL ShowNavigationInFooter = YES;

+ (int)version {
  return [super version] + 1 /* v3 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  StrClass = [NSString class];
  if (YesNumber == nil) YesNumber = [[NSNumber numberWithBool:YES] retain];
  if (NoNumber  == nil) NoNumber  = [[NSNumber numberWithBool:NO]  retain];
  
  ShowNavigationAlways = [ud boolForKey:@"WETableView_showBlindNavigation"];
}

static NSString *retStrForInt(int i) {
  switch(i) {
  case 0:  return @"0";
  case 1:  return @"1";
  case 2:  return @"2";
  case 3:  return @"3";
  case 4:  return @"4";
  case 5:  return @"5";
  case 6:  return @"6";
  case 7:  return @"7";
  case 8:  return @"8";
  case 9:  return @"9";
  case 10: return @"10";
    // TODO: find useful count!
  default:
    return [[StrClass alloc] initWithFormat:@"%i", i];
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->state = [[WETableViewState alloc] init];

    self->list           = WOExtGetProperty(_config, @"list");
    self->currentBatch   = WOExtGetProperty(_config, @"currentBatch");
    self->batchSize      = WOExtGetProperty(_config, @"batchSize");
    
    self->item           = WOExtGetProperty(_config, @"item");
    self->index          = WOExtGetProperty(_config, @"index");
    self->identifier     = WOExtGetProperty(_config, @"identifier");
    self->previousItem   = WOExtGetProperty(_config, @"previousItem");
    self->previousIndex  = WOExtGetProperty(_config, @"previousIndex");
    self->sortedKey      = WOExtGetProperty(_config, @"sortedKey");
    self->isDescending   = WOExtGetProperty(_config, @"isDescending");
    self->selection      = WOExtGetProperty(_config, @"selection");
    self->groups         = WOExtGetProperty(_config, @"groups");
    self->showGroup      = WOExtGetProperty(_config, @"showGroup");

    // display state
    self->indexOfFirst =
      WOExtGetProperty(_config, @"indexOfFirstDisplayedObject");
    self->indexOfLast  =
      WOExtGetProperty(_config, @"indexOfLastDisplayedObject");

    self->collapseOnClient = WOExtGetProperty(_config, @"collapseOnClient");
    self->scrollOnClient   = WOExtGetProperty(_config, @"scrollOnClient");
    self->autoScroll       = WOExtGetProperty(_config, @"autoScroll");
    self->showBatchResizeButtons =
      WOExtGetProperty(_config, @"showBatchResizeButtons");

    // actions
    self->sortAction     = WOExtGetProperty(_config, @"sortAction");
    self->firstAction    = WOExtGetProperty(_config, @"firstAction");
    self->previousAction = WOExtGetProperty(_config, @"previousAction");
    self->nextAction     = WOExtGetProperty(_config, @"nextAction");
    self->lastAction     = WOExtGetProperty(_config, @"lastAction");
    
    // config stuff:
    self->colors = 
      [[WETableViewColorConfig alloc] initWithAssociations:_config];
    self->groupColor     = WOExtGetProperty(_config, @"groupColor");
    self->fontColor      = WOExtGetProperty(_config, @"fontColor");
    self->fontFace       = WOExtGetProperty(_config, @"fontFace");
    self->fontSize       = WOExtGetProperty(_config, @"fontSize");

    // icons:
    self->icons = [[WETableViewIconConfig alloc] initWithAssociations:_config];
    self->groupOpenedIcon = WOExtGetProperty(_config, @"groupOpenedIcon");
    self->groupClosedIcon = WOExtGetProperty(_config, @"groupClosedIcon");
    
    // labels:
    self->labels = 
      [[WETableViewLabelConfig alloc] initWithAssociations:_config];

    self->cellspacing    = WOExtGetProperty(_config, @"cellspacing");
    self->cellpadding    = WOExtGetProperty(_config, @"cellpadding");
    self->border         = WOExtGetProperty(_config, @"border");

    self->showGroupTitle = WOExtGetProperty(_config, @"showGroupTitle");

#define SetAssociationValue(_a_, _value_) \
         if (_a_ == nil)                  \
           _a_ = [[WOAssociation associationWithValue:_value_] retain];
    
    SetAssociationValue(self->cellspacing,   @"0");
    SetAssociationValue(self->cellpadding,   @"1");
    SetAssociationValue(self->border,        @"0");
           
#undef SetAssociationValue

    if (self->list == nil) {
      [self logWithFormat:@"ERROR: no 'list' binding is set!"];
      [self release];
      return nil;
    }

    self->state->doScriptScrolling = NO;
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->state  release];
  [self->colors release];
  [self->labels release];
  [self->icons  release];

  [self->list          release];
  [self->currentBatch  release];
  [self->batchSize     release];
  
  [self->item          release];
  [self->index         release];
  [self->identifier    release];
  [self->previousItem  release];
  [self->previousIndex release];
  [self->sortedKey     release];
  [self->isDescending  release];
  [self->selection     release];
  [self->groups        release];
  [self->showGroup     release];

  [self->indexOfFirst  release];
  [self->indexOfLast   release];

  [self->collapseOnClient release];
  [self->scrollOnClient   release];
  [self->autoScroll       release];
  [self->showBatchResizeButtons release];
  
  [self->sortAction     release];
  [self->firstAction    release];
  [self->previousAction release];
  [self->nextAction     release];
  [self->lastAction     release];

  [self->fontColor   release];
  [self->fontFace    release];
  [self->fontSize    release];

  [self->groupColor      release];
  [self->groupOpenedIcon release];
  [self->groupClosedIcon release];
  
  [self->allObjects release];
  [self->scriptID   release];
  [self->template   release];

  [self->cellpadding release];
  [self->cellspacing release];
  [self->border release];

  [self->showGroupTitle release];

  [super dealloc];
}

static inline void
_applyIdentifier(WETableView *self, WOComponent *comp, NSString *_idx)
{
  unsigned count;
  count = [self->allObjects count];

  if (count > 0) {
    unsigned i;

    /* find subelement for unique id */
    
    for (i = 0; i < count; i++) {
      NSString *ident;
      
      if (self->index)
        [self->index setUnsignedIntValue:i inComponent:comp];

      if (self->item) {
        [self->item setValue:[self->allObjects objectAtIndex:i]
                    inComponent:comp];
      }
      if ([self->previousItem isValueSettable]) {
        [self->previousItem setValue:(i > self->state->firstIndex)
             ? [self->allObjects objectAtIndex:i-1] : nil
             inComponent:comp];
      }
      if ([self->previousIndex isValueSettable])
        [self->previousIndex setUnsignedIntValue:(i-1) inComponent:comp];

      ident = [self->identifier stringValueInComponent:comp];

      if ([ident isEqualToString:_idx]) {
        /* found subelement with unique id */
        return;
      }
    }
    
    [comp logWithFormat:
          @"WETableView: array did change, "
          @"unique-id isn't contained."];
    [self->item  setValue:nil          inComponent:comp];
    [self->index setUnsignedIntValue:0 inComponent:comp];
  }
}

static inline void _applyItems_(WETableView *self, WOComponent *cmp, int i) {
  if ([self->index isValueSettable])
    [self->index setUnsignedIntValue:i inComponent:cmp];
  if ([self->item isValueSettable])
    [self->item setValue:[self->allObjects objectAtIndex:i] inComponent:cmp];
  if ([self->previousItem isValueSettable]) {
    id value;

    value = (i > (int)self->state->firstIndex) 
      ? [self->allObjects objectAtIndex:(i - 1)] 
      : nil;
    [self->previousItem setValue:value inComponent:cmp];
  }
  if ([self->previousIndex isValueSettable])
    [self->previousIndex setUnsignedIntValue:(i-1) inComponent:cmp];
}

static inline void _applyState_(WETableView *self, WOComponent *cmp) {
  if ([self->currentBatch isValueSettable])
    [self->currentBatch setUnsignedIntValue:self->state->currentBatch
                                inComponent:cmp];
}

- (void)updateStateInContext:(WOContext *)_ctx {
  WEClientCapabilities *ccaps;
  BOOL        isAutoScroll;
  WOComponent *cmp;
  NSArray     *array;
  unsigned    batchIdx, size, cnt;

  cmp            = [_ctx component];
  ccaps          = [[_ctx request] clientCapabilities];
  isAutoScroll   = [ccaps doesSupportCSSOverflow];
  self->state->doScriptScrolling  = [ccaps isInternetExplorer];
  self->state->doScriptCollapsing = [ccaps isInternetExplorer];
  if (self->state->doScriptCollapsing) {
    self->state->doScriptCollapsing =
      [self->collapseOnClient boolValueInComponent:cmp];
  }

  if ([[self->autoScroll valueInComponent:cmp] intValue] < 10)
    isAutoScroll   = NO;
  else if (isAutoScroll)
    self->state->doScriptScrolling = NO;
  
  /* use JavaScript on InternetExplorer only */
  self->state->doScriptScrolling = (self->state->doScriptScrolling)
    ? (self->state->batchCount > 1)
    : NO;
  
  self->state->doScriptScrolling = (self->state->doScriptScrolling)
    ? [self->scrollOnClient boolValueInComponent:cmp]
    : NO;
  
  array    = [self->list         valueInComponent:cmp];
  batchIdx = [self->currentBatch unsignedIntValueInComponent:cmp];
  size     = [self->batchSize    unsignedIntValueInComponent:cmp];
  cnt      = [array count];
  size     = (isAutoScroll) ? cnt : size;
  batchIdx = (batchIdx) ? batchIdx : 1;
  batchIdx = ((batchIdx * size) < (cnt+size)) ? batchIdx : 1;

  ASSIGN(self->allObjects, array);

  self->state->currentBatch = batchIdx;
  self->state->batchSize    = size;
  
  self->state->batchCount = (!size) ? 1 :(cnt / size) + ((cnt % size) ? 1 : 0);
  self->state->firstIndex = (batchIdx - 1) * size;
  self->state->lastIndex  = 
    (size == 0 || !((self->state->firstIndex+size) < cnt))
    ? cnt-1
    : self->state->firstIndex + size - 1;

  if ([self->indexOfFirst isValueSettable]) {
    [self->indexOfFirst setUnsignedIntValue:self->state->firstIndex
                        inComponent:cmp];
  }
  
  if ([self->indexOfLast isValueSettable]) {
    [self->indexOfLast setUnsignedIntValue:self->state->lastIndex
                       inComponent:cmp];
  }
  
  self->state->doCheckBoxes = 
    ([_ctx isInForm] && [self->selection isValueSettable]) ? YES : NO;
  self->state->doOverflow = isAutoScroll;
}

- (void)updateScriptIdInContext:(WOContext *)_ctx {
  NSArray  *tmp;
  NSString *str;

  tmp = [[_ctx elementID] componentsSeparatedByString:@"."];
  str = [tmp componentsJoinedByString:@""];
  
  ASSIGN(self->scriptID, str);
}

- (void)updateConfigInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *tmp;

  cmp = [_ctx component];
  
  [self->colors updateConfigInContext:_ctx];
  [self->icons  updateConfigInContext:_ctx];
  [self->labels updateConfigInContext:_ctx];
  
#define SetConfigInContext(_a_, _key_)                                  \
      if (_a_ && (tmp = [_a_ valueInComponent:cmp]))                    \
        [_ctx setObject:tmp forKey:_key_];                              \

  SetConfigInContext(self->fontColor,       WETableView_fontColor);
  SetConfigInContext(self->fontFace,        WETableView_fontFace);
  SetConfigInContext(self->fontSize,        WETableView_fontSize);
#undef SetConfigInContext
}

- (void)removeConfigInContext:(WOContext *)_ctx {
  [_ctx removeObjectForKey:WETableView_titleColor];
  [_ctx removeObjectForKey:WETableView_headerColor];
  [_ctx removeObjectForKey:WETableView_footerColor];
  [_ctx removeObjectForKey:WETableView_evenColor];
  [_ctx removeObjectForKey:WETableView_oddColor];
  [_ctx removeObjectForKey:WETableView_fontColor];
  [_ctx removeObjectForKey:WETableView_fontFace];
  [_ctx removeObjectForKey:WETableView_fontSize];
  
  [_ctx removeObjectForKey:WETableView_downwardIcon];
  [_ctx removeObjectForKey:WETableView_upwardIcon];
  [_ctx removeObjectForKey:WETableView_nonSortIcon];

  [_ctx removeObjectForKey:WETableView_first];
  [_ctx removeObjectForKey:WETableView_first_blind];
  [_ctx removeObjectForKey:WETableView_previous];
  [_ctx removeObjectForKey:WETableView_previous_blind];
  [_ctx removeObjectForKey:WETableView_next];
  [_ctx removeObjectForKey:WETableView_next_blind];
  [_ctx removeObjectForKey:WETableView_last];
  [_ctx removeObjectForKey:WETableView_last_blind];
  [_ctx removeObjectForKey:WETableView_select_all];
  [_ctx removeObjectForKey:WETableView_deselect_all];

  [_ctx removeObjectForKey:WETableView_ofLabel];
  [_ctx removeObjectForKey:WETableView_toLabel];
  [_ctx removeObjectForKey:WETableView_firstLabel];
  [_ctx removeObjectForKey:WETableView_previousLabel];
  [_ctx removeObjectForKey:WETableView_nextLabel];
  [_ctx removeObjectForKey:WETableView_lastLabel];
  [_ctx removeObjectForKey:WETableView_pageLabel];
  [_ctx removeObjectForKey:WETableView_sortLabel];
}

- (NSArray *)_collectDataInContext:(WOContext *)_ctx
{
  NSAutoreleasePool *pool;
  NSMutableArray    *matrix    = nil;
  NSMutableArray    *headInfos = nil;
  NSString          *k         = nil;
  WOComponent       *cmp       = nil;
  id                oldGroup   = nil;
  int               i, first, last;
  int               sortedHeadIndex = -2;
  
  pool   = [[NSAutoreleasePool alloc] init];
  cmp    = [_ctx component];
  k      = [self->sortedKey stringValueInComponent:cmp];

  first  = self->state->firstIndex;
  last   = self->state->lastIndex;
  matrix = [NSMutableArray arrayWithCapacity:last-first+1];

  [_ctx setObject:YesNumber forKey:WETableView_CollectMode];
  [_ctx setObject:k         forKey:WETableView_SORTEDKEY];

  self->state->groupCount = 0;

  for (i=first; i<=last; i++) {
    NSMutableArray *infos = nil;
    NSString       *tmp   = nil;

    _applyItems_(self, cmp, i);
    
    [_ctx removeObjectForKey:WETableView_INFOS];
    [self->template appendToResponse:nil inContext:_ctx];
    infos = [_ctx objectForKey:WETableView_INFOS];

    if (infos == nil)
      infos = [NSArray array];

    NSAssert(infos != nil, @"Infos is nil.");

    if (headInfos == nil) {
      unsigned j, cnt;
      headInfos = [[NSMutableArray alloc] initWithArray:infos];

      for (j=0, cnt=[headInfos count]; j<cnt; j++) {
        WETableViewInfo *headInfo = [headInfos objectAtIndex:j];
        
        headInfo->isEven = (((i-first) % 2) == 0) ? YES : NO;
      }
    }
    else {
      unsigned j, cnt;
      BOOL     isEven = NO;

      cnt = [infos count];
      
      if (sortedHeadIndex == -2) { // first time
        for (j=0; j < cnt; j++) {
          WETableViewInfo *info;

          info = [infos objectAtIndex:j];
          if (info->isSorted) {
            sortedHeadIndex = j;
            break;
          }
        }
        sortedHeadIndex = (sortedHeadIndex < 0) ? -1 : sortedHeadIndex;
      }

      if (cnt) {
        WETableViewInfo *headInfo;
        WETableViewInfo *info;

        if (sortedHeadIndex >= 0) {
          NSAssert(sortedHeadIndex < (int)cnt, 
                   @"SortedHeadIndex out of range!!!");
          headInfo = [headInfos objectAtIndex:sortedHeadIndex];
          info     = [infos     objectAtIndex:sortedHeadIndex];
          isEven = (!info->isGroup) ? !headInfo->isEven : headInfo->isEven;
        }
        else { // sortedHeadIndex == -1 --> no column is sorted
          headInfo = [headInfos lastObject];
          isEven = !headInfo->isEven;
        }
      }

      for (j = 0; j < cnt; j++) {
        WETableViewInfo *info     = [infos     objectAtIndex:j];
        WETableViewInfo *headInfo = [headInfos objectAtIndex:j];

        if (!info->isGroup || ((int)j != sortedHeadIndex)) {
          info->isEven  = isEven;
          info->isGroup = NO;
          [headInfos replaceObjectAtIndex:j withObject:info];
        }
        else
          headInfo->rowSpan++;
      }
    }
    {
      BOOL doGroupTitle = [self->showGroupTitle boolValueInComponent:cmp];

      // insert groupMode (to render the group title)
      tmp = [self->groups valueInComponent:cmp];
      if ((tmp != nil) && ![oldGroup isEqual:tmp] && doGroupTitle) {
        oldGroup = [self->groups valueInComponent:cmp];
        self->state->groupCount++;
        [infos addObject:tmp];
        [infos addObject:WETableView_GroupMode];
      }
    }

    [matrix addObject:infos];
  }
  [_ctx removeObjectForKey:WETableView_INFOS];
  [_ctx removeObjectForKey:WETableView_CollectMode];
  [_ctx removeObjectForKey:WETableView_SORTEDKEY];

  matrix = [matrix retain];
  [headInfos release];
  [pool      release];

  return [matrix autorelease];
}

- (void)_appendNav:(NSString *)_nav isBlind:(BOOL)_isBlind
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
{
  NSString *imgUri;
  NSString *label;
  BOOL     doForm   = [_ctx isInForm];

  imgUri = [WETableView_ stringByAppendingString:_nav];
  imgUri = [imgUri stringByAppendingString:(_isBlind) ? @"_blind" : @""];
  imgUri = [_ctx objectForKey:imgUri];
  imgUri = WEUriOfResource(imgUri,_ctx);
  
  label  = WETableLabelForKey(_nav, _ctx);

  [_response appendContentString:@"<td valign='middle' width='5'>"];
  // append as submit button
  if (doForm && !_isBlind && !self->state->doScriptScrolling && imgUri) {
    [_ctx appendElementIDComponent:_nav];
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:imgUri];
    [_response appendContentString:@"\" alt=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" title=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" />"];
    [_ctx deleteLastElementIDComponent];
    [_response appendContentString:@"</td>"];
    return;
  }

  /* open anker */
  if (!_isBlind || self->state->doScriptScrolling) {
    [_ctx appendElementIDComponent:_nav];
    [_response appendContentString:@"<a href=\""];
    if (self->state->doScriptScrolling)
      [self _appendScriptLink:_response name:_nav];
    else
      [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];
  }
  if (imgUri == nil) {
    [_response appendContentCharacter:'['];
    [_response appendContentString:label];
    [_response appendContentCharacter:']'];
  }
  else {
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:imgUri];
    if (self->state->doScriptScrolling) {
      [_response appendContentString:@"\" name=\""];
      [self _appendScriptImgName:_response name:_nav];
    }
    [_response appendContentString:@"\" alt=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" title=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" />"];
  }
  /* close anker */
  if (!_isBlind || self->state->doScriptScrolling) {
    [_response appendContentString:@"</a>"];
    [_ctx deleteLastElementIDComponent];
  }
  [_response appendContentString:@"</td>"];
}

- (void)_appendPreviousNav:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  int  batch, batchCount;
  BOOL isFirstBlind, isPreviousBlind, isNextBlind, isLastBlind;
  
  batch      = self->state->currentBatch;
  batchCount = self->state->batchCount;

  isFirstBlind    = (batch < 2);
  isPreviousBlind = (batch < 2);
  isNextBlind     = ((batchCount-1) < batch);
  isLastBlind     = ((batchCount-1) < batch);

  if ((ShowNavigationAlways) ||
      (!(isFirstBlind && isPreviousBlind && isNextBlind && isLastBlind))) {
    [self _appendNav:@"first"    isBlind:isFirstBlind
          toResponse:_resp     inContext:_ctx];
    [self _appendNav:@"previous"   isBlind:isPreviousBlind
          toResponse:_resp       inContext:_ctx];
  }
}

- (void)_appendNextNav:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  int  batch, batchCount;
  BOOL isFirstBlind, isPreviousBlind, isNextBlind, isLastBlind;
  
  batch      = self->state->currentBatch;
  batchCount = self->state->batchCount;

  isFirstBlind    = (batch < 2);
  isPreviousBlind = (batch < 2);
  isNextBlind     = ((batchCount-1) < batch);
  isLastBlind     = ((batchCount-1) < batch);

  if ((ShowNavigationAlways) ||
      (!(isFirstBlind && isPreviousBlind && isNextBlind && isLastBlind))) {
    [self _appendNav:@"next"     isBlind:isNextBlind
          toResponse:_resp     inContext:_ctx];
    [self _appendNav:@"last"     isBlind:isLastBlind
          toResponse:_resp     inContext:_ctx];
  }
}

- (void)_appendNavigation:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  [_resp appendContentString:
         @"<table border='0' cellspacing='0' cellpadding='0'><tr>"];

  [self _appendPreviousNav:_resp inContext:_ctx];
  
  /* append extra buttons */
  [_resp appendContentString:@"<td valign='middle'>"];
  [_ctx setObject:YesNumber forKey:WETableView_ButtonMode];
  [_ctx appendElementIDComponent:@"button"];
  [self->template appendToResponse:_resp     inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  [_ctx removeObjectForKey:WETableView_ButtonMode];
  [_resp appendContentString:@"</td>"];

  [self _appendNextNav:_resp inContext:_ctx];
  
  [_resp appendContentString:@"</tr></table>"];
}

- (void)_appendTitle:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *bg;

  bg = [_ctx objectForKey:WETableView_titleColor];
  
  /* open title bar*/
  [_response appendContentString:
             @"<table border='0' width='100%' cellpadding='0' cellspacing='0'>"
             @"<tr>"];

  /* append title */
  [_ctx setObject:YesNumber forKey:WETableView_TitleMode];
  [_ctx appendElementIDComponent:@"title"];
  WEAppendTD(_response, @"left", @"middle", bg);                   // <td..>
  [self->template appendToResponse:_response inContext:_ctx];
  [_response appendContentString:@"</td>"];                        // </td>
  [_ctx deleteLastElementIDComponent]; // delete "title"
  [_ctx removeObjectForKey:WETableView_TitleMode];

  /* append navigation + extra buttons */
  WEAppendTD(_response, @"right", @"middle", bg);                  // <td..>
  [self _appendNavigation:_response inContext:_ctx];
  [_response appendContentString:@"</td>"];                        // </td>
  
  /* close title bar*/
  [_response appendContentString:@"</tr></table>"];
}

- (void)_appendHeader:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (self->sortedKey)
    [_ctx setObject:[self->sortedKey stringValueInComponent:[_ctx component]]
             forKey:WETableView_SORTEDKEY];
  if (self->isDescending)
    [_ctx setObject:[self->isDescending valueInComponent:[_ctx component]]
             forKey:WETableView_ISDESCENDING];
  [_ctx setObject:YesNumber forKey:WETableView_HeaderMode];
  [_response appendContentString:@"<tr>"];

  [_ctx appendElementIDComponent:@"header"];
  {
    NSString *bn;
    bn = retStrForInt(self->state->currentBatch);
    [_ctx appendElementIDComponent:bn]; // append batchNumber
    [bn release];
  }
  if (self->state->doCheckBoxes) {
    NSString *img;
    NSArray  *selArray;
    BOOL     doSelectAll;

    selArray    = [self->selection valueInComponent:[_ctx component]];
    doSelectAll = ([selArray count] < ([self->allObjects count] / 2));

    img = [_ctx objectForKey:(doSelectAll)
                ? WETableView_select_all
                : WETableView_deselect_all];

    img = WEUriOfResource(img, _ctx);

    [_response appendContentString:
               @"<td  align=\"center\" bgcolor=\""];
    [_response appendContentString:
               [_ctx objectForKey:WETableView_headerColor]];
    [_response appendContentString:@"\">"];
      
    if (doSelectAll)
      [_ctx appendElementIDComponent:@"_sa"]; // select all
    else
      [_ctx appendElementIDComponent:@"_dsa"]; // deselect all
    
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];

    if (img) {
      [_response appendContentString:@"<img border=\"0\" src=\""];
      [_response appendContentString:img];
      [_response appendContentString:@"\" alt=\""];
      [_response appendContentString:(doSelectAll)
                 ? @"selectall"
                 : @"deselect all"];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentString:(doSelectAll)
                 ? @"selectall"
                 : @"deselect all"];
      [_response appendContentString:@"\" />"];
    }
    else
      [_response appendContentString:(doSelectAll) ? @"[+]" : @"[-]"];

    [_response appendContentString:@"</a>"];
    [_ctx deleteLastElementIDComponent];    // (de)select all
    [_response appendContentString:@"</td>"];
  }
  [self->template appendToResponse:_response inContext:_ctx];
  
  [_ctx deleteLastElementIDComponent]; // delete batchNumber
  [_ctx deleteLastElementIDComponent]; // delete "header"

  if (self->state->showBatchResizeButtons) {
    int cnt;

    cnt = (self->state->lastIndex - self->state->firstIndex + 1);

    if (cnt == (int)self->state->batchSize && !self->state->doOverflow) {
      [_response appendContentString:@"<td width=\"1%\""];
      if ([_ctx objectForKey:WETableView_headerColor]) {
        [_response appendContentString:@" bgcolor=\""];
        [_response appendContentString:
                   [_ctx objectForKey:WETableView_headerColor]];
        [_response appendContentString:@"\""];
      }
      [_response appendContentString:@"></td>"];
    }
  }
  
  [_response appendContentString:@"</tr>"];
  [_ctx removeObjectForKey:WETableView_HeaderMode];
  [_ctx removeObjectForKey:WETableView_SORTEDKEY];
  [_ctx removeObjectForKey:WETableView_ISDESCENDING];
}

- (void)_appendResizeButtons:(WOResponse *)_response
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx
{
  NSString *img;
  NSString *uri;

  // append batchSize--Button  
  img = [self->icons->minusResizeIcon stringValueInComponent:[_ctx component]];
  img = WEUriOfResource(img, _ctx);
  uri = [_actionUrl stringByAppendingString:@".mm"];
  
  if (img && [_ctx isInForm]) {
    uri = [[uri componentsSeparatedByString:@"/"] lastObject];
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" name=\""];
    [_response appendContentString:uri];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\"minus\" title=\"minus\" />"];
  }
  else {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:uri];
    [_response appendContentString:@"\">"];
  }
  
  if (img && ![_ctx isInForm]) {
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\"minus\" title=\"minus\" />"];
  }
  else if (!img)
    [_response appendContentString:@"-"];

  if (!(img && [_ctx isInForm]))
    [_response appendContentString:@"</a>"];

  // append batchSize--Button
  img = [self->icons->plusResizeIcon stringValueInComponent:[_ctx component]];
  img = WEUriOfResource(img, _ctx);
  uri = [_actionUrl stringByAppendingString:@".pp"] ;
  
  if (img && [_ctx isInForm]) {
    uri = [[uri componentsSeparatedByString:@"/"] lastObject];
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" name=\""];
    [_response appendContentString:uri];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\"plus\" title=\"plus\" />"];
  }
  else {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:uri];
    [_response appendContentString:@"\">"];
  }
  
  if (img && ![_ctx isInForm]) {
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:img];
    [_response appendContentString:@"\" alt=\"plus\" title=\"plus\" />"];
  }
  else if (!img)
    [_response appendContentString:@"+"];

  if (!(img && [_ctx isInForm]))
    [_response appendContentString:@"</a>"];

}

- (void)_appendBatchResizeButtons:(WOResponse *)_response
  rowSpan:(unsigned int)_rowSpan
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx
{
  NSString *s;
  
  // open "td"
  s = [[StrClass alloc] initWithFormat:
                  @"<td align='center' valign='bottom' width='5' rowspan='%d'", _rowSpan];
  [_response appendContentString:s];
  [s release];
  
  if ([_ctx objectForKey:WETableView_footerColor]) {
    [_response appendContentString:@" bgcolor='"];
    [_response appendContentString:
               [_ctx objectForKey:WETableView_footerColor]];
    [_response appendContentCharacter:'\''];
  }
  [_response appendContentCharacter:'>'];

      // apppend resize buttons
  [self _appendResizeButtons:_response
        actionUrl:_actionUrl
        inContext:_ctx];
  // close "td"
  [_response appendContentString:@"</td>"];
}

- (void)_appendData:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSArray     *matrix;
  NSString    *batchSizeUrl = nil;
  NSArray     *selArray     = nil;
  NSString    *groupId      = nil;
  BOOL        hideObject    = NO;
  unsigned    i, cnt, first;

  comp     = [_ctx component];
  matrix   = [self _collectDataInContext:_ctx];
  first    = self->state->firstIndex;
  cnt      = [matrix count];

  if (matrix == nil || cnt == 0)
    return;

  if (self->state->doCheckBoxes)
    selArray = [self->selection valueInComponent:comp];

  if (self->state->doScriptCollapsing)
    [self _appendGroupCollapseScript:_response inContext:_ctx];

  [_ctx appendElementIDComponent:@"data"];
  {
    NSString *bn;
    bn = retStrForInt(self->state->currentBatch);
    [_ctx appendElementIDComponent:bn]; // append batchNumber
    [bn release];
  }

  batchSizeUrl = [_ctx componentActionURL];

  if (self->identifier == nil) {
    NSString *s;
    
    s = retStrForInt(first);
    [_ctx appendElementIDComponent:s];
    [s release];
  }
  
  for (i = 0; i < cnt; i++) {
    NSMutableArray *infos = nil;

    _applyItems_(self, comp, first+i);
    if (self->identifier) {
      NSString *ident;

      ident = [self->identifier stringValueInComponent:comp];
      [_ctx appendElementIDComponent:ident];
    }
    
    infos = [matrix objectAtIndex:i];

    if ([[infos lastObject] isEqual:WETableView_GroupMode]) {
      unsigned rowSpan;
      
      groupId = [StrClass stringWithFormat:@"group%d", i];

      rowSpan = ((i==0) && self->state->showBatchResizeButtons)
        ? cnt+self->state->groupCount
        : 0;
      [self _appendGroupTitle:_response
            inContext:_ctx
            infos:infos
            actionUrl:batchSizeUrl
            rowSpan:rowSpan
            groupId:groupId];
      
      if ((self->state->groupCount > 0) && !self->state->doScriptCollapsing &&
          (self->showGroup) && ![self->showGroup boolValueInComponent:comp])
        hideObject = YES;
      else
        hideObject = NO;
    }
        
    [_ctx setObject:infos forKey:WETableView_INFOS];

    if (hideObject) {
      if (self->identifier == nil)
        [_ctx incrementLastElementIDComponent];
      else
        [_ctx deleteLastElementIDComponent]; // delete identifier
      continue;
    }
    
    [_response appendContentString:@"<tr"];
    if (groupId) {
      [_response appendContentString:@" groupName=\""];
      [_response appendContentString:groupId];
      [_response appendContentCharacter:'"'];
      if (self->state->doScriptCollapsing &&
          self->showGroup && ![self->showGroup boolValueInComponent:comp])
        [_response appendContentString:@" style=\"display:none;\""];
    }
    [_response appendContentCharacter:'>'];

    [_ctx setObject:YesNumber forKey:WETableView_DataMode];

    if (self->state->doCheckBoxes) {
      WETableViewInfo *info = nil;
      NSString        *bg   = nil;
      NSString *s;

      info = ([infos count]) ? [infos objectAtIndex:0] : nil;

      bg = (info && info->isEven)
        ? [_ctx objectForKey:WETableView_evenColor]
        : [_ctx objectForKey:WETableView_oddColor];

      [_ctx appendElementIDComponent:@"cb"];
      [_response appendContentString:@"<td width=\"15\" align=\"left\""];
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bg];
      [_response appendContentString:@"\"><input type=\"checkbox\" name=\""];
      [_response appendContentHTMLAttributeValue:[_ctx elementID]];
      [_response appendContentString:@"\" value=\""];
      s = retStrForInt(first + i);
      [_response appendContentString:s];
      [s release];
      [_response appendContentCharacter:'"'];

      if ([selArray containsObject:[self->allObjects objectAtIndex:first+i]])
        [_response appendContentString:@" checked=\"checked\""];
        
      [_response appendContentString:@" />"];
      [_response appendContentString:@"</td>"];
      
      [_ctx deleteLastElementIDComponent]; // delete "cb"
    }

    [self->template appendToResponse:_response inContext:_ctx];

    if (!i && self->state->showBatchResizeButtons &&!self->state->groupCount) {
      [self _appendBatchResizeButtons:_response
                              rowSpan:cnt+self->state->groupCount
                            actionUrl:batchSizeUrl
                            inContext:_ctx];
    }
    
    [_response appendContentString:@"</tr>"];

    if (self->identifier == nil)
      [_ctx incrementLastElementIDComponent];
    else
      [_ctx deleteLastElementIDComponent]; // delete identifier
  }
  if (self->identifier == nil)
    [_ctx deleteLastElementIDComponent]; // delete index
  [_ctx deleteLastElementIDComponent];   // delete batchNumber
  [_ctx deleteLastElementIDComponent];   // delete "data"
  [_ctx removeObjectForKey:WETableView_DataMode];
}

- (void)_appendFooter:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *bg      = nil;
  unsigned first    = self->state->firstIndex + 1;
  unsigned last     = self->state->lastIndex  + 1;
  unsigned count    = [self->allObjects count];
  unsigned batch    = self->state->currentBatch;
  unsigned batchCnt = self->state->batchCount;
  NSString *s;

  first    = (count)    ? first    : 0;
  batchCnt = (batchCnt) ? batchCnt : 1;
  bg       = [_ctx objectForKey:WETableView_footerColor];
  
  [_response appendContentString:
             @"<table border='0' width='100%' cellpadding='0' cellspacing='0'>"];
  [_response appendContentString:@"<tr>"];                        // <TR>

  WEAppendTD(_response, @"left", nil, bg);                        //   <TD...>

  [_ctx setObject:YesNumber forKey:WETableView_FooterMode];
  [_ctx appendElementIDComponent:@"footer"];  
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  [_ctx removeObjectForKey:WETableView_FooterMode];

  [_response appendContentString:@"<small>"];
  if (!self->state->doOverflow) {
    s = [[StrClass alloc] initWithFormat:@"%d ", first];
    [_response appendContentString:s];
    [s release];
    [_response appendContentString:WETableLabelForKey(@"to", _ctx)];
    s = [[StrClass alloc] initWithFormat:@" %d ", last];
    [_response appendContentString:s];
    [s release];
    [_response appendContentString:WETableLabelForKey(@"of", _ctx)];
  }
  s = [[StrClass alloc] initWithFormat:@" %d", count];
  [_response appendContentString:s];
  [s release];
  [_response appendContentString:@"</small>"];
  
  [_response appendContentString:@"</td>"];                       // </td>

  WEAppendTD(_response, @"right", nil, bg);                     // <td...> 
  if (!self->state->doOverflow) {
    if (ShowNavigationInFooter) {
      [_response appendContentString:
                 @"<table border='0' cellpadding='0' cellspacing='0'><tr>"];
      [self _appendPreviousNav:_response inContext:_ctx];
      WEAppendTD(_response, nil, nil, bg);                        // <td...>
    }
    [_response appendContentString:@"<small>"];
    [_response appendContentString:@"&nbsp;"];
    [_response appendContentString:WETableLabelForKey(@"page", _ctx)];
    s = [[StrClass alloc] initWithFormat:@": %d ", batch];
    [_response appendContentString:s];
    [s release];
    [_response appendContentString:WETableLabelForKey(@"of", _ctx)];
    s = [[StrClass alloc] initWithFormat:@" %d", batchCnt];
    [_response appendContentString:s];
    [s release];
    [_response appendContentString:@"&nbsp;"];
    [_response appendContentString:@"</small>"];
    if (ShowNavigationInFooter) {
      [_response appendContentString:@"</td>"];
      [self _appendNextNav:_response inContext:_ctx];
      [_response appendContentString:@"</tr></table>"];
    }
  }
  else {
    [self _appendResizeButtons:_response
          actionUrl:[_ctx componentActionURL]
          inContext:_ctx];
  }

  [_response appendContentString:@"</td></tr>"];                // </td></tr>
  [_response appendContentString:@"</table>"];                  // </table>
}

// --- action handler -----------------------------------------------------

- (void)_handleSortActionInContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *key;
  NSString    *oldKey;
  BOOL        isDesc;
  BOOL        oldIsDesc;

  if (self->sortedKey == nil || self->isDescending == nil)
    return; // nothing to do

  if ([_ctx objectForKey:WETableView_SORTEDKEY] == nil ||
      [_ctx objectForKey:WETableView_ISDESCENDING] == nil)
    return; // nothing to do

  cmp    = [_ctx component];
  key    = [_ctx  objectForKey:WETableView_SORTEDKEY];
  isDesc = [[_ctx objectForKey:WETableView_ISDESCENDING] boolValue];

  oldIsDesc = [self->isDescending boolValueInComponent:cmp];
  oldKey    = [self->sortedKey  stringValueInComponent:cmp];

  if ([oldKey isEqual:key] && oldIsDesc == isDesc)
    return; // nothing to do

  if ([self->isDescending isValueSettable])
    [self->isDescending setBoolValue:isDesc inComponent:cmp];
  if ([self->sortedKey isValueSettable])
    [self->sortedKey setStringValue:key inComponent:cmp];

  if (self->sortAction == nil && key != nil) {
    EOSortOrdering *so;
    NSArray        *soArray;
    SEL            sel;
    NSArray        *tmp;
    
    sel = (isDesc) ? EOCompareDescending : EOCompareAscending;
    so  = [EOSortOrdering sortOrderingWithKey:key selector:sel];
    
    soArray = [[NSArray alloc] initWithObjects:&so count:1];
    tmp = [self->allObjects sortedArrayUsingKeyOrderArray:soArray];
    [soArray release];
    
    if ([self->list isValueSettable])
      [self->list setValue:tmp inComponent:[_ctx component]];
    else {
      [[_ctx component] debugWithFormat:
                          @"couldn't set sorted list on 'list' binding"];
    }
  }
  else if (self->sortAction)
    [self->sortAction valueInComponent:cmp];
}

- (void)_handleFirstButtonInContext:(WOContext *)_ctx {
  if (self->firstAction)
    [self->firstAction valueInComponent:[_ctx component]];
  else if (self->state->currentBatch != 1) {
    self->state->currentBatch = 1;
    _applyState_(self, [_ctx component]);
  }
}

- (void)_handlePreviousButtonInContext:(WOContext *)_ctx {
  if (self->previousAction)
    [self->previousAction valueInComponent:[_ctx component]];
  else {
    unsigned batch = self->state->currentBatch;
    
    self->state->currentBatch = ((batch -1) > 0) ? batch - 1 : 1;
    _applyState_(self, [_ctx component]);
  }
}

- (void)_handleNextButtonInContext:(WOContext *)_ctx {
  if (self->nextAction)
    [self->nextAction valueInComponent:[_ctx component]];
  else {
    unsigned batch = self->state->currentBatch;
    unsigned cnt   = self->state->batchCount;

    self->state->currentBatch = ((batch +1) < cnt) ? batch + 1 : cnt;
    _applyState_(self, [_ctx component]);
  }
}

- (void)_handleLastButtonInContext:(WOContext *)_ctx {
  if (self->lastAction)
    [self->lastAction valueInComponent:[_ctx component]];
  else {
    self->state->currentBatch = self->state->batchCount;
    _applyState_(self, [_ctx component]);
  }
}

/* handle request */

- (void)takeValuesFromRequest:(WORequest *)_request
  forBatch:(int)_batch
  selections:(NSMutableArray *)_selArray
  inContext:(WOContext *)_ctx
{
  NSString *eid, *s;
  int      i, first, last;
  
  first = self->state->firstIndex;
  last  = self->state->lastIndex;
  
  {
    NSString *bn;
    bn = retStrForInt(self->state->currentBatch);
    [_ctx appendElementIDComponent:bn]; // append batchNumber
    [bn release];
  }

  eid = [_ctx elementID];

  if ([_request formValueForKey:[eid stringByAppendingString:@".pp.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".pp"]];
  }
  else if ([_request formValueForKey:[eid stringByAppendingString:@".mm.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".mm"]];
  }
  
  if (self->identifier == nil) { // append index
    s = retStrForInt(first);
    [_ctx appendElementIDComponent:s];
    [s release];
  }

  for (i = first; i <= last; i++) {
    _applyItems_(self, [_ctx component], i);
    if (self->identifier) {
      NSString *s;
      
      s = [self->identifier stringValueInComponent:[_ctx component]];
      [_ctx appendElementIDComponent:s];
    }
    
    if (_selArray) {
      NSString *cbID; // checkBoxID
      id       formValue;
      id       obj;
      
      cbID = [[_ctx elementID] stringByAppendingString:@".cb"];
      obj  = [self->item valueInComponent:[_ctx component]];

      if (obj) {
        if ((formValue = [_request formValueForKey:cbID])) {
          if (![_selArray containsObject:obj])
            [_selArray addObject:obj];
        }
        else if ([_selArray containsObject:obj])
          [_selArray removeObject:obj];
      }
    }
    [self->template takeValuesFromRequest:_request inContext:_ctx];
    
    if (self->identifier == nil)
      [_ctx incrementLastElementIDComponent];
    else
      [_ctx deleteLastElementIDComponent]; // delete identifier
  }
  if (self->identifier == nil)
    [_ctx deleteLastElementIDComponent]; // delete index

  [_ctx deleteLastElementIDComponent]; // delete batchNumber
}

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  int            i, firstBatch, lastBatch, savedCurrentBatch;
  NSString       *eid;
  NSMutableArray *selArray = nil;

  [self updateStateInContext:_ctx];

  eid      = [_ctx elementID];

  /* handle "data" section */

  if (self->state->doCheckBoxes) {
    selArray = [self->selection valueInComponent:[_ctx component]];
    selArray = [selArray mutableCopyWithZone:[self zone]];
  }

  firstBatch = self->state->doScriptScrolling ? 1 : self->state->currentBatch;
  lastBatch  = (self->state->doScriptScrolling)
    ? self->state->batchCount
    : self->state->currentBatch;
  
  [_ctx appendElementIDComponent:@"data"];
  [_ctx setObject:YesNumber forKey:WETableView_DataMode];

  savedCurrentBatch = self->state->currentBatch;
  for (i = firstBatch; i <= lastBatch; i++) {    
    self->state->currentBatch = i;
    _applyState_(self, [_ctx component]);
    [self updateStateInContext:_ctx];

    [self takeValuesFromRequest:_rq
          forBatch:i
          selections:selArray
          inContext:_ctx];
  }
  [_ctx removeObjectForKey:WETableView_DataMode];
  
  if (self->state->currentBatch != (unsigned)savedCurrentBatch) {
    self->state->currentBatch = savedCurrentBatch;
    _applyState_(self, [_ctx component]);
  }

  [_ctx deleteLastElementIDComponent]; // delete "data"

  if (self->state->doCheckBoxes) {
    [self->selection setValue:selArray inComponent:[_ctx component]];
    [selArray release];
  }
  
  // handle header (sort buttons, ...)
  [_ctx setObject:YesNumber forKey:WETableView_HeaderMode];
  [_ctx appendElementIDComponent:@"header"];
  
  for (i = 1; i <= (int)self->state->batchCount; i++) {
    NSString *s;
    
    // TODO: improve
    s = retStrForInt(i);
    [_ctx appendElementIDComponent:s];
    [s release];
    
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
    [_ctx deleteLastElementIDComponent]; // delete batchNumber
  }

  [_ctx deleteLastElementIDComponent]; // delete "header"
  [_ctx removeObjectForKey:WETableView_HeaderMode];

  // handle title
  [_ctx setObject:YesNumber forKey:WETableView_TitleMode];
  [_ctx appendElementIDComponent:@"title"];
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "title"
  [_ctx removeObjectForKey:WETableView_TitleMode];

  // handle buttons
  [_ctx setObject:YesNumber forKey:WETableView_ButtonMode];
  [_ctx appendElementIDComponent:@"button"];
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "button"
  [_ctx removeObjectForKey:WETableView_ButtonMode];

  // handle footer
  [_ctx setObject:YesNumber forKey:WETableView_FooterMode];
  [_ctx appendElementIDComponent:@"footer"];

  // reset autoScrollHeight
  if ([_rq formValueForKey:[eid stringByAppendingString:@".footer.pp.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".pp"]];
  }
  else if ([_rq formValueForKey:
		  [eid stringByAppendingString:@".footer.mm.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".mm"]];
  }
 
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "footer"
  [_ctx removeObjectForKey:WETableView_FooterMode];

  if ([_rq formValueForKey:[eid stringByAppendingString:@".first.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".first"]];
  }
  if ([_rq formValueForKey:[eid stringByAppendingString:@".next.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".next"]];
  }
  if ([_rq formValueForKey:[eid stringByAppendingString:@".last.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".last"]];
  }
  if ([_rq formValueForKey:[eid stringByAppendingString:@".previous.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".previous"]];
  }
}

- (id)increaseAutoScrollHeightInContext:(WOContext *)_ctx {
  if ([self->autoScroll isValueSettable]) {
    int sh; // scrollHeight

    sh = [self->autoScroll intValueInComponent:[_ctx component]] + 20;
    [self->autoScroll setIntValue:sh inComponent:[_ctx component]];
  }
  return nil;
}

- (id)decreaseAutoScrollHeightInContext:(WOContext *)_ctx {
  if ([self->autoScroll isValueSettable]) {
    int sh; // scrollHeight

    sh = [self->autoScroll intValueInComponent:[_ctx component]] - 20;
    if (sh > 50)
      [self->autoScroll setIntValue:sh inComponent:[_ctx component]];
  }
  return nil;
}


- (id)increaseBatchSizeInContext:(WOContext *)_ctx {
  if ([self->batchSize isValueSettable]) {
    int bs;

    bs = [self->batchSize intValueInComponent:[_ctx component]] + 1;
    [self->batchSize setIntValue:bs inComponent:[_ctx component]];
  }
  return nil;
}

- (id)decreaseBatchSizeInContext:(WOContext *)_ctx {
  if ([self->batchSize isValueSettable]) {
    int bs;

    bs = [self->batchSize intValueInComponent:[_ctx component]] - 1;
    if (bs > 1)
      [self->batchSize setIntValue:bs inComponent:[_ctx component]];
  }
  return nil;
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent    *cmp;
  NSString       *eid;
  id             result = nil;

  [self updateStateInContext:_ctx];

  eid = [_ctx currentElementID];
  cmp = [_ctx component];

  if ([eid isEqual:@"first"])
    [self _handleFirstButtonInContext:_ctx];
  else if ([eid isEqual:@"previous"])
    [self _handlePreviousButtonInContext:_ctx];
  else if ([eid isEqual:@"next"])
    [self _handleNextButtonInContext:_ctx];
  else if ([eid isEqual:@"last"])
    [self _handleLastButtonInContext:_ctx];
  else if ([eid isEqual:@"data"]) {
    NSString *idxId;

    [_ctx consumeElementID];             // consume "data"
    [_ctx appendElementIDComponent:eid]; // append  "data"

    {
      NSString *bn;

      bn = [_ctx currentElementID];
      if ([self->currentBatch isValueSettable])
        [self->currentBatch setIntValue:[bn intValue] inComponent:cmp];
      
      [_ctx consumeElementID];            // consume batchNumber
      [_ctx appendElementIDComponent:bn]; // append batch
    }

    if ((idxId = [_ctx currentElementID])) {
      [_ctx consumeElementID];               // consume index-id
      [_ctx appendElementIDComponent:idxId]; // append index-id

      // reset batchSize
      if ([idxId isEqualToString:@"pp"])
        result = [self increaseBatchSizeInContext:_ctx];
      else if ([idxId isEqualToString:@"mm"])
        result = [self decreaseBatchSizeInContext:_ctx];
      else {
        if (self->identifier == nil) {
          unsigned idx;
      
          idx   = [idxId unsignedIntValue];
          if (idx < [self->allObjects count] && idx >= 0) {
            _applyItems_(self, cmp, idx);
          }
          else
            NSLog(@"WETableView: index is out of range!");
        }
        else
          _applyIdentifier(self, cmp, idxId);

        result = [self invokeGrouping:_rq inContext:_ctx];
      }
      [_ctx deleteLastElementIDComponent]; // delete index-id
    }
    [_ctx deleteLastElementIDComponent]; // delete batchNumber
    [_ctx deleteLastElementIDComponent]; // delete "data"
  }
  else if ([eid isEqual:@"header"]) {
    [_ctx consumeElementID];             // consume "header"
    [_ctx appendElementIDComponent:eid]; // append  "header"

    if ([self->currentBatch isValueSettable]) {
      int bn = [[_ctx currentElementID] intValue];
      [self->currentBatch setIntValue:bn inComponent:cmp];
    }
    [_ctx appendElementIDComponent:[_ctx currentElementID]]; // batchNumber
    [_ctx consumeElementID];                         // consume batchNumber

    // handle selectAllCheckBoxes:
    if ([[_ctx currentElementID] isEqualToString:@"_sa"]) {
      NSMutableArray *selArray;
        
      selArray = [self->allObjects mutableCopyWithZone:[self zone]];
      [self->selection setValue:selArray inComponent:cmp];
      [selArray release];
    }
    // handle deselectAllCheckBoxes:
    else if ([[_ctx currentElementID] isEqualToString:@"_dsa"]) {
      [self->selection setValue:[NSMutableArray array] inComponent:cmp];
    }
    else
      result = [self->template invokeActionForRequest:_rq inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete batchNumber
    [_ctx deleteLastElementIDComponent]; // delete "header"

    [self _handleSortActionInContext:_ctx];
    
    [_ctx removeObjectForKey:WETableView_SORTEDKEY];
    [_ctx removeObjectForKey:WETableView_ISDESCENDING];
  }
  else if ([eid isEqual:@"title"] || [eid isEqual:@"button"] ||
           [eid isEqual:@"footer"]) {
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:eid];

    eid = [_ctx currentElementID];

    // reset autoScrollHeight
    if ([eid isEqualToString:@"pp"])
      result = [self increaseAutoScrollHeightInContext:_ctx];
    else if ([eid isEqualToString:@"mm"])
      result = [self decreaseAutoScrollHeightInContext:_ctx];
    else
      result = [self->template invokeActionForRequest:_rq inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent];
  }
  else
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  /*
    The main HTML of the tableview are two tables:
    - a table with the: title+buttons, header and content
      this table has three rows:
      - a row for the title+buttons
      - some kind of padding row?
      - a row for the header and the content
        this is just a single cell with an embedded table with one row for
        the header and n-rows for the content
    - a separate table with the footer
  */
  WOComponent *cmp;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  [self updateStateInContext:_ctx];
  [self updateScriptIdInContext:_ctx];
  [self updateConfigInContext:_ctx];
  
  cmp = [_ctx component];

  /* open main tableView */
  // TODO: add CSS
  [_response appendContentString:
	       @"<table border='0' width='100%' "
	       @"cellpadding='0' cellspacing='0'>"];

  /* append tableTitle + navigation */
  [_response appendContentString:@"<tr><td>"];
  [self _appendTitle:_response inContext:_ctx];
  [_response appendContentString:@"</td></tr>"];

  [_response appendContentString:@"<tr><td></td></tr>"];
  
  if (self->state->doScriptScrolling) {
    [self _appendTableContentAsScript:_response inContext:_ctx]; //close tables
  }
  else {
    /* open header + data area */
    [_response appendContentString:@"<tr><td>"];
    
    if (self->state->doOverflow) {
      [_response appendContentString:
                 @"<p style=\"width:100%; height: "];
      [_response appendContentString:
                   [self->autoScroll stringValueInComponent:cmp]];
      [_response appendContentString:@"; overflow-y: auto\">"];
    }
    
    [_response appendContentString:@"<table width='100%' border='"];
    [_response appendContentString:[self->border stringValueInComponent:cmp]];
    [_response appendContentString:@"' cellpadding='"];
    [_response appendContentString:
               [self->cellpadding stringValueInComponent:cmp]];
    [_response appendContentString:@"' cellspacing='"];
    [_response appendContentString:
               [self->cellspacing stringValueInComponent:cmp]];
    [_response appendContentString:@"'>"];


    self->state->showBatchResizeButtons =
      ([self->showBatchResizeButtons boolValueInComponent:cmp] &&
       (self->state->currentBatch < self->state->batchCount) &&
       !self->state->doOverflow);
    
    [self _appendHeader:_response inContext:_ctx];
    [self _appendData:_response   inContext:_ctx];
  
    [_response appendContentString:@"</table>"];
    if (self->state->doOverflow)
      [_response appendContentString:@"</p>"];
    
    /* close header + data area */
    [_response appendContentString:@"</td></tr>"];
    
    [_response appendContentString:@"</table>"];                  // </TABLE>

    /* append footer */
    [self _appendFooter:_response inContext:_ctx];
  }
  
  // close tableView


  if (self->state->doScriptScrolling)
    [self appendJavaScript:_response inContext:_ctx];
  
  [self removeConfigInContext:_ctx];
}

@end /* WETableView */

@implementation WETableViewInfo
@end

// --- JavaScript additions -------------------------------------------------

@implementation WETableView(JavaScriptAdditions)

- (void)_appendGroupCollapseScript:(WOResponse *)_resp
  inContext:(WOContext *)_ctx
{
  if ([_ctx objectForKey:WETableView_HasCollapseScript])
    return;

  [_resp appendContentString:
           @"\n<script language=\"JavaScript\">\n"
           @"<!--\n"
           @"function toggleTableGroup()\n"
           @"{\n"
           @"   img = event.srcElement;\n"
           @"   visibility = img.isGroupVisible;\n"
           @"   visibility = (visibility != \"none\") ? \"none\" : \"\";\n"
           @"   img.isGroupVisible = visibility;\n"
           @"   img.src = (visibility == \"\") ? img.openImg : img.closeImg;\n"
           @"   groupName  = img.group;\n"
           @"   table  = img.parentNode.parentNode.parentNode;\n"
           @"   trList = table.getElementsByTagName(\"TR\");\n"
           @"   cnt    = trList.length;\n"
           @"   for (i=0; i<cnt; i++) {\n"
           @"     tr = trList[i];\n"
           @"     if (tr.groupName == groupName)\n"
           @"       tr.style.display = visibility;\n"
           @"   }\n"
           @"}\n"
           @"//-->\n"
           @"</script>\n"];
  [_ctx setObject:YesNumber forKey:WETableView_HasCollapseScript];
}

- (void)jsButton:(WOResponse *)_resp ctx:(WOContext *)_ctx
  name:(NSString *)_name button:(NSString *)_button 
{
  NSString *imgUri;
  NSString *n;
  
  _button = [_button stringByAppendingString:@".gif"];
  imgUri  = WEUriOfResource(_button, _ctx);
  n       = [_name stringByAppendingString:self->scriptID];
  
  n = [[StrClass alloc] initWithFormat:
          @"var %@ = new Image(); %@.src = \"%@\";\n", n, n, imgUri];
  [_resp appendContentString:n];
  [n release];
}
                                    
- (void)appendJavaScript:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  NSString *n;
  
  [_resp appendContentString:@"<script language=\"JavaScript\">\n<!--\n"];
  
  [self jsButton:_resp ctx:_ctx name:@"First"     button:@"first"];
  [self jsButton:_resp ctx:_ctx name:@"First2"    button:@"first_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Previous"  button:@"previous"];
  [self jsButton:_resp ctx:_ctx name:@"Previous2" button:@"previous_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Next"      button:@"next"];
  [self jsButton:_resp ctx:_ctx name:@"Next2"     button:@"next_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Last"      button:@"last"];
  [self jsButton:_resp ctx:_ctx name:@"Last2"     button:@"last_blind"];

  n = [[StrClass alloc] initWithFormat:
    @"function showPage%@() {\n"
    @"  for (var i=1; i< page%@.length; i++) {\n"
	@"    if (i == actualPage%@) {\n"
    @"      page%@[i][\"Div\"].style.display = \"\";\n"
    @"      footer%@[i][\"Div\"].style.display = \"\";\n"
    @"    }\n"
	@"    else {\n"
    @"      page%@[i][\"Div\"].style.display = \"none\";\n"
    @"      footer%@[i][\"Div\"].style.display = \"none\";\n"
    @"    }\n"
	@"	}\n"
	@"	flushImages%@();\n"
	@"}\n",
    self->scriptID, // showPage
    self->scriptID, // page.length
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID  // flushImages
  ];
  [_resp appendContentString:n];
  [n release];

  n = [[StrClass alloc] initWithFormat:
    @"function firstPage%@() {\n"
    @"  actualPage%@ = 1;\n"
    @"  showPage%@();\n"
    @"}\n",
    self->scriptID, // firstPage
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ];
  [_resp appendContentString:n];
  [n release];

  n = [[StrClass alloc] initWithFormat:
    @"function previousPage%@() {\n"
    @"	if (actualPage%@ > 1) {\n"
    @"    actualPage%@--;\n"
    @"    showPage%@();\n"
    @"  }\n"
	@"}\n",
    self->scriptID, // previousPage
    self->scriptID, // actualPage
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ];
  [_resp appendContentString:n];
  [n release];
  
  n = [[StrClass alloc] initWithFormat:
    @"function nextPage%@() {\n"
    @"  if (actualPage%@ < page%@.length - 1) {\n"
    @"    actualPage%@++;\n"
    @"    showPage%@();\n"
    @"	}\n"
	@"}\n",
    self->scriptID, // nextPage
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ];
  [_resp appendContentString:n];
  [n release];

  n = [[StrClass alloc] initWithFormat:
    @"function lastPage%@() {\n"
    @"  actualPage%@ = page%@.length - 1;\n"
    @"  showPage%@();\n"
    @"}\n",
    self->scriptID, // lastPage
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID  // showPage
  ];
  [_resp appendContentString:n];
  [n release];

  n = [[StrClass alloc] initWithFormat:
    @"function flushImages%@() {\n"
    @"  document.images[\"firstPageImg%@\"].src    = First%@.src;\n"
    @"  document.images[\"previousPageImg%@\"].src = Previous%@.src;\n"
    @"  document.images[\"nextPageImg%@\"].src     = Next%@.src;\n"
    @"  document.images[\"lastPageImg%@\"].src     = Last%@.src;\n"
    @"  if (actualPage%@ == 1) {\n"
    @"    document.images[\"firstPageImg%@\"].src    = First2%@.src;\n"
    @"    document.images[\"previousPageImg%@\"].src = Previous2%@.src;\n"
    @"  }\n"
                             
#if 0          
        @"  if (actualPage%@ == 2) {\n"
        @"    document.images[\"firstPageImg%@\"].src = First2%@.src;\n"
        @"  }\n"
        @"  if (actualPage%@ == page%@.length -2) {\n"
        @"    document.images[\"lastPageImg%@\"].src = Last2%@.src;\n"
        @"  }\n"
#endif
                                       
    @"  if (actualPage%@ == page%@.length - 1) {\n"
    @"    document.images[\"nextPageImg%@\"].src = Next2%@.src;\n"
    @"    document.images[\"lastPageImg%@\"].src = Last2%@.src;\n"
    @"  }\n"
    @"}\n",
    self->scriptID, // flushImages
    self->scriptID, // firstPageImg
    self->scriptID, // First
    self->scriptID, // previousPageImg
    self->scriptID, // Previous
    self->scriptID, // nextPageImg
    self->scriptID, // Next
    self->scriptID, // lastPageImg
    self->scriptID, // Last
    self->scriptID, // actualPage
    self->scriptID, // firstPageImg
    self->scriptID, // First2
    self->scriptID, // previousPageImg
    self->scriptID, // Previous2
                                       
#if 0
    self->scriptID, // actualPage
    self->scriptID, // firstPageImg
    self->scriptID, // First2
                                       
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // lastPageImg
    self->scriptID, // Last2
#endif
                                       
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // nextPageImg,
    self->scriptID, // Next2
    self->scriptID, // lastPageImg
    self->scriptID  // Last2
  ];
  [_resp appendContentString:n];
  [n release];
  
  n = [[StrClass alloc] initWithFormat:
    @"var page%@   = new Array();\n"
    @"var footer%@ = new Array();\n"
    @"var actualPage%@ = %d;",
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID, //actualPage
    self->state->currentBatch
  ];
  [_resp appendContentString:n];
  [n release];

  {
    unsigned i;

    for (i = 1; i <= self->state->batchCount; i++) {
      n = [[StrClass alloc] initWithFormat:
        @"page%@[%d] = new Array();\n"
        @"page%@[%d][\"Div\"] = page%dDiv%@;\n\n"
        @"footer%@[%d] = new Array();\n"
        @"footer%@[%d][\"Div\"] = footer%dDiv%@;\n\n",
        self->scriptID, // page
        i,              // page[i]
        self->scriptID, // page
        i,              // page[i]
        i,              // pageiDiv
        self->scriptID, // pageDiv
        self->scriptID, // footer
        i,              // footer[i]
        self->scriptID, // footer
        i,              // footer[i]
        i,              // footeriDiv
        self->scriptID  // footerDiv
      ];
      [_resp appendContentString:n];
      [n release];
    }
  }
  n = [[StrClass alloc] initWithFormat:@"showPage%@();", self->scriptID];
  [_resp appendContentString:n];
  [n release];

  [_resp appendContentString:@"//-->\n</script>\n"];
}

- (void)_appendTableContentAsScript:(WOResponse *)_resp 
  inContext:(WOContext *)_ctx
{
  WOComponent *cmp;
  unsigned i, savedBatchIndex;

  cmp = [_ctx component];
  
  savedBatchIndex = self->state->currentBatch;
  /* open header + data area */
  [_resp appendContentString:@"<tr><td>"];

  for (i = 1; i <= self->state->batchCount; i++) {
    NSString *s;
    
    self->state->currentBatch = i;
    _applyState_(self, cmp);
    [self updateStateInContext:_ctx];
    
    s = [[StrClass alloc] initWithFormat:         // <DIV...>
      @"<div id=\"page%dDiv%@\" style=\"display: ; \">", i, self->scriptID];
    [_resp appendContentString:s];
    [s release];

    [_resp appendContentString:
           @"<table border='0' width='100%' cellpadding='1' cellspacing='0'>"];
    
    [self _appendHeader:_resp inContext:_ctx];
    [self _appendData:_resp inContext:_ctx];
    
    [_resp appendContentString:@"</table>"];
    [_resp appendContentString:@"</div>"];                        // </DIV>
    

    /* append footer */
    s = [[StrClass alloc] initWithFormat:        // <DIV...>
      @"<div id=\"footer%dDiv%@\" style=\"display: ; \">", i, self->scriptID];
    [_resp appendContentString:s];
    [s release];

    [self _appendFooter:_resp inContext:_ctx];
    
    [_resp appendContentString:@"</div>"];                        // </DIV>
  }
  
  /* close header + data area */
  [_resp appendContentString:@"</td></tr>"];
  if (self->state->currentBatch != savedBatchIndex) {
    self->state->currentBatch = savedBatchIndex;
    _applyState_(self, cmp);
  }
  [self updateStateInContext:_ctx];
}

- (void)_appendScriptLink:(WOResponse *)_response name:(NSString *)_name {
  NSString *s;
  
  [_response appendContentString:@"JavaScript:"];
  [_response appendContentString:_name];
  s = [[StrClass alloc] initWithFormat:@"Page%@();", self->scriptID];
  [_response appendContentString:s];
  [s release];
}

- (void)_appendScriptImgName:(WOResponse *)_response name:(NSString *)_name {
  [_response appendContentString:_name];
  [_response appendContentString:@"PageImg"];
  [_response appendContentString:self->scriptID];
}

@end /* WETableView(JavaScriptAdditions) */
