#!/usr/bin/env ruby
# $Id$

$:.push File.join( File.dirname( __FILE__ ), ".." )
require "search.rb"

describe "search.rb" do
   it "should return empty if parameter \"q\" is empty." do
      config_fname = File.join( File.dirname( __FILE__ ), "..", "config.yml" )
      config = YAML.load( open config_fname )
      db = Trend::CiNiiArticles.new
      result = db.search( "", { :config => config } )
      result[ :pubyear ].should be_empty
   end
end
