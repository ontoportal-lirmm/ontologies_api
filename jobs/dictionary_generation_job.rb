module Jobs
  class DictionaryGenerationJob < Jobs::Base
    def perform(ptions = {})
      logger = Sidekiq.logger
      
      begin
        logger.info("Starting DictionaryGenerationJob (mgrep dictionary generation)...")
        annotator = Annotator::Models::NcboAnnotator.new
        # Using the logger if the method supports it, otherwise it will just use default logging
        if annotator.respond_to?(:generate_dictionary_file)
          annotator.generate_dictionary_file
        else
          logger.error("Annotator::Models::NcboAnnotator does not respond to generate_dictionary_file")
          raise "Method generate_dictionary_file not found on NcboAnnotator"
        end
        logger.info("Finished DictionaryGenerationJob successfully.")
      rescue Exception => e
        logger.error("Error in DictionaryGenerationJob: #{e.message}\n#{e.backtrace.join("\n")}")
        raise e
      end
    end
  end
end