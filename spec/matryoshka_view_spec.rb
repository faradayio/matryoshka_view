require 'spec_helper'

describe MatryoshkaView do
  let(:outer) { MatryoshkaView.new(:numbers) }

  it "just gives you back the original table name by default" do
    expect(outer.name).to eq('numbers')
  end

  it "doesn't auto-create anything" do
    expect(outer.find(x: 1)).to eq(outer)
    expect(outer.find(x: 10)).to eq(outer)
  end

  it "helps you spawn inner views" do
    inner = outer.spawn conditions: { x: [1,2] }
    expect(ActiveRecord::Base.connection.table_exists?(inner.name)).to be_truthy
  end

  it "lets you name inner views as you spawn them" do
    inner = outer.spawn conditions: { x: [1,2] }, name: 'magic'
    expect(inner.name).to eq('magic')
  end

  describe "after spawning a matryoshka view" do
    let(:inner) { outer.spawn conditions: { x: [1,2] } }

    it "tells you what view to use inside boundaries (inclusive)" do
      expect(outer.find(x: 1)).to eq(inner)
      expect(outer.find(x: 2)).to eq(inner)
    end

    it "falls back to original table outside boundaries" do
      expect(outer.find(x: 0)).to eq(inner)
      expect(outer.find(x: 3)).to eq(inner)
    end
  end

  describe "non-overlapping matryoshka views" do
    let(:one_to_ten)       { outer.spawn conditions: { x: [ 1,10] } }
    let(:eleven_to_twenty) { outer.spawn conditions: { x: [11,20] } }

    it "chooses the right view" do
      expect(outer.find(x: 1)).to eq(one_to_ten)
      expect(outer.find(x: 11)).to eq(eleven_to_twenty)
    end

    it "falls back to original table outside boundaries" do
      expect(outer.find(x: 0)).to eq(outer)
      expect(outer.find(x: 21)).to eq(outer)
    end
  end

  describe "overlapping matryoshka views" do
    let(:one_to_ten)     { outer.spawn conditions: { x: [ 1,10] } }
    let(:one_to_twenty)  { outer.spawn conditions: { x: [ 1,20] } }
    let(:ten_to_twenty)  { outer.spawn conditions: { x: [10,20] } }

    it "chooses the smaller view" do
      expect(outer.find(x: 1)).to eq(one_to_ten)
      expect(outer.find(x: 11)).to eq(ten_to_twenty)
    end
  end

  describe "contents of matryoshka views" do
    let(:inner) { outer.spawn conditions: { x: [-Float::Infinity, Float::Infinity] } }

    it "has the same columns" do
      expect(ActiveRecord::Base.connection.column_names(inner.name)).to match_array(ActiveRecord::Base.connection.column_names(outer.name))
    end
  end

end
