require 'spec_helper'

describe MatryoshkaView do
  let(:world)               { MatryoshkaView.new(base: Place.table_name) }

  def geojson(name)
    TheGeomGeoJSON::EXAMPLES.fetch name
  end

  def place(name)
    place = Place.new
    place.save!
    place.the_geom_geojson = geojson(name)
    place.save!
    place
  end

  shared_examples 'OK' do
    it "just gives you back the base by default" do
      expect(world.from_sql).to eq('places')
    end

    it "doesn't auto-create anything" do
      expect(world.lookup(the_geom_geojson: geojson(:burlington_point))).to eq(world)
      expect(world.lookup(the_geom_geojson: geojson(:montpelier_point))).to eq(world)
    end

    it "helps you spawn inner views given geojson" do
      burlington # spawn it
      expect(MatryoshkaView.view_exists?(burlington.from_sql)).to be_truthy
    end

    it "lets you specify an name name" do
      world.spawn the_geom_geojson: geojson(:burlington), name: 'magic'
      expect(MatryoshkaView.view_exists?('magic')).to be_truthy
      ActiveRecord::Base.connection.execute 'DROP TABLE magic CASCADE'
    end

    describe "after spawning a matryoshka view" do
      before do
        burlington
      end

      it "tells you what view to use inside boundaries (inclusive)" do
        expect(world.lookup(the_geom_geojson: geojson(:burlington_point))).to eq(burlington)
      end

      it "falls back to original table outside boundaries" do
        expect(world.lookup(the_geom_geojson: geojson(:montreal_canada))).to eq(world)
      end

      xit "doesn't confuse bases" do
        # you can only use this with one base table
      end
    end

    describe "non-overlapping matryoshka views" do
      before do
        south_burlington
        burlington_downtown
      end

      it "chooses the right view" do
        expect(world.lookup(the_geom_geojson: geojson(:south_burlington_point))).to eq(south_burlington)
        expect(world.lookup(the_geom_geojson: geojson(:burlington_downtown_point))).to eq(burlington_downtown)
      end

      it "falls back to original table outside boundaries" do
        expect(world.lookup(the_geom_geojson: geojson(:montreal_canada))).to eq(world)
      end
    end

    describe "overlapping matryoshka views" do
      before do
        burlington
        south_burlington
      end

      it "chooses the smaller view" do
        expect(world.lookup(the_geom_geojson: geojson(:south_burlington_point))).to eq(south_burlington)
      end
    end

    describe "contents of matryoshka views" do
      it "has the same columns" do
        expect(ActiveRecord::Base.connection.columns(burlington.from_sql).map(&:name)).to match_array(ActiveRecord::Base.connection.columns(world.from_sql).map(&:name))
      end
    end

    describe "optimizing view creation" do
      # even if you tell a view it's based on nationwide, it should see if there is a smaller view that it can base itself on
    end
  end

  describe 'with the_geom_geojson' do
    let(:burlington)          { world.spawn the_geom_geojson: geojson(:burlington) }
    let(:south_burlington)    { world.spawn the_geom_geojson: geojson(:south_burlington) }
    let(:burlington_downtown) { world.spawn the_geom_geojson: geojson(:burlington_downtown) }

    it_behaves_like 'OK'
  end

  describe 'with geom_source' do
    let(:burlington)          { world.spawn geom_source: place(:burlington) }
    let(:south_burlington)    { world.spawn geom_source: place(:south_burlington) }
    let(:burlington_downtown) { world.spawn geom_source: place(:burlington_downtown) }

    it_behaves_like 'OK'
  end

  describe 'with the_geom' do
    let(:burlington)          { world.spawn geom_source: place(:burlington) }
    it "tells you what view to use inside boundaries (inclusive)" do
      burlington
      expect(world.lookup(geom_source: place(:burlington_point))).to eq(burlington)
    end

    it "falls back to original table outside boundaries" do
      burlington
      expect(world.lookup(geom_source: place(:montreal_canada))).to eq(world)
    end
  end

end
