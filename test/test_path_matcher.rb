require 'test/test_helper'

class TestPathMatcher < Test::Unit::TestCase

  def setup
    @matcher = Path::Matcher.new :key => "foo*", :value => "*bar*"
    @data = {
      :key1 => {
        :key1a => [
          "foo",
          "bar",
          "foobar",
          {:findme => "thing"}
        ],
        'key1b' => "findme"
      },
      'findme' => [
        123,
        456,
        {:findme => 123456}
      ],
      :key2 => "foobar",
      :key3 => {
        :key3a => ["val1", "val2", "val3"]
      }
    }
  end


  def test_new
    assert_equal %r{\A(?:foo(.*))\Z},     @matcher.key
    assert_equal %r{\A(?:(.*)bar(.*))\Z}, @matcher.value
    assert !@matcher.recursive
  end



  def test_each_data_item_hash
    hash = {
      :a => 1,
      :b => 2,
      :c => 3
    }

    keys = []
    values = []

    @matcher.each_data_item hash do |key, val|
      keys << key
      values << val
    end

    assert_equal keys, (keys | hash.keys)
    assert_equal values, (values | hash.values)
  end


  def test_each_data_item_array
    ary = [:a, :b, :c]

    keys = []
    values = []

    @matcher.each_data_item ary do |key, val|
      keys << key
      values << val
    end

    assert_equal [2,1,0], keys
    assert_equal ary.reverse, values
  end


  def test_match_node
    assert @matcher.match_node(:key, "key")
    assert @matcher.match_node("key", :key)

    assert @matcher.match_node(/key/, "foo_key")
    assert !@matcher.match_node("foo_key", /key/)
    assert @matcher.match_node(/key/, /key/)

    assert @matcher.match_node(Path::Matcher::ANY_VALUE, "foo_key")
    assert !@matcher.match_node("foo_key", Path::Matcher::ANY_VALUE)

    assert @matcher.match_node(1..3, 1)
    assert !@matcher.match_node(1, 1..3)
    assert @matcher.match_node(1..3, 1..3)
  end


  def test_find_in
    keys = []

    Path::Matcher.new(:key => /key/).find_in @data do |data, key|
      keys << key.to_s
      assert_equal @data, data
    end

    assert_equal ['key1', 'key2', 'key3'], keys.sort
  end


  def test_find_in_recursive
    keys = []
    data_points = []

    matcher = Path::Matcher.new :key       => :findme,
                                       :recursive => true

    path_matches = matcher.find_in @data do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert path_matches.find{|pm| pm.splat == [[matcher, [:key1, :key1a, 3]]]}
    assert_equal 3, keys.length
    assert_equal 1, keys.uniq.length
    assert_equal "findme", keys.first

    assert_equal 3, data_points.length
    assert data_points.include?(@data)
    assert data_points.include?({:findme => "thing"})
    assert data_points.include?({:findme => 123456})
  end


  def test_find_in_value
    keys = []
    data_points = []

    matcher = Path::Matcher.new :key => "*", :value => "findme"
    matcher.find_in @data do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert keys.empty?
    assert data_points.empty?

    matcher = Path::Matcher.new :key       => "*",
                                       :value     => "findme",
                                       :recursive => true

    paths = matcher.find_in @data do |data, key|
      keys << key.to_s
      data_points << data
    end

    assert_equal ['key1b'], keys
    assert_equal [@data[:key1]], data_points
    assert_equal ['key1b'], paths.first.matches
  end


  def test_find_in_match
    matcher = Path::Matcher.new :key       => "find*",
                                       :value     => "th*g",
                                       :recursive => true
    paths = matcher.find_in @data
    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal Path::Match, paths.first.class

    assert_equal ["me", "in"], paths.first.matches
  end


  def test_find_in_match_one
    matcher = Path::Matcher.new :key       => "findme|foo",
                                       :recursive => true
    paths = matcher.find_in @data

    expected_paths = [
      ["findme"],
      ["findme", 2, :findme],
      [:key1, :key1a, 3, :findme]
    ]

    assert_equal expected_paths, (expected_paths | paths)
    assert_equal Path::Match, paths.first.class

    assert_equal ["findme"], paths.first.matches
  end


  def test_find_in_match_one_value
    matcher = Path::Matcher.new :key       => "findme|foo",
                                       :value     => "th*g",
                                       :recursive => true
    paths = matcher.find_in @data
    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal Path::Match, paths.first.class

    assert_equal ["findme", "in"], paths.first.matches
  end


  def test_find_in_match_any
    matcher = Path::Matcher.new :key => "*"
    paths = matcher.find_in @data

    expected_paths = [
      ["findme"],
      [:key1],
      [:key2],
      [:key3]
    ]

    paths.each do |path|
      assert path.splat.empty?,
        "Expected empty splat for #{path.inspect} but got #{path.splat.inspect}"
    end

    assert_equal expected_paths, (expected_paths | paths)
    assert_equal Path::Match, paths.first.class
    assert_equal expected_paths, (expected_paths | paths.map{|p| p.matches})
  end


  def test_find_in_match_value_only
    matcher = Path::Matcher.new :value     => "th*g",
                                       :recursive => true

    paths = matcher.find_in @data

    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal ["in"], paths.first.matches
  end


  def test_find_in_match_value_and_nil_key
    matcher = Path::Matcher.new :key       => nil,
                                       :value     => "th*g",
                                       :recursive => true

    paths = matcher.find_in @data

    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal ["in"], paths.first.matches
  end


  def test_find_in_match_value_and_empty_key
    matcher = Path::Matcher.new :key       => "",
                                       :value     => "th*g",
                                       :recursive => true

    paths = matcher.find_in @data

    assert_equal [[:key1, :key1a, 3, :findme]], paths
    assert_equal ["in"], paths.first.matches
  end


  def test_find_in_match_value_and_nil_value
    matcher = Path::Matcher.new :key       => "*3a",
                                       :value     => nil,
                                       :recursive => true

    paths = matcher.find_in @data

    assert_equal [[:key3, :key3a]], paths
    assert_equal ["key"], paths.first.matches
  end


  def test_find_in_match_value_and_empty_value
    matcher = Path::Matcher.new :key       => "*3a",
                                       :value     => "",
                                       :recursive => true

    paths = matcher.find_in @data

    assert_equal [[:key3, :key3a]], paths
    assert_equal ["key"], paths.first.matches
  end


  def test_find_in_match_splat
    matcher = Path::Matcher.new :key       => "findme",
                                       :recursive => true

    matches = matcher.find_in @data

    splat_i = matches.index [:key1, :key1a, 3, :findme]
    assert_equal [:key1, :key1a, 3], matches[splat_i].splat[0][1]

    splat_i = matches.index ["findme"]
    assert_equal [], matches[splat_i].splat[0][1]

    splat_i = matches.index ["findme", 2, :findme]
    assert_equal ["findme", 2], matches[splat_i].splat[0][1]
  end


  def test_find_in_match_splat_value
    matcher = Path::Matcher.new :value     => "foobar",
                                       :recursive => true

    matches = matcher.find_in @data

    assert(matches.any?{|m|
      m == [:key1, :key1a, 2] && assert_equal([:key1, :key1a, 2], m.splat[0][1])
      true
    })

    assert(matches.any?{|m|
      m == [:key2] && assert_equal([:key2], m.splat[0][1])
      true
    })
  end


  def test_parse_node_range
    assert_equal 1..4,   @matcher.parse_node("1..4")
    assert_equal 1...4,  @matcher.parse_node("1...4")
    assert_equal "1..4", @matcher.parse_node("\\1..4")
    assert_equal "1..4", @matcher.parse_node("1\\..4")
    assert_equal "1..4", @matcher.parse_node("1.\\.4")
    assert_equal "1..4", @matcher.parse_node("1..\\4")
    assert_equal "1..4", @matcher.parse_node("1..4\\")
  end


  def test_parse_node_index_length
    assert_equal 2...6, @matcher.parse_node("2,4")
    assert_equal "2,4", @matcher.parse_node("\\2,4")
    assert_equal "2,4", @matcher.parse_node("2\\,4")
    assert_equal "2,4", @matcher.parse_node("2,\\4")
    assert_equal "2,4", @matcher.parse_node("2,4\\")
  end


  def test_parse_node_anyval
    assert_equal Path::Matcher::ANY_VALUE, @matcher.parse_node("*")
    assert_equal Path::Matcher::ANY_VALUE, @matcher.parse_node("")
    assert_equal Path::Matcher::ANY_VALUE, @matcher.parse_node("**?*?*?")
    assert_equal Path::Matcher::ANY_VALUE, @matcher.parse_node(nil)
  end


  def test_parse_node_regex
    assert_equal(/\A(?:test(.*))\Z/,       @matcher.parse_node("test*"))
    assert_equal(/\A(?:(.?)test(.*))\Z/,   @matcher.parse_node("?test*"))
    assert_equal(/\A(?:\?test(.*))\Z/,     @matcher.parse_node("\\?test*"))
    assert_equal(/\A(?:(.?)test\*(.*))\Z/, @matcher.parse_node("?test\\**"))
    assert_equal(/\A(?:(.?)test(.*))\Z/,   @matcher.parse_node("?test*?**??"))
    assert_equal(/\A(?:(.?)test(.?)(.?)(.*))\Z/,
      @matcher.parse_node("?test??**??"))
    assert_equal(/\A(?:a|b)\Z/,            @matcher.parse_node("a|b"))
    assert_equal(/\A(?:a|b(c|d))\Z/,       @matcher.parse_node("a|b(c|d)"))

    matcher = Path::Matcher.new :regex_opts => Regexp::IGNORECASE
    assert_equal(/\A(?:a|b(c|d))\Z/i, matcher.parse_node("a|b(c|d)"))
  end


  def test_parse_node_string
    assert_equal "a|b", @matcher.parse_node("a\\|b")
    assert_equal "a(b", @matcher.parse_node("a\\(b")
    assert_equal "a?b", @matcher.parse_node("a\\?b")
    assert_equal "a*b", @matcher.parse_node("a\\*b")
  end


  def test_parse_node_passthru
    assert_equal Path::PARENT,
      @matcher.parse_node(Path::PARENT)

    assert_equal :thing, @matcher.parse_node(:thing)
  end
end
