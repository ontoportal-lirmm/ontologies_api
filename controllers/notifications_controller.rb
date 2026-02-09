class NotificationsController < ApplicationController
  namespace "/notifications" do
    ##
    # Display notifications for the current user
    # Optional parameter: seen=true|false to filter by দেখা status
    get do
      user = current_user
      error 401, "You must be logged in to retrieve notifications" if user.username.nil?

      notifications = Notification.for_target(user.username.to_s)
      
      if params["seen"] == "true"
        notifications = notifications.seen
      elsif params["seen"] == "false"
        notifications = notifications.unseen
      end

      # Order by most recent first
      notifications = notifications.order(created_at: :desc)
      
      page, size = page_params
      size = 10 if params["pagesize"].nil?
      offset, limit = offset_and_limit(page, size)
      
      total_count = notifications.count
      notifications_page = notifications.offset(offset).limit(limit).to_a
      
      # Mark returned notifications as seen
      unseen_ids = notifications_page.select { |n| !n.seen? }.map(&:id)
      Notification.where(id: unseen_ids).update_all(seen_at: Time.now) if unseen_ids.any?
      
      page_object(notifications_page, total_count).to_json
    end

    # Check if the current user has unseen notifications
    get "/status" do
      user = current_user
      error 401, "You must be logged in to check notifications" if user.username.nil?

      unseen_count = Notification.for_target(user.username.to_s).unseen.count
      { has_unseen: unseen_count > 0, count: unseen_count }.to_json
    end

    ##
    # Mark a notification as seen
    patch "/:id/seen" do
      user = current_user
      error 401, "You must be logged in to update notifications" if user.username.nil?

      notification = Notification.find_by(id: params[:id], target: user.username.to_s)
      error 404, "Notification not found" if notification.nil?

      notification.mark_as_seen!
      halt 204
    end
  end
end
