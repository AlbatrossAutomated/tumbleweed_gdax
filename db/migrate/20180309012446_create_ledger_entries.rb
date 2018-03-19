class CreateLedgerEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :ledger_entries do |t|
      t.decimal :amount, null: false
      t.string :category, null: false
      t.string :description, null: false

      t.timestamps null: false
    end
  end
end
