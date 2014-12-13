require 'nokogiri'
require 'date'
require 'digest'
require 'scraperwiki'
require 'json'

ScraperWiki.config = { db: 'data.sqlite', default_table_name: 'data' }

box_url = 'http://www.thecommunityfarm.co.uk/boxes/box_display.php'
html = ScraperWiki.scrape(box_url)
doc = Nokogiri.HTML(html)
box_date = (Date.today - Date.today.wday + 1).iso8601

doc.css('.panel').each do |panel|
  title = panel.at_css('.lead').text.strip
  box_size = panel.at_css('option[selected]')
  box_size && title += " #{box_size.text.strip}"
  item_selector = %([data-content*="This week's contents"])
  item_html = panel.at_css(item_selector)['data-content']
  item_doc = Nokogiri.HTML(item_html)
  items = item_doc.css('li').map { |li| li.text.strip }

  id = Digest::MD5.new
  id.update(title)
  id.update(box_date)
  id.update(items.join("\n"))

  box_exists = begin
    ScraperWiki.select('* from data where id = ?', id.to_s).any?
  rescue
    false
  end

  if box_exists
    puts "Existing box found, skipping #{id} #{title}"
    next
  end

  puts "Creating new entry for #{id} #{title}"
  ScraperWiki.save_sqlite(
    [:id],
    id: id.to_s,
    date: box_date,
    title: title,
    items: JSON.generate(items),
    created_at: DateTime.now.to_s
  )
end
