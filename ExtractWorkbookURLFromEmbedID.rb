require 'net/http'
require 'uri'
require 'json'

client_id = 'yourClientId' # Replace 'yourClientId' with the actual client ID
embed_secret = 'yourEmbedSecret' # Replace 'yourEmbedSecret' with the actual embed secret
cloud_type = 'AWS US' # Set the cloud type here

base_urls = {
  'AWS US' => 'https://aws-api.sigmacomputing.com',
  'AWS Canada' => 'https://api.ca.aws.sigmacomputing.com',
  'AWS Europe' => 'https://api.eu.aws.sigmacomputing.com',
  'AWS UK' => 'https://api.uk.aws.sigmacomputing.com',
  'Azure US' => 'https://api.us.azure.sigmacomputing.com',
  'GCP' => 'https://api.sigmacomputing.com'
}

base_url = base_urls[cloud_type]
auth_url = "#{base_url}/v2/auth/token"

encoded_params = URI.encode_www_form({client_id: client_id, client_secret: embed_secret, grant_type: 'client_credentials'})

auth_options = {
  method: 'POST',
  url: auth_url,
  headers: {
    'Accept' => 'application/json',
    'Content-Type' => 'application/x-www-form-urlencoded'
  },
  body: encoded_params
}

cache = {} # Global cache to store all embed URLs

def get_workbook_url_from_embed_url(embed_url, auth_options, base_url, cache)
  return cache[embed_url] if cache[embed_url]

  begin
    uri = URI(auth_options[:url])
    request = Net::HTTP::Post.new(uri)
    auth_options[:headers].each { |key, value| request[key] = value }
    request.body = auth_options[:body]

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    auth_response = JSON.parse(response.body)
    access_token = auth_response['access_token']

    workbook_list_options = {
      method: 'GET',
      url: "#{base_url}/v2/workbooks",
      headers: {
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{access_token}"
      }
    }

    uri = URI(workbook_list_options[:url])
    request = Net::HTTP::Get.new(uri)
    workbook_list_options[:headers].each { |key, value| request[key] = value }

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    workbook_response = JSON.parse(response.body)
    all_workbook_ids = []
    workbook_url_map = {}

    current_entries = workbook_response['entries']
    has_more = workbook_response['hasMore']
    next_page = workbook_response['nextPage']

    while current_entries.any?
      current_entries.each do |entry|
        all_workbook_ids << entry['workbookId']
        workbook_url_map[entry['workbookId']] = entry['url'] # Store the workbook URL
      end

      break unless has_more

      next_options = {
        method: 'GET',
        url: "#{base_url}/v2/workbooks",
        headers: {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{access_token}"
        },
        params: {
          page: next_page
        }
      }

      uri = URI(next_options[:url])
      uri.query = URI.encode_www_form(next_options[:params])
      request = Net::HTTP::Get.new(uri)
      next_options[:headers].each { |key, value| request[key] = value }

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      next_res = JSON.parse(response.body)
      current_entries = next_res['entries']
      has_more = next_res['hasMore']
      next_page = next_res['nextPage']
    end

    all_workbook_ids.each do |workbook_id|
      embed_options = {
        method: 'GET',
        url: "#{base_url}/v2/workbooks/#{workbook_id}/embeds",
        headers: {
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{access_token}"
        }
      }

      uri = URI(embed_options[:url])
      request = Net::HTTP::Get.new(uri)
      embed_options[:headers].each { |key, value| request[key] = value }

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      res = JSON.parse(response.body)
      res['entries'].each do |entry|
        cache[entry['embedUrl']] = workbook_url_map[workbook_id] # Map embed URL to workbook URL
      end
    end

    # Comment in the line below to return the full list of mappings between your org's embed URLs and the parent workbook URLs
    # return cache

    # Comment in the line below to return the single workbook URL associated with an embed path
    cache[embed_url] || nil

  rescue => e
    puts e.message
    nil
  end
end

# Example usage:
puts get_workbook_url_from_embed_url('yourEmbedPath', auth_options, base_url, cache)
