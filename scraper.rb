# frozen_string_literal: true
require 'bundler/setup'
require 'nokogiri'
require 'date'
require 'digest'
require 'scraperwiki'
require 'json'
require 'open-uri'
require 'pry'
require 'dotenv'

Dotenv.load

def morph(sql, scraper = ENV['MORPH_SCRAPER'], api_key = ENV['MORPH_API_KEY'])
  url = URI::HTTPS.build(
    host: 'api.morph.io',
    path: "/#{scraper}/data.json",
    query: URI.encode_www_form(query: sql, key: api_key)
  )
  JSON.parse(url.open.read, symbolize_names: true)
end

class CommunityFarm
  class Box
    def initialize(noko:)
      @noko = noko
    end

    def id
      Digest::MD5.new.tap do |id|
        id.update(title)
        id.update(items.join("\n"))
      end.hexdigest
    end

    def title
      @title ||= noko.at_css('.lead').text.strip
    end

    def box_size
      @box_size ||= noko.at_css('option[selected]')&.text&.strip
    end

    def items
      @items ||= item_doc.css('li').map { |li| li.text.strip }
    end

    def to_s
      "#{title} #{box_size}".strip
    end

    private

    attr_reader :noko

    def item_doc
      @item_doc ||= Nokogiri::HTML(noko.at_css(item_selector)['data-content'])
    end

    def item_selector
      %([data-content*="This week's contents"])
    end
  end

  def initialize(html:)
    @html = html
  end

  def boxes
    noko.css('.panel').map { |p| Box.new(noko: p) }
  end

  private

  attr_reader :html

  def noko
    @noko ||= Nokogiri::HTML(html)
  end
end

# page = morph("select id, html from 'data' limit 1").first

html = open('https://chrismytton.github.io/the-community-farm-html/').read

cf = CommunityFarm.new(html: html)

cf.boxes.each do |box|
  puts "#{box.id} #{box}"
  ScraperWiki.save_sqlite(
    [:id],
    id: box.id,
    date: Date.today.iso8601,
    title: box.to_s,
    items: JSON.generate(box.items),
    created_at: DateTime.now.to_s
  )
end
