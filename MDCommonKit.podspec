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
  s.version          = '1.0.10'
  s.summary          = 'A short description of MDCommonKit.'
  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/leon0206/MDCommonKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'leon0206' => '634376133@qq.com' }
  s.source           = { :git => 'https://github.com/leon0206/MDCommonKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'


  s.preserve_paths = "#{s.name}/Classes/**/*","Framework/**/*", "#{s.name}/Assets/**/*",

  $use_binary = ENV['use_binary']
  $pod_use_binary = ENV["#{s.name}_use_binary"]

  $use_binary = nil

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
    $use_binary =true
  end

  if $use_binary ==true
    s.vendored_frameworks = "Framework/#{s.version}/*.framework"
  else
    s.source_files = "#{s.name}/Classes/**/*"
  end
  

end
