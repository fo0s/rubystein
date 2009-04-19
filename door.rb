require 'map'

class Door
  attr_accessor :pos
  attr_reader   :state
  OPEN_CLOSE_STEP = 1

  def initialize
    @state = :closed
    @pos   = 0
  end

  def open!
    @state = :opening if closed?
    
    if !open? && @state == :opening
      @pos += OPEN_CLOSE_STEP
    end
  end
  
  def open?
    return @pos == Map::GRID_WIDTH_HEIGHT
  end
  
  def close!
    @state = :closing if open?
    
    if !closed? && @state == :closing
      @pos -= OPEN_CLOSE_STEP
    end
  end
  
  def closed?
    return @pos == 0
  end
  
  def interact
    if @state == :opening
      open!
    elsif @state == :closing
      close!
    end
  end
  
end