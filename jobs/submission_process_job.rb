require 'logger'

class SubmissionProcessJob < LinkedData::Jobs::Base
  sidekiq_options queue: 'submissions'

  PROCESS_ACTIONS = {
    process_rdf: true,
    generate_labels: true,
    extract_metadata: true,
    index_all_data: true,
    index_search: true,
    index_properties: true,
    run_metrics: true,
    process_annotator: true,
    diff: true,
    remote_pull: false
  }.freeze

  def perform(options = {})
    submission_id = options["submission_id"]
    actions = normalize_actions(options["actions"] || { "all" => true })

    logger = Sidekiq.logger
    multi_logger = LinkedData::Utils::MultiLogger.new(loggers: logger)
    t0 = Time.now

    # Handle remote_pull action: pull the ontology and get a new submission
    if actions[:remote_pull]
      acronym = acronym_from_submission_id(submission_id)
      new_submission = do_remote_pull(acronym, logger)
      return unless new_submission

      submission_id = new_submission.id.to_s
      actions.delete(:remote_pull)
    end

    sub = LinkedData::Models::OntologySubmission.find(RDF::IRI.new(submission_id)).first

    unless sub
      multi_logger.error "Submission #{submission_id} is not in the system. Processing cancelled..."
      return
    end

    sub.bring_remaining
    sub.ontology.bring(:acronym)
    FileUtils.mkdir_p(sub.data_folder) unless Dir.exist?(sub.data_folder)

    log_path = sub.parsing_log_path
    logger.info "Logging parsing output to #{log_path}"
    file_logger = Logger.new(log_path)
    multi_logger.add_logger(file_logger)
    multi_logger.info "Starting to process #{submission_id}"

    # Check to make sure the file has been downloaded
    if sub.pullLocation && (!sub.uploadFilePath || !File.exist?(sub.uploadFilePath))
      multi_logger.debug "Pull location found (#{sub.pullLocation}), but no file in the upload file path (#{sub.uploadFilePath}). Retrying download."
      file, filename = sub.download_ontology_file
      file_location = sub.class.copy_file_repository(sub.ontology.acronym, sub.submissionId, file, filename)
      file_location = "../" + file_location if file_location.start_with?(".") # relative path fix
      sub.uploadFilePath = File.expand_path(file_location, __FILE__)
      sub.save
      multi_logger.debug "Download complete"
    end

    sub.process_submission(multi_logger, actions)
    parsed = sub.ready?(status: [:rdf, :rdf_labels])

    if parsed
      archive_old_submissions(multi_logger, sub) if actions[:process_rdf]
      process_annotator(multi_logger, sub) if actions[:process_annotator]
      multi_logger.debug "Completed processing of #{submission_id} in #{(Time.now - t0).to_f.round(2)}s"
    else
      multi_logger.error "Submission #{submission_id} parsing failed"
    end

    NcboCron::Models::OntologiesReport.new(multi_logger).refresh_report([sub.ontology.acronym])

    Notifier.notify_submission_processed(sub)
  end

  private

  # Normalize action flags from the options hash.
  # If `all: true`, use the full set of default actions.
  # Otherwise, filter to only recognized action keys.
  def normalize_actions(raw_actions)
    actions = raw_actions.transform_keys(&:to_sym)

    if actions[:all]
      PROCESS_ACTIONS.dup
    else
      actions.select { |k, _| PROCESS_ACTIONS.key?(k) }
    end
  end

  def acronym_from_submission_id(submission_id)
    submission_id.to_s.split("/")[-3]
  end

  def do_remote_pull(acronym, logger)
    NcboCron::Helpers::OntologyHelper.do_ontology_pull(
      acronym,
      enable_pull_umls: false,
      umls_download_url: '',
      logger: logger,
      add_to_queue: false
    )
  end

  def archive_old_submissions(logger, sub)
    logger.debug "Archiving submissions previous to #{sub.id.to_s}..."
    submissions = LinkedData::Models::OntologySubmission
                    .where(ontology: sub.ontology)
                    .include(:submissionId)
                    .include(:submissionStatus)
                    .all

    recent_submissions = submissions.sort { |a, b| b.submissionId <=> a.submissionId }[0..10]
    options = { process_rdf: false, index_search: false, index_commit: false,
                run_metrics: false, reasoning: false, archive: true }

    recent_submissions.each do |old_sub|
      next if old_sub.id.to_s == sub.id.to_s
      next if sub.submissionId < old_sub.submissionId
      old_sub.process_submission(logger, options) unless old_sub.archived?
    end
    logger.debug "Completed archiving submissions previous to #{sub.id.to_s}"
  end

  def process_annotator(logger, sub)
    parsed = sub.ready?(status: [:rdf, :rdf_labels])

    if parsed
      begin
        annotator = Annotator::Models::NcboAnnotator.new
        annotator.create_term_cache_for_submission(logger, sub)
        annotator.generate_dictionary_file() unless NcboCron.settings.enable_dictionary_generation_cron_job
      rescue Exception => e
        logger.error(e.message + "\n" + e.backtrace.join("\n\t"))
        logger.flush() if logger.respond_to?(:flush)
      end
    else
      logger.error "Annotator entries cannot be generated on the submission #{sub.id.to_s} because it has not been successfully parsed"
    end
  end
end