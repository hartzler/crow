require 'rubygems'
require 'haml'

def partial(name)
  Haml::Engine.new(IO.read("src/haml/_#{name}.haml.partial")).render
end
