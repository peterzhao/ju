Given(/^a gocd pipeline which have the builds$/) do |table|
  json = get_builds(table)
  Ju.mb_stub_from_json(json, 4547)
end

Given(/^a dashboard 'test\-gocd' with a gocd widget 'my\-widget' which monitor the gocd pipeline$/) do
  File.open("spec/data/config/test-gocd.json","w") {|file| file.write({"widgets"=>[{"name"=>"my-widget", "pipeline" => "ju", "type"=>"gocd_pipeline", "base_url"=>"http://localhost:4547", "user"=>"guest", "password"=>"1234", "pull_inteval"=>5, "number_of_instances"=>11, "row"=>"1", "col"=>"1", "sizex"=>"2", "sizey"=>"4"}], "board"=>"test-gocd"}.to_json)}
end

When(/^I go the dashboard 'test\-gocd'$/) do
  visit ('/boards/test-gocd')  
end

When(/^the widget 'my\-widget' should contain the build info$/) do |table|
  table.hashes.each do |row|
    within(find('.gocd-build-number',text:"#{row[:build_label]}").find(:xpath, "..").find(:xpath,"..")) do
      expect(find('.gocd-build-label-details')).to have_text(row[:commit_message])
      expect(find('.gocd-stage.'"#{row[:result]}")).not_to be_nil
    end
  end
end
