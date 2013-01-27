module Damageable
  attr_accessor :health
  
  def dead?
    @health <= 0
  end
  
  def take_damage_from(player)
    @health -= 5
    #@health -= player.weapon.damage
  end
end

class Weapon
  attr_accessor :name, :damage, :idle_sprite, :fire_sprite
end

class PowerOfCode < Weapon
  def initialize(window)
    @name = 'Ruby'
    @damage = 5
    @idle_sprite = Gosu::Image::new(window, 'hand1.bmp', true)
    @fire_sprite = Gosu::Image::new(window, 'hand2.bmp', true)
  end
end

class Pistol < Weapon
  def initialize(window)
    @name = 'COD4'
    @damage = 10
    @idle_sprite = Gosu::Image::new(window, 'gun.png', true)
    @fire_sprite = Gosu::Image::new(window, 'gun2.png', true)
  end
end
