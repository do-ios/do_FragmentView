//
//  do_FragmentView_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_FragmentView_UIView.h"

#import "doInvokeResult.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doIPage.h"
#import "doUIContainer.h"
#import "doISourceFS.h"
#import "doJsonHelper.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"


#define SET_CENTERY(VIEW) centerY = (CGRectGetHeight(VIEW.frame)>=CGRectGetHeight(self.frame))?CGRectGetHeight(VIEW.frame)/2:(CGRectGetHeight(self.frame)-CGRectGetHeight(VIEW.frame))/2+CGRectGetHeight(VIEW.frame)/2

#define PANVIEWX CGRectGetMinX(panView.frame)
#define ANIMATION_DURATION .3


@interface do_FragmentView_UIView ()<UIGestureRecognizerDelegate>

@property (nonatomic,strong) UIView *coverView;

@end


@implementation do_FragmentView_UIView
{
    id<doIListData> _dataArray;
    NSMutableArray *_templates;

    UIView *_leftView;
    UIView *_middleView;
    UIView *_rightView;

    UIPanGestureRecognizer *_panRecognizer;
    
    UITapGestureRecognizer *_tapRecognizer;

    CGRect _leftRect,_rightRect,_middleRect;
    
    NSString *_direction;
    
    BOOL _isPan;
    
    NSString *_isState;
    
    BOOL _isAnimation;
    
    BOOL _isValidate;
    
    BOOL _isAllowAnimation;

    CGFloat MiddlePageScale;
    
    CGFloat SideViewScale;
    
    NSString *_supportGesture;
}
#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    _templates = [NSMutableArray array];
    
    _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(showView:)];
    [self addGestureRecognizer:_panRecognizer];

    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideView:)];
    _tapRecognizer.numberOfTapsRequired = 1;
    _tapRecognizer.numberOfTouchesRequired = 1;

    _isAnimation = NO;
    _direction = @"left";
    
    _isPan = NO;
    
    _isState = @"close";
    _isValidate = YES;
    
    MiddlePageScale = 1;
    SideViewScale = 1;
    
    _supportGesture = @"both";
    self.layer.masksToBounds = true;
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性,view-model(UIModel)类销毁时会递归调用<子view-model(UIModel)>的该方法，将上层的引用切断。所以如果self类有非原生扩展，需主动调用view-model(UIModel)的该方法。(App || Page)-->强引用-->view-model(UIModel)-->强引用-->view
    _model = nil;
    [(doModule*)_dataArray Dispose];
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self disposeContent];

    _panRecognizer = nil;
}
//实现布局
- (void) OnRedraw
{
    //实现布局相关的修改,如果添加了非原生的view需要主动调用该view的OnRedraw，递归完成布局。view(OnRedraw)<显示布局>-->调用-->view-model(UIModel)<OnRedraw>
    
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
}

#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
- (void)change_templates:(NSString *)newValue
{
    //自己的代码实现
    _templates = (NSMutableArray *)[newValue componentsSeparatedByString:@","];
}

- (void)change_allowAnimation:(NSString *)newValue
{
    _isAllowAnimation = [newValue boolValue];
    if (_isAllowAnimation) {
        MiddlePageScale = .7;
        SideViewScale = .7;
    }else{
        MiddlePageScale = 1;
        SideViewScale = 1;
    }
}

- (void)change_supportGesture:(NSString *)newValue
{
    if (!newValue || newValue.length==0) {
        return;
    }
    _supportGesture = newValue;
}


- (void)resetDisplay
{
    [self disposeContent];
    NSDictionary *dict = [_dataArray GetData:0];
    for (NSString *t in dict.allKeys) {
        NSString *v = dict[t];
        if ([t isEqualToString:@"template"]) {
            _middleView = [self getView:v];
        }else if([t isEqualToString:@"leftTemplate"]){
            _leftView = [self getView:v];
        }else if([t isEqualToString:@"rightTemplate"]){
            _rightView = [self getView:v];
        }
    }
    [self initialization];
}

- (void)initialization
{
    if (_leftView) {
        _leftView.frame = CGRectMake(-CGRectGetWidth(_leftView.frame)-1, 0, CGRectGetWidth(_leftView.frame), CGRectGetHeight(_leftView.frame));
        [self addSubview:_leftView];
        [self bringSubviewToFront:_leftView];
        _leftRect = _leftView.frame;
    }
    if (_middleView) {
        _middleView.frame = CGRectMake(0, 0, CGRectGetWidth(_middleView.frame), CGRectGetHeight(_middleView.frame));
        [self addSubview:_middleView];
        _middleRect = _middleView.frame;
    }
    if (_rightView) {
        _rightView.frame = CGRectMake(CGRectGetWidth(self.frame)+1, 0, CGRectGetWidth(_rightView.frame), CGRectGetHeight(_rightView.frame));
        [self addSubview:_rightView];
        [self bringSubviewToFront:_rightView];
        _rightRect = _rightView.frame;
    }
    

    if (!self.coverView) {
        UIView *view = [UIView new];
        view.frame = self.bounds;
        view.backgroundColor = [UIColor blackColor];
        view.alpha = 0;
        self.coverView = view;
    }
    [self addSubview:self.coverView];
    [self sendSubviewToBack:self.coverView];
    self.coverView.userInteractionEnabled = YES;

    
    [self.coverView addGestureRecognizer:_tapRecognizer];
}

- (void)disposeContent
{
    [_leftView removeFromSuperview];
    _leftView = nil;
    [_middleView removeFromSuperview];
    _middleView = nil;
    [_rightView removeFromSuperview];
    _rightView = nil;
}

- (UIView *)getView:(NSString *)template
{
    if (_templates.count==0) {
        return nil;
    }
    int index = [template intValue];
    if ([template intValue]<0||[template intValue]>=_templates.count) {
        index = 0;
    }
    NSString *templateName = [_templates objectAtIndex:index];
    doSourceFile *source = [[[_model.CurrentPage CurrentApp] SourceFS] GetSourceByFileName:templateName];
    @try {
        if(!source)
        {
            [NSException raise:@"doFragmentView" format:@"无效的模板",nil];
            
            return nil;
        }
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
        
        return nil;
    }

    id<doIPage> pageModel = _model.CurrentPage;
    doUIModule* module;
    UIView *view ;
    NSDictionary *dict = [_dataArray GetData:0];
    doUIContainer *container = [[doUIContainer alloc] init:pageModel];
    [container LoadFromFile:source:nil:nil];
    module = container.RootView;
    [container LoadDefalutScriptFile:templateName];
    
    view = (UIView*)(((doUIModule*)module).CurrentUIModuleView);
    id<doIUIModuleView> modelView =((doUIModule*) module).CurrentUIModuleView;
    [modelView OnRedraw];
    [module SetModelData:dict];

    return view;
}


- (void)showView:(UIPanGestureRecognizer *)pan
{
    if (([_isState isEqualToString:@"left"] && [_supportGesture isEqualToString:@"right"]) || ([_isState isEqualToString:@"right"] && [_supportGesture isEqualToString:@"left"])) {
        return;
    }
    CGPoint velocity = [pan velocityInView:self];
    CGPoint point1 = [pan locationInView:self];

    _isValidate = YES;
    if(CGRectGetMinX(_middleView.frame)==0){
        if (velocity.x>0) {
            if (point1.x>60) {
                _isValidate = NO;
            }
        }else{
            if (point1.x<(CGRectGetWidth(self.frame)-60)) {
                _isValidate = NO;
            }
        }
    }

    if (!_isValidate) {
        return;
    }

    CGPoint point = [pan translationInView:self];
    UIView *panView = _middleView;
    
    if ((((point.x >= 0 && (!_leftView || [_supportGesture isEqualToString:@"right"])) || (point.x <= 0 && (!_rightView || [_supportGesture isEqualToString:@"left"])))&&CGRectGetMinX(_middleView.frame)==0)) {
        _middleView.frame = CGRectMake(0, 0, CGRectGetWidth(_middleView.frame), CGRectGetHeight(_middleView.frame));
        return;
    }

    if (([_isState isEqualToString:@"left"] && point.x>=0) || ([_isState isEqualToString:@"right"] && point.x<=0)) {
        return;
    }else
        _isState = @"close";

    _isPan = YES;

    if (_rightView&&CGRectGetMinX(_rightView.frame)<CGRectGetWidth(self.frame)&&CGRectGetMaxX(_leftView.frame)<=0) {
        _direction = @"right";
    }else if (_leftView&&CGRectGetMaxX(_leftView.frame)>0&&CGRectGetMinX(_rightView.frame)>=CGRectGetWidth(self.frame)){
        _direction = @"left";
    }else
        if (point.x > 0) {
            _direction = @"left";
        }else
            _direction = @"right";

    if (_leftView&&!_rightView) {
        _direction = @"left";
    }else if(_rightView&&!_leftView)
        _direction = @"right";

    CGFloat centerX = panView.center.x;
    CGFloat pointX = point.x;
    centerX += pointX;
    
    CGFloat centerY;
    
    //scale 1.0~kMainPageScale
    CGFloat scale = 1 - (1 - MiddlePageScale) * (fabs(CGRectGetMinX(panView.frame)) / CGRectGetWidth(_leftRect));
    if ([_direction isEqualToString:@"right"]) {
        scale = 1 - (1 - MiddlePageScale) * fabs(CGRectGetMinX(panView.frame) / CGRectGetWidth(_rightRect));
    }
    _middleView.transform = CGAffineTransformScale(CGAffineTransformIdentity,scale, scale);
    [pan setTranslation:CGPointMake(0, 0) inView:self];
    
    //leftScale kLeftScale~1.0
    CGFloat sideScale = SideViewScale + (1 - SideViewScale) * (CGRectGetMinX(panView.frame) / CGRectGetWidth(_leftRect));
    
    CGFloat coverX;
    
    if ([_direction isEqualToString:@"left"]) {
        _leftView.transform = CGAffineTransformScale(CGAffineTransformIdentity, sideScale,sideScale);
        CGFloat validateX = centerX - CGRectGetWidth(_middleView.frame)/2 - CGRectGetWidth(_leftRect);
        if (validateX < 0) {
            validateX = 0;
        }
        SET_CENTERY(panView);
        panView.center = CGPointMake(centerX-validateX,centerY);
        SET_CENTERY(_leftView);
        _leftView.center = CGPointMake(CGRectGetMinX(panView.frame)-CGRectGetWidth(_leftView.frame)/2, centerY);
        coverX = CGRectGetMinX(_middleView.frame);
    }else{
        sideScale = SideViewScale + (1 - SideViewScale) * ((CGRectGetWidth(_middleRect)-CGRectGetMaxX(_middleView.frame)) / CGRectGetWidth(_rightRect));
        _rightView.transform = CGAffineTransformScale(CGAffineTransformIdentity, sideScale,sideScale);
        
        CGFloat validateX = CGRectGetWidth(self.frame) - centerX - CGRectGetWidth(panView.frame)/2 - CGRectGetWidth(_rightRect);
        if (validateX < 0) {
            validateX = 0;
        }
        SET_CENTERY(panView);
        panView.center = CGPointMake(centerX+validateX,centerY);
        SET_CENTERY(_rightView);
        _rightView.center = CGPointMake(CGRectGetMaxX(panView.frame)+CGRectGetWidth(_rightView.frame)/2, centerY);
        coverX = CGRectGetMaxX(_middleView.frame)-CGRectGetWidth(_middleRect);
    }
    
    BOOL _isReset = NO;
    if (!_rightView || [_supportGesture isEqualToString:@"left"]){
        if (CGRectGetMaxX(_leftView.frame)<0) {
            _isReset = YES;
        }
    }
    if (_leftView || [_supportGesture isEqualToString:@"right"]) {
        if (CGRectGetMaxX(_rightView.frame)<CGRectGetMinX(self.frame)) {
            _isReset = YES;
        }
    }
    
    if (_isReset) {
        [self resetWithoutAnimation];
        return;
    }

    [self bringSubviewToFront:self.coverView];
    self.coverView.frame = CGRectMake(coverX, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
    self.coverView.alpha = sideScale-.5;

    if (pan.state == UIGestureRecognizerStateEnded) {
        [self resetPosition];
    }

    _isPan = NO;
}

- (void)resetPosition
{
    if ([_direction isEqualToString:@"left"]) {
        if ((CGRectGetMinX(_middleView.frame) >= CGRectGetWidth(_leftRect)/2)) {
            [self openLeftView];
        }else
            [self closeLeftView];
    }else{
        if ((CGRectGetWidth(_middleRect)-CGRectGetMinX(_rightView.frame)) >= CGRectGetWidth(_rightRect)/2) {
            [self openRightView];
        }else
            [self closeRightView];
    }
}


- (void)hideView:(UITapGestureRecognizer *)tap
{
    if (_isPan) {
        return;
    }
    CGPoint point = [tap locationInView:self.coverView];
    if (point.x >0&&point.y>0) {
        if ([_direction isEqualToString:@"left"]) {
            [self closeLeftView];
        }else
            [self closeRightView];
    }
}

- (void)closeLeftView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendSubviewToBack:self.coverView];
        self.coverView.alpha = 0;
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            _middleView.transform = CGAffineTransformIdentity;
            _middleView.center = CGPointMake(CGRectGetWidth(_middleRect)/2, CGRectGetMidY(_middleView.bounds));
            _leftView.transform = CGAffineTransformIdentity;
            _leftView.center = CGPointMake(-(CGRectGetWidth(_leftRect)/2), CGRectGetMidY(_leftView.bounds));
        }  completion:^(BOOL finished) {
            self.coverView.frame = self.bounds;
            _isState = @"close";
            _isAnimation = NO;
        }];
    });
}

- (void)openLeftView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bringSubviewToFront:self.coverView];
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            _leftView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.0,1.0);
            _leftView.center = CGPointMake(CGRectGetWidth(_leftRect)/2, CGRectGetMidY(_leftView.bounds));
            _middleView.transform = CGAffineTransformScale(CGAffineTransformIdentity, MiddlePageScale,MiddlePageScale);
            CGFloat centerY ;
            SET_CENTERY(_middleView);
            _middleView.center = CGPointMake(CGRectGetMaxX(_leftView.frame)+CGRectGetWidth(_middleView.frame)/2, centerY);
            self.coverView.alpha = .5;
            self.coverView.center = CGPointMake(CGRectGetMaxX(_leftView.frame)+CGRectGetWidth(self.coverView.frame)/2, CGRectGetMidY(self.coverView.frame));
        } completion:^(BOOL finished) {
            _isState = @"left";
            _isAnimation = NO;
        }];
    });
}

- (void)closeRightView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self sendSubviewToBack:self.coverView];
        self.coverView.alpha = 0;
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            _middleView.transform = CGAffineTransformIdentity;
            _middleView.center = CGPointMake(CGRectGetWidth(_middleRect)/2, CGRectGetMidY(_middleView.bounds));
            _rightView.transform = CGAffineTransformIdentity;
            _rightView.center = CGPointMake(CGRectGetWidth(self.frame)+1+CGRectGetWidth(_rightRect)/2, CGRectGetMidY(_rightView.bounds));
        }  completion:^(BOOL finished) {
            self.coverView.frame = self.bounds;
            _isState = @"close";
            _isAnimation = NO;
        }];
    });
}

- (void)openRightView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bringSubviewToFront:self.coverView];
        [UIView animateWithDuration:ANIMATION_DURATION animations:^{
            _rightView.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.0,1.0);
            _rightView.center = CGPointMake(CGRectGetWidth(self.frame)-CGRectGetWidth(_rightRect)/2, CGRectGetMidY(_rightView.bounds));
            _middleView.transform = CGAffineTransformScale(CGAffineTransformIdentity, MiddlePageScale,MiddlePageScale);
            CGFloat centerY ;
            SET_CENTERY(_middleView);
            _middleView.center = CGPointMake(CGRectGetMinX(_rightView.frame)-CGRectGetWidth(_middleView.frame)/2, centerY);
            self.coverView.alpha = .5;
            self.coverView.center = CGPointMake(CGRectGetMinX(_rightView.frame)-CGRectGetWidth(self.coverView.frame)/2, CGRectGetMidY(self.coverView.frame));
        } completion:^(BOOL finished) {
            _isState = @"right";
            _isAnimation = NO;
        }];
    });
}



#pragma mark -
#pragma mark - 同步异步方法的实现
//同步
- (void)bindItems:(NSArray *)parms
{
    NSDictionary * _dictParas = [parms objectAtIndex:0];
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString* _address = [doJsonHelper GetOneValue:_dictParas :@"data"];

    @try {
        if (_address == nil || _address.length <= 0) [NSException raise:@"doFragmentView" format:@"未指定相关的doFragmentView data参数！",nil];
        id bindingModule = [doScriptEngineHelper ParseMultitonModule: _scriptEngine : _address];
        if (bindingModule == nil) [NSException raise:@"doFragmentView" format:@"data参数无效！",nil];
        if([bindingModule conformsToProtocol:@protocol(doIListData)])
        {
            if(_dataArray!= bindingModule)
                _dataArray = bindingModule;
            if ([_dataArray GetCount]>0) {
                [self refreshItems:parms];
            }
        }
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
}
- (void)refreshItems:(NSArray *)parms
{
    [self resetDisplay];
}


- (void)reset:(NSArray *)parms
{
    if (_isAnimation) {
        return ;
    }else
        _isAnimation = YES;
    if ([_direction isEqualToString:@"left"]) {
        [self closeLeftView];
    }else{
        [self closeRightView];
    }
}

- (void)resetWithoutAnimation
{
    self.coverView.frame = self.bounds;
    self.coverView.alpha = 0;
    
    if (_leftView) {
        _leftView.transform = CGAffineTransformIdentity;
        _leftView.frame = _leftRect;
    }
    if (_middleView) {
        _middleView.transform = CGAffineTransformIdentity;
        _middleView.frame = _middleRect;
    }
    if (_rightView) {
        _rightView.transform = CGAffineTransformIdentity;
        _rightView.frame = _rightRect;
    }
}

- (void)showLeft:(NSArray *)parms
{
    if (!_leftView) {
        [[doServiceContainer Instance].LogEngine WriteError:nil : @"左边模板不存在"];
        return;
    }
    if (_isAnimation) {
        return ;
    }else
        _isAnimation = YES;
    if (![_direction isEqualToString:@"left"]) {
        [self resetWithoutAnimation];
    }
    _isPan = YES;
    _direction = @"left";
    [self openLeftView];
    _isPan = NO;
}
- (void)showRight:(NSArray *)parms
{
    if (!_rightView) {
        [[doServiceContainer Instance].LogEngine WriteError:nil : @"右边模板不存在"];
        return;
    }
    if (_isAnimation) {
        return ;
    }else
        _isAnimation = YES;
    if (![_direction isEqualToString:@"right"]) {
        [self resetWithoutAnimation];
    }
    _isPan = YES;
    _direction = @"right";
    [self openRightView];
    _isPan = NO;
}

#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}

@end
