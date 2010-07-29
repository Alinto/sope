
#include <Foundation/NSObject.h>

@class NSString, NSCalendarDate;

@interface SlashDotStory : NSObject
{
  NSString       *title;
  NSString       *url;
  NSCalendarDate *time;
  NSString       *author;
  NSString       *department;
  NSString       *topic;
  unsigned       numberOfComments;
  NSString       *section;
  NSString       *image;
}
@end

#import <Foundation/Foundation.h>

@implementation SlashDotStory

- (void)setTitle:(NSString *)_value {
  ASSIGN(self->title, _value);
}
- (NSString *)title {
  return self->title;
}

- (void)setUrl:(NSString *)_value {
  ASSIGN(self->url, _value);
}
- (NSString *)url {
  return self->url;
}

- (void)setTime:(NSCalendarDate *)_value {
  if (![_value isKindOfClass:[NSCalendarDate class]]) {
    NSString *svalue;
    
    svalue = [[_value description] stringByAppendingString:@" GMT"];
    _value = [NSCalendarDate dateWithString:svalue
                             calendarFormat:@"%Y-%m-%d %H:%M:%S %Z"];
  }
  ASSIGN(self->time, _value);
}
- (NSCalendarDate *)time {
  return self->time;
}

- (void)setAuthor:(NSString *)_value {
  ASSIGN(self->author, _value);
}
- (NSString *)author {
  return self->author;
}

- (void)setDepartment:(NSString *)_value {
  ASSIGN(self->department, _value);
}
- (NSString *)department {
  return self->department;
}

- (void)setTopic:(NSString *)_topic {
  ASSIGN(self->topic, _topic);
}
- (NSString *)topic {
  return self->topic;
}

- (void)setNumberOfComments:(unsigned)_count {
  self->numberOfComments = _count;
}
- (unsigned)numberOfComments {
  return self->numberOfComments;
}

- (void)setSection:(NSString *)_section {
  ASSIGN(self->section, _section);
}
- (NSString *)section {
  return self->section;
}

- (void)setImage:(NSString *)_image {
  ASSIGN(self->image, _image);
}
- (NSString *)image {
  return self->image;
}

/* description */

- (NSString *)description {
  NSMutableString *s;

  s = [NSMutableString stringWithCapacity:200];

  [s appendFormat:@"<%@[0x%p]: author=%@ topic=%@ title='%@'>",
       NSStringFromClass([self class]), self,
       [self topic],
       [self title],
       [self author]];
  
  return s;
}

@end /* SlashDotStory */
