# frozen_string_literal: true

require "cgi"
require "singleton"
require "flog"
require "language_server-protocol"
require "ruby_lsp/extension"

module RubyLspFlog
  # Extension for the flog linter
  class FlogExtension < ::RubyLsp::Extension
    extend T::Sig

    sig { override.void }
    def activate
      ::RubyLsp::Requests::Diagnostics.register_diagnostic_provider("flog", FlogRunner.instance)
    end

    sig { override.returns(String) }
    def name
      "Ruby LSP Flog"
    end
  end

  class FlogRunner
    extend T::Sig
    include Singleton
    include ::RubyLsp::Requests::Support::DiagnosticsRunner

    Interface = LanguageServer::Protocol::Interface
    Constant = LanguageServer::Protocol::Constant

    sig { override.params(uri: String, document: ::RubyLsp::Document).returns(T::Array[Interface::Diagnostic]) }
    def run(uri, _document)
      filename = CGI.unescape(URI.parse(uri).path)

      # Run flog for this file, parsing the results and generating diagnostics for each of the methods
      flog = Flog.new
      flog.flog(filename)

      flog.totals.filter_map do |method_name, score|
        # TODO: make this configurable
        next if score <= 10

        location = flog.method_locations[method_name]
        next unless location

        # location is of the form filename:start_line-end_line
        filename, range = location.split(":")
        start_line, _end_line = range.split("-").map(&:to_i)
        Interface::Diagnostic.new(
          range: Interface::Range.new(
            start: Interface::Position.new(line: start_line - 1, character: 0),
            end: Interface::Position.new(line: start_line - 1, character: 0),
          ),
          severity: Constant::DiagnosticSeverity::WARNING,
          source: "flog",
          message: "Score of #{score.round(2)} for method #{method_name}",
          code: "flog",
        )
      end
    end
  end
end
