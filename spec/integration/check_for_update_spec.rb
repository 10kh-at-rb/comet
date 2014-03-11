require 'spec_helper'
require 'tmpdir'
require 'yaml'
require 'comet'

describe 'check for update' do
  let(:tmpdir) { Dir.mktmpdir('comet_test', '/tmp') }
  let(:config_file) { File.join(tmpdir, '.comet') }

  let(:comet_settings) do
    {
      'email' => 'barry.zuckerkorn@example.com',
      'token' => 'abcdefghijklmnopqrstuv12345678',
      'server' => 'http://localhost:3000',
      'basedir' => tmpdir
    }
  end

  let(:challenge_list) do
    [{
        id: 1,
        name: "Calculator"
      },
      {
        id: 2,
        name: "Mini Golf"
      },
      {
        id: 3,
        name: "Sum Of Integers"
      }]
  end

  before :each do
    Comet::API.stub(:get_challenges).and_return(challenge_list)
    File.write(config_file, comet_settings.to_yaml)
  end

  after :each do
    FileUtils.remove_entry_secure(tmpdir) if Dir.exists?(tmpdir)
  end

  let(:update_notice) do
    'NOTICE: An updated version of comet exists. ' +
      'Run `gem update comet` to upgrade.'
  end

  context 'when a newer version exists' do
    let(:next_version) do
      Comet::Version.build(
        Comet::MAJOR_VERSION,
        Comet::MINOR_VERSION,
        Comet::PATCH_LEVEL + 1)
    end

    before :each do
      Comet::API.stub(:latest_gem_version).and_return(next_version)
    end

    it 'notifies user to update the gem' do
      stdout, stderr = capture_output { Comet::Runner.go(['list'], tmpdir) }
      expect(stderr).to include(update_notice)
    end

    it 'does not notify the user when running a test suite' do
      stdout, stderr = capture_output { Comet::Runner.go(['test'], tmpdir) }
      expect(stderr).to_not include(update_notice)
    end
  end

  context 'when the current version is up-to-date' do
    before :each do
      Comet::API.stub(:latest_gem_version).and_return(Comet::VERSION)
    end

    it 'does not notify user to update the gem' do
      stdout, stderr = capture_output { Comet::Runner.go(['list'], tmpdir) }
      expect(stderr).to_not include(update_notice)
    end

  end
end
