require 'securerandom'
require 'spec_helper'

RSpec.describe SimCtl, order: :defined do
  before(:all) do
    @name = SecureRandom.hex
    @devicetype = SimCtl.devicetype(name: 'iPhone 5')
    @runtime = SimCtl::Runtime.latest(:ios)
    @device = SimCtl.create_device @name, @devicetype, @runtime
    @device.wait! {|d| d.state == :shutdown}
  end

  after(:all) do
    with_rescue { @device.kill! }
    with_rescue { @device.wait! {|d| d.state == :shutdown} }
    with_rescue { @device.delete! }
  end

  describe 'creating a device' do
    it 'raises exception if devicetype lookup failed' do
      expect { SimCtl.create_device @name, 'invalid devicetype', @runtime }.to raise_error SimCtl::DeviceTypeNotFound
    end

    it 'raises exception if runtime lookup failed' do
      expect { SimCtl.create_device @name, @devicetype, 'invalid runtime' }.to raise_error SimCtl::RuntimeNotFound
    end
  end

  describe 'device properties' do
    it 'is a device' do
      expect(@device).to be_kind_of SimCtl::Device
    end

    it 'has a name property' do
      expect(@device.name).to be == @name
    end

    it 'has a devicetype property' do
      expect(@device.devicetype).to be == @devicetype
    end

    it 'has a runtime property' do
      expect(@device.runtime).to be == @runtime
    end

    it 'has a availability property' do
      expect(@device.availability).not_to be_nil
    end

    it 'has a os property' do
      expect(@device.os).not_to be_nil
    end

    it 'state is shutdown' do
      expect(@device.state).to be == :shutdown
    end
  end

  describe 'device settings' do
    describe 'update hardware keyboard' do
      it 'creates the preferences plist' do
        File.delete(@device.path.preferences_plist) if File.exists?(@device.path.preferences_plist)
        @device.settings.update_hardware_keyboard!(false)
        expect(File).to exist(@device.path.preferences_plist)
      end
    end

    describe 'disable keyboard helpers' do
      it 'creates the preferences plist' do
        File.delete(@device.path.preferences_plist) if File.exists?(@device.path.preferences_plist)
        @device.settings.disable_keyboard_helpers!
        expect(File).to exist(@device.path.preferences_plist)
      end
    end

    describe 'setting the device language' do
      it 'sets the device language' do
        @device.settings.set_language('de')
      end
    end
  end

  describe 'finding the device' do
    it 'finds the device by udid' do
      expect(SimCtl.device(udid: @device.udid)).to be == @device
    end

    it 'finds the device by name' do
      expect(SimCtl.device(name: @device.name)).to be == @device
    end

    unless SimCtl.device_set_path.nil?
      it 'finds the device by runtime' do
        expect(SimCtl.device(runtime: @device.runtime)).to be == @device
      end

      it 'finds the device by devicetype' do
        expect(SimCtl.device(devicetype: @device.devicetype)).to be == @device
      end

      it 'finds the device by all given properties' do
        expect(SimCtl.device(udid: @device.udid, name: @device.name, runtime: @device.runtime, devicetype: @device.devicetype)).to be == @device
      end
    end
  end

  describe 'renaming the device' do
    it 'renames the device' do
      @device.rename!('new name')
      expect(@device.name).to be == 'new name'
      expect(SimCtl.device(udid: @device.udid).name).to be == 'new name'
    end
  end

  describe 'erasing the device' do
    it 'erases the device' do
      @device.erase!
    end
  end

  describe 'launching the device' do
    it 'launches the device' do
      @device.launch!
      @device.wait!{|d| d.state == :booted}
      expect(@device.state).to be == :booted
    end
  end

  describe 'launching a system app' do
    it 'launches Safari' do
      @device.launch_app!('com.apple.mobilesafari')
    end
  end

  describe 'taking a screenshot' do
    if SimCtl::XcodeVersion.gte? '8.2'
      it 'takes a screenshot' do
        file = File.join(Dir.mktmpdir, 'screenshot.png')
        @device.screenshot!(file)
        expect(File).to exist(file)
      end
    else
      it 'raises exception' do
        expect { @device.screenshot!('/tmp/foo.png') }.to raise_error SimCtl::UnsupportedCommandError
      end
    end
  end

  describe 'installing an app' do
    before(:all) do
      system 'cd spec/SampleApp && xcodebuild -sdk iphonesimulator >/dev/null 2>&1'
    end

    it 'installs SampleApp' do
      @device.install!('spec/SampleApp/build/Release-iphonesimulator/SampleApp.app')
    end
  end

  describe 'launching an app' do
    it 'launches SampleApp' do
      @device.launch_app!('com.github.plu.simctl.SampleApp')
    end
  end

  describe 'uninstall an app' do
    it 'uninstalls SampleApp' do
      @device.uninstall!('com.github.plu.simctl.SampleApp')
    end
  end

  describe 'opening a url' do
    it 'opens some url' do
      @device.open_url!('https://www.github.com')
    end
  end

  describe 'killing the device' do
    it 'state is booted' do
      expect(@device.state).to be == :booted
    end

    it 'kills the device' do
      @device.kill!
      @device.wait!{|d| d.state == :shutdown}
    end

    it 'state is shutdown' do
      expect(@device.state).to be == :shutdown
    end
  end

  describe 'booting the device' do
    it 'state is shutdown' do
      expect(@device.state).to be == :shutdown
    end

    it 'boots the device' do
      @device.boot!
      @device.wait! {|d| d.state == :booted}
      expect(@device.state).to be == :booted
    end

    it 'state is booted' do
      expect(@device.state).to be == :booted
    end
  end

  describe 'shutting down the device' do
    it 'state is booted' do
      expect(@device.state).to be == :booted
    end

    it 'shuts down the device' do
      @device.shutdown!
      @device.wait!{|d| d.state == :shutdown}
    end

    it 'state is shutdown' do
      expect(@device.state).to be == :shutdown
    end
  end

  describe 'resetting the device' do
    it 'deletes the old device and creates a new one' do
      new_device = @device.reset!
      expect(new_device.name).to be == @device.name
      expect(new_device.devicetype).to be == @device.devicetype
      expect(new_device.runtime).to be == @device.runtime
      expect(new_device.udid).not_to be == @device.udid
      expect(SimCtl.device(udid: @device.udid)).to be_nil
      @device = new_device
    end
  end

  describe 'deleting the device' do
    it 'deletes the device' do
      device = SimCtl.create_device @name, @devicetype, @runtime
      device.delete!
      expect(SimCtl.device(udid: @device.udid)).to be_nil
    end
  end
end