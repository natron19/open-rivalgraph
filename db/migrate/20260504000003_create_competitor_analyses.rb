class CreateCompetitorAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :competitor_analyses, id: :uuid do |t|
      t.references :competitor, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "pending"
      t.text :battlecard
      t.text :agent_trace
      t.text :gemini_raw
      t.text :error_message
      t.datetime :researched_at
      t.timestamps null: false
    end

    add_index :competitor_analyses, :status
    add_index :competitor_analyses, :created_at
  end
end
