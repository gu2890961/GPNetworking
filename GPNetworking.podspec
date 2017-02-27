Pod::Spec.new do |spec|

spec.name                  = 'GPNetWorking'

spec.version               = '1.0.1'

spec.ios.deployment_target = '8.0'

spec.license               = 'MIT'

spec.homepage              = 'https://github.com/gu2890961'

spec.author                = { "gu2890961" => "745001999@qq.com" }

spec.summary               = '网络框架的封装'

spec.source                = { :git => 'https://github.com/gu890961/GPNetworking.git', :tag => spec.version }

spec.source_files          = "GPNetworking/GPNetworking/**/{*.h,*.m}"

spec.frameworks            = 'UIKit'

spec.requires_arc          = true

spec.dependency "AFNetworking"

end
