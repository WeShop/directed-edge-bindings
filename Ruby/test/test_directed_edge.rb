require 'helper'

# Defines a multithreaded "each"

module Enumerable
  def concurrently
    map {|item| Thread.new { yield item }}.each {|t| t.join }
  end
end

class TestDirectedEdge < Test::Unit::TestCase
  def setup
    user = ENV['DIRECTEDEDGE_TEST_DB']
    pass = ENV['DIRECTEDEDGE_TEST_PASS']
    @database = DirectedEdge::Database.new(user, pass)
    @database.import('../testdb.xml')
  end

  def test_exporter
    exporter = DirectedEdge::Exporter.new('exported.xml')

    product = DirectedEdge::Item.new(exporter.database, 'test_product')
    product.add_tag('product')
    product['name'] = 'Test Product'
    exporter.export(product)

    first_user = DirectedEdge::Item.new(exporter.database, 'test_user_1')
    second_user = DirectedEdge::Item.new(exporter.database, 'test_user_2')
    first_user.add_tag('user')
    first_user['name'] = 'Test User'

    first_user.link_to(second_user)
    first_user.link_to(product, 5)

    exporter.export(first_user)
    exporter.export(second_user)

    exporter.finish

    database = DirectedEdge::Database.new('testdb', 'test')
    database.import('exported.xml')

    user = DirectedEdge::Item.new(database, 'test_user_1')
    product = DirectedEdge::Item.new(database, 'test_product')

    assert(user.tags.include?('user'))
    assert_equal('Test User', user['name'])

    assert(user.links.include?('test_product'))
    assert(user.links.include?('test_user_2'))

    assert_equal(5, user.links['test_product'])

    assert(product.tags.include?('product'))
    assert_equal('Test Product', product['name'])
  end

  def test_add
    exporter = DirectedEdge::Exporter.new(@database)
    item = DirectedEdge::Item.new(exporter.database, 'Foo')
    item['name'] = 'Bar'
    exporter.export(item)
    exporter.finish
    
    item = DirectedEdge::Item.new(@database, 'Foo')
    assert_equal('Bar', item['name'])
  end

  def test_tags
    item = DirectedEdge::Item.new(@database, 'customer1')
    test_tag = 'test_tag'

    assert(!item.tags.include?(test_tag))

    item.add_tag(test_tag);
    item.save

    assert(item.tags.include?(test_tag))

    item.remove_tag(test_tag);
    item.save

    assert(!item.tags.include?(test_tag))
  end

  def test_items
    first_item = DirectedEdge::Item.new(@database, 'test_1')
    first_item.create

    second_item = DirectedEdge::Item.new(@database, 'test_2')
    second_item.create([first_item])

    third_item = DirectedEdge::Item.new(@database, 'test_3')
    third_item.create([first_item, second_item], 'test_tag')

    assert_equal('test_1', first_item.name)

    # Make sure that the number of tags / links for the first item is zero

    assert_equal(0, first_item.links.length)
    assert_equal(0, first_item.tags.length)

    # Link the first item to the second item and make sure it worked

    first_item.link_to(second_item)
    first_item.save
    assert_equal(1, first_item.links.length)

    # Make sure that the number of tags for the second item is zero and that
    # there is a link to the second item

    assert_equal(1, second_item.links.length)
    assert_equal(0, second_item.tags.length)

    # Make sure that the third item is linked to both the first and second items

    assert_equal(2, third_item.links.length)
    assert(third_item.links.include?(first_item))
    assert(third_item.links.include?(second_item))

    # Make sure that the first and second items show up in the related items for
    # the third item

    assert(third_item.related.include?(first_item.to_s))
    assert(third_item.related.include?(second_item.to_s))

    # Since linked items are excluded from recommendations, nothing should show
    # up in the recommended items for the third item.

    assert_equal(0, third_item.recommended.length)
    assert_equal(1, second_item.recommended.length)
    assert_equal(0, second_item.recommended(['unknown_tag']).length)
    assert_equal([third_item.to_s], first_item.recommended(['test_tag']))

    # Remove the link from the second item and assure that it was removed

    second_item.unlink_from(first_item)
    second_item.save

    assert_equal(0, second_item.links.length)

    # Remove the links from the third item and assure that they were removed

    third_item.unlink_from(first_item)
    third_item.unlink_from(second_item)
    third_item.save

    assert_equal(0, third_item.links.length)

    # Now make sure that those items no longer show up as related items

    assert(!third_item.related.include?(first_item.to_s))
    assert(!third_item.related.include?(second_item.to_s))

    # Test item removal

    assert_equal(1, first_item.links.length)

    second_item.destroy
    first_item.reload

    assert(0, first_item.links.length)
  end

  def test_tags
    item = DirectedEdge::Item.new(@database, 'customer1')
    item.add_tag('dude')
    assert(item.tags.include?('dude'))

    item.save
    item.reload
    assert(item.tags.include?('dude'))

    item.remove_tag('dude')
    item.add_tag('greek')
    item.save
    item.reload
    assert(item.tags.include?('greek'))
    assert(!item.tags.include?('dude'))

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.remove_tag('greek')
    item.save
    item.reload
    
    assert(!item.tags.include?('greek'))
  end

  def test_properties
    item = DirectedEdge::Item.new(@database, 'customer1')

    assert_equal(0, item.properties.length)

    item['test_property_1'] = 'test_value'
    item.save

    assert_equal(1, item.properties.length)
    assert_equal('test_value', item['test_property_1'])

    item['test_property_2'] = 'test_value'

    assert_equal(2, item.properties.length)
    assert_equal('test_value', item['test_property_2'])

    item['test_property_1'] = 'test_value_updated'

    assert_equal(2, item.properties.length)
    assert_equal('test_value_updated', item['test_property_1'])

    # Test the cached example of clearing a property
    
    item.clear_property('test_property_1')
    assert(!item.properties.include?('test_property_1'))

    # Make sure that it stays gone when reloading

    item.save
    item.reload
    assert(!item.properties.include?('test_property_1'))

    # Test the incremental update

    item['test_property_1'] = 'test_value'
    item.save

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.clear_property('test_property_1')
    item.save
    item.reload
    assert(!item.properties.include?('test_property_1'))
  end

  def test_load
    def run_load_test(prefix, count)
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        item.create([], ['test_tag'])
      end
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        item['test_property'] = 'test_value'
        item.save
      end
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        assert_equal(1, item.tags.length)
        assert_equal(1, item.properties.length)
      end
    end

    # Run 5 sets of load tests which each create 100 items, add a property to
    # them, and then query them to make sure the tag and properties on each of
    # them are correct

    (1..5).concurrently do |i|
      # Stagger the results so that reads and writes are interleaved
      sleep(i - 1)
      run_load_test(i, 100)
    end
  end

  def test_rankings
    customer1 = DirectedEdge::Item.new(@database, 'customer1')
    customer2 = DirectedEdge::Item.new(@database, 'customer2')
    customer3 = DirectedEdge::Item.new(@database, 'customer3')

    # Test an out of range ranking.

    customer1.links[customer2] = -1
    assert_raise(RestClient::RequestFailed) { customer1.save }

    # And another.

    customer1.reload
    customer1.links[customer2] = 100
    assert_raise(RestClient::RequestFailed) { customer1.save }

    customer1.reload
    customer1.link_to(customer3, 10)
    customer1.save
    customer1.reload
    assert_equal(10, customer1.weight_for(customer3))
  end

  def test_group_related
    assert_equal(0, @database.group_related([], ['product']).size)
    assert_equal(20, @database.group_related(['product1', 'product2'], ['product']).size)
  end

  def test_unsafe_chars
    item = DirectedEdge::Item.new(@database, ';@%&!')
    item['foo'] = 'bar'
    item.save

    item = DirectedEdge::Item.new(@database, ';@%&!')
    assert(item['foo'] == 'bar')
  end

  def test_bad_links
    item = DirectedEdge::Item.new(@database, 'does not exist')
    assert_raise(RestClient::ResourceNotFound) { item.destroy }

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.link_to('also does not exist')
    assert_raise(RestClient::RequestFailed) { item.save }
  end

  def test_query_parameters
    item = DirectedEdge::Item.new(@database, 'product1')
    assert_equal(5, item.related(['product'], :max_results => 5).size)

    item.link_to('product21')
    item.save

    assert(item.related(['product']).include?('product21'))
    assert(!item.related(['product'], :exclude_linked => true).include?('product21'))
  end

  def test_include_properties
    item = DirectedEdge::Item.new(@database, 'product1')
    other = DirectedEdge::Item.new(@database, 'product21')
    other['foo'] = 'bar'
    other.save
    related = item.related(['product'], :include_properties => true)
    assert_equal('bar', related['product21']['foo'])

    related = @database.group_related(['product1'], ['product'], :include_properties => true)
    assert_equal('bar', related['product21']['foo'])

    customer = DirectedEdge::Item.new(@database, 'customer2')
    recommended = customer.recommended(['product'], :include_properties => true)
    assert_equal('bar', recommended['product21']['foo'])
  end
end