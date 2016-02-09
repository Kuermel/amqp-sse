require 'sinatra'
require 'sinatra/streaming'
require 'haml'
require 'amqp'

configure do
  disable :logging
  EM.next_tick do
    # Connect to CloudAMQP and set the default connection
    url = 'amqp://wcjncudr:ONEd3KMBhCvGF3ng3Yul4vj5M__6GsKI@chicken.rmq.cloudamqp.com/wcjncudr' || "amqp://guest:guest@localhost"
    #url = ENV['CLOUDAMQP_URL'] || "amqp://guest:guest@localhost"
    AMQP.connection = AMQP.connect url
    PUB_CHAN = AMQP::Channel.new
  end
end

get '/' do
  haml :index
end

post '/publish' do
  # publish a message to a fanout exchange
  message = params[:message]
  channel = params[:channel]
  PUB_CHAN.fanout("#{channel}", auto_delete: true).publish "Channel:#{channel} Message: #{message} "
  204
end

get '/stream', provides: 'text/event-stream' do
  channel2 = params['channel2']
  stream :keep_open do |out|
    AMQP::Channel.new do |channel|
      channel.queue('', exclusive: true, auto_delete: true) do |queue|
        # create a queue and bind it to the fanout exchange
        queue.bind(channel.fanout("#{channel2}", auto_delete: true)).subscribe do |payload|
          out << "data: #{payload}\n\n"
        end
      end

      # add a timer to keep the connection alive 
      timer = EM.add_periodic_timer(20) { out << ":\n" } 

      # clean up when the user closes the stream
      out.callback do
        timer.cancel
        channel.close
      end
    end
  end
end

