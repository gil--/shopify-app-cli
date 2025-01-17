# frozen_string_literal: true
require 'shopify_cli'

module ShopifyCli
  class Project
    include SmartProperties

    class << self
      def current
        at(Dir.pwd)
      end

      def at(dir)
        proj_dir = directory(dir)
        unless proj_dir
          raise(ShopifyCli::Abort, "You are not in a Shopify app project")
        end
        @at ||= Hash.new { |h, k| h[k] = new(directory: k) }
        @at[proj_dir]
      end

      # Returns the directory of the project you are current in
      # Traverses up directory hierarchy until it finds a `.shopify-cli.json`, then returns the directory is it in
      #
      # #### Example Usage
      # `directory`, e.g. `~/src/Shopify/dev`
      #
      def directory(dir)
        @dir ||= Hash.new { |h, k| h[k] = __directory(k) }
        @dir[dir]
      end

      def write(ctx, identifier)
        require 'yaml' # takes 20ms, so deferred as late as possible.
        content = {
          'app_type' => identifier,
        }
        ctx.write('.shopify-cli.yml', YAML.dump(content))
      end

      private

      def __directory(curr)
        loop do
          return nil if curr == '/'
          file = File.join(curr, '.shopify-cli.yml')
          return curr if File.exist?(file)
          curr = File.dirname(curr)
        end
      end
    end

    property :directory

    def app_type
      ShopifyCli::AppTypeRegistry[config['app_type'].to_sym]
    end

    def env
      @env ||= ShopifyCli::Helpers::EnvFile.read(app_type, File.join(directory, '.env'))
    end

    def config
      @config ||= begin
        config = load_yaml_file('.shopify-cli.yml')
        unless config.is_a?(Hash)
          raise ShopifyCli::Abort, '.shopify-cli.yml was not a proper YAML file. Expecting a hash.'
        end
        config
      end
    end

    private

    def load_yaml_file(relative_path)
      f = File.join(directory, relative_path)
      require 'yaml' # takes 20ms, so deferred as late as possible.
      begin
        YAML.load_file(f) || {}
      rescue Psych::SyntaxError => e
        raise(ShopifyCli::Abort, "#{relative_path} contains invalid YAML: #{e.message}")
      # rescue Errno::EACCES => e
      # TODO
      #   Dev::Helpers::EaccesHandler.diagnose_and_raise(f, e, mode: :read)
      rescue Errno::ENOENT
        raise
      end
    end
  end
end
