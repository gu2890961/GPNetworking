//
//  GPNetworking.m
//  GPNetworking
//
//  Created by apple on 2017/2/25.
//  Copyright © 2017年 gupeng. All rights reserved.
//

#import "GPNetworkManager.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFNetworking.h"
#import "AFHTTPSessionManager.h"

#import <CommonCrypto/CommonDigest.h>

@interface NSString (md5)

+ (NSString *)gpnetworking_md5:(NSString *)string;

@end

@implementation NSString (md5)

+ (NSString *)gpnetworking_md5:(NSString *)string {
    if (string == nil || [string length] == 0) {
        return nil;
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([string UTF8String], (int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSMutableString *ms = [NSMutableString string];
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat:@"%02x", (int)(digest[i])];
    }
    
    return [ms copy];
}
@end

static NSString *gp_privateNetworkBaseUrl = nil;
static BOOL gp_isEnableInterfaceDebug = YES;
static BOOL gp_shouldAutoEncode = NO;
static NSDictionary *gp_httpHeaders = nil;
static GPResponseType gp_responseType = kGPResponseTypeJSON;
static GPRequestType  gp_requestType  = kGPRequestTypePlainText;
static GPNetworkStatus gp_networkStatus = kGPNetworkStatusReachableViaWiFi;
static NSMutableArray *gp_requestTasks;
static BOOL gp_shouldCallbackOnCancelRequest = YES;
static NSTimeInterval gp_timeout = 60.0f;
static BOOL gp_shouldObtainLocalWhenUnconnected = NO;
static BOOL gp_isBaseURLChanged = YES;
static AFHTTPSessionManager *gp_sharedManager = nil;
static NSUInteger gp_maxCacheSize = 0;

@implementation GPNetworkManager


+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 尝试清除缓存
        if (gp_maxCacheSize > 0 && [self totalCacheSize] > 1024 * 1024 * gp_maxCacheSize) {
            [self clearCaches];
        }
    });
}

+ (void)autoToClearCacheWithLimitedToSize:(NSUInteger)mSize {
    gp_maxCacheSize = mSize;
}


+ (void)updateBaseUrl:(NSString *)baseUrl
{
    if (![baseUrl isEqualToString:gp_privateNetworkBaseUrl] && baseUrl && baseUrl.length>0) {
        gp_isBaseURLChanged = YES;
    }else{
        gp_isBaseURLChanged = NO;
    }
    gp_privateNetworkBaseUrl = baseUrl;
}

+ (NSString *)baseUrl
{
    return gp_privateNetworkBaseUrl;
}

+ (void)setTimeout:(NSTimeInterval)timeout{
    gp_timeout = timeout;
}

+ (void)obtainDataFromLocalWhenNetworkUnconnected:(BOOL)shouldObtain
{
    gp_shouldObtainLocalWhenUnconnected = shouldObtain;
    if (gp_shouldObtainLocalWhenUnconnected) {
        //探测网络情况
        [self detectNetwork];
    }
}
//打开调试
+ (void)enableInterfaceDebug:(BOOL)isDebug
{
    gp_isEnableInterfaceDebug = isDebug;
}

+ (BOOL)isDebug
{
    return gp_isEnableInterfaceDebug;
}

static inline NSString *cachePath() {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/GPNetworkingCaches"];
}

//清除缓存
+ (void)clearCaches {
    NSString *directorypath = cachePath();
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:directorypath isDirectory:nil]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:directorypath error:&error];
        if (error) {
            NSLog(@"GPNetworking clear caches errror：%@",error);
        }
        else{
            NSLog(@"GPNetworking clear caches ok");
        }
    }
}

//计算缓存大小
+ (unsigned long long)totalCacheSize {
    NSString *directoryPath = cachePath();
    BOOL isDir = NO;
    unsigned long long total = 0;
    //创建文件管理对象
    NSFileManager *filemanager = [NSFileManager defaultManager];
    if ([filemanager fileExistsAtPath:directoryPath isDirectory:&isDir]) {
        if (isDir) {
            NSError *error = nil;
            NSArray *array = [filemanager contentsOfDirectoryAtPath:directoryPath error:&error];
            if (error == nil) {
                for (NSString *subpath in array) {
                    NSString *path = [directoryPath stringByAppendingPathComponent:subpath];
                    //计算文件的大小
                    long long fileSize = [[filemanager attributesOfItemAtPath:path error:nil]fileSize];
                    total += fileSize;
                }
            }
        }
    }
    return total;
}

+ (NSMutableArray *)allTasks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (gp_requestTasks == nil) {
            gp_requestTasks = [[NSMutableArray alloc] init];
        }
    });
    
    return gp_requestTasks;
}

//取消所有请求
+ (void)cancelAllRequest{
    //加锁线程
    @synchronized (self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(GPURLSessionTask *  _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task isKindOfClass:[GPURLSessionTask class]]) {
                [task cancel];
            }
        }];
        [[self allTasks] removeAllObjects];
    }
}

//根据url取消某个请求
+ (void)cancelRequestWithURL:(NSString *)url {
    if (!url || url.length) {
        return;
    }
    @synchronized (self) {
        [[self allTasks] enumerateObjectsUsingBlock:^(GPURLSessionTask *  _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            //遍历task 然后取消
            if ([task isKindOfClass:[GPURLSessionTask class]] && [task.currentRequest.URL.absoluteString hasSuffix:url]) {
                [task cancel];
                [[self allTasks] removeObject:task];
                *stop = YES;
            }
        }];
    }
}
//配置网络请求设置
+ (void)configRequestType:(GPRequestType)requestType responseType:(GPResponseType)responseType shouldAutoEncodeUrl:(BOOL)shouldAutoEncode callbackOnCancelRequest:(BOOL)shouldCallbackOnCancelRequest {
    gp_requestType = requestType;
    gp_responseType = responseType;
    gp_shouldAutoEncode = shouldAutoEncode;
    gp_shouldCallbackOnCancelRequest = shouldCallbackOnCancelRequest;
}

+ (BOOL)shouldEncode {
    return gp_shouldAutoEncode;
}

+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders {
    gp_httpHeaders = httpHeaders;
}

#pragma mark - =======GET请求========

+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    return [self getWithUrl:url loadCache:loadCache refreshCache:refreshCache params:nil success:success fail:fail];
}

+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    return [self getWithUrl:url loadCache:loadCache refreshCache:refreshCache params:params success:success fail:fail];
}

+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params progress:(GPGetProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    return [self requestWithUrl:url loadCache:loadCache refreshCache:refreshCache httpMedth:GPNetWorkTypeGET params:params progress:progress success:success fail:fail];
}

#pragma mark - =======POST请求========

+ (GPURLSessionTask *)postWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    return [self postWithUrl:url loadCache:loadCache refreshCache:refreshCache params:params progress:nil success:success fail:fail];
}

+ (GPURLSessionTask *)postWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params progress:(GPGetProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    return [self requestWithUrl:url loadCache:loadCache refreshCache:refreshCache httpMedth:GPNetWorkTypePOST params:params progress:progress success:success fail:fail];
}
#pragma mark - ==========GET和POST请求网络方法封装==========
+ (GPURLSessionTask *)requestWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache httpMedth:(GPNetWorkType)httpMethod params:(NSDictionary *)params progress:(GPDownloadProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    //对URL进行编码
    if ([self shouldEncode]) {
        url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    AFHTTPSessionManager *manager = [self manager];
    NSString *absolute = [self absoluteUrlWithPath:url];
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:url] == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }else {
        NSURL *absoluteURL = [NSURL URLWithString:absolute];
        if (absoluteURL == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }
    GPURLSessionTask *session = nil;
    
    if (loadCache) {//加载缓存
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            
//        });
        id response = [self cahceResponseWithURL:absolute parameters:params];
        if (response) {
            //成功回调
            if (success) {
                [self successResponse:response url:absolute params:params callback:success];
            }
            //不刷新缓存
            if (!refreshCache) {
                return nil;
            }
        }
    }
    //GET请求
    if (httpMethod == GPNetWorkTypeGET) {
        
    session = [manager GET:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
        //进度回调
        if (progress) {
            progress(downloadProgress.completedUnitCount,downloadProgress.totalUnitCount);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self successResponse:responseObject url:absolute params:params callback:success];
        
        if (loadCache) {
            [self cacheResponseObject:responseObject request:task.currentRequest parameters:params];
        }
        
        [[self allTasks] removeObject:task];

    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [[self allTasks] removeObject:task];
        
        if ([error code] < 0 && loadCache) {// 获取缓存
            id response = [self cahceResponseWithURL:absolute parameters:params];
            if (response) {
                if (success) {
                    [self successResponse:response url:absolute params:params callback:success];
                }
            } else {
                [self handleCallbackWithError:error url:absolute params:params fail:fail];
            }
        } else {
            [self handleCallbackWithError:error url:absolute params:params fail:fail];
        }
    }];
    }
    else if (httpMethod == GPNetWorkTypePOST) {//post请求
        session = [manager POST:url parameters:params progress:^(NSProgress * _Nonnull downloadProgress) {
            if (progress) {
                progress(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
            }
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            [self successResponse:responseObject url:absolute params:params callback:success];
            
            if (loadCache) {
                [self cacheResponseObject:responseObject request:task.currentRequest  parameters:params];
            }
            
            [[self allTasks] removeObject:task];
            
            if ([self isDebug]) {
                [self logWithSuccessResponse:responseObject url:absolute params:params];
            }
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [[self allTasks] removeObject:task];
            
            if ([error code] < 0 && loadCache) {// 获取缓存
                id response = [GPNetworkManager cahceResponseWithURL:absolute parameters:params];
                
                if (response) {
                    if (success) {
                        [self successResponse:response url:absolute params:params callback:success];

                    }
                } else {
                    [self handleCallbackWithError:error url:absolute params:params fail:fail];

                }
            } else {
                [self handleCallbackWithError:error url:absolute params:params fail:fail];

            }

        }];
    }
    //添加任务
    if (session) {
        [[self allTasks] addObject:session];
    }
    return session;
}
#pragma mark - =====================================
+ (GPURLSessionTask *)uploadFileWithUrl:(NSString *)url uploadingFile:(NSString *)uploadingFile progress:(GPUploadProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    if ([NSURL URLWithString:uploadingFile] == nil) {
        GPAppLog(@"uploadingFile无效，无法生成URL。请检查待上传文件是否存在");
        return nil;
    }
    
    NSURL *uploadURL = nil;
    if ([self baseUrl] == nil) {
        uploadURL = [NSURL URLWithString:url];
    } else {
        uploadURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self baseUrl], url]];
    }
    
    if (uploadURL == nil) {
        GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文或特殊字符，请尝试Encode URL");
        return nil;
    }
    
    AFHTTPSessionManager *manager = [self manager];
    NSURLRequest *request = [NSURLRequest requestWithURL:uploadURL];
    GPURLSessionTask *session = nil;
    
    [manager uploadTaskWithRequest:request fromFile:[NSURL URLWithString:uploadingFile] progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progress) {
            progress(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        }
    } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [[self allTasks] removeObject:session];

        if (error) {
            [self handleCallbackWithError:error url:response.URL.absoluteString params:nil fail:fail];
        } else {
             [self successResponse:responseObject url:response.URL.absoluteString params:nil callback:success];
        }
    }];
    
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

+ (GPURLSessionTask *)uploadWithImage:(UIImage *)image url:(NSString *)url filename:(NSString *)filename name:(NSString *)name mimeType:(NSString *)mimeType parameters:(NSDictionary *)parameters progress:(GPUploadProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail {
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:url] == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    } else {
        if ([NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self baseUrl], url]] == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }
    
    if ([self shouldEncode]) {
        url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSString *absolute = [self absoluteUrlWithPath:url];
    
    AFHTTPSessionManager *manager = [self manager];
    GPURLSessionTask *session = [manager POST:url parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSData *imageData = UIImageJPEGRepresentation(image, 1);
        
        NSString *imageFileName = filename;
        if (filename == nil || ![filename isKindOfClass:[NSString class]] || filename.length == 0) {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.dateFormat = @"yyyyMMddHHmmss";
            NSString *str = [formatter stringFromDate:[NSDate date]];
            imageFileName = [NSString stringWithFormat:@"%@.jpg", str];
        }
        
        // 上传图片，以文件流的格式
        [formData appendPartWithFileData:imageData name:name fileName:imageFileName mimeType:mimeType];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        if (progress) {
            progress(uploadProgress.completedUnitCount, uploadProgress.totalUnitCount);
        }
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [[self allTasks] removeObject:task];
        [self successResponse:responseObject url:absolute params:parameters callback:success];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [[self allTasks] removeObject:task];
        
        [self handleCallbackWithError:error url:absolute params:nil fail:fail];

    }];
    
    [session resume];
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}

+ (GPURLSessionTask *)downloadWithUrl:(NSString *)url saveToPath:(NSString *)saveToPath progress:(GPDownloadProgress)progressBlock success:(GPResponseSuccess)success failure:(GPResponseFail)failure {
    if ([self baseUrl] == nil) {
        if ([NSURL URLWithString:url] == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    } else {
        if ([NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [self baseUrl], url]] == nil) {
            GPAppLog(@"URLString无效，无法生成URL。可能是URL中有中文，请尝试Encode URL");
            return nil;
        }
    }
    
    NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    AFHTTPSessionManager *manager = [self manager];
    
    GPURLSessionTask *session = nil;
    
    session = [manager downloadTaskWithRequest:downloadRequest progress:^(NSProgress * _Nonnull downloadProgress) {
        if (progressBlock) {
            progressBlock(downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
        }
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:saveToPath];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        [[self allTasks] removeObject:session];
        
        if (error == nil) {
            if (success) {
                success(filePath.absoluteString);
            }
            
            if ([self isDebug]) {
                GPAppLog(@"Download success for url %@", [self absoluteUrlWithPath:url]);
            }
        } else {
            [self handleCallbackWithError:error url:filePath.absoluteString params:nil fail:failure];

        }
    }];
    
    [session resume];
    if (session) {
        [[self allTasks] addObject:session];
    }
    
    return session;
}


#pragma mark - Private
+ (AFHTTPSessionManager *)manager {
    @synchronized (self) {
        // 只要不切换baseurl，就一直使用同一个session manager
        if (gp_sharedManager == nil || gp_isBaseURLChanged) {
            // 开启转圈圈
            [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
            
            AFHTTPSessionManager *manager = nil;;
            if ([self baseUrl] != nil) {
                manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:[self baseUrl]]];
            } else {
                manager = [AFHTTPSessionManager manager];
            }
            //设置https单向认证
//            [manager setSecurityPolicy:[self customSecurityPolicy]];
            switch (gp_requestType) {
                case kGPRequestTypeJSON: {
                    manager.requestSerializer = [AFJSONRequestSerializer serializer];
                    break;
                }
                case kGPRequestTypePlainText: {
                    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
                    break;
                }
                default: {
                    break;
                }
            }
            
            switch (gp_responseType) {
                case kGPResponseTypeJSON: {
                    manager.responseSerializer = [AFJSONResponseSerializer serializer];
                    break;
                }
                case kGPResponseTypeXML: {
                    manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
                    break;
                }
                case kGPResponseTypeData: {
                    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
                    break;
                }
                default: {
                    break;
                }
            }
            
            manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
            
            
            for (NSString *key in gp_httpHeaders.allKeys) {
                if (gp_httpHeaders[key] != nil) {
                    [manager.requestSerializer setValue:gp_httpHeaders[key] forHTTPHeaderField:key];
                }
            }
            
            manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json",@"text/html",@"text/json",@"text/plain",@"text/javascript",@"text/xml",@"image/*"]];
            
            manager.requestSerializer.timeoutInterval = gp_timeout;
            
            // 设置允许同时最大并发数量，过大容易出问题
            manager.operationQueue.maxConcurrentOperationCount = 3;
            gp_sharedManager = manager;
        }
    }
    
    return gp_sharedManager;
}
+ (AFSecurityPolicy*)customSecurityPolicy
{
    
    //证书路径
    // /先导入证书
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"" ofType:@"cer"];//证书的路径
    NSData *certData = [NSData dataWithContentsOfFile:cerPath];
    
    // AFSSLPinningModeCertificate 使用证书验证模式
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    
    // allowInvalidCertificates 是否允许无效证书（也就是自建的证书），默认为NO
    // 如果是需要验证自建证书，需要设置为YES
    securityPolicy.allowInvalidCertificates = YES;
    
    //validatesDomainName 是否需要验证域名，默认为YES；
    //假如证书的域名与你请求的域名不一致，需把该项设置为NO；如设成NO的话，即服务器使用其他可信任机构颁发的证书，也可以建立连接，这个非常危险，建议打开。
    //置为NO，主要用于这种情况：客户端请求的是子域名，而证书上的是另外一个域名。因为SSL证书上的域名是独立的，假如证书上注册的域名是www.google.com，那么mail.google.com是无法验证通过的；当然，有钱可以注册通配符的域名*.google.com，但这个还是比较贵的。
    //如置为NO，建议自己添加对应域名的校验逻辑。
    securityPolicy.validatesDomainName = NO;
    
    securityPolicy.pinnedCertificates =[NSSet setWithObject:certData];
    
    return securityPolicy;
}

//检测网络
+ (void)detectNetwork {
    AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
    
    [reachabilityManager startMonitoring];
    [reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (status == AFNetworkReachabilityStatusNotReachable){
            gp_networkStatus = kGPNetworkStatusNotReachable;
        } else if (status == AFNetworkReachabilityStatusUnknown){
            gp_networkStatus = kGPNetworkStatusUnknown;
        } else if (status == AFNetworkReachabilityStatusReachableViaWWAN){
            gp_networkStatus = kGPNetworkStatusReachableViaWWAN;
        } else if (status == AFNetworkReachabilityStatusReachableViaWiFi){
            gp_networkStatus = kGPNetworkStatusReachableViaWiFi;
        }
    }];
}

#pragma mark - =======处理缓存相关========
/** 根据过期时间获取缓存 */
+ (id)cahceResponseWithURL:(NSString *)url parameters:params {
    
    id cacheData = nil;
    
    if (url) {
        // Try to get datas from disk
        NSString *directoryPath = cachePath();
        NSString *absoluteURL = [self generateGETAbsoluteURL:url params:params];
        NSString *key = [NSString gpnetworking_md5:absoluteURL];
        NSString *path = [directoryPath stringByAppendingPathComponent:key];
        //判断文件是否存在
        NSFileManager *manage  = [NSFileManager defaultManager];
        if ([manage fileExistsAtPath:path]) {
            //缓存修改时间
            NSDictionary  *dic = [manage attributesOfItemAtPath:path error:nil];
            /*
             NSFileCreationDate = "2015-08-10 03:38:15 +0000";
             NSFileModificationDate = "2015-08-10 03:38:15 +0000";
             NSFileSize = 17090;
             */
            //判断数据是否过期  文件修改时间相差的秒数
            NSTimeInterval invalitTime = [[NSDate date] timeIntervalSinceDate:dic[NSFileModificationDate]];
            if (invalitTime < KExpirationTime) {//没过期
                NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
                if (data) {
                    cacheData = data;
                    GPAppLog(@"Read data from cache for url: %@\n", url);
                }
            }
        }
     }
    return cacheData;
}

/** 缓存文件  */
+ (void)cacheResponseObject:(id)responseObject request:(NSURLRequest *)request parameters:params {
    if (request && responseObject && ![responseObject isKindOfClass:[NSNull class]]) {
        NSString *directoryPath = cachePath();
        
        NSError *error = nil;
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                GPAppLog(@"create cache dir error: %@\n", error);
                return;
            }
        }
        
        NSString *absoluteURL = [self generateGETAbsoluteURL:request.URL.absoluteString params:params];
        NSString *key = [NSString gpnetworking_md5:absoluteURL];
        NSString *path = [directoryPath stringByAppendingPathComponent:key];
        NSDictionary *dict = (NSDictionary *)responseObject;
        
        NSData *data = nil;
        if ([dict isKindOfClass:[NSData class]]) {
            data = responseObject;
        } else {
            data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
        }
        
        if (data && error == nil) {
            BOOL isOk = [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil];
            if (isOk) {
                GPAppLog(@"cache file ok for request: %@\n", absoluteURL);
            } else {
                GPAppLog(@"cache file error for request: %@\n", absoluteURL);
            }
        }
    }
}
#pragma mark - ============打印相关=============
+ (void)logWithSuccessResponse:(id)response url:(NSString *)url params:(NSDictionary *)params {
    GPAppLog(@"\n");
    GPAppLog(@"\nRequest success, URL: %@\n params:%@\n response:%@\n\n",
              [self generateGETAbsoluteURL:url params:params],
              params,
              [self tryToParseData:response]);
}

+ (void)logWithFailError:(NSError *)error url:(NSString *)url params:(id)params {
    NSString *format = @" params: ";
    if (params == nil || ![params isKindOfClass:[NSDictionary class]]) {
        format = @"";
        params = @"";
    }
    
    GPAppLog(@"\n");
    if ([error code] == NSURLErrorCancelled) {
        GPAppLog(@"\nRequest was canceled mannully, URL: %@ %@%@\n\n",
                  [self generateGETAbsoluteURL:url params:params],
                  format,
                  params);
    } else {
        GPAppLog(@"\nRequest error, URL: %@ %@%@\n errorInfos:%@\n\n",
                  [self generateGETAbsoluteURL:url params:params],
                  format,
                  params,
                  [error localizedDescription]);
    }
}


// 仅对一级字典结构起作用
+ (NSString *)generateGETAbsoluteURL:(NSString *)url params:(id)params {
    if (params == nil || ![params isKindOfClass:[NSDictionary class]] || [params count] == 0) {
        return url;
    }
    
    NSString *queries = @"";
    for (NSString *key in params) {
        id value = [params objectForKey:key];
        
        if ([value isKindOfClass:[NSDictionary class]]) {
            continue;
        } else if ([value isKindOfClass:[NSArray class]]) {
            continue;
        } else if ([value isKindOfClass:[NSSet class]]) {
            continue;
        } else {
            queries = [NSString stringWithFormat:@"%@%@=%@&",
                       (queries.length == 0 ? @"&" : queries),
                       key,
                       value];
        }
    }
    
    if (queries.length > 1) {
        queries = [queries substringToIndex:queries.length - 1];
    }
    
    if (([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) && queries.length > 1) {
        if ([url rangeOfString:@"?"].location != NSNotFound
            || [url rangeOfString:@"#"].location != NSNotFound) {
            url = [NSString stringWithFormat:@"%@%@", url, queries];
        } else {
            queries = [queries substringFromIndex:1];
            url = [NSString stringWithFormat:@"%@?%@", url, queries];
        }
    }
    
    return url.length == 0 ? queries : url;
}


+ (id)tryToParseData:(id)responseData {
    if ([responseData isKindOfClass:[NSData class]]) {
        // 尝试解析成JSON
        if (responseData == nil) {
            return responseData;
        } else {
            NSError *error = nil;
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
            
            if (error != nil) {
                return responseData;
            } else {
                return response;
            }
        }
    } else {
        return responseData;
    }
}

+ (void)successResponse:(id)responseData url:(NSString *)absolute params:(NSDictionary *)params callback:(GPResponseSuccess)success {
    if (success) {
        success([self tryToParseData:responseData]);
    }
    if ([self isDebug]) {
        [self logWithSuccessResponse:responseData url:absolute params:params];
    }
}

+ (NSString *)absoluteUrlWithPath:(NSString *)path {
    if (path == nil || path.length == 0) {
        return @"";
    }
    
    if ([self baseUrl] == nil || [[self baseUrl] length] == 0) {
        return path;
    }
    
    NSString *absoluteUrl = path;
    
    if (![path hasPrefix:@"http://"] && ![path hasPrefix:@"https://"]) {
        if ([[self baseUrl] hasSuffix:@"/"]) {
            if ([path hasPrefix:@"/"]) {
                NSMutableString * mutablePath = [NSMutableString stringWithString:path];
                [mutablePath deleteCharactersInRange:NSMakeRange(0, 1)];
                absoluteUrl = [NSString stringWithFormat:@"%@%@",
                               [self baseUrl], mutablePath];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@%@",[self baseUrl], path];
            }
        } else {
            if ([path hasPrefix:@"/"]) {
                absoluteUrl = [NSString stringWithFormat:@"%@%@",[self baseUrl], path];
            } else {
                absoluteUrl = [NSString stringWithFormat:@"%@/%@",
                               [self baseUrl], path];
            }
        }
    }
    
    return absoluteUrl;
}

+ (void)handleCallbackWithError:(NSError *)error url:absolute params:params fail:(GPResponseFail)fail {
    if ([error code] == NSURLErrorCancelled) {
        if (gp_shouldCallbackOnCancelRequest) {
            if (fail) {
                fail(error);
            }
        }
    } else {
        if (fail) {
            fail(error);
        }
    }
    if ([self isDebug]) {
        [self logWithFailError:error url:absolute params:params];
    }
}

@end
