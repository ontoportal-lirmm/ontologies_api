require 'sinatra/base'

module Sinatra
  module Helpers
    module PaginationHelper
      MAX_PAGE_SIZE = 5_000

      ##
      # Check the request params to get page and pagesize, both are returned
      def page_params(params=nil)
        params ||= @params
        page = params["page"]     || 1
        size = params["pagesize"] || 50
        begin
          page = Integer(page)
          size = Integer(size)
        rescue
          error 400, "Page number and page size must be integers. Page number is #{page} and page size is #{size}."
        end
        raise error 400, "Page size limit is #{MAX_PAGE_SIZE}. Page size in request is #{size}" if size > MAX_PAGE_SIZE
        return page, size
      end

      ##
      # Calculate the offset and limit based on page and pagesize, both are returned
      def offset_and_limit(page, pagesize)
        offset = page * pagesize - pagesize
        return offset, pagesize
      end

      ##
      # Return a page object given the total potential results for a call and an array
      def page_object(array, total_result_count = 0)
        page, size = page_params
        LinkedData::Models::Page.new(page, size, total_result_count, array)
      end
      
      def empty_page
        page_object([], 0)        
      end

      def hydra_page_object(array, total_result_count = 0)
        page, size = page_params
        LinkedData::Models::HydraPage.new(page, size, total_result_count, array)
      end

      def hydra_empty_page
        hydra_page_object([], 0)
      end
      
      
    end
  end
end

helpers Sinatra::Helpers::PaginationHelper
