require 'map'
require 'sprite'
require 'weapon'
require 'sound'

module AStar
  Coordinate = Struct.new(:x, :y)

  def line_of_sight(map,start, goal)
    start  = Coordinate.new(start[0], start[1])
    goal   = Coordinate.new(goal[0], goal[1])

    dy = (goal.y.to_f - start.y)/100
    dx = (goal.x.to_f - start.x)/100

    x = start.x
    y = start.y

    100.times do
      return false unless map.walkable?(y.to_i,x.to_i)
      x += dx
      y += dy
    end

    return Coordinate.new((start.x+goal.x)/2, (start.y+goal.y)/2)
  end

  def find_path(map, start, goal)
    line_of_sight(map, start, goal)
  end

  def dist_between(a, b)
    col_a, row_a = Map.matrixify(a.x, a.y)
    col_b, row_b = Map.matrixify(b.x, b.y)

    if col_a == col_b && row_a != row_b
      1.0
    elsif col_a != col_b && row_a == row_b
      1.0
    else
      1.4142135623731 # Sqrt(1**2 + 1**2)
    end
  end

  def neighbor_nodes(map, node)
    node_x, node_y = node.x, node.y
    result = []

    x = node_x - 1
    x_max = node_x + 1
    y_max = node_y + 1
    while(x <= x_max && x < map.width)
      y = node_y - 1

      while(y <= y_max && y < map.height)
        result << Coordinate.new(x, y) unless (x == node_x && y == node_y)
        y += 1
      end

      x += 1
    end

    return result
  end

  def heuristic_estimate_of_distance(start, goal)
    # Manhattan distance
    (goal.x - start.x).abs + (goal.y - start.y).abs
  end

  def reconstruct_path(came_from, current_node)
    #puts "START TRACE"

    while came_from[current_node]
      #puts "#{current_node[0]}, #{current_node[1]}"
      parent = came_from[current_node]

      if came_from[parent].nil?
        # No more parent for this node, return the current_node
        return current_node
      else
        current_node = parent
      end
    end

    #puts "No path found"
  end

  def smallest_f_score(list_of_coordinates, f_score)
    x_min = list_of_coordinates[0]
    f_min = f_score[x_min]

    list_of_coordinates.each {|x|
      if f_score[x] < f_min
        f_min = f_score[x]
        x_min = x
      end
    }

    return x_min
  end
end

class AIPlayer
  include AStar
  include Sprite
  include Damageable

  # Maximum distance (in blocks) that this player can see.
  attr_accessor :sight
  # This enemy must not be closer than the given number of blocks to the main character.
  attr_accessor :min_dinstance
  # Whether the AI for this sprite is active.
  attr_accessor :active

  def initialize(sight = 10, min_distance = 2)
    @sight = sight
    @min_distance = min_distance
    @active = true
  end

  def interact(player, drawn_sprite_x)
    return if @health <= 0 || !@active

    self.current_state = :idle if @current_state == :firing && @firing_left == 0

    if @firing_left > 0
      if (@current_anim_seq_id == 0)
        self.fire(player)
      end
      @firing_left -= 1
      return
    end

    start = Coordinate.new(*Map.matrixify(@x, @y))
    goal  = Coordinate.new(*Map.matrixify(player.x, player.y))
    if (line_of_sight(@map,start,goal) and rand > 0.8)
      @firing_left = 1 + rand(5)
    end

    start = Coordinate.new(*Map.matrixify(@x, @y))
    goal  = Coordinate.new(*Map.matrixify(player.x, player.y))
    if heuristic_estimate_of_distance(start, goal) > @min_distance
      path  = self.find_path(@map, start, goal)
      if path
        self.step_to_adjacent_squarily(path.y, path.x)
      end
    end
  end
end

class Enemy < AIPlayer
  FIRING_SOUND_BLOCKS = 2.5

  attr_accessor :step_size
  attr_accessor :animation_interval

  def initialize(window, kind_tex_paths, map, x, y, death_sound, firing_sound, kill_score = 100, step_size = 4, animation_interval = 0.2)
    super()
    @window = window
    @x = x
    @y = y
    @slices = {}
    @health ||= 100
    @map = map
    @firing_left = 0
    @kill_score  = kill_score
    @firing_sounds = load_sounds(firing_sound)
    @death_sounds  = load_sounds(death_sound)
    @name       ||= self.class.to_s
    #@firing_text  = "#{@name}: \"#{SOUND_TO_TEXT[firing_sound]}\"" if SOUND_TO_TEXT.has_key?(firing_sound)
    #@death_text   = "#{@name}: \"#{SOUND_TO_TEXT[death_sound]}\"" if SOUND_TO_TEXT.has_key?(death_sound)

    kind_tex_paths.each { |kind, tex_paths|
      @slices[kind] = []
      tex_paths.each { |tex_path|
        @slices[kind] << SpritePool::get(window, tex_path, TEX_HEIGHT)
      }
    }

    @step_size = step_size
    @animation_interval = animation_interval

    self.current_state = :idle
    @last_draw_time = Time.now.to_f
  end

  def take_damage_from(player)
    return if @current_state == :dead
    @health -= 5 # TODO: Need to refactor this to take into account different weapons.
    if @health > 0
      self.current_state = :damaged
    else
      self.current_state = :dead
      @firing_sound_sample.stop if @firing_sound_sample
      play_random_sound(@death_sounds)
      player.score += @kill_score
    end
  end

  def step_to_adjacent_squarily(target_row, target_column)
    my_column, my_row = Map.matrixify(@x, @y)
    x = my_column
    y = my_row

    if my_column == target_column || my_row == target_row
      type = "orthogonal"
      # Orthogonal
      x = target_column # * Map::GRID_WIDTH_HEIGHT
      y = target_row    # * Map::GRID_WIDTH_HEIGHT
    else
      # Diagonal
      type = "diagonal"
      x = my_column
      y = target_row

      if not @map.walkable?(y, x)
        x = target_column
        y = my_row
      end
    end

    x += 0.5
    y += 0.5

    x *= Map::GRID_WIDTH_HEIGHT
    y *= Map::GRID_WIDTH_HEIGHT

    #puts "#{Time.now} -- (#{x}, #{y})"
    self.step_to(x, y)

  end

  def step_to(x, y)
    return if @current_state == :dead

    if (@x == x && @y == y)
      self.current_state = :idle
      return
    end

    self.current_state = :walking if self.current_state != :walking &&
      @current_anim_seq_id + 1 == @slices[@current_state].size

    dx = x - @x
    dy = (y - @y) * -1

    angle_rad = Math::atan2(dy, dx) * -1

    @x += @step_size * Math::cos(angle_rad)
    @y += @step_size * Math::sin(angle_rad)
  end

  def current_state
    @current_state
  end

  def current_state=(state)
    @current_state       = state
    @current_anim_seq_id = 0
    if state == :idle || state == :walking || state == :firing
      @repeating_anim = true
    else
      @repeating_anim = false
    end
  end

  def slices
    # Serve up current slice
    now = Time.now.to_f

    if @current_state == :dead && @current_anim_seq_id + 1 == @slices[:dead].size && !@on_death_called
      @on_death_called = true
      on_death if respond_to?(:on_death, true)
    end

    if not (( @current_state == :dead and @current_anim_seq_id + 1 == @slices[:dead].size ) or (@current_state == :idle))
      if now >= @last_draw_time + @animation_interval
        @current_anim_seq_id += 1
        if @repeating_anim
          @current_anim_seq_id = @current_anim_seq_id % @slices[@current_state].size
        else
          if @current_anim_seq_id >= @slices[@current_state].size
            self.current_state = :idle
          end
        end

        @last_draw_time = now
      end
    end

    return @slices[@current_state][@current_anim_seq_id]
  end

  def fire(player)
    return if @current_status == :dead
    dx = player.x - @x
    dy = player.y - @y
    r_2 = dx * dx + dy * dy
    f_2 = FIRING_SOUND_BLOCKS * FIRING_SOUND_BLOCKS * Map::GRID_WIDTH_HEIGHT * Map::GRID_WIDTH_HEIGHT
    r_2 = f_2 if r_2 < f_2

    volume = f_2 / (r_2 * 1.25)

    if @firing_sound_sample.nil? || !@firing_sound_sample.playing?
      @firing_sound_sample = play_random_sound(@firing_sounds)
    end
    player.take_damage_from(self)

    self.current_state = :firing
  end

  private

  def load_sounds(sounds)
    sounds = [sounds] if !sounds.is_a?(Array)
    sounds.map do |sound_file|
      { :file => sound_file, :sound => SoundPool.get(@window, sound_file) }
    end
  end

  def play_random_sound(sounds)
    sound = sounds[rand(sounds.size)]
    text = SOUND_TO_TEXT[sound[:file]]
    @window.show_text("#{@name}: \"#{text}\"") if text
    sound[:sound].play
  end
end

class MeleeEnemy < Enemy
  def interact(player, drawn_sprite_x)
    return if @health <= 0

    self.current_state = :idle if @current_state == :firing && @firing_left == 0

    if @firing_left > 0
      if (@current_anim_seq_id == 0)
        self.fire(player)
      end
      @firing_left -= 1
      return
    end

    start = Coordinate.new(*Map.matrixify(@x, @y))
    goal  = Coordinate.new(*Map.matrixify(player.x, player.y))

    h = heuristic_estimate_of_distance(start, goal)

    if h > @min_distance
      path  = self.find_path(@map, start, goal)
      if path
        self.step_to_adjacent_squarily(path.y, path.x)
      end
    elsif h == @min_distance and line_of_sight(@map,start,goal) and rand > 0.5
      @firing_left = 1 + rand(5)
    end
  end
end

class Guard < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 100, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ['guard_idle.png'],
      :walking => ['guard_walking.png', 'guard_walking2.png', 'guard_walking3.png', 'guard_walking4.png'],
      :firing  => ['guard_firing.png', 'guard_firing2.png'],
      :damaged => ['guard_damaged.png', 'guard_dead.png'],
      :dead    => ['guard_dead.png', 'guard_dead2.png', 'guard_dead3.png', 'guard_dead4.png', 'guard_dead5.png']
    }

    sounds  = ['long live php.ogg', 'myphplife.ogg', 'my damn php life.ogg', 'phpforever.ogg']
    firing_sound ||= sounds[rand(sounds.size - 1)]
    death_sound  ||= sounds[rand(sounds.size - 1)]

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 50
  end
end

class Hans < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = 'machine_gun_burst.ogg', kill_score = 1000, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ['hans1.bmp'],
      :walking => ['hans1.bmp', 'hans2.bmp', 'hans3.bmp', 'hans4.bmp'],
      :firing  => ['hans5.bmp', 'hans6.bmp', 'hans7.bmp'],
      :damaged => ['hans8.bmp', 'hans9.bmp'],
      :dead    => ['hans9.bmp', 'hans10.bmp', 'hans11.bmp']
    }

    # Special thanks goes out to Julian Raschke (jlnr on #gosu@irc.freenode.net ) of libgosu.org for recording these samples for us.
    death_sounds  = ['mein_spagetthicode.ogg', 'meine_magischen_qpc.ogg', 'meine_sql.ogg', 'meine_sql.ogg']
    death_sound ||= death_sounds[rand(death_sounds.size - 1)]

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
  end
end

class Ronald < Enemy
  def initialize(window, map, x, y, death_sound = 'balloon.ogg', firing_sound = 'floating.ogg', kill_score = 2000, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ['ronald.png'],
      :walking => ['ronald_moving.png', 'ronald_moving2.png'],
      :firing  => ['ronald_attack.png', 'ronald_attack2.png'],
      :damaged => ['ronald_damaged.png'],
      :dead    => ['ronald_dead.png', 'ronald_dead2.png', 'ronald_dead3.png', 'ronald_dead4.png',
                   'ronald_dead5.png', 'ronald_dead6.png', 'ronald_dead7.png', 'ronald_dead8.png',
                   'ronald_dead9.png', 'ronald_dead10.png']
    }

    @name = "Pennywise McDonalds"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 250
  end

  def on_death
    @map.players.delete(self)
    @map.items << Fries.new(@window, @map, x, y)
  end
end

class Hongli < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 10000, step_size = 3, animation_interval = 0.2, &on_death)
    sprites = {
      :idle    => ['hongli.png'],
      :walking => ['hongli.png'],
      :firing  => ['hongli_attack.png', 'hongli_attack2.png'],
      :damaged => ['hongli_damaged.png'],
      :dead    => ['hongli_dead.png', 'hongli_dead2.png', 'hongli_dead3.png', 'hongli_dead4.png']
    }

    death_sound  ||= 'impossible.ogg'
    firing_sound ||= ['i_hope_you_catch_swine_flu.ogg', 'i_will_not_be_defeated.ogg', 'your_attack_is_weak.ogg']

    @name = "Hongli Lai"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 350
    @on_death = on_death
  end

  private

  def on_death
    @on_death.call if @on_death
  end
end

class Ninh < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 10000, step_size = 3, animation_interval = 0.2, &on_death)
    sprites = {
      :idle    => ['ninh.png'],
      :walking => ['ninh.png'],
      :firing  => ['ninh_attack.png'],
      :damaged => ['ninh_damaged.png'],
      :dead    => ['ninh_dead.png', 'ninh_dead2.png', 'ninh_dead3.png', 'ninh_dead4.png']
    }

    death_sound  ||= 'nooo.ogg'
    firing_sound ||= ['never_gonna_give_you_up.ogg', 'ni.ogg', 'boom_headshot.ogg']

    @name = "Ninh Bui"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 350
    @on_death = on_death
  end

  private

  def on_death
    @on_death.call if @on_death
  end
end

class Zed < Enemy
  def initialize(window, map, x, y, death_sound = 'omgponies.ogg', firing_sound = ['test_all_the_effing_time_is_lame.ogg', 'guitar_weapon.ogg', 'guitar_weapon2.ogg'], kill_score = 10000, step_size = 3, animation_interval = 0.2)
    sprites = {
      :idle    => ['rockzed.png'],
      :walking => ['rockzed_moving.png', 'rockzed_moving2.png'],
      :firing  => ['rockzed_attacking.png', 'rockzed_attacking2.png', 'rockzed_attacking3.png',
                   'rockzed_attacking4.png', 'rockzed_attacking5.png', 'rockzed_attacking6.png',
                   'rockzed_attacking7.png', 'rockzed_attacking8.png', 'rockzed_attacking9.png'],
      :damaged => ['rockzed_damaged.png'],
      :dead    => ['magic_pony.png']
    }

    @name = "Zed Shaw"
    @health = 1337 # That way we can hear the nice evil sound sample ;-)
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
  end
end

class Thin < Enemy
  def initialize(window, map, x, y, death_sound = nil, firing_sound = nil, kill_score = 500, step_size = 3, animation_interval = 0.5)
    sprites = {
      :idle    => ['thin.png'],
      :walking => ['thin.png', 'thin2.png'],
      :firing  => ['thin_attacking.png', 'thin_attacking2.png'],
      :damaged => ['thin_damaged.png'],
      :dead    => ['thin_dead.png', 'thin_dead2.png', 'thin_dead3.png', 'thin_dead4.png']
    }

    sounds = ['connection_broken.ogg', 'long_live_http.ogg', 'too_many_io_errors.ogg']
    death_sound  ||= sounds
    firing_sound ||= sounds

    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 200
    @min_distance = 1
  end
end

class Dog < MeleeEnemy
  def initialize(window, map, x, y, death_sound = 'dog_cry.ogg', firing_sound = 'dog_bark.ogg', kill_score = 500, step_size = 7, animation_interval = 0.2)
    sprites = {
      :idle => ['dog_walking.png'],
      :walking => ['dog_walking.png', 'dog_walking2.png', 'dog_walking3.png', 'dog_walking4.png'],
      :firing  => ['dog_attacking.png', 'dog_attacking2.png', 'dog_attacking3.png'],
      :damaged => ['dog_dead.png', 'dog_dead2.png'],
      :dead    => ['dog_dead.png', 'dog_dead2.png', 'dog_dead3.png', 'dog_dead4.png']
    }

    @name = "Mongrel"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 100
    @min_distance = 1
  end
end

class DavidHasslehoff < MeleeEnemy
  def initialize(window, map, x, y, death_sound = 'dog_cry.ogg', firing_sound = 'machine_gun_burst.ogg', kill_score = 500, step_size = 7, animation_interval = 0.2)
    sprites = {
      :idle => ['david_hasselhoff.png'],
      :walking => ['david_hasselhoff.png'],
      :firing  => ['david_hasselhoff_attack.png'],
      :damaged => ['david_hasselhoff_damaged.png'],
      :dead    => ['david_hasselhoff_damaged.png', 'david_hasselhoff_dead2.png', 'david_hasselhoff_dead3.png', 'david_hasselhoff_dead4.png']
    }

    @name = "David Hasslehoff"
    super(window, sprites, map, x, y, death_sound, firing_sound, kill_score, step_size, animation_interval)
    @health = 250
  end
end
