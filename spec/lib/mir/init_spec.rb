require 'rspec'
require 'tmpdir'
require 'yaml'
require 'mir'

describe Mir::Init do
  let(:settings) do
    {
    'email' => 'foo@example.com',
    'token' => 'foobarbaz'
    }
  end

  describe '.find_config' do
    context 'when config file is in current dir' do
      it 'loads the config file in the given dir' do
        Dir.mktmpdir do |dir|
          config_file = File.join(dir, '.mir')
          File.write(config_file, settings.to_yaml)

          config = Mir::Init.find_config(dir)

          expect(config['email']).to eq('foo@example.com')
          expect(config['token']).to eq('foobarbaz')
        end
      end
    end

    context 'when config file is in a parent dir' do
      around(:each) do |test|
        Dir.mktmpdir do |parent_dir|
          config_file = File.join(parent_dir, '.mir')
          File.write(config_file, settings.to_yaml)

          @parent_dir = parent_dir
          @child_dir = File.join(parent_dir, 'child')

          Dir.mkdir(@child_dir)

          test.run
        end
      end

      it 'recursively checks parent directories for the file' do
        config = Mir::Init.find_config(@child_dir)

        expect(config['email']).to eq('foo@example.com')
        expect(config['token']).to eq('foobarbaz')
      end

      it 'includes the directory where the file was found' do
        config = Mir::Init.find_config(@child_dir)

        expect(config['basedir']).to eq(@parent_dir)
      end
    end
  end

  describe '.init_project_dir' do
    let(:answers) do
      { 'email' => 'bar@example.com', 'token' => 'bazbatfoo', 'server' => 'example.com' }
    end

    it 'creates a .mir file if doesnt already exist' do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, '.mir')
        expect(File.exists?(config_file)).to be_false

        Mir::Init.init_project_dir(dir, answers)
        expect(File.exists?(config_file)).to be_true
      end
    end

    it 'writes settings from user answers' do
      Dir.mktmpdir do |dir|
        Mir::Init.init_project_dir(dir, answers)

        config_file = File.join(dir, '.mir')
        config = YAML.load(File.read(config_file))

        expect(config['email']).to eq('bar@example.com')
        expect(config['token']).to eq('bazbatfoo')
        expect(config['server']).to eq('example.com')
      end
    end

    it 'does not overwrite an existing file' do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, '.mir')
        File.write(config_file, settings.to_yaml)

        Mir::Init.init_project_dir(dir, answers)
        current_settings = YAML.load(File.read(config_file))

        expect(current_settings['email']).to eq('foo@example.com')
        expect(current_settings['token']).to eq('foobarbaz')
      end
    end
  end
end
