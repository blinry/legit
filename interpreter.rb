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
        @tape = Array.new(10000, 0)
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
        @debug = ENV["LEGIT_DEBUG"] == "1"
        @did_jump = false
    end

    def run
        loop do
            @did_jump = false

            @current.message.split("\n").first.myshellsplit.each do |command|
                execute command
                if @debug
                    p @stack
                    p @tape
                end
            end

            unless @did_jump
                case @current.parents.size
                when 0
                    exit
                when 1
                    @current = @current.parents.first
                else
                    v = @stack.pop
                    v = 999 if v < 0 # FIXME
                    @current = @current.parents[[v, @current.parents.size-1].min]
                end
            end
        end
    end

    def execute command
        if @debug
            hash = @current.oid[0..8]
            puts "Executing #{command} (#{hash})..."
        end


        case command
        when "getchar"
            c = STDIN.getc
            @stack.push c.nil? ? 0 : c.ord
        when "putchar"
            c = (@stack.pop % 256).chr
            STDOUT.write c
        when "dup"
            v = @stack.pop
            @stack.push v
            @stack.push v
        when "pop"
            @stack.pop
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
        when /^\[.*\]$/
            tag_name = command[1..-2]
            tag = @repo.tags[tag_name]
            raise "Could not jump to tag '"+tagname+"'" unless tag
            @current = tag.target
            @did_jump = true
        when /^".*"$/
            command.undump.split("").each do |c|
                @stack.push c.ord
            end
        else
            raise "Unknown command '"+command+"'"
        end
    end
end

i = LegitInterpreter.new(ARGV.first)
i.run
