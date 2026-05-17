class CreateIssuers < ActiveRecord::Migration[8.0]
  def change
    create_table :issuers do |t|
      t.string :name,      null: false
      t.string :ticker
      t.string :sector
      t.string :home_page
      t.timestamps
    end
    add_index :issuers, :ticker, unique: true, where: "ticker IS NOT NULL"
  end
end
