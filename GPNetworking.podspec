Pod::Spec.new do |s|
  s.name         = "GPNetworking”
  s.version      = "1.0.0"
  s.summary      = "A Library for iOS to use for GPNetworking."
  s.homepage     = "https://github.com/gu2890961/GPNetworking”
  s.license      = "MIT"
  s.author             = { “gu2890961” => “745001999@qq.com" }
  s.source       = { :git => "https://github.com/gu2890961/GPNetworking.git", :tag => "#{s.version}" }
  s.source_files  = "GPNetworking/GPNetWorking/*.{h,m}”
#第三方依赖
  s.dependency "AFNetworking", "~>3.0.4”
   # 是否支持arc
   s.requires_arc = true
end