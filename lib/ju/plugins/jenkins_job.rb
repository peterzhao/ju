require 'rest-client'
require 'json'
require 'erb'

module Ju
  class JenkinsJob < Ju::Plugin
    attr_reader :data

    def check
      @data= call_server
      render = ERB.new(template)
      render.result(binding)      
    end

    def template
<<EOS
<%
  builds = data['builds'] || []
%>
<div class="jenkins">
  <div class="jenkins-title" title="Job: <%= options['job'] %>"><%= options['name'] %></div>
  <div class="jenkins-builds" style="height: <%= options['height'] - const[:title_height] - const[:title_padding_top] %>px">
    <% builds.each do |build| %>
      <div class="jenkins-build-wrapper" style="height: <%= 1.0/builds.count * 100 - 1 %>%">
        <div class="jenkins-build <%= build['state'] %>">
          <div class="jenkins-build-title vertical-align-block">
              <div class="jenkins-build-number" title="Build number: <%= build['number'] %>"><%= build['number'] %></div>
              <div class="ellipseis jenkins-build-info" title="Started <%= build['started'] %>"><%= build['started'] %></div>
          </div>
          <div class="jenkins-build-details vertical-align-block" style="width: <%= options['width'] - const[:build_number_width] - 3 %>px">
              <% build['changes'].each do |change| %>
                <div class="jenkins-build-info jenkins-change-message" title="Author: <%= change['author'] %>, Message: <%= change['message'] %>, Commit ID: <%= change['commitId'] %>">
                  <%= change['message'] %>
                </div>
              <% end %>
              <% if build['changes'].empty? %>
                <% build['causes'].each do |cause| %>
                <div class="jenkins-build-info"><%= cause %></div>
                <% end %>
              <% end %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
</div>
EOS
    end

    def style
<<EOS
.jenkins-title {
 text-align: center;
 color: black;
 font-weight: 600;
 font-size: 120%;
 padding-top: #{const[:title_padding_top]}px;
 height: #{const[:title_height]}px;
}
.jenkins-build-wrapper {
  clear: both;
  width: 100%;
}
.jenkins-build {
  height: 95%;
  overflow: hidden;
  border-radius: 3px;
}
.jenkins-build-title{
  float: left;
  width: #{const[:build_number_width]}px;
}
.jenkins-build-details{
  float: left;
  overflow: hidden;
}
.jenkins-build-info {
  font-size: 90%;
  line-height: normal; 
}
.jenkins-build-number {
  font-weight: 600;
  font-size: 140%;
}
.jenkins-change-message {
  font-size: 100%;
}
EOS
    end

    def config
        [
          {
            'name' => 'base_url',
            'default' => 'http://localhost:8080',
            'description' => 'Server Base URL',
            'validate' => '^[0-9a-zA-Z\-_:/.]+$',
            'validation_message' => 'Server base URL is not a valid URL.'
          },
          {
            'name' => 'job',
            'description' => 'Job Name',
            'validate' => '^[0-9a-zA-Z\-_ ]+$',
            'validation_message' => 'Job Name can only contain alphanumeric characters, space, dash and underscore.'
          },
          {
            'name' => 'user',
            'description' => 'User Name',
            'validate' => '^.*$',
            'validation_message' => 'User Name can be any characters.'
          },
          {
            'name' => 'password',
            'description' => 'Password',
            'validate' => '^.*$',
            'validation_message' => 'Password can be any characters.'
          },
          {
            'name' => 'number_of_builds',
            'description' => 'Number of Builds',
            'validate' => '^[0-9]+$',
            'validation_message' => 'Number of Builds must be digits.',
            'default' => 3
          }
      ]
    end

    private 

    def call_server
      tree_param = "builds[number,url,result,timestamp,building,actions[causes[shortDescription]],changeSet[items[msg,commitId,author[fullName]]]]{0,#{options['number_of_builds']}}"
      params = { :method =>  :get, 
                 :url =>  "#{options['base_url']}/job/#{URI.escape(options['job'])}/api/json?tree=#{URI.escape(tree_param)}"
               }
      if options['user']
        params[:user] = options['user']
        params[:password] = options['password']
      end
      begin
        response = RestClient::Request.execute(params)
      rescue => e
        #return {'error' => e.message} 
        raise Ju::RemoteConnectionError.new("Failed to get Jenkins job information. #{e.message}")
      end
      Transformer.transform(JSON.parse(response))
    end

    # to avoid constant already defined warning when reloading class
    def const
      {
        title_height: 27, 
        build_number_width: 84,
        title_padding_top: 3
      }
    end

    class Transformer
      def self.transform(response)
        response['builds'].each do |build|
          build['state'] = get_state(build['result'], build['building'])
          build['changes'] = get_changes(build['changeSet']['items']) 
          build['causes'] = get_causes(build['actions'])
          build['started'] = "#{Ju::TimeConverter.ago_in_words(build['timestamp'])} ago" 
        end
        response
      end

      private 
      
      def self.get_causes(actions)
        causes = []
        (actions.find{ |a| a['causes'] } || {'causes' => []})['causes'].each do |cause|
          causes << cause['shortDescription']
        end
        causes
      end

      def self.get_state(state, building)
        return 'building' if building
        {'SUCCESS' => 'passed', 'FAILURE' => 'failed'}[state] || state
      end

      def self.get_changes(change_items)
        change_items.map do |i| 
          {
            'author' => i['author']['fullName'],
            'commitId' => i['commitId'][0..6],
            'message' => i['msg']
          }
        end
      end
    end
  end
end



Ju::Plugin.register('jenkins_job', Ju::JenkinsJob)
