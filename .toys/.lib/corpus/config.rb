# frozen_string_literal: true

require "yaml"

module Corpus
  ##
  # The hand-maintained half of the corpus definition, read from
  # `.toys/.data/corpus-config.yml`.
  #
  # The manifest is regenerated in full on every run, so nothing a human
  # decides can live there. It lives here instead, and this class is the only
  # thing that knows the file's shape.
  #
  # Every pin, exclusion and family carries a `reason`. That is enforced here
  # rather than left to review, because an unexplained pin is indistinguishable
  # from an accident a year later, and the whole point of pinning a gem is that
  # a human knew something the rankings did not.
  #
  class Config
    ##
    # Reads and validates a config file.
    #
    # @param path [String] Path to the YAML config file.
    # @return [Corpus::Config]
    #
    def self.load_file(path)
      new(::YAML.load_file(path), path: path)
    end

    ##
    # @param data [Hash] Parsed config contents.
    # @param path [String] Where the contents came from, for error messages.
    #
    def initialize(data, path: "(config)")
      @path = path
      @pins = string_keyed_list(data, "pins")
      @excludes = string_keyed_list(data, "exclude")
      @families = string_keyed_list(data, "families").map { |entry| Family.new(entry, path) }
      validate!
    end

    # @return [Array<String>] Gem names always included, in config order.
    attr_reader :pins

    # @return [Array<String>] Gem names never included.
    attr_reader :excludes

    # @return [Array<Corpus::Config::Family>] Family caps, in config order.
    attr_reader :families

    ##
    # Whether a gem is excluded by name.
    #
    # @param name [String] Gem name.
    # @return [boolean]
    #
    def excluded?(name)
      @excludes.include?(name)
    end

    ##
    # The family a gem belongs to, or nil if it belongs to none. The first
    # match in config order wins, so overlapping patterns are resolved by
    # where they appear in the file rather than by which is more specific.
    #
    # @param name [String] Gem name.
    # @return [Corpus::Config::Family,nil]
    #
    def family_for(name)
      @families.find { |family| family.matches?(name) }
    end

    ##
    # A cap on how many gems from one structurally uniform family may be
    # selected by ranking.
    #
    class Family
      ##
      # @param entry [Hash] One element of the config's `families` list.
      # @param path [String] Config path, for error messages.
      #
      def initialize(entry, path)
        @name = entry["name"]
        @cap = entry["cap"]
        raise ConfigError, "#{path}: a family needs a name" if @name.to_s.empty?
        unless @cap.is_a?(::Integer) && @cap.positive?
          raise ConfigError,
                "#{path}: family #{@name.inspect} needs a positive cap"
        end
        begin
          @match = ::Regexp.new(entry["match"].to_s)
        rescue ::RegexpError => e
          raise ConfigError, "#{path}: family #{@name.inspect} has an unparseable match: #{e.message}"
        end
      end

      # @return [String] Human-readable family name, used in reports.
      attr_reader :name

      # @return [Integer] Most gems this family may contribute by ranking.
      attr_reader :cap

      # @return [Regexp] Pattern matched against gem names.
      attr_reader :match

      ##
      # Whether a gem name belongs to this family.
      #
      # @param gem_name [String] Gem name.
      # @return [boolean]
      #
      def matches?(gem_name)
        @match.match?(gem_name)
      end
    end

    ##
    # Raised when the config file cannot be understood.
    #
    class ConfigError < ::StandardError
    end

    private

    # Reads one top-level list, tolerating an absent or null key so that an
    # empty section can be written as `exclude: []` or omitted entirely.
    def string_keyed_list(data, key)
      value = data.is_a?(::Hash) ? data[key] : nil
      return [] if value.nil?
      raise ConfigError, "#{@path}: #{key} must be a list" unless value.is_a?(::Array)
      return value if key == "families"
      value.map do |entry|
        raise ConfigError, "#{@path}: each #{key} entry must be a mapping" unless entry.is_a?(::Hash)
        name = entry["name"].to_s
        raise ConfigError, "#{@path}: a #{key} entry is missing a name" if name.empty?
        if entry["reason"].to_s.strip.empty?
          raise ConfigError,
                "#{@path}: #{key} entry #{name.inspect} is missing a reason"
        end
        name
      end
    end

    # A gem that is both pinned and excluded is a contradiction the tool
    # cannot resolve by picking a side, so it is refused outright rather than
    # silently obeying whichever check happens to run first.
    def validate!
      conflicts = @pins & @excludes
      unless conflicts.empty?
        raise ConfigError, "#{@path}: #{conflicts.join(', ')} appear in both pins and exclude"
      end
      duplicates = @pins.tally.select { |_name, n| n > 1 }.keys
      raise ConfigError, "#{@path}: duplicate pins: #{duplicates.join(', ')}" unless duplicates.empty?
    end
  end
end
