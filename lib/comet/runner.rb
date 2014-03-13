require 'gli'
require 'yaml'
require 'helpers'
require 'openssl'
require 'shellwords'

module Comet
  class Runner
    extend GLI::App
    version Comet::VERSION

    def self.go(args, cwd)
      program_desc 'Test your Ruby skills! Download Ruby exercises and submit your solutions for grading.'

      desc 'Initialize the current directory as a comet project directory'
      skips_pre
      command :init do |c|
        c.action do |global_options, options, args|
          answers = Comet::Init.find_config(cwd) || {}

          ['email', 'token', 'server'].each do |setting|
            answers[setting] = prompt_for_setting(setting, answers)
          end

          Comet::Init.init_project_dir(cwd, answers)
        end
      end

      desc 'List the available katas'
      command :list do |c|
        c.action do |global_options,options,args|
          katas = Comet::Kata.list(@config)

          if katas.empty?
            puts "No katas available."
          else
            katas.each do |kata|
              printf("(%4d) \e[34m%s\e[0m: %s (%s)\n",
                kata[:id],
                kata[:topic_name],
                kata[:name],
                difficulty_to_string(kata[:difficulty]))
            end
          end
        end
      end

      desc 'Download a kata'
      command :fetch do |c|
        c.action do |global_options, options, args|
          kata_id = args.first
          kata = Comet::Kata.find(@config, kata_id)
          directory = kata.download

          info_file = File.join(directory, '.kata')
          info = YAML.load(File.read(info_file))
          info['id'] = kata_id.to_i

          File.write(info_file, info.to_yaml)

          puts "Downloaded kata to #{directory}."
        end
      end

      desc 'Run test suite'
      command :test do |c|
        c.action do |global_options, options, args|
          kata_file = Comet::Kata.find_kata_dir(cwd)

          if !kata_file.nil?
            Comet::Tester.run_test_suite(kata_file)
          else
            $stderr.puts "\e[31mNot a kata directory.\e[0m"
          end
        end
      end

      desc 'Submit kata'
      command :submit do |c|
        c.action do |global_options, options, args|
          require 'rest_client'
          require 'tmpdir'

          current_dir = cwd
          kata_file = File.join(current_dir, '.kata')

          if File.exists?(kata_file)
            kata_info = YAML.load(File.read(kata_file))
            lib_dir = File.join(current_dir, 'lib')
            slug = File.basename(current_dir)

            Dir.mktmpdir do |tmpdir|
              submission_file = File.join(tmpdir, 'submission.tar.gz')
              if system("tar zcf #{Shellwords.escape(submission_file)} -C #{Shellwords.escape(lib_dir)} .")
                payload = {
                  submission: {
                    challenge_id: kata_info['id'],
                    archive: File.new(submission_file)
                  }
                }

                headers = { 'Authorization' => "Token #{@config['token']}" }

                RestClient.post("#{@config['server']}/api/v1/submissions.json", payload, headers)

                puts "Submitted solution for #{slug}."
              else
                puts "Unable to create submission archive."
                exit 1
              end
            end

          else
            puts "Not a kata directory."
            exit 1
          end
        end
      end

      pre do |global,command,options,args|
        # Only query for newer versions when running commands that makes
        # network calls.
        if [:submit, :fetch, :list].include?(command.name)
          latest_version = Comet::API.latest_gem_version
          if Comet::Version.is_more_recent(latest_version)
            $stderr.puts "\e[33mNOTICE: An updated version of comet exists. " +
              "Run `gem update comet` to upgrade.\e[0m"
          end
        end

        @config = Comet::Init.find_config(cwd)
        !@config.nil?
      end

      on_error do |exception|
        case exception
        when Comet::UnauthorizedError
          $stderr.puts "\e[31mERROR: Invalid credentials. " +
            "Verify that the e-mail, token, and server are correctly " +
            "configured in #{File.join(@config['basedir'], '.comet')}\e[0m"
        else
          raise exception
        end
      end

      run(args)
    end
  end
end
