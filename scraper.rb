#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class MembersPage < Scraped::HTML
  decorator RemoveNotes
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :members do
    members_tables.xpath('.//tr[td]').map { |tr| fragment(tr => MemberRow) }.reject(&:vacant?).map(&:to_h)
  end

  private

  def members_tables
    noko.xpath('//table[.//th[contains(.,"Pays")]]')
  end
end

class MemberRow < Scraped::HTML
  def vacant?
    tds[0].text.include? 'Vacant'
  end

  field :id do
    name_link.attr('wikidata')
  end

  field :name do
    name_link.text.tidy
  end

  field :party_wikidata do
    party_link&.attr('wikidata')
  end

  # TODO: also fetch the Groups
  field :party do
    party_link&.text&.tidy || 'Indépendant'
  end

  # full constituencies aren't given on this page
  field :country do
    tds[3].text.tidy
  end

  private

  def tds
    noko.css('td')
  end

  # for now, ignore people who have been replaced
  def name_link
    tds[0].css('a').first
  end

  # for now, ignore changes
  def party_link
    tds[1].css('a').first
  end
end

url = 'https://fr.wikipedia.org/wiki/Liste_des_d%C3%A9put%C3%A9s_europ%C3%A9ens_de_la_8e_l%C3%A9gislature'
Scraped::Scraper.new(url => MembersPage).store(:members, index: %i[name party country])
