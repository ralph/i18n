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
          Feature.new name[/\@(\w+)/, 1].to_sym, backend
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
          regexp = Regexp.new("\@#{name}")
          backend.featurized_keys.select { |k| k =~ regexp }
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

        def missing_keys_for(language)
          language.missing_keys_for self
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

        def missing_keys_for(feature)
          regexp = Regexp.new("\@#{feature}")
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
        regexp = Regexp.new("\@#{feature}")
        keys_with_translations_missing.select { |k| k =~ regexp }
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
        @state_source || ->(name){ :live }
      end

      def featurized_keys
        init_translations unless initialized?
        regexp = Regexp.new(active_features.map {|f| "@#{f}"}.join('|'))

        list = Set.new
        supported_languages.each do |language|
          list += @translations[language.to_sym].keys.map(&:to_s).select { |key|
            key =~ regexp
          }.map { |key| FeaturizedKey.new(key, self) }
        end
        list.to_a.sort
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
    end
  end
end
