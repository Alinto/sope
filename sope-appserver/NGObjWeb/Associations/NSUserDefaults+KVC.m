
#import <Foundation/NSUserDefaults.h>

@implementation NSUserDefaults(KeyValueCoding)

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  [self setObject:_value forKey:_key];
}

- (id)valueForKey:(NSString *)_key {
  return [self objectForKey:_key];
}

@end /* NSUserDefaults(KeyValueCoding) */
