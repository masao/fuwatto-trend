#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# $Id$

$:.push File.join( File.dirname( __FILE__ ), ".." )
require "search.rb"

describe "search.rb" do
   context Trend::CiNiiArticles do
      describe "#search" do
         config_fname = File.join( File.dirname( __FILE__ ), "..", "config.yml" )
         config = YAML.load( open config_fname )
         db = Trend::CiNiiArticles.new( config )

         it "should return empty if parameter \"q\" is empty." do
            result = db.search( "", { :config => config } )
            result[ :pubyear ].should be_empty
         end

         it "should return some results for a normal query." do
            result = db.search( "portal", { :config => config } )
            result[ :pubyear ].should_not be_empty
            result[ :pubyear ].should have_key( 2012 )
         end

         it "should return url for each year." do
            result = db.search( "portal", { :config => config } )
            result[ :pubyear ][ 2010 ].should have_key( :url )
            url = result[ :pubyear ][ 2010 ][ :url ]
            url.should match( /\b2010\b/ )
            url.should_not match( /appid/ )
            result[ :pubyear ][ 2010 ].should have_key( :number )
         end

         it "should return some results for unusual query '日本', too many hits." do
            result = db.search( "日本", { :config => config } )
            result[ :pubyear ].should_not be_empty
         end
      end
   end

   context Trend::CiNiiBooks do
      describe "#search" do
         config_fname = File.join( File.dirname( __FILE__ ), "..", "config.yml" )
         config = YAML.load( open config_fname )
         db = Trend::CiNiiBooks.new( config )

         it "should return url for each year." do
            result = db.search( "ウェブログ", { :config => config } )
            result[ :pubyear ][ 2003 ].should have_key( :url )
            result[ :pubyear ][ 2003 ][ :url ].should match( /\b2003\b/ )
         end

         it "should return some results for unusual query '日本', too many hits." do
            result = db.search( "日本", { :config => config } )
            result[ :pubyear ].should_not be_empty
         end
      end
   end
end
