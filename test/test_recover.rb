# frozen_string_literal: true

require "test_helper"

class RecoverTest < ParanoidBaseTest
  def test_recovery
    assert_equal 3, ParanoidBoolean.count
    ParanoidBoolean.first.destroy
    assert_equal 2, ParanoidBoolean.count
    ParanoidBoolean.only_deleted.first.recover
    assert_equal 3, ParanoidBoolean.count

    assert_equal 1, ParanoidString.count
    ParanoidString.first.destroy
    assert_equal 0, ParanoidString.count
    ParanoidString.with_deleted.first.recover
    assert_equal 1, ParanoidString.count
  end

  def test_recovery!
    ParanoidBoolean.first.destroy
    ParanoidBoolean.create(name: "paranoid")

    assert_raise do
      ParanoidBoolean.only_deleted.first.recover!
    end
  end

  def test_recursive_recovery
    setup_recursive_tests

    @paranoid_time_object.destroy
    @paranoid_time_object.reload

    @paranoid_time_object.recover(recursive: true)

    assert_equal 3, ParanoidTime.count
    assert_equal 3, ParanoidHasManyDependant.count
    assert_equal 3, ParanoidBelongsDependant.count
    assert_equal @paranoid_boolean_count + 3, ParanoidBoolean.count
    assert_equal 3, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
  end

  def test_recursive_recovery_dependant_window
    setup_recursive_tests

    # Stop the following from recovering:
    #   - ParanoidHasManyDependant and its ParanoidBelongsDependant
    #   - A single ParanoidBelongsDependant, but not its parent
    Time.stub :now, 2.days.ago do
      @paranoid_time_object.paranoid_has_many_dependants.first.destroy
    end
    Time.stub :now, 1.hour.ago do
      @paranoid_time_object.paranoid_has_many_dependants
        .last.paranoid_belongs_dependant
        .destroy
    end
    @paranoid_time_object.destroy
    @paranoid_time_object.reload

    @paranoid_time_object.recover(recursive: true)

    assert_equal 3, ParanoidTime.count
    assert_equal 2, ParanoidHasManyDependant.count
    assert_equal 1, ParanoidBelongsDependant.count
    assert_equal @paranoid_boolean_count + 3, ParanoidBoolean.count
    assert_equal 3, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
  end

  def test_recursive_recovery_for_belongs_to_polymorphic
    child_1 = ParanoidAndroid.create
    section_1 = ParanoidSection.create(paranoid_thing: child_1)

    child_2 = ParanoidPolygon.create(sides: 3)
    section_2 = ParanoidSection.create(paranoid_thing: child_2)

    assert_equal section_1.paranoid_thing, child_1
    assert_equal section_1.paranoid_thing.class, ParanoidAndroid
    assert_equal section_2.paranoid_thing, child_2
    assert_equal section_2.paranoid_thing.class, ParanoidPolygon

    parent = ParanoidTime.create(name: "paranoid_parent")
    parent.paranoid_sections << section_1
    parent.paranoid_sections << section_2

    assert_equal 4, ParanoidTime.count
    assert_equal 2, ParanoidSection.count
    assert_equal 1, ParanoidAndroid.count
    assert_equal 1, ParanoidPolygon.count

    parent.destroy

    assert_equal 3, ParanoidTime.count
    assert_equal 0, ParanoidSection.count
    assert_equal 0, ParanoidAndroid.count
    assert_equal 0, ParanoidPolygon.count

    parent.reload
    parent.recover

    assert_equal 4, ParanoidTime.count
    assert_equal 2, ParanoidSection.count
    assert_equal 1, ParanoidAndroid.count
    assert_equal 1, ParanoidPolygon.count
  end

  def test_non_recursive_recovery
    setup_recursive_tests

    @paranoid_time_object.destroy
    @paranoid_time_object.reload

    @paranoid_time_object.recover(recursive: false)

    assert_equal 3, ParanoidTime.count
    assert_equal 0, ParanoidHasManyDependant.count
    assert_equal 0, ParanoidBelongsDependant.count
    assert_equal @paranoid_boolean_count, ParanoidBoolean.count
    assert_equal 0, ParanoidHasOneDependant.count
    assert_equal 1, NotParanoid.count
    assert_equal 0, HasOneNotParanoid.count
  end

  def test_recovery_callbacks
    @paranoid_with_callback = ParanoidWithCallback.first

    ParanoidWithCallback.transaction do
      @paranoid_with_callback.destroy

      assert_nil @paranoid_with_callback.called_before_recover
      assert_nil @paranoid_with_callback.called_after_recover

      @paranoid_with_callback.recover
    end

    assert @paranoid_with_callback.called_before_recover
    assert @paranoid_with_callback.called_after_recover
  end

  def test_recovery_callbacks_without_destroy
    @paranoid_with_callback = ParanoidWithCallback.first
    @paranoid_with_callback.recover

    assert_nil @paranoid_with_callback.called_before_recover
    assert_nil @paranoid_with_callback.called_after_recover
  end

  def test_boolean_type_with_no_nil_value_after_recover
    ps = ParanoidBooleanNotNullable.create!
    ps.destroy
    assert_equal 1, ParanoidBooleanNotNullable.only_deleted.where(id: ps).count

    ps.recover
    assert_equal 1, ParanoidBooleanNotNullable.where(id: ps).count
  end

  def test_boolean_type_with_no_nil_value_after_recover!
    ps = ParanoidBooleanNotNullable.create!
    ps.destroy
    assert_equal 1, ParanoidBooleanNotNullable.only_deleted.where(id: ps).count

    ps.recover!
    assert_equal 1, ParanoidBooleanNotNullable.where(id: ps).count
  end
end
