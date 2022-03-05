Pod::Spec.new do |spec|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.name         = "TetraNetwork"
  spec.version      = "0.0.1"
  spec.summary      = "A slightly opinionated network framework with only the minimal functionality and no bloater."

  spec.description  = <<-DESC
  This library provide most basic functionality to make API call from iOS written
  in Swift.
                   DESC

  spec.homepage     = "https://github.com/son-iOS/TetraNetwork"

  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.license      = { :type => "MIT", :file => "LICENSE" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.author             = { "Son Nguyen" => "ndson040496@gmail.com" }

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.ios.deployment_target = "11.0"
  spec.osx.deployment_target = "10.15"
  spec.swift_versions = "5"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.source       = { :git => "https://github.com/son-iOS/TetraNetwork.git", :tag => "#{spec.version}" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.source_files  = "TetraNetwork", "TetraNetwork/**/*.{swift}"
  spec.public_header_files = "TetraNetwork/**/TetraNetwork.h"

end
