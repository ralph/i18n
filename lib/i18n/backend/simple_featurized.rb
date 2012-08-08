require 'set'

module I18n
  module Backend
    class SimpleFeaturized < I18n::Backend::Simple
      FeaturizedKey = Struct.new(:name, :backend) do

        def <=>(other)
          name <=> other.name
        end
        include Comparable

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
      end

      attr_writer :active_features_source, :supported_languages_source

      def features
        featurized_keys.map { |key| key.to_s[/@(\w)+/] }.map { |key|
          key[1..-1].to_sym
        }.uniq.sort
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
        supported_languages_source.call
      end

      def supported_languages_source
        @supported_languages_source || ->{ [] }
      end

      def active_features
        active_features_source.call
      end

      def active_features_source
        @active_features_source || ->{ [] }
      end

      def featurized_keys
        init_translations unless initialized?
        regexp = Regexp.new(active_features.map {|f| "@#{f}"}.join('|'))

        list = Set.new
        supported_languages.each do |language|
          list += @translations[language].keys.map(&:to_s).select { |key|
            key =~ regexp
          }.map { |key| FeaturizedKey.new(key, self) }
        end
        list.to_a.sort
      end
    end
  end
end
