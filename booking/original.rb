class Booking  < ActiveRecord::Base

  belongs_to :user
  belongs_to :lesson

  before_create :validate_booking_limit
  after_create :update_booking_tracking

  def cancel
    return false if self.cancelled = true

    self.update(cancelled: true)

    # Users can only book classes at a given gym a limited number of times a month.
    # BookingTracking is used to track how many times a user books into each gym.
    tracking = BookingTracking.find(:all, :conditions=> ["user_id = ? AND gym_id = ?]", self.user.id, self.lesson.gym.id], limit: 1).first

    if tracking.present?
      if tracking.count > 0
        tracking.update(count: tracking.count - 1)
      end
    end
  end

  def update_booking_tracking
    tracking = BookingTracking.find(:all, :conditions=> ["user_id = ? AND gym_id = ?]", self.user.id, self.lesson.gym.id], limit: 1).first

    if tracking == nil
      tracking = BookingTracking.create(user: self.user, gym: self.lesson.gym, count: 1)
    else
      tracking.update(count: tracking.count + 1)
    end
  end

  def validate_booking_limit
    tracking = BookingTracking.find(:all, :conditions=> ["user_id = ? AND gym_id = ?]", self.user.id, self.lesson.gym.id], limit: 1).first

    # Max number of bookings at a given gym
    magicNumber=3

    if tracking != nil && tracking.count >= magicNumber
      raise BookingLimitExceeded.new
    end
  end

end



# app/controllers/booking_controller.rb
class BookingsController < ApplicationController

  def create
    @booking = @user.bookings.create(permited_params)
    redirect_to show_booking_path(@booking)
  rescue BookingLimitExceeded.new
    flash.now[:alert] = "Booking limit exceeded"
    render :new
  end

  private

  def permited_params
    params.require(:booking).permit(:lesson_id)
  end

end
