Pod::Spec.new do |s|
  s.name     = ‘GPNetworking’ 
  s.version  = ‘1.0.1’ 
  s.license  = "MIT"  //开源协议
  s.summary  = 'This is a countdown button' //简单的描述 
  s.homepage = 'https://github.com/gu2890961/GPNetworking' //主页
  s.author   = { ‘gu2890961’ => ‘745001999@qq.com' } //作者
  s.source   = { :git => 'https://github.com/gu2890961/GPNetworking.git', :tag => “1.0.1” } //git路径、指定tag号
  s.platform = :ios 
  s.source_files = ‘GPNetworking/*’  //库的源代码文件
  s.framework = 'UIKit'  //依赖的framework
  s.requires_arc = true
end
