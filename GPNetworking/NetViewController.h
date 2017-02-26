//
//  NetViewController.h
//  GPNetworking
//
//  Created by apple on 2017/2/25.
//  Copyright © 2017年 gupeng. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef NS_ENUM(NSUInteger, GPNetType) {
    GPNetTypeGet = 1,
    GPNetTypePost = 2,
    GPNetTypeDown
};

@interface NetViewController : UIViewController
@property (nonatomic , assign) GPNetType type;

@property (weak, nonatomic) IBOutlet UITextView *infoLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UISwitch *loadCacheSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *refreshSwitch;
@property (weak, nonatomic) IBOutlet UITextField *baseTextField;
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;

@end
