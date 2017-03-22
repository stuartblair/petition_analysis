#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'forwardable'
require 'net/http'
require 'uri'

class Country 
  attr_reader :name, :signature_count, :code

  def initialize(name, signature_count, code)
    @name = name
    @signature_count = signature_count
    @code = code
  end
end

class Constituency
  attr_reader :name, :ons_code, :mp, :signature_count

  def initialize(name, ons_code, mp, signature_count)
    @name = name
    @ons_code = ons_code
    @mp = mp
    @signature_count = signature_count
  end
end

class Countries
  include Enumerable
  extend Forwardable

  attr_reader :countries 
  def_delegators :@countries, :each, :name, :[], :size, :<<, :map, :reduce

  def initialize
    @countries = []
  end

  def from_rest_of_world
    reject {|country| country.name == "United Kingdom"}
  end
end

class Constituencies
  include Enumerable
  extend Forwardable

  attr_reader :constituencies 
  def_delegators :@constituencies, :each, :name, :[], :size, :<<, :map, :reduce

  def initialize
    @constituencies = []
  end

  @@scottish_constituency_names = [
    "Na h-Eileanan an Iar",
    "Orkney and Shetland",
    "Dundee West",
    "Glenrothes",
    "Caithness, Sutherland and Easter Ross",
    "Glasgow North East",
    "Edinburgh East",
    "Ross, Skye and Lochaber",
    "Glasgow North",
    "Dundee East",
    "Aberdeen North",
    "Glasgow Central",
    "Kirkcaldy and Cowdenbeath",
    "Midlothian",
    "Angus",
    "Paisley and Renfrewshire South",
    "West Dunbartonshire",
    "Glasgow South",
    "Kilmarnock and Loudoun",
    "Inverclyde",
    "Motherwell and Wishaw",
    "Glasgow South West",
    "Cumbernauld, Kilsyth and Kirkintilloch East",
    "Glasgow North West",
    "Coatbridge, Chryston and Bellshill",
    "Glasgow East",
    "North East Fife",
    "Dumfries and Galloway",
    "Dumfriesshire, Clydesdale and Tweeddale",
    "Berwickshire, Roxburgh and Selkirk",
    "Inverness, Nairn, Badenoch and Strathspey",
    "North Ayrshire and Arran",
    "Airdrie and Shotts",
    "Moray",
    "Dunfermline and West Fife",
    "Perth and North Perthshire",
    "Banff and Buchan",
    "Falkirk",
    "Ayr, Carrick and Cumnock",
    "Central Ayrshire",
    "Stirling",
    "Edinburgh South West",
    "Edinburgh South",
    "Argyll and Bute",
    "Livingston",
    "Aberdeen South",
    "East Lothian",
    "Lanark and Hamilton East",
    "Paisley and Renfrewshire North",
    "East Kilbride, Strathaven and Lesmahagow",
    "Rutherglen and Hamilton West",
    "Ochil and South Perthshire",
    "Gordon",
    "West Aberdeenshire and Kincardine",
    "East Dunbartonshire",
    "Linlithgow and East Falkirk",
    "Edinburgh West",
    "East Renfrewshire",
    "Edinburgh North and Leith"
  ]

 def in_scotland
    select {|constituency| @@scottish_constituency_names.include?(constituency.name)}
  end

  def in_ruk
    reject {|constituency| @@scottish_constituency_names.include?(constituency.name)}
  end
end

class Report
  attr_reader :countries, :constituencies

  def initialize(countries, constituencies)
    @countries = countries
    @constituencies = constituencies
  end

  def scottish_constituency_signature_count
    @constituencies.in_scotland.reduce(0) {|sum, constituency| sum + constituency.signature_count}
  end

  def ruk_constituency_signature_count
    @constituencies.in_ruk.reduce(0) {|sum, constituency| sum + constituency.signature_count}
  end

  def rest_of_world_signature_count
    @countries.from_rest_of_world.reduce(0) {|sum, country| sum + country.signature_count}
  end

  def create_summary_report
    CSV.open("summary.csv", "wb") do |csv|
      csv << ["Scottish constituencies signature count", "rUK constituencies signature count", "Rest of world signature count"]
      csv << [scottish_constituency_signature_count, ruk_constituency_signature_count, rest_of_world_signature_count]
    end
  end

  def create_countries_agreeing_report
    CSV.open("countries_agreeing_with_the_petition.csv", "wb") do |csv|
      csv << ["country", "#signatures"]
      countries.sort_by {|country| country.signature_count}.each {|country| csv << [country.name, country.signature_count]}
    end
  end

  def create_constituencies_agreeing_report
    CSV.open("constituencies_agreeing_with_the_petition.csv", "wb") do |csv|
      csv << ["constituency", "#signatures"]
      constituencies.sort_by { |constituency| constituency.signature_count}.each {|constituency| csv << [constituency.name, constituency.signature_count]}
    end
  end
end

class DataIngest
  attr_reader :countries, :constituencies
  
  def initialize(raw_json)
    @countries = Countries.new
    @constituencies = Constituencies.new

    raw_json['data']['attributes']['signatures_by_country'].each {|record| @countries << Country.new(record['name'], record['signature_count'], record['code'])}
    raw_json['data']['attributes']['signatures_by_constituency'].each {|record| @constituencies << Constituency.new(record['name'], record['ons_code'], record['mp'], record['signature_count'])}
  end
end

class NetDataSource
  attr_reader :source

  def initialize
    uri = URI.parse("https://petition.parliament.uk/petitions/180642.json")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    if response.code != "200"
       raise "Unable to download from petitions site"
    end

    @source = JSON.parse(response.body)
  end
end

class FileDataSource
  attr_reader :source

  def initialize(filename)
    @source = JSON.parse(File.open(ARGV[0], "rb").read)
  end
end

#data = FileDataSource.new(ARGV[0])
data = NetDataSource.new
data_ingest = DataIngest.new(data.source)
report = Report.new(data_ingest.countries, data_ingest.constituencies)

report.create_summary_report
report.create_countries_agreeing_report
report.create_constituencies_agreeing_report

