if Transaction.count.zero?
  csv_path = Rails.root.join("db", "seeds", "sedi_2025_01_1.csv")
  result = TransactionImportService.new(csv_path).call
  puts "Seed: #{result.inserted} inserted, #{result.skipped} skipped" +
       (result.errors.any? ? ", #{result.errors.size} errors" : "")
else
  puts "Seed: #{Transaction.count} transactions already present, skipping."
end
