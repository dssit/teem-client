require 'rubygems'
require 'bundler/setup'
require 'mechanize'
require 'net/http'
require 'json'

require 'pp'
require 'byebug'

CLIENT_ID=ENV["CLIENT_ID"]
CLIENT_SECRET=ENV["CLIENT_SECRET"]
REDIRECT_URI=ENV["REDIRECT_URI"]

USERNAME=ENV["USERNAME"]
PASSWORD=ENV["PASSWORD"]

ORG_NAME=ENV["ORG_NAME"]

def request(methods, access_token, url, json_obj = nil)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  if methods == :get
    request = Net::HTTP::Get.new(uri.request_uri)
  elsif methods == :post
    request = Net::HTTP::Post.new(uri.request_uri)
  elsif methods == :patch
    request = Net::HTTP::Patch.new(uri.path)
  elsif methods == :delete
    request = Net::HTTP::Delete.new(uri.request_uri)
  end

  if access_token
    request.add_field("Authorization", "Bearer #{access_token}")
  end

  if json_obj
    request.add_field('Content-Type', 'application/json')
    request.body = json_obj
  end

  response = http.request(request)

  return response.body ? JSON.parse(response.body) : nil
end

# Authorizes against the Teem API. Required before any API actions.
# Returns the Teem API JSON object containing the access token.
def teem_authorize
  # Enable this for Mechanize debugging
  #Mechanize.log = Logger.new $stderr

  browser = Mechanize.new { |agent|
    agent.user_agent_alias = 'Mac Safari'
  }

  # Load the sign-in page
  page = browser.get("https://app.teem.com/oauth/authorize/?client_id=#{CLIENT_ID}&redirect_uri=#{REDIRECT_URI}&response_type=code&scope=users")

  # Find the link to sign in via SSO
  sign_in_link = page.links.find { |link| link.text.include? 'Sign In with Company SSO' }

  # Click that link
  page = sign_in_link.click

  # We will be prompted for our organization
  org_ask_form = page.forms[0]
  org_ask_form.fields[0].value = ORG_NAME

  # Submit that form
  page = browser.submit(page.forms.first)

  # We should be on the SSO login page now. Fill it out.
  f = page.forms[0]
  f.field_with(:name => "UserName").value = USERNAME
  f.field_with(:name => "Password").value = PASSWORD
  page = f.submit

  # We are now at a weird, no-where-place page that we just need to submit (SAML stuff?)
  f = page.forms.first
  page = f.submit

  # We should now be at teem.com being asked to Authorize
  f = page.forms.first
  authorize_btn = f.button_with(:value => 'Authorize')

  the_code = nil

  # This will take us back to our Roles page, which doesn't exist
  begin
    page = browser.submit(f, authorize_btn)
  rescue  Mechanize::ResponseCodeError => e
    regex_results = /code=(\w+)/.match(e.to_s)

    the_code = regex_results[1]
  end

  url = "https://app.teem.com/oauth/token/?client_id=#{CLIENT_ID}&client_secret=#{CLIENT_SECRET}&grant_type=authorization_code&redirect_uri=#{REDIRECT_URI}&code=#{the_code}"

  return request(:post, nil, url)
end

def teem_get_users(access_token)
  url = "https://app.teem.com/api/v4/accounts/users/"

  response = request(:get, access_token, url)
  return response["users"]
end

def teem_create_user(access_token, organization_id, email, first_name, last_name)
  url = "https://app.teem.com/api/v4/accounts/users/"

  json_obj = {'user' => { 'organization_id' => organization_id,
                          'email' => "#{email}",
                          'first_name' => "#{first_name}",
                          'last_name' => "#{last_name}"}}.to_json

  response = request(:post, access_token, url, json_obj)
  return response["user"]
end

def teem_get_groups(access_token)
  url = "https://app.teem.com/api/v4/accounts/groups/"

  response = request(:get, access_token, url)
  return response["groups"]
end

def teem_get_API_user_info(access_token)
  url = "https://app.teem.com/api/v4/accounts/users/me/"

  response = request(:get, access_token, url)
  return response["user"]
end

def teem_create_group(access_token, organization_id, name, description)
  url = "https://app.teem.com/api/v4/accounts/groups/"

  json_obj = {'group' => { 'organization_id' => organization_id,
                           'name' => "#{name}",
                           'description' => "#{description}"}}.to_json

  response = request(:post, access_token, url, json_obj)
  return response["group"]
end

def teem_update_group_assign(access_token, group_ids, user_id)
  url = "https://app.teem.com/api/v4/accounts/users/#{user_id}/"

  json_obj = {'user' => {'group_ids' => group_ids}}.to_json

  request(:patch, access_token, url, json_obj)
end

def teem_delete_user(access_token, user_id)
  url = "https://app.teem.com/api/v4/accounts/users/#{user_id}/"

  request(:delete, access_token, url)
end

def teem_delete_group(access_token, group_id)
  url = "https://app.teem.com/api/v4/accounts/groups/#{group_id}/"

  request(:delete, access_token, url)
end

#json = teem_authorize()
#access_token = json["access_token"]
#puts "access_token: #{access_token}"
access_token = "hmVJ8JNF17al28n2pKDCZCww0eK2i6"

#users = teem_get_users(access_token)

# users.each do |user|
# puts user["email"]
#end

organization_id = 13856
email = "cwjwong@ucdavis.edu"
first_name = "Jarold"
last_name = "Wong"
#created_user = teem_create_user(access_token, organization_id, email, first_name, last_name)
#puts created_user['email']

organization_id = 13856
name = "Young 102A"
description = "Can book Young 102A"
#created_group = teem_create_group(access_token, organization_id, name, description)
#puts created_group['name']

#groups = teem_get_groups(access_token)
# groups.each do |group|
# puts group["name"]
#end

#users = teem_get_API_user_info(access_token)
#puts users["email"]

group_ids = [318304, 655258]
user_id = 1023460
#group = teem_update_group_assign(access_token, group_ids, user_id)

user_id = 2146837
#teem_delete_user(access_token, user_id)

group_id = 684125
#teem_delete_group(access_token, group_id)
