include Chef::Mixin::ShellOut
include MacOS

module MacOS
  class Xcode
    attr_reader :version
    attr_reader :apple_version
    attr_reader :intended_path
    attr_reader :download_url

    def initialize(semantic_version, intended_path, download_url = '')
      @semantic_version = semantic_version
      @intended_path = intended_path
      @apple_version = Xcode::Version.new(@semantic_version).apple
      @download_url = download_url
      @version = if download_url.empty?
                   version_index = xcode_index @apple_version
                   listed_version = sorted_versions[version_index]
                   listed_version.strip
                 else
                   semantic_version
                 end
    end

    def compatible_with_platform?(macos_version)
      Gem::Dependency.new('macOS', minimum_required_os).match?('macOS', macos_version)
    end

    def minimum_required_os
      return '>= 0' if Gem::Dependency.new('Xcode', '<= 9.2').match?('Xcode', @semantic_version)
      return '>= 10.13.2' if Gem::Dependency.new('Xcode', '>= 9.3', '<= 9.4.1').match?('Xcode', @semantic_version)
      return '>= 10.13.6' if Gem::Dependency.new('Xcode', '>= 10.0', '<= 10.1').match?('Xcode', @semantic_version)
      return '>= 10.14.3' if Gem::Dependency.new('Xcode', '>= 10.2', '<= 10.3').match?('Xcode', @semantic_version)
      return '>= 10.14.4' if Gem::Dependency.new('Xcode', '>= 11.0', '<= 11.3.1').match?('Xcode', @semantic_version)
      return '>= 10.15.2' if Gem::Dependency.new('Xcode', '>= 11.4').match?('Xcode', @semantic_version)
    end

    def xcode_index(version)
      available_xcodes.index { |available_version| available_version.apple == version }
    end

    def available_xcodes
      sorted_versions.map { |v| Xcode::Version.new v.split.first }
    end

    def sorted_versions
      XCVersion.available_versions.sort
    end

    def installed_path
      XCVersion.installed_xcodes.find { |path| path[@semantic_version] }
    end

    def current_path
      if installed_path.nil?
        "/Applications/Xcode-#{@version.tr(' ', '.')}.app"
      else
        installed_path[@semantic_version]
      end
    end

    def installed?
      return false if installed_path.nil?
      installed_path.any?
    end

    class Simulator
      attr_reader :version

      def initialize(major_version)
        while available_list.empty?
          Chef::Log.warn('iOS Simulator list not populated yet')
          sleep 10
        end
        if latest_semantic_version(major_version).nil?
          raise("iOS #{major_version} Simulator no longer available from Apple!")
        else
          @version = latest_semantic_version(major_version).join(' ')
        end
      end

      def latest_semantic_version(major_version)
        requirement = Gem::Dependency.new('iOS', "~> #{major_version}")
        available_list.select { |platform, version| requirement.match?(platform, version) }.max
      end

      def available_list
        available_versions.split(/\n/).map { |version| version.split[0..1] }
      end

      def installed?
        available_versions.include?("#{@version} Simulator (installed)")
      end

      def available_versions
        shell_out!(XCVersion.list_simulators).stdout
      end

      def show_sdks
        shell_out!('/usr/bin/xcodebuild -showsdks').stdout
      end

      def included_with_xcode?
        version_matcher    = /\d{1,2}\.\d{0,2}\.?\d{0,3}/
        included_simulator = show_sdks.match(/Simulator - iOS (?<version>#{version_matcher})/)
        @version.split.last.to_i == included_simulator[:version].to_i
      end
    end

    class Version < Gem::Version
      def major
        _segments.first
      end

      def minor
        _segments[1] || 0
      end

      def patch
        _segments[2] || 0
      end

      def major_release?
        minor == 0 && patch == 0
      end

      def minor_release?
        minor != 0 && patch == 0
      end

      def patch_release?
        patch != 0
      end

      def apple
        if major_release?
          major
        else
          version
        end
      end
    end
  end
end

Chef::Recipe.include(MacOS)
Chef::Resource.include(MacOS)
