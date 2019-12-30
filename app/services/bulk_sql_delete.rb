class BulkSqlDelete
  attr_accessor :connection

  def delete_in_batches(sql)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      perform_and_log(sql) do
        unless Rails.env.test?
          connection.begin_db_transaction
        end
        result = connection.exec_delete(sql)
        connection.commit_db_transaction unless Rails.env.test?

        result
      end
    end
  end

  private

  def perform_and_log(delete_sql)
    deleted = 0

    loop do
      result = 0

      duration = Benchmark.realtime do
        result = yield
      end

      log_deletion_batch(delete_sql, result, duration)

      deleted += result

      break if result.zero?
    end

    deleted
  rescue StandardError => e
    log_deletion_error(delete_sql, e)
    raise e
  end

  def log_deletion_batch(statement, count, duration)
    Rails.logger.info(
      tag: "notification_delete",
      statement: statement,
      rows_deleted: count,
      duration: duration,
    )
  end

  def log_deletion_error(statement, exception)
    Rails.logger.error(
      tag: "notification_delete",
      statement: statement,
      exception_message: exception.message,
      backtrace: exception.backtrace.join("\n"),
    )
  end
end
