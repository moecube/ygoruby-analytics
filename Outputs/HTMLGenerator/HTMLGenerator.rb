require 'nokogiri'
require 'json'
require "#{File.dirname __FILE__}/../Config.rb"
require "#{File.dirname __FILE__}/../RecordUnzipper/Card.rb"

module HTMLGenerator
	def self.generate
		data     = self.load_data
		document = self.load_html
		names    = $config["SingleCardAnalyzer"]["OutputName"]
		self.generate_pack document, data[names["Day"]], "Day"
		self.generate_pack document, data[names["Week"]], "Week"
		self.generate_pack document, data[names["Month"]], "Month"
		self.generate_pack document, data[names["Season"]], "Season"
		self.set_time document, data[names["Time"]]
		self.set_title document
		self.save_html document.to_html
	end

	def self.load_html
		html_source = $config["Generator"]["inputName"]
		file        = File.open(html_source)
		document    = Nokogiri::HTML file
		file.close
		document
	end

	def self.load_data
		data_source = $config["Generator"]["dataName"]
		file        = File.open(data_source).read
		JSON.parse file
	end

	def self.save_html(html)
		html_target = $config["Generator"]["outputName"]
		File.open(html_target, "w") { |f| f.write html }
	end

	def self.generate_pack(document, data, key)
		config_key = key.downcase + "TableName"
		class_name = $config["Generator"][config_key]
		return if class_name == nil
		css  = "table .#{class_name}"
		node = document.at_css css
		return if node == nil
		node.replace create_table data, document
	end

	def self.create_table(data, document)
		table = Nokogiri::XML::Node.new "tbody", document
		data.each_with_index { |stat, index| table.add_child self.create_row index + 1, stat, document }
		table
	end

	def self.create_row(order, card_stat, document)
		node   = Nokogiri::XML::Node.new "tr", document
		cardID = card_stat[0]
		card   = Card[cardID]
		self.create_cell node, order.to_s
		if card == nil
			self.create_cell node, self.create_card_image(cardID, document)
			self.create_cell node, "神秘卡片[#{cardID}]"
			self.create_cell node, "神秘类别"
		else
			self.create_cell node, self.create_card_image(card, document)
			self.create_cell node, card.name
			self.create_cell node, card.main_type_desc
		end
		self.create_cell node, card_stat[1].to_s
		self.create_cell node, card_stat[3].to_s
		self.create_cell node, card_stat[4].to_s
		self.create_cell node, card_stat[5].to_s
		node
	end

	def self.create_cell(parent, content)
		node = Nokogiri::XML::Node.new "td", parent.document
		if content.is_a? String
			node.content = content
		elsif content.is_a? Nokogiri::XML::Element
			node.add_child content
		end
		parent.add_child node
		node
	end

	def self.create_card_image(card, document)
		node = Nokogiri::XML::Node.new "img", document
		if card.is_a? Card
			node['alt'] = card.name
			node['src'] = sprintf($config['Generator']['imagePath'], card.id)
		elsif card.is_a? Integer
			node['src'] = sprintf($config['Generator']['imagePath'], card)
		end
		node
	end

	def self.set_time(document, time)
		time              = Time.at(time) if time.is_a? Integer
		time              = Time.now if time == nil
		day_css_name      = $config["Generator"]["dayLabelName"]
		week_css_name     = $config["Generator"]["weekLabelName"]
		day_css_key       = "small.#{day_css_name}"
		week_css_key      = "small.#{week_css_name}"
		day_node          = document.at_css day_css_key
		day_node.content  = time.strftime "%Y-%m-%d" if day_node != nil
		week_node         = document.at_css week_css_key
		week_node.content = time.strftime "%Y-%U" if week_node != nil
	end

	def self.set_title(document)
		title   = $config["Generator"]["title"]
		css_key = "head title"
		node    = document.at_css css_key
		return if node == nil
		node.content = title
	end
end
