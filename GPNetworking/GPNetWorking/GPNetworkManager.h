//
//  GPNetworking.h
//  GPNetworking
//
//  Created by apple on 2017/2/25.
//  Copyright © 2017年 gupeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 项目打包上线都不会打印日志，因此可放心。
#ifdef DEBUG
#define GPAppLog(s, ... ) NSLog( @"[%@ in line %d] ===============>%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define GPAppLog(s, ... )
#endif

#define KExpirationTime  60*60*24*5  //缓存时间 秒数

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  下载进度
 *
 *  @param bytesRead                 已下载的大小
 *  @param totalBytesRead            文件总大小
 */
typedef void (^GPDownloadProgress)(int64_t bytesRead,
int64_t totalBytesRead);

typedef GPDownloadProgress GPGetProgress;
typedef GPDownloadProgress GPPostProgress;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  上传进度
 *
 *  @param bytesWritten              已上传的大小
 *  @param totalBytesWritten         总上传大小
 */
typedef void (^GPUploadProgress)(int64_t bytesWritten,
int64_t totalBytesWritten);

typedef NS_ENUM(NSUInteger, GPResponseType) {
    kGPResponseTypeJSON = 1, // 默认
    kGPResponseTypeXML  = 2, // XML
    // 特殊情况下，一转换服务器就无法识别的，默认会尝试转换成JSON，若失败则需要自己去转换
    kGPResponseTypeData = 3
};

/*** 请求类型*/
typedef NS_ENUM(NSUInteger, GPNetWorkType) {
    GPNetWorkTypeGET = 1,   /**< GET请求 */
    GPNetWorkTypePOST       /**< POST请求 */
};

typedef NS_ENUM(NSUInteger, GPRequestType) {
    kGPRequestTypeJSON = 1, // 默认
    kGPRequestTypePlainText  = 2 // 普通text/html
};

typedef NS_ENUM(NSInteger, GPNetworkStatus) {
    kGPNetworkStatusUnknown          = -1,//未知网络
    kGPNetworkStatusNotReachable     = 0,//网络无连接
    kGPNetworkStatusReachableViaWWAN = 1,//2，3，4G网络
    kGPNetworkStatusReachableViaWiFi = 2,//WIFI网络
};

@class NSURLSessionTask;

// 请勿直接使用NSURLSessionDataTask,以减少对第三方的依赖
// 所有接口返回的类型都是基类NSURLSessionTask，若要接收返回值
// 且处理，请转换成对应的子类类型
typedef NSURLSessionTask GPURLSessionTask;
typedef void(^GPResponseSuccess)(id response);
typedef void(^GPResponseFail)(NSError *error);

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  基于AFNetworking的网络层封装类.
 *
 *  @note 这里只提供公共api
 */
@interface GPNetworkManager : NSObject

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  用于指定网络请求接口的基础url，如：
 *  http://henishuo.com或者http://101.200.209.244
 *  通常在AppDelegate中启动时就设置一次就可以了。如果接口有来源
 *  于多个服务器，可以调用更新
 *
 *  @param baseUrl 网络接口的基础url
 */
+ (void)updateBaseUrl:(NSString *)baseUrl;
+ (NSString *)baseUrl;

/**
 *	设置请求超时时间，默认为60秒
 *
 *	@param timeout 超时时间
 */
+ (void)setTimeout:(NSTimeInterval)timeout;

/**
 *	当检查到网络异常时，是否从从本地提取数据。默认为NO。一旦设置为YES,当设置刷新缓存时，
 *  若网络异常也会从缓存中读取数据。同样，如果设置超时不回调，同样也会在网络异常时回调，除非
 *  本地没有数据！
 *
 *	@param shouldObtain	YES/NO
 */
+ (void)obtainDataFromLocalWhenNetworkUnconnected:(BOOL)shouldObtain;


/**
 *	@author gupeng, 17-02-22 14:01:26
 *
 *	获取缓存总大小/bytes
 *
 *	@return 缓存大小
 */
+ (unsigned long long)totalCacheSize;

/**
 *	默认不会自动清除缓存，如果需要，可以设置自动清除缓存，并且需要指定上限。当指定上限>0M时，
 *  若缓存达到了上限值，则每次启动应用则尝试自动去清理缓存。
 *
 *	@param mSize				缓存上限大小，单位为M（兆），默认为0，表示不清理
 */
+ (void)autoToClearCacheWithLimitedToSize:(NSUInteger)mSize;

/**
 *	@author GP
 *
 *	清除缓存
 */
+ (void)clearCaches;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  开启或关闭接口打印信息
 *
 *  @param isDebug 开发期，最好打开，默认是NO
 */
+ (void)enableInterfaceDebug:(BOOL)isDebug;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  配置请求格式，默认为JSON。如果要求传XML或者PLIST，请在全局配置一下
 *
 *  @param requestType 请求格式，默认为JSON
 *  @param responseType 响应格式，默认为JSO，
 *  @param shouldAutoEncode YES or NO,默认为NO，是否自动encode url
 *  @param shouldCallbackOnCancelRequest 当取消请求时，是否要回调，默认为YES
 */
+ (void)configRequestType:(GPRequestType)requestType
             responseType:(GPResponseType)responseType
      shouldAutoEncodeUrl:(BOOL)shouldAutoEncode
  callbackOnCancelRequest:(BOOL)shouldCallbackOnCancelRequest;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  配置公共的请求头，只调用一次即可，通常放在应用启动的时候配置就可以了
 *
 *  @param httpHeaders 只需要将与服务器商定的固定参数设置即可
 */
+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders;

/**
 *	@author gupeng, 17-02-22 14:01:26
 */
+ (void)cancelAllRequest;
/**
 *	@author gupeng, 17-02-22 14:01:26
 *
 *	取消某个请求。如果是要取消某个请求，最好是引用接口所返回来的GPURLSessionTask对象，
 *  然后调用对象的cancel方法。如果不想引用对象，这里额外提供了一种方法来实现取消某个请求
 *
 *	@param url				URL，可以是绝对URL，也可以是path（也就是不包括baseurl）
 */
+ (void)cancelRequestWithURL:(NSString *)url;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  GET请求接口，若不指定baseurl，可传完整的url
 *
 *  @param url     接口路径，如/path/getArticleList
 *   refreshCache 是否刷新缓存。由于请求成功也可能没有数据，对于业务失败，只能通过人为手动判断
 *   params  接口中所需要的拼接参数，如@{"categoryid" : @(12)}
 *  @param success 接口成功请求到数据的回调
 *  @param fail    接口请求数据失败的回调
 *
 *  @return 返回的对象中有可取消请求的API
 */
+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache success:(GPResponseSuccess)success fail:(GPResponseFail)fail;
// 多一个params参数
+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params success:(GPResponseSuccess)success fail:(GPResponseFail)fail;
// 多一个带进度回调
+ (GPURLSessionTask *)getWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params progress:(GPGetProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail;

/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  POST请求接口，若不指定baseurl，可传完整的url
 *
 *  @param url     接口路径，如/path/getArticleList
 *  @param params  接口中所需的参数，如@{"categoryid" : @(12)}
 *  @param success 接口成功请求到数据的回调
 *  @param fail    接口请求数据失败的回调
 *
 *  @return 返回的对象中有可取消请求的API
 */
+ (GPURLSessionTask *)postWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params success:(GPResponseSuccess)success fail:(GPResponseFail)fail;
+ (GPURLSessionTask *)postWithUrl:(NSString *)url loadCache:(BOOL)loadCache refreshCache:(BOOL)refreshCache params:(NSDictionary *)params progress:(GPGetProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail;
/**
 *	@author gupeng, 17-02-22 14:01:26
 *
 *	图片上传接口，若不指定baseurl，可传完整的url
 *
 *	@param image			图片对象
 *	@param url				上传图片的接口路径，如/path/images/
 *	@param filename		给图片起一个名字，默认为当前日期时间,格式为"yyyyMMddHHmmss"，后缀为`jpg`
 *	@param name				与指定的图片相关联的名称，这是由后端写接口的人指定的，如imagefiles
 *	@param mimeType		默认为image/jpeg
 *	@param parameters	参数
 *	@param progress		上传进度
 *	@param success		上传成功回调
 *	@param fail				上传失败回调
 *
 */
+ (GPURLSessionTask *)uploadWithImage:(UIImage *)image url:(NSString *)url filename:(NSString *)filename name:(NSString *)name mimeType:(NSString *)mimeType parameters:(NSDictionary *)parameters progress:(GPUploadProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail;

/**
 *	@author gupeng, 17-02-22 14:01:26
 *
 *	上传文件操作
 *
 *	@param url						上传路径
 *	@param uploadingFile	待上传文件的路径
 *	@param progress			上传进度
 *	@param success				上传成功回调
 *	@param fail					上传失败回调
 *
 */
+ (GPURLSessionTask *)uploadFileWithUrl:(NSString *)url uploadingFile:(NSString *)uploadingFile progress:(GPUploadProgress)progress success:(GPResponseSuccess)success fail:(GPResponseFail)fail;


/*!
 *  @author gupeng, 17-02-22 14:01:26
 *
 *  下载文件
 *
 *  @param url           下载URL
 *  @param saveToPath    下载到哪个路径下
 *  @param progressBlock 下载进度
 *  @param success       下载成功后的回调
 *  @param failure       下载失败后的回调
 */
+ (GPURLSessionTask *)downloadWithUrl:(NSString *)url saveToPath:(NSString *)saveToPath progress:(GPDownloadProgress)progressBlock success:(GPResponseSuccess)success failure:(GPResponseFail)failure;



@end
