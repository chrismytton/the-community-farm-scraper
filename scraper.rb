require 'bundler/setup'
require 'nokogiri'
require 'date'
require 'digest'
require 'scraperwiki'
require 'json'

box_url = 'http://www.thecommunityfarm.co.uk/boxes/box_display.php'
html = ScraperWiki.scrape(box_url)
doc = Nokogiri.HTML(html)

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
  id.update(items.join("\n"))

  box_exists = begin
    ScraperWiki.select('* from data where id = ?', id.hexdigest).any?
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
    id: id.hexdigest,
    date: Date.today.iso8601,
    title: title,
    items: JSON.generate(items),
    created_at: DateTime.now.to_s
  )
end
