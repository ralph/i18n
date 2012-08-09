require 'test_helper'

class FeaturizedKeyTest < Test::Unit::TestCase
  def setup
    @fk_class = I18n::Backend::SimpleFeaturized::FeaturizedKey
    @fk = @fk_class.new 'name', 'backend'
  end

  test "has a name" do
    assert_equal 'name', @fk.name
  end

  test "has a backend" do
    assert_equal 'backend', @fk.backend
  end

  class WithBackendTest < Test::Unit::TestCase
    def setup
      @fk_class = I18n::Backend::SimpleFeaturized::FeaturizedKey
      I18n.load_path = [locales_dir + '/en_featurized.yml']
      backend = I18n::Backend::SimpleFeaturized.new
      backend.features_source = ->{ [:sexy_bookings, :my_feature, :deutsch] }
      backend.supported_languages_source = ->{ [:de, :en] }
      I18n.backend = backend
    end

    test "#translations_complete? is false if not all translations present" do
      fk = @fk_class.new "Etwas nur auf Deutsch @deutsch", I18n.backend
      assert !fk.translations_complete?
    end

    test "#translations_complete? is true if all translations present" do
      fk = @fk_class.new "Add another place @sexy_bookings", I18n.backend
      assert fk.translations_complete?
    end

    test "#missing_languages returns languages that are missing translations" do
      fk = @fk_class.new "Etwas nur auf Deutsch @deutsch", I18n.backend
      assert_equal [:en], fk.missing_languages.map(&:to_sym)
    end

    test "#feature returns matching feature" do
      fk = @fk_class.new "Etwas nur auf Deutsch @deutsch", I18n.backend
      assert_equal :deutsch, fk.feature.to_sym
    end
  end
end


class FeatureTest < Test::Unit::TestCase
  def setup
    @klazz = I18n::Backend::SimpleFeaturized::Feature
    @feature = @klazz.new :name, 'backend'
  end

  test "has a name" do
    assert_equal :name, @feature.name
  end

  test "has a backend" do
    assert_equal 'backend', @feature.backend
  end

  class WithBackendTest < Test::Unit::TestCase
    def setup
      @klazz = I18n::Backend::SimpleFeaturized::Feature
      I18n.load_path = [locales_dir + '/en_featurized.yml']
      backend = I18n::Backend::SimpleFeaturized.new
      backend.features_source = ->{ [:sexy_bookings, :my_feature, :deutsch] }
      backend.supported_languages_source = ->{ [:de, :en] }
      I18n.backend = backend
    end

    test "#keys returns all translation keys belonging to that feature" do
      feature = @klazz.new :sexy_bookings, I18n.backend
      expected = [
        "Add another place @sexy_bookings",
        "Do something @sexy_bookings"
      ]
      assert_equal expected, feature.keys.map(&:to_s)
    end

    test "#languages is same as in backend" do
      feature = @klazz.new :sexy_bookings, I18n.backend
      assert_equal I18n.backend.supported_languages, feature.languages
    end

    test "#languages_with_missing_keys returns languages that are missing keys for a feature" do
      feature = @klazz.new :sexy_bookings, I18n.backend
      language_class = I18n::Backend::SimpleFeaturized::Language
      expected = [language_class.new(:de, I18n.backend)]
      assert_equal expected, feature.languages_with_missing_keys
    end

    test "#missing_keys_for(language)" do
      feature = @klazz.new :sexy_bookings, I18n.backend
      language_class = I18n::Backend::SimpleFeaturized::Language
      language = language_class.new(:de, I18n.backend)

      expected = ["Do something @sexy_bookings"]
      assert_equal expected, feature.missing_keys_for(language).map(&:to_s)
    end
  end
end



class LanguageTest < Test::Unit::TestCase
  def setup
    @klazz = I18n::Backend::SimpleFeaturized::Language
    @language = @klazz.new :de, 'backend'
  end

  test "has a name" do
    assert_equal :de, @language.name
  end

  test "has a backend" do
    assert_equal 'backend', @language.backend
  end

  class WithBackendTest < Test::Unit::TestCase
    def setup
      @klazz = I18n::Backend::SimpleFeaturized::Language
      I18n.load_path = [locales_dir + '/en_featurized.yml']
      backend = I18n::Backend::SimpleFeaturized.new
      backend.features_source = ->{ [:sexy_bookings, :my_feature, :deutsch] }
      backend.supported_languages_source = ->{ [:de, :en] }
      I18n.backend = backend
    end

    test "#keys_with_translations_missing" do
      language = @klazz.new :de, I18n.backend
      expected = ["Do something @sexy_bookings"]
      assert_equal expected, language.keys_with_translations_missing.map(&:to_s)
    end

    test "#features_with_missing_keys" do
      language = @klazz.new :de, I18n.backend
      expected = [:sexy_bookings]
      assert_equal expected, language.features_with_missing_keys.map(&:to_sym)
    end
  end
end



class I18nBackendSimpleFeaturizedTest < Test::Unit::TestCase
  def setup
    I18n.backend = I18n::Backend::SimpleFeaturized.new
    I18n.load_path = [locales_dir + '/en_featurized.yml']

    @backend = I18n.backend
    @backend.features_source = ->{ [:sexy_bookings, :my_feature, :deutsch] }
    @backend.supported_languages_source = ->{ [:de, :en] }
  end

  test "#active_features calls the features_source" do
    expected = [:sexy_bookings, :my_feature, :deutsch]
    assert_equal expected, @backend.active_features
  end

  test "#supported_languages calls the supported_languages_source" do
    assert_equal [:de, :en], @backend.supported_languages.map(&:to_sym)
  end

  test "#features returns list of features that have translations" do
    assert_equal [:deutsch, :my_feature, :sexy_bookings], @backend.features.map(&:to_sym)
  end

  test "#featurized_keys returns list of featurized translation keys" do
    expected = [
      "Add another place @sexy_bookings",
      "Do something @sexy_bookings",
      "Etwas nur auf Deutsch @deutsch",
      "something plural with spaces @my_feature"
    ]

    assert_equal expected, @backend.featurized_keys.map(&:to_s)
  end

  test "#keys_with_translations_missing returns list of keys that are missing translations" do
    expected = ["Do something @sexy_bookings", "Etwas nur auf Deutsch @deutsch"]
    assert_equal expected, @backend.keys_with_translations_missing.map(&:to_s)
  end

  test "#keys_missing_for(feature) returns a list of missing keys" do
    expected = ["Do something @sexy_bookings"]
    actual = @backend.keys_missing_for(:sexy_bookings).map(&:to_s)

    assert_equal expected, actual
  end

  test "#keys_missing_for?(feature) is true if keys missing" do
    assert @backend.keys_missing_for?(:sexy_bookings)
  end

  test "#keys_missing_for?(feature) is false if all translations present" do
    assert !@backend.keys_missing_for?(:my_feature)
  end

  test "#unready_languages_for(feature) returns languages that are not fully translated" do
    assert_equal [:en], @backend.unready_languages_for(:deutsch).map(&:to_sym)
  end

  test "#unready_languages_for?(feature) is true for unready languages" do
    assert @backend.unready_languages_for?(:deutsch)
  end

  test "#unready_languages_for?(feature) is false for ready languages" do
    assert !@backend.unready_languages_for?(:my_feature)
  end

  test "#missing_keys_by_language returns a Hash containing the lang as key and missing keys as value" do
    fk_class = I18n::Backend::SimpleFeaturized::FeaturizedKey
    language_class = I18n::Backend::SimpleFeaturized::Language
    expected = {
      language_class.new(:de, @backend) => [fk_class.new("Do something @sexy_bookings", @backend)],
      language_class.new(:en, @backend) => [fk_class.new("Etwas nur auf Deutsch @deutsch", @backend)]
    }
    assert_equal expected, @backend.missing_keys_by_language
  end
end
