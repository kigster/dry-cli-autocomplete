# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::FileName do
  {
    ["https://www.ruby-lang.org/images/header-ruby-logo.png", "image/png"] => "www.ruby-lang.org_images_header-ruby-logo.png",
    ["https://example.com", "text/html"] => "example.com.html",
    ["https://example.com/", "text/html"] => "example.com.html",
    ["https://httpbin.org/json", "application/json"] => "httpbin.org_json.json",
    ["https://example.com/search?q=ruby&page=2", "text/html"] => "example.com_search_q_ruby_page_2.html",
    ["https://example.com/data", "application/x-unknown"] => "example.com_data.txt",
    ["https://example.com/data", nil] => "example.com_data.txt"
  }.each do |(url, type), name|
    it("names #{url} served as #{type.inspect} #{name}") { expect(described_class.call(url, type)).to eq(name) }
  end
end
