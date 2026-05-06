class CreateCompetitors < ActiveRecord::Migration[8.1]
  def change
    create_table :competitors, id: :uuid do |t|
      t.references :own_product, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :company_name, null: false
      t.string :website
      t.text :notes
      t.timestamps null: false
    end
  end
end
