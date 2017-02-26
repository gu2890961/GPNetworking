//
//  NetViewController.m
//  GPNetworking
//
//  Created by apple on 2017/2/25.
//  Copyright © 2017年 gupeng. All rights reserved.
//

#import "NetViewController.h"
#import "GPNetworkManager.h"

@interface NetViewController ()
{
    NSString *urlStr;
    NSString *baseUrl;
    NSDictionary *parm;
}
@end

@implementation NetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self confingNet];
}

- (void)confingNet {
    _progressView.progress = 0;
    _progressLabel.text = @"0.00%";
    switch (_type) {
        case GPNetTypeGet:
            urlStr = @"http://api.map.baidu.com/telematics/v3/weather?location=嘉兴&output=json&ak=5slgyqGDENN7Sy7pw29IUvrZ";
            baseUrl = @"http://api.map.baidu.com";
            break;
        case GPNetTypePost:
            urlStr = @"http://data.zz.baidu.com/urls?site=www.henishuo.com&token=bRidefmXoNxIi3Jp";
            baseUrl = @"http://data.zz.baidu.com";
            parm = @{ @"urls": @"http://www.henishuo.com/git-use-inwork/",
                      @"goal" : @"site",
                      @"total" : @(123)
                      };
            break;
        case GPNetTypeDown:
            baseUrl = @"http://wiki.lbsyun.baidu.com";
            urlStr = @"http://wiki.lbsyun.baidu.com/cms/iossdk/sdk/BaiduMap_IOSSDK_v2.10.2_All.zip";
            break;
            
        default:
            break;
    }
    _baseTextField.text = baseUrl;
    _urlTextField.text = urlStr;
    [GPNetworkManager enableInterfaceDebug:YES];
    [GPNetworkManager configRequestType:kGPRequestTypeJSON responseType:kGPResponseTypeJSON shouldAutoEncodeUrl:YES callbackOnCancelRequest:YES];
}

- (IBAction)sartButtonClick:(id)sender {
    switch (_type) {
        case GPNetTypeGet:
            [self getRequest];
            break;
        case GPNetTypePost:
            [self postRequest];
            break;
        case GPNetTypeDown:
            [self downRequest];
            break;
            
        default:
            break;
    }
}

- (void)getRequest {
    __weak typeof(self) weakSelf = self;
    [GPNetworkManager getWithUrl:_urlTextField.text loadCache:_loadCacheSwitch.isOn refreshCache:_refreshSwitch.isOn params:nil progress:^(int64_t bytesRead, int64_t totalBytesRead) {
        CGFloat progress = (float)bytesRead/totalBytesRead;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.progressView setProgress:progress animated:YES];
            weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.2f%%",progress*100];
            NSLog(@"%f %lld   %lld ",progress,bytesRead,totalBytesRead);
        });
    } success:^(id response) {
        weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",response];
    } fail:^(NSError *error) {
         weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",error.localizedDescription];
    }];
}

- (void)postRequest {
    __weak typeof(self) weakSelf = self;
    [GPNetworkManager postWithUrl:_urlTextField.text loadCache:_loadCacheSwitch.isOn refreshCache:_refreshSwitch.isOn params:parm progress:^(int64_t bytesRead, int64_t totalBytesRead) {
        CGFloat progress = (float)bytesRead/totalBytesRead;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.progressView setProgress:progress animated:YES];
            weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.2f%%",progress*100];
            NSLog(@"%f %lld   %lld ",progress,bytesRead,totalBytesRead);
        });
    } success:^(id response) {
        weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",response];
    } fail:^(NSError *error) {
        weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",error.localizedDescription];
    }];
}

- (void)downRequest {
    __weak typeof(self) weakSelf = self;
    NSString *patch = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/BaiduMap_IOSSDK.zip"];

    [GPNetworkManager downloadWithUrl:_urlTextField.text saveToPath:patch progress:^(int64_t bytesRead, int64_t totalBytesRead) {
        CGFloat progress = (float)bytesRead/totalBytesRead;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.progressView setProgress:progress animated:YES];
            weakSelf.progressLabel.text = [NSString stringWithFormat:@"%.2f%%",progress*100];
            NSLog(@"%f %lld   %lld ",progress,bytesRead,totalBytesRead);
        });
        
    } success:^(id response) {
        weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",response];
    } failure:^(NSError *error) {
        weakSelf.infoLabel.text = [NSString stringWithFormat:@"%@",error.localizedDescription];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
-(void)dealloc
{
    NSLog(@"delloc");
    [GPNetworkManager cancelRequestWithURL:_urlTextField.text];
}
@end
