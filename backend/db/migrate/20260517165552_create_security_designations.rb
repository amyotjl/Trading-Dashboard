class CreateSecurityDesignations < ActiveRecord::Migration[8.0]
  def change
    create_table :security_designations do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :security_designations, :name, unique: true
  end
end
