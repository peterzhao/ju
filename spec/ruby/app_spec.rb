ENV['RACK_ENV'] = 'test'

require_relative '../../app.rb' 
require_relative '../../lib/ju' 
require 'rspec'
require 'rack/test'

describe 'Ju App' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it "should redirect to /boards/Default when getting /" do
    get '/'
    expect(last_response.status).to eq(302)
    expect(last_response.header['Location']).to match(/boards\/Default$/) 
  end

  it "should get board" do
    config = {'board' => 'test',
              'styles' => {},
              'widgets' => [ {'type' => 'gocd', 'id' => 'foo', 'name' => 'foo'} ]
              } 
    expect(Ju::Config).to receive(:get_board_config).with('boo').and_return(config)
    expect(Ju::Board).to receive(:add_style).with(config).and_return(config)
    expect(Ju::Config).to receive(:get_all_boards).and_return(['test', 'moo'])
    get '/boards/boo'
    expect(last_response).to be_ok 
  end

  it "should check widget" do
    config = {'type' => 'gocd'}
    expect(Ju::Config).to receive(:get_widget_config).with('boo', 'myApp').and_return(config)
    expect(Ju::Plugin).to receive(:check).with('gocd', config).and_return('good')

    get '/boards/boo/widgets/myApp'

    expect(last_response).to be_ok 
    expect(last_response.body).to eq('good')
  end

  it "should save layout for a board" do
    data_str = '{"widget1": {"row":1, "col":1}}'
    data = JSON.parse(data_str)
    expect(Ju::Config).to receive(:save_layout).with('boo', data)
    post '/boards/boo/layout', data_str , "CONTENT_TYPE" => "application/json" 
    expect(last_response).to be_ok 
  end

  it "should get a new board form" do
    get '/boards/new'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to match(/New Dashboard/) 
  end


  it "should create a new board whose name contains space" do
    params = {:board_name => ' good one', :sizex => '280', :sizey => '140'}
    expect(Ju::Board).to receive(:validate).with('good one', '280', '140', nil).and_return([])
    expect(Ju::Board).to receive(:save).with('good one', '280', '140', nil, nil)
    post '/boards', params
    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/boards\/good%20one$/) 
  end


  it "should not create a new board if the board validate has errors" do
    params = {:board_name => 'bad_board', :sizex => '280', :sizey => '140', :action => 'new'}
    expect(Ju::Board).to receive(:validate).with('bad_board', '280', '140', nil).and_return(['not good'])
    expect(Ju::Board).not_to receive(:create).with('bad_board', '280', '140')
    post '/boards', params 

    expect(last_response.status).to eq(400)
  end

  it "should get a new widget form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['gocd_pipeline'])
    expect(Ju::Plugin).to receive(:config).with('gocd_pipeline').and_return([])
    get '/boards/boo/widgets/new/gocd_pipeline'
    expect(last_response.status).to eq(200)
  end

  it "should get an error when getting a new widget form for an unexisting board" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['Default'])
    get '/boards/boo/widgets/new/gocd_pipeline'
    expect(last_response.status).to eq(400)
  end

  it "should get an error when getting a new widget form of an unexisting widget type" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])
    get '/boards/boo/widgets/new/gocd_pipeline'
    expect(last_response.status).to eq(400)
  end

  it "should get an error when creating a new widget of an unexisting board" do
    allow(Ju::Config).to receive(:get_all_boards).and_return([])
    post '/boards/boo/widgets/gocd_pipeline'
    expect(last_response.status).to eq(400)
  end

  it "should get an error when creating a new widget of an unexisting widget type" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])
    post '/boards/boo/widgets/gocd_pipeline'
    expect(last_response.status).to eq(400)
  end

  it "should create a new widget" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])

    settings = [{'name' => 'url'}]
    params = {'name' => 'mywidget', 'action' => 'new', 'widget_type' => 'curl'}
    allow(Ju::Plugin).to receive(:config).with('curl').and_return(settings)
    allow(Ju::Widget).to receive(:validate).with(settings, anything).and_return([])
    expect(Ju::Widget).to receive(:save).with('boo', 'curl', settings, anything)
    post '/boards/boo/widgets', params

    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/boards\/boo$/) 
  end

  it "should not create a new widget when validation failed" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])

    settings = [{'name' => 'url'}]
    params = {'name' => 'mywidget', 'action' => 'new', 'widget_type' => 'curl'}
    allow(Ju::Plugin).to receive(:config).with('curl').and_return(settings)
    allow(Ju::Widget).to receive(:validate).with(settings, anything).and_return(['something wrong'])
    expect(Ju::Widget).not_to receive(:save)

    post '/boards/boo/widgets', params

    expect(last_response.status).to eq(400)
  end

  it "should save a widget" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])

    settings = [{'name' => 'url'}]
    params = {'name' => 'mywidget', 'action' => 'new', 'widget_type' => 'curl'}
    allow(Ju::Plugin).to receive(:config).with('curl').and_return(settings)
    allow(Ju::Widget).to receive(:validate).with(settings, anything).and_return([])
    expect(Ju::Widget).to receive(:save).with('boo', 'curl', settings, anything)
    post '/boards/boo/widgets/mywidget', params

    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/boards\/boo$/) 
  end

  it "should not save a widget when validation failed" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Plugin).to receive(:types).and_return(['curl'])

    settings = [{'name' => 'url'}]
    params = {'name' => 'mywidget', 'action' => 'new', 'widget_type' => 'curl'}
    allow(Ju::Plugin).to receive(:config).with('curl').and_return(settings)
    allow(Ju::Widget).to receive(:validate).with(settings, anything).and_return(['something wrong'])
    expect(Ju::Widget).not_to receive(:save)

    post '/boards/boo/widgets/mywdiget', params

    expect(last_response.status).to eq(400)
  end

  it "should get an edit widget form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Config).to receive(:get_board_config).and_return({'widgets' => [{'name' => 'widget1', 'type' => 'gocd_pipeline'}]})
    allow(Ju::Plugin).to receive(:types).and_return(['gocd_pipeline'])
    expect(Ju::Plugin).to receive(:config).with('gocd_pipeline').and_return([])
    get '/boards/boo/widgets/widget1/edit'
    expect(last_response.status).to eq(200)
  end

  it 'should delete a widge' do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    expect(Ju::Config).to receive(:delete_widget).with('boo', 'widget1')
    delete '/boards/boo/widgets/widget1'
    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/boards\/boo$/) 
  end

  it 'should get an error when deleting a widge from an non-existing board' do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['foo'])
    expect(Ju::Config).not_to receive(:delete_widget).with('boo', 'widget1')
    delete '/boards/boo/widgets/widget1'
    expect(last_response.status).to eq(400)
  end
  
  it "should get an edit board form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    expect(Ju::Config).to receive(:get_board_config).and_return({'widgets' => [{'name' => 'widget1', 'type' => 'gocd_pipeline'}], 'base_sizex' => 220, 'base_sizey' => 110})
    get '/boards/boo/edit'
    expect(last_response.status).to eq(200)
  end

  it "should get errors when getting an un-existing board form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['foo'])
    expect(Ju::Config).not_to receive(:get_board_config)
    get '/boards/boo/edit'
    expect(last_response.status).to eq(400)
  end

  it "should get errors when posting an un-existing board form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['foo'])
    post '/boards/boo'
    expect(last_response.status).to eq(400)
  end

  it "should get errors when posting an invalid board form" do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    widgets = [{'name' => 'widget1'}]
    allow(Ju::Config).to receive(:get_board_config).with('boo').and_return({'widgets' => widgets, 'base_sizex' => '100', 'base_sizey' => '200'})
    expect(Ju::Board).to receive(:validate).with('boo', '220', '110', 'boo').and_return(['something wrong'])
    params= {:sizex => '220', :sizey => '110', :board_name => 'boo'}
    post '/boards/boo', params
    expect(last_response.status).to eq(400)
  end

  it "should save a board form" do
    widgets = [{'name' => 'widget1'}]
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    allow(Ju::Config).to receive(:get_board_config).with('boo').and_return({'widgets' => widgets, 'base_sizex' => '100', 'base_sizey' => '200'})
    expect(Ju::Board).to receive(:validate).with('boo', '220', '110', 'boo').and_return([])
    expect(Ju::Board).to receive(:save).with('boo', '220', '110', 'boo', widgets)
    params= {:sizex => '220', :sizey => '110', :board_name => 'boo'}
    post '/boards/boo', params
    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/boards\/boo$/) 
  end

  it 'should delete a board' do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['boo'])
    expect(Ju::Config).to receive(:delete_board).with('boo')
    delete '/boards/boo'
    expect(last_response.status).to eq(303)
    expect(last_response.header['Location']).to match(/\/$/) 
  end

  it 'should get an error when deleting an non-existing board' do
    allow(Ju::Config).to receive(:get_all_boards).and_return(['foo'])
    expect(Ju::Config).not_to receive(:delete_board)
    delete '/boards/boo'
    expect(last_response.status).to eq(400)
  end
end
