require './map'
require './sprite'
require './sound'

class Missle
  include Sprite
  attr_accessor :angle
  attr_accessor :damage
  attr_accessor :speed
  TEX_WIDTH  = 64
  TEX_HEIGHT = 64

  def initialize(window, map, x, y)
    @window = window
    @map = map
    @x = x
    @y = y
    @angle = 0
    @slices = (1..8).map{|n| SpritePool::get(window, "missles/rocket#{n}.png", TEX_HEIGHT)}
    #@slices = SpritePool::get(window, "missles/#{clean_name}#{1}.png", TEX_HEIGHT)
    @last_draw_time = Time.now.to_f
  end

  def clean_name
    self.class.to_s.downcase
  end

  def slices
    pa = @window.player.angle
    a = @angle
    @slices[((a+180+pa+22.5)%360/45).to_i]
  end
end

class Rocket < Missle
end
