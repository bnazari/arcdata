class Scheduler::FlexSchedule < ActiveRecord::Base
  belongs_to :person, foreign_key: 'id', class_name: 'Roster::Person'

  scope :for_county, lambda {|county_ids| 
    joins{person.county_memberships}.where{person.county_memberships.county_id.in my{county_ids}}
  }

  scope :with_availability, lambda {
    where{
      Scheduler::FlexSchedule.available_columns.map{|c|__send__(c) == true}.reduce(&:|)
    }
  }

  scope :available_at, lambda { |day, shift|
    where("available_#{day}_#{shift}" => true)
  }

  def self.by_distance_from inc
    joins{person}.order{_(person.lat.op(:-, inc.lat)).op('^', 2).op(:+, _(person.lng.op(:-, inc.lng)).op('^', 2))}
  end

  def available(day, shift)
    self.send "available_#{day}_#{shift}".to_sym
  end

  def num_shifts
    shifts = 0
    self.class.days.each do |day|
      self.class.shifts.each do |shift|
        shifts = shifts+1 if available(day, shift)
      end
    end
    shifts
  end

  def self.days; %w(sunday monday tuesday wednesday thursday friday saturday); end
  def self.shifts; %w(day night); end
  def self.available_columns
    self.days.map do |day|
      self.shifts.map do |shift|
        "available_#{day}_#{shift}"
      end
    end.flatten
  end
end
