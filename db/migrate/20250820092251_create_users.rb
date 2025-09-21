class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :email1, index: true
      t.string :email2
      t.string :name1, index: true
      t.string :name2
      t.boolean :sex1, index: true
      t.boolean :sex2
      t.integer :age1, index: true
      t.integer :age2

      t.timestamps
    end
  end
end
