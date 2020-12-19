# frozen_string_literal: true

require "test_helper"

class ParanoidTest < ParanoidBaseTest
  def test_paranoid?
    assert !NotParanoid.paranoid?
    assert_raise(NoMethodError) { NotParanoid.delete_all! }
    assert_raise(NoMethodError) { NotParanoid.with_deleted }
    assert_raise(NoMethodError) { NotParanoid.only_deleted }

    assert ParanoidTime.paranoid?
  end

  def test_scope_inclusion_with_time_column_type
    assert ParanoidTime.respond_to?(:deleted_inside_time_window)
    assert ParanoidTime.respond_to?(:deleted_before_time)
    assert ParanoidTime.respond_to?(:deleted_after_time)

    assert !ParanoidBoolean.respond_to?(:deleted_inside_time_window)
    assert !ParanoidBoolean.respond_to?(:deleted_before_time)
    assert !ParanoidBoolean.respond_to?(:deleted_after_time)
  end

  def test_fake_removal
    assert_equal 3, ParanoidTime.count
    assert_equal 3, ParanoidBoolean.count
    assert_equal 1, ParanoidString.count

    ParanoidTime.first.destroy
    ParanoidBoolean.delete_all("name = 'paranoid' OR name = 'really paranoid'")
    ParanoidString.first.destroy
    assert_equal 2, ParanoidTime.count
    assert_equal 1, ParanoidBoolean.count
    assert_equal 0, ParanoidString.count
    assert_equal 1, ParanoidTime.only_deleted.count
    assert_equal 2, ParanoidBoolean.only_deleted.count
    assert_equal 1, ParanoidString.only_deleted.count
    assert_equal 3, ParanoidTime.with_deleted.count
    assert_equal 3, ParanoidBoolean.with_deleted.count
    assert_equal 1, ParanoidString.with_deleted.count
  end

  def test_real_removal
    ParanoidTime.first.destroy_fully!
    ParanoidBoolean.delete_all!("name = 'extremely paranoid' OR name = 'really paranoid'")
    ParanoidString.first.destroy_fully!
    assert_equal 2, ParanoidTime.count
    assert_equal 1, ParanoidBoolean.count
    assert_equal 0, ParanoidString.count
    assert_equal 2, ParanoidTime.with_deleted.count
    assert_equal 1, ParanoidBoolean.with_deleted.count
    assert_equal 0, ParanoidString.with_deleted.count
    assert_equal 0, ParanoidTime.only_deleted.count
    assert_equal 0, ParanoidBoolean.only_deleted.count
    assert_equal 0, ParanoidString.only_deleted.count

    ParanoidTime.first.destroy
    ParanoidTime.only_deleted.first.destroy
    assert_equal 0, ParanoidTime.only_deleted.count

    ParanoidTime.delete_all!
    assert_empty ParanoidTime.all
    assert_empty ParanoidTime.with_deleted
  end

  def test_non_persisted_destroy
    pt = ParanoidTime.new
    assert_nil pt.paranoid_value
    pt.destroy
    assert_not_nil pt.paranoid_value
  end

  def test_non_persisted_delete
    pt = ParanoidTime.new
    assert_nil pt.paranoid_value
    pt.delete
    assert_not_nil pt.paranoid_value
  end

  def test_non_persisted_destroy!
    pt = ParanoidTime.new
    assert_nil pt.paranoid_value
    pt.destroy!
    assert_not_nil pt.paranoid_value
  end

  def test_removal_not_persisted
    assert ParanoidTime.new.destroy
  end

  # Rails does not allow saving deleted records
  def test_no_save_after_destroy
    paranoid = ParanoidString.first
    paranoid.destroy
    paranoid.name = "Let's update!"

    assert_not paranoid.save
    assert_raises ActiveRecord::RecordNotSaved do
      paranoid.save!
    end
  end

  def test_recursive_fake_removal
    setup_recursive_tests

    @paranoid_time_object.destroy

    assert_equal 2, ParanoidTime.count
    assert_equal 0, ParanoidHasManyDependant.count
    assert_equal 0, ParanoidBelongsDependant.count
    assert_equal @paranoid_boolean_count, ParanoidBoolean.count
    assert_equal 0, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count

    assert_equal 3, ParanoidTime.with_deleted.count
    assert_equal 4, ParanoidHasManyDependant.with_deleted.count
    assert_equal 3, ParanoidBelongsDependant.with_deleted.count
    assert_equal @paranoid_boolean_count + 3, ParanoidBoolean.with_deleted.count
    assert_equal 3, ParanoidHasOneDependant.with_deleted.count
  end

  def test_recursive_real_removal
    setup_recursive_tests

    @paranoid_time_object.destroy_fully!

    assert_equal 0, ParanoidTime.only_deleted.count
    assert_equal 1, ParanoidHasManyDependant.only_deleted.count
    assert_equal 0, ParanoidBelongsDependant.only_deleted.count
    assert_equal 0, ParanoidBoolean.only_deleted.count
    assert_equal 0, ParanoidHasOneDependant.only_deleted.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
  end

  def test_dirty
    pt = ParanoidTime.create
    pt.destroy
    assert_not pt.changed?
  end

  def test_delete_dirty
    pt = ParanoidTime.create
    pt.delete
    assert_not pt.changed?
  end

  def test_destroy_fully_dirty
    pt = ParanoidTime.create
    pt.destroy_fully!
    assert_not pt.changed?
  end

  def test_deleted?
    ParanoidTime.first.destroy
    assert ParanoidTime.with_deleted.first.deleted?

    ParanoidString.first.destroy
    assert ParanoidString.with_deleted.first.deleted?
  end

  def test_delete_deleted?
    ParanoidTime.first.delete
    assert ParanoidTime.with_deleted.first.deleted?

    ParanoidString.first.delete
    assert ParanoidString.with_deleted.first.deleted?
  end

  def test_destroy_fully_deleted?
    object = ParanoidTime.first
    object.destroy_fully!
    assert object.deleted?

    object = ParanoidString.first
    object.destroy_fully!
    assert object.deleted?
  end

  def test_deleted_fully?
    ParanoidTime.first.destroy
    assert_not ParanoidTime.with_deleted.first.deleted_fully?

    ParanoidString.first.destroy
    assert ParanoidString.with_deleted.first.deleted?
  end

  def test_delete_deleted_fully?
    ParanoidTime.first.delete
    assert_not ParanoidTime.with_deleted.first.deleted_fully?
  end

  def test_destroy_fully_deleted_fully?
    object = ParanoidTime.first
    object.destroy_fully!
    assert object.deleted_fully?
  end

  def test_paranoid_destroy_callbacks
    @paranoid_with_callback = ParanoidWithCallback.first
    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy
    end

    assert @paranoid_with_callback.called_before_destroy
    assert @paranoid_with_callback.called_after_destroy
    assert @paranoid_with_callback.called_after_commit_on_destroy
  end

  def test_hard_destroy_callbacks
    @paranoid_with_callback = ParanoidWithCallback.first

    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy!
    end

    assert @paranoid_with_callback.called_before_destroy
    assert @paranoid_with_callback.called_after_destroy
    assert @paranoid_with_callback.called_after_commit_on_destroy
  end

  def test_delete_by_multiple_id_is_paranoid
    model_a = ParanoidBelongsDependant.create
    model_b = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.delete([model_a.id, model_b.id])

    assert_paranoid_deletion(model_a)
    assert_paranoid_deletion(model_b)
  end

  def test_destroy_by_multiple_id_is_paranoid
    model_a = ParanoidBelongsDependant.create
    model_b = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.destroy([model_a.id, model_b.id])

    assert_paranoid_deletion(model_a)
    assert_paranoid_deletion(model_b)
  end

  def test_delete_by_single_id_is_paranoid
    model = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.delete(model.id)

    assert_paranoid_deletion(model)
  end

  def test_destroy_by_single_id_is_paranoid
    model = ParanoidBelongsDependant.create
    ParanoidBelongsDependant.destroy(model.id)

    assert_paranoid_deletion(model)
  end

  def test_instance_delete_is_paranoid
    model = ParanoidBelongsDependant.create
    model.delete

    assert_paranoid_deletion(model)
  end

  def test_instance_destroy_is_paranoid
    model = ParanoidBelongsDependant.create
    model.destroy

    assert_paranoid_deletion(model)
  end

  # Test string type columns that don't have a nil value when not deleted (Y/N for example)
  def test_string_type_with_no_nil_value_before_destroy
    ps = ParanoidString.create!(deleted: "not dead")
    assert_equal 1, ParanoidString.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_after_destroy
    ps = ParanoidString.create!(deleted: "not dead")
    ps.destroy
    assert_equal 0, ParanoidString.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_before_destroy_with_deleted
    ps = ParanoidString.create!(deleted: "not dead")
    assert_equal 1, ParanoidString.with_deleted.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_after_destroy_with_deleted
    ps = ParanoidString.create!(deleted: "not dead")
    ps.destroy
    assert_equal 1, ParanoidString.with_deleted.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_before_destroy_only_deleted
    ps = ParanoidString.create!(deleted: "not dead")
    assert_equal 0, ParanoidString.only_deleted.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_after_destroy_only_deleted
    ps = ParanoidString.create!(deleted: "not dead")
    ps.destroy
    assert_equal 1, ParanoidString.only_deleted.where(id: ps).count
  end

  def test_string_type_with_no_nil_value_after_destroyed_twice
    ps = ParanoidString.create!(deleted: "not dead")
    2.times { ps.destroy }
    assert_equal 0, ParanoidString.with_deleted.where(id: ps).count
  end

  # Test boolean type columns, that are not nullable
  def test_boolean_type_with_no_nil_value_before_destroy
    ps = ParanoidBooleanNotNullable.create!
    assert_equal 1, ParanoidBooleanNotNullable.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_after_destroy
    ps = ParanoidBooleanNotNullable.create!
    ps.destroy
    assert_equal 0, ParanoidBooleanNotNullable.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_before_destroy_with_deleted
    ps = ParanoidBooleanNotNullable.create!
    assert_equal 1, ParanoidBooleanNotNullable.with_deleted.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_after_destroy_with_deleted
    ps = ParanoidBooleanNotNullable.create!
    ps.destroy
    assert_equal 1, ParanoidBooleanNotNullable.with_deleted.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_before_destroy_only_deleted
    ps = ParanoidBooleanNotNullable.create!
    assert_equal 0, ParanoidBooleanNotNullable.only_deleted.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_after_destroy_only_deleted
    ps = ParanoidBooleanNotNullable.create!
    ps.destroy
    assert_equal 1, ParanoidBooleanNotNullable.only_deleted.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_after_destroyed_twice
    ps = ParanoidBooleanNotNullable.create!
    2.times { ps.destroy }
    assert_equal 0, ParanoidBooleanNotNullable.with_deleted.where(id: ps).count
  end

  def test_no_double_tap_destroys_fully
    ps = ParanoidNoDoubleTapDestroysFully.create!
    2.times { ps.destroy }
    assert_equal 1, ParanoidNoDoubleTapDestroysFully.with_deleted.where(id: ps).count
  end

  def test_decrement_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_counter_cache = ParanoidWithCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.paranoid_with_counter_caches_count

    paranoid_with_counter_cache.destroy

    assert_equal 0, paranoid_boolean.reload.paranoid_with_counter_caches_count
  end

  def test_decrement_custom_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_custom_counter_cache = ParanoidWithCustomCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.custom_counter_cache

    paranoid_with_custom_counter_cache.destroy

    assert_equal 0, paranoid_boolean.reload.custom_counter_cache
  end

  def test_destroy_with_optional_belongs_to_and_counter_cache
    ps = ParanoidWithCounterCacheOnOptionalBelognsTo.create!
    ps.destroy
    assert_equal 1, ParanoidWithCounterCacheOnOptionalBelognsTo.only_deleted
      .where(id: ps).count
  end

  def test_hard_destroy_decrement_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_counter_cache = ParanoidWithCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.paranoid_with_counter_caches_count

    paranoid_with_counter_cache.destroy_fully!

    assert_equal 0, paranoid_boolean.reload.paranoid_with_counter_caches_count
  end

  def test_hard_destroy_decrement_custom_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_custom_counter_cache = ParanoidWithCustomCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.custom_counter_cache

    paranoid_with_custom_counter_cache.destroy_fully!

    assert_equal 0, paranoid_boolean.reload.custom_counter_cache
  end

  def test_increment_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_counter_cache = ParanoidWithCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.paranoid_with_counter_caches_count

    paranoid_with_counter_cache.destroy

    assert_equal 0, paranoid_boolean.reload.paranoid_with_counter_caches_count

    paranoid_with_counter_cache.recover

    assert_equal 1, paranoid_boolean.reload.paranoid_with_counter_caches_count
  end

  def test_increment_custom_counters
    paranoid_boolean = ParanoidBoolean.create!
    paranoid_with_custom_counter_cache = ParanoidWithCustomCounterCache
      .create!(paranoid_boolean: paranoid_boolean)

    assert_equal 1, paranoid_boolean.custom_counter_cache

    paranoid_with_custom_counter_cache.destroy

    assert_equal 0, paranoid_boolean.reload.custom_counter_cache

    paranoid_with_custom_counter_cache.recover

    assert_equal 1, paranoid_boolean.reload.custom_counter_cache
  end

  def test_explicitly_setting_table_name_after_acts_as_paranoid_macro
    assert_equal "explicit_table.deleted_at", ParanoidWithExplicitTableNameAfterMacro
      .paranoid_column_reference
  end
end
