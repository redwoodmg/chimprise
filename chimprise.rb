require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'highrise'

class Chimprise < Sinatra::Base
  include Highrise
  
  Config = YAML.load_file('config.yml')
  Base.site = Config['highrise']['site']
  Base.user = Config['highrise']['user']
  
  post '/:list_id/:list_key' do
    list = Config['lists'][params['list_id']]
    authenticated = list && params['list_key'] == list['key'] && %w{subscribe unsubscribe}.include?(params['type'])
    
    if authenticated
      Chimprise.send(params['type'], list, params['data'])
    else
      status 400
    end
  end
  
  def self.find_by_email(email)
    Person.search(:email => email).first
  end
  
  def self.passes_interest_filter?(list, data)
    list_interests, user_interests = list['interests'], data['merges']['INTERESTS']
    return true unless list_interests && user_interests
    
    (list_interests & user_interests.split(',').map(&:strip)).any?
  end
  
  def self.subscribe(list, data)
    return unless passes_interest_filter?(list, data)
    
    person = find_by_email(data['email']) || Person.create(
      :first_name => data['merges']['FNAME'] || data['email'].split('@').first,
      :last_name => data['merges']['LNAME'],
      :contact_data => {
        :email_addresses => [{:address => data['email']}]
      }
    )

    (list['tags'] || []).each { |tag| person.tag!(tag) }
    person.note! :body => "Subscribed to list #{list['name']}: " + 
                          "https://us1.admin.mailchimp.com/lists/members/view?id=#{data['web_id']}"
  end
  
  def self.unsubscribe(list, data)
    if person = find_by_email(data['email'])
      person.note! :body => "Unsubscribed from list #{list['name']}: " + 
                            "https://us1.admin.mailchimp.com/lists/members/view?id=#{data['web_id']}"
    end
  end
end

class Highrise::Person
  def note!(params={})
    Highrise::Note.create({
      :subject_type => 'Party',
      :subject_id => id
    }.merge(params))
  end
end