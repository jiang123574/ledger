# frozen_string_literal: true

require "rails_helper"

RSpec.describe TailwindConfigHelper, type: :helper do
  describe ".theme_extensions" do
    let(:extensions) { TailwindConfigHelper.theme_extensions }

    it "returns a hash" do
      expect(extensions).to be_a(Hash)
    end

    describe "fontFamily" do
      it "defines sans font stack" do
        expect(extensions[:fontFamily][:sans]).to include("Geist", "system-ui")
      end

      it "defines mono font stack" do
        expect(extensions[:fontFamily][:mono]).to include("Geist Mono", "ui-monospace")
      end
    end

    describe "colors" do
      describe "surface" do
        it "has DEFAULT color" do
          expect(extensions[:colors][:surface][:DEFAULT]).to eq("#f8f9fa")
        end

        it "has hover color" do
          expect(extensions[:colors][:surface][:hover]).to eq("#f1f3f5")
        end

        it "has inset color" do
          expect(extensions[:colors][:surface][:inset]).to eq("#e9ecef")
        end

        it "has dark variants" do
          expect(extensions[:colors][:surface][:dark]).to eq("#1a1a1a")
          expect(extensions[:colors][:'surface'][:'dark-hover']).to eq("#262626")
          expect(extensions[:colors][:'surface'][:'dark-inset']).to eq("#262626")
        end
      end

      describe "container" do
        it "has all required colors" do
          container = extensions[:colors][:container]
          expect(container[:DEFAULT]).to eq("#ffffff")
          expect(container[:inset]).to eq("#f8f9fa")
          expect(container[:dark]).to eq("#262626")
          expect(container[:'dark-inset']).to eq("#1a1a1a")
        end
      end

      describe "primary" do
        it "has light and dark variants" do
          primary = extensions[:colors][:primary]
          expect(primary[:DEFAULT]).to eq("#1a1a1a")
          expect(primary[:hover]).to eq("#333333")
          expect(primary[:dark]).to eq("#f8f9fa")
          expect(primary[:'dark-hover']).to eq("#e9ecef")
        end
      end

      describe "secondary" do
        it "has all variants" do
          secondary = extensions[:colors][:secondary]
          expect(secondary[:DEFAULT]).to eq("#6c757d")
          expect(secondary[:hover]).to eq("#495057")
          expect(secondary[:dark]).to eq("#9ca3af")
          expect(secondary[:'dark-hover']).to eq("#d1d5db")
        end
      end

      describe "border" do
        it "has all border colors" do
          border = extensions[:colors][:border]
          expect(border[:DEFAULT]).to eq("#dee2e6")
          expect(border[:secondary]).to eq("#e9ecef")
          expect(border[:dark]).to eq("#404040")
          expect(border[:'dark-secondary']).to eq("#333333")
        end
      end

      describe "inverse" do
        it "has all variants" do
          inverse = extensions[:colors][:inverse]
          expect(inverse[:DEFAULT]).to eq("#1a1a1a")
          expect(inverse[:hover]).to eq("#333333")
          expect(inverse[:dark]).to eq("#f8f9fa")
          expect(inverse[:'dark-hover']).to eq("#e9ecef")
        end
      end

      describe "income" do
        it "has CSS variable references" do
          income = extensions[:colors][:income]
          expect(income[:DEFAULT]).to include("var(--color-income")
          expect(income[:soft]).to include("rgba")
          expect(income[:light]).to include("rgba")
        end
      end

      describe "expense" do
        it "has CSS variable references" do
          expense = extensions[:colors][:expense]
          expect(expense[:DEFAULT]).to include("var(--color-expense")
          expect(expense[:soft]).to include("rgba")
          expect(expense[:light]).to include("rgba")
        end
      end

      describe "transfer" do
        it "has a color value" do
          expect(extensions[:colors][:transfer]).to eq("#3b82f6")
        end
      end
    end
  end
end
