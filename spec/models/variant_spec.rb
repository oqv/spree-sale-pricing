require 'spec_helper'

describe Spree::Variant do

  it 'can put a variant on a standard sale' do
    variant = create(:variant)
    expect(variant.on_sale?).to be false

    # Preço fixo
    variant.put_on_sale(10.95, {kind: 'fixedprice'})

    expect(variant.on_sale?).to be true
    expect(variant.original_price).to eql 19.99
    expect(variant.price).to eql 10.95

    # Desconto fixo
    variant.put_on_sale(5, {kind: 'fixeddiscount'})
    expect(variant.on_sale?).to be true
    expect(variant.price).to eql 14.99

  end

  it 'changes the price of all attached prices' do
    variant = create(:multi_price_variant)
    variant.put_on_sale(10.95, {kind: 'fixedprice'})
    expect(variant.prices.count).not_to eql 0

    # Preço fixo
    variant.prices.each do |p|
      expect(p.price).to eql BigDecimal.new(10.95, 4)
    end

    variant.put_on_sale(10, {kind: 'percentual'})
    # Porcentagem
    variant.prices.each do |p|
      expect(p.price).to eql 17.991
    end

  end

  it 'changes the price for each specific currency' do
    variant = create(:multi_price_variant, prices_count: 5)

    variant.prices.each do |p|
      variant.put_on_sale 10.95, { currencies: [ p.currency ], kind: 'fixedprice' }

      expect(variant.price_in(p.currency).price).to eq BigDecimal.new(10.95, 4)
      expect(variant.original_price_in(p.currency).price).to eql BigDecimal.new(19.99, 4)
    end
  end

  it 'changes the price for multiple currencies' do
    variant = create(:multi_price_variant, prices_count: 5)
    some_prices = variant.prices.sample(3)

    variant.put_on_sale(10.95, {
      currencies: some_prices.map(&:currency),
      kind: 'fixedprice'
    })

    some_prices.each do |p|
      expect(variant.price_in(p.currency).price).to be_within(0.01).of(10.95)
      expect(variant.original_price_in(p.currency).price).to eql BigDecimal.new(19.99, 4)
    end
  end

  it 'can set the original price to something different without changing the sale price' do
    variant = create(:multi_price_variant, prices_count: 5)
    variant.put_on_sale(10.95, {kind: 'fixedprice'})
    variant.prices.each do |p|
      p.original_price = 12.90
    end

    variant.prices.each do |p|
      expect(p.on_sale?).to be true
      expect(p.price).to eq BigDecimal.new(10.95, 4)
      expect(p.sale_price).to eq BigDecimal.new(10.95, 4)
      expect(p.original_price).to eq BigDecimal.new(12.90, 4)
    end
  end

  it 'is not on sale anymore if the original price is lower than the sale price' do
    variant = create(:multi_price_variant, prices_count: 5)
    variant.put_on_sale(10.95, {kind: 'fixedprice'})
    variant.prices.each do |p|
      p.original_price = 9.90
    end

    variant.prices.each do |p|
      expect(p.on_sale?).to be false
      expect(p.price).to eq BigDecimal.new(9.90, 4)
      expect(p.sale_price).to eq nil
      expect(p.original_price).to eq BigDecimal.new(9.90, 4)
    end
  end

  context 'with a valid sale' do

    before(:each) do
      @variant = create(:multi_price_variant, prices_count: 5)
      @variant.put_on_sale(10.95) # sale is started and enabled at this point for all currencies
    end

    it 'can stop and start a sale for all currencies' do
      @variant.stop_sale
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be false
      end

      @variant.start_sale
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end
    end

    it 'can disable and enable a sale for all currencies' do
      @variant.disable_sale
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be false
      end

      @variant.enable_sale
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end
    end

    it 'can stop and start a sale for specific currencies' do
      price_groups = @variant.prices.in_groups(2)
      @variant.stop_sale(price_groups.first.map(&:currency))

      price_groups.first.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be false
      end
      price_groups.second.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end

      @variant.start_sale(1.second.ago, price_groups.first.map(&:currency))
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end
    end

    it 'can disable and enable a sale for specific currencies' do
      price_groups = @variant.prices.in_groups(2)
      @variant.disable_sale(price_groups.first.map(&:currency))

      price_groups.first.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be false
      end
      price_groups.second.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end

      @variant.enable_sale(price_groups.first.map(&:currency))
      @variant.prices.each do |p|
        expect(@variant.on_sale_in?(p.currency)).to be true
      end
    end

  end

end
