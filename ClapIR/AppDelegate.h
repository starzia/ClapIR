//
//  AppDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import <UIKit/UIKit.h>
#import "ClapRecorder.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong) ClapRecorder* recorder;

@end
