require 'set'

module I18n
  module Backend
    class SimpleFeaturized < I18n::Backend::Simple
      FeaturizedKey = Struct.new(:name, :backend) do
        include Comparable

        def <=>(other)
          name <=> other.name
        end

        def to_s
          name
        end

        def translations_complete?
          missing_languages.none?
        end

        def missing_languages
          translations = backend.supported_languages.inject({}) { |memo, language|
            memo[language] = backend.send(:lookup, language, name)
            memo
          }
          translations.reject { |language, translation| translation }.keys
        end

        def =~(regexp)
          name =~ regexp
        end

        def inspect
          "\"#{name}\""
        end

        def feature
          Feature.new name.split('.').first.to_sym, backend
        end
      end


      Feature = Struct.new(:name, :backend) do
        include Comparable

        def <=>(other)
          name <=> other.name
        end

        def inspect
          "\"#{name}\""
        end

        def keys
          SimpleFeaturized.flat_hash_keys backend.featurized_hash[name.to_sym], name
        end

        def to_s
          name.to_s
        end

        def to_sym
          name.to_sym
        end

        def languages_with_missing_keys
          backend.unready_languages_for(self)
        end

        def languages_with_missing_keys?
          languages_with_missing_keys.any?
        end

        def languages
          backend.supported_languages
        end

        def keys_missing_for(language)
          language.keys_missing_for self
        end

        def state
          backend.feature_state_source.call(name)
        end
      end


      Language = Struct.new(:name, :backend) do
        include Comparable

        def <=>(other)
          name <=> other.name
        end

        def keys_with_translations_missing
          backend.missing_keys_by_language[self] || []
        end

        def keys_missing_for(feature)
          regexp = Regexp.new("^#{feature}\.")
          keys_with_translations_missing.select { |k| k =~ regexp }
        end

        def features_with_missing_keys
          keys_with_translations_missing.map(&:feature).uniq.sort
        end

        def to_s
          name.to_s
        end

        def to_sym
          name.to_sym
        end

        def inspect
          "\"#{name}\""
        end
      end




      attr_writer :features_source, :feature_state_source, :supported_languages_source

      def features
        active_features.uniq.sort.map { |sym| Feature.new(sym, self) }
      end

      def keys_with_translations_missing
        init_translations unless initialized?
        featurized_keys.reject(&:translations_complete?)
      end

      def keys_missing_for?(feature)
        keys = keys_missing_for(feature)
        keys.any? ? true : false
      end

      def keys_missing_for(feature)
        regexp = Regexp.new("^#{feature}\.")
        keys_with_translations_missing.select { |k| k =~ regexp }
      end

      def keys_for(feature)
        init_translations unless initialized?

        self.class.flat_hash_keys featurized_hash[feature.to_sym], feature.to_s
      end

      def unready_languages_for?(feature)
        languages = unready_languages_for(feature)
        languages.any? ? true : false
      end

      def unready_languages_for(feature)
        keys = keys_missing_for(feature)
        keys.map { |key| key.missing_languages }.flatten.uniq.sort
      end

      def supported_languages
        supported_languages_source.call.map { |l| Language.new l, self }
      end

      def supported_languages_source
        @supported_languages_source || ->{ [] }
      end

      def active_features
        features_source.call
      end

      def features_source
        @features_source || ->{ [] }
      end

      def feature_state_source
        @feature_state_source || ->(name){ :live }
      end

      def featurized_keys
        self.class.flat_hash_keys(featurized_hash).map do |key|
          FeaturizedKey.new key, self
        end
      end

      def featurized_hash
        init_translations unless initialized?

        supported_languages.inject({}) do |all_keys, language|
          keys = @translations[language.to_sym].select {|k,_| active_features.include? k }
          all_keys.deep_merge! keys unless keys.nil?
          all_keys
        end
      end

      def missing_keys_by_language
        supported_languages.inject({}) do |memo, language|
          memo[language] = featurized_keys.map { |key|
            translation = lookup(language, key)
            translation.nil? ? key : nil
          }.compact
          memo
        end
      end

      def self.flat_hash_keys(hash, prefix = nil, separator = I18n.default_separator)
        hash.inject([]) do |list, key_value|
          key, value = key_value
          current_key = [prefix, key.to_s].compact.join(separator)
          if value.is_a? Hash
            list += flat_hash_keys(value, current_key, separator)
          else
            list << current_key
          end
          list
        end
      end
    end
  end
end
