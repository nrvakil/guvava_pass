# app/models/booking.rb
class Booking < ActiveRecord::Base
  MAX_LIMIT = 3

  belongs_to :user
  belongs_to :lesson
end

# app/services/booking/creation.rb
module Booking
  # creation service for booking
  class Creation
    def initalize(params = {})
      @params = params
      @user_id = params[:user_id]
      @gym_id = gym.id
    end

    attr_reader :params, :booking

    def init
      validate_booking_limit

      Booking.transaction do
        create_booking
        @booking_tracker.add_booking
      end

      booking
    end

    private

    def gym
      Lession.find! params[:lesson_id]
    end

    def validate_booking_limit
      Booking::LimitValidator.new(booking_tracker).validate
    end

    def booking_tracker
      @booking_tracker = Booking::Tracker.new @user_id, @gym_id
    end

    def create_booking
      @booking = Booking.create! params
    end
  end
end

# app/services/booking/limit_validator.rb
module Booking
  # Validator on booking limit
  class LimitValidator
    def initialize(booking_tracker)
      @booking_tracker = booking_tracker
    end

    attr_reader :booking_tracker

    def validate
      raise_exceded_booking_limit if booking_limit_exceded?
    end

    private

    def booking_limit_exceded?
      booking_count >= Booking::MAX_LIMIT
    end

    def booking_count
      booking_tracker.count
    end

    def raise_exceded_booking_limit
      raise Exceptions::BookingLimitExceeded
    end
  end
end

# app/services/booking/tracker.rb
module Booking
  # interface to BookingTracking
  class Tracker
    def initialize(user_id, gym_id)
      @user_id = user_id
      @gym_id = gym_id
      @record = fetch_tracking_record
    end

    attr_reader :user_id, :gym_id, :record

    def booking_count
      record ? record.count : 0
    end

    def add_booking
      if record
        record.update_attributes! count: record.count + 1
      else
        create_booking_tracking
      end
    end

    def remove_booking
      record.update_attributes! count: record.count - 1
    end

    private

    def fetch_tracking_record
      BookingTracking.find_by user_id: user_id, gym_id: gym_id
    end

    def create_booking_tracking
      @record = BookingTracking.create! user_id: user_id, gym_id: gym_id
    end
  end
end

# app/services/booking/cancellation.rb
module Booking
  # Cancellation service
  class Cancellation
    def initialize(booking)
      @booking = booking
    end

    attr_reader :booking

    def init
      return false if cancelled?

      Booking.transaction do
        cancel_booking
        booking_tracker.remove_booking
      end

      true
    end

    private

    def cancelled?
      booking.cancelled
    end

    def cancel_booking
      booking.update_attributes! cancelled: true
    end

    def booking_tracker
      Booking::Tracker.new booking.user_id, booking.lesson.gym_id
    end
  end
end

# app/controllers/bookings_controller.rb
class BookingsController < ApplicationController
  def create
    @booking = Booking::Creation.new(creation_params).init
    redirect_to show_booking_path(@booking)
  rescue Exceptions::BookingLimitExceeded
    flash.now[:alert] = 'Booking limit exceeded'
    render :new
  end

  private

  def creation_params
    permited_params.merge user_id: @user.id
  end

  def permited_params
    params.require(:booking).permit(:lesson_id)
  end
end
