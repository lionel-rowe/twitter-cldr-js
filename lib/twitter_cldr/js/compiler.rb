# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'mustache'
require 'uglifier'
require 'coffee-script'

module TwitterCldr
  module Js
    CompiledFile = Struct.new(:source, :source_map)

    class Compiler
      attr_reader :locales

      def initialize(options = {})
        @locales = options[:locales] || TwitterCldr.supported_locales
        @features = options[:features] || implementation_renderers.keys
        @data = options[:features] || data_renderers.keys
        @test_helpers = options[:test_helpers] || test_helper_renderers.keys
        @prerender = options[:prerender].nil? ? true : options[:prerender]
        @source_map = options[:source_map]
      end

      def compile_bundle(bundle, bundle_elements, bundle_hash, options = {})
        contents = ""
        bundle_elements.each do |bundle_element|
          if renderer_const = bundle_hash[bundle_element]
            if bundle[:locale]
              contents << renderer_const.new(:locale => bundle[:locale], :prerender => @prerender).render
            else
              contents << renderer_const.new(:prerender => @prerender).render
            end
          end
        end

        bundle[:contents] = contents
        bundle[:source_map] = @source_map

        result = CoffeeScript.compile(bundle.render, {
          :bare => false,
          :sourceMap => @source_map
        })

        file = if @source_map
          CompiledFile.new(result["js"], result["sourceMap"])
        else
          CompiledFile.new(result)
        end

        file.source = post_process_file(file.source, options)
        file
      end

      def post_process_file(file_source, options)
        options[:minify] = true unless options.include?(:minify)
        # required alias definition that adds twitter_cldr to Twitter's static build process
        file_source.gsub!(/\/\*<<module_def>>\s+\*\//, %Q(/*-module-*/\n/*_lib/twitter_cldr_*/))

        if options[:minify]
          file_source = Uglifier.compile(file_source)
        end

        file_source
      end

      def compile_each(options = {})
        @locales.each do |locale|
          bundle = TwitterCldr::Js::Renderers::DataBundle.new
          bundle[:locale] = locale

          bundle[:contents] = data_renderers.inject({}) do |ret, (data_renderer_name, data_renderer_class)|
            data_renderer = data_renderer_class.new(:locale => locale)
            data = data_renderer.get_data
            data.each_pair do |name, value|
              ret[name] = value
            end

            ret
          end.to_json

          file = post_process_file(CoffeeScript.compile(bundle.render), options)

          yield file, TwitterCldr.twitter_locale(locale)
        end
      end

      def compile_implementation(options = {})
        bundle = TwitterCldr::Js::Renderers::Bundle.new
        bundle[:locale] = TwitterCldr::DEFAULT_LOCALE
        file = compile_bundle(bundle, @features, implementation_renderers, options)

        file.source
      end

      def compile_test(options = {})
        bundle = TwitterCldr::Js::Renderers::TestBundle.new
        file = compile_bundle(bundle, @test_helpers, test_helper_renderers, options)
        file.source
      end

      private

      def implementation_renderers
        @implementation_renderers ||= {
          :settings                        => TwitterCldr::Js::Renderers::ImplementationRenderers::Settings::SettingsRenderer,
          :plural_rules                    => TwitterCldr::Js::Renderers::ImplementationRenderers::PluralRules::PluralRulesRenderer,
          :timespan                        => TwitterCldr::Js::Renderers::ImplementationRenderers::Calendars::TimespanRenderer,
          :datetime                        => TwitterCldr::Js::Renderers::ImplementationRenderers::Calendars::DateTimeRenderer,
          :additional_date_format_selector => TwitterCldr::Js::Renderers::ImplementationRenderers::Calendars::AdditionalDateFormatSelectorRenderer,
          :currencies                      => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::CurrenciesRenderer,
          :lists                           => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::ListRenderer,
          :bidi                            => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::BidiRenderer,
          :break_iterator                  => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::BreakIteratorRenderer,
          :calendar                        => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::CalendarRenderer,
          :code_point                      => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::CodePointRenderer,
          :numbering_systems               => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::NumberingSystemsRenderer,
          :phone_codes                     => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::PhoneCodesRenderer,
          :postal_codes                    => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::PostalCodesRenderer,
          :languages                       => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::LanguagesRenderer,
          :unicode_regex                   => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::UnicodeRegexRenderer,
          :territories_containment         => TwitterCldr::Js::Renderers::ImplementationRenderers::Shared::TerritoriesContainmentRenderer,
          :number_parser                   => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::NumberParser,
          :component                       => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::ComponentRenderer,
          :literal                         => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::LiteralRenderer,
          :unicode_string                  => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::UnicodeStringRenderer,
          :character_class                 => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::CharacterClassRenderer,
          :character_range                 => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::CharacterRangeRenderer,
          :character_set                   => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegex::CharacterSetRenderer,
          :symbol_table                    => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::SymbolTableRenderer,
          :parser                          => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::ParserRenderer,
          :segmentation_parser             => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::SegmentationParserRenderer,
          :unicode_regex_parser            => TwitterCldr::Js::Renderers::ImplementationRenderers::Parsers::UnicodeRegexParserRenderer,
          :token                           => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::TokenRenderer,
          :composite_token                 => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::CompositeTokenRenderer,
          :tokenizer                       => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::TokenizerRenderer,
          :segmentation_tokenizer          => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::SegmentationTokenizerRenderer,
          :unicode_regex_tokenizer         => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::UnicodeRegexTokenizerRenderer,
          :rbnf_tokenizer                  => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::RBNFTokenizerRenderer,
          :number_tokenizer                => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::NumberTokenizerRenderer,
          :pattern_tokenizer               => TwitterCldr::Js::Renderers::ImplementationRenderers::Tokenizers::PatternTokenizerRenderer,
          :numbers                         => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::NumbersRenderer,
          :rbnf                            => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::RBNFRenderer,
          :number_data_reader              => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::NumberDataReaderRenderer,
          :rbnf_formatters                 => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::FormattersRenderer,
          :rbnf_rule                       => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::RuleRenderer,
          :rbnf_rule_group                 => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::RuleGroupRenderer,
          :rbnf_rule_set                   => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::RuleSetRenderer,
          :rbnf_substitution               => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::SubstitutionRenderer,
          :rbnf_rule_parser                => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::RuleParserRenderer,
          :plural                          => TwitterCldr::Js::Renderers::ImplementationRenderers::Numbers::RBNF::PluralRenderer,
          :range                           => TwitterCldr::Js::Renderers::ImplementationRenderers::Utils::RangeRenderer,
          :range_set                       => TwitterCldr::Js::Renderers::ImplementationRenderers::Utils::RangeSetRenderer,
          :code_points                     => TwitterCldr::Js::Renderers::ImplementationRenderers::Utils::CodePointsRenderer
        }
      end

      def data_renderers
        @data_renderers ||= {
          :settings                        => TwitterCldr::Js::Renderers::DataRenderers::Settings::SettingsRenderer,
          :plural_rules                    => TwitterCldr::Js::Renderers::DataRenderers::PluralRules::PluralRulesRenderer,
          :timespan                        => TwitterCldr::Js::Renderers::DataRenderers::Calendars::TimespanRenderer,
          :datetime                        => TwitterCldr::Js::Renderers::DataRenderers::Calendars::DateTimeRenderer,
          :break_iterator                  => TwitterCldr::Js::Renderers::DataRenderers::Shared::BreakIteratorRenderer,
          :calendar                        => TwitterCldr::Js::Renderers::DataRenderers::Shared::CalendarRenderer,
          :code_point                      => TwitterCldr::Js::Renderers::DataRenderers::Shared::CodePointRenderer,
          :lists                           => TwitterCldr::Js::Renderers::DataRenderers::Shared::ListRenderer,
          :languages                       => TwitterCldr::Js::Renderers::DataRenderers::Shared::LanguagesRenderer,
          :number_parser                   => TwitterCldr::Js::Renderers::DataRenderers::Parsers::NumberParser,
          :numbers                         => TwitterCldr::Js::Renderers::DataRenderers::Numbers::NumbersRenderer,
          :rbnf                            => TwitterCldr::Js::Renderers::DataRenderers::Numbers::RBNF::RBNFRenderer,
          :number_data_reader              => TwitterCldr::Js::Renderers::DataRenderers::Numbers::RBNF::NumberDataReaderRenderer,
        }
      end

      def test_helper_renderers
        @test_helper_renderers ||= {
          :rbnf                            => TwitterCldr::Js::Renderers::TestRenderers::TestHelpers::RBNFHelperRenderer,
          :plural_rules                    => TwitterCldr::Js::Renderers::TestRenderers::TestHelpers::PluralRulesHelperRenderer,
          :numbers                         => TwitterCldr::Js::Renderers::TestRenderers::TestHelpers::NumbersHelperRenderer
        }
      end

    end
  end
end
