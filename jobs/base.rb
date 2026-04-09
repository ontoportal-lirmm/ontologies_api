module Jobs
  class Base < LinkedData::Jobs::Base
    include Sinatra::Helpers::ApplicationHelper
  end
end
