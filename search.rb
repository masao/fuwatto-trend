#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "cgi"
require "digest/md5"
require "uri"
require "net/http"
require "net/https"
require "yaml"

require "rubygems"
require "json"
require "libxml"

module Trend
   VERSION = 0.1
   USER_AGENT = "CiNii-Trend #{ VERSION }"
   module Util
      def cache_xml( basedir, prefix, params )
         xml_fname = params.keys.sort_by{|e| e.to_s }.map{|k|
            [ URI.escape( k.to_s ), URI.escape( params[k].to_s ) ].join( "=" )
         }.join("_")
         if xml_fname.size > 245
            xml_fname = Digest::MD5.hexdigest( xml_fname )
         end
         xml_fname << ".xml"
         File.join( basedir, prefix, xml_fname )
      end

      # Supports redirect
      def http_get( uri, limit = 10 )
         #STDERR.puts uri.to_s
         raise "Too many redirects: #{ uri }" if limit < 0
         http_proxy = ENV[ "http_proxy" ]
         proxy, proxy_port = nil
         if http_proxy
            proxy_uri = URI.parse( http_proxy )
            proxy = proxy_uri.host
            proxy_port = proxy_uri.port
         end
         http = Net::HTTP.Proxy( proxy, proxy_port ).new( uri.host, uri.port )
         http.use_ssl = true if uri.scheme == "https"
         http.start do |http|
            response, = http.get( uri.request_uri, { 'User-Agent'=>USER_AGENT } )
            #if response.code !~ /^2/
            #   response.each do |k,v|
            #      p [ k, v ]
            #   end
            #end
            case response
            when Net::HTTPSuccess
               response
            when Net::HTTPRedirection
               redirect_uri = URI.parse( response['Location'] )
               STDERR.puts "redirect to #{ redirect_uri } (#{limit})"
               http_get( uri + redirect_uri, limit - 1 )
            else
               p response.body
               response.error!
            end
         end
      end
   end

   class SearchBase
      def appname
         ( /::(\w+)\Z/.match(self.class.to_s) )[1].downcase
      end
   end

   class CiNiiBase < SearchBase
      def search( q, opts = {} )
         appid = opts[ :config ][ appname ][ "appid" ]
         done = {}
         if q.nil? or q.empty?
            {
               :q => q,
               :target => appname,
               :label  => opts[ :config ][ appname ][ "label" ],
               :totalResults => 0,
               :pubyear => done,
            }
         else
            params_default = {
               :appid => appid,
               :q => q,
               # :count => 200,
            }
            params = params_default.dup
            params[ :sortorder ] = opts[ :sortorder_latest ] if opts[ :sortorder_latest ]
            params[ :count ] = 200
            result1 = _search( params, opts[ :config ] )
            if result1[ :totalResults ] > 0
               years = result1[ :pubyear ].keys.sort.reverse
               while( years.size > 1 )
                  y = years.shift
                  done[ y ] = result1[ :pubyear ][ y ]
               end
               if result1[ :totalResults ] <= result1[ :itemsPerPage ]
                  done[ years[-1] ] = result1[ :pubyear ][ years[-1] ]
               else
                  params = params_default.dup
                  params[ :sortorder ] = opts[ :sortorder_oldest ] if opts[ :sortorder_oldest ]
                  params[ :count ] = 200
                  result2 = _search( params, opts[ :config ] )
                  years2 = result2[ :pubyear ].keys.sort
                  if years2.empty?
                     100.times do |i|
                        params[ :start ] = i * params[ :count ]
                        result2 = _search( params, opts[ :config ] )
                        years2 = result2[ :pubyear ].keys.sort
                        break if not years2.empty?
                     end
                  end
                  while( years2.size > 1 )
                     y = years2.shift
                     done[ y ] = result2[ :pubyear ][ y ]
                  end
                  ( years2.first .. years.first ).each do |y|
                     param = { :year_from => y, :year_to => y }
                     param[ :sortorder ] = opts[ :sortorder_latest ] if opts[ :sortorder_latest ]
                     result = _search( params_default.merge( param ), opts[ :config ] )
                     done[ y ] = result[ :totalResults ]
                  end
               end
               d = done.keys.sort
               ( d[0] .. d[-1] ).each do |k|
                  done[ k ] ||= 0
               end
            end
            {
               :q => q,
               :target => appname,
               :label  => opts[ :config ][ appname ][ "label" ],
               :totalResults => result1[ :totalResults ],
               :pubyear => done,
            }
         end
      end

      include Util
      def _search( params, config = {} )
         count = {}
         cont = nil
         base_url = config[ appname ][ "base_url" ]
         cache_dir = config[ "cache" ][ "basedir" ]
         cache_expires = config[ "cache" ][ "expires" ]
         cache_params = params.reject do |k, v|
            k == :appid or k == :format
         end
         cache_file = cache_xml( cache_dir, appname, cache_params )
         if File.exist?( cache_file ) and ( Time.now - File.mtime( cache_file ) ) < cache_expires
            cont = open( cache_file ){|io| io.read }
         else
            params[ :format ] = "atom"
            if not params.empty?
               opts_s = params.keys.map do |e|
                  "#{ e }=#{ URI.escape( params[e].to_s ) }"
               end.join( "&" )
            end
            # CiNii Opensearch API
            opensearch_uri = URI.parse( "#{ base_url }?#{ opts_s }" )
            STDERR.puts opensearch_uri.inspect
            response = http_get( opensearch_uri )
            cont = response.body
            open( cache_file, "w" ){|io| io.print cont }
         end
         data = {}
         parser = LibXML::XML::Parser.string( cont )
         doc = parser.parse
         # ref. http://ci.nii.ac.jp/info/ja/if_opensearch.html
         data[ :q ] = params[ :q ]
         #p doc.find( "//atom:id", "atom:http://www.w3.org/2005/Atom" )[0].content
         data[ :link ] = doc.find( "//atom:id", "atom:http://www.w3.org/2005/Atom" )[0].content.gsub( /\b(format=atom|appid=(#{ params[ :appid  ] })?)($|&)/, "" )
         data[ :totalResults ] = doc.find( "//opensearch:totalResults" )[0].content.to_i
         if data[ :totalResults ] > 0
            data[ :itemsPerPage ] = doc.find( "//opensearch:itemsPerPage" )[0].content.to_i
         end
         entries = doc.find( "//atom:entry", "atom:http://www.w3.org/2005/Atom" )
         entries.each do |e|
            pubdate = e.find( "./prism:publicationDate", "prism:http://prismstandard.org/namespaces/basic/2.0/" )[0] #.content
            next if pubdate.nil?
            if pubdate.content =~ /\A(\d\d\d\d)/o
               pubyear = $1.to_i
               next if pubyear < 1500
               count[ pubyear ] ||= 0
               count[ pubyear ] += 1
            end
         end
         data[ :pubyear ] = count
         data
      end
   end

   class CiNiiArticles < CiNiiBase
      def search( keyword, opts = {} )
         super( keyword, opts.merge( :sortorder_oldest => 2 ) )
      end
   end

   class CiNiiBooks < CiNiiBase
      def search( keyword, opts = {} )
         super( keyword, opts.merge( { :sortorder_latest => 3,
                                       :sortorder_oldest => 2,
                                     } ) )
      end
   end
end

if $0 == __FILE__
   result = {}
   config = YAML.load( open("config.yml") )
   #p config
   @cgi = CGI.new
   q = @cgi.params[ "q" ][ 0 ]
   target = @cgi.params[ "target" ][ 0 ] || "ciniiarticles"
   callback = @cgi.params[ "callback" ][ 0 ]
   case target
   when "ciniiarticles"
      db = Trend::CiNiiArticles.new
   when "ciniibooks"
      db = Trend::CiNiiBooks.new
   end
   result = db.search( q, :config => config )
   print @cgi.header "application/json"
   print result.to_json
end
