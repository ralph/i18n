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
      @fk = @fk_class.new "Etwas nur auf Deutsch @deutsch", I18n.backend
      assert !@fk.translations_complete?
    end

    test "#translations_complete? is true if all translations present" do
      @fk = @fk_class.new "Add another place @sexy_bookings", I18n.backend
      assert @fk.translations_complete?
    end

    test "#missing_languages returns languages that are missing translations" do
      @fk = @fk_class.new "Etwas nur auf Deutsch @deutsch", I18n.backend
      assert_equal [:en], @fk.missing_languages
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
    assert_equal [:de, :en], @backend.supported_languages
  end

  test "#features returns list of features that have translations" do
    assert_equal [:deutsch, :my_feature, :sexy_bookings], @backend.features
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
    assert_equal [:en], @backend.unready_languages_for(:deutsch)
  end

  test "#unready_languages_for?(feature) is true for unready languages" do
    assert @backend.unready_languages_for?(:deutsch)
  end

  test "#unready_languages_for?(feature) is false for ready languages" do
    assert !@backend.unready_languages_for?(:my_feature)
  end
end
