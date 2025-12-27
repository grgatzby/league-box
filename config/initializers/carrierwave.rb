CarrierWave.configure do |config|
  config.cache_storage = :file
  config.cache_dir = "#{Rails.root}/tmp/uploads"
end
