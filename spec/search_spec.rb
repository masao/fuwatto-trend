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

   it "should return some results for a normal query." do
      config_fname = File.join( File.dirname( __FILE__ ), "..", "config.yml" )
      config = YAML.load( open config_fname )
      db = Trend::CiNiiArticles.new
      result = db.search( "portal", { :config => config } )
      result[ :pubyear ].should_not be_empty
      result[ :pubyear ].should have_key( 2012 )
   end
end
