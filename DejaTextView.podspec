#
# Be sure to run `pod lib lint DejaTextView.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "DejaTextView"
  s.version          = "0.1.0"
  s.summary          = "DejaTextView is a UITextView subclass with improved text selection and cursor movement tools."
  s.description      = <<-DESC
                       An optional longer description of DejaTextView

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/markusschlegel/DejaTextView"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Markus Schlegel" => "mail@markus-schlegel.com" }
  s.source           = { :git => "https://github.com/markusschlegel/DejaTextView.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'DejaTextView' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
