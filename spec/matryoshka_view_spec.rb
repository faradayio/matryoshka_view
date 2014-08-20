require 'spec_helper'

describe MatryoshkaView do
  let(:world)               { MatryoshkaView.new(base: Place) }
  let(:burlington)          { world.spawn place(:burlington) }
  let(:south_burlington)    { world.spawn place(:south_burlington) }
  let(:downtown_burlington) { world.spawn place(:downtown_burlington) }

  def place(name)
    TheGeomGeoJSON::EXAMPLES.fetch name
  end

  it "just gives you back the base by default" do
    expect(world.from_sql).to eq('places')
  end

  it "doesn't auto-create anything" do
    expect(world.lookup(place(:burlington_point))).to eq(world)
    expect(world.lookup(place(:barre_point))).to eq(world)
  end

  it "helps you spawn inner views given geojson" do
    burlington # spawn it
    expect(MatryoshkaView.view_exists?(burlington.from_sql)).to be_truthy
  end

  describe "after spawning a matryoshka view" do
    before do
      burlington
    end

    it "tells you what view to use inside boundaries (inclusive)" do
      expect(world.lookup(place(:burlington_point))).to eq(burlington)
    end

    it "falls back to original table outside boundaries" do
      expect(world.lookup(place(:montreal))).to eq(world)
    end
  end

  describe "non-overlapping matryoshka views" do
    before do
      south_burlington
      downtown_burlington
    end

    it "chooses the right view" do
      expect(world.lookup(place(:south_burlington_point))).to eq(south_burlington)
      expect(world.lookup(place(:downtown_burlington_point))).to eq(downtown_burlington)
    end

    it "falls back to original table outside boundaries" do
      expect(world.lookup(place(:montreal))).to eq(world)
    end
  end

  describe "overlapping matryoshka views" do
    before do
      burlington
      south_burlington
    end

    it "chooses the smaller view" do
      expect(world.lookup(place(:south_burlington_point))).to eq(south_burlington)
    end
  end

  describe "contents of matryoshka views" do
    it "has the same columns" do
      expect(ActiveRecord::Base.connection.columns(burlington.from_sql).map(&:name)).to match_array(ActiveRecord::Base.connection.columns(world.from_sql).map(&:name))
    end
  end

end
