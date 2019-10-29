#
# Be sure to run `pod lib lint MDCommonKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MDCommonKit'
  def self.smart_version
    tag = `git describe --abbrev=0 --tags 2>/dev/null`.strip
    if $?.success? then tag else "0.0.1" end
  end
  s.version          = smart_version
  s.summary          = 'A short description of MDCommonKit.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/leon0206/MDCommonKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'leon0206' => '634376133@qq.com' }
  s.source           = { :git => 'https://github.com/leon0206/MDCommonKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'MDCommonKit/Classes/**/*'

  if $use_source=='1'
    # ！！！！！！源码方式，需要加载哪些代码和资源，请在这里做相应变更
    s.source_files = "#{s.name}/Classes/**/*"
  else
    # ！！！！！！以下为固定写法，理论上不要动它
    s.vendored_frameworks = "Framework/#{s.version}/*.framework"
  end
  

end
