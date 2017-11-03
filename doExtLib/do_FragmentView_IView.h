//
//  do_FragmentView_UI.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol do_FragmentView_IView <NSObject>

@required
//属性方法
- (void)change_templates:(NSString *)newValue;
- (void)change_allowAnimation:(NSString *)newValue;
- (void)change_supportGesture:(NSString *)newValue;

//同步或异步方法
- (void)bindItems:(NSArray *)parms;
- (void)refreshItems:(NSArray *)parms;
- (void)showLeft:(NSArray *)parms;
- (void)showRight:(NSArray *)parms;
- (void)reset:(NSArray *)parms;


@end