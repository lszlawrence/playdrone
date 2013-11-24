module Stack
  # Each step in a stack must be idempotent, so the chain can fail at any point,
  # and we can retry the whole thing.
  def self.common_stack
    ::Middleware::Builder.new do
      use IndexAppAfter
        use FetchMarketDetails
          use CacheApkResults
            use DownloadApk
            use DecompileApk
            use IndexSources
            use FindTokens
            use LookForNativeLibraries
            use LookForObfuscatedCode
            use FetchDevSignature
            use FindLibraries
            # use Signature
    end
  end

  def self.reprocess_app(options={})
    raise "missing app_id" unless options[:app_id]

    @create_app_stack ||= ::Middleware::Builder.new do
      use LockApp
        use PrepareFS
          use ForEachDate
            use Stack.common_stack
    end
    @create_app_stack.call(options.dup)
  end

  def self.process_app(options={})
    raise "missing app_id"     unless options[:app_id]
    raise "missing crawled_at" unless options[:crawled_at]
    # can pass :reprocess => branch to reprocess that branch
    # do not use unless you know what you are doing.

    @create_app_stack ||= ::Middleware::Builder.new do
      use LockApp
        use DeleteMissingApp
          use PrepareFS
            use Stack.common_stack
    end
    @create_app_stack.call(options.dup)
  end

  def self.purge_branch(options={})
    raise "missing app_id"       unless options[:app_id]
    raise "missing purge_branch" unless options[:purge_branch]

    @clean_branch_stack ||= ::Middleware::Builder.new do
      use LockApp
        use PrepareFS
          use PurgeBranch
    end
    @clean_branch_stack.call(options.dup)
  end

  class << self
    extend StatsD::Instrument
    statsd_count   :reprocess_app,    'stack.reprocess_app'
    statsd_measure :reprocess_app,    'stack.reprocess_app'
    statsd_count   :process_app,      'stack.process_app'
    statsd_measure :process_app,      'stack.process_app'
    statsd_count   :purge_branch,     'stack.purge_branch'
    statsd_measure :purge_branch,     'stack.purge_branch'
  end
end
