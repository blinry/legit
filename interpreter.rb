require "rugged"

class String
  def myshellsplit
    pieces = [""]
    stringmode = false
    self.strip.gsub(/\s+/, " ").split("").each do |c|
      if c == '"'
        stringmode = (not stringmode)
      elsif c == ' ' and not stringmode
        pieces << ""
      end

      unless c == ' ' and not stringmode
        pieces[-1] = pieces.last+c
      end
    end
    return pieces
  end
end

class Stack
  def initialize
    @stack = []
  end
  def push value
    if value.nil?
      raise "Tried to push nil"
    end
    @stack.push value
  end
  def pop
    if @stack.empty?
      0
    else
      @stack.pop
    end
  end
end

class Tape
  def initialize
    @tape = Array.new(1000, 0)
    @position = @tape.size/2
  end
  def write value
    if value.nil?
      raise "Tried to write nil"
    end
    @tape[@position] = value
  end
  def read
    @tape[@position]
  end
  def left i
    @position -= i
  end
  def right i
    @position += i
  end
end

class LegitInterpreter
  def initialize path
    @repo = Rugged::Repository.new(path)
    @current = @repo.branches["master"].target
    @stack = Stack.new
    @tape = Tape.new
    @debug = false
  end

  def run
    loop do
      @current.message.myshellsplit.each do |command|
        execute command
        if @debug
          p @stack
        end
      end

      transition
      if @debug
        puts "Now at "+@current.oid
      end

    end
  end

  def execute command
    if @debug
      puts "Executing "+command+"..."
    end

    case command
    when "getchar"
      c = STDIN.getc
      @stack.push c.nil? ? 0 : c.ord
    when "putchar"
      c = @stack.pop.chr
      STDOUT.write c
    when "dup"
      v = @stack.pop
      @stack.push v
      @stack.push v
    when "add"
      a = @stack.pop
      b = @stack.pop
      @stack.push b+a
    when "sub"
      a = @stack.pop
      b = @stack.pop
      @stack.push b-a
    when "cmp"
      a = @stack.pop
      b = @stack.pop
      @stack.push b>a ? 1 : 0
    when "read"
      @stack.push @tape.read
    when "write"
      @tape.write @stack.pop
    when "left"
      v = @stack.pop
      @tape.left v
    when "right"
      v = @stack.pop
      @tape.right v
    when "quit"
      exit
    when /\d+/
      @stack.push command.to_i
    when /^[a-zA-Z]$/
      @stack.push command[0].ord
    when /^".*"$/
      command.undump.split("").each do |c|
        @stack.push c.ord
      end
    else
      raise "Unknown command '"+command+"'"
    end
  end

  def transition
    @repo.references.each("refs/tags/*") do |ref|
      if @current == ref.target
        tagname = ref.name.split("/").last
        branch = @repo.branches[tagname] || @repo.branches["origin/"+tagname]
        raise "Could not jump to branch '"+tagname+"'" unless branch
        @current = branch.target
        return
      end
    end

    case @current.parents.size
    when 0
      exit
    when 1
      @current = @current.parents.first
    else
      v = @stack.pop
      @current = @current.parents[[v, @current.parents.size-1].min]
    end
  end
end

i = LegitInterpreter.new(ARGV.first)
i.run
