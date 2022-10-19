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

  s.ios.deployment_target = '10.0'

  s.pod_target_xcconfig = {
    'MARTIN_PACKAGE_VERSION' => '1.0',
    'GCC_PRECOMPILE_PREFIX_HEADER' => true,
    'CLANG_ENABLE_MODULES' => 'YES',
  }

  s.preserve_paths = "#{s.name}/Classes/**/*","Framework/**/*", "#{s.name}/Assets/**/*",

  $use_binary = nil

  $use_binary = ENV['use_binary']
  $pod_use_binary = ENV["#{s.name}_use_binary"]

  if $pod_use_binary =='1'
    $use_binary = true
  elsif $pod_use_binary =='0'
    $use_binary = false
  else
    if $use_binary == '1'
      $use_binary = true
    end
  end

  tag = `git describe --abbrev=0 --tags 2>/dev/null`.strip
  if tag && !tag.empty?
    $use_binary =false
  end

  if $use_binary ==true
    s.vendored_frameworks = "Framework/**/*.framework"
  else
    s.source_files = "#{s.name}/Classes/**/*"
  end
  

end
