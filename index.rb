#!/usr/bin/env ruby
# $Id$

require "cgi"
require "erb"

module Trend
   include ERB::Util
   def eval_rhtml( fname, binding )
      rhtml = open( fname, 'r:utf-8' ){|io| io.read }
      result = ERB::new( rhtml, $SAFE, "<>" ).result( binding )
   end
end

if $0 == __FILE__
   include Trend
   begin
      @cgi = CGI.new
      q = @cgi.params[ "q" ][ 0 ]
      targets = @cgi.params[ "target" ]
      print @cgi.header( "text/html; charset=utf-8" )
      print eval_rhtml( "template.html", binding )
   rescue Exception
      if @cgi then
         print @cgi.header( 'status' => CGI::HTTP_STATUS['SERVER_ERROR'], 'type' => 'text/html' )
      else
         print "Status: 500 Internal Server Error\n"
         print "Content-Type: text/html\n\n"
      end
      puts "<h1>500 Internal Server Error</h1>"
      puts "<pre>"
      puts CGI::escapeHTML( "#{$!} (#{$!.class})" )
      puts ""
      puts CGI::escapeHTML( $@.join( "\n" ) )
      puts "</pre>"
      puts "<div>#{' ' * 500}</div>"
   end
end
