namespace :import do
  desc "Import SEDI transactions from a CSV file. Usage: rake import:transactions FILE=path/to/file.csv"
  task transactions: :environment do
    file = ENV["FILE"]
    abort "Usage: rake import:transactions FILE=path/to/file.csv" if file.blank?
    abort "File not found: #{file}" unless File.exist?(file)

    puts "Importing transactions from #{file}..."
    result = TransactionImportService.new(file).call

    puts "Done. Inserted: #{result.inserted}, Skipped (duplicates): #{result.skipped}"
    if result.errors.any?
      puts "Errors (#{result.errors.size}):"
      result.errors.each { |e| puts "  Row #{e[:row]}: #{e[:message]}" }
    end
  end

  desc "Import issuer metadata from a CSV file. Usage: rake import:issuers FILE=path/to/file.csv"
  task issuers: :environment do
    file = ENV["FILE"]
    abort "Usage: rake import:issuers FILE=path/to/file.csv" if file.blank?
    abort "File not found: #{file}" unless File.exist?(file)

    puts "Importing issuers from #{file}..."
    result = IssuerImportService.new(file).call

    puts "Done. Created: #{result.created}, Updated: #{result.updated}"
    if result.errors.any?
      puts "Errors (#{result.errors.size}):"
      result.errors.each { |e| puts "  Row #{e[:row]}: #{e[:message]}" }
    end
  end
end
