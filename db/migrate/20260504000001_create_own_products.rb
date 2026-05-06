class CreateOwnProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :own_products, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :differentiator_1, null: false
      t.string :differentiator_2, null: false
      t.string :differentiator_3, null: false
      t.timestamps null: false
    end
  end
end
