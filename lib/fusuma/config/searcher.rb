# frozen_string_literal: true

# Index for searching value from config.yml
module Fusuma
  class Config
    # Search config.yml
    class Searcher
      def initialize
        @cache = {}
      end

      # @param index [Index]
      # @param location [Hash]
      # @return [NilClass]
      # @return [Hash]
      # @return [Object]
      def search(index, location:)
        key = index.keys.first
        return location if key.nil?

        return nil if location.nil?

        return nil unless location.is_a?(Hash)

        next_index = Index.new(index.keys[1..-1])

        value = nil
        next_location_cadidates(location, key).find do |next_location|
          value = search(next_index, location: next_location)
        end
        value
      end

      def search_with_context(index, location:, context:)
        return nil if location.nil?

        return search(index, location: location[0]) if context == {}

        value = nil
        location.find do |conf|
          value = search(index, location: conf) if conf[:context] == context
        end
        value
      end

      # @param index [Index]
      # @param location [Hash]
      # @return [NilClass]
      # @return [Hash]
      # @return [Object]
      def search_with_cache(index, location:)
        cache([index.cache_key, Searcher.context]) do
          search_with_context(index, location: location, context: Searcher.context)
        end
      end

      def cache(key)
        key = key.join(",") if key.is_a? Array
        if @cache.key?(key)
          @cache[key]
        else
          @cache[key] = block_given? ? yield : nil
        end
      end

      private

      # next locations' candidates sorted by priority
      #  1. look up location with key
      #  2. skip the key and go to child location
      def next_location_cadidates(location, key)
        [
          location[key.symbol],
          key.skippable && location
        ].compact
      end

      class << self
        # Search with context from load_streamed Config
        # @param context [Hash]
        # @return [Object]
        def with_context(context, &block)
          @context = context || {}
          result = block.call
          @context = {}
          result
        end

        # Return a matching context from config
        # @params request_context [Hash]
        # @return [Hash]
        def find_context(request_context, &block)
          # Search in blocks in the following order.
          # 1. primary context(no context)
          # 2. complete match config[:context] == request_context
          # 3. partial match config[:context] =~ request_context
          return {} if with_context({}, &block)

          Config.instance.keymap.each do |config|
            next unless config[:context] == request_context
            return config[:context] if with_context(config[:context], &block)
          end
          if request_context.keys.size > 1
            Config.instance.keymap.each do |config|
              next if config[:context].nil?

              next unless config[:context].all? { |k, v| request_context[k] == v }
              return config[:context] if with_context(config[:context], &block)
            end
          end
        end

        attr_reader :context

      end
    end
  end
end
